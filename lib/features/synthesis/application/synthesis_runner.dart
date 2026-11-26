import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:eudemonia/core/logger/app_logger.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_service.dart';
import 'package:eudemonia/features/ai_processing/cpu_wake_lock.dart';
import 'package:eudemonia/features/ai_processing/llm_service.dart';
import 'package:eudemonia/features/ai_processing/model_lifecycle_manager.dart';
import 'package:eudemonia/features/ai_processing/model_residency_arbiter.dart';
import 'package:eudemonia/features/capture/capture_controller.dart';
import 'package:eudemonia/features/models/application/model_library_controller.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/synthesis/application/folder_settings.dart';
import 'package:eudemonia/features/synthesis/application/session_actions.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/synthesis/domain/folder_definition.dart';
import 'package:eudemonia/features/synthesis/domain/note_style.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_engine.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_model_profile.dart';

/// [noModel]: no language model is downloaded and chosen, so nothing was started.
enum SynthesisRunResult { completed, nothingToDo, busy, preempted, failed, noModel }

/// Reports how the rewrite of a flagged session ended: [failure] is null when its note was
/// written in [styleId], otherwise why it was not (the note was kept and the flag cleared).
typedef RewriteFinished = void Function(String clusterId, String styleId, String? failure);

/// The failure reported when the model gave no valid note.
const String noValidReply = 'no valid reply';

/// Automatic runs give up on a thought after this many runs failed to file or write it.
const int maxAutomaticSynthesisAttempts = 3;

String _thoughtText(Note n) => n.correctedText.isNotEmpty ? n.correctedText : n.rawText;

/// True when [note] waits in Capture for synthesis and the run kind may take it.
bool isSynthesisCandidate(Note note, {required bool manual, int maxAttempts = maxAutomaticSynthesisAttempts}) =>
    note.state == ThoughtState.processed &&
    _thoughtText(note).trim().isNotEmpty &&
    (manual || note.synthesisAttempts < maxAttempts);

/// Runs one synthesis pass: organise new thoughts into the user's folders, write each touched
/// session and commit it (a new one in its folder's default style), then rewrite sessions flagged
/// for reprocessing (a rewrite without a valid reply keeps the note and clears the flag). A note
/// edited by hand is never rewritten: its new thoughts are appended to it, and a flag on it is
/// cleared. Capture always has priority: a run never starts while capture is active and ends as
/// soon as the speech model is needed.
///
/// Every thought of a run is counted as one attempt when the run starts, so a run that dies
/// mid-way (process killed) still counts; a thought that gets synthesized has its count reset,
/// and a run preempted by capture takes its count back.
class SynthesisRunner {
  /// How long the CPU is kept awake per hold; renewed before the model load and every model
  /// call, so it only has to outlast one turn including its stop timeout.
  static const Duration wakeLockWindow = Duration(minutes: 10);

  final NotesRepository _notes;
  final SynthesisRepository _sessions;
  final List<SynthesisCluster> Function() _readSessions;
  final LLMService _llm;
  final ModelLifecycleManager _lifecycle;
  final ModelResidencyArbiter _arbiter;
  final bool Function() _isCaptureActive;
  final Future<String?> Function() _modelsDir;
  final SynthesisModelProfile? Function() _profile;
  final Future<List<FolderDefinition>> Function() _folders;
  final AppLogger? _logger;
  final CpuWakeLock? _wakeLock;
  final void Function(bool running)? _onRunningChanged;

  /// Told every time a session's note is written in its style (also when new thoughts join it)
  /// and every time a flagged session's rewrite fails, so a restyle can be confirmed or undone.
  final RewriteFinished? _onRewriteFinished;
  final int maxAutomaticAttempts;

  bool _running = false;
  bool _preempted = false;
  Future<void>? _loading;

