import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:eudemonia/features/ai_processing/native/llama_backend.dart';
import 'package:flutter_test/flutter_test.dart';

import 'process_memory.dart';

// Loads the real llama.cpp library in a worker isolate that ends without dispose, as when the
// Flutter engine is destroyed, and checks that the process memory returns. Run on the Mac with
// a host build of the pinned commit and any GGUF model, for example:
//   EUDEMONIA_LLAMA_LIB=<build>/bin/libllama.dylib EUDEMONIA_LLAMA_MODEL=models/qwen2.5-1.5b.gguf \
//     flutter test test/native/llama_native_release_host_test.dart
final String? _library = Platform.environment['EUDEMONIA_LLAMA_LIB'];
final String? _model = Platform.environment['EUDEMONIA_LLAMA_MODEL'];
final String? _skip = _library == null || _model == null
    ? 'Set EUDEMONIA_LLAMA_LIB (a host build of libllama) and EUDEMONIA_LLAMA_MODEL (a GGUF) '
        'to run the native release host test.'
    : null;

/// Most the memory may stay above its value before the load once the worker has ended.
/// Measured on an M-series Mac with Qwen2.5-1.5B (about 1.4 GB while loaded): see the report
/// lines this test prints.
const int _toleranceBytes = 64 << 20;

enum _End { dispose, exit, kill }

/// [message]: reply port, library, model, how the worker ends. Replies with the memory once the
/// backend is loaded and has decoded (before the dispose for [_End.dispose]).
void _worker(List<Object> message) {
  final reply = message[0] as SendPort;
  final backend = NativeLlamaBackend.load(message[2] as String,
      libraryPath: message[1] as String, contextSize: 2048, batchSize: 512);
  // Decoding allocates the compute buffers and fills the memory, as a real turn does.
  backend.decode(backend.tokenize('The quick brown fox jumps over the lazy dog.'), 0, logitsForLast: true);
  final loaded = processMemory();
  switch (_End.values[message[3] as int]) {
    case _End.dispose:
      backend.dispose();
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

/// Runs one worker to its end; returns the memory while it held the model.
Future<int> _runWorker(_End end) async {
  final replies = ReceivePort();
  final exit = ReceivePort();
  final loaded = Completer<int>();
  replies.listen((memory) => loaded.complete(memory as int));
  final isolate = await Isolate.spawn(_worker, [replies.sendPort, _library!, _model!, end.index],
      onExit: exit.sendPort, errorsAreFatal: true);
  final memory = await loaded.future.timeout(const Duration(minutes: 2));
  if (end == _End.kill) isolate.kill(priority: Isolate.immediate);
  await exit.first.timeout(const Duration(minutes: 1));
  replies.close();
  return memory;
}

String _mb(int bytes) => '${(bytes / (1 << 20)).toStringAsFixed(0)} MB';

void main() {
  group('NativeLlamaBackend native release (host)', skip: _skip, () {
    setUpAll(() async {
      // The first loads open the libraries, initialise the backend and grow the allocators'
      // pools once per process (about 210 MB on the second load); that memory is not the
      // model's and stays. After them a load and dispose returns within a few MB.
      await _runWorker(_End.dispose);
      await _runWorker(_End.dispose);
    });

    for (final end in _End.values) {
      final how = switch (end) {
        _End.dispose => 'disposes and then exits',
        _End.exit => 'exits without dispose',
        _End.kill => 'is killed without dispose',
      };
      test('a worker that $how frees the model, and nothing twice', () async {
        final before = processMemory();
        final rssBefore = ProcessInfo.currentRss;
        final loaded = await _runWorker(end);
        final after = processMemory();
        // ignore: avoid_print
        print('${end.name}: footprint before ${_mb(before)}, loaded ${_mb(loaded)}, after ${_mb(after)}; '
            'resident before ${_mb(rssBefore)}, after ${_mb(ProcessInfo.currentRss)}');
        expect(loaded - before, greaterThan(_toleranceBytes * 4), reason: 'the model did not load');
        expect(after - before, lessThan(_toleranceBytes));
      }, timeout: const Timeout(Duration(minutes: 5)));
    }
  });
}
