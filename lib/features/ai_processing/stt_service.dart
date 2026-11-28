import 'dart:async';
import 'dart:isolate';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/core/logger/app_logger.dart';
import 'stt_engine.dart';

export 'stt_engine.dart';

/// On-device speech-to-text service.
///
/// Model loading and decoding are synchronous native calls that take seconds,
/// so they run on a dedicated worker isolate. The UI isolate (which also
/// services hardware capture triggers) only exchanges messages with it.
class STTService {
  final AppLogger? _logger;
  final SttEngineFactory _engineFactory;

  _SttWorker? _worker;
  bool _isInitialized = false;
  Future<void> _teardown = Future.value();

  STTService({this._logger, this._engineFactory = createSherpaSttEngine});

  bool get isInitialized => _isInitialized;

  Future<void> initialize(String modelDir) async {
    if (_isInitialized) return;

    // Never hold two copies of the model: wait for a previous worker to free its weights.
    await _teardown;
    if (_isInitialized) return;

    _logger?.info('[STTService] Initializing speech model from $modelDir...');

    final worker = await _SttWorker.spawn(_engineFactory);
    try {
      await worker.request(_SttOp.load, modelDir);
    } catch (_) {
      await worker.shutdown();
      rethrow;
    }

    _worker = worker;
    _isInitialized = true;
    _logger?.info('[STTService] speech model loaded successfully.');
  }

  Future<String> transcribe(String audioFilePath) async {
    final worker = _worker;
    if (!_isInitialized || worker == null) throw Exception('STT Service not initialized');

    final transcript = await worker.request(_SttOp.transcribe, audioFilePath) as SttTranscript;
    if (transcript.segmentCount > 1) {
      // Never the transcript itself: recordings are private.
      _logger?.info('[STTService] Long recording: ${_seconds(transcript.audioDuration)} s of audio in '
          '${transcript.segmentCount} segments, transcribed in ${_seconds(transcript.elapsed)} s.');
    }
    if (transcript.text.isEmpty) {
      _logger?.warning('[STTService] No speech found in file: $audioFilePath');
    }
    return transcript.text;
  }

  /// Frees the model. The worker handles requests in order, so an in-flight
  /// transcription finishes before its native handles are released.
  void dispose() {
    final worker = _worker;
    _worker = null;
    _isInitialized = false;
    if (worker == null) return;

    _logger?.info('[STTService] Disposing speech model...');
    _teardown = worker.shutdown().then((_) {
      _logger?.info('[STTService] speech model disposed.');
    });
  }
}

String _seconds(Duration duration) => (duration.inMilliseconds / 1000).toStringAsFixed(1);

enum _SttOp { load, transcribe, dispose }

/// Main-isolate handle to the STT worker isolate.
class _SttWorker {
  final Isolate _isolate;
  final SendPort _commands;
  final ReceivePort _replies;
  final ReceivePort _exit;
  final Map<int, Completer<Object?>> _pending = {};
  final Completer<void> _exited = Completer<void>();
  int _nextRequestId = 0;

  _SttWorker._(this._isolate, this._commands, this._replies, this._exit);

  static Future<_SttWorker> spawn(SttEngineFactory engineFactory) async {
    final replies = ReceivePort();
    final exit = ReceivePort();
    final isolate = await Isolate.spawn(
      _sttWorkerMain,
      [replies.sendPort, engineFactory],
      onExit: exit.sendPort,
      debugName: 'stt-worker',
    );

    final events = StreamIterator<dynamic>(replies);
    await events.moveNext();
    final worker = _SttWorker._(isolate, events.current as SendPort, replies, exit);
    worker._listen(events);
    return worker;
  }

  void _listen(StreamIterator<dynamic> events) {
    () async {
      while (await events.moveNext()) {
        final reply = events.current as List<dynamic>;
        final completer = _pending.remove(reply[0] as int);
        if (completer == null) continue;
        if (reply[1] as bool) {
          completer.complete(reply[2]);
        } else {
          completer.completeError(Exception(reply[2] as String));
        }
      }
    }();

    _exit.first.then((_) {
      _replies.close();
      _exit.close();
      for (final completer in _pending.values) {
        completer.completeError(Exception('STT worker stopped unexpectedly'));
      }
      _pending.clear();
      if (!_exited.isCompleted) _exited.complete();
    });
  }

  Future<Object?> request(_SttOp op, [String? argument]) {
    if (_exited.isCompleted) {
      return Future.error(Exception('STT worker is not running'));
    }
    final id = _nextRequestId++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    _commands.send([id, op.index, argument]);
    return completer.future;
  }

  /// Releases the engine and waits for the isolate to exit.
  Future<void> shutdown() async {
    try {
      await request(_SttOp.dispose);
    } catch (_) {
      _isolate.kill(priority: Isolate.immediate);
    }
    await _exited.future;
  }
}

void _sttWorkerMain(List<dynamic> args) {
  final replies = args[0] as SendPort;
  final engineFactory = args[1] as SttEngineFactory;
  final commands = ReceivePort();
  SttEngine? engine;

  replies.send(commands.sendPort);

  commands.listen((dynamic message) {
    final request = message as List<dynamic>;
    final id = request[0] as int;
    final op = _SttOp.values[request[1] as int];
    final argument = request[2] as String?;

    try {
      switch (op) {
        case _SttOp.load:
          final created = engineFactory();
          try {
            created.load(argument!);
          } catch (_) {
            created.dispose();
            rethrow;
          }
          engine = created;
          replies.send([id, true, null]);
        case _SttOp.transcribe:
          final active = engine;
          if (active == null) throw Exception('STT Service not initialized');
          replies.send([id, true, active.transcribe(argument!)]);
        case _SttOp.dispose:
          engine?.dispose();
          engine = null;
          replies.send([id, true, null]);
          commands.close();
      }
    } catch (e) {
      replies.send([id, false, e.toString().replaceFirst('Exception: ', '')]);
    }
  });
}

final sttServiceProvider = Provider<STTService>((ref) {
  final logger = ref.watch(appLoggerProvider);
  return STTService(logger: logger);
});
