import 'package:flutter/widgets.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';
import 'package:eudemonia/features/synthesis/presentation/note_markdown.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_texts.dart';
import 'package:eudemonia/features/theme/widgets/clipboard_copy.dart';

/// Copies [note] to the clipboard as plain readable text: its title (when it has one) and its
/// body without Markdown marks. The stored note is not touched.
Future<void> copyNote(BuildContext context, SynthesisCluster note) => copyToClipboard(
      context,
      noteTextForClipboard(noteHeadingTitle(note.synthesizedContent) ?? '', note.synthesizedContent),
    );
