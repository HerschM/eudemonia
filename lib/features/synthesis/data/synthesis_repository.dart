import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/core/logger/app_logger.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_session_store.dart';
import 'package:eudemonia/features/synthesis/domain/session_clock.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';

/// Synthesis sessions, held in memory for the UI and written through to
/// [SynthesisSessionStore] on every change so they survive app restarts.
class SynthesisRepository extends Notifier<List<SynthesisCluster>> {
  final List<SynthesisCluster>? _initialClusters;

  Future<void> _hydration = Future.value();
  Future<void> _writes = Future.value();
  bool _isHydrating = false;

  SynthesisRepository([this._initialClusters]);

  @override
  List<SynthesisCluster> build() {
    final initial = _initialClusters;
    if (initial != null) return initial;
    _hydration = _hydrateFromStore();
    return [];
  }

  /// Completes once stored sessions have been loaded into [state].
  Future<void> get hydrated => _hydration;

  /// Completes once every change made so far has reached the store.
  Future<void> get pendingWrites => _writes;

  Future<void> _hydrateFromStore() async {
    try {
      final stored = await ref.read(synthesisSessionStoreProvider).loadAll();
      if (stored.isEmpty) return;
      final current = stateOrNull ?? const <SynthesisCluster>[];
      final currentIds = current.map((c) => c.clusterId).toSet();
      _isHydrating = true;
      state = [...current, ...stored.where((c) => !currentIds.contains(c.clusterId))];
    } catch (e, stack) {
      ref.read(appLoggerProvider).error('[Synthesis] Failed to load stored sessions', error: e, stackTrace: stack);
    } finally {
      _isHydrating = false;
    }
  }

  @override
  set state(List<SynthesisCluster> next) {
    final previous = stateOrNull ?? const <SynthesisCluster>[];
    super.state = next;
    if (!_isHydrating) _writeThrough(previous, next);
  }

  /// Persists the difference between two states, in order.
  void _writeThrough(List<SynthesisCluster> previous, List<SynthesisCluster> next) {
    final store = ref.read(synthesisSessionStoreProvider);
    final logger = ref.read(appLoggerProvider);
    final before = {for (final c in previous) c.clusterId: c};
    final after = {for (final c in next) c.clusterId: c};
    final removed = before.keys.where((id) => !after.containsKey(id)).toList();
    final changed = next.where((c) => !identical(before[c.clusterId], c)).toList();
    if (removed.isEmpty && changed.isEmpty) return;

    _writes = _writes.then((_) async {
      try {
        for (final id in removed) {
          await store.delete(id);
        }
        for (final cluster in changed) {
          await store.put(cluster);
        }
      } catch (e, stack) {
        logger.error('[Synthesis] Failed to persist sessions', error: e, stackTrace: stack);
      }
    });
  }

  int get unreadCount => state.where((c) => c.isUnread).length;

  /// Next `#S-NN` index. Derived from the highest existing identifier so
  /// deleting or merging a session never produces a duplicate.
  int _nextSequenceIndex() {
    int highest = 0;
    for (final cluster in state) {
      final index = SynthesisSessionStore.sequenceIndexOf(cluster);
      if (index > highest) highest = index;
    }
    return highest + 1;
  }

  void markClusterAsRead(String clusterId) {
    state = [
      for (final cluster in state)
        if (cluster.clusterId == clusterId)
          cluster.copyWith(isUnread: false)
        else
          cluster,
    ];
  }

  void toggleExpand(String clusterId) {
    state = [
      for (final cluster in state)
        if (cluster.clusterId == clusterId)
          cluster.copyWith(
            isExpanded: !cluster.isExpanded,
            isUnread: false,
          )
        else
          cluster,
    ];
  }

  void reassignFolder(String clusterId, String newFolder) {
    state = [
      for (final cluster in state)
        if (cluster.clusterId == clusterId)
          cluster.copyWith(folder: newFolder)
        else
          cluster,
    ];
  }

  void applyStyle(String clusterId, String stylePresetId) {
    state = [
      for (final cluster in state)
        if (cluster.clusterId == clusterId)
          cluster.copyWith(
            appliedStyleId: stylePresetId,
            isReprocessing: true,
          )
        else
          cluster,
    ];
  }

  void mergeClusters(String sourceClusterId, String targetClusterId) {
    final sourceCluster =
        state.where((c) => c.clusterId == sourceClusterId).firstOrNull;
    if (sourceCluster == null) return;

    final targetCluster =
        state.where((c) => c.clusterId == targetClusterId).firstOrNull;
    if (targetCluster == null) return;

    final mergedOriginNotes = [
      ...targetCluster.originNotes,
      ...sourceCluster.originNotes,
    ];

    final updatedTarget = targetCluster.copyWith(
      originNotes: mergedOriginNotes,
      synthesizedContent:
          '${targetCluster.synthesizedContent}\n\n${sourceCluster.synthesizedContent}',
      isReprocessing: true,
    );

    state = [
      for (final cluster in state)
        if (cluster.clusterId == targetClusterId)
          updatedTarget
        else if (cluster.clusterId != sourceClusterId)
          cluster,
    ];
  }

  void ejectRawNoteToTarget(
      String sourceClusterId, String targetClusterId, int rawNoteId) {
    final sourceCluster =
        state.where((c) => c.clusterId == sourceClusterId).firstOrNull;
    if (sourceCluster == null) return;

    final noteToMove =
        sourceCluster.originNotes.where((n) => n.id == rawNoteId).firstOrNull;
    if (noteToMove == null) return;

    final updatedSourceNotes =
        sourceCluster.originNotes.where((n) => n.id != rawNoteId).toList();
    final updatedSource = sourceCluster.copyWith(
      originNotes: updatedSourceNotes,
      isReprocessing: true,
    );

    state = [
      for (final cluster in state)
        if (cluster.clusterId == sourceClusterId)
          updatedSource
        else if (cluster.clusterId == targetClusterId)
          cluster.copyWith(
            originNotes: [...cluster.originNotes, noteToMove],
            isReprocessing: true,
          )
        else
          cluster,
    ];
  }

