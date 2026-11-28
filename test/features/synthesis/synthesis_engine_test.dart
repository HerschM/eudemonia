import 'dart:async';

import 'package:eudemonia/features/synthesis/domain/folder_definition.dart';
import 'package:eudemonia/features/synthesis/domain/note_style.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_engine.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_model_profile.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_prompts.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime(2026, 1, 1, 9);

SynthesisThought th(int id, int minutes, [String? text]) =>
    SynthesisThought(id: id, text: text ?? 'thought $id', time: _t0.add(Duration(minutes: minutes)));

/// Scripted model: [responder] returns the reply (or throws); every prompt is recorded.
class FakeModel {
  final List<String> prompts = [];
  final List<int> budgets = [];
  final List<String?> grammars = [];
  final FutureOr<SynthesisReply> Function(String prompt, int call) responder;
  FakeModel(this.responder);

  Future<SynthesisReply> call(String prompt, int maxTokens, {String? grammar}) async {
    prompts.add(prompt);
    budgets.add(maxTokens);
    grammars.add(grammar);
    return responder(prompt, prompts.length - 1);
  }
}

SynthesisReply ok(String text) => (text: text, hitOutputCap: false);

/// Answers every organise turn by labelling each thought with [folderOf] (by the thought's number in the prompt text).
SynthesisReply labelAll(String prompt, String Function(String thoughtText) folderOf) {
  final lines = RegExp(r'^(\d+)\. (.*)$', multiLine: true)
      .allMatches(prompt.split('Thoughts:\n').last)
      .map((m) => '${m[1]}: ${folderOf(m[2]!)}');
  return ok(lines.join('\n'));
}

String words(int n) => List.filled(n, 'w').join(' ');