  SynthesisRunner({
    required this._notes,
    required this._sessions,
    required this._readSessions,
    required this._llm,
    required this._lifecycle,
    required this._arbiter,
    required this._isCaptureActive,
    required this._modelsDir,
    required this._profile,
    this._folders = _defaultFolderList,
    this._logger,
    this._wakeLock,
    this._onRunningChanged,
    this._onRewriteFinished,
    this.maxAutomaticAttempts = maxAutomaticSynthesisAttempts,
  });

  bool get isRunning => _running;

  static Future<List<FolderDefinition>> _defaultFolderList() async => defaultFolders;

  /// Never throws. [manual] runs also retry thoughts that failed [maxAutomaticAttempts] times.
  Future<SynthesisRunResult> run({required bool manual}) async {
    if (_running) return SynthesisRunResult.busy;
    _running = true;
    try {
      return await _run(manual);
    } catch (e, stack) {
      _logger?.error('[Synthesis] Run could not start', error: e, stackTrace: stack);
      return SynthesisRunResult.failed;
    } finally {
      _running = false;
    }
  }

  Future<SynthesisRunResult> _run(bool manual) async {
    // Resolved once: a model chosen or deleted mid-run does not change the run in progress.
    final profile = _profile();
    // Checked before anything is evicted, loaded or counted as an attempt (FR16.5).
    if (profile == null) return SynthesisRunResult.noModel;
    await _sessions.hydrated;
    // Also resolved once: folders edited mid-run apply from the next run.
    final folders = await _folders();
    // Before deciding there is work: a flag on a note edited by hand never needs the model.
    _clearHandEditedFlags();
    final candidates = (await _notes.getAllNotes())
        .where((n) => isSynthesisCandidate(n, manual: manual, maxAttempts: maxAutomaticAttempts))
        .toList();
    final hasFlagged = _readSessions().any((s) => s.isReprocessing);
    if (candidates.isEmpty && !hasFlagged) return SynthesisRunResult.nothingToDo;

    if (_isCaptureActive() || _lifecycle.isBusy) return SynthesisRunResult.busy;
    if (!await _lifecycle.evictModels(reason: 'Synthesis run')) return SynthesisRunResult.busy;
    // Capture may have started while the speech model was being evicted.
    if (_isCaptureActive()) return SynthesisRunResult.busy;
    _preempted = false;
    if (!_arbiter.tryAcquireLanguage(onPreempt: _preempt)) return SynthesisRunResult.busy;

    _onRunningChanged?.call(true);
    final watch = Stopwatch()..start();
    final flagged = [for (final s in _readSessions()) if (s.isReprocessing) s];
    _logger?.info('[Synthesis] Run started (${manual ? 'manual' : 'automatic'}): model ${profile.modelFileName}, '
        '${candidates.length} thought(s) waiting, ${flagged.length} session(s) to rewrite'
        '${flagged.isEmpty ? '' : ' (styles ${flagged.map((s) => '${s.sequenceNumber} ${s.appliedStyleId}').join(', ')})'}.');
    // Thoughts a model answer could not file or write; they keep the attempt counted at the start.
    final failedIds = <int>{};
    var result = SynthesisRunResult.completed;
    try {
      await _wakeLock?.hold(wakeLockWindow);
      await _countAttempts(candidates);
      await _work(candidates, failedIds, profile, folders);
    } catch (e, stack) {
      if (_preempted || e is LlmCancelledException) {
        _logger?.info('[Synthesis] Run preempted by capture; uncommitted work is redone next run.');
        result = SynthesisRunResult.preempted;
      } else {
        _logger?.error('[Synthesis] Run failed', error: e, stackTrace: stack);
        result = SynthesisRunResult.failed;
      }
    } finally {
      // The speech model may load as soon as the slot is released, so free this one first.
      await _llm.dispose();
      _arbiter.releaseLanguage();
      if (result == SynthesisRunResult.preempted) {
        try {
          await _undoAttempts(candidates);
        } catch (e, stack) {
          _logger?.error('[Synthesis] Could not undo the attempts of a preempted run', error: e, stackTrace: stack);
        }
      }
      await _wakeLock?.release();
      _onRunningChanged?.call(false);
    }
    _logger?.info('[Synthesis] Run ended: ${result.name} after ${watch.elapsed.inSeconds}s; '
        '${failedIds.length} thought(s) not synthesized.');
    return result;
  }

