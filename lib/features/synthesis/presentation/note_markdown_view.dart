import 'package:flutter/material.dart';
import 'package:eudemonia/features/synthesis/presentation/note_markdown.dart';
import 'package:eudemonia/features/theme/app_colors.dart';

/// Rendering of a synthesized note's light Markdown (see [parseNoteMarkdown]). Tasks are drawn
/// as checkbox rows; they can be ticked only when [onTaskToggled] is given.
/// Not selectable by itself; wrap in a `SelectionArea` where selection is wanted.
class NoteMarkdownView extends StatelessWidget {
  final String text;

  /// Body style; defaults to the synthesis card body style.
  final TextStyle? style;

  /// Draws only the first blocks, for a collapsed card.
  final int? maxBlocks;

  /// Called with a task's index among the note's tasks and its new state when it is tapped.
  final void Function(int taskIndex, bool checked)? onTaskToggled;

  const NoteMarkdownView({
    super.key,
    required this.text,
    this.style,
    this.maxBlocks,
    this.onTaskToggled,
  });

  /// Minimum height of a tappable task row (touch target).
  static const double taskTapHeight = 44;

  static const TextStyle defaultStyle = TextStyle(
    fontSize: 13.5,
    height: 1.45,
    color: AppColors.textPrimary,
  );

  @override
  Widget build(BuildContext context) {
    final body = style ?? defaultStyle;
    final titleStyle = body.copyWith(
      fontSize: (body.fontSize ?? 14.0) + 2.0,
      fontWeight: FontWeight.w700,
    );
    final headingStyle = body.copyWith(fontWeight: FontWeight.w700);

    var blocks = parseNoteMarkdown(text);
    final limit = maxBlocks;
    if (limit != null && blocks.length > limit) {
      blocks = blocks.take(limit < 0 ? 0 : limit).toList();
    }
    if (blocks.isEmpty) return const SizedBox.shrink();

    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      final spans = [
        for (final s in block.spans)
          TextSpan(
            text: s.text,
            style: s.bold ? const TextStyle(fontWeight: FontWeight.w700) : null,
          ),
      ];
      switch (block.kind) {
        case NoteBlockKind.title:
          children.add(Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text.rich(TextSpan(style: titleStyle, children: spans)),
          ));
        case NoteBlockKind.heading:
          children.add(Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
            child: Text.rich(TextSpan(style: headingStyle, children: spans)),
          ));
        case NoteBlockKind.bullet:
          children.add(Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 16,
                  child: Text('•', style: body),
                ),
                Expanded(
                  child: Text.rich(TextSpan(style: body, children: spans)),
                ),
              ],
            ),
          ));
        case NoteBlockKind.task:
          children.add(_taskRow(block, spans, body));
        case NoteBlockKind.paragraph:
          children.add(Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
            child: Text.rich(TextSpan(style: body, children: spans)),
          ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _taskRow(NoteBlock block, List<InlineSpan> spans, TextStyle body) {
    final index = block.taskIndex ?? 0;
    final checked = block.checked;
    final textStyle = checked
        ? body.copyWith(
            color: AppColors.textTertiary,
            decoration: TextDecoration.lineThrough,
            decorationColor: AppColors.textTertiary,
          )
        : body;
    final lineHeight = (body.fontSize ?? 14.0) * (body.height ?? 1.2);
    final toggle = onTaskToggled;
    Widget row = Row(
      crossAxisAlignment: toggle == null ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        // Hanging indent like a bullet: wrapped lines start under the text, not under the box.
        SizedBox(
          width: 26,
          height: lineHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _TaskBox(key: Key('note_task_box_$index'), checked: checked),
          ),
        ),
        Expanded(child: Text.rich(TextSpan(style: textStyle, children: spans))),
      ],
    );
    if (toggle != null) {
      row = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => toggle(index, !checked),
        child: ConstrainedBox(constraints: const BoxConstraints(minHeight: taskTapHeight), child: row),
      );
    }
    return Semantics(
      key: Key('note_task_$index'),
      checked: checked,
      button: toggle != null,
      child: Padding(padding: EdgeInsets.only(top: toggle == null ? 3 : 0), child: row),
    );
  }
}

/// A rounded box in the synthesis accent colour, filled with a tick when [checked].
class _TaskBox extends StatelessWidget {
  final bool checked;

  const _TaskBox({super.key, required this.checked});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: checked ? AppColors.accentAI : Colors.transparent,
        borderRadius: BorderRadius.circular(4.5),
        border: Border.all(color: AppColors.accentAI, width: 1.5),
      ),
      child: checked ? const Icon(Icons.check_rounded, size: 12, color: AppColors.textPrimary) : null,
    );
  }
}