void main() {
  group('organise', () {
    test('batches by size and by time gap, in time order', () async {
      final model = FakeModel((p, _) => labelAll(p, (_) => 'Work'));
      final engine = SynthesisEngine(generate: model.call);
      // 7 close thoughts, then one 3 hours later; given out of order.
      final input = [th(8, 300), for (var i = 7; i >= 1; i--) th(i, i)];
      await engine.organise(input, const []);
      expect(model.prompts.length, 3);
      expect(model.prompts[0], contains('1. thought 1\n2. thought 2\n3. thought 3\n4. thought 4\n5. thought 5\nAnswer:'));
      expect(model.prompts[1], contains('1. thought 6\n2. thought 7\nAnswer:'));
      expect(model.prompts[2], contains('1. thought 8\nAnswer:'));
      expect(model.budgets[0], organiseOutputBudget(5));
      // Each organise turn is bound to the reply form for its own number of thoughts.
      expect(model.grammars, [
        buildOrganiseGrammar(5, defaultFolders),
        buildOrganiseGrammar(2, defaultFolders),
        buildOrganiseGrammar(1, defaultFolders),
      ]);
    });

    test('valid replies create one plan per folder', () async {
      final model = FakeModel((p, _) => labelAll(p, (t) => t.endsWith('2') ? 'Personal' : 'Work'));
      final out = await SynthesisEngine(generate: model.call).organise([th(1, 0), th(2, 1), th(3, 2)], const []);
      expect(out.failedThoughtIds, isEmpty);
      expect(out.plans.map((p) => p.folder), ['Work', 'Personal']);
      expect(out.plans[0].thoughts.map((t) => t.id), [1, 3]);
      expect(out.plans[0].existingSessionId, isNull);
      expect(out.plans[0].currentNote, isNull);
      expect(out.plans[1].newThoughts.map((t) => t.id), [2]);
    });

    test('joins an existing session of the same folder inside the window', () async {
      final model = FakeModel((p, _) => labelAll(p, (_) => 'Work'));
      final existing = ExistingSession(id: 's1', folder: 'Work', note: 'Old note.', thoughts: [th(1, 0), th(2, 20)]);
      final out = await SynthesisEngine(generate: model.call).organise([th(3, 60)], [existing]);
      expect(out.plans, hasLength(1));
      final plan = out.plans.single;
      expect(plan.existingSessionId, 's1');
      expect(plan.currentNote, 'Old note.');
      expect(plan.thoughts.map((t) => t.id), [1, 2, 3]);
      expect(plan.newThoughts.map((t) => t.id), [3]);
      expect(model.prompts.single, contains('[Work] Old note.'));
    });

    test('a thought in the middle of an existing session joins it', () async {
      final model = FakeModel((p, _) => labelAll(p, (_) => 'Work'));
      final existing = ExistingSession(id: 's1', folder: 'Work', note: 'N', thoughts: [th(1, 0), th(2, 100)]);
      final out = await SynthesisEngine(generate: model.call).organise([th(3, 50)], [existing]);
      expect(out.plans.single.existingSessionId, 's1');
      expect(out.plans.single.thoughts.map((t) => t.id), [1, 3, 2]);
    });

    test('a 46 minute gap or a 2 hour span starts a new session', () async {
      final model = FakeModel((p, _) => labelAll(p, (_) => 'Work'));
      final gap = ExistingSession(id: 'a', folder: 'Work', note: 'N', thoughts: [th(1, 0)]);
      var out = await SynthesisEngine(generate: model.call).organise([th(2, 46)], [gap]);
      expect(out.plans.single.existingSessionId, isNull);
      expect(model.prompts.single, isNot(contains('Notes already in progress')));

      final span = ExistingSession(id: 'b', folder: 'Work', note: 'N', thoughts: [th(1, 0), th(2, 40), th(3, 80), th(4, 119)]);
      out = await SynthesisEngine(generate: model.call).organise([th(5, 120)], [span]);
      expect(out.plans.single.existingSessionId, isNull);
      // 45 minutes exactly still joins.
      out = await SynthesisEngine(generate: model.call).organise([th(6, 45)], [gap]);
      expect(out.plans.single.existingSessionId, 'a');
    });

    test('context holds only joinable sessions and truncates to 60 words', () async {
      final model = FakeModel((p, _) => labelAll(p, (_) => 'Work'));
      final near = ExistingSession(id: 'n', folder: 'Personal', note: '', thoughts: [th(1, 0, 'alpha beta'), th(2, 1, 'gamma')]);
      final far = ExistingSession(id: 'f', folder: 'Journal', note: 'Far note.', thoughts: [th(3, -600)]);
      final long = ExistingSession(id: 'l', folder: 'Work', note: List.generate(70, (i) => 'x$i').join(' '), thoughts: [th(4, 2)]);
      await SynthesisEngine(generate: model.call).organise([th(9, 10)], [near, far, long]);
      final p = model.prompts.single;
      expect(p, contains('[Personal] alpha beta gamma'));
      expect(p, isNot(contains('Far note.')));
      expect(p, contains('x59…'));
      expect(p, isNot(contains('x60')));
    });

    test('sessions formed in batch 1 are context for batch 2', () async {
      final model = FakeModel((p, _) => labelAll(p, (_) => 'Journal'));
      final input = [for (var i = 1; i <= 6; i++) th(i, i)];
      final out = await SynthesisEngine(generate: model.call).organise(input, const []);
      expect(model.prompts[0], isNot(contains('Notes already in progress')));
      expect(model.prompts[1], contains('[Journal] thought 1 thought 2 thought 3 thought 4 thought 5'));
      expect(out.plans, hasLength(1));
      expect(out.plans.single.newThoughts, hasLength(6));
    });

    test('an invalid reply splits the batch and never resends an identical prompt', () async {
      final model = FakeModel((p, _) {
        final n = RegExp(r'^\d+\. ', multiLine: true).allMatches(p.split('Thoughts:\n').last).length;
        return n > 2 ? ok('garbage') : labelAll(p, (_) => 'Work');
      });
      final input = [for (var i = 1; i <= 5; i++) th(i, i)];
      final out = await SynthesisEngine(generate: model.call).organise(input, const []);
      expect(model.prompts.toSet().length, model.prompts.length);
      expect(model.prompts[1], contains('1. thought 1\n2. thought 2\n3. thought 3\nAnswer:'));
      expect(out.failedThoughtIds, isEmpty);
      expect(out.plans.single.newThoughts.map((t) => t.id), [1, 2, 3, 4, 5]);
    });

    test('a single unanswerable thought is failed while the others succeed', () async {
      final model = FakeModel((p, _) {
        final body = p.split('Thoughts:\n').last;
        final n = RegExp(r'^\d+\. ', multiLine: true).allMatches(body).length;
        return n > 1 || body.contains('thought 2') ? ok('nope') : labelAll(p, (_) => 'Work');
      });
      final out = await SynthesisEngine(generate: model.call).organise([th(1, 1), th(2, 2), th(3, 3)], const []);
      expect(out.failedThoughtIds, [2]);
      expect(out.plans.single.newThoughts.map((t) => t.id), [1, 3]);
    });

    test('hitOutputCap and TimeoutException count as invalid', () async {
      final capped = FakeModel((p, _) => (text: '1: Work', hitOutputCap: true));
      var out = await SynthesisEngine(generate: capped.call).organise([th(1, 1)], const []);
      expect(out.failedThoughtIds, [1]);
      expect(out.plans, isEmpty);

      final timeout = FakeModel((p, _) => throw TimeoutException('slow'));
      out = await SynthesisEngine(generate: timeout.call).organise([th(1, 1), th(2, 2)], const []);
      expect(out.failedThoughtIds, [1, 2]);
      expect(timeout.prompts.length, 3);
    });

    test('every rejected organise reply is reported with its thought ids and a one-line reason', () async {
      final rejected = <String>[];
      final model = FakeModel((p, call) {
        final n = RegExp(r'^\d+\. ', multiLine: true).allMatches(p.split('Thoughts:\n').last).length;
        if (n == 2) return ok('Sure!\nHere you go');
        return p.contains('thought 2') ? (text: '1: Work and more', hitOutputCap: true) : labelAll(p, (_) => 'Work');
      });
      final out = await SynthesisEngine(
        generate: model.call,
        onRejected: (kind, ids, reason) => rejected.add('$kind $ids $reason'),
      ).organise([th(1, 1), th(2, 2)], const []);
      expect(out.failedThoughtIds, [2]);
      expect(rejected, [
        'organise [1, 2] not in the expected form: "Sure! Here you go"',
        'organise [2] reached the output limit: "1: Work and more"',
      ]);
    });

    test('other exceptions propagate', () {
      final model = FakeModel((p, _) => throw StateError('engine fault'));
      expect(SynthesisEngine(generate: model.call).organise([th(1, 1)], const []), throwsStateError);
    });

    test('uses the profile chat format and folders', () async {
      final model = FakeModel((p, _) => labelAll(p, (_) => 'Work'));
      const profile = SynthesisModelProfile(
        modelFileName: 'x.gguf',
        chatFormat: ChatFormat.llama3,
        noteStyle: NoteStyle.cleanUp,
        organiseBatchSize: 2,
        writeWordLimit: 700,
        minOutputRatio: 0.5,
        maxOutputRatio: 1.3,
      );
      await SynthesisEngine(generate: model.call, profile: profile).organise([th(1, 1), th(2, 2), th(3, 3)], const []);
      expect(model.prompts, hasLength(2));
      expect(model.prompts.first, startsWith('<|start_header_id|>system'));
      expect(model.grammars, [buildOrganiseGrammar(2, defaultFolders), buildOrganiseGrammar(1, defaultFolders)]);
    });
  });

  group('write', () {
    SessionPlan plan(List<SynthesisThought> all, {List<SynthesisThought>? added, String? note}) => SessionPlan(
          existingSessionId: note == null ? null : 's',
          folder: 'Work',
          currentNote: note,
          thoughts: all,
          newThoughts: added ?? all,
        );

    test('a single turn under the word limit replaces the note', () async {
      final model = FakeModel((p, _) => ok('  The note.  '));
      final all = [th(1, 0, 'one two three'), th(2, 1, 'four five')];
      final result = await SynthesisEngine(generate: model.call).write(plan(all, added: [all[1]], note: 'Old.'));
      expect(result, 'The note.');
      expect(model.prompts.single, buildWritePrompt(['one two three', 'four five']));
      expect(model.budgets.single, writeOutputBudget(5));
      // A note is free text: no grammar.
      expect(model.grammars.single, isNull);
    });

    test('over the limit with an existing note writes only the new thoughts and appends', () async {
      final model = FakeModel((p, _) => ok('New part.'));
      final all = [th(1, 0, words(700)), th(2, 1, 'fresh idea')];
      final result = await SynthesisEngine(generate: model.call).write(plan(all, added: [all[1]], note: 'Old note.'));
      expect(result, 'Old note.\n\nNew part.');
      expect(model.prompts.single, buildWritePrompt(['fresh idea']));
    });

    test('over the limit without a note writes pieces and joins them', () async {
      final model = FakeModel((p, i) {
        final inputWords = i == 0 ? 400 : 400;
        return ok(words(inputWords));
      });
      final all = [th(1, 0, words(400)), th(2, 1, words(400)), th(3, 2, words(100))];
      final result = await SynthesisEngine(generate: model.call).write(plan(all));
      // Pieces: [1], [2, 3] (400 + 100 <= 700).
      expect(model.prompts, hasLength(2));
      expect(result, '${words(400)}\n\n${words(400)}');
    });

    test('a thought longer than the limit is its own piece', () async {
      final model = FakeModel((p, _) => ok(words(750)));
      final all = [th(1, 0, words(750)), th(2, 1, 'short')];
      final engine = SynthesisEngine(generate: (p, b, {grammar}) => model.call(p, b, grammar: grammar));
      // 'short' piece reply of 750 words is too long for 1 input word: invalid, single thought -> null.
      expect(await engine.write(plan(all)), isNull);
      expect(model.prompts, hasLength(2));
    });

    group('a single thought longer than one write turn', () {
      // 175 sentences of 10 words: 1750 words, 2.5 times the 700-word limit of the default profile.
      final sentences = [for (var k = 0; k < 175; k++) 'Sentence $k has a few more words in it now.'];
      final long = sentences.join(' ');
      final parts = [
        sentences.sublist(0, 70).join(' '),
        sentences.sublist(70, 140).join(' '),
        sentences.sublist(140).join(' '),
      ];
      final organised = noteStyleById(defaultNoteStyleId);

      test('is written in consecutive pieces cut at sentence ends and joined in the style', () async {
        final model = FakeModel((p, i) => ok(parts[i]));
        final result = await SynthesisEngine(generate: model.call).write(plan([th(1, 0, long)]));
        expect(model.prompts, [for (final part in parts) buildWritePrompt([part])]);
        expect(result, organised.join(organised.join(parts[0], parts[1]), parts[2]));
      });

      test('keeps its place between shorter thoughts', () async {
        final texts = ['First short thought.', ...parts, 'Last short thought.'];
        final model = FakeModel((p, i) => ok(texts[i]));
        final all = [th(1, 0, texts.first), th(2, 1, long), th(3, 2, texts.last)];
        final result = await SynthesisEngine(generate: model.call).write(plan(all));
        expect(model.prompts, [for (final text in texts) buildWritePrompt([text])]);
        expect(result, texts.reduce(organised.join));
      });

      test('a failing piece fails the write and is reported with the thought id', () async {
        final rejected = <String>[];
        final model = FakeModel((p, i) => i == 1 ? ok('Too short.') : ok(parts[i]));
        final engine =
            SynthesisEngine(generate: model.call, onRejected: (kind, ids, reason) => rejected.add('$kind $ids'));
        expect(await engine.write(plan([th(7, 0, long)])), isNull);
        expect(model.prompts, hasLength(2));
        expect(rejected, ['write [7]']);
      });
    });

    test('too short, too long or empty replies are invalid and split', () async {
      for (final bad in [words(5), words(100), '   ']) {
        final model = FakeModel((p, _) {
          final isHalf = p.contains('Thoughts:\n1. ') && !p.contains('2. ');
          return isHalf ? ok(words(15)) : ok(bad);
        });
        final all = [th(1, 0, words(15)), th(2, 1, words(15))];
        // Whole piece: 30 input words -> valid range 15..69; 5 too short, 100 too long, blank empty.
        final result = await SynthesisEngine(generate: model.call).write(plan(all));
        expect(result, '${words(15)}\n\n${words(15)}', reason: 'bad reply ${bad.length}');
        expect(model.prompts, hasLength(3));
      }
    });

    test('a note that leaves a thought out is invalid and the piece is split', () async {
      const dentist = 'Call the dentist tomorrow morning and book a cleaning appointment.';
      const shoes = 'I already purchased running shoes yesterday and will order another pair.';
      final rejected = <String>[];
      final model = FakeModel((p, _) {
        if (p.contains('2. ')) return ok('- $dentist\n- Also remember the dentist cleaning appointment tomorrow.');
        return ok(p.contains(dentist) ? '- $dentist' : '- $shoes');
      });
      final engine = SynthesisEngine(generate: model.call, onRejected: (kind, ids, reason) => rejected.add('$kind $ids $reason'));
      final result = await engine.write(plan([th(1, 0, dentist), th(2, 1, shoes)]));
      expect(result, '- $dentist\n\n- $shoes');
      expect(model.prompts, hasLength(3));
      expect(rejected.single, 'write [1, 2] the note leaves out thought(s) [2]');
    });

    test('the minimum ratio is not applied below 30 input words', () async {
      final model = FakeModel((p, _) => ok('Ok.'));
      expect(await SynthesisEngine(generate: model.call).write(plan([th(1, 0, words(20))])), 'Ok.');
    });

    test('a single failing thought makes write return null', () async {
      final model = FakeModel((p, _) => (text: 'cut off', hitOutputCap: true));
      expect(await SynthesisEngine(generate: model.call).write(plan([th(1, 0)])), isNull);
      final timeout = FakeModel((p, _) => throw TimeoutException('slow'));
      expect(await SynthesisEngine(generate: timeout.call).write(plan([th(1, 0)])), isNull);
    });

    test('every rejected write reply is reported with word counts, never with the text', () async {
      final rejected = <String>[];
      void report(String kind, List<int> ids, String reason) => rejected.add('$kind $ids $reason');
      final long = SynthesisThought(id: 7, text: words(40), time: DateTime(2026));
      final short = FakeModel((p, _) => ok('too short'));
      expect(await SynthesisEngine(generate: short.call, onRejected: report).write(plan([long])), isNull);
      final capped = FakeModel((p, _) => (text: 'cut off', hitOutputCap: true));
      expect(await SynthesisEngine(generate: capped.call, onRejected: report).write(plan([long])), isNull);
      final timeout = FakeModel((p, _) => throw TimeoutException('slow'));
      expect(await SynthesisEngine(generate: timeout.call, onRejected: report).write(plan([long])), isNull);
      expect(rejected, [
        'write [7] 2 words written from 40',
        'write [7] reached the output limit',
        'write [7] timed out',
      ]);
    });

    test('one half failing fails the whole write', () async {
      final model = FakeModel((p, _) => p.contains('thought 2') && !p.contains('thought 1') ? ok('') : ok(''));
      expect(await SynthesisEngine(generate: model.call).write(plan([th(1, 0), th(2, 1)])), isNull);
    });

    test('other exceptions propagate', () {
      final model = FakeModel((p, _) => throw StateError('engine fault'));
      expect(SynthesisEngine(generate: model.call).write(plan([th(1, 0)])), throwsStateError);
    });

    test('structured style uses the structured prompt and budget', () async {
      final model = FakeModel((p, _) => ok('Title\n- point'));
      const profile = SynthesisModelProfile(
        modelFileName: 'x.gguf',
        chatFormat: ChatFormat.chatml,
        noteStyle: NoteStyle.structured,
        organiseBatchSize: 5,
        writeWordLimit: 700,
        minOutputRatio: 0.5,
        maxOutputRatio: 1.3,
      );
      await SynthesisEngine(generate: model.call, profile: profile).write(plan([th(1, 0, 'a b c')]));
      expect(model.prompts.single, buildStructuredWritePrompt(['a b c']));
      expect(model.budgets.single, structuredOutputBudget(3));
    });
  });

  group('note styles', () {
    const structured = SynthesisModelProfile(
      modelFileName: 'x.gguf',
      chatFormat: ChatFormat.chatml,
      noteStyle: NoteStyle.structured,
      organiseBatchSize: 5,
      writeWordLimit: 700,
      minOutputRatio: 0.5,
      maxOutputRatio: 1.3,
    );

    SessionPlan styled(List<SynthesisThought> all, String styleId, {List<SynthesisThought>? added, String? note}) =>
        SessionPlan(
          existingSessionId: 's',
          folder: 'Work',
          currentNote: note,
          thoughts: all,
          newThoughts: added ?? all,
          styleId: styleId,
        );

    test('the parts of a split thought get the long-thought text; the short thoughts around them do not', () async {
      final sentences = [for (var k = 0; k < 175; k++) 'Sentence $k has a few more words in it now.'];
      final parts = [
        sentences.sublist(0, 70).join(' '),
        sentences.sublist(70, 140).join(' '),
        sentences.sublist(140).join(' '),
      ];
      final texts = ['First short thought.', ...parts, 'Last short thought.'];
      final model = FakeModel((p, i) => ok(texts[i]));
      final all = [th(1, 0, texts.first), th(2, 1, sentences.join(' ')), th(3, 2, texts.last)];
      final journal = noteStyleById('journal');
      final result = await SynthesisEngine(generate: model.call, profile: structured).write(styled(all, 'journal'));
      expect(model.prompts, [
        buildStyleWritePrompt([texts[0]], journal),
        for (final part in parts) buildStyleWritePrompt([part], journal, longThoughtText: true),
        buildStyleWritePrompt([texts[4]], journal),
      ]);
      expect([for (final p in model.prompts) p.contains(longThoughtRules)], [false, true, true, true, false]);
      expect(result, texts.reduce(journal.join));
    });

    // Orchestrator decision 2026-11-28: long text only for split parts or as a retry. An unsplit
    // long thought is written with the plain text first; only a reply that left something out is
    // retried, once, with the long-thought text.
    group('a long thought that is not split', () {
      List<String> numbers(int n) => [for (var i = 0; i < n; i++) '${1000 + i}'];
      final organised = noteStyleById('organised');

      SynthesisEngine engine(FakeModel model, List<String> rejected) => SynthesisEngine(
          generate: model.call, profile: structured, onRejected: (kind, ids, reason) => rejected.add('$kind $ids $reason'));

      test('is written with the plain text when its reply is valid: one call', () async {
        final thought = numbers(275).join(' ');
        final model = FakeModel((p, _) => ok(thought));
        final rejected = <String>[];
        expect(await engine(model, rejected).write(styled([th(4, 0, thought)], 'organised')), thought);
        expect(model.prompts, [buildStyleWritePrompt([thought], organised)]);
        expect(model.prompts.single, isNot(contains(longThoughtRules)));
        expect(rejected, isEmpty);
      });

      test('a reply too short is retried exactly once with the long-thought text, whose valid reply is the note', () async {
        final thought = numbers(275).join(' ');
        final model = FakeModel((p, i) => i == 0 ? ok(numbers(10).join(' ')) : ok(thought));
        final rejected = <String>[];
        expect(await engine(model, rejected).write(styled([th(4, 0, thought)], 'organised')), thought);
        expect(model.prompts, [
          buildStyleWritePrompt([thought], organised),
          buildStyleWritePrompt([thought], organised, longThoughtText: true),
        ]);
        expect(rejected, ['write [4] 10 words written from 275; retrying with the long-thought rules']);
      });

      test('a note that drops a stretch is retried; rejected twice, the turn has no note and is never tried a third time',
          () async {
        final thought = numbers(464);
        final model = FakeModel((p, _) => ok(thought.sublist(0, 232).join(' ')));
        final rejected = <String>[];
        expect(await engine(model, rejected).write(styled([th(4, 0, thought.join(' '))], 'organised')), isNull);
        expect(model.prompts, hasLength(2));
        expect(model.prompts.last, contains(longThoughtRules));
        expect(rejected, [
          'write [4] the note leaves out a stretch of thought(s) [1]; retrying with the long-thought rules',
          'write [4] the note leaves out a stretch of thought(s) [1]',
        ]);
      });

      test('a turn whose thoughts are all under longThoughtWords words is never retried', () async {
        for (final (n, calls) in [(149, 1), (150, 2)]) {
          final model = FakeModel((p, _) => ok(numbers(10).join(' ')));
          expect(await engine(model, []).write(styled([th(4, 0, numbers(n).join(' '))], 'organised')), isNull);
          expect(model.prompts, hasLength(calls), reason: '$n words');
        }
      });

      test('a rejection for the form, the output limit or a timeout is not retried', () async {
        final thought = numbers(275).join(' ');
        final heading = FakeModel((p, _) => ok('**Title**\n\n**Heading**\n- $thought'));
        expect(await engine(heading, []).write(styled([th(4, 0, thought)], 'bullets')), isNull);
        expect(heading.prompts, hasLength(1));
        final capped = FakeModel((p, _) => (text: thought, hitOutputCap: true));
        expect(await engine(capped, []).write(styled([th(4, 0, thought)], 'organised')), isNull);
        expect(capped.prompts, hasLength(1));
        final timeout = FakeModel((p, _) => throw TimeoutException('slow'));
        expect(await engine(timeout, []).write(styled([th(4, 0, thought)], 'organised')), isNull);
        expect(timeout.prompts, hasLength(1));
      });

      test('a style without a long-thought text is not retried', () async {
        // Too long for the input: rejected by the length check, but actionable has no other text.
        final model = FakeModel((p, _) => ok('**Plan**\n\n- [ ] ${numbers(500).join(' ')}'));
        final rejected = <String>[];
        expect(await engine(model, rejected).write(styled([th(4, 0, numbers(275).join(' '))], 'actionable')), isNull);
        expect(model.prompts, hasLength(1));
        expect(rejected, ['write [4] 504 words written from 275']);
      });
    });

    test('a plan is organised unless it names a style', () {
      final plan = SessionPlan(existingSessionId: null, folder: 'Work', currentNote: null, thoughts: const [], newThoughts: const []);
      expect(plan.styleId, 'organised');
    });

    test('organise carries an existing session\'s style into its plan; a new session is organised', () async {
      final model = FakeModel((p, _) => labelAll(p, (t) => t.contains('home') ? 'Personal' : 'Work'));
      final existing = ExistingSession(
          id: 's1', folder: 'Work', note: 'Old.', thoughts: [th(1, 0)], styleId: 'journal');
      final out = await SynthesisEngine(generate: model.call)
          .organise([th(2, 5, 'more work'), th(3, 6, 'clean the home')], [existing]);
      expect({for (final p in out.plans) p.folder: p.styleId}, {'Work': 'journal', 'Personal': 'organised'});
      expect(const ExistingSession(id: 'x', folder: 'Work', note: '', thoughts: []).styleId, 'organised');
    });

    test('a new session takes the default style of its folder; an unknown or hand-edit default reads as organised',
        () async {
      final model = FakeModel((p, _) => labelAll(p, (t) => t.contains('home') ? 'Personal' : 'Work'));
      const folders = [
        FolderDefinition(name: 'Work', description: 'w', defaultStyleId: 'journal'),
        FolderDefinition(name: 'Personal', description: 'p', defaultStyleId: manualStyleId),
        FolderDefinition(name: 'Uncategorized', description: 'u'),
      ];
      final existing = ExistingSession(id: 's1', folder: 'Work', note: 'Old.', thoughts: [th(1, 0)], styleId: 'bullets');
      final out = await SynthesisEngine(generate: model.call, folders: folders)
          .organise([th(2, 5, 'more work'), th(3, 6, 'clean the home'), th(4, 300, 'later work')], [existing]);
      expect([for (final p in out.plans) '${p.existingSessionId} ${p.folder} ${p.styleId}'],
          ['s1 Work bullets', 'null Personal organised', 'null Work journal']);
    });

    test('new thoughts of a hand-edited note are written alone, organised, and appended under Added later', () async {
      final model = FakeModel((p, _) => ok('**New bits**\n\n- I need to move the release to Monday.'));
      final all = [th(1, 0, 'plan the release'), th(2, 5, 'move the release to Monday')];
      final note = await SynthesisEngine(generate: model.call, profile: structured).write(
          styled(all, manualStyleId, added: [all[1]], note: '**My plan**\n\nI wrote this myself.'));
      expect(model.prompts.single, buildStyleWritePrompt(['move the release to Monday'], noteStyleById('organised')));
      expect(note, '**My plan**\n\nI wrote this myself.\n\n**Added later**\n\n- I need to move the release to Monday.');
    });

    test('a hand-edited note is held to the every-thought check and an invalid fragment appends nothing', () async {
      final rejected = <String>[];
      final model = FakeModel((p, _) => ok('**New**\n\n- Something else entirely.'));
      final all = [th(1, 0, 'plan'), th(2, 5, 'Call the dentist tomorrow morning about the broken crown.')];
      final note = await SynthesisEngine(
              generate: model.call, profile: structured, onRejected: (k, ids, r) => rejected.add('$k $ids $r'))
          .write(styled(all, manualStyleId, added: [all[1]], note: 'Mine.'));
      expect(note, isNull);
      expect(rejected.single, 'write [2] the note leaves out thought(s) [1]');
    });

    test('write uses the prompt of the plan\'s style', () async {
      for (final style in noteStyles) {
        final model = FakeModel((p, _) => ok('**T**\n\n- a b c'));
        await SynthesisEngine(generate: model.call, profile: structured).write(styled([th(1, 0, 'a b c')], style.id));
        expect(model.prompts.single, buildStyleWritePrompt(['a b c'], style), reason: style.id);
        expect(model.prompts.single, contains(style.systemPrompt), reason: style.id);
        expect(model.budgets.single, structuredOutputBudget(3), reason: style.id);
      }
    });

    test('the small-model clean-up prompt is kept for organised notes only', () async {
      final organised = FakeModel((p, _) => ok('A b c.'));
      await SynthesisEngine(generate: organised.call).write(styled([th(1, 0, 'a b c')], 'organised'));
      expect(organised.prompts.single, buildWritePrompt(['a b c']));
      final journal = FakeModel((p, _) => ok('**T**\n\nA b c.'));
      await SynthesisEngine(generate: journal.call).write(styled([th(1, 0, 'a b c')], 'journal'));
      expect(journal.prompts.single, buildStyleWritePrompt(['a b c'], noteStyleById('journal')));
    });

    test('a reply that breaks its style\'s form is rejected with the style named, never the text', () async {
      final rejected = <String>[];
      final model = FakeModel((p, _) => ok('**Day**\n\n**Errands**\n- I went to the market.'));
      final engine = SynthesisEngine(
          generate: model.call, profile: structured, onRejected: (k, ids, r) => rejected.add('$k $ids $r'));
      expect(await engine.write(styled([th(1, 0, 'I went to the market.')], 'bullets')), isNull);
      expect(rejected.single, startsWith('write [1] not in the Key points form: '));
      expect(rejected.single, isNot(contains('market')));
      // The same reply is a valid organised note.
      expect(await engine.write(styled([th(1, 0, 'I went to the market.')], 'organised')), isNotNull);
    });

    test('actionable notes are not held to every thought or to a minimum length', () async {
      final thoughts = [
        th(1, 0, 'Call the dentist tomorrow morning and book a cleaning appointment for Tuesday.'),
        th(2, 1, 'I really enjoyed the long walk along the river yesterday evening with my sister.'),
        th(3, 2, words(40)),
      ];
      final model = FakeModel((p, _) => ok('**Dentist**\n\n- [ ] Call the dentist tomorrow morning.'));
      final note = await SynthesisEngine(generate: model.call, profile: structured).write(styled(thoughts, 'actionable'));
      expect(note, '**Dentist**\n\n- [ ] Call the dentist tomorrow morning.');
      expect(model.prompts, hasLength(1));
      // The same reply as an organised note leaves thoughts out and is far too short.
      final strict = FakeModel((p, _) => ok('**Dentist**\n\n- [ ] Call the dentist tomorrow morning.'));
      expect(await SynthesisEngine(generate: strict.call, profile: structured).write(styled(thoughts, 'organised')),
          isNull);
    });

    test('a summary of a session over the write limit is invalid before any model call and is never split',
        () async {
      final rejected = <String>[];
      final model = FakeModel((p, _) => ok('**T**\n\nShort.'));
      final engine = SynthesisEngine(
          generate: model.call, profile: structured, onRejected: (k, ids, r) => rejected.add('$k $ids $r'));
      final long = styled([th(1, 0, words(400)), th(2, 1, words(400))], 'concise');
      expect(engine.unwritableReason(long), tooLongForShortSummary);
      expect(await engine.write(long), isNull);
      expect(model.prompts, isEmpty);
      expect(rejected.single, 'write [1, 2] $tooLongForShortSummary');
      // Over the limit with a note: still not appended in pieces.
      expect(await engine.write(styled(long.thoughts, 'concise', added: [long.thoughts.last], note: 'Old.')), isNull);
      expect(model.prompts, isEmpty);

      // Under the limit, a rejected summary is not retried in halves.
      final bad = FakeModel((p, _) => ok('**T**\n\n- a bullet'));
      final short = styled([th(1, 0, 'one two'), th(2, 1, 'three four')], 'concise');
      expect(SynthesisEngine(generate: bad.call, profile: structured).unwritableReason(short), isNull);
      expect(await SynthesisEngine(generate: bad.call, profile: structured).write(short), isNull);
      expect(bad.prompts, hasLength(1));
    });

    test('pieces of a long session written in a style other than organised join into one titled note', () async {
      var n = 0;
      final model = FakeModel((p, _) {
        n++;
        return ok('**Part $n**\n\n${words(250)} sentence.');
      });
      final all = [th(1, 0, words(400)), th(2, 1, words(400))];
      final note = await SynthesisEngine(generate: model.call, profile: structured).write(styled(all, 'journal'));
      expect(model.prompts, hasLength(2));
      expect('**'.allMatches(note!).length, 2, reason: 'one title');
      expect(note, startsWith('**Part 1**\n\n'));
      expect(note, isNot(contains('Part 2')));
    });

    test('new thoughts appended to a long styled note do not add a second title', () async {
      final model = FakeModel((p, _) => ok('**New**\n\n- [ ] Buy milk.'));
      final all = [th(1, 0, words(700)), th(2, 1, 'buy milk')];
      final note = await SynthesisEngine(generate: model.call, profile: structured)
          .write(styled(all, 'actionable', added: [all[1]], note: '**Old**\n\n- [ ] Call Ana.'));
      expect(note, '**Old**\n\n- [ ] Call Ana.\n\n- [ ] Buy milk.');
    });
  });

  group('splitAtSentenceEnds', () {
    List<String> wordsOf(String text) => text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    test('cuts at the last sentence end that keeps a part within the limit', () {
      expect(splitAtSentenceEnds('a b c d e. f g h i j k l? m n!', 10), ['a b c d e.', 'f g h i j k l? m n!']);
    });

    test('a sentence longer than the limit is cut at the limit and the rest runs on', () {
      expect(splitAtSentenceEnds('one two three four five six seven. eight', 3),
          ['one two three', 'four five six', 'seven. eight']);
    });

    test('a text within the limit is one part', () {
      expect(splitAtSentenceEnds('Just this. And that.', 4), ['Just this. And that.']);
    });

    test('no word is dropped, duplicated or moved, and no part is over the limit', () {
      final text = [
        for (var k = 0; k < 60; k++) k % 7 == 0 ? '${words(k + 3)} end$k!\n' : 'sentence $k ${words(k % 5)}? '
      ].join();
      for (final limit in [1, 4, 25, 700]) {
        final parts = splitAtSentenceEnds(text, limit);
        expect(parts.expand(wordsOf).toList(), wordsOf(text), reason: 'limit $limit');
        expect(parts.every((p) => wordsOf(p).length <= limit && wordsOf(p).isNotEmpty), isTrue,
            reason: 'limit $limit');
      }
    });
  });

  group('prompt formats', () {
    test('llama3 wraps system and user turns', () {
      final prompt = buildWritePrompt(['One.'], format: ChatFormat.llama3);
      expect(prompt, startsWith('<|start_header_id|>system<|end_header_id|>\n\nYou turn spoken thoughts'));
      expect(prompt, contains('<|eot_id|><|start_header_id|>user<|end_header_id|>\n\nThoughts:\n1. One.\n\nWrite the note.<|eot_id|>'));
      expect(prompt, endsWith('<|start_header_id|>assistant<|end_header_id|>\n\n'));
      expect(buildOrganisePrompt(['a'], format: ChatFormat.llama3), startsWith('<|start_header_id|>system'));
      expect(buildStructuredWritePrompt(['a'], format: ChatFormat.llama3), startsWith('<|start_header_id|>system'));
    });

    test('chatml stays the default', () {
      expect(buildWritePrompt(['One.']), startsWith('<|im_start|>system\n'));
      expect(buildWritePrompt(['One.']), buildWritePrompt(['One.'], format: ChatFormat.chatml));
      expect(buildWritePrompt(['One.']), endsWith('<|im_start|>assistant\n'));
    });

    test('default folders are exposed to the engine', () {
      expect(defaultFolders.map((f) => f.name), containsAll(['Work', 'Personal', 'Journal']));
    });
  });
}
