import 'dart:async';
import 'dart:convert';
import 'dart:typed_data' show BytesBuilder;
import 'dart:math' show min;

import 'native/llama_backend.dart';

/// Thrown before anything is decoded when a prompt and its output cap do not fit the context.
class LlmPromptTooLongException implements Exception {
  final int promptTokens;
  final int maxOutputTokens;
  final int contextSize;

  const LlmPromptTooLongException(this.promptTokens, this.maxOutputTokens, this.contextSize);

  @override
  String toString() => 'LlmPromptTooLongException: $promptTokens prompt tokens plus up to $maxOutputTokens '
      'output tokens do not fit the context of $contextSize tokens.';
}

/// One prompt's reply and how it was produced.
class LlmGenerationResult {
  final String text;
  final int promptTokens;

  /// Prompt tokens whose memory was kept from the previous prompt instead of decoded again.
  final int reusedPromptTokens;
  final int outputTokens;

  /// Time spent tokenizing and decoding the prompt.
  final int readMs;

  /// Time spent generating the reply.
  final int writeMs;

  /// True when the output cap ended the reply before the model ended it.
  final bool hitOutputCap;

  /// True when a stop request ended the prompt; [text] is then incomplete.
  final bool stopped;

  const LlmGenerationResult({
    required this.text,
    required this.promptTokens,
    required this.reusedPromptTokens,
    required this.outputTokens,
    required this.readMs,
    required this.writeMs,
    required this.hitOutputCap,
    required this.stopped,
  });
}

/// Runs one prompt at a time over a [LlamaBackend] (IMPLEMENTATION.md 4.D, "The loop").
///
/// The prompt is decoded in chunks of `C = backend.batchSize` tokens at the aligned positions
/// `[0, C) [C, 2C) …`. Between prompts the loop remembers the prompt tokens whose memory is
/// valid and keeps `floor(common / C) · C` of them, where `common` is the shared token prefix:
/// every kept chunk was computed exactly as a cold run computes it, so the reply is the cold
/// reply. Generated tokens are never remembered.
class LlmGenerationLoop {
  final LlamaBackend _backend;

  /// When false every prompt is decoded from position 0.
  final bool reusePromptPrefix;

  /// Prompt tokens at positions `0 … length - 1` whose memory is valid.
  List<int> _remembered = const [];

  LlmGenerationLoop(this._backend, {required this.reusePromptPrefix});

  /// Generates the reply to [prompt]: at most [maxOutputTokens] tokens, constrained by the GBNF
  /// [grammar] when given. [stopRequested] is read after every decoded chunk and every generated
  /// token, each time after returning to the event loop.
  ///
  /// Throws [LlmPromptTooLongException] before decoding anything when the prompt and the cap do
  /// not fit the context. Any backend failure forgets the remembered tokens and clears the
  /// memory before it is rethrown.
  Future<LlmGenerationResult> run(
    String prompt, {
    required int maxOutputTokens,
    String? grammar,
    required bool Function() stopRequested,
  }) async {
    final watch = Stopwatch()..start();
    final List<int> tokens;
    try {
      tokens = _backend.tokenize(prompt);
    } catch (_) {
      _forget();
      rethrow;
    }
    if (tokens.isEmpty) throw ArgumentError.value(prompt, 'prompt', 'has no tokens');
    if (tokens.length + maxOutputTokens > _backend.contextSize) {
      throw LlmPromptTooLongException(tokens.length, maxOutputTokens, _backend.contextSize);
    }
    try {
      return await _generate(tokens, maxOutputTokens, grammar, stopRequested, watch);
    } catch (_) {
      _forget();
      rethrow;
    }
  }

  Future<LlmGenerationResult> _generate(
    List<int> tokens,
    int maxOutputTokens,
    String? grammar,
    bool Function() stopRequested,
    Stopwatch watch,
  ) async {
    final chunk = _backend.batchSize;
    // The final chunk is always decoded: it produces the logits of the last prompt token.
    final finalChunkStart = (tokens.length - 1) ~/ chunk * chunk;
    final keep = reusePromptPrefix ? min(_commonPrefix(_remembered, tokens) ~/ chunk * chunk, finalChunkStart) : 0;

    // Before the memory changes, so a grammar that does not parse costs no reading.
    _backend.startSampler(grammar: grammar);
    _backend.truncateMemory(keep);
    _remembered = tokens.sublist(0, keep);

    LlmGenerationResult result({required String text, required int output, required int readMs, bool cap = false, bool stopped = false}) =>
        LlmGenerationResult(
          text: text,
          promptTokens: tokens.length,
          reusedPromptTokens: keep,
          outputTokens: output,
          readMs: readMs,
          writeMs: watch.elapsedMilliseconds - readMs,
          hitOutputCap: cap,
          stopped: stopped,
        );

    for (var start = keep; start < tokens.length; start += chunk) {
      final end = min(start + chunk, tokens.length);
      _backend.decode(tokens.sublist(start, end), start, logitsForLast: end == tokens.length);
      _remembered = tokens.sublist(0, end);
      await Future<void>.delayed(Duration.zero);
      if (stopRequested()) return result(text: '', output: 0, readMs: watch.elapsedMilliseconds, stopped: true);
    }
    final readMs = watch.elapsedMilliseconds;

    final bytes = BytesBuilder(copy: false);
    var output = 0;
    var position = tokens.length;
    while (true) {
      final token = _backend.sample();
      if (_backend.isEndOfGeneration(token)) break;
      if (output == maxOutputTokens) {
        return result(text: _text(bytes), output: output, readMs: readMs, cap: true);
      }
      bytes.add(_backend.tokenBytes(token));
      output++;
      _backend.decode([token], position++, logitsForLast: true);
      await Future<void>.delayed(Duration.zero);
      if (stopRequested()) return result(text: _text(bytes), output: output, readMs: readMs, stopped: true);
    }
    return result(text: _text(bytes), output: output, readMs: readMs);
  }

  static String _text(BytesBuilder bytes) => utf8.decode(bytes.toBytes(), allowMalformed: true);

  static int _commonPrefix(List<int> a, List<int> b) {
    final n = min(a.length, b.length);
    var i = 0;
    while (i < n && a[i] == b[i]) {
      i++;
    }
    return i;
  }

  void _forget() {
    _remembered = const [];
    try {
      _backend.truncateMemory(0);
    } catch (_) {}
  }
}
