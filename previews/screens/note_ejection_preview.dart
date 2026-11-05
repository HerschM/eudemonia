import 'package:flutter/material.dart';
import '../mock_data.dart';
import '../preview_theme.dart';

class NoteEjectionModal extends StatelessWidget {
  final MockCaptureNote rawNote;
  final VoidCallback? onMoveToCluster;
  final VoidCallback? onMakeIndependent;

  const NoteEjectionModal({
    super.key,
    required this.rawNote,
    this.onMoveToCluster,
    this.onMakeIndependent,
  });

  static Future<void> show(
    BuildContext context, {
    required MockCaptureNote rawNote,
    VoidCallback? onMoveToCluster,
    VoidCallback? onMakeIndependent,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: PreviewTheme.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(PreviewTheme.modalRadius),
        ),
      ),
      builder: (context) => NoteEjectionModal(
        rawNote: rawNote,
        onMoveToCluster: onMoveToCluster,
        onMakeIndependent: onMakeIndependent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: PreviewTheme.textTertiary.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Reassign Raw Note [${rawNote.formattedSequence}]',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: PreviewTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '"${rawNote.cleanedText}"',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: PreviewTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            // Option 1: Move to another clubbed note
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(PreviewTheme.buttonRadius),
                onTap: () {
                  Navigator.pop(context);
                  onMoveToCluster?.call();
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: PreviewTheme.surface,
                    borderRadius: BorderRadius.circular(PreviewTheme.buttonRadius),
                    border: Border.all(color: PreviewTheme.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: PreviewTheme.accentAction.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.folder_open, color: PreviewTheme.accentAction, size: 20),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Move to Another Clubbed Note',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: PreviewTheme.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Choose from existing sessions or create new',
                              style: TextStyle(
                                fontSize: 12,
                                color: PreviewTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: PreviewTheme.textTertiary, size: 18),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Option 2: Make it an independent note
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(PreviewTheme.buttonRadius),
                onTap: () {
                  Navigator.pop(context);
                  onMakeIndependent?.call();
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: PreviewTheme.surface,
                    borderRadius: BorderRadius.circular(PreviewTheme.buttonRadius),
                    border: Border.all(color: PreviewTheme.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: PreviewTheme.accentCapture.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.description_outlined, color: PreviewTheme.accentCapture, size: 20),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Make It An Independent Note',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: PreviewTheme.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Detach and generate a separate synthesized note',
                              style: TextStyle(
                                fontSize: 12,
                                color: PreviewTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: PreviewTheme.textTertiary, size: 18),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: PreviewTheme.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }
}