  void _checkPreempted() {
    if (_preempted) throw const LlmCancelledException();
  }

  Future<void> _work(
    List<Note> candidates,
    Set<int> failedIds,
    SynthesisModelProfile profile,
    List<FolderDefinition> folders,
  ) async {
    final dir = await _modelsDir();
    if (dir == null) throw Exception('Could not resolve models directory path.');
    await _wakeLock?.hold(wakeLockWindow);
    // A recording may have preempted the run while it was still preparing; nothing is loaded yet.
    _checkPreempted();
    final loading = _loading = _llm.initialize('$dir/${profile.modelFileName}');
    try {
      await loading;
    } finally {
      _loading = null;
    }
    _checkPreempted();

    final engine = SynthesisEngine(
      generate: (prompt, maxTokens, {grammar}) async {
        await _wakeLock?.hold(wakeLockWindow);
        _checkPreempted();
        final g = await _llm.generate(prompt, maxOutputTokens: maxTokens, grammar: grammar);
        _logger?.info('[Synthesis] Turn: ${g.promptTokens} prompt tokens (${g.reusedPromptTokens} reused) read in '
            '${_seconds(g.readMs)}s; ${g.outputTokens} output tokens written in ${_seconds(g.writeMs)}s; '
            'threads ${g.readingThreads} reading / ${g.writingThreads} writing on cores ${g.allowedCores}.');
        return (text: g.text, hitOutputCap: g.hitOutputCap);
      },
      profile: profile,
      folders: folders,
      onRejected: (kind, ids, reason) =>
          _logger?.warning('[Synthesis] Rejected $kind reply for thought ids $ids: $reason'),
    );

    // The style and thoughts each session's note was last written from in this run. The user may
    // delete or edit a thought, or choose another style, while a note is being written; such a
    // note is not committed as final.
    final writtenFrom = <String, String>{};
    if (candidates.isNotEmpty) {
      final now = DateTime.now();
      final thoughts = [
        for (final n in candidates) SynthesisThought(id: n.id, text: _thoughtText(n), time: n.createdAt ?? now),
      ];
      final organisedFrom = {for (final s in _readSessions()) s.clusterId: _thoughtKey(s)};
      final outcome = await engine.organise(thoughts, [
        for (final s in _readSessions())
          ExistingSession(
            id: s.clusterId,
            folder: s.folder,
            note: s.synthesizedContent,
            thoughts: _thoughtsOf(s),
            styleId: s.appliedStyleId,
          ),
      ]);
      failedIds.addAll(outcome.failedThoughtIds);
      _logger?.info('[Synthesis] Organised into ${outcome.plans.length} session(s)'
          '${outcome.failedThoughtIds.isEmpty ? '' : '; no valid folder reply for thought ids ${outcome.failedThoughtIds}'}.');

      for (final plan in outcome.plans) {
        _checkPreempted();
        final note = await engine.write(plan);
        _checkPreempted();
        if (note == null) {
          failedIds.addAll(plan.newThoughts.map((t) => t.id));
          _logger?.warning('[Synthesis] No valid note for the ${plan.folder} session with thought ids '
              '${plan.newThoughts.map((t) => t.id).toList()}.');
          continue;
        }
        final existingId = plan.existingSessionId;
        final existing = existingId == null ? null : _sessionById(existingId);
        // The user may have deleted the session during the run; its thoughts then stay in Capture.
        if (existingId != null && existing == null) continue;
        // Read again: a thought deleted meanwhile must not be saved back, an edit must not be undone,
        // and a style chosen meanwhile must still be applied.
        var stale = existing != null &&
            (_thoughtKey(existing) != organisedFrom[existingId] || existing.appliedStyleId != plan.styleId);
        final added = <Note>[];
        var newThoughtsChanged = false;
        for (final t in plan.newThoughts) {
          final current = await _notes.getNoteById(t.id);
          if (current == null || _thoughtText(current) != t.text) newThoughtsChanged = true;
          if (current != null) added.add(current);
        }
        stale = stale || newThoughtsChanged;
        if (added.isEmpty) continue;
        // A note edited by hand is never overwritten and cannot be rewritten: when it was edited
        // while this note was written, or a thought appended to it changed meanwhile, nothing is
        // committed and its new thoughts stay in Capture for the next run.
        if (existing != null &&
            existing.isHandEdited &&
            (plan.styleId != manualStyleId || existing.synthesizedContent != plan.currentNote || newThoughtsChanged)) {
          _logger?.info('[Synthesis] Session ${existing.sequenceNumber} was edited by hand while its note was '
              'written; its new thoughts are filed next run.');
          continue;
        }
        final origins = [for (final n in added) SynthesisOriginNote.fromNote(n)];
        final String sessionId;
        if (existingId == null) {
          sessionId = _sessions
              .createSession(folder: plan.folder, note: note, origins: origins, styleId: plan.styleId)
              .clusterId;
        } else {
          _sessions.updateSession(existingId, note: note, addedOrigins: origins);
          sessionId = existingId;
        }
        // Written from thoughts that changed meanwhile: rewritten from the current ones below. A note
        // still edited by hand is not rewritten; only its earlier thoughts can have changed.
        if (stale && !_sessionById(sessionId)!.isHandEdited) {
          _sessions.markForRewrite(sessionId);
        } else {
          writtenFrom[sessionId] = _writtenKey(plan.styleId, _sessionById(sessionId)!);
        }
        _onRewriteFinished?.call(sessionId, plan.styleId, null);
        for (final n in added) {
          n.state = ThoughtState.synthesized;
          n.synthesisAttempts = 0;
          await _notes.saveNote(n);
        }
      }
    }

    // Flagged sessions are rewritten from their thoughts in their style, also those flagged while
    // this run was working. Every pass only takes sessions whose thoughts or style changed since
    // they were last written, so the loop ends once the user stops changing them.
    while (true) {
      _clearHandEditedFlags();
      final due = [
        for (final s in _readSessions())
          if (s.isReprocessing && writtenFrom[s.clusterId] != _writtenKey(s.appliedStyleId, s)) s,
      ];
      if (due.isEmpty) break;
      for (final s in due) {
        final key = writtenFrom[s.clusterId] = _writtenKey(s.appliedStyleId, s);
        if (s.originNotes.isEmpty) {
          _sessions.removeEmptySession(s.clusterId);
          continue;
        }
        _checkPreempted();
        final all = _thoughtsOf(s);
        final plan = SessionPlan(
          existingSessionId: s.clusterId,
          folder: s.folder,
          currentNote: null,
          thoughts: all,
          newThoughts: all,
          styleId: s.appliedStyleId,
        );
        _logger?.info('[Synthesis] Rewriting session ${s.sequenceNumber} in the ${s.appliedStyleId} style.');
        final note = await engine.write(plan);
        _checkPreempted();
        final current = _sessionById(s.clusterId);
        // Deleted, or its thoughts or style changed while the note was written: the next pass handles it.
        if (current == null || _writtenKey(current.appliedStyleId, current) != key) continue;
        if (note != null) {
          _sessions.updateSession(s.clusterId, note: note);
          _onRewriteFinished?.call(s.clusterId, s.appliedStyleId, null);
        } else {
          // No fallback text: the note stays as it was, and the session is not retried forever.
          _sessions.clearReprocessing(s.clusterId);
          _logger?.warning('[Synthesis] No valid rewrite for session ${s.sequenceNumber} in the '
              '${s.appliedStyleId} style; its note is kept.');
          _onRewriteFinished?.call(s.clusterId, s.appliedStyleId, engine.unwritableReason(plan) ?? noValidReply);
        }
      }
    }
  }

