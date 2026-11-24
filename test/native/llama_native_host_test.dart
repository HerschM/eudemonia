import 'dart:io';

import 'package:eudemonia/features/ai_processing/llama_isolate_engine.dart';
import 'package:eudemonia/features/ai_processing/llm_service.dart';
import 'package:eudemonia/features/synthesis/domain/folder_definition.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_prompts.dart';
import 'package:flutter_test/flutter_test.dart';

// Drives the real llama.cpp library through the worker isolate, the backend and the loop.
// Run on the Mac with a host build of the pinned commit and a ChatML model, for example:
//   EUDEMONIA_LLAMA_LIB=<build>/bin/libllama.dylib EUDEMONIA_LLAMA_MODEL=models/qwen2.5-1.5b.gguf \
//     flutter test test/native/llama_native_host_test.dart
final String? _library = Platform.environment['EUDEMONIA_LLAMA_LIB'];
final String? _model = Platform.environment['EUDEMONIA_LLAMA_MODEL'];
final String? _skip = _library == null || _model == null
    ? 'Set EUDEMONIA_LLAMA_LIB (a host build of libllama) and EUDEMONIA_LLAMA_MODEL (a ChatML GGUF) '
        'to run the native host test.'
    : null;

String chatml(String system, String user) =>
    '<|im_start|>system\n$system<|im_end|>\n<|im_start|>user\n$user<|im_end|>\n<|im_start|>assistant\n';

const String _shortPrompt = 'Name three colours of a rainbow, separated by commas, and nothing else.';

/// A system text of a few hundred tokens shared by prompts A and B.
final String _sharedSystem = [
  'You answer questions about a small town called Lindholm.',
  for (var i = 1; i <= 12; i++)
    'Fact $i: the street number $i of Lindholm has ${i * 3} houses, a bakery that opens at ${5 + i % 4} '
        "o'clock and a park with ${i + 2} benches.",
  'Answer in one short sentence.',
].join('\n');

/// Over 600 tokens.
final String _longPrompt = chatml(
  [for (var i = 0; i < 40; i++) 'Paragraph $i: the quick brown fox jumps over the lazy dog near the river bank.'].join('\n'),
  'Summarise the paragraphs.',
);

const Duration _turnTimeout = Duration(minutes: 2);

