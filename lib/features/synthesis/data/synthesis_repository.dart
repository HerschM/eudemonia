import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';

class SynthesisRepository extends Notifier<List<SynthesisCluster>> {
  final List<SynthesisCluster>? _initialClusters;

  SynthesisRepository([this._initialClusters]);

  @override
  List<SynthesisCluster> build() {
    return _initialClusters ?? [];
  }

  int get unreadCount => state.where((c) => c.isUnread).length;

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

    final newClusterSeq = state.length + 1;
    final newCluster = SynthesisCluster(
      clusterId: 'cluster_${DateTime.now().millisecondsSinceEpoch}',
      sequenceNumber: '#S-${newClusterSeq.toString().padLeft(2, '0')}',
      folder: noteToMove.folder,
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

  void deleteCluster(String clusterId) {
    state = state.where((c) => c.clusterId != clusterId).toList();
  }

  /// Synthesizes raw notes from NotesRepository into structured sessions
  Future<void> synthesizeRawNotes([List<Note>? rawNotes]) async {
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

    // Group notes by folder to preserve 2D routing (Time Window ∩ Target Folder)
    final byFolder = <String, List<Note>>{};
    for (final n in notesToCluster) {
      byFolder.putIfAbsent(n.folder, () => []).add(n);
    }

    final newClusters = <SynthesisCluster>[];
    int nextSeqIndex = state.length + 1;

    for (final entry in byFolder.entries) {
      final folder = entry.key;
      final folderNotes = entry.value;

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
        folder: folder,
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
