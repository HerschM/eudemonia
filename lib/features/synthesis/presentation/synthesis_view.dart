import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';
import 'package:eudemonia/features/synthesis/presentation/folder_panel.dart';
import 'package:eudemonia/features/synthesis/presentation/note_body.dart';
import 'package:eudemonia/features/synthesis/presentation/note_row.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_bar.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_filtering.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_notices.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_texts.dart';
import 'package:eudemonia/features/theme/app_colors.dart';
import 'package:eudemonia/features/theme/widgets/day_header.dart';
import 'package:eudemonia/features/theme/widgets/read_on_dwell.dart';

/// The whole Synthesis tab as plain values and callbacks: the bar, the list of notes grouped by
/// day (each a [NoteRow] that opens in place to a [NoteBody]), the notices above it and the
/// folder panel over it. `SynthesisScreen` feeds it from the providers and the preview feeds it
/// from mock data. Pure presentational widget.
class SynthesisView extends StatelessWidget {
  /// Every note; this widget filters and orders them by [folder] and [triage].
  final List<SynthesisCluster> notes;
  final List<String> folderNames;

  /// The selected folder; null is `All notes`.
  final String? folder;
  final SynthesisTriage triage;
  final bool readMode;
  final bool panelOpen;
  final bool Function(String clusterId) isOpen;
  final String? highlightedId;

  /// Build every row, not only those near the viewport (while one is being scrolled to).
  final bool buildAll;

  /// Whether this tab is in front: unread notes are read by dwelling only while it is.
  final bool tabActive;
  final bool hasWritingModel;
  final int pendingThoughts;
  final bool synthesisBusy;
  final ScrollController? scrollController;

  /// A key per note's row, for scrolling it into view.
  final Key? Function(String clusterId)? rowKeyFor;

  final VoidCallback onFolderButton;
  final VoidCallback onDismissPanel;
  final void Function(List<String> clusterIds, bool open) onToggleAll;
  final ValueChanged<bool> onReadModeChanged;
  final VoidCallback onSelectAllNotes;
  final ValueChanged<String> onSelectFolder;
  final ValueChanged<SynthesisTriage> onTriageChanged;
  final VoidCallback onManageFolders;
  final VoidCallback onChooseModel;
  final VoidCallback onSynthesizeNow;
  final ValueChanged<SynthesisCluster> onToggleNote;
  final ValueChanged<String> onNoteRead;
  final void Function(String clusterId, int taskIndex, bool checked) onTaskToggled;
  final ValueChanged<String> onToggleThoughts;
  final void Function(String clusterId, String folder) onFolderChanged;
  final ValueChanged<SynthesisCluster> onStyle;
  final ValueChanged<SynthesisCluster> onEditText;
  final ValueChanged<SynthesisCluster> onMerge;
  final ValueChanged<SynthesisCluster> onDelete;
  final void Function(SynthesisCluster note, SynthesisOriginNote thought) onMoveOut;

  const SynthesisView({
    super.key,
    required this.notes,
    required this.folderNames,
    required this.folder,
    required this.triage,
    required this.readMode,
    required this.panelOpen,
    required this.isOpen,
    required this.hasWritingModel,
    required this.pendingThoughts,
    required this.synthesisBusy,
    required this.onFolderButton,
    required this.onDismissPanel,
    required this.onToggleAll,
    required this.onReadModeChanged,
    required this.onSelectAllNotes,
    required this.onSelectFolder,
    required this.onTriageChanged,
    required this.onManageFolders,
    required this.onChooseModel,
    required this.onSynthesizeNow,
    required this.onToggleNote,
    required this.onNoteRead,
    required this.onTaskToggled,
    required this.onToggleThoughts,
    required this.onFolderChanged,
    required this.onStyle,
    required this.onEditText,
    required this.onMerge,
    required this.onDelete,
    required this.onMoveOut,
    this.highlightedId,
    this.buildAll = false,
    this.tabActive = true,
    this.scrollController,
    this.rowKeyFor,
  });

