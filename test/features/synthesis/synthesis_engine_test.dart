import 'dart:async';

import 'package:eudemonia/features/synthesis/domain/folder_definition.dart';
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
  final FutureOr<SynthesisReply> Function(String prompt, int call) responder;
  FakeModel(this.responder);

  Future<SynthesisReply> call(String prompt, int maxTokens) async {
    prompts.add(prompt);
    budgets.add(maxTokens);
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
      final engine = SynthesisEngine(generate: (p, b) => model.call(p, b));
      // 'short' piece reply of 750 words is too long for 1 input word: invalid, single thought -> null.
      expect(await engine.write(plan(all)), isNull);
      expect(model.prompts, hasLength(2));
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
