import 'package:flutter/material.dart';
import 'package:eudemonia/features/synthesis/domain/note_style.dart';
import 'package:eudemonia/features/theme/app_colors.dart';

/// One row of the style picker, made from a [NoteStyleSpec]; the style's prompt stays in the domain.
class StylePreset {
  final String id;
  final String name;
  final IconData icon;
  final String description;

  const StylePreset({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
  });

  static const Map<String, IconData> _icons = {
    'organised': Icons.view_agenda_outlined,
    'concise': Icons.bolt,
    'bullets': Icons.format_list_bulleted,
    'professional': Icons.business_center,
    'journal': Icons.spa,
    'actionable': Icons.checklist,
    'casual': Icons.chat_bubble_outline,
  };

  /// Every style in picker order.
  static final List<StylePreset> defaultPresets = [
    for (final s in noteStyles)
      StylePreset(id: s.id, name: s.label, icon: _icons[s.id] ?? Icons.auto_awesome, description: s.description),
  ];
}

class StyleRewriterModal extends StatelessWidget {
  final String sequenceLabel;
  final String selectedPresetId;
  final ValueChanged<StylePreset>? onSelectPreset;

  const StyleRewriterModal({
    super.key,
    required this.sequenceLabel,
    this.selectedPresetId = defaultNoteStyleId,
    this.onSelectPreset,
  });

  static Future<void> show(
    BuildContext context, {
    required String sequenceLabel,
    String selectedPresetId = defaultNoteStyleId,
    ValueChanged<StylePreset>? onSelectPreset,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppColors.modalRadius),
        ),
      ),
      builder: (context) => StyleRewriterModal(
        sequenceLabel: sequenceLabel,
        selectedPresetId: selectedPresetId,
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
                  color: AppColors.textTertiary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppColors.accentAI, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'AI Style Re-Writer',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.numberBadgeBg,
                    borderRadius: BorderRadius.circular(AppColors.badgeRadius),
                  ),
                  child: Text(
                    sequenceLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.numberBadgeText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Select an on-device prompt preset to rewrite this synthesized note:',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: StylePreset.defaultPresets.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final preset = StylePreset.defaultPresets[index];
                  final isSelected = preset.id == selectedPresetId;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                      onTap: () {
                        Navigator.pop(context);
                        onSelectPreset?.call(preset);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.accentAI.withValues(alpha: 0.08)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.accentAI
                                : AppColors.borderSubtle,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.accentAI
                                    .withValues(alpha: isSelected ? 0.2 : 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(preset.icon,
                                  color: AppColors.accentAI, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          preset.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      if (isSelected) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.accentAI
                                                .withValues(alpha: 0.2),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'Active',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.accentAI,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    preset.description,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary
                                          .withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check,
                                  color: AppColors.accentAI, size: 20),
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

