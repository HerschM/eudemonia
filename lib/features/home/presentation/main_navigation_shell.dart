import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/theme/app_colors.dart';
import 'package:eudemonia/features/theme/widgets/thinking_indicator.dart';
import 'package:eudemonia/features/home/application/pipeline_status.dart';
import 'package:eudemonia/features/home/application/shell_state.dart';
import 'package:eudemonia/features/models/application/model_library_controller.dart';
import 'package:eudemonia/features/models/application/model_settings.dart';
import 'package:eudemonia/features/models/presentation/model_setup_screen.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/settings/settings_screen.dart';
import 'package:eudemonia/features/capture/presentation/capture_screen.dart';
import 'package:eudemonia/features/synthesis/presentation/manual_synthesis.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_screen.dart';
import 'package:eudemonia/features/home/presentation/pipeline_hud_modal.dart';
import 'package:eudemonia/features/home/presentation/shell_capture_capsule.dart';

class MainNavigationShell extends ConsumerStatefulWidget {
  /// The tab shown first. When null the shell opens on Synthesis if at least one synthesis note
  /// exists, else on Capture (a new user has nothing to read yet).
  final int? initialIndex;

  const MainNavigationShell({super.key, this.initialIndex});

  @override
  ConsumerState<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  /// False only while the start tab waits for the stored synthesis notes to load (see
  /// [_decideStartTab]); the shell then shows an empty page instead of a tab it may have to leave.
  bool _startTabDecided = true;

  @override
  void initState() {
    super.initState();
    final explicit = widget.initialIndex;
    final hasNotes = ref.read(synthesisRepositoryProvider).isNotEmpty;
    _tabController = TabController(
      length: ShellTab.values.length,
      vsync: this,
      initialIndex: explicit ?? (hasNotes ? ShellTab.synthesis.index : ShellTab.capture.index),
    );
    if (explicit == null && !hasNotes) {
      // Stored sessions load asynchronously and none are here yet: decide once they have, before
      // the first tab is drawn, so there is never a visible jump between tabs.
      _startTabDecided = false;
      ref.read(synthesisRepositoryProvider.notifier).hydrated.whenComplete(_decideStartTab);
    }
    // Taps, swipes and the jump from a Capture card's session number all move this one controller.
    _tabController.addListener(_publishSelectedTab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _publishSelectedTab();
      if (ref.read(shouldOfferModelSetupProvider)) _offerModelSetup();
    });
  }

  /// Opens Synthesis when stored notes turned up; either way the shell is drawn from here on.
  void _decideStartTab() {
    if (!mounted) return;
    if (ref.read(synthesisRepositoryProvider).isNotEmpty) _tabController.index = ShellTab.synthesis.index;
    setState(() => _startTabDecided = true);
    _publishSelectedTab();
  }

  /// Tells the screens which tab is in front (they read thoughts only while theirs is).
  void _publishSelectedTab() {
    if (!mounted) return;
    final tab = ShellTab.values[_tabController.index];
    if (ref.read(selectedShellTabProvider) != tab) ref.read(selectedShellTabProvider.notifier).select(tab);
  }

  /// First launch without a speech model: open the setup screen once, never again on its own.
  void _offerModelSetup() {
    ref.read(modelSettingsProvider.notifier).markSetupShown();
    openModelSetup(Navigator.of(context));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    // Zero-Suppression Rule: omit count if zero to avoid clutter
    if (unreadCount <= 0) {
      return stage;
    }
    return '$stage ($unreadCount)';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(shouldOfferModelSetupProvider, (previous, offer) {
      if (offer) _offerModelSetup();
    });
    // The session number on a Capture card asks for that note: show the Synthesis tab.
    ref.listen(synthesisFocusRequestProvider, (previous, clusterId) {
      if (clusterId != null) _tabController.animateTo(ShellTab.synthesis.index);
    });
    if (!_startTabDecided) return const Scaffold(backgroundColor: AppColors.background);
    // The chip and the status sheet are drawn from the same picture of the pipeline.
    final status = ref.watch(pipelineStatusProvider);
    final synthesisBusy = status.synthesizing;
    final pendingQueueCount = status.transcribing;
    final notesAsync = ref.watch(recentNotesProvider);
    final synthesisClusters = ref.watch(synthesisRepositoryProvider);
    final totalPipelinePending = status.pending;
    final hasActivePipeline = totalPipelinePending > 0;

    // Unread count for Capture
    // A thought counts until it has been seen, whatever its state (a synthesized one too).
    final unreadCaptureNotesCount = notesAsync.value?.where((n) => !n.isRead).length ?? 0;
    final totalCaptureUnread = unreadCaptureNotesCount + pendingQueueCount;

    // Unread count for Synthesis
    final totalSynthesisUnread = synthesisClusters.where((c) => c.isUnread).length;

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
                  onTap: () => PipelineHudModal.show(
                    context,
                    onSynthesizeNow: () => startManualSynthesis(context),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: synthesisBusy || hasActivePipeline
                          ? AppColors.accentAI.withValues(alpha: 0.18)
                          : AppColors.accentCapture.withValues(alpha: 0.15),
                      borderRadius:
                          BorderRadius.circular(AppColors.pillRadius),
                      border: Border.all(
                        color: synthesisBusy || hasActivePipeline
                            ? AppColors.accentAI.withValues(alpha: 0.35)
                            : AppColors.accentCapture.withValues(alpha: 0.3),
                        width: 1.0,
                      ),
                    ),
                    // While a synthesis run is on, the pill says so and shows the AI thinking.
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
            tooltip: 'Settings',
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
              // No rectangular ink frame around the rounded pill; the pill itself slides with the
              // swipe (it follows the controller's animation), so the tap needs no splash.
              splashFactory: NoSplash.splashFactory,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              indicatorAnimation: TabIndicatorAnimation.linear,
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
              tabs: [
                Tab(text: _formatTabTitle('Capture', totalCaptureUnread)),
                Tab(text: _formatTabTitle('Synthesis', totalSynthesisUnread)),
              ],
            ),
          ),
        ),
      ),
      // The record capsule belongs to the shell, so it shows on both tabs; being the floating action
      // button, a SnackBar is laid out beside it and never covers it.
      floatingActionButton: const ShellCaptureCapsule(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      // Swiping the body moves between the stages like the bar does; each page keeps its state.
      body: TabBarView(
        controller: _tabController,
        children: const [
          CaptureScreen(),
          SynthesisScreen(),
        ],
      ),
    );
  }
}

