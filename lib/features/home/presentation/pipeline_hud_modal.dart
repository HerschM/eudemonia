import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/synthesis/presentation/manual_synthesis.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_texts.dart';
import 'package:eudemonia/features/theme/app_colors.dart';
import 'package:eudemonia/features/theme/widgets/busy_action_button.dart';

class PipelineHudModal extends StatelessWidget {
  final int captureTranscribingCount;
  final int synthesisReadyCount;
  final VoidCallback onSynthesizeNow;
  /// Live memory line. Resolves after the sheet is already on screen so opening never waits on it.
  final Future<String> memoryTelemetry;

  /// A synthesis run is going: the button is disabled and shows the AI thinking in its place.
  final bool synthesizing;

  const PipelineHudModal({
    super.key,
    required this.captureTranscribingCount,
    required this.synthesisReadyCount,
    required this.onSynthesizeNow,
    required this.memoryTelemetry,
    this.synthesizing = false,
  });

  static void show(
    BuildContext context, {
    required int captureTranscribingCount,
    required int synthesisReadyCount,
    required VoidCallback onSynthesizeNow,
    required Future<String> memoryTelemetry,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppColors.modalRadius),
        ),
      ),
      // The sheet stays open while a run starts and ends, so it follows the run itself.
      builder: (context) => Consumer(
        builder: (context, ref, _) => PipelineHudModal(
          captureTranscribingCount: captureTranscribingCount,
          synthesisReadyCount: synthesisReadyCount,
          onSynthesizeNow: onSynthesizeNow,
          memoryTelemetry: memoryTelemetry,
          synthesizing: ref.watch(synthesisBusyProvider),
        ),
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
                const Icon(Icons.hub_outlined,
                    color: AppColors.accentAI, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Mind Pipeline Status',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('close_pipeline_hud_button'),
                  icon: const Icon(Icons.close,
                      size: 20, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Everything is processed on this phone',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 18),

            // Stage 1: Capture STT
            _buildStageTile(
              stageNumber: '1',
              stageName: 'Capture',
              description: captureTranscribingCount > 0
                  ? '$captureTranscribingCount audio recording transcribing'
                  : 'All raw voice recordings transcribed',
              statusColor: captureTranscribingCount > 0
                  ? AppColors.accentWarning
                  : AppColors.accentCapture,
              icon: captureTranscribingCount > 0
                  ? Icons.hourglass_top
                  : Icons.check_circle_outline,
            ),
            const SizedBox(height: 10),

            // Stage 2: Synthesis Clustering
            _buildStageTile(
              stageNumber: '2',
              stageName: 'Synthesis',
              description: synthesisReadyCount > 0
                  ? describeThoughtsReadyForSynthesis(synthesisReadyCount)
                  : 'All sessions consolidated',
              statusColor: synthesisReadyCount > 0
                  ? AppColors.accentAction
                  : AppColors.accentCapture,
              icon: synthesisReadyCount > 0
                  ? Icons.extension_outlined
                  : Icons.check_circle_outline,
              trailing: synthesisReadyCount > 0
                  ? BusyActionButton(
                      key: const Key('hud_synthesize_now_button'),
                      label: 'Synthesize Now',
                      busyLabel: 'Synthesizing…',
                      busy: synthesizing,
                      onPressed: () {
                        Navigator.pop(context);
                        onSynthesizeNow();
                      },
                    )
                  : null,
            ),
            const SizedBox(height: 18),

            // Memory Footprint telemetry footer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  const Icon(Icons.memory, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FutureBuilder<String>(
                      future: memoryTelemetry,
                      builder: (context, snapshot) => Text(
                        snapshot.data ?? 'Reading device memory…',
                        key: const Key('hud_memory_telemetry'),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildStageTile({
    required String stageNumber,
    required String stageName,
    required String description,
    required Color statusColor,
    required IconData icon,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.buttonRadius),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: statusColor, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stage $stageNumber: $stageName',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (trailing != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: trailing,
            ),
          ],
        ],
      ),
    );
  }
}

