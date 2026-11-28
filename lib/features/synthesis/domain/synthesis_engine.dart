/// The synthesis algorithm: files new thoughts into time sessions by folder (organise) and writes a
/// session's note (write). Pure Dart; the language model is injected as [SynthesisGenerate].
/// There is no fallback: a turn the model cannot answer validly is retried smaller or reported failed.
library;

import 'dart:async';

import 'folder_definition.dart';
import 'note_style.dart';
import 'session_clock.dart';
import 'synthesis_model_profile.dart';
import 'synthesis_prompts.dart';

class SynthesisThought {
  final int id;
  final String text;
  final DateTime time;

  const SynthesisThought({required this.id, required this.text, required this.time});
}

class ExistingSession {
  final String id;
  final String folder;
  final String note;
  final List<SynthesisThought> thoughts;

  /// The style its note is written in (see [noteStyles]); new thoughts are written in it too, or
  /// appended to it for a note edited by hand ([manualStyleId]).
  final String styleId;

  const ExistingSession({
    required this.id,
    required this.folder,
    required this.note,
    required this.thoughts,
    this.styleId = defaultNoteStyleId,
  });
}

class SessionPlan {
  /// Null when the session does not exist yet.
  final String? existingSessionId;
  final String folder;

  /// The existing session's note; null for a new session.
  final String? currentNote;

  /// All thoughts of the session in time order (existing and new).
  final List<SynthesisThought> thoughts;

  /// The thoughts added by this run, in time order.
  final List<SynthesisThought> newThoughts;

  /// The style the note is written in (see [noteStyles]): the session's, its folder's default for a
  /// new one. [manualStyleId] for a note edited by hand: only the new thoughts are written.
  final String styleId;

  const SessionPlan({
    required this.existingSessionId,
    required this.folder,
    required this.currentNote,
    required this.thoughts,
    required this.newThoughts,
    this.styleId = defaultNoteStyleId,
  });
}

class OrganiseOutcome {
  final List<SessionPlan> plans;
  final List<int> failedThoughtIds;

  const OrganiseOutcome({required this.plans, required this.failedThoughtIds});
}

typedef SynthesisReply = ({String text, bool hitOutputCap});
/// Generates the reply to [prompt]; [grammar] (GBNF) constrains its form when given.
typedef SynthesisGenerate = Future<SynthesisReply> Function(String prompt, int maxOutputTokens, {String? grammar});

/// Reports a model reply the engine rejected: the turn kind, the thought ids of the turn and why.
typedef SynthesisRejection = void Function(String kind, List<int> thoughtIds, String reason);

/// Cuts [text] into consecutive parts of at most [wordLimit] words, at sentence ends (`.`, `?` or
/// `!` followed by whitespace) where it can; a sentence longer than the limit is cut at the limit.
/// The parts' words, in order, are exactly the words of [text].
List<String> splitAtSentenceEnds(String text, int wordLimit) {
  if (wordLimit < 1) throw ArgumentError.value(wordLimit, 'wordLimit', 'must be at least 1');
  final parts = <String>[];
  var current = <String>[];
  for (final sentence in text.trim().split(RegExp(r'(?<=[.?!])\s+'))) {
    final words = sentence.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) continue;
    if (current.isNotEmpty && current.length + words.length > wordLimit) {
      parts.add(current.join(' '));
      current = [];
    }
    if (words.length <= wordLimit) {
      current.addAll(words);
      continue;
    }
    // Too long on its own: full parts of the limit, and the rest runs on with the next sentence.
    var i = 0;
    for (; i + wordLimit <= words.length; i += wordLimit) {
      parts.add(words.sublist(i, i + wordLimit).join(' '));
    }
    current = words.sublist(i);
  }
  if (current.isNotEmpty) parts.add(current.join(' '));
  return parts;
}

class _Session {
  final String? existingId;
  final String folder;
  final String? currentNote;
  final String styleId;
  final List<SynthesisThought> thoughts;
  final List<SynthesisThought> newThoughts = [];

  _Session(this.existingId, this.folder, this.currentNote, List<SynthesisThought> thoughts,
      {this.styleId = defaultNoteStyleId})
      : thoughts = List.of(thoughts)..sort((a, b) => a.time.compareTo(b.time));

