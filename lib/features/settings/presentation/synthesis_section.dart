import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/synthesis/application/synthesis_settings.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/synthesis/presentation/manual_synthesis.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_texts.dart';
import 'package:eudemonia/features/theme/app_colors.dart';
import 'package:eudemonia/features/theme/widgets/thinking_indicator.dart';

import 'settings_card.dart';

/// When Synthesis starts by itself (thought count, quiet period) and the button to start it now.
class AutomaticSynthesisSection extends ConsumerWidget {
  const AutomaticSynthesisSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rawNotesCountAsync = ref.watch(rawNotesReadyToClusterCountProvider);
    final bufferCount = rawNotesCountAsync.value ?? 0;
    final synthesisSettings = ref.watch(synthesisSettingsProvider);
    // True from the moment a run is requested, like every other Synthesize control.
    final synthesisRunning = ref.watch(synthesisBusyProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader('AUTOMATIC SYNTHESIS'),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppColors.cardRadius),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Synthesis turns waiting thoughts into notes by itself. Choose when it starts.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              // Threshold 1: Trigger after X capture thoughts
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Start after this many thoughts',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Synthesis starts once this many thoughts are waiting.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    key: const Key('synthesis_note_threshold_dropdown'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(
                        AppColors.buttonRadius,
                      ),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: synthesisSettings.noteThreshold,
                        dropdownColor: AppColors.surfaceElevated,
                        isDense: true,
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: AppColors.accentAction,
                          size: 20,
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        items: const [1, 2, 3, 5, 8, 10].map((count) {
                          return DropdownMenuItem<int>(
                            value: count,
                            child: Text(
                              '$count ${count == 1 ? 'note' : 'notes'}',
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            ref
                                .read(synthesisSettingsProvider.notifier)
                                .setNoteThreshold(val);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20, color: AppColors.borderSubtle),
              // Threshold 2: Trigger after Y minutes of session quiet
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Or after a quiet period',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Synthesis also starts when no new thought has arrived for this long.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    key: const Key('synthesis_inactivity_minutes_dropdown'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(
                        AppColors.buttonRadius,
                      ),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: synthesisSettings.inactivityMinutes,
                        dropdownColor: AppColors.surfaceElevated,
                        isDense: true,
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: AppColors.accentAction,
                          size: 20,
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        items: const [5, 10, 15, 30, 45, 60].map((mins) {
                          return DropdownMenuItem<int>(
                            value: mins,
                            child: Text('$mins mins'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            ref
                                .read(synthesisSettingsProvider.notifier)
                                .setInactivityMinutes(val);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20, color: AppColors.borderSubtle),
              // Buffer Status & Instant Override Trigger
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 20,
                      color: AppColors.accentAction,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bufferCount == 0
                                ? 'No thoughts waiting'
                                : describeThoughtsReadyForSynthesis(
                                    bufferCount,
                                  ),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Starts by itself when the settings above are met',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      key: const Key('synthesize_buffer_now_button'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentAction,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppColors.badgeRadius,
                          ),
                        ),
                      ),
                      onPressed: bufferCount > 0 && !synthesisRunning
                          ? () => startManualSynthesis(context)
                          : null,
                      child: synthesisRunning
                          ? const ThinkingIndicator(
                              label: 'Synthesizing…',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                              ),
                            )
                          : const Text(
                              'Synthesize Now',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
