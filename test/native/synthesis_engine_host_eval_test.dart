import 'dart:convert';
import 'dart:io';

import 'package:eudemonia/features/ai_processing/llama_isolate_engine.dart';
import 'package:eudemonia/features/ai_processing/llm_service.dart';
import 'package:eudemonia/features/synthesis/domain/note_style.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_engine.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_model_profile.dart';
import 'package:flutter_test/flutter_test.dart';

// Model evaluation on the Mac (TASK-065): runs the real SynthesisEngine — organise turns with
// the folder grammar, write turns with every reply check and split — on the real llama.cpp
// library, over thoughts exported from a phone. It measures what the app would produce with a
// candidate model, not what a bare prompt produces.
//
//   EUDEMONIA_LLAMA_LIB=<build>/bin/libllama.dylib EUDEMONIA_LLAMA_MODEL=models/eval/<model>.gguf \
//   EUDEMONIA_EVAL_THOUGHTS=<thoughts.json> EUDEMONIA_EVAL_OUT=<result.json> \
//     flutter test test/native/synthesis_engine_host_eval_test.dart
//
// thoughts.json: [{"id": 30, "text": "...", "time": "2026-11-21 11:46:17.719170"}, ...]. The
// thoughts and the result contain a user's own words: keep both out of git.
// Optional: EUDEMONIA_EVAL_WRITE_LIMIT (words per write turn, default 500),
// EUDEMONIA_EVAL_FORMAT (chatmlNoThink | chatml | llama3, default chatmlNoThink),
// EUDEMONIA_EVAL_STYLE (a note style id, default organised): every session is written in it, as
// a restyle rewrites it.
final Map<String, String> _env = Platform.environment;
final String? _library = _env['EUDEMONIA_LLAMA_LIB'];
final String? _model = _env['EUDEMONIA_LLAMA_MODEL'];
final String? _thoughts = _env['EUDEMONIA_EVAL_THOUGHTS'];
final String? _out = _env['EUDEMONIA_EVAL_OUT'];
final String? _skip = [_library, _model, _thoughts, _out].contains(null)
    ? 'Set EUDEMONIA_LLAMA_LIB, EUDEMONIA_LLAMA_MODEL, EUDEMONIA_EVAL_THOUGHTS and EUDEMONIA_EVAL_OUT '
        'to run the synthesis engine evaluation.'
    : null;

void main() {
  test('synthesis engine evaluation on the host library', skip: _skip, timeout: const Timeout(Duration(minutes: 60)),
      () async {
    final thoughts = [
      for (final t in jsonDecode(File(_thoughts!).readAsStringSync()) as List<dynamic>)
        SynthesisThought(
          id: t['id'] as int,
          text: t['text'] as String,
          time: DateTime.parse((t['time'] as String).replaceFirst(' ', 'T')),
        ),
    ]..sort((a, b) => a.time.compareTo(b.time));

    final profile = SynthesisModelProfile(
      modelFileName: _model!.split('/').last,
      chatFormat: ChatFormat.values.byName(_env['EUDEMONIA_EVAL_FORMAT'] ?? 'chatmlNoThink'),
      noteStyle: NoteStyle.structured,
      organiseBatchSize: 5,
      writeWordLimit: int.parse(_env['EUDEMONIA_EVAL_WRITE_LIMIT'] ?? '500'),
      minOutputRatio: 0.4,
      maxOutputRatio: 1.3,
    );

    final style = _env['EUDEMONIA_EVAL_STYLE'] ?? defaultNoteStyleId;
    if (!isKnownNoteStyle(style)) throw ArgumentError.value(style, 'EUDEMONIA_EVAL_STYLE', 'unknown note style');

    final engine = LlamaIsolateEngine(const LLMConfig(kvCacheMaxSize: 4096), null, _library!);
    await engine.load(_model!);
    final rejections = <Map<String, Object?>>[];
    var turns = 0;
    var promptTokens = 0;
    var reusedTokens = 0;
    var outputTokens = 0;
    final watch = Stopwatch()..start();
    try {
      final synthesis = SynthesisEngine(
        profile: profile,
        generate: (prompt, maxTokens, {grammar}) async {
          final session = await engine.sendPrompt(prompt, maxOutputTokens: maxTokens, grammar: grammar);
          final done = await session.completion;
          turns++;
          promptTokens += done.promptTokens;
          reusedTokens += done.reusedPromptTokens;
          outputTokens += done.outputTokens;
          return (text: done.text, hitOutputCap: done.hitOutputCap);
        },
        onRejected: (kind, ids, reason) => rejections.add({'kind': kind, 'thoughts': ids, 'reason': reason}),
      );

      final organised = await synthesis.organise(thoughts, const []);
      final sessions = <Map<String, Object?>>[];
      var unwritten = 0;
      for (final plan in organised.plans) {
        final note = await synthesis.write(SessionPlan(
          existingSessionId: plan.existingSessionId,
          folder: plan.folder,
          currentNote: plan.currentNote,
          thoughts: plan.thoughts,
          newThoughts: plan.newThoughts,
          styleId: style,
        ));
        if (note == null) unwritten += plan.thoughts.length;
        sessions.add({
          'folder': plan.folder,
          'thoughts': [for (final t in plan.thoughts) t.id],
          'spokenWords': plan.thoughts.fold<int>(0, (n, t) => n + t.text.trim().split(RegExp(r'\s+')).length),
          'noteWords': note?.trim().split(RegExp(r'\s+')).length,
          'note': note,
        });
      }

      final summary = {
        'model': profile.modelFileName,
        'style': style,
        'thoughts': thoughts.length,
        'sessions': organised.plans.length,
        'unfiledThoughts': organised.failedThoughtIds.length,
        'thoughtsInUnwrittenSessions': unwritten,
        'rejectedReplies': rejections.length,
        'turns': turns,
        'promptTokens': promptTokens,
        'reusedPromptTokens': reusedTokens,
        'outputTokens': outputTokens,
        'seconds': watch.elapsed.inSeconds,
      };
      File(_out!).writeAsStringSync(const JsonEncoder.withIndent(' ').convert({
        'summary': summary,
        'unfiled': organised.failedThoughtIds,
        'rejections': rejections,
        'sessions': sessions,
      }));
      // ignore: avoid_print
      print('SYN_HOST_EVAL|${jsonEncode(summary)}');
    } finally {
      await engine.dispose();
    }
  });
}