  SynthesisCluster? _sessionById(String id) => _readSessions().where((s) => s.clusterId == id).firstOrNull;

  /// A note edited by hand is never rewritten automatically: a flag on it (a merge, an ejected
  /// thought) is cleared and its note kept. One without thoughts is still flagged, to be removed.
  void _clearHandEditedFlags() {
    for (final s in _readSessions()) {
      if (s.isReprocessing && s.isHandEdited && s.originNotes.isNotEmpty) _sessions.clearReprocessing(s.clusterId);
    }
  }

  /// The thoughts of a session (ids and texts in order), to see whether they changed.
  static String _thoughtKey(SynthesisCluster s) =>
      [for (final o in s.originNotes) '${o.id}\u0000${o.cleanedText}'].join('\u0001');

  /// What a note written in [styleId] from the thoughts of [s] was written from.
  static String _writtenKey(String styleId, SynthesisCluster s) => '$styleId\u0002${_thoughtKey(s)}';

  static String _seconds(int ms) => (ms / 1000).toStringAsFixed(1);

  static List<SynthesisThought> _thoughtsOf(SynthesisCluster s) => [
        for (final o in s.originNotes) SynthesisThought(id: o.id, text: o.cleanedText, time: o.timestamp),
      ]..sort((a, b) => a.time.compareTo(b.time));

