import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/ai_processing/llama_isolate_engine.dart';
import 'package:eudemonia/features/ai_processing/llm_service.dart';

// The generation behaviour (chunks, reuse, cap, end of generation, stop, failures) is tested on
// LlmGenerationLoop with a fake backend; the real library in test/native/. These tests cover the
// worker plumbing that needs no native library.
void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('llama_engine_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('sendPrompt before load throws StateError', () async {
    final engine = LlamaIsolateEngine(const LLMConfig());
    await expectLater(engine.sendPrompt('p', maxOutputTokens: 4), throwsA(isA<StateError>()));
  });

  test('a missing model file fails the load before a worker starts', () async {
    final engine = LlamaIsolateEngine(const LLMConfig());
    await expectLater(engine.load('${dir.path}/missing.gguf'), throwsA(isA<Exception>()));
    await expectLater(engine.sendPrompt('p', maxOutputTokens: 4), throwsA(isA<StateError>()));
  });

  test('a library that cannot be opened fails the load with the worker error and stops the worker', () async {
    final model = File('${dir.path}/model.gguf')..writeAsBytesSync([0]);
    final engine = LlamaIsolateEngine(const LLMConfig(), null, '${dir.path}/libllama-missing.so');
    await expectLater(
      engine.load(model.path),
      throwsA(isA<Exception>().having((e) => '$e', 'message', contains('failed to load'))),
    );
    // Nothing is left running: the engine is unusable and disposing it returns at once.
    await expectLater(engine.sendPrompt('p', maxOutputTokens: 4), throwsA(isA<StateError>()));
    await engine.dispose().timeout(const Duration(seconds: 1));
  });
}
