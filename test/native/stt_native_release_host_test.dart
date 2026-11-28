import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:eudemonia/features/ai_processing/stt_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'process_memory.dart';

// Loads the real sherpa-onnx recognizer in a worker isolate that ends without dispose, as when
// the Flutter engine is destroyed, and checks that the process memory returns. Under
// `flutter test` sherpa_onnx looks its symbols up in the process, so the test loads the macOS
// library from the pub cache first. Run on the Mac with the Parakeet model files, for example:
//   EUDEMONIA_SHERPA_LIB=~/.pub-cache/hosted/pub.dev/sherpa_onnx_macos-1.13.8/macos/sherpa_onnx_macos/\
//   sherpa-onnx.xcframework/macos-arm64_x86_64/libsherpa-onnx-c-api.dylib \
//   EUDEMONIA_STT_MODEL_DIR=models/parakeet flutter test test/native/stt_native_release_host_test.dart
final String? _library = Platform.environment['EUDEMONIA_SHERPA_LIB'];
final String? _modelDir = Platform.environment['EUDEMONIA_STT_MODEL_DIR'];
final String? _skip = _library == null || _modelDir == null
    ? 'Set EUDEMONIA_SHERPA_LIB (the sherpa-onnx C API library) and EUDEMONIA_STT_MODEL_DIR (a directory '
        'with the Parakeet int8 files) to run the STT native release host test.'
    : null;

/// Least memory the recognizer must add when it loads (Parakeet int8 on an M-series Mac: about
/// 400 MB).
const int _minimumLoadBytes = 256 << 20;

enum _End { dispose, exit, kill }

/// [message]: reply port, library, model directory, how the worker ends. Replies with the memory
/// once the recognizer is loaded (before the dispose for [_End.dispose]).
void _worker(List<Object> message) {
  final reply = message[0] as SendPort;
  // Opened globally, so the process lookups of sherpa_onnx and of the engine find its symbols.
  DynamicLibrary.open(message[1] as String);
  final engine = SherpaSttEngine()..load(message[2] as String);
  final loaded = processMemory();
  switch (_End.values[message[3] as int]) {
    case _End.dispose:
      engine.dispose();
      reply.send(loaded);
    case _End.exit:
      reply.send(loaded);
    case _End.kill:
      // An open port keeps the isolate alive until it is killed.
      final port = ReceivePort();
      reply.send(loaded);
      port.listen((_) {});
  }
}

/// Runs one worker to its end; returns the memory while it held the recognizer.
Future<int> _runWorker(_End end) async {
  final replies = ReceivePort();
  final exit = ReceivePort();
  final loaded = Completer<int>();
  replies.listen((memory) => loaded.complete(memory as int));
  final isolate = await Isolate.spawn(_worker, [replies.sendPort, _library!, _modelDir!, end.index],
      onExit: exit.sendPort, errorsAreFatal: true);
  final memory = await loaded.future.timeout(const Duration(minutes: 2));
  if (end == _End.kill) isolate.kill(priority: Isolate.immediate);
  await exit.first.timeout(const Duration(minutes: 1));
  replies.close();
  return memory;
}

String _mb(int bytes) => '${(bytes / (1 << 20)).toStringAsFixed(0)} MB';

void main() {
  group('SherpaSttEngine native release (host)', skip: _skip, () {
    setUpAll(() async {
      // The first loads open the library and grow the allocators' pools once per process.
      await _runWorker(_End.dispose);
      await _runWorker(_End.dispose);
    });

    for (final end in _End.values) {
      final how = switch (end) {
        _End.dispose => 'disposes and then exits',
        _End.exit => 'exits without dispose',
        _End.kill => 'is killed without dispose',
      };
      test('a worker that $how frees the recognizer, and nothing twice', () async {
        final before = processMemory();
        final loaded = await _runWorker(end);
        final after = processMemory();
        // ignore: avoid_print
        print('${end.name}: footprint before ${_mb(before)}, loaded ${_mb(loaded)}, after ${_mb(after)}');
        expect(loaded - before, greaterThan(_minimumLoadBytes), reason: 'the recognizer did not load');
        // Without the release the whole recognizer stays. With it, one load and end measured
        // 2 to 60 MB, at times 160 to 205 MB, after an explicit dispose too: the allocations
        // sherpa-onnx and onnxruntime keep. Half of what the load added separates the two.
        expect(after - before, lessThan((loaded - before) ~/ 2));
      }, timeout: const Timeout(Duration(minutes: 5)));
    }
  });
}
