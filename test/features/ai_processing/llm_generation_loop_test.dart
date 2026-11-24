import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:eudemonia/features/ai_processing/llm_generation_loop.dart';
import 'package:eudemonia/features/ai_processing/native/llama_backend.dart';
import 'package:flutter_test/flutter_test.dart';

/// Token id that ends generation in [FakeBackend].
const int eog = -1;

/// One `decode` call as the fake saw it.
typedef DecodeCall = ({List<int> tokens, int start, bool logitsForLast});

/// Scripted backend. A prompt is tokenized as its space-separated integers. [replies] feeds
/// `sample` one token at a time (then [eog] forever); token `t` renders as the bytes of `t<t>`
/// unless [bytesOf] says otherwise. Throws when used before `startSampler` or after dispose.
class FakeBackend implements LlamaBackend {
  @override
  final int contextSize;
  @override
  final int batchSize;

  final List<DecodeCall> decodes = [];
  final List<int> truncations = [];
  final List<String?> grammars = [];
  final Map<int, List<int>> bytesOf = {};
  List<int> replies = [];
  int sampled = 0;

  /// When set, the decode call with this index (0-based, over the fake's life) throws.
  int? failDecodeAt;
  bool _samplerReady = false;
  bool _disposed = false;

  FakeBackend({this.contextSize = 4096, this.batchSize = 64});

  void _check() {
    if (_disposed) throw StateError('FakeBackend used after dispose');
  }

  /// Prompt decodes only (more than one token, or with no logits).
  List<DecodeCall> get promptDecodes => decodes.where((d) => d.tokens.length > 1 || !d.logitsForLast).toList();

  @override
  List<int> tokenize(String text) {
    _check();
    return [for (final t in text.split(' ')) if (t.isNotEmpty) int.parse(t)];
  }

  @override
  void truncateMemory(int position) {
    _check();
    truncations.add(position);
  }

  @override
  void decode(List<int> tokens, int start, {required bool logitsForLast}) {
    _check();
    if (tokens.isEmpty || tokens.length > batchSize) throw ArgumentError('bad chunk of ${tokens.length}');
    final index = decodes.length;
    decodes.add((tokens: List.of(tokens), start: start, logitsForLast: logitsForLast));
    if (failDecodeAt == index) throw StateError('llama_decode returned -3');
  }

  @override
  void startSampler({String? grammar}) {
    _check();
    grammars.add(grammar);
    _samplerReady = true;
  }

  @override
  int sample() {
    _check();
    if (!_samplerReady) throw StateError('FakeBackend.sample before startSampler');
    final i = sampled++;
    return i < replies.length ? replies[i] : eog;
  }

  @override
  bool isEndOfGeneration(int token) {
    _check();
    return token == eog;
  }

  @override
  Uint8List tokenBytes(int token) {
    _check();
    return Uint8List.fromList(bytesOf[token] ?? utf8.encode('t$token'));
  }

  @override
  void setThreads({required int reading, required int writing}) => _check();

  @override
  void dispose() => _disposed = true;
}

/// A prompt of the tokens `from, from + 1, …` ([count] of them).
String prompt(int count, {int from = 1000}) => [for (var i = 0; i < count; i++) from + i].join(' ');

