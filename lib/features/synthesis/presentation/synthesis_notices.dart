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
          const Icon(Icons.hub_outlined, size: 16, color: AppColors.accentAI),
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
/// With [unwrittenThoughts] above zero (waiting thoughts that already failed a run, and no run on
/// now) a second line in the warning colour (`synthesis_unwritten_notice`) says why nothing was written.
class PendingThoughtsBanner extends StatelessWidget {
  final int pendingThoughts;
  final int unwrittenThoughts;
  final bool busy;
  final VoidCallback onSynthesizeNow;

  const PendingThoughtsBanner({
    super.key,
    required this.pendingThoughts,
    required this.busy,
    required this.onSynthesizeNow,
    this.unwrittenThoughts = 0,
  });

  @override
  Widget build(BuildContext context) {
    // While a run is on, the thoughts are being tried again: last time's failure is not news.
    final showUnwritten = unwrittenThoughts > 0 && !busy;
    return Container(
      key: const Key('pending_synthesis_batch_banner'),
      margin: const EdgeInsets.only(top: 4, bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accentAI.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppColors.cardRadius),
        border: Border.all(color: AppColors.accentAI.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          if (showUnwritten)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(Icons.info_outline, size: 14, color: AppColors.accentWarning),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      describeUnwrittenThoughts(unwrittenThoughts),
                      key: const Key('synthesis_unwritten_notice'),
                      style: const TextStyle(fontSize: 11.5, height: 1.35, color: AppColors.accentWarning),
                    ),
                  ),
                ],
              ),
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
