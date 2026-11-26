import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/synthesis/application/folder_settings.dart';
import 'package:eudemonia/features/synthesis/application/synthesis_runner.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/synthesis/domain/folder_definition.dart';
import 'package:eudemonia/features/synthesis/domain/note_style.dart';

/// A restyle that could not be written: the note of [clusterId] is unchanged.
class RestyleNotice {
  final String clusterId;
  final String message;

  const RestyleNotice({required this.clusterId, required this.message});
}

/// The latest restyle notice for the Synthesis screen to show; it clears it once shown.
class RestyleNoticeNotifier extends Notifier<RestyleNotice?> {
  @override
  RestyleNotice? build() => null;

  void publish(RestyleNotice notice) => state = notice;

  void clear() => state = null;
}

final restyleNoticeProvider = NotifierProvider<RestyleNoticeNotifier, RestyleNotice?>(RestyleNoticeNotifier.new);

/// How a hand edit of a note ended ([SessionActions.editNoteText]).
enum NoteTextEdit {
  saved,

  /// The text was empty or only whitespace: nothing changed.
  empty,

  /// The session no longer exists: nothing changed.
  notFound;

  bool get accepted => this == NoteTextEdit.saved;
}

/// What the user does to a whole session in Synthesis that decides how its note is written:
/// choosing its style, moving it to a folder (which writes it in the folder's default style) and
/// editing it by hand (after which it is never rewritten automatically).
///
/// The previous style is remembered only in memory, so nothing new is persisted: after a restart
/// a pending restyle that fails falls back to organised.
class SessionActions {
  final SynthesisRepository _sessions;

  /// Starts a synthesis run. Not awaited: a busy, preempted or model-less run leaves the flag for
  /// the next run, which rewrites the session in its style then.
  final Future<SynthesisRunResult> Function() _startRun;
  final void Function(RestyleNotice notice) _notify;

  /// The user's folders, for their default styles.
  final Future<List<FolderDefinition>> Function() _folders;

  /// Restyles not yet written: the style the note is still written in and the one asked for.
  final Map<String, ({String previous, String requested})> _pending = {};

  /// The style each session's note was last written in during this launch.
  final Map<String, String> _written = {};

  SessionActions({
    required this._sessions,
    required this._startRun,
    required this._notify,
    this._folders = _defaultFolderList,
  });

  static Future<List<FolderDefinition>> _defaultFolderList() async => defaultFolders;

  /// Flags the session to be rewritten in [styleId] and starts a run without waiting for it.
  /// A note edited by hand is regenerated from its thoughts like any other.
  Future<void> applyStyle(String clusterId, String styleId) async {
    await _sessions.hydrated;
    final session = _sessions.sessionById(clusterId);
    if (session == null) return;
    _restyle(session.clusterId, session.appliedStyleId, styleId);
  }

  /// Files the session under [folderName]. Unless its note was edited by hand, a note whose style
  /// differs from the folder's default style is then rewritten in it, as [applyStyle] does; a
  /// folder that is not in the list restyles nothing.
  Future<void> moveToFolder(String clusterId, String folderName) async {
    await _sessions.hydrated;
    final folders = await _folders();
    final session = _sessions.sessionById(clusterId);
    if (session == null) return;
    _sessions.reassignFolder(clusterId, folderName);
    if (session.isHandEdited || !folders.any((f) => f.name == folderName)) return;
    final styleId = folderDefaultStyle(folders, folderName);
    if (styleId != session.appliedStyleId) _restyle(clusterId, session.appliedStyleId, styleId);
  }

  /// Replaces the note with [text] the user wrote, kept exactly except for trailing whitespace.
  /// The note is then edited by hand ([manualStyleId]): never rewritten automatically, not marked
  /// unread, and no run is started. A text that is empty or only whitespace changes nothing.
  Future<NoteTextEdit> editNoteText(String clusterId, String text) async {
    await _sessions.hydrated;
    final kept = text.trimRight();
    if (kept.trim().isEmpty) return NoteTextEdit.empty;
    if (_sessions.sessionById(clusterId) == null) return NoteTextEdit.notFound;
    // A restyle not yet written is dropped: the user's text replaces it.
    _pending.remove(clusterId);
    _sessions.setHandEditedNote(clusterId, kept);
    return NoteTextEdit.saved;
  }

  void _restyle(String clusterId, String current, String styleId) {
    // A second choice before the first was written: the note is still in the earlier style.
    final previous = _pending[clusterId]?.previous ?? current;
    _pending[clusterId] = (previous: previous, requested: styleId);
    _sessions.applyStyle(clusterId, styleId);
    unawaited(_startRun());
  }

  /// Called by the runner (see [RewriteFinished]). A failed restyle puts the previous style back
  /// and publishes a notice; the runner has already kept the note and cleared the flag.
  void rewriteFinished(String clusterId, String styleId, String? failure) {
    final pending = _pending[clusterId];
    if (failure == null) {
      _written[clusterId] = styleId;
      if (pending?.requested == styleId) _pending.remove(clusterId);
      return;
    }
    if (pending != null && pending.requested != styleId) return;
    // A rewrite after a thought change of a note already written in this style: nothing to undo.
    if (pending == null && (_written[clusterId] == styleId || styleId == defaultNoteStyleId)) return;
    _pending.remove(clusterId);
    _sessions.restoreStyle(clusterId, pending?.previous ?? defaultNoteStyleId);
    _notify(RestyleNotice(
      clusterId: clusterId,
      message: failure == tooLongForShortSummary
          ? 'This note is too long for a short summary. It is unchanged.'
          : 'Could not rewrite this note as "${noteStyleById(styleId).label}". It is unchanged.',
    ));
  }
}

final Provider<SessionActions> sessionActionsProvider = Provider<SessionActions>((ref) {
  return SessionActions(
    sessions: ref.watch(synthesisRepositoryProvider.notifier),
    // Read only when a style is chosen, so Synthesis does not build the runner up front.
    startRun: () => ref.read(synthesisRunnerProvider).run(manual: true),
    notify: (notice) => ref.read(restyleNoticeProvider.notifier).publish(notice),
    folders: () async {
      await ref.read(foldersProvider.notifier).loaded;
      return ref.read(foldersProvider);
    },
  );
});