  /// Counts one attempt for every thought of this run, persisted before any model work.
  Future<void> _countAttempts(List<Note> candidates) async {
    for (final n in candidates) {
      n.synthesisAttempts++;
      await _notes.saveNote(n);
    }
  }

  /// Takes the start-of-run attempt back from thoughts that are still waiting in Capture.
  Future<void> _undoAttempts(List<Note> candidates) async {
    for (final n in candidates) {
      final note = await _notes.getNoteById(n.id);
      if (note == null || note.state != ThoughtState.processed || note.synthesisAttempts <= 0) continue;
      note.synthesisAttempts--;
      await _notes.saveNote(note);
    }
  }

  /// Called by the arbiter when a recording needs the speech model.
  Future<void> _preempt() async {
    _preempted = true;
    final loading = _loading;
    if (loading != null) {
      try {
        await loading;
      } catch (_) {}
    }
    await _llm.cancelActiveGeneration();
    await _llm.dispose();
    _arbiter.releaseLanguage();
  }
}

/// True while a synthesis run holds the language model, for the UI.
class SynthesisRunningNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setRunning(bool value) => state = value;
}

final synthesisRunningProvider = NotifierProvider<SynthesisRunningNotifier, bool>(SynthesisRunningNotifier.new);

final Provider<SynthesisRunner> synthesisRunnerProvider = Provider<SynthesisRunner>((ref) {
  return SynthesisRunner(
    notes: ref.watch(notesRepositoryProvider),
    sessions: ref.watch(synthesisRepositoryProvider.notifier),
    readSessions: () => ref.read(synthesisRepositoryProvider),
    llm: ref.watch(llmServiceProvider),
    lifecycle: ref.watch(modelLifecycleManagerProvider),
    arbiter: ref.watch(modelResidencyArbiterProvider),
    profile: () => ref.read(activeSynthesisProfileProvider),
    folders: () async {
      await ref.read(foldersProvider.notifier).loaded;
      return ref.read(foldersProvider);
    },
    isCaptureActive: () => ref.read(captureControllerProvider) || ref.read(pendingQueueCountProvider) > 0,
    // Same directory the speech model is loaded from.
    modelsDir: () async => (await getExternalStorageDirectory())?.path,
    logger: ref.watch(appLoggerProvider),
    wakeLock: ref.watch(synthesisWakeLockProvider),
    onRunningChanged: (running) => ref.read(synthesisRunningProvider.notifier).setRunning(running),
    // Read when a rewrite ends, so the runner does not build the actions up front.
    onRewriteFinished: (id, style, failure) => ref.read(sessionActionsProvider).rewriteFinished(id, style, failure),
  );
});
