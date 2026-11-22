import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:eudemonia/core/logger/app_logger.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_service.dart';
import 'package:eudemonia/features/ai_processing/llm_service.dart';
import 'package:eudemonia/features/ai_processing/model_lifecycle_manager.dart';
import 'package:eudemonia/features/ai_processing/model_residency_arbiter.dart';
import 'package:eudemonia/features/capture/capture_controller.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/synthesis/domain/folder_definition.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_engine.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_model_profile.dart';

enum SynthesisRunResult { completed, nothingToDo, busy, preempted, failed }

/// Automatic runs give up on a thought after this many runs failed to file or write it.
const int maxAutomaticSynthesisAttempts = 3;

String _thoughtText(Note n) => n.correctedText.isNotEmpty ? n.correctedText : n.rawText;

/// True when [note] waits in Capture for synthesis and the run kind may take it.
bool isSynthesisCandidate(Note note, {required bool manual, int maxAttempts = maxAutomaticSynthesisAttempts}) =>
    note.state == ThoughtState.processed &&
    _thoughtText(note).trim().isNotEmpty &&
    (manual || note.synthesisAttempts < maxAttempts);

/// Runs one synthesis pass: organise new thoughts, write each touched session and commit it,
/// then rewrite sessions flagged for reprocessing. Capture always has priority: a run never
/// starts while capture is active and ends as soon as the speech model is needed.
class SynthesisRunner {
  final NotesRepository _notes;
  final SynthesisRepository _sessions;
  final List<SynthesisCluster> Function() _readSessions;
  final LLMService _llm;
  final ModelLifecycleManager _lifecycle;
  final ModelResidencyArbiter _arbiter;
  final bool Function() _isCaptureActive;
  final Future<String?> Function() _modelsDir;
  final SynthesisModelProfile profile;
  final List<FolderDefinition> folders;
  final AppLogger? _logger;
  final void Function(bool running)? _onRunningChanged;
  final void Function()? _onNotesChanged;
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
    this.profile = SynthesisModelProfile.qwen25_1_5b,
    this.folders = defaultFolders,
    this._logger,
    this._onRunningChanged,
    this._onNotesChanged,
    this.maxAutomaticAttempts = maxAutomaticSynthesisAttempts,
  });

  bool get isRunning => _running;

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
    await _sessions.hydrated;
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
    // Thoughts a model answer could not file or write; counted only if the run is not preempted.
    final failedIds = <int>{};
    var result = SynthesisRunResult.completed;
    try {
      await _work(candidates, failedIds);
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
      if (result != SynthesisRunResult.preempted) {
        try {
          await _countAttempts(failedIds);
        } catch (e, stack) {
          _logger?.error('[Synthesis] Could not record failed attempts', error: e, stackTrace: stack);
        }
      }
      _onNotesChanged?.call();
      _onRunningChanged?.call(false);
    }
    _logger?.info('[Synthesis] Run ended: ${result.name}; ${failedIds.length} thought(s) not synthesized.');
    return result;
  }

  void _checkPreempted() {
    if (_preempted) throw const LlmCancelledException();
  }

  Future<void> _work(List<Note> candidates, Set<int> failedIds) async {
    final dir = await _modelsDir();
    if (dir == null) throw Exception('Could not resolve models directory path.');
    final loading = _loading = _llm.initialize('$dir/${profile.modelFileName}');
    try {
      await loading;
    } finally {
      _loading = null;
    }
    _checkPreempted();

    final engine = SynthesisEngine(
      generate: (prompt, maxTokens) async {
        _checkPreempted();
        final g = await _llm.generate(prompt, maxOutputTokens: maxTokens);
        return (text: g.text, hitOutputCap: g.hitOutputCap);
      },
      profile: profile,
      folders: folders,
    );

    final rewritten = <String>{};
    if (candidates.isNotEmpty) {
      final byId = {for (final n in candidates) n.id: n};
      final now = DateTime.now();
      final thoughts = [
        for (final n in candidates) SynthesisThought(id: n.id, text: _thoughtText(n), time: n.createdAt ?? now),
      ];
      final outcome = await engine.organise(thoughts, [
        for (final s in _readSessions())
          ExistingSession(id: s.clusterId, folder: s.folder, note: s.synthesizedContent, thoughts: _thoughtsOf(s)),
      ]);
      failedIds.addAll(outcome.failedThoughtIds);

      for (final plan in outcome.plans) {
        _checkPreempted();
        final note = await engine.write(plan);
        _checkPreempted();
        if (note == null) {
          failedIds.addAll(plan.newThoughts.map((t) => t.id));
          continue;
        }
        final added = [for (final t in plan.newThoughts) byId[t.id]!];
        final origins = [for (final n in added) SynthesisOriginNote.fromNote(n)];
        final existingId = plan.existingSessionId;
        // The user may have deleted the session during the run; its thoughts then stay in Capture.
        if (existingId != null && !_readSessions().any((s) => s.clusterId == existingId)) continue;
        if (existingId == null) {
          _sessions.createSession(folder: plan.folder, note: note, origins: origins);
        } else {
          _sessions.updateSession(existingId, note: note, addedOrigins: origins);
          rewritten.add(existingId);
        }
        for (final n in added) {
          n.state = ThoughtState.synthesized;
          n.synthesisAttempts = 0;
          await _notes.saveNote(n);
        }
      }
    }

    for (final s in _readSessions().where((s) => s.isReprocessing && !rewritten.contains(s.clusterId)).toList()) {
      if (s.originNotes.isEmpty) {
        _sessions.removeEmptySession(s.clusterId);
        continue;
      }
      _checkPreempted();
      final all = _thoughtsOf(s);
      final note = await engine.write(SessionPlan(
        existingSessionId: s.clusterId,
        folder: s.folder,
        currentNote: null,
        thoughts: all,
        newThoughts: all,
      ));
      _checkPreempted();
      if (note != null) _sessions.updateSession(s.clusterId, note: note);
    }
  }

  static List<SynthesisThought> _thoughtsOf(SynthesisCluster s) => [
        for (final o in s.originNotes) SynthesisThought(id: o.id, text: o.cleanedText, time: o.timestamp),
      ]..sort((a, b) => a.time.compareTo(b.time));

  Future<void> _countAttempts(Set<int> ids) async {
    for (final id in ids) {
      final note = await _notes.getNoteById(id);
      if (note == null || note.state != ThoughtState.processed) continue;
      note.synthesisAttempts++;
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

final synthesisRunnerProvider = Provider<SynthesisRunner>((ref) {
  return SynthesisRunner(
    notes: ref.watch(notesRepositoryProvider),
    sessions: ref.watch(synthesisRepositoryProvider.notifier),
    readSessions: () => ref.read(synthesisRepositoryProvider),
    llm: ref.watch(llmServiceProvider),
    lifecycle: ref.watch(modelLifecycleManagerProvider),
    arbiter: ref.watch(modelResidencyArbiterProvider),
    isCaptureActive: () => ref.read(captureControllerProvider) || ref.read(pendingQueueCountProvider) > 0,
    // Same directory the speech model is loaded from.
    modelsDir: () async => (await getExternalStorageDirectory())?.path,
    logger: ref.watch(appLoggerProvider),
    onRunningChanged: (running) => ref.read(synthesisRunningProvider.notifier).setRunning(running),
    onNotesChanged: () {
      ref.invalidate(recentNotesProvider);
      ref.invalidate(rawNotesReadyToClusterCountProvider);
    },
  );
});
