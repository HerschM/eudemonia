import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

class LLMResponse {
  final String correctedText;
  final String folder;

  LLMResponse({required this.correctedText, required this.folder});

  factory LLMResponse.fromJson(Map<String, dynamic> json) {
    return LLMResponse(
      correctedText: json['corrected_text'] ?? '',
      folder: json['folder'] ?? 'Uncategorized',
    );
  }
}

class LLMService {
  LlamaParent? _llama;
  bool _isInitialized = false;

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

  Future<LLMResponse> processText(String rawText) async {
    if (!_isInitialized || _llama == null) throw Exception('LLM Service not initialized');

    final systemPrompt = '''
You are an AI assistant that corrects grammar, removes filler words (ums, ahs), and categorizes thoughts.
Output strictly in JSON format: {"corrected_text": "...", "folder": "Work/Ideas/Todos/Journal"}

Raw text: "$rawText"
''';

    final buffer = StringBuffer();
    final streamSub = _llama!.stream.listen((response) {
      buffer.write(response);
    });

    String fullResponse = '';
    try {
      final promptId = await _llama!.sendPrompt(systemPrompt);
      await _llama!.completions
          .firstWhere((e) => e.promptId == promptId)
          .timeout(const Duration(seconds: 25));
      fullResponse = buffer.toString();
    } catch (e) {
      print('LLM generation error/timeout: $e');
      fullResponse = buffer.toString();
    } finally {
      await streamSub.cancel();
    }

    try {
      final jsonStart = fullResponse.indexOf('{');
      final jsonEnd = fullResponse.lastIndexOf('}');
      if (jsonStart != -1 && jsonEnd != -1) {
        final jsonStr = fullResponse.substring(jsonStart, jsonEnd + 1);
        final jsonMap = jsonDecode(jsonStr);
        return LLMResponse.fromJson(jsonMap);
      } else {
        throw FormatException('No JSON found in LLM response');
      }
    } catch (e) {
      return LLMResponse(correctedText: rawText, folder: 'Uncategorized');
    }
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
