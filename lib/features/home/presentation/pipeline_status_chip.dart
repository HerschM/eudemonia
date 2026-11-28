import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/home/application/pipeline_status.dart';
import 'package:eudemonia/features/home/presentation/pipeline_hud_modal.dart';
import 'package:eudemonia/features/synthesis/presentation/manual_synthesis.dart';
import 'package:eudemonia/features/theme/app_colors.dart';
import 'package:eudemonia/features/theme/widgets/thinking_indicator.dart';

/// Widest the chip is drawn; a longer text scales down to fit instead of pushing the tabs.
const double pipelineChipMaxWidth = 124.0;

/// The pipeline status chip of the shell's top row: `Synthesizing…` while a run is on,
/// `N in Pipeline ▾` while thoughts wait, else `In Sync ▾`. Tapping it opens the status sheet.
/// Drawn from [pipelineStatusProvider], the same picture the sheet shows.
class PipelineStatusChip extends ConsumerWidget {
  const PipelineStatusChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(pipelineStatusProvider);
    final synthesisBusy = status.synthesizing;
    final hasActivePipeline = status.pending > 0;
    final active = synthesisBusy || hasActivePipeline;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: pipelineChipMaxWidth),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('top_ai_pipeline_pill'),
            borderRadius: BorderRadius.circular(AppColors.pillRadius),
            onTap: () => PipelineHudModal.show(
              context,
              onSynthesizeNow: () => startManualSynthesis(context),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.5),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.accentAI.withValues(alpha: 0.18)
                    : AppColors.accentCapture.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppColors.pillRadius),
                border: Border.all(
                  color: active
                      ? AppColors.accentAI.withValues(alpha: 0.35)
                      : AppColors.accentCapture.withValues(alpha: 0.3),
                  width: 1.0,
                ),
              ),
              // While a synthesis run is on, the chip says so and shows the AI thinking.
              child: synthesisBusy
                  ? const ThinkingIndicator(
                      label: 'Synthesizing…',
                      style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.w600),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasActivePipeline ? Icons.bolt : Icons.check_circle_outline,
                          size: 13.0,
                          color: hasActivePipeline ? AppColors.accentAI : AppColors.accentCapture,
                        ),
                        const SizedBox(width: 4.0),
                        Text(
                          hasActivePipeline ? '${status.pending} in Pipeline ▾' : 'In Sync ▾',
                          style: TextStyle(
                            color: hasActivePipeline ? AppColors.accentAI : AppColors.accentCapture,
                            fontSize: 11.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
