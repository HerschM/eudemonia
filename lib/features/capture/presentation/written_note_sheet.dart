import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/capture/written_note_capture.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/theme/app_colors.dart';

/// Opens the compose sheet for a written thought: a bottom sheet that rises with the keyboard,
/// with a multi-line field (`written_note_field`, hint `Write a thought`), `Save`
/// (`written_note_save`, disabled while the text is empty) and `Cancel`. Saving stores the thought
/// through [WrittenNoteCapture], closes the sheet and says `Saved a written note [#NN]`. Closing
/// with text typed (Cancel, back, a tap outside, a swipe down) asks `Discard this note?` first
/// (`written_note_discard_keep`, `written_note_discard_confirm`), so text is never lost silently.
Future<void> showWrittenNoteSheet(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final saved = await showModalBottomSheet<Note>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppColors.modalRadius)),
    ),
    builder: (_) => const _WrittenNoteSheet(),
  );
  if (saved == null) return;
  final number = saved.dailySequenceNumber;
  messenger.showSnackBar(
    SnackBar(
      backgroundColor: AppColors.surfaceElevated,
      duration: const Duration(seconds: 2),
      content: Text(
        number == null ? 'Saved a written note' : 'Saved a written note [#${number.toString().padLeft(2, '0')}]',
        style: const TextStyle(color: AppColors.textPrimary),
      ),
    ),
  );
}

class _WrittenNoteSheet extends ConsumerStatefulWidget {
  const _WrittenNoteSheet();

  @override
  ConsumerState<_WrittenNoteSheet> createState() => _WrittenNoteSheetState();
}

class _WrittenNoteSheetState extends ConsumerState<_WrittenNoteSheet> {
  final TextEditingController _text = TextEditingController();
  bool _saving = false;

  bool get _hasText => _text.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_hasText) return;
    setState(() => _saving = true);
    final Note? note;
    try {
      note = await ref.read(writtenNoteCaptureProvider).save(_text.text);
    } catch (_) {
      // The text stays in the field so the user can try again.
      if (mounted) setState(() => _saving = false);
      rethrow;
    }
    if (!mounted) return;
    Navigator.of(context).pop(note);
  }

  /// Runs when a close is asked for while there is text (the sheet could not close by itself).
  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Discard this note?', style: TextStyle(fontSize: 16, color: AppColors.textPrimary)),
        actions: [
          TextButton(
            key: const Key('written_note_discard_keep'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep writing', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            key: const Key('written_note_discard_confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard', style: TextStyle(color: AppColors.accentError, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasText || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Padding(
        // Rises with the keyboard.
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.draw_outlined, size: 18, color: AppColors.accentAction),
                  SizedBox(width: 8),
                  Text(
                    'Written note',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('written_note_field'),
                controller: _text,
                autofocus: true,
                minLines: 3,
                maxLines: 8,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 15, height: 1.4, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Write a thought',
                  hintStyle: const TextStyle(color: AppColors.textTertiary),
                  filled: true,
                  fillColor: AppColors.surface,
                  isDense: true,
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
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: const Key('written_note_cancel'),
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    key: const Key('written_note_save'),
                    onPressed: _hasText && !_saving ? _save : null,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
