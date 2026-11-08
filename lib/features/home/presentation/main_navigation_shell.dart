import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/theme/app_colors.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_service.dart';
import 'package:eudemonia/features/ai_processing/model_lifecycle_manager.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/settings/settings_screen.dart';
import 'package:eudemonia/features/home/home_screen.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_screen.dart';
import 'package:eudemonia/features/insights/presentation/insights_placeholder_screen.dart';
import 'package:eudemonia/features/action/presentation/action_placeholder_screen.dart';
import 'package:eudemonia/features/home/presentation/pipeline_hud_modal.dart';

class MainNavigationShell extends ConsumerStatefulWidget {
  final int initialIndex;

  const MainNavigationShell({super.key, this.initialIndex = 0});

  @override
  ConsumerState<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _stages = ['Capture', 'Synthesis', 'Insights', 'Action'];
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _tabController = TabController(
      length: _stages.length,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        if (_tabController.index >= 2) {
          // Insights and Action are placeholders, greyed out and unclickable
          _tabController.animateTo(_currentIndex);
        } else {
          setState(() {
            _currentIndex = _tabController.index;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openPipelineHud({
    required int queueCount,
    required int readyToClusterCount,
    required VoidCallback onSynthesizeNow,
    required String memoryTelemetry,
  }) {
    PipelineHudModal.show(
      context,
      captureTranscribingCount: queueCount,
      synthesisReadyCount: readyToClusterCount,
      onSynthesizeNow: onSynthesizeNow,
      memoryTelemetry: memoryTelemetry,
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  String _formatTabTitle(String stage, int unreadCount) {
    if (stage == 'Insights' || stage == 'Action') {
      return stage;
    }
    // Zero-Suppression Rule: omit count if zero to avoid clutter
    if (unreadCount <= 0) {
      return stage;
    }
    return '$stage ($unreadCount)';
  }

  @override
  Widget build(BuildContext context) {
    final pendingQueueCount = ref.watch(pendingQueueCountProvider);
    final notesAsync = ref.watch(recentNotesProvider);
    final rawNotesCountAsync = ref.watch(rawNotesReadyToClusterCountProvider);
    final synthesisClusters = ref.watch(synthesisRepositoryProvider);
    final modelLifecycle = ref.watch(modelLifecycleManagerProvider);

    final readyToClusterCount = rawNotesCountAsync.value ?? 0;
    final totalPipelinePending = pendingQueueCount + readyToClusterCount;
    final hasActivePipeline = totalPipelinePending > 0;

    // Unread count for Capture
    final unreadCaptureNotesCount = notesAsync.value?.where((n) => !n.isRead).length ?? 0;
    final totalCaptureUnread = unreadCaptureNotesCount + pendingQueueCount;

    // Unread count for Synthesis
    final totalSynthesisUnread = synthesisClusters.where((c) => c.isUnread).length;

    // Memory status
    final isReady = modelLifecycle.areModelsLoaded;
    final memTelemetry = isReady
        ? 'Ready: ~1.58 GB RAM • 3m Inactivity Eviction Active'
        : 'Baseline: <60 MB RAM • Models Unloaded';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
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
                  color: AppColors.textPrimary,
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
                  borderRadius: BorderRadius.circular(AppColors.pillRadius),
                  onTap: () => _openPipelineHud(
                    queueCount: pendingQueueCount,
                    readyToClusterCount: readyToClusterCount,
                    onSynthesizeNow: () async {
                      await ref
                          .read(synthesisRepositoryProvider.notifier)
                          .synthesizeRawNotes();
                      ref.invalidate(rawNotesReadyToClusterCountProvider);
                      ref.invalidate(recentNotesProvider);
                    },
                    memoryTelemetry: memTelemetry,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: hasActivePipeline
                          ? AppColors.accentAI.withValues(alpha: 0.18)
                          : AppColors.accentCapture.withValues(alpha: 0.15),
                      borderRadius:
                          BorderRadius.circular(AppColors.pillRadius),
                      border: Border.all(
                        color: hasActivePipeline
                            ? AppColors.accentAI.withValues(alpha: 0.35)
                            : AppColors.accentCapture.withValues(alpha: 0.3),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasActivePipeline ? Icons.bolt : Icons.check_circle_outline,
                          size: 13.0,
                          color: hasActivePipeline
                              ? AppColors.accentAI
                              : AppColors.accentCapture,
                        ),
                        const SizedBox(width: 4.0),
                        Text(
                          hasActivePipeline
                              ? '$totalPipelinePending in Pipeline ▾'
                              : 'In Sync ▾',
                          style: TextStyle(
                            color: hasActivePipeline
                                ? AppColors.accentAI
                                : AppColors.accentCapture,
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
                color: AppColors.textSecondary, size: 22.0),
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
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppColors.pillRadius),
              border: Border.all(color: AppColors.borderSubtle, width: 1.0),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(AppColors.pillRadius),
                border: Border.all(color: AppColors.borderFocus, width: 1.0),
              ),
              labelColor: AppColors.textPrimary,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
              labelPadding: EdgeInsets.zero,
              onTap: (index) {
                if (index >= 2) {
                  // Keep on active tab, do not switch to unclickable placeholder tabs
                  _tabController.animateTo(_currentIndex);
                } else {
                  setState(() {
                    _currentIndex = index;
                  });
                }
              },
              tabs: [
                Tab(text: _formatTabTitle('Capture', totalCaptureUnread)),
                Tab(text: _formatTabTitle('Synthesis', totalSynthesisUnread)),
                const Tab(
                  child: Opacity(
                    opacity: 0.38,
                    child: Text('Insights'),
                  ),
                ),
                const Tab(
                  child: Opacity(
                    opacity: 0.38,
                    child: Text('Action'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          HomeScreen(showAppBar: false),
          SynthesisScreen(),
          InsightsPlaceholderScreen(),
          ActionPlaceholderScreen(),
        ],
      ),
    );
  }
}

