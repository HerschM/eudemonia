import 'package:flutter/material.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_texts.dart';
import 'package:eudemonia/features/theme/app_colors.dart';

/// Full-height sheet with the note's raw Markdown in one multi-line field, `Cancel` and `Save`.
/// [onSave] reports whether the text was accepted: an accepted text closes the sheet, a refused
/// one (empty) shows [emptyNoteRefusal] and keeps what was typed. Pure presentational widget.
/// Keys: `note_text_field`, `note_text_save_button`, `note_text_cancel_button`, `note_text_error`.
class NoteTextEditorSheet extends StatefulWidget {
  final String sequenceLabel;
  final String initialText;
  final Future<bool> Function(String text) onSave;

  const NoteTextEditorSheet({
    super.key,
    required this.sequenceLabel,
    required this.initialText,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required String sequenceLabel,
    required String initialText,
    required Future<bool> Function(String text) onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppColors.modalRadius)),
      ),
      builder: (context) => NoteTextEditorSheet(
        sequenceLabel: sequenceLabel,
        initialText: initialText,
        onSave: onSave,
      ),
    );
  }

  @override
  State<NoteTextEditorSheet> createState() => _NoteTextEditorSheetState();
}

class _NoteTextEditorSheetState extends State<NoteTextEditorSheet> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialText);
  bool _refused = false;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final accepted = await widget.onSave(_controller.text);
    if (!mounted) return;
    if (accepted) {
      Navigator.pop(context);
    } else {
      setState(() {
        _saving = false;
        _refused = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // The sheet shrinks with the keyboard instead of hiding the end of the text.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: double.infinity,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  TextButton(
                    key: const Key('note_text_cancel_button'),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                  Expanded(
                    child: Text(
                      'Edit ${widget.sequenceLabel}',
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                  ),
                  TextButton(
                    key: const Key('note_text_save_button'),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.accentAction,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _saving ? null : _save,
                    child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: TextField(
                  key: const Key('note_text_field'),
                  controller: _controller,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  keyboardType: TextInputType.multiline,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(fontSize: 14, height: 1.45, color: AppColors.textPrimary),
                  cursorColor: AppColors.accentAction,
                  onChanged: (_) {
                    if (_refused) setState(() => _refused = false);
                  },
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                      borderSide: const BorderSide(color: AppColors.borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                      borderSide: const BorderSide(color: AppColors.borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                      borderSide: const BorderSide(color: AppColors.accentAction),
                    ),
                  ),
                ),
              ),
              if (_refused)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    emptyNoteRefusal,
                    key: Key('note_text_error'),
                    style: TextStyle(fontSize: 12, color: AppColors.accentError),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
