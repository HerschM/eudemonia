import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/home/application/shell_state.dart';
import 'package:eudemonia/features/models/application/model_library_controller.dart';
import 'package:eudemonia/features/models/presentation/model_setup_screen.dart';
import 'package:eudemonia/features/settings/presentation/folder_editor_sheet.dart';
import 'package:eudemonia/features/settings/settings_screen.dart';
import 'package:eudemonia/features/synthesis/application/folder_settings.dart';
import 'package:eudemonia/features/synthesis/application/session_actions.dart';
import 'package:eudemonia/features/synthesis/application/unwritten_thoughts.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/synthesis/domain/session_numbering.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';
import 'package:eudemonia/features/synthesis/presentation/manual_synthesis.dart';
import 'package:eudemonia/features/synthesis/presentation/note_ejection_sheet.dart';
import 'package:eudemonia/features/synthesis/presentation/note_merge_sheet.dart';
import 'package:eudemonia/features/synthesis/presentation/notes_view_prefs.dart';
import 'package:eudemonia/features/synthesis/presentation/rewrite_confirmation.dart';
import 'package:eudemonia/features/synthesis/presentation/style_rewriter_sheet.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_filtering.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_view.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_texts.dart';
import 'package:eudemonia/features/theme/app_colors.dart';
import 'package:eudemonia/features/theme/widgets/confirm_delete_dialog.dart';

// The keys of a note's row and card (`synthesis_cluster_card_<id>`, `note_row_<id>`, ...) are
// documented with `NoteRow`; this file keeps exporting `sessionCardKey` for its users.
export 'package:eudemonia/features/synthesis/presentation/note_row.dart' show sessionCardKey, noteRowKey;

/// The Synthesis tab: connects the providers (notes, folders, view preferences, runs) to
/// [SynthesisView] and runs what its controls ask for. Holds only what the user chose in this
/// visit: the folder and triage selection, which notes are open, the open folder panel and the
/// note whose text is being edited in place.
class SynthesisScreen extends ConsumerStatefulWidget {
  const SynthesisScreen({super.key});

  @override
  ConsumerState<SynthesisScreen> createState() => _SynthesisScreenState();
}

class _SynthesisScreenState extends ConsumerState<SynthesisScreen> with AutomaticKeepAliveClientMixin {
  static const _highlightDuration = Duration(milliseconds: 1500);

  /// The selected folder; null is `All notes`.
  String? _folder;
  SynthesisTriage _triage = SynthesisTriage.all;
  bool _panelOpen = false;

  /// The note whose text is being edited in place (one at a time) and what is typed in it so far,
  /// kept here so the draft survives the note being scrolled away or closed.
  String? _editingId;
  String _draft = '';

  /// The notes listed under the Unread or Read filter so far: they stay listed after their read
  /// state changes (a note being read does not vanish). Dropped when a filter chip is picked, the
  /// folder changes or the screen goes.
  final Set<String> _kept = {};

  /// Notes opened or closed by the user; a note not in here is open when the preference says so.
  final Map<String, bool> _open = {};

  final ScrollController _scrollController = ScrollController();

  /// One per note, for scrolling it into view.
  final Map<String, GlobalKey> _rowKeys = {};

  /// Every row is built (not only those near the viewport) while one is being scrolled to.
  bool _buildAllRows = false;
  String? _highlightedId;
  Timer? _highlightTimer;

