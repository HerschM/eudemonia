import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/theme/app_colors.dart';
import 'package:eudemonia/features/home/application/pipeline_status.dart';
import 'package:eudemonia/features/home/application/shell_state.dart';
import 'package:eudemonia/features/models/application/model_library_controller.dart';
import 'package:eudemonia/features/models/application/model_settings.dart';
import 'package:eudemonia/features/models/presentation/model_setup_screen.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/settings/background_permission_service.dart';
import 'package:eudemonia/features/settings/settings_screen.dart';
import 'package:eudemonia/features/capture/capture_controller.dart';
import 'package:eudemonia/features/capture/presentation/capture_screen.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_screen.dart';
import 'package:eudemonia/features/home/presentation/shell_action_bar.dart';
import 'package:eudemonia/features/home/presentation/shell_top_bar.dart';

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
      // The capture service keeps the Record button ready and lets transcription and Synthesis
      // finish after the app is left. Started here, not by a screen: the shell may open on
      // Synthesis and never build the Capture screen.
      ref.read(backgroundPermissionServiceProvider).startForegroundService();
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
    // A raw thought asked for (from a Synthesis note or the search): show the Capture tab.
    ref.listen(captureFocusRequestProvider, (previous, noteId) {
      if (noteId != null) _tabController.animateTo(ShellTab.capture.index);
    });
    if (!_startTabDecided) return const Scaffold(backgroundColor: AppColors.background);
    final pendingQueueCount = ref.watch(pipelineStatusProvider.select((s) => s.transcribing));
    final notesAsync = ref.watch(recentNotesProvider);
    final synthesisClusters = ref.watch(synthesisRepositoryProvider);

    // Unread count for Capture
    // A thought counts until it has been seen, whatever its state (a synthesized one too).
    final unreadCaptureNotesCount = notesAsync.value?.where((n) => !n.isRead).length ?? 0;
    final totalCaptureUnread = unreadCaptureNotesCount + pendingQueueCount;

    // Unread count for Synthesis
    final totalSynthesisUnread = synthesisClusters.where((c) => c.isUnread).length;

    final keyboardUp = MediaQuery.viewInsetsOf(context).bottom > 0;
    final isRecording = ref.watch(captureControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      // The bottom row (write, search, record) belongs to the shell, so it shows on both tabs; being
      // the floating action button, a SnackBar is laid out above it and never covers it.
      // While the keyboard is up the row would sit on the text being edited (the in-place editors
      // of both screens) and on their Save / Cancel; it steps aside, except during a recording,
      // whose stop button must stay within reach.
      floatingActionButton: keyboardUp && !isRecording ? null : const ShellActionBar(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: Column(
        children: [
          ShellTopBar(
            controller: _tabController,
            captureLabel: _formatTabTitle('Capture', totalCaptureUnread),
            synthesisLabel: _formatTabTitle('Synthesis', totalSynthesisUnread),
            onOpenSettings: _openSettings,
          ),
          Expanded(
            // The top row already sits below the status bar: the pages must not leave that room
            // a second time (a page's own SafeArea would).
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              // Swiping the body moves between the stages like the bar does; each page keeps its state.
              child: TabBarView(
                controller: _tabController,
                children: const [
                  CaptureScreen(),
                  SynthesisScreen(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