  DateTime get start => thoughts.first.time;
  DateTime get last => thoughts.last.time;

  void add(SynthesisThought t) {
    var i = thoughts.length;
    while (i > 0 && thoughts[i - 1].time.isAfter(t.time)) {
      i--;
    }
    thoughts.insert(i, t);
    newThoughts.add(t);
  }
}

class SynthesisEngine {
  final SynthesisGenerate _generate;
  final SynthesisModelProfile profile;
  final List<FolderDefinition> folders;
  final Duration idleWindow;
  final Duration maxSpan;
  final SynthesisRejection? _onRejected;

  SynthesisEngine({
    required SynthesisGenerate generate,
    this.profile = SynthesisModelProfile.qwen25_1_5b,
    this.folders = defaultFolders,
    this.idleWindow = const Duration(minutes: 45),
    this.maxSpan = const Duration(hours: 2),
    this._onRejected,
  }) : _generate = generate; // ignore: prefer_initializing_formals

  /// The start of a rejected reply on one line, for diagnostics.
  static String _excerpt(String text) {
    final line = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    return line.length > 100 ? '${line.substring(0, 100)}…' : line;
  }

  static String _replyProblem(SynthesisReply? reply) => reply == null
      ? 'timed out'
      : '${reply.hitOutputCap ? 'reached the output limit' : 'not in the expected form'}: "${_excerpt(reply.text)}"';

  /// Calls the model; a timeout is reported as null (an invalid reply), other errors propagate.
  Future<SynthesisReply?> _call(String prompt, int maxTokens, {String? grammar}) async {
    try {
      return await _generate(prompt, maxTokens, grammar: grammar);
    } on TimeoutException {
      return null;
    }
  }

  static int _words(String text) => text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  bool _canJoin(_Session s, DateTime t) =>
      !t.isBefore(s.start) && t.difference(s.start) < maxSpan && t.difference(s.last) <= idleWindow;

  // ---- organise ----

  Future<OrganiseOutcome> organise(List<SynthesisThought> newThoughts, List<ExistingSession> existing) async {
    final working = <_Session>[
      for (final e in existing)
        if (e.thoughts.isNotEmpty) _Session(e.id, e.folder, e.note, e.thoughts, styleId: e.styleId),
    ];
    final failed = <int>[];
    final groups = splitIntoSessions(newThoughts, timeOf: (t) => t.time, idleWindow: idleWindow, maxSpan: maxSpan);
    for (final group in groups) {
      for (var i = 0; i < group.length; i += profile.organiseBatchSize) {
        final end = i + profile.organiseBatchSize < group.length ? i + profile.organiseBatchSize : group.length;
        await _organiseBatch(group.sublist(i, end), working, failed);
      }
    }
    final touched = working.where((s) => s.newThoughts.isNotEmpty).toList()
      ..sort((a, b) => a.newThoughts.first.time.compareTo(b.newThoughts.first.time));
    return OrganiseOutcome(
      plans: [
        for (final s in touched)
          SessionPlan(
            existingSessionId: s.existingId,
            folder: s.folder,
            currentNote: s.currentNote,
            thoughts: List.unmodifiable(s.thoughts),
            newThoughts: List.unmodifiable(s.newThoughts),
            styleId: s.styleId,
          ),
      ],
      failedThoughtIds: failed,
    );
  }

  String _contextText(_Session s) {
    final note = s.currentNote;
    final text = note != null && note.trim().isNotEmpty ? note : s.thoughts.map((t) => t.text).join(' ');
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return words.length > 60 ? '${words.take(60).join(' ')}…' : words.join(' ');
  }

