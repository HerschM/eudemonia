import 'package:flutter/material.dart';
import 'package:eudemonia/features/synthesis/domain/note_style.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';
import 'package:eudemonia/features/synthesis/presentation/note_action_row.dart';
import 'package:eudemonia/features/synthesis/presentation/note_copy.dart';
import 'package:eudemonia/features/synthesis/presentation/note_markdown_view.dart';
import 'package:eudemonia/features/synthesis/presentation/raw_thoughts_list.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_texts.dart';
import 'package:eudemonia/features/theme/app_colors.dart';

/// An opened note. Read mode: the formatted note (its checklist can be ticked) and under it the
/// quiet link `From 3 thoughts ▾` that reveals the thoughts as a plain list. Edit mode: also the
/// note's actions above it, a line saying so when the note was edited by hand, and a Move Out
/// button on every thought. In both modes a Copy button (`note_copy_button`) and a long press on
/// the note copy it as plain text. The note's title is not repeated here: its row shows it.
/// Pure presentational widget.
class NoteBody extends StatelessWidget {
  final SynthesisCluster note;
  final bool editMode;
  final List<String> folderNames;

  /// Merge needs another note to merge into.
  final bool canMerge;
  final void Function(int taskIndex, bool checked) onTaskToggled;
  final VoidCallback onToggleThoughts;
  final ValueChanged<String> onFolderChanged;
  final VoidCallback onStyle;
  final VoidCallback onEditText;
  final VoidCallback onMerge;
  final VoidCallback onDelete;
  final ValueChanged<SynthesisOriginNote> onMoveOut;

  const NoteBody({
    super.key,
    required this.note,
    required this.editMode,
    required this.folderNames,
    required this.canMerge,
    required this.onTaskToggled,
    required this.onToggleThoughts,
    required this.onFolderChanged,
    required this.onStyle,
    required this.onEditText,
    required this.onMerge,
    required this.onDelete,
    required this.onMoveOut,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: () => copyNote(context, note),
      child: _content(context),
    );
  }

  Widget _content(BuildContext context) {
    final thoughtCount = note.originNotes.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (editMode) ...[
          NoteActionRow(
            clusterId: note.clusterId,
            folder: note.folder,
            folderNames: folderNames,
            styleLabel: noteStyleLabel(note.appliedStyleId),
            canMerge: canMerge,
            onFolderChanged: onFolderChanged,
            onStyle: onStyle,
            onEditText: onEditText,
            onMerge: onMerge,
            onDelete: onDelete,
          ),
          if (note.isHandEdited)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                handEditedNotice,
                key: Key('hand_edited_notice_${note.clusterId}'),
                style: TextStyle(fontSize: 11, height: 1.35, color: AppColors.textSecondary.withValues(alpha: 0.85)),
              ),
            ),
          const SizedBox(height: 12),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: NoteMarkdownView(text: note.synthesizedContent, hideTitle: true, onTaskToggled: onTaskToggled),
            ),
            Tooltip(
              message: 'Copy note',
              child: InkWell(
                key: const Key('note_copy_button'),
                borderRadius: BorderRadius.circular(16),
                onTap: () => copyNote(context, note),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.copy_outlined, size: 18, color: AppColors.textSecondary),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            InkWell(
              key: Key('expand_raw_notes_${note.clusterId}'),
              borderRadius: BorderRadius.circular(6),
              onTap: onToggleThoughts,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      describeNoteOrigin(thoughtCount),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accentAction),
                    ),
                    Icon(
                      note.isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 16,
                      color: AppColors.accentAction,
                    ),
                  ],
                ),
              ),
            ),
            Text(
              describeSessionSpan(note.sessionStart, note.sessionDuration),
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.8)),
            ),
          ],
        ),
        if (note.isExpanded)
          RawThoughtsList(thoughts: note.originNotes, onMoveOut: editMode ? onMoveOut : null),
      ],
    );
  }
}
