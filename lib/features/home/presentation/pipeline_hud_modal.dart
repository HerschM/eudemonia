import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/ai_processing/resident_model.dart';
import 'package:eudemonia/features/home/application/pipeline_status.dart';
import 'package:eudemonia/features/settings/system_telemetry_service.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_texts.dart';
import 'package:eudemonia/features/theme/app_colors.dart';
import 'package:eudemonia/features/theme/widgets/busy_action_button.dart';

/// How often the memory line is read again while the sheet is open (never while it is closed).
const Duration pipelineHudRefreshInterval = Duration(seconds: 2);

/// The sheet's memory line: the model in memory and the latest OS reading; nothing is estimated.
String describePipelineMemoryLine(ResidentModel model, SystemTelemetry? telemetry) {
  final parts = <String>[describeResidentModel(model)];
  final appMemory = telemetry?.appMemoryLabel;
  final deviceMemory = telemetry?.deviceMemoryLabel;
  if (appMemory != null) parts.add('App memory $appMemory');
  if (deviceMemory != null) parts.add('Device $deviceMemory');
  if (appMemory == null && deviceMemory == null) parts.add('live memory reading unavailable');
  return parts.join(' • ');
}

String _notes(int count) => '$count ${count == 1 ? 'note' : 'notes'}';

/// The Synthesis stage line. A run going says so, also a rewrite or restyle with no new thoughts.
String describeSynthesisStage({required int readyThoughts, required int rewriting, required bool synthesizing}) {
  if (readyThoughts > 0) return describeThoughtsReadyForSynthesis(readyThoughts);
  if (synthesizing) return rewriting > 0 ? 'Rewriting ${_notes(rewriting)}' : 'Writing your notes';
  if (rewriting > 0) return '${_notes(rewriting)} waiting to be rewritten';
  return 'All sessions consolidated';
}

class PipelineHudModal extends StatelessWidget {
  final int captureTranscribingCount;
  final int synthesisReadyCount;

  /// Notes flagged to be rewritten.
  final int rewritingCount;
  final VoidCallback onSynthesizeNow;

  /// The memory line; null until the first reading, so opening never waits on it.
  final String? memoryLine;

  /// A synthesis run is going: the button is disabled and shows the AI thinking in its place.
  final bool synthesizing;

  const PipelineHudModal({
    super.key,
    required this.captureTranscribingCount,
    required this.synthesisReadyCount,
    required this.onSynthesizeNow,
    this.memoryLine,
    this.rewritingCount = 0,
    this.synthesizing = false,
  });

  /// Opens the sheet. It reads the live status itself ([pipelineStatusProvider]) for as long as
  /// it is open.
  static void show(BuildContext context, {required VoidCallback onSynthesizeNow}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppColors.modalRadius),
        ),
      ),
      // The sheet stays open while a run starts and ends, so it follows the pipeline itself.
      builder: (context) => LivePipelineHud(onSynthesizeNow: onSynthesizeNow),
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
              description: describeSynthesisStage(
                readyThoughts: synthesisReadyCount,
                rewriting: rewritingCount,
                synthesizing: synthesizing,
              ),
              statusColor: synthesisReadyCount > 0
                  ? AppColors.accentAction
                  : synthesizing || rewritingCount > 0
                      ? AppColors.accentAI
                      : AppColors.accentCapture,
              icon: synthesisReadyCount > 0
                  ? Icons.extension_outlined
                  : synthesizing || rewritingCount > 0
                      ? Icons.hourglass_top
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
                    child: Text(
                      memoryLine ?? 'Reading device memory…',
                      key: const Key('hud_memory_telemetry'),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
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


/// The sheet as shown: every line from [pipelineStatusProvider], and the memory read again every
/// [pipelineHudRefreshInterval] while it is open. The timer lives exactly as long as the sheet.
class LivePipelineHud extends ConsumerStatefulWidget {
  final VoidCallback onSynthesizeNow;

  const LivePipelineHud({super.key, required this.onSynthesizeNow});

  @override
  ConsumerState<LivePipelineHud> createState() => _LivePipelineHudState();
}

class _LivePipelineHudState extends ConsumerState<LivePipelineHud> {
  Timer? _refresh;
  SystemTelemetry? _telemetry;
  bool _hasReading = false;

  @override
  void initState() {
    super.initState();
    _readMemory();
    _refresh = Timer.periodic(pipelineHudRefreshInterval, (_) => _readMemory());
  }

  Future<void> _readMemory() async {
    final reading = await ref.read(systemTelemetryServiceProvider).read();
    if (!mounted) return;
    setState(() {
      _telemetry = reading;
      _hasReading = true;
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(pipelineStatusProvider);
    return PipelineHudModal(
      captureTranscribingCount: status.transcribing,
      synthesisReadyCount: status.readyThoughts,
      rewritingCount: status.rewriting,
      synthesizing: status.synthesizing,
      onSynthesizeNow: widget.onSynthesizeNow,
      memoryLine: _hasReading
          ? describePipelineMemoryLine(status.residentModel, _telemetry)
          : '${describeResidentModel(status.residentModel)} • Reading device memory…',
    );
  }
}
