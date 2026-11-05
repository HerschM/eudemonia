import 'package:flutter/material.dart';
import '../mock_data.dart';
import '../preview_theme.dart';

class StyleRewriterModal extends StatelessWidget {
  final MockCaptureNote note;
  final ValueChanged<MockStylePreset>? onSelectPreset;

  const StyleRewriterModal({
    super.key,
    required this.note,
    this.onSelectPreset,
  });

  static Future<void> show(
    BuildContext context, {
    required MockCaptureNote note,
    ValueChanged<MockStylePreset>? onSelectPreset,
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
      builder: (context) => StyleRewriterModal(
        note: note,
        onSelectPreset: onSelectPreset,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: PreviewTheme.accentAI, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'AI Style Re-Writer',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: PreviewTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: PreviewTheme.numberBadgeBg,
                    borderRadius: BorderRadius.circular(PreviewTheme.badgeRadius),
                  ),
                  child: Text(
                    note.formattedSequence,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: PreviewTheme.numberBadgeText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Select an on-device prompt preset to rewrite this thought:',
              style: TextStyle(
                fontSize: 13,
                color: PreviewTheme.textSecondary.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: MockData.stylePresets.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final preset = MockData.stylePresets[index];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(PreviewTheme.buttonRadius),
                      onTap: () {
                        Navigator.pop(context);
                        onSelectPreset?.call(preset);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
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
                                color: PreviewTheme.accentAI.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(preset.icon, color: PreviewTheme.accentAI, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    preset.name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: PreviewTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    preset.outputFormat,
                                    style: const TextStyle(
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