  Future<void> _organiseBatch(List<SynthesisThought> batch, List<_Session> working, List<int> failed) async {
    final ctx = [
      for (final s in working)
        if (_canJoin(s, batch.first.time)) OpenSessionContext(folder: s.folder, note: _contextText(s)),
    ];
    final prompt = buildOrganisePrompt(
      [for (final t in batch) t.text],
      folders: folders,
      openSessions: ctx,
      format: profile.chatFormat,
    );
    final reply = await _call(prompt, organiseOutputBudget(batch.length),
        grammar: buildOrganiseGrammar(batch.length, folders));
    final labels = reply == null || reply.hitOutputCap ? null : parseOrganiseReply(reply.text, batch.length, folders);
    if (labels == null) {
      _onRejected?.call('organise', [for (final t in batch) t.id], _replyProblem(reply));
      if (batch.length == 1) {
        failed.add(batch.first.id);
        return;
      }
      final mid = (batch.length + 1) ~/ 2;
      await _organiseBatch(batch.sublist(0, mid), working, failed);
      await _organiseBatch(batch.sublist(mid), working, failed);
      return;
    }
    for (var i = 0; i < batch.length; i++) {
      final t = batch[i];
      _Session? target;
      for (final s in working) {
        if (s.folder == labels[i] && _canJoin(s, t.time) && (target == null || s.last.isAfter(target.last))) {
          target = s;
        }
      }
      if (target == null) {
        target = _Session(null, labels[i], null, [t], styleId: folderDefaultStyle(folders, labels[i]));
        target.newThoughts.add(t);
        working.add(target);
      } else {
        target.add(t);
      }
    }
  }

  // ---- write ----

  /// Why [plan] cannot be written in its style at all, before any model call; null when it can.
  /// A short summary is never written in pieces, so a session over one write turn cannot have one.
  String? unwritableReason(SessionPlan plan) {
    final style = noteStyleById(plan.styleId);
    if (style.splittable) return null;
    final total = plan.thoughts.fold<int>(0, (n, t) => n + _words(t.text));
    return total > profile.writeWordLimit ? tooLongForShortSummary : null;
  }

  /// The note of [plan] in its style, or null when the model gave no valid reply. A session over
  /// the write limit is written in pieces that are joined into one note of the style (see
  /// [NoteStyleSpec.join]); with an existing note only the new thoughts are written and appended.
  /// A note edited by hand is never rewritten: its new thoughts alone are written organised and
  /// appended to it (see [appendAddedLater]).
  Future<String?> write(SessionPlan plan) async {
    if (plan.styleId == manualStyleId) {
      final added = await _writePieces(plan.newThoughts, noteStyleById(defaultNoteStyleId));
      return added == null ? null : appendAddedLater(plan.currentNote ?? '', added);
    }
    final style = noteStyleById(plan.styleId);
    final problem = unwritableReason(plan);
    if (problem != null) {
      _onRejected?.call('write', [for (final t in plan.thoughts) t.id], problem);
      return null;
    }
    final total = plan.thoughts.fold<int>(0, (n, t) => n + _words(t.text));
    final note = plan.currentNote;
    if (total <= profile.writeWordLimit) return _writePieces(plan.thoughts, style);
    if (note != null && note.trim().isNotEmpty) {
      final added = await _writePieces(plan.newThoughts, style);
      return added == null ? null : style.join(note, added);
    }
    return _writePieces(plan.thoughts, style);
  }

  /// Packs [thoughts] into pieces of at most one write turn, in order. A thought longer than one
  /// turn is written as its own consecutive pieces, cut at sentence ends (see
  /// [splitAtSentenceEnds]); each part keeps the thought's id and time, and its turn is told it
  /// is a part of a long thought (see [buildStyleWritePrompt]).
  Future<String?> _writePieces(List<SynthesisThought> thoughts, NoteStyleSpec style) async {
    final limit = profile.writeWordLimit;
    final pieces = <({List<SynthesisThought> thoughts, bool isPart})>[];
    var current = <SynthesisThought>[];
    var words = 0;
    for (final t in thoughts) {
      final w = _words(t.text);
      if (current.isNotEmpty && words + w > limit) {
        pieces.add((thoughts: current, isPart: false));
        current = [];
        words = 0;
      }
      if (w > limit && style.splittable) {
        for (final part in splitAtSentenceEnds(t.text, limit)) {
          pieces.add((thoughts: [SynthesisThought(id: t.id, text: part, time: t.time)], isPart: true));
        }
        continue;
      }
      current.add(t);
      words += w;
    }
    if (current.isNotEmpty) pieces.add((thoughts: current, isPart: false));
    final notes = <String>[];
    for (final piece in pieces) {
      final n = await _writePiece(piece.thoughts, style, isPart: piece.isPart);
      if (n == null) return null;
      notes.add(n);
    }
    return notes.isEmpty ? null : notes.reduce(style.join);
  }

