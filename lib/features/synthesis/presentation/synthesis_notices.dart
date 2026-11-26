import 'package:flutter/material.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_texts.dart';
import 'package:eudemonia/features/theme/app_colors.dart';
import 'package:eudemonia/features/theme/widgets/busy_action_button.dart';

/// Shown above the list while no writing model is chosen: without one a run cannot start (FR16.5).
class ChooseWritingModelCard extends StatelessWidget {
  final VoidCallback onChoose;

  const ChooseWritingModelCard({super.key, required this.onChoose});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('choose_writing_model_card'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accentAI.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppColors.cardRadius),
        border: Border.all(color: AppColors.accentAI.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_outlined, size: 16, color: AppColors.accentAI),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Choose a writing model to turn your thoughts into notes.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            key: const Key('choose_writing_model_button'),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.accentAction,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(48, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: onChoose,
            child: const Text('Choose model', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// `N thoughts ready for Synthesis` with its `Synthesize Now` button, which shows the run while one is on.
class PendingThoughtsBanner extends StatelessWidget {
  final int pendingThoughts;
  final bool busy;
  final VoidCallback onSynthesizeNow;

  const PendingThoughtsBanner({
    super.key,
    required this.pendingThoughts,
    required this.busy,
    required this.onSynthesizeNow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('pending_synthesis_batch_banner'),
      margin: const EdgeInsets.only(top: 4, bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accentAI.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppColors.cardRadius),
        border: Border.all(color: AppColors.accentAI.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.extension_outlined, size: 16, color: AppColors.accentAI),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              describeThoughtsReadyForSynthesis(pendingThoughts),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
          BusyActionButton(
            key: const Key('synthesize_now_banner_button'),
            label: 'Synthesize Now',
            busyLabel: 'Synthesizing…',
            icon: Icons.bolt,
            busy: busy,
            onPressed: onSynthesizeNow,
          ),
        ],
      ),
    );
  }
}

/// The list when no note matches (or none exists yet), with a way to synthesize the waiting thoughts.
class EmptySynthesisState extends StatelessWidget {
  final int pendingThoughts;
  final bool busy;
  final VoidCallback onSynthesizeNow;

  const EmptySynthesisState({
    super.key,
    required this.pendingThoughts,
    required this.busy,
    required this.onSynthesizeNow,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 36.0),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: const Icon(Icons.hub_outlined, size: 32, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 16),
            const Text(
              'No synthesis sessions yet',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                'Thoughts captured in close proximity or sharing similar context will be automatically clustered here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary.withValues(alpha: 0.8)),
              ),
            ),
            if (pendingThoughts > 0) ...[
              const SizedBox(height: 16),
              BusyActionButton(
                label: 'Synthesize Thoughts Now',
                busyLabel: 'Synthesizing…',
                icon: Icons.bolt,
                busy: busy,
                onPressed: onSynthesizeNow,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                radius: 8,
                fontSize: 12,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
