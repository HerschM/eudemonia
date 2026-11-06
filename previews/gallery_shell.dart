import 'package:flutter/material.dart';
import 'mock_data.dart';
import 'preview_theme.dart';
import 'screens/capture_screen_preview.dart';
import 'screens/synthesis_screen_preview.dart';
import 'screens/insights_screen_preview.dart';
import 'screens/action_screen_preview.dart';
import 'screens/settings_preview.dart';

/// Top-level shell presenting the 4-Stage Cognitive Architecture
/// [ Capture • Synthesis • Insights • Action ]
/// Designed for isolated interactive testing and verification.
class GalleryShell extends StatefulWidget {
  final int initialIndex;

  const GalleryShell({super.key, this.initialIndex = 0});

  @override
  State<GalleryShell> createState() => _GalleryShellState();
}

class _GalleryShellState extends State<GalleryShell>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _stages = ['Capture', 'Synthesis', 'Insights', 'Action'];

  // Human Unconsumed Value Counts
  final int _captureUnreadCount = 2;
  int _synthesisUnreadCount = 1;
  final int _insightsUnreadCount = 1;
  final int _actionPendingCount = 3;

  // AI Pipeline Machine State
  late MockPipelineStatus _pipelineStatus;

  @override
  void initState() {
    super.initState();
    _pipelineStatus = MockData.pipelineStatus;
    _tabController = TabController(
      length: _stages.length,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _triggerSynthesizeNow() {
    setState(() {
      _pipelineStatus = MockPipelineStatus(
        captureTranscribingCount: _pipelineStatus.captureTranscribingCount,
        synthesisReadyCount: 0,
        insightsNextRefresh: _pipelineStatus.insightsNextRefresh,
        actionPendingCount: _pipelineStatus.actionPendingCount,
      );
      _synthesisUnreadCount += 1;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: PreviewTheme.surfaceElevated,
        content: const Row(
          children: [
            Icon(Icons.auto_awesome, color: PreviewTheme.accentAI, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Synthesized 2 raw thoughts into a new cluster!',
                style: TextStyle(color: PreviewTheme.textPrimary),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openPipelineHud() {
    PipelineHudModal.show(
      context,
      pipelineStatus: _pipelineStatus,
      onSynthesizeNow: _triggerSynthesizeNow,
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsPreview(),
      ),
    );
  }

  String _formatTabTitle(String stage) {
    int count = 0;
    switch (stage) {
      case 'Capture':
        count = _captureUnreadCount;
        break;
      case 'Synthesis':
        count = _synthesisUnreadCount;
        break;
      case 'Insights':
        count = _insightsUnreadCount;
        break;
      case 'Action':
        count = _actionPendingCount;
        break;
    }

    // Zero-Suppression Rule: omit count if zero to avoid clutter
    if (count <= 0) {
      return stage;
    }
    return '$stage ($count)';
  }

  @override
  Widget build(BuildContext context) {
    final hasActive = _pipelineStatus.hasActiveJobs;

    return Scaffold(
      backgroundColor: PreviewTheme.background,
      appBar: AppBar(
        backgroundColor: PreviewTheme.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16.0,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // App Branding
              const Text(
                'Eudemonia',
                style: TextStyle(
                  color: PreviewTheme.textPrimary,
                  fontSize: 18.0,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8.0),

              // Interactive AI Pipeline Status Pill
              Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const Key('top_ai_pipeline_pill'),
                  borderRadius: BorderRadius.circular(PreviewTheme.pillRadius),
                  onTap: _openPipelineHud,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: hasActive
                          ? PreviewTheme.accentAI.withValues(alpha: 0.18)
                          : PreviewTheme.accentCapture.withValues(alpha: 0.15),
                      borderRadius:
                          BorderRadius.circular(PreviewTheme.pillRadius),
                      border: Border.all(
                        color: hasActive
                            ? PreviewTheme.accentAI.withValues(alpha: 0.35)
                            : PreviewTheme.accentCapture.withValues(alpha: 0.3),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasActive ? Icons.bolt : Icons.check_circle_outline,
                          size: 13.0,
                          color: hasActive
                              ? PreviewTheme.accentAI
                              : PreviewTheme.accentCapture,
                        ),
                        const SizedBox(width: 4.0),
                        Text(
                          hasActive
                              ? '${_pipelineStatus.totalPending} in Pipeline ▾'
                              : 'In Sync ▾',
                          style: TextStyle(
                            color: hasActive
                                ? PreviewTheme.accentAI
                                : PreviewTheme.accentCapture,
                            fontSize: 11.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            key: const Key('settings_gear_button'),
            tooltip: 'Settings & Diagnostics',
            icon: const Icon(Icons.settings_outlined,
                color: PreviewTheme.textSecondary, size: 22.0),
            onPressed: _openSettings,
          ),
          const SizedBox(width: 8.0),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48.0),
          child: Container(
            height: 44.0,
            margin:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: PreviewTheme.surface,
              borderRadius: BorderRadius.circular(PreviewTheme.pillRadius),
              border: Border.all(color: PreviewTheme.borderSubtle, width: 1.0),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: PreviewTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(PreviewTheme.pillRadius),
                border: Border.all(color: PreviewTheme.borderFocus, width: 1.0),
              ),
              labelColor: PreviewTheme.textPrimary,
              unselectedLabelColor: PreviewTheme.textSecondary,
              labelStyle: const TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
              labelPadding: EdgeInsets.zero,
              tabs: _stages
                  .map((stage) => Tab(text: _formatTabTitle(stage)))
                  .toList(),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          CaptureScreenPreview(),
          SynthesisScreenPreview(),
          InsightsScreenPreview(),
          ActionScreenPreview(),
        ],
      ),
    );
  }
}

/// Interactive Mind Pipeline HUD Bottom Sheet
class PipelineHudModal extends StatelessWidget {
  final MockPipelineStatus pipelineStatus;
  final VoidCallback onSynthesizeNow;

  const PipelineHudModal({
    super.key,
    required this.pipelineStatus,
    required this.onSynthesizeNow,
  });

  static void show(
    BuildContext context, {
    required MockPipelineStatus pipelineStatus,
    required VoidCallback onSynthesizeNow,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: PreviewTheme.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(PreviewTheme.modalRadius),
        ),
      ),
      builder: (context) => PipelineHudModal(
        pipelineStatus: pipelineStatus,
        onSynthesizeNow: onSynthesizeNow,
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
                  color: PreviewTheme.textTertiary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.hub_outlined,
                    color: PreviewTheme.accentAI, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Mind Pipeline Status',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: PreviewTheme.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close,
                      size: 20, color: PreviewTheme.textSecondary),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'On-Device AI Inference Engine (Sherpa-ONNX STT & Qwen 2.5)',
              style: TextStyle(
                fontSize: 12,
                color: PreviewTheme.textSecondary.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 18),

            // Stage 1: Capture STT
            _buildStageTile(
              stageNumber: '1',
              stageName: 'Capture',
              description: pipelineStatus.captureTranscribingCount > 0
                  ? '${pipelineStatus.captureTranscribingCount} audio recording transcribing (#06)'
                  : 'All raw voice recordings transcribed',
              statusColor: pipelineStatus.captureTranscribingCount > 0
                  ? PreviewTheme.accentWarning
                  : PreviewTheme.accentCapture,
              icon: pipelineStatus.captureTranscribingCount > 0
                  ? Icons.hourglass_top
                  : Icons.check_circle_outline,
            ),
            const SizedBox(height: 10),

            // Stage 2: Synthesis Clustering
            _buildStageTile(
              stageNumber: '2',
              stageName: 'Synthesis',
              description: pipelineStatus.synthesisReadyCount > 0
                  ? '${pipelineStatus.synthesisReadyCount} raw thoughts ready to cluster'
                  : 'All sessions consolidated',
              statusColor: pipelineStatus.synthesisReadyCount > 0
                  ? PreviewTheme.accentAction
                  : PreviewTheme.accentCapture,
              icon: pipelineStatus.synthesisReadyCount > 0
                  ? Icons.extension_outlined
                  : Icons.check_circle_outline,
              trailing: pipelineStatus.synthesisReadyCount > 0
                  ? ElevatedButton(
                      key: const Key('hud_synthesize_now_button'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PreviewTheme.accentAction,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        onSynthesizeNow();
                      },
                      child: const Text(
                        'Synthesize Now',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 10),

            // Stage 3: Insights Mining
            _buildStageTile(
              stageNumber: '3',
              stageName: 'Insights',
              description:
                  'Next daily refresh in ${pipelineStatus.insightsNextRefresh} (periodic compute guard)',
              statusColor: PreviewTheme.accentAI,
              icon: Icons.auto_awesome,
            ),
            const SizedBox(height: 10),

            // Stage 4: Action Extraction
            _buildStageTile(
              stageNumber: '4',
              stageName: 'Action',
              description: pipelineStatus.actionPendingCount > 0
                  ? '${pipelineStatus.actionPendingCount} sessions awaiting task extraction'
                  : 'All action commitments extracted',
              statusColor: pipelineStatus.actionPendingCount > 0
                  ? PreviewTheme.accentWarning
                  : PreviewTheme.accentCapture,
              icon: pipelineStatus.actionPendingCount > 0
                  ? Icons.schedule
                  : Icons.check_circle_outline,
            ),
            const SizedBox(height: 18),

            // Memory Footprint telemetry footer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PreviewTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: PreviewTheme.borderSubtle),
              ),
              child: const Row(
                children: [
                  Icon(Icons.memory, size: 16, color: PreviewTheme.textSecondary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ready: ~1.58 GB RAM • 3m Inactivity Eviction Active',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: PreviewTheme.textSecondary,
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
        color: PreviewTheme.surface,
        borderRadius: BorderRadius.circular(PreviewTheme.buttonRadius),
        border: Border.all(color: PreviewTheme.borderSubtle),
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
                        color: PreviewTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: PreviewTheme.textSecondary.withValues(alpha: 0.9),
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
