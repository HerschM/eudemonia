import 'package:flutter/material.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_texts.dart';
import 'package:eudemonia/features/theme/app_colors.dart';

/// A note's text edited where it stands: one multi-line field holding the note's Markdown source,
/// focused at once, with `Cancel` and `Save` under it. [onSave] reports whether the text was
/// accepted: an accepted text ends the editing (the owner removes this widget), a refused one
/// (empty) shows [emptyNoteRefusal] and keeps what was typed. [onChanged] tells the owner what is
/// typed so a draft survives this widget being scrolled away. The field is brought into view when
/// it opens and when the keyboard comes up. Pure presentational widget.
/// Keys: `note_edit_field`, `note_edit_save`, `note_edit_cancel`, `note_edit_error`.
class NoteTextEditor extends StatefulWidget {
  final String initialText;
  final Future<bool> Function(String text) onSave;
  final VoidCallback onCancel;
  final ValueChanged<String>? onChanged;

  const NoteTextEditor({
    super.key,
    required this.initialText,
    required this.onSave,
    required this.onCancel,
    this.onChanged,
  });

  @override
  State<NoteTextEditor> createState() => _NoteTextEditorState();
}

class _NoteTextEditorState extends State<NoteTextEditor> with WidgetsBindingObserver {
  late final TextEditingController _controller = TextEditingController(text: widget.initialText)
    ..selection = TextSelection.collapsed(offset: widget.initialText.length);
  bool _refused = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // The Scaffold hides the keyboard's height from its body, so the screen's metrics are the signal.
    WidgetsBinding.instance.addObserver(this);
    _scheduleReveal(const Duration(milliseconds: 200));
  }

  /// The keyboard opening or closing (every frame of its animation): the list's viewport changed.
  @override
  void didChangeMetrics() => _scheduleReveal(Duration.zero);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  /// Scrolls the list just enough that the field and its buttons are on screen, above the keyboard.
  void _scheduleReveal(Duration duration) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.maybeOf(context)?.position.ensureVisible(
            context.findRenderObject()!,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
            duration: duration,
            curve: Curves.easeOut,
          );
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final accepted = await widget.onSave(_controller.text);
    if (!mounted) return;
    if (!accepted) {
      setState(() {
        _saving = false;
        _refused = true;
      });
    }
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppColors.buttonRadius),
        borderSide: BorderSide(color: color),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('note_edit_field'),
          controller: _controller,
          autofocus: true,
          minLines: 5,
          maxLines: 12,
          keyboardType: TextInputType.multiline,
          textAlignVertical: TextAlignVertical.top,
          style: const TextStyle(fontSize: 14, height: 1.45, color: AppColors.textPrimary),
          cursorColor: AppColors.accentAction,
          onChanged: (text) {
            widget.onChanged?.call(text);
            if (_refused) setState(() => _refused = false);
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.all(12),
            border: _border(AppColors.borderSubtle),
            enabledBorder: _border(AppColors.borderSubtle),
            focusedBorder: _border(AppColors.accentAction),
          ),
        ),
        if (_refused)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              emptyNoteRefusal,
              key: Key('note_edit_error'),
              style: TextStyle(fontSize: 12, color: AppColors.accentError),
            ),
          ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              key: const Key('note_edit_cancel'),
              onPressed: widget.onCancel,
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            const SizedBox(width: 8),
            TextButton(
              key: const Key('note_edit_save'),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.accentAction,
                foregroundColor: Colors.white,
              ),
              onPressed: _saving ? null : _save,
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ],
    );
  }
}
