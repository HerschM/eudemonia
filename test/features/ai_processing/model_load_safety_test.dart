import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_item.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_service.dart';
import 'package:eudemonia/features/ai_processing/model_file_validator.dart';
import 'package:eudemonia/features/ai_processing/model_lifecycle_manager.dart';
import 'package:eudemonia/features/ai_processing/model_load_guard.dart';
import 'package:eudemonia/features/ai_processing/stt_service.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';

/// Lifecycle-enforcing double. `dieDuringLoad` models the native runtime aborting
/// the process: the load never returns, so nothing after it runs.
class FakeSTTService implements STTService {
  @override
  bool isInitialized = false;
  int initializeCalls = 0;
  bool dieDuringLoad = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> initialize(String modelDir) async {
    initializeCalls++;
    if (dieDuringLoad) throw _ProcessDied();
    isInitialized = true;
  }

  @override
  Future<String> transcribe(String audioFilePath) async {
    if (!isInitialized) throw StateError('STT Service not initialized');
    return 'A thought';
  }

  @override
  void dispose() => isInitialized = false;
}

class _ProcessDied extends Error {}

/// Minimal well-formed ONNX-shaped protobuf: ir_version (field 1) + producer_name (field 2)
/// + a length-delimited graph (field 7) of [graphBytes] bytes.
Uint8List onnxBytes({int graphBytes = 4096}) {
  final builder = BytesBuilder();
  builder.add([0x08, 0x08]);
  builder.add([0x12, 0x04, ...'test'.codeUnits]);
  builder.addByte(0x3A);
  int remaining = graphBytes;
  while (remaining >= 0x80) {
    builder.addByte((remaining & 0x7F) | 0x80);
    remaining >>= 7;
  }
  builder.addByte(remaining);
  builder.add(List<int>.generate(graphBytes, (i) => (i * 31 + 7) & 0xFF));
  return builder.toBytes();
}

