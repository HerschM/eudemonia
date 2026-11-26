import 'package:flutter/material.dart';
import 'package:eudemonia/features/synthesis/presentation/note_markdown.dart';
import 'package:eudemonia/features/theme/app_colors.dart';

/// Read-only rendering of a synthesized note's light Markdown (see [parseNoteMarkdown]).
/// Not selectable by itself; wrap in a `SelectionArea` where selection is wanted.
class NoteMarkdownView extends StatelessWidget {
  final String text;

  /// Body style; defaults to the synthesis card body style.
  final TextStyle? style;

  /// Draws only the first blocks, for a collapsed card.
  final int? maxBlocks;

  const NoteMarkdownView({
    super.key,
    required this.text,
    this.style,
    this.maxBlocks,
  });

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
}
