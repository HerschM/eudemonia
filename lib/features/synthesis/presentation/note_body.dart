import 'package:flutter/material.dart';
import 'package:eudemonia/features/synthesis/domain/note_style.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';
import 'package:eudemonia/features/synthesis/presentation/note_action_row.dart';
import 'package:eudemonia/features/synthesis/presentation/note_copy.dart';
import 'package:eudemonia/features/synthesis/presentation/note_markdown_view.dart';
import 'package:eudemonia/features/synthesis/presentation/note_text_editor.dart';
import 'package:eudemonia/features/synthesis/presentation/raw_thoughts_list.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_texts.dart';
import 'package:eudemonia/features/theme/app_colors.dart';

/// An opened note. Read mode: the formatted note (its checklist can be ticked) and under it the
/// quiet link `From 3 thoughts ▾` that reveals the thoughts as a plain list. Edit mode: also the
/// note's actions above it, a line saying so when the note was edited by hand, and a Move Out
/// button on every thought. In both modes a Copy button (`note_copy_button`: at the right end of
/// the `From N thoughts` row in Read mode, in the action row in Edit mode) and a long press on
/// the note copy it as plain text; the note's text has the full width. The note's title is not repeated here: its row shows it.
/// A tap on the note's text (a tick box takes its own tap) asks to edit it ([onEditText], as the
/// `Edit text` action does); while [editing] the text is a [NoteTextEditor] in its place (and a
/// long press no longer copies). With [onOpenThought] a thought in the list opens in Capture.
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

  /// The note's text is being edited in place; needs [onSaveText] and [onCancelEdit].
  final bool editing;

  /// What the editor starts with (a draft kept while it was scrolled away); the note's text when null.
  final String? draftText;
  final Future<bool> Function(String text)? onSaveText;
  final VoidCallback? onCancelEdit;
  final ValueChanged<String>? onDraftChanged;
  final ValueChanged<int>? onOpenThought;

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
    this.editing = false,
    this.draftText,
    this.onSaveText,
    this.onCancelEdit,
    this.onDraftChanged,
    this.onOpenThought,
  }) : assert(!editing || (onSaveText != null && onCancelEdit != null), 'an editing note needs onSaveText and onCancelEdit');

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: editing ? null : () => copyNote(context, note),
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
            // The one Copy control of Edit mode sits with the other actions.
            onCopy: () => copyNote(context, note),
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
        if (editing)
          NoteTextEditor(
            initialText: draftText ?? note.synthesizedContent,
            onSave: onSaveText!,
            onCancel: onCancelEdit!,
            onChanged: onDraftChanged,
          )
        else
          GestureDetector(
            key: Key('note_text_tap_${note.clusterId}'),
            behavior: HitTestBehavior.opaque,
            onTap: onEditText,
            child: NoteMarkdownView(text: note.synthesizedContent, hideTitle: true, onTaskToggled: onTaskToggled),
          ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Wrap(
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
            ),
            // Read mode's Copy control, at the right end of this row; Edit mode has it in its actions.
            if (!editMode)
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
        if (note.isExpanded)
          RawThoughtsList(
            thoughts: note.originNotes,
            onMoveOut: editMode ? onMoveOut : null,
            onOpenThought: onOpenThought,
          ),
      ],
    );
  }
}