  Future<String?> _writePiece(List<SynthesisThought> thoughts, NoteStyleSpec style, {bool isPart = false}) async {
    final texts = [for (final t in thoughts) t.text];
    final ids = [for (final t in thoughts) t.id];
    // A small model writes organised notes with the clean-up prompt; every other style has its own.
    final cleanUp = profile.noteStyle == NoteStyle.cleanUp && style.id == defaultNoteStyleId;
    var turn = await _writeTurn(texts, style, cleanUp: cleanUp, longThoughtText: isPart);
    // A turn with a long thought whose plain reply left something out is retried once with the
    // long-thought rules (a long story can be read as its opening sentence alone). The retry meets
    // every check unchanged; on ordinary sessions the rules change the form, so they are never
    // the first try (TASK-104).
    final retry = turn.note == null &&
        turn.leftSomethingOut &&
        !isPart &&
        !cleanUp &&
        style.longThoughtSystemPrompt != null &&
        texts.any((t) => _words(t) >= longThoughtWords);
    if (turn.note == null) _onRejected?.call('write', ids, retry ? '${turn.reason}; retrying with the long-thought rules' : turn.reason);
    if (retry) {
      turn = await _writeTurn(texts, style, cleanUp: false, longThoughtText: true);
      if (turn.note == null) _onRejected?.call('write', ids, turn.reason);
    }
    final note = turn.note;
    if (note != null) return note;
    if (thoughts.length == 1 || !style.splittable) return null;
    final mid = (thoughts.length + 1) ~/ 2;
    final a = await _writePiece(thoughts.sublist(0, mid), style);
    if (a == null) return null;
    final b = await _writePiece(thoughts.sublist(mid), style);
    return b == null ? null : style.join(a, b);
  }

  /// One write turn of [texts]: the note, or why the reply was rejected and whether that was for
  /// leaving something out (the length, every-thought or stretch check).
  Future<({String? note, String reason, bool leftSomethingOut})> _writeTurn(List<String> texts, NoteStyleSpec style,
      {required bool cleanUp, required bool longThoughtText}) async {
    final inputWords = texts.fold<int>(0, (n, t) => n + _words(t));
    final prompt = cleanUp
        ? buildWritePrompt(texts, format: profile.chatFormat)
        : buildStyleWritePrompt(texts, style, format: profile.chatFormat, longThoughtText: longThoughtText);
    final budget = cleanUp ? writeOutputBudget(inputWords) : structuredOutputBudget(inputWords);
    final reply = await _call(prompt, budget);
    if (reply == null) return (note: null, reason: 'timed out', leftSomethingOut: false);
    if (reply.hitOutputCap) return (note: null, reason: 'reached the output limit', leftSomethingOut: false);
    final text = reply.text.trim();
    final out = _words(text);
    final minRatio = style.minOutputRatio ?? profile.minOutputRatio;
    final maxRatio = style.maxOutputRatio ?? profile.maxOutputRatio;
    final ok = text.isNotEmpty && out <= maxRatio * inputWords + 30 && (inputWords < 30 || out >= minRatio * inputWords);
    if (!ok) return (note: null, reason: '$out words written from $inputWords', leftSomethingOut: true);
    if (style.requiresEveryThought) {
      final missing = thoughtsMissingFrom(text, texts);
      if (missing.isNotEmpty) return (note: null, reason: 'the note leaves out thought(s) $missing', leftSomethingOut: true);
      // A long thought is also judged stretch by stretch: a note can keep half of it and still
      // pass as a whole.
      final stretch = longThoughtsWithMissingStretch(text, texts);
      if (stretch.isNotEmpty) {
        return (note: null, reason: 'the note leaves out a stretch of thought(s) $stretch', leftSomethingOut: true);
      }
    }
    final form = style.formProblem(text);
    if (form != null) return (note: null, reason: 'not in the ${style.label} form: $form', leftSomethingOut: false);
    return (note: text, reason: '', leftSomethingOut: false);
  }
}