void main() {
  late FakeBackend backend;
  late LlmGenerationLoop loop;

  setUp(() {
    backend = FakeBackend();
    loop = LlmGenerationLoop(backend, reusePromptPrefix: true);
  });

  Future<LlmGenerationResult> run(String p, {int cap = 100, String? grammar, bool Function()? stop}) =>
      loop.run(p, maxOutputTokens: cap, grammar: grammar, stopRequested: stop ?? () => false);

  group('reading', () {
    test('the prompt is decoded in position-aligned chunks with logits for its last token only', () async {
      await run(prompt(150));
      final chunks = backend.promptDecodes;
      expect([for (final d in chunks) (d.start, d.tokens.length)], [(0, 64), (64, 64), (128, 22)]);
      expect([for (final d in chunks) d.logitsForLast], [false, false, true]);
      expect(chunks[1].tokens.first, 1064);
      expect(backend.truncations, [0]);
    });

    test('a prompt of exactly one chunk is one decode with logits', () async {
      await run(prompt(64));
      expect([for (final d in backend.promptDecodes) (d.start, d.tokens.length, d.logitsForLast)], [(0, 64, true)]);
    });

    test('a prompt that does not fit with its output cap fails before anything is decoded', () async {
      backend = FakeBackend(contextSize: 128);
      loop = LlmGenerationLoop(backend, reusePromptPrefix: true);
      // 100 prompt tokens + 28 output tokens fill the 128 exactly.
      await expectLater(run(prompt(100), cap: 28), completes);
      backend.decodes.clear();
      backend.truncations.clear();
      backend.grammars.clear();
      await expectLater(run(prompt(100), cap: 29), throwsA(isA<LlmPromptTooLongException>()));
      expect(backend.decodes, isEmpty);
      expect(backend.truncations, isEmpty);
      expect(backend.grammars, isEmpty);
    });

    test('the sampler is started fresh for every prompt with the given grammar', () async {
      await run(prompt(10), grammar: 'root ::= "a"');
      await run(prompt(10));
      expect(backend.grammars, ['root ::= "a"', null]);
    });
  });

  group('prefix reuse', () {
    test('only whole chunks of the shared prefix are kept (common 130, chunk 64 keeps 128)', () async {
      await run(prompt(200));
      backend.decodes.clear();
      // Shares the first 130 tokens, then differs.
      final next = '${prompt(130)} ${prompt(170, from: 5000)}';
      final r = await run(next);
      expect(backend.truncations.last, 128);
      expect(r.reusedPromptTokens, 128);
      expect(r.promptTokens, 300);
      expect([for (final d in backend.promptDecodes) (d.start, d.tokens.length)], [(128, 64), (192, 64), (256, 44)]);
      expect(backend.promptDecodes.first.tokens.first, 1128);
    });

    test('a shared prefix shorter than one chunk keeps nothing', () async {
      await run(prompt(200));
      final r = await run('${prompt(63)} ${prompt(100, from: 5000)}');
      expect(backend.truncations.last, 0);
      expect(r.reusedPromptTokens, 0);
    });

    test('a fully cached prompt still decodes its final chunk', () async {
      await run(prompt(128));
      backend.decodes.clear();
      final r = await run(prompt(128));
      expect(backend.truncations.last, 64);
      expect(r.reusedPromptTokens, 64);
      expect([for (final d in backend.promptDecodes) (d.start, d.tokens.length, d.logitsForLast)], [(64, 64, true)]);
    });

    test('a fully cached prompt with a short final chunk decodes only that chunk', () async {
      await run(prompt(130));
      backend.decodes.clear();
      await run(prompt(130));
      expect(backend.truncations.last, 128);
      expect([for (final d in backend.promptDecodes) (d.start, d.tokens.length)], [(128, 2)]);
    });

    test('with reuse off every prompt is decoded from position 0', () async {
      loop = LlmGenerationLoop(backend, reusePromptPrefix: false);
      await run(prompt(200));
      backend.decodes.clear();
      final r = await run(prompt(200));
      expect(backend.truncations, [0, 0]);
      expect(r.reusedPromptTokens, 0);
      expect(backend.promptDecodes.first.start, 0);
      expect(backend.promptDecodes.length, 4);
    });

    test('generated tokens are never remembered as prompt', () async {
      backend.replies = List.generate(70, (i) => 7000 + i);
      await run(prompt(64));
      backend.decodes.clear();
      // The next prompt repeats the first prompt and its whole reply: only the prompt is kept.
      final next = '${prompt(64)} ${prompt(70, from: 7000)} ${prompt(10, from: 9000)}';
      backend.sampled = 0;
      backend.replies = [];
      final r = await run(next);
      expect(backend.truncations.last, 64);
      expect(r.reusedPromptTokens, 64);
      expect(backend.promptDecodes.first.start, 64);
    });

    test('a prompt stopped while reading keeps the chunks it decoded for the next prompt', () async {
      var chunks = 0;
      await run(prompt(300), stop: () => ++chunks == 2);
      final r = await run(prompt(300));
      expect(backend.truncations.last, 128);
      expect(r.reusedPromptTokens, 128);
    });

    test('a decode failure clears the remembered tokens and the memory', () async {
      await run(prompt(200));
      // The first decode of the next prompt fails.
      backend.failDecodeAt = backend.decodes.length;
      await expectLater(run('${prompt(200)} 1 2 3'), throwsA(isA<StateError>()));
      expect(backend.truncations.last, 0);
      backend.decodes.clear();
      final r = await run(prompt(200));
      expect(r.reusedPromptTokens, 0);
      expect(backend.promptDecodes.first.start, 0);
    });

    test('a grammar that does not parse clears the remembered tokens', () async {
      final failing = _GrammarFailingBackend();
      loop = LlmGenerationLoop(failing, reusePromptPrefix: true);
      await loop.run(prompt(200), maxOutputTokens: 4, stopRequested: () => false);
      await expectLater(loop.run(prompt(200), maxOutputTokens: 4, grammar: 'bad', stopRequested: () => false),
          throwsA(isA<FormatException>()));
      final r = await loop.run(prompt(200), maxOutputTokens: 4, stopRequested: () => false);
      expect(r.reusedPromptTokens, 0);
    });
  });

  group('writing', () {
    test('generation ends at an end-of-generation token, which is not part of the text', () async {
      backend.replies = [1, 2, 3];
      final r = await run(prompt(10), cap: 10);
      expect(r.text, 't1t2t3');
      expect(r.outputTokens, 3);
      expect(r.hitOutputCap, isFalse);
      expect(r.stopped, isFalse);
      // Each generated token is decoded at the next position, with logits.
      final writes = backend.decodes.skip(1).toList();
      expect([for (final d in writes) (d.tokens.single, d.start, d.logitsForLast)], [(1, 10, true), (2, 11, true), (3, 12, true)]);
    });

    test('the output cap ends generation with at most the cap of tokens', () async {
      backend.replies = List.filled(50, 5);
      final r = await run(prompt(10), cap: 3);
      expect(r.outputTokens, 3);
      expect(r.text, 't5t5t5');
      expect(r.hitOutputCap, isTrue);
    });

    test('a reply that ends exactly at the cap is not reported as capped', () async {
      backend.replies = [1, 2, 3];
      final r = await run(prompt(10), cap: 3);
      expect(r.outputTokens, 3);
      expect(r.hitOutputCap, isFalse);
    });

    test('a character split across two tokens is decoded once the bytes are joined', () async {
      backend.bytesOf[1] = [0x63, 0x61, 0x66, 0xC3];
      backend.bytesOf[2] = [0xA9];
      backend.replies = [1, 2];
      expect((await run(prompt(4))).text, 'café');
    });

    test('control tokens that render no bytes still count as output tokens', () async {
      backend.bytesOf[9] = [];
      backend.replies = [9, 1];
      final r = await run(prompt(4));
      expect(r.text, 't1');
      expect(r.outputTokens, 2);
    });
  });

  group('stop', () {
    test('a stop after a prompt chunk ends the prompt without sampling', () async {
      final r = await run(prompt(300), stop: () => backend.decodes.isNotEmpty);
      expect(r.stopped, isTrue);
      expect(r.outputTokens, 0);
      expect(r.text, isEmpty);
      expect(backend.decodes.length, 1);
      expect(backend.sampled, 0);
    });

    test('a stop while writing ends after the token in progress', () async {
      backend.replies = List.filled(50, 5);
      final r = await run(prompt(10), stop: () => backend.sampled == 2);
      expect(r.stopped, isTrue);
      expect(r.outputTokens, 2);
      expect(r.hitOutputCap, isFalse);
    });

    test('the loop returns to the event loop between chunks so a stop sent by a timer is honoured', () async {
      var stop = false;
      // Runs only if the loop yields; a synchronous loop would read all 20 chunks.
      Timer.run(() => stop = true);
      final r = await run(prompt(64 * 20), cap: 10, stop: () => stop);
      expect(r.stopped, isTrue);
      expect(backend.decodes.length, lessThan(20));
    });

    test('the loop returns to the event loop between generated tokens', () async {
      var stop = false;
      backend.replies = List.filled(1000, 5);
      final r = await run(prompt(10), cap: 1000, stop: () {
        if (backend.sampled == 1) Timer.run(() => stop = true);
        return stop;
      });
      expect(r.stopped, isTrue);
      expect(r.outputTokens, lessThan(1000));
    });
  });

  test('the figures count prompt, reused and output tokens', () async {
    backend.replies = [1, 2];
    final r = await run(prompt(70));
    expect(r.promptTokens, 70);
    expect(r.reusedPromptTokens, 0);
    expect(r.outputTokens, 2);
    expect(r.readMs, greaterThanOrEqualTo(0));
    expect(r.writeMs, greaterThanOrEqualTo(0));
  });
}

/// A backend whose sampler rejects every grammar, as llama.cpp does with one that does not parse.
class _GrammarFailingBackend extends FakeBackend {
  @override
  void startSampler({String? grammar}) {
    if (grammar != null) throw const FormatException('llama.cpp could not parse the grammar.');
    super.startSampler(grammar: grammar);
  }
}
