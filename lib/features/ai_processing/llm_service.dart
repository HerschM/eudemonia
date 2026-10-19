import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'note_classifier.dart';

export 'note_classifier.dart';

/// Legacy alias for NoteClassificationResult for backwards compatibility.
typedef LLMResponse = NoteClassificationResult;

class LLMService {
  LlamaParent? _llama;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  Future<void> initialize(String modelPath) async {
    if (_isInitialized) return;

    if (!await File(modelPath).exists()) {
      throw Exception('LLM model not found at $modelPath');
    }

    final loadCommand = LlamaLoad(
      path: modelPath,
      modelParams: ModelParams(),
      contextParams: ContextParams(),
      samplingParams: SamplerParams(),
    );

    _llama = LlamaParent(loadCommand);
    await _llama!.init();
    _isInitialized = true;
  }

  Future<NoteClassificationResult> processText(String rawText) async {
    if (!_isInitialized || _llama == null) {
      print('[LLMService] LLM not initialized, falling back to heuristic classifier.');
      final result = NoteClassifier.fallbackClassify(rawText, reason: 'LLM not initialized');
      result.printDebugLog();
      return result;
    }

    final prompt = NoteClassifier.buildPrompt(rawText);
    final buffer = StringBuffer();
    final streamSub = _llama!.stream.listen((response) {
      buffer.write(response);
    });

    String fullResponse = '';
    try {
      final promptId = await _llama!.sendPrompt(prompt);
      await _llama!.completions
          .firstWhere((e) => e.promptId == promptId)
          .timeout(const Duration(seconds: 25));
      fullResponse = buffer.toString();
    } catch (e) {
      print('[LLMService] LLM generation error or timeout: $e');
      fullResponse = buffer.toString();
    } finally {
      await streamSub.cancel();
    }

    final result = NoteClassifier.parseResponse(rawText, fullResponse);
    result.printDebugLog();
    return result;
  }

  void dispose() {
    _llama?.dispose();
    _llama = null;
    _isInitialized = false;
  }
}

final llmServiceProvider = Provider<LLMService>((ref) {
  return LLMService();
});
