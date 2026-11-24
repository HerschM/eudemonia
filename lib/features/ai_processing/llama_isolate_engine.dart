import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:eudemonia/core/logger/app_logger.dart';
import 'cpu_thread_policy.dart';
import 'llm_generation_loop.dart';
import 'llm_service.dart';
import 'native/llama_backend.dart';

/// [LlmEngine] that owns a [NativeLlamaBackend] and its [LlmGenerationLoop] on one long-lived
/// worker isolate. The loop returns to the worker's event loop after every prompt chunk and every
/// generated token, so stop and dispose take effect within one of them.
class LlamaIsolateEngine implements LlmEngine {
  static const Duration disposeTimeout = Duration(seconds: 5);

  final LLMConfig config;
  final AppLogger? _logger;

  /// The libllama to open; the ggml libraries are looked up next to it.
  final String libraryPath;

  Isolate? _isolate;
  SendPort? _commands;
  ReceivePort? _replies;
  ReceivePort? _exit;
  Completer<String?>? _loadReply;
  Completer<void>? _disposeAck;
  _IsolatePromptSession? _current;
  int _nextPromptId = 0;

  LlamaIsolateEngine(this.config, [this._logger, this.libraryPath = NativeLlamaBackend.defaultLibraryPath]);

  @override
  Future<void> load(String modelPath) async {
    if (_isolate != null) throw StateError('LlamaIsolateEngine.load called twice.');
    if (!await File(modelPath).exists()) {
      throw Exception('LLM model not found at $modelPath');
    }

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
        libraryPath,
        modelPath,
        config.kvCacheMaxSize,
        config.promptChunkTokens,
        config.reusePromptPrefix,
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
      case _Reply.done:
        final session = _current;
        // Messages for a prompt that is no longer current are ignored.
        if (session == null || session.id != reply[1]) return;
        _current = null;
        final error = reply[2] as String?;
        if (error != null) {
          session._fail(Exception('Language model error: $error'));
        } else {
          session._finish(reply[3] as LlmPromptCompletion);
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
  Future<LlmPromptSession> sendPrompt(String prompt, {required int maxOutputTokens, String? grammar}) async {
    final commands = _commands;
    if (commands == null || _isolate == null) {
      throw StateError('LlamaIsolateEngine.sendPrompt called before load.');
    }
    if (_current != null) throw StateError('LlamaIsolateEngine.sendPrompt called while a prompt is running.');
    final id = _nextPromptId++;
    final session = _current = _IsolatePromptSession(id, () => commands.send(<Object?>[_Op.stop.index, id]));
    commands.send(<Object?>[_Op.prompt.index, id, prompt, maxOutputTokens, grammar]);
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
  final Completer<LlmPromptCompletion> _completion = Completer<LlmPromptCompletion>();

  _IsolatePromptSession(this.id, this._sendStop) {
    _completion.future.ignore();
  }

  void _finish(LlmPromptCompletion completion) {
    if (!_completion.isCompleted) _completion.complete(completion);
  }

  void _fail(Object error) {
    if (!_completion.isCompleted) _completion.completeError(error);
  }

  @override
  Future<LlmPromptCompletion> get completion => _completion.future;

  @override
  Future<void> stop() async {
    if (!_completion.isCompleted) _sendStop();
  }
}

enum _Op { load, prompt, stop, dispose }

enum _Reply { loaded, done, disposed }

/// Worker isolate: owns the backend and the loop, one prompt at a time. The thread counts are
/// chosen again before every prompt because the allowed cores change with the app's state.
void _llamaWorkerMain(SendPort replies) {
  final commands = ReceivePort();
  LlamaBackend? backend;
  LlmGenerationLoop? loop;
  int? runningId;
  var stopRequested = false;
  Future<void> running = Future.value();

  Future<void> generate(int id, String prompt, int maxOutputTokens, String? grammar) async {
    final activeBackend = backend;
    final activeLoop = loop;
    if (activeBackend == null || activeLoop == null) {
      replies.send(<Object?>[_Reply.done.index, id, 'model not loaded']);
      return;
    }
    try {
      final threads = readCpuThreads();
      activeBackend.setThreads(reading: threads.reading, writing: threads.writing);
      final r = await activeLoop.run(prompt,
          maxOutputTokens: maxOutputTokens, grammar: grammar, stopRequested: () => stopRequested);
      replies.send(<Object?>[
        _Reply.done.index,
        id,
        null,
        LlmPromptCompletion(
          text: r.text,
          hitOutputCap: r.hitOutputCap,
          stopped: r.stopped,
          promptTokens: r.promptTokens,
          reusedPromptTokens: r.reusedPromptTokens,
          outputTokens: r.outputTokens,
          readMs: r.readMs,
          writeMs: r.writeMs,
          readingThreads: threads.reading,
          writingThreads: threads.writing,
          allowedCores: threads.allowedCores,
        ),
      ]);
    } catch (e) {
      replies.send(<Object?>[_Reply.done.index, id, e.toString()]);
    }
  }

  replies.send(commands.sendPort);

  commands.listen((dynamic message) async {
    final request = message as List<dynamic>;
    switch (_Op.values[request[0] as int]) {
      case _Op.load:
        try {
          final loaded = backend = NativeLlamaBackend.load(
            request[2] as String,
            libraryPath: request[1] as String,
            contextSize: request[3] as int,
            batchSize: request[4] as int,
          );
          loop = LlmGenerationLoop(loaded, reusePromptPrefix: request[5] as bool);
          replies.send(<Object?>[_Reply.loaded.index, null]);
        } catch (e) {
          replies.send(<Object?>[_Reply.loaded.index, e.toString()]);
        }
      case _Op.prompt:
        final id = request[1] as int;
        if (runningId != null) {
          replies.send(<Object?>[_Reply.done.index, id, 'another prompt is running']);
          return;
        }
        runningId = id;
        stopRequested = false;
        running = generate(id, request[2] as String, request[3] as int, request[4] as String?)
            .whenComplete(() => runningId = null);
      case _Op.stop:
        if (runningId != null && runningId == request[1]) stopRequested = true;
      case _Op.dispose:
        stopRequested = true;
        await running;
        try {
          backend?.dispose();
        } catch (_) {}
        backend = null;
        loop = null;
        replies.send(<Object?>[_Reply.disposed.index]);
        commands.close();
    }
  });
}