void main() {
  late Directory dir;
  const validator = ModelFileValidator();

  Future<String> write(String name, List<int> bytes) async {
    final file = File('${dir.path}/$name');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// Lays down a complete, valid model directory.
  Future<void> installValidModels() async {
    for (final name in ['encoder', 'decoder', 'joiner']) {
      await write('parakeet/$name.int8.onnx', onnxBytes());
    }
    await write('parakeet/tokens.txt', 'a 0\n'.codeUnits);
    await write('qwen2.5-1.5b.gguf', [...'GGUF'.codeUnits, 3, 0, 0, 0, 1, 2, 3, 4]);
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('model_safety_test_');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  group('ModelFileValidator ONNX integrity', () {
    test('accepts a well-formed model file', () async {
      await validator.validateOnnx(await write('ok.onnx', onnxBytes()));
    });

    test('rejects a truncated download', () async {
      final bytes = onnxBytes();
      final path = await write('truncated.onnx', bytes.sublist(0, bytes.length - 500));
      await expectLater(validator.validateOnnx(path), throwsA(isA<ModelFileException>()));
    });

    test('rejects a resumed download spliced onto an older, shorter file', () async {
      // Old revision in full, followed by the tail of a newer, longer revision.
      final oldRevision = onnxBytes(graphBytes: 3000);
      final newRevision = onnxBytes(graphBytes: 4096);
      final spliced = [...oldRevision, ...newRevision.sublist(oldRevision.length)];
      expect(spliced.length, newRevision.length, reason: 'size alone looks correct');

      final path = await write('spliced.onnx', spliced);
      await expectLater(
        validator.validateOnnx(path),
        throwsA(isA<ModelFileException>()
            .having((e) => e.message, 'message', contains('corrupt or incomplete'))),
      );
    });

    test('rejects placeholder and non-model files', () async {
      final candidates = {
        'zeros.onnx': List<int>.filled(4096, 0),
        'empty.onnx': <int>[],
        'lfs_pointer.onnx': 'version https://git-lfs.github.com/spec/v1\noid sha256:abc\nsize 1\n'.codeUnits,
        'error_page.onnx': '<!DOCTYPE html><html><body>404 Not Found</body></html>'.codeUnits,
      };
      for (final entry in candidates.entries) {
        final path = await write(entry.key, entry.value);
        await expectLater(validator.validateOnnx(path), throwsA(isA<ModelFileException>()),
            reason: entry.key);
      }
    });

    test('reports a missing file by name', () async {
      await expectLater(
        validator.validateOnnx('${dir.path}/encoder.int8.onnx'),
        throwsA(isA<ModelFileException>()
            .having((e) => e.message, 'message', contains('encoder.int8.onnx is missing'))),
      );
    });
  });

  group('ModelFileValidator full model set', () {
    test('accepts a complete valid set', () async {
      await installValidModels();
      await validator.validate(
        ModelFiles(sttModelDir: '${dir.path}/parakeet', llmModelPath: '${dir.path}/qwen2.5-1.5b.gguf'),
      );
    });

    test('rejects LLM weights without the GGUF header', () async {
      await installValidModels();
      await write('qwen2.5-1.5b.gguf', List<int>.filled(1024, 0));
      await expectLater(
        validator.validate(
          ModelFiles(sttModelDir: '${dir.path}/parakeet', llmModelPath: '${dir.path}/qwen2.5-1.5b.gguf'),
        ),
        throwsA(isA<ModelFileException>().having((e) => e.message, 'message', contains('Language model'))),
      );
    });

    test('rejects a set without tokens.txt', () async {
      await installValidModels();
      await File('${dir.path}/parakeet/tokens.txt').delete();
      await expectLater(
        validator.validate(
          ModelFiles(sttModelDir: '${dir.path}/parakeet', llmModelPath: '${dir.path}/qwen2.5-1.5b.gguf'),
        ),
        throwsA(isA<ModelFileException>().having((e) => e.message, 'message', contains('tokens.txt'))),
      );
    });
  });

  group('Model loading is safe against bad files and native crashes', () {
    late FakeSTTService stt;
    late File marker;

    /// A new manager over the same marker file models a fresh process after a restart.
    ModelLifecycleManager newProcess() => ModelLifecycleManager(
          stt,
          modelsDirResolver: () async => dir.path,
          fileValidator: validator,
          loadGuard: ModelLoadGuard(markerResolver: () async => marker),
        );

    setUp(() {
      stt = FakeSTTService();
      marker = File('${dir.path}/model_load_in_progress');
    });

    test('a corrupt model file fails the load without ever reaching the native runtime', () async {
      await installValidModels();
      final bytes = onnxBytes();
      await write('parakeet/encoder.int8.onnx', bytes.sublist(0, bytes.length - 100));
      final manager = newProcess();

      await expectLater(manager.ensureModelsLoaded(), throwsA(isA<ModelFileException>()));

      expect(stt.initializeCalls, 0);
      expect(manager.state, ModelLifecycleState.unloaded);
      expect(await marker.exists(), isFalse);
    });

    test('a missing or corrupt GGUF cannot block speech loading', () async {
      await installValidModels();
      await File('${dir.path}/qwen2.5-1.5b.gguf').delete();
      final manager = newProcess();
      await manager.ensureModelsLoaded();
      expect(manager.state, ModelLifecycleState.ready);
      manager.dispose();

      await write('qwen2.5-1.5b.gguf', List<int>.filled(1024, 0));
      final again = newProcess();
      await again.ensureModelsLoaded();
      expect(again.state, ModelLifecycleState.ready);
      again.dispose();
    });

    test('a successful load leaves no crash marker behind', () async {
      await installValidModels();
      final manager = newProcess();

      await manager.ensureModelsLoaded();

      expect(manager.state, ModelLifecycleState.ready);
      expect(await marker.exists(), isFalse);
      manager.dispose();
    });

    test('after the process dies inside a load, the next launch refuses to load the same files', () async {
      await installValidModels();
      stt.dieDuringLoad = true;
      // The native abort: this process never gets to clean up its marker.
      await marker.writeAsString(
        await ModelFiles(sttModelDir: '${dir.path}/parakeet').signature(),
      );

      final relaunched = newProcess();
      await expectLater(relaunched.ensureModelsLoaded(), throwsA(isA<ModelLoadBlockedException>()));

      expect(stt.initializeCalls, 0, reason: 'the crashing load must not be attempted again');
    });

    test('replacing the model files lifts the block automatically', () async {
      await installValidModels();
      await marker.writeAsString('signature-of-the-previous-damaged-files');

      final relaunched = newProcess();
      await relaunched.ensureModelsLoaded();

      expect(relaunched.state, ModelLifecycleState.ready);
      relaunched.dispose();
    });

    test('queue items fail with a readable reason while blocked, and Retry attempts the load again',
        () async {
      await installValidModels();
      await marker.writeAsString(
        await ModelFiles(sttModelDir: '${dir.path}/parakeet').signature(),
      );
      final manager = newProcess();
      final queue = AudioQueueService(
        stt,
        NotesRepository(),
        manager,
        storageFileResolver: () async => File('${dir.path}/queue.json'),
      );

      // Startup resume: must not crash-loop, must explain itself on the card.
      await queue.enqueue('/captures/1.wav', autoProcess: false);
      await queue.processPending();

      expect(queue.items.single.status, AudioQueueStatus.failed);
      expect(queue.items.single.errorMessage, contains('Tap Retry to try again'));
      expect(queue.items.single.errorMessage, isNot(startsWith('Exception')));
      expect(stt.initializeCalls, 0);

      // Explicit user retry lifts the block.
      await queue.retryFailed();
      await queue.processPending();

      expect(stt.initializeCalls, 1);
      expect(queue.items.single.status, AudioQueueStatus.completed);
      manager.dispose();
    });
  });
}
