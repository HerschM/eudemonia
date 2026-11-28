import 'package:flutter/material.dart';
import 'package:eudemonia/features/synthesis/domain/note_style.dart';
import 'package:eudemonia/features/theme/app_colors.dart';

/// Modal bottom sheet that lists every note style a folder can default to: one row per style
/// (`folder_style_option_<id>`) with its name and its description under it, the chosen one marked
/// with a check. Choosing a row closes the sheet and returns the style's id. Neutral colours, as
/// in the restyle sheet.
class FolderStyleSheet extends StatelessWidget {
  final String selectedId;

  const FolderStyleSheet({super.key, required this.selectedId});

  /// The chosen style's id, null when the sheet was dismissed.
  static Future<String?> show(BuildContext context, {required String selectedId}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppColors.modalRadius)),
      ),
      builder: (_) => FolderStyleSheet(selectedId: selectedId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Default style',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: noteStyles.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final style = noteStyles[index];
                final selected = style.id == selectedId;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: Key('folder_style_option_${style.id}'),
                    borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                    onTap: () => Navigator.pop(context, style.id),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.surfaceElevated : AppColors.surface,
                        borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                        border: Border.all(
                          color: selected ? AppColors.borderFocus : AppColors.borderSubtle,
                          width: selected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  style.label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  style.description,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          if (selected) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.check, size: 20, color: AppColors.textPrimary),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
