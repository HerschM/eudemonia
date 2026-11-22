import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/core/logger/app_logger.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_session_store.dart';
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

  /// Adds a session whose note the write turn produced. Called by the synthesis runner only
  /// after both the organise and the write turn succeeded.
  SynthesisCluster createSession({
    required String folder,
    required String note,
    required List<SynthesisOriginNote> origins,
  }) {
    final sorted = _timeSorted(origins);
    final seq = _nextSequenceIndex();
    final cluster = SynthesisCluster(
      clusterId: 'cluster_${DateTime.now().millisecondsSinceEpoch}_$seq',
      sequenceNumber: '#S-${seq.toString().padLeft(2, '0')}',
      folder: folder,
      synthesizedContent: note,
      sessionStart: sorted.first.timestamp,
      sessionEnd: sorted.last.timestamp,
      sessionDuration: sorted.last.timestamp.difference(sorted.first.timestamp),
      originNotes: sorted,
      isExpanded: false,
      isReprocessing: false,
      isUnread: true,
      isActionExtracted: true,
    );
    state = [cluster, ...state];
    return cluster;
  }

  /// Replaces a session's note with a newly written one, adding [addedOrigins], and clears
  /// the reprocessing flag.
  void updateSession(
    String clusterId, {
    required String note,
    List<SynthesisOriginNote> addedOrigins = const [],
  }) {
    state = [
      for (final cluster in state)
        if (cluster.clusterId == clusterId) _rewritten(cluster, note, addedOrigins) else cluster,
    ];
  }

  SynthesisCluster _rewritten(SynthesisCluster cluster, String note, List<SynthesisOriginNote> added) {
    final origins = _timeSorted([...cluster.originNotes, ...added]);
    if (origins.isEmpty) {
      return cluster.copyWith(synthesizedContent: note, isUnread: true, isReprocessing: false);
    }
    return cluster.copyWith(
      synthesizedContent: note,
      originNotes: origins,
      sessionStart: origins.first.timestamp,
      sessionEnd: origins.last.timestamp,
      sessionDuration: origins.last.timestamp.difference(origins.first.timestamp),
      isUnread: true,
      isReprocessing: false,
    );
  }

  /// Drops a session left without thoughts (e.g. after its last thought was ejected).
  void removeEmptySession(String clusterId) {
    state = [
      for (final cluster in state)
        if (cluster.clusterId != clusterId || cluster.originNotes.isNotEmpty) cluster,
    ];
  }

  static List<SynthesisOriginNote> _timeSorted(List<SynthesisOriginNote> origins) =>
      List.of(origins)..sort((a, b) => a.timestamp.compareTo(b.timestamp));
}

final synthesisRepositoryProvider =
    NotifierProvider<SynthesisRepository, List<SynthesisCluster>>(() {
  return SynthesisRepository();
});

final rawNotesReadyToClusterCountProvider = FutureProvider<int>((ref) async {
  final notes = await ref.watch(notesRepositoryProvider).getAllNotes();
  return notes.where((n) => n.state == ThoughtState.processed).length;
});
