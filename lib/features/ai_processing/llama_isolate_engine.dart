import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' show max;
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:eudemonia/core/logger/app_logger.dart';
import 'llm_service.dart';

/// One `getNextWithStatus()` step: (text, done, contextLimitReached).
typedef LlamaTokenStep = (String, bool, bool) Function();

/// Outcome of [runTokenLoop]; [error] is set when the token source threw.
typedef TokenLoopOutcome = ({bool hitOutputCap, bool stopped, String? error});

/// Generates tokens from [next] until done, the context limit, [maxOutputTokens] calls or
/// [stopRequested]. Non-empty pieces go to [onChunk]. Returns to the event loop after every
/// token so a stop message queued on the worker's port is read mid-generation.
Future<TokenLoopOutcome> runTokenLoop({
  required LlamaTokenStep next,
  required int maxOutputTokens,
  required void Function(String chunk) onChunk,
  required bool Function() stopRequested,
}) async {
  var count = 0;
  try {
    while (true) {
      final (text, done, contextLimit) = next();
      count++;
      if (text.isNotEmpty) onChunk(text);
      if (done || contextLimit) return (hitOutputCap: false, stopped: false, error: null);
      if (count >= maxOutputTokens) return (hitOutputCap: true, stopped: false, error: null);
      await Future<void>.delayed(Duration.zero);
      if (stopRequested()) return (hitOutputCap: false, stopped: true, error: null);
    }
  } catch (e) {
    return (hitOutputCap: false, stopped: false, error: e.toString());
  }
}

/// [LlmEngine] that owns a `Llama` instance on one long-lived worker isolate. Generation
/// yields between tokens, so stop and dispose take effect within one token.
class LlamaIsolateEngine implements LlmEngine {
  static const Duration disposeTimeout = Duration(seconds: 5);

  final LLMConfig config;
  final AppLogger? _logger;

  Isolate? _isolate;
  SendPort? _commands;
  ReceivePort? _replies;
  ReceivePort? _exit;
  Completer<String?>? _loadReply;
  Completer<void>? _disposeAck;
  _IsolatePromptSession? _current;
  int _nextPromptId = 0;

  LlamaIsolateEngine(this.config, [this._logger]);

  @override
  Future<void> load(String modelPath) async {
    if (_isolate != null) throw StateError('LlamaIsolateEngine.load called twice.');
    if (!await File(modelPath).exists()) {
      throw Exception('LLM model not found at $modelPath');
    }

    final contextParams = ContextParams()
      ..nCtx = config.kvCacheMaxSize
      // The binding rejects any prompt longer than nBatch, so the batch must span the context.
      ..nBatch = max(config.batchSize, config.kvCacheMaxSize)
      // The per-call cap is enforced by the worker's token loop; -1 is unlimited.
      ..nPredict = -1
      ..nThreads = config.threads
      ..nThreadsBatch = config.threads
      ..typeK = config.kvCacheType
      ..typeV = config.kvCacheType;

    final replies = _replies = ReceivePort();
    final exit = _exit = ReceivePort();
    final ready = Completer<SendPort>();
    final loaded = _loadReply = Completer<String?>();
    replies.listen((message) {
      if (message is SendPort) {
        ready.complete(message);
      } else {
        _onReply(message as List<dynamic>);
      }
    });
    exit.listen((_) => _onExit());

    try {
      _isolate = await Isolate.spawn(_llamaWorkerMain, replies.sendPort,
          onExit: exit.sendPort, errorsAreFatal: true, debugName: 'llm-worker');
      final commands = _commands = await ready.future;
      commands.send(<Object?>[
        _Op.load.index,
        Llama.libraryPath,
        modelPath,
        // The bundled library is CPU-only; the load fails unless no GPU device is selected.
        ModelParams()
          ..nGpuLayers = 0
          ..mainGpu = -1,
        contextParams,
        SamplerParams()..greedy = config.greedySampling,
      ]);
      final error = await loaded.future.timeout(config.modelLoadTimeout);
      if (error != null) throw Exception('The language model failed to load: $error');
    } on TimeoutException {
      _kill();
      throw Exception('The language model did not finish loading within ${config.modelLoadTimeout.inSeconds} seconds.');
    } catch (_) {
      _kill();
      rethrow;
    }
  }

  void _onReply(List<dynamic> reply) {
    switch (_Reply.values[reply[0] as int]) {
      case _Reply.loaded:
        final loaded = _loadReply;
        if (loaded != null && !loaded.isCompleted) loaded.complete(reply[1] as String?);
      case _Reply.chunk:
        final session = _current;
        if (session != null && session.id == reply[1]) session._addChunk(reply[2] as String);
      case _Reply.done:
        final session = _current;
        // Messages for a prompt that is no longer current are ignored.
        if (session == null || session.id != reply[1]) return;
        _current = null;
        final error = reply[4] as String?;
        if (error != null) {
          session._fail(Exception('Language model error: $error'));
        } else {
          session._finish(LlmPromptCompletion(hitOutputCap: reply[2] as bool, stopped: reply[3] as bool));
        }
      case _Reply.disposed:
        final ack = _disposeAck;
        if (ack != null && !ack.isCompleted) ack.complete();
    }
  }

  void _onExit() {
    final loaded = _loadReply;
    if (loaded != null && !loaded.isCompleted) loaded.complete('worker isolate exited');
    final ack = _disposeAck;
    if (ack != null && !ack.isCompleted) ack.complete();
    _failCurrent('worker isolate exited');
    _closePorts();
  }