void main() {
  group('NativeLlamaBackend through LlamaIsolateEngine (host)', skip: _skip, () {
    late LlamaIsolateEngine engine;

    Future<LlamaIsolateEngine> load({bool reuse = true}) async {
      final e = LlamaIsolateEngine(LLMConfig(kvCacheMaxSize: 4096, reusePromptPrefix: reuse), null, _library!);
      await e.load(_model!);
      return e;
    }

    Future<LlmPromptCompletion> ask(LlamaIsolateEngine e, String prompt, {int cap = 256, String? grammar}) async {
      final session = await e.sendPrompt(prompt, maxOutputTokens: cap, grammar: grammar);
      return session.completion.timeout(_turnTimeout);
    }

    setUp(() async => engine = await load());
    tearDown(() async => engine.dispose());

    test('a short prompt generates text and ends by itself before the cap', () async {
      final service = LLMService(
          config: const LLMConfig(kvCacheMaxSize: 4096),
          engineFactory: () => LlamaIsolateEngine(const LLMConfig(kvCacheMaxSize: 4096), null, _library!));
      await service.initialize(_model!);
      try {
        final g = await service.generate(chatml('You are a helpful assistant.', _shortPrompt), maxOutputTokens: 256);
        // ignore: avoid_print
        print('short: "${g.text}" (${g.promptTokens} prompt, ${g.outputTokens} output, read ${g.readMs} ms, '
            'write ${g.writeMs} ms, threads ${g.readingThreads}/${g.writingThreads}, cores ${g.allowedCores})');
        expect(g.text, isNotEmpty);
        expect(g.hitOutputCap, isFalse);
        expect(g.outputTokens, lessThan(256));
        expect(g.promptTokens, greaterThan(10));
      } finally {
        await service.dispose();
      }
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('the same prompt again reuses its memory and returns the identical text', () async {
      // Longer than one chunk: only whole chunks are reused.
      final prompt = chatml(_sharedSystem, 'How many benches are in the park on street number 9?');
      final cold = await ask(engine, prompt);
      final warm = await ask(engine, prompt);
      // ignore: avoid_print
      print('repeat: ${cold.promptTokens} prompt tokens, reused ${cold.reusedPromptTokens} then '
          '${warm.reusedPromptTokens}; read ${cold.readMs} then ${warm.readMs} ms');
      expect(cold.reusedPromptTokens, 0);
      expect(warm.reusedPromptTokens, greaterThan(0));
      expect(warm.reusedPromptTokens % 64, 0);
      expect(warm.text, cold.text);
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('a prompt sharing a long prefix gives the same text with reuse as on a fresh backend without', () async {
      final a = chatml(_sharedSystem, 'How many houses are on street number 4?');
      final b = chatml(_sharedSystem, 'When does the bakery on street number 7 open?');
      await ask(engine, a);
      final reused = await ask(engine, b);
      await engine.dispose();

      engine = await load(reuse: false);
      final fresh = await ask(engine, b);
      // ignore: avoid_print
      print('shared prefix: B has ${reused.promptTokens} tokens, ${reused.reusedPromptTokens} reused after A; '
          'read ${reused.readMs} ms against ${fresh.readMs} ms fresh; "${reused.text}"');
      expect(reused.reusedPromptTokens, greaterThanOrEqualTo(64));
      expect(fresh.reusedPromptTokens, 0);
      expect(reused.text, fresh.text);
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('a grammar-bound organise reply always parses, also within the organise budget', () async {
      const thoughts = [
        'Ask Priya to move the design review to Thursday.',
        'Buy oat milk and batteries on the way home.',
        'Felt calm after the long walk this morning.',
      ];
      final prompt = buildOrganisePrompt(thoughts);
      final grammar = buildOrganiseGrammar(thoughts.length, defaultFolders);
      for (final cap in [256, organiseOutputBudget(thoughts.length)]) {
        final reply = await ask(engine, prompt, cap: cap, grammar: grammar);
        // ignore: avoid_print
        print('organise (cap $cap): ${reply.text.replaceAll('\n', ' | ')} (${reply.outputTokens} tokens)');
        expect(reply.hitOutputCap, isFalse, reason: 'cap $cap');
        expect(parseOrganiseReply(reply.text, thoughts.length, defaultFolders), isNotNull, reason: reply.text);
      }
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('a stop during reading of a long prompt completes as stopped without generating', () async {
      final session = await engine.sendPrompt(_longPrompt, maxOutputTokens: 64);
      final watch = Stopwatch()..start();
      await session.stop();
      final stopped = await session.completion.timeout(_turnTimeout);
      final stopMs = watch.elapsedMilliseconds;
      expect(stopped.stopped, isTrue);
      expect(stopped.outputTokens, 0);
      expect(stopped.text, isEmpty);
      expect(stopped.promptTokens, greaterThanOrEqualTo(600));

      // The chunks decoded before the stop are what the next run of the prompt reuses.
      final full = await ask(engine, _longPrompt, cap: 1);
      // ignore: avoid_print
      print('stop: ${stopped.promptTokens} prompt tokens, stopped after $stopMs ms with ${full.reusedPromptTokens} '
          'tokens decoded; full read of the rest ${full.readMs} ms');
      expect(full.reusedPromptTokens, inInclusiveRange(64, 128));
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('dispose then a second load works', () async {
      final prompt = chatml('You are a helpful assistant.', _shortPrompt);
      final first = await ask(engine, prompt);
      await engine.dispose();
      engine = await load();
      final second = await ask(engine, prompt);
      expect(second.reusedPromptTokens, 0);
      expect(second.text, first.text);
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