  void ejectRawNoteToIndependent(String sourceClusterId, int rawNoteId) {
    final sourceCluster =
        state.where((c) => c.clusterId == sourceClusterId).firstOrNull;
    if (sourceCluster == null) return;

    final noteToMove =
        sourceCluster.originNotes.where((n) => n.id == rawNoteId).firstOrNull;
    if (noteToMove == null) return;

    final updatedSourceNotes =
        sourceCluster.originNotes.where((n) => n.id != rawNoteId).toList();
    final updatedSource = sourceCluster.copyWith(
      originNotes: updatedSourceNotes,
      isReprocessing: true,
    );

    final newClusterSeq = _nextSequenceIndex();
    final newCluster = SynthesisCluster(
      clusterId: 'cluster_${DateTime.now().millisecondsSinceEpoch}',
      sequenceNumber: '#S-${newClusterSeq.toString().padLeft(2, '0')}',
      folder: sourceCluster.folder,
      synthesizedContent: noteToMove.cleanedText,
      sessionStart: noteToMove.timestamp,
      sessionEnd: noteToMove.timestamp.add(const Duration(minutes: 5)),
      sessionDuration: const Duration(minutes: 5),
      originNotes: [noteToMove],
      isExpanded: false,
      isReprocessing: false,
      isUnread: true,
      isActionExtracted: true,
    );

    state = [
      newCluster,
      for (final cluster in state)
        if (cluster.clusterId == sourceClusterId) updatedSource else cluster,
    ];
  }

  /// Removes a session and returns its thoughts to `processed` so they can be
  /// clustered again.
  Future<void> deleteCluster(String clusterId) async {
    final cluster = state.where((c) => c.clusterId == clusterId).firstOrNull;
    if (cluster == null) return;
    state = state.where((c) => c.clusterId != clusterId).toList();

    final notesRepo = ref.read(notesRepositoryProvider);
    for (final origin in cluster.originNotes) {
      final note = await notesRepo.getNoteById(origin.id);
      if (note == null || note.state != ThoughtState.synthesized) continue;
      note.state = ThoughtState.processed;
      await notesRepo.saveNote(note);
    }
    ref.invalidate(recentNotesProvider);
    ref.invalidate(rawNotesReadyToClusterCountProvider);
  }

  /// Synthesizes raw notes from NotesRepository into structured sessions
  Future<void> synthesizeRawNotes([List<Note>? rawNotes]) async {
    // Stored sessions must be known first, or new identifiers could collide with them.
    await hydrated;
    final notesRepo = ref.read(notesRepositoryProvider);
    final notesToCluster = rawNotes ??
        (await notesRepo.getAllNotes())
            .where((n) => n.state == ThoughtState.processed)
            .toList();

    if (notesToCluster.isEmpty) return;

    // Mark these notes as synthesized in NotesRepository
    for (final note in notesToCluster) {
      note.state = ThoughtState.synthesized;
      await notesRepo.saveNote(note);
    }

    final sessions = splitIntoSessions<Note>(
      notesToCluster,
      timeOf: (n) => n.createdAt ?? DateTime.now(),
    );

    final newClusters = <SynthesisCluster>[];
    int nextSeqIndex = _nextSequenceIndex();

    for (final folderNotes in sessions) {
      final originNotes = folderNotes
          .map((n) => SynthesisOriginNote.fromNote(n))
          .toList();

      final earliest = folderNotes
          .map((n) => n.createdAt ?? DateTime.now())
          .reduce((a, b) => a.isBefore(b) ? a : b);
      final latest = folderNotes
          .map((n) => n.createdAt ?? DateTime.now())
          .reduce((a, b) => a.isAfter(b) ? a : b);

      final diff = latest.difference(earliest);
      final duration = diff < const Duration(minutes: 5)
          ? const Duration(minutes: 15)
          : diff;

      final combinedNarrative = folderNotes.map((n) {
        final text = n.correctedText.isNotEmpty ? n.correctedText : n.rawText;
        return '• $text';
      }).join('\n\n');

      final cluster = SynthesisCluster(
        clusterId:
            'cluster_${DateTime.now().millisecondsSinceEpoch}_$nextSeqIndex',
        sequenceNumber: '#S-${nextSeqIndex.toString().padLeft(2, '0')}',
        // Interim until the LLM organise turn assigns a session folder.
        folder: 'Uncategorized',
        synthesizedContent:
            'Consolidated ${folderNotes.length} thoughts:\n$combinedNarrative',
        sessionStart: earliest,
        sessionEnd: latest,
        sessionDuration: duration,
        originNotes: originNotes,
        isExpanded: false,
        isReprocessing: false,
        isUnread: true,
        isActionExtracted: true,
      );

      newClusters.add(cluster);
      nextSeqIndex++;
    }

    state = [...newClusters, ...state];
  }
}

final synthesisRepositoryProvider =
    NotifierProvider<SynthesisRepository, List<SynthesisCluster>>(() {
  return SynthesisRepository();
});

final rawNotesReadyToClusterCountProvider = FutureProvider<int>((ref) async {
  final notes = await ref.watch(notesRepositoryProvider).getAllNotes();
  return notes.where((n) => n.state == ThoughtState.processed).length;
});