  void _failCurrent(String reason) {
    final session = _current;
    _current = null;
    session?._fail(StateError('Language model $reason.'));
  }

  @override
  Future<LlmPromptSession> sendPrompt(String prompt, {required int maxOutputTokens}) async {
    final commands = _commands;
    if (commands == null || _isolate == null) {
      throw StateError('LlamaIsolateEngine.sendPrompt called before load.');
    }
    if (_current != null) throw StateError('LlamaIsolateEngine.sendPrompt called while a prompt is running.');
    final id = _nextPromptId++;
    final session = _current = _IsolatePromptSession(id, () => commands.send(<Object?>[_Op.stop.index, id]));
    commands.send(<Object?>[_Op.prompt.index, id, prompt, maxOutputTokens]);
    return session;
  }

  @override
  Future<void> dispose() async {
    final isolate = _isolate;
    final commands = _commands;
    if (isolate == null) return;
    _isolate = null;
    _commands = null;
    final ack = _disposeAck = Completer<void>();
    if (commands != null) {
      // Disposal in the worker waits for an in-flight generation, so stop it first.
      final session = _current;
      if (session != null) commands.send(<Object?>[_Op.stop.index, session.id]);
      commands.send(<Object?>[_Op.dispose.index]);
      try {
        await ack.future.timeout(disposeTimeout);
      } on TimeoutException {
        _logger?.warning('[LLMService] Language worker did not acknowledge dispose within '
            '${disposeTimeout.inSeconds}s; killing it.');
      }
    }
    // Killing the isolate guarantees nothing keeps running; the worker has freed the model if it acked.
    isolate.kill(priority: Isolate.immediate);
    _failCurrent('engine was disposed');
    _closePorts();
  }

  void _kill() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _commands = null;
    _closePorts();
  }

  void _closePorts() {
    _replies?.close();
    _exit?.close();
    _replies = null;
    _exit = null;
  }
}

class _IsolatePromptSession implements LlmPromptSession {
  final int id;
  final void Function() _sendStop;
  final StreamController<String> _chunks = StreamController<String>();
  final Completer<LlmPromptCompletion> _completion = Completer<LlmPromptCompletion>();

  _IsolatePromptSession(this.id, this._sendStop) {
    _completion.future.ignore();
  }

  void _addChunk(String chunk) {
    if (!_chunks.isClosed) _chunks.add(chunk);
  }

  void _finish(LlmPromptCompletion completion) {
    if (!_completion.isCompleted) _completion.complete(completion);
  }

  void _fail(Object error) {
    if (!_completion.isCompleted) _completion.completeError(error);
  }

  @override
  Stream<String> get chunks => _chunks.stream;

  @override
  Future<LlmPromptCompletion> get completion => _completion.future;

  @override
  Future<void> stop() async {
    if (!_completion.isCompleted) _sendStop();
  }

  @override
  Future<void> close() async {
    await _chunks.close();
  }
}

enum _Op { load, prompt, stop, dispose }

enum _Reply { loaded, chunk, done, disposed }

/// Worker isolate: owns the `Llama` instance. Each prompt starts from an empty context.
void _llamaWorkerMain(SendPort replies) {
  final commands = ReceivePort();
  Llama? llama;
  int? runningId;
  var stopRequested = false;
  Future<void> running = Future.value();

  Future<void> generate(int id, String prompt, int maxOutputTokens) async {
    final active = llama;
    if (active == null) {
      replies.send(<Object?>[_Reply.done.index, id, false, false, 'model not loaded']);
      return;
    }
    TokenLoopOutcome outcome;
    try {
      // Resets position, prompt and pending bytes and clears the KV memory; setPrompt then
      // also resets the sampler because the position is 0 (AGENTS.md 4.C).
      active.clear();
      active.setPrompt(prompt);
      outcome = await runTokenLoop(
        next: active.getNextWithStatus,
        maxOutputTokens: maxOutputTokens,
        onChunk: (chunk) => replies.send(<Object?>[_Reply.chunk.index, id, chunk]),
        stopRequested: () => stopRequested,
      );
    } catch (e) {
      outcome = (hitOutputCap: false, stopped: false, error: e.toString());
    }
    replies.send(<Object?>[_Reply.done.index, id, outcome.hitOutputCap, outcome.stopped, outcome.error]);
  }

  replies.send(commands.sendPort);

  commands.listen((dynamic message) async {
    final request = message as List<dynamic>;
    switch (_Op.values[request[0] as int]) {
      case _Op.load:
        try {
          final libraryPath = request[1] as String?;
          if (libraryPath != null) Llama.libraryPath = libraryPath;
          llama = Llama(
            request[2] as String,
            modelParams: request[3] as ModelParams,
            contextParams: request[4] as ContextParams,
            samplerParams: request[5] as SamplerParams,
          );
          replies.send(<Object?>[_Reply.loaded.index, null]);
        } catch (e) {
          replies.send(<Object?>[_Reply.loaded.index, e.toString()]);
        }
      case _Op.prompt:
        final id = request[1] as int;
        if (runningId != null) {
          replies.send(<Object?>[_Reply.done.index, id, false, false, 'another prompt is running']);
          return;
        }
        runningId = id;
        stopRequested = false;
        running = generate(id, request[2] as String, request[3] as int).whenComplete(() => runningId = null);
      case _Op.stop:
        if (runningId != null && runningId == request[1]) stopRequested = true;
      case _Op.dispose:
        stopRequested = true;
        await running;
        try {
          llama?.dispose();
        } catch (_) {}
        llama = null;
        replies.send(<Object?>[_Reply.disposed.index]);
        commands.close();
    }
  });
}