  /// The shell swipes between tabs; this one keeps its scroll position and selection while away.
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // A request or notice made before this screen existed (first visit through a Capture card's
    // session number, a restyle that failed while another tab was in front).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _handleFocusRequest(ref.read(synthesisFocusRequestProvider));
      _showRestyleNotice(ref.read(restyleNoticeProvider));
    });
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  bool _isOpen(String clusterId) => _open[clusterId] ?? ref.read(notesViewPrefsProvider).notesOpenByDefault;

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceElevated,
        content: Text(message, style: const TextStyle(color: AppColors.textPrimary)),
      ),
    );
  }

  void _showRestyleNotice(RestyleNotice? notice) {
    if (notice == null) return;
    ref.read(restyleNoticeProvider.notifier).clear();
    _showMessage(notice.message);
  }

  /// Brings the session [clusterId] into view: it is looked for among all notes, the triage
  /// filter is cleared when it would hide the note, its row opens, is scrolled to and glows for
  /// a moment. The request is consumed either way.
  void _handleFocusRequest(String? clusterId) {
    if (clusterId == null) return;
    ref.read(synthesisFocusRequestProvider.notifier).clear();
    final target = ref.read(synthesisRepositoryProvider).where((c) => c.clusterId == clusterId).firstOrNull;
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.surfaceElevated,
          duration: Duration(seconds: 2),
          content: Text('That note no longer exists.', style: TextStyle(color: AppColors.textPrimary)),
        ),
      );
      return;
    }
    setState(() {
      _folder = null;
      _panelOpen = false;
      if (!matchesTriage(target, _triage)) _triage = SynthesisTriage.all;
      _kept.clear();
      _open[clusterId] = true;
      _buildAllRows = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealRow(clusterId));
  }

  Future<void> _revealRow(String clusterId) async {
    final rowContext = _rowKeys[clusterId]?.currentContext;
    if (!mounted) return;
    if (rowContext != null && rowContext.mounted) {
      await Scrollable.ensureVisible(
        rowContext,
        alignment: 0.1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
    if (!mounted) return;
    _highlightTimer?.cancel();
    setState(() {
      _buildAllRows = false;
      _highlightedId = clusterId;
    });
    _highlightTimer = Timer(_highlightDuration, () {
      if (mounted) setState(() => _highlightedId = null);
    });
  }

  void _toggleNote(SynthesisCluster note) {
    final wasOpen = _isOpen(note.clusterId);
    setState(() => _open[note.clusterId] = !wasOpen);
    // Opening a note reads it; closing one changes nothing.
    if (!wasOpen) _markRead(note.clusterId);
  }

  void _markRead(String clusterId) {
    final repo = ref.read(synthesisRepositoryProvider.notifier);
    if (repo.sessionById(clusterId)?.isUnread ?? false) repo.markClusterAsRead(clusterId);
  }

  Future<void> _delete(SynthesisCluster note) async {
    final confirmed = await confirmDelete(
      context,
      question: deleteNoteQuestion(note.sequenceNumber, noteListTitle(note.synthesizedContent)),
      consequence: deleteNoteConsequence(note.originNotes.length),
    );
    if (!confirmed || !mounted) return;
    await ref.read(synthesisRepositoryProvider.notifier).deleteCluster(note.clusterId);
  }

  void _manageFolders() {
    setState(() => _panelOpen = false);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  Future<void> _chooseStyle(SynthesisCluster note) async {
    if (note.isHandEdited && !await confirmRewriteOfHandEditedNote(context)) return;
    if (!mounted) return;
    StyleRewriterModal.show(
      context,
      sequenceLabel: note.sequenceNumber,
      selectedPresetId: note.appliedStyleId,
      onSelectPreset: (preset) {
        unawaited(ref.read(sessionActionsProvider).applyStyle(note.clusterId, preset.id));
        _showMessage('Applying style "${preset.name}" to ${note.sequenceNumber}...');
      },
    );
  }

  /// Turns the note's text into the in-place editor. A note being rewritten may be edited too (Save
  /// makes it hand-edited and clears its rewrite, FR11.19); a second note while one is being edited
  /// is refused (its typing would be lost).
  void _editText(SynthesisCluster note, List<SynthesisCluster> notes) {
    final editing = _liveEditingId(notes);
    if (editing == note.clusterId) return;
    if (editing != null) {
      _showMessage(finishEditingFirstNotice);
      return;
    }
    // Editing a note reads it.
    _markRead(note.clusterId);
    setState(() {
      _editingId = note.clusterId;
      _draft = note.synthesizedContent;
    });
  }

  /// The edited note, unless it was deleted meanwhile.
  String? _liveEditingId(List<SynthesisCluster> notes) =>
      notes.any((c) => c.clusterId == _editingId) ? _editingId : null;

  void _stopEditing() => setState(() => _editingId = null);

  /// Saves the edited text through [SessionActions.editNoteText] (a changed text makes the note
  /// hand-edited, FR11.19). Text equal to the note's (apart from trailing whitespace) changes nothing
  /// and just ends the editing. False when the text was refused (empty): the editor stays.
  Future<bool> _saveText(SynthesisCluster note, String text) async {
    if (text.trimRight() != note.synthesizedContent.trimRight()) {
      final outcome = await ref.read(sessionActionsProvider).editNoteText(note.clusterId, text);
      if (!outcome.accepted) return false;
    }
    if (mounted) _stopEditing();
    return true;
  }

  void _merge(SynthesisCluster note, List<SynthesisCluster> notes) {
    NoteMergeModal.show(
      context,
      sourceCluster: note,
      availableClusters: notes,
      onMergeToTargetCluster: (target) {
        ref.read(synthesisRepositoryProvider.notifier).mergeClusters(note.clusterId, target.clusterId);
        _showMessage(
            'Merged [${note.sequenceNumber}] into ${sessionReferenceLabel(target, relativeTo: note.sessionStart)}');
      },
    );
  }

  void _moveOut(SynthesisCluster note, SynthesisOriginNote thought, List<SynthesisCluster> notes) {
    final repo = ref.read(synthesisRepositoryProvider.notifier);
    NoteEjectionModal.show(
      context,
      rawNote: thought,
      currentCluster: note,
      availableClusters: notes,
      onMoveToTargetCluster: (target) {
        repo.ejectRawNoteToTarget(note.clusterId, target.clusterId, thought.id);
        _showMessage(
            'Moved [${thought.formattedSequence}] to ${sessionReferenceLabel(target, relativeTo: note.sessionStart)}');
      },
      onMakeIndependent: () {
        unawaited(ref.read(sessionActionsProvider).moveThoughtOut(note.clusterId, thought.id));
        _showMessage('Promoted [${thought.formattedSequence}] to independent synthesized note.');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.listen(synthesisFocusRequestProvider, (_, clusterId) => _handleFocusRequest(clusterId));
    ref.listen(restyleNoticeProvider, (_, notice) => _showRestyleNotice(notice));
    final notes = ref.watch(synthesisRepositoryProvider);
    final folderNames = [for (final f in ref.watch(foldersProvider)) f.name];
    final prefs = ref.watch(notesViewPrefsProvider);
    final repo = ref.read(synthesisRepositoryProvider.notifier);
    final pendingThoughts = ref.watch(rawNotesReadyToClusterCountProvider).value ?? 0;
    final unwrittenThoughts = ref.watch(unwrittenThoughtsCountProvider).value ?? 0;
    final synthesisBusy = ref.watch(synthesisBusyProvider);
    final hasWritingModel = ref.watch(activeSynthesisProfileProvider) != null;
    final tabActive = ref.watch(shellTabActiveProvider(ShellTab.synthesis));
    _rowKeys.removeWhere((id, _) => !notes.any((c) => c.clusterId == id));

    // A folder renamed or removed since it was chosen, and holding no notes, no longer filters.
    final chosen = _folder?.toLowerCase();
    final folder = chosen != null && folderCounts(notes, folderNames).any((f) => f.name.toLowerCase() == chosen)
        ? _folder
        : null;
    // Remember what the filter lists now; a note read while it is listed stays listed.
    if (_triage == SynthesisTriage.all) {
      _kept.clear();
    } else {
      _kept.addAll([for (final n in visibleNotes(notes, folder: folder, triage: _triage)) n.clusterId]);
    }
    // Without a chosen writing model a run cannot start, so the buttons lead to the choice (FR16.5).
    void synthesizeNow() => hasWritingModel ? startManualSynthesis(context) : openModelSetup(Navigator.of(context));

    // Back closes the folder panel before it leaves the screen.
    return PopScope(
      canPop: !_panelOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _panelOpen = false);
      },
      child: SynthesisView(
        notes: notes,
        folderNames: folderNames,
        folder: folder,
        triage: _triage,
        keptIds: _kept,
        readMode: prefs.readMode,
        panelOpen: _panelOpen,
        isOpen: _isOpen,
        highlightedId: _highlightedId,
        buildAll: _buildAllRows,
        tabActive: tabActive,
        hasWritingModel: hasWritingModel,
        pendingThoughts: pendingThoughts,
        unwrittenThoughts: unwrittenThoughts,
        synthesisBusy: synthesisBusy,
        scrollController: _scrollController,
        rowKeyFor: (id) => _rowKeys.putIfAbsent(id, () => GlobalKey(debugLabel: id)),
        onFolderButton: () => setState(() => _panelOpen = !_panelOpen),
        onDismissPanel: () => setState(() => _panelOpen = false),
        onToggleAll: (ids, open) => setState(() {
          for (final id in ids) {
            _open[id] = open;
          }
        }),
        onReadModeChanged: ref.read(notesViewPrefsProvider.notifier).setReadMode,
        onSelectAllNotes: () => setState(() {
          _kept.clear();
          _folder = null;
          _panelOpen = false;
        }),
        onSelectFolder: (name) => setState(() {
          _kept.clear();
          _folder = name;
          _panelOpen = false;
        }),
        onTriageChanged: (triage) => setState(() {
          _kept.clear();
          _triage = triage;
        }),
        onManageFolders: _manageFolders,
        onAddFolder: () => unawaited(FolderEditorSheet.show(context)),
        onChooseModel: () => openModelSetup(Navigator.of(context)),
        onSynthesizeNow: synthesizeNow,
        onToggleNote: _toggleNote,
        onNoteRead: _markRead,
        onTaskToggled: repo.setTaskChecked,
        onToggleThoughts: repo.toggleExpand,
        onFolderChanged: (id, name) => unawaited(ref.read(sessionActionsProvider).moveToFolder(id, name)),
        onStyle: _chooseStyle,
        onEditText: (note) => _editText(note, notes),
        editingId: _liveEditingId(notes),
        draftText: _draft,
        onSaveText: _saveText,
        onCancelEdit: _stopEditing,
        onDraftChanged: (text) => _draft = text,
        onOpenThought: (id) => ref.read(captureFocusRequestProvider.notifier).request(id),
        onMerge: (note) => _merge(note, notes),
        onDelete: (note) => unawaited(_delete(note)),
        onMoveOut: (note, thought) => _moveOut(note, thought, notes),
      ),
    );
  }
}