  @override
  Widget build(BuildContext context) {
    final visible = visibleNotes(notes, folder: folder, triage: triage);
    final visibleIds = [for (final n in visible) n.clusterId];
    final allOpen = visible.isNotEmpty && visible.every((n) => isOpen(n.clusterId));

    // Everything above the notes, then one entry per day header and per note.
    final leading = <Widget>[
      if (!hasWritingModel) ChooseWritingModelCard(onChoose: onChooseModel),
      if (pendingThoughts > 0)
        PendingThoughtsBanner(pendingThoughts: pendingThoughts, busy: synthesisBusy, onSynthesizeNow: onSynthesizeNow),
      if (visible.isEmpty)
        EmptySynthesisState(pendingThoughts: pendingThoughts, busy: synthesisBusy, onSynthesizeNow: onSynthesizeNow),
    ];
    final entries = <Object>[];
    DateTime? currentDay;
    for (final note in visible) {
      if (currentDay != note.sessionDay) {
        currentDay = note.sessionDay;
        entries.add(dayHeaderLabel(currentDay));
      }
      entries.add(note);
    }

    final list = ListView.builder(
      controller: scrollController,
      // While a note is scrolled to, all of them exist so it can be found wherever it is.
      scrollCacheExtent: buildAll ? const ScrollCacheExtent.pixels(1e7) : null,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      itemCount: leading.length + entries.length,
      itemBuilder: (context, index) {
        if (index < leading.length) return leading[index];
        final entry = entries[index - leading.length];
        if (entry is String) return DayHeader(label: entry);
        return _buildRow(entry as SynthesisCluster);
      },
    );

    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          SynthesisBar(
            folderLabel: folder ?? 'All notes',
            filterActive: triage != SynthesisTriage.all,
            readMode: readMode,
            allOpen: allOpen,
            onFolderTap: onFolderButton,
            onToggleAll: () => onToggleAll(visibleIds, !allOpen),
            onReadModeChanged: onReadModeChanged,
          ),
          Expanded(
            child: FolderPanelOverlay(
              open: panelOpen,
              onDismiss: onDismissPanel,
              panel: FolderPanel(
                triage: triage,
                onTriageChanged: onTriageChanged,
                selectedFolder: folder,
                totalCount: notes.length,
                totalUnread: notes.where((n) => n.isUnread).length,
                folders: folderCounts(notes, folderNames),
                onSelectAll: onSelectAllNotes,
                onSelectFolder: onSelectFolder,
                onManageFolders: onManageFolders,
              ),
              child: list,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(SynthesisCluster note) {
    final id = note.clusterId;
    final open = isOpen(id);
    final tone = note.isReprocessing
        ? NoteRowTone.rewriting
        : (note.isActionExtracted ? NoteRowTone.synthesized : NoteRowTone.processed);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      // Only an opened note can be read by staying on it: a title alone has not been read.
      child: ReadOnDwell(
        key: rowKeyFor?.call(id),
        enabled: note.isUnread && open,
        active: tabActive,
        onRead: () => onNoteRead(id),
        child: NoteRow(
          clusterId: id,
          number: note.sequenceNumber,
          title: noteListTitle(note.synthesizedContent),
          timeLabel: formatNoteTime(note.sessionStart),
          unread: note.isUnread,
          folderLabel: folder == null ? note.folder : null,
          rewriting: note.isReprocessing,
          animateRewriting: synthesisBusy,
          tone: tone,
          open: open,
          highlighted: highlightedId == id,
          onTap: () => onToggleNote(note),
          // A tap anywhere on an opened note that is still unread reads it (a control takes its own tap).
          body: open
              ? GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: note.isUnread ? () => onNoteRead(id) : null,
                  child: NoteBody(
                    note: note,
                    editMode: !readMode,
                    folderNames: folderNames,
                    canMerge: notes.length > 1,
                    onTaskToggled: (index, checked) => onTaskToggled(id, index, checked),
                    onToggleThoughts: () => onToggleThoughts(id),
                    onFolderChanged: (name) => onFolderChanged(id, name),
                    onStyle: () => onStyle(note),
                    onEditText: () => onEditText(note),
                    onMerge: () => onMerge(note),
                    onDelete: () => onDelete(note),
                    onMoveOut: (thought) => onMoveOut(note, thought),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
