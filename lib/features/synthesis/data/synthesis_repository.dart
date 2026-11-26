import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/core/logger/app_logger.dart';
import 'package:eudemonia/features/synthesis/data/session_numbering_flag_store.dart';
import 'package:eudemonia/features/synthesis/data/style_reset_flag_store.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_session_store.dart';
import 'package:eudemonia/features/synthesis/domain/note_style.dart';
import 'package:eudemonia/features/synthesis/domain/session_numbering.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';
import 'package:eudemonia/features/synthesis/presentation/note_markdown.dart' as markdown;

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
      final store = ref.read(synthesisSessionStoreProvider);
      final stored = await _withStylesApplied(store, await _withDailyNumbers(store, await store.loadAll()));
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

  /// Once per database: sessions numbered globally before daily numbers are renumbered per day
  /// in order of their start and persisted. A fresh install has nothing to renumber and only
  /// sets the flag. If the flag cannot be read or written the sessions load unchanged.
  Future<List<SynthesisCluster>> _withDailyNumbers(SynthesisSessionStore store, List<SynthesisCluster> stored) async {
    try {
      final flag = ref.read(sessionNumberingFlagStoreProvider);
      if (await flag.isDailyNumbering()) return stored;
      final renumbered = renumberSessionsByDay(stored);
      for (var i = 0; i < stored.length; i++) {
        if (!identical(renumbered[i], stored[i])) await store.put(renumbered[i]);
      }
      await flag.markDailyNumbering();
      if (stored.isNotEmpty) {
        ref.read(appLoggerProvider).info('[Synthesis] Renumbered ${stored.length} stored session(s) per day.');
      }
      return renumbered;
    } catch (e) {
      ref.read(appLoggerProvider).warning('[Synthesis] Could not move sessions to daily numbers: $e');
      return stored;
    }
  }

  /// Once per database: every stored session's style is set to organised, the style its note is
  /// really written in (before styles were applied a chosen style was only stored). The
  /// reprocessing flag is left alone: a flag set by a deleted or edited thought cannot be told
  /// apart from one set by a style tap, and a flagged session is rewritten either way.
  Future<List<SynthesisCluster>> _withStylesApplied(SynthesisSessionStore store, List<SynthesisCluster> stored) async {
    try {
      final flag = ref.read(styleResetFlagStoreProvider);
      if (await flag.isStylesApplied()) return stored;
      final reset = [
        for (final s in stored) s.appliedStyleId == defaultNoteStyleId ? s : s.copyWith(appliedStyleId: defaultNoteStyleId),
      ];
      var changed = 0;
      for (var i = 0; i < stored.length; i++) {
        if (identical(reset[i], stored[i])) continue;
        await store.put(reset[i]);
        changed++;
      }
      await flag.markStylesApplied();
      if (changed > 0) {
        ref.read(appLoggerProvider).info('[Synthesis] Set the style of $changed stored session(s) to organised.');
      }
      return reset;
    } catch (e) {
      ref.read(appLoggerProvider).warning('[Synthesis] Could not reset the stored session styles: $e');
      return stored;
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

  /// The one place a session gets its identifier and `#S-NN` label: the next number of the
  /// day of [sessionStart] (see [nextSessionNumber]), assigned once and never changed after.
  ({String clusterId, String label}) _allocateSession(DateTime sessionStart) {
    final number = nextSessionNumber(state, sessionStart);
    final day = calendarDayOf(sessionStart);
    final dayKey = '${day.year}${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}';
    // The day and number are unique among existing sessions, so the id stays unique even for
    // several sessions created within the same millisecond.
    return (
      clusterId: 'cluster_${DateTime.now().millisecondsSinceEpoch}_${dayKey}_$number',
      label: formatSessionLabel(number),
    );
  }

  SynthesisCluster? sessionById(String clusterId) => state.where((c) => c.clusterId == clusterId).firstOrNull;

  /// The session holding thought [noteId], or null when no session consumed it.
  SynthesisCluster? sessionOfThought(int noteId) {
    for (final cluster in state) {
      if (cluster.originNotes.any((o) => o.id == noteId)) return cluster;
    }
    return null;
  }

  /// Removes deleted thought [noteId] from the session holding it. A session left without
  /// thoughts is removed; otherwise it is flagged so its note is rewritten from the thoughts
  /// that remain, unless the note was edited by hand (it is never rewritten automatically).
  /// Returns true when a session now waits for that rewrite.
  bool removeThought(int noteId) {
    final cluster = sessionOfThought(noteId);
    if (cluster == null) return false;
    final remaining = cluster.originNotes.where((o) => o.id != noteId).toList();
    if (remaining.isEmpty) {
      state = state.where((c) => c.clusterId != cluster.clusterId).toList();
      return false;
    }
    final rewrite = !cluster.isHandEdited;
    _replace(_spanning(cluster, remaining).copyWith(isReprocessing: rewrite ? true : null));
    return rewrite;
  }

  /// Gives thought [noteId] its edited [text] in the session holding it and flags the session
  /// so its note is rewritten, unless the note was edited by hand. Returns true when a session
  /// now waits for that rewrite.
  bool updateThoughtText(int noteId, String text) {
    final cluster = sessionOfThought(noteId);
    if (cluster == null) return false;
    final origin = cluster.originNotes.firstWhere((o) => o.id == noteId);
    if (origin.cleanedText == text) return false;
    _replace(cluster.copyWith(
      originNotes: [
        for (final o in cluster.originNotes)
          if (o.id == noteId)
            SynthesisOriginNote(
              id: o.id,
              formattedSequence: o.formattedSequence,
              cleanedText: text,
              timestamp: o.timestamp,
              audioPath: o.audioPath,
            )
          else
            o,
      ],
      isReprocessing: cluster.isHandEdited ? null : true,
    ));
    return !cluster.isHandEdited;
  }

  /// Replaces the session's note with [text] the user wrote by hand: its style becomes
  /// [manualStyleId], a pending rewrite is dropped and the note is not marked unread.
  void setHandEditedNote(String clusterId, String text) => _update(
      clusterId,
      (c) => c.copyWith(synthesizedContent: text, appliedStyleId: manualStyleId, isReprocessing: false));

  /// Flags a session so the next synthesis run rewrites its note from its thoughts.
  void markForRewrite(String clusterId) => _update(clusterId, (c) => c.copyWith(isReprocessing: true));

  /// Ends a rewrite that produced no valid note: the session keeps its note and is no longer flagged.
  void clearReprocessing(String clusterId) => _update(clusterId, (c) => c.copyWith(isReprocessing: false));

  /// Puts back the style the note is written in after a restyle failed, without flagging it.
  void restoreStyle(String clusterId, String styleId) =>
      _update(clusterId, (c) => c.appliedStyleId == styleId ? c : c.copyWith(appliedStyleId: styleId));

  /// Ticks or unticks task [taskIndex] of the session's note (see [markdown.setTaskChecked]).
  /// The user's own change: the note is not marked unread and not flagged for a rewrite.
  void setTaskChecked(String clusterId, int taskIndex, bool checked) {
    final cluster = sessionById(clusterId);
    if (cluster == null) return;
    final text = markdown.setTaskChecked(cluster.synthesizedContent, taskIndex, checked);
    if (text != cluster.synthesizedContent) _replace(cluster.copyWith(synthesizedContent: text));
  }

  /// Files every session of folder [from] under [to] (a folder was removed).
  void moveFolderSessions(String from, String to) {
    if (from == to || !state.any((c) => c.folder == from)) return;
    state = [
      for (final cluster in state)
        if (cluster.folder == from) cluster.copyWith(folder: to) else cluster,
    ];
  }

  /// A folder was renamed: its sessions follow it.
  void renameFolder(String from, String to) => moveFolderSessions(from, to);

  void _update(String clusterId, SynthesisCluster Function(SynthesisCluster) change) {
    final cluster = state.where((c) => c.clusterId == clusterId).firstOrNull;
    if (cluster != null) _replace(change(cluster));
  }

  void _replace(SynthesisCluster updated) {
    state = [
      for (final cluster in state)
        if (cluster.clusterId == updated.clusterId) updated else cluster,
    ];
  }

  /// [cluster] with [origins] (time-sorted) and the time span they cover.
  static SynthesisCluster _spanning(SynthesisCluster cluster, List<SynthesisOriginNote> origins) {
    final sorted = _timeSorted(origins);
    return cluster.copyWith(
      originNotes: sorted,
      sessionStart: sorted.first.timestamp,
      sessionEnd: sorted.last.timestamp,
      sessionDuration: sorted.last.timestamp.difference(sorted.first.timestamp),
    );
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

  /// Files the session under [newFolder] and nothing else; restyling it to the folder's default
  /// is `SessionActions.moveToFolder`'s job.
  void reassignFolder(String clusterId, String newFolder) {
    state = [
      for (final cluster in state)
        if (cluster.clusterId == clusterId)
          cluster.copyWith(folder: newFolder)
        else
          cluster,
    ];
  }

  /// Stores the chosen style and flags the session so its note is rewritten in it. Starting that
  /// rewrite is `SessionActions.applyStyle`'s job.
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

    final allocated = _allocateSession(noteToMove.timestamp);
    final newCluster = SynthesisCluster(
      clusterId: allocated.clusterId,
      sequenceNumber: allocated.label,
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
  }

  /// Adds a session whose note the write turn produced in [styleId]. Called by the synthesis
  /// runner only after both the organise and the write turn succeeded.
  SynthesisCluster createSession({
    required String folder,
    required String note,
    required List<SynthesisOriginNote> origins,
    String styleId = defaultNoteStyleId,
  }) {
    final sorted = _timeSorted(origins);
    final allocated = _allocateSession(sorted.first.timestamp);
    final cluster = SynthesisCluster(
      clusterId: allocated.clusterId,
      sequenceNumber: allocated.label,
      folder: folder,
      synthesizedContent: note,
      sessionStart: sorted.first.timestamp,
      sessionEnd: sorted.last.timestamp,
      sessionDuration: sorted.last.timestamp.difference(sorted.first.timestamp),
      originNotes: sorted,
      isExpanded: false,
      isReprocessing: false,
      appliedStyleId: styleId,
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
    final origins = [...cluster.originNotes, ...added];
    final updated = cluster.copyWith(synthesizedContent: note, isUnread: true, isReprocessing: false);
    return origins.isEmpty ? updated : _spanning(updated, origins);
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
  ref.watch(notesRevisionProvider);
  final notes = await ref.watch(notesRepositoryProvider).getAllNotes();
  return notes.where((n) => n.state == ThoughtState.processed).length;
});
