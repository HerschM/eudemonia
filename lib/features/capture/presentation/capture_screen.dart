import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_item.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_service.dart';
import 'package:eudemonia/features/capture/presentation/capture_view_bar.dart';
import 'package:eudemonia/features/capture/presentation/capture_view_filter.dart';
import 'package:eudemonia/features/capture/presentation/capture_view_panel.dart';
import 'package:eudemonia/features/capture/presentation/thought_delete_wording.dart';
import 'package:eudemonia/features/capture/thought_actions.dart';
import 'package:eudemonia/features/home/application/shell_state.dart';
import 'package:eudemonia/features/models/application/model_library_controller.dart';
import 'package:eudemonia/features/models/presentation/model_setup_screen.dart';
import 'package:eudemonia/features/models/presentation/model_setup_texts.dart';
import 'package:eudemonia/features/notes/audio_playback_controller.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/notes/presentation/thought_card.dart';
import 'package:eudemonia/features/settings/background_permission_service.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/synthesis/domain/session_numbering.dart';
import 'package:eudemonia/features/synthesis/presentation/folder_panel.dart';
import 'package:eudemonia/features/theme/app_colors.dart';
import 'package:eudemonia/features/theme/widgets/clipboard_copy.dart';
import 'package:eudemonia/features/theme/widgets/confirm_delete_dialog.dart';
import 'package:eudemonia/features/theme/widgets/day_header.dart';
import 'package:eudemonia/features/theme/widgets/pulse_dots_loader.dart';
import 'package:eudemonia/features/theme/widgets/read_on_dwell.dart';

/// Stage 1 — Capture: the unfiltered, state-coded stream of raw thoughts.
///
/// Thoughts carry no folder here (folders belong to Synthesis). Machine
/// pipeline status lives in the navigation shell's Pipeline HUD, not on this screen. The record
/// capsule belongs to the shell, so it is on every tab.
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  CaptureTriageFilter _triageFilter = CaptureTriageFilter.all;
  CaptureStatusFilter _statusFilter = CaptureStatusFilter.all;

  /// Thoughts that have been listed while Unread or Read is showing. They stay listed after their
  /// read state changes (a thought read while the user looks at it must not vanish); the set is
  /// dropped when a triage filter is picked, and with the screen.
  final Set<int> _keptUnderTriage = {};

  /// The view panel (Show and Status) is laid over the list.
  bool _panelOpen = false;

  /// One per card, for scrolling a thought into view.
  final Map<int, GlobalKey> _cardKeys = {};

  /// Every card is built (not only those near the viewport) while one is being scrolled to.
  bool _buildAllCards = false;
  int? _highlightedId;
  Timer? _highlightTimer;
  final ScrollController _scrollController = ScrollController();
  static const _highlightDuration = Duration(milliseconds: 1500);

  /// The shell swipes between tabs; this one keeps its scroll position and filters while away.
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // A request made before this screen existed (first visit through a Synthesis note's thought).
      if (mounted) unawaited(_handleFocusRequest(ref.read(captureFocusRequestProvider)));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _highlightTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(backgroundPermissionStatusProvider);
    }
  }

  /// Merges persisted notes with in-flight and failed queue items into one feed, newest first.
  List<Note> _unifiedThoughts(List<Note> persistedNotes, List<AudioQueueItem> queueItems) {
    final persistedAudioPaths = {
      for (final n in persistedNotes)
        if (n.originalAudioPath != null) n.originalAudioPath!,
    };
    final queueNotes = <Note>[];
    for (final item in queueItems) {
      if (item.status == AudioQueueStatus.completed) continue;
      if (persistedAudioPaths.contains(item.audioFilePath)) continue;

      final isFailed = item.status == AudioQueueStatus.failed;
      queueNotes.add(
        Note(
          originalAudioPath: item.audioFilePath,
          rawText: item.rawTranscript ?? '',
          correctedText: item.correctedText ?? item.rawTranscript ?? '',
          createdAt: item.recordedAt,
          dailySequenceNumber: item.sequenceNumber,
          state: isFailed ? ThoughtState.failed : ThoughtState.enqueued,
          failureReason: isFailed ? (item.errorMessage ?? 'Error processing voice recording.') : null,
          isRead: isFailed,
        )..id = -(int.tryParse(item.id) ?? item.hashCode.abs()),
      );
    }

    return [...queueNotes, ...persistedNotes]
      ..sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
  }

  /// Picking a triage filter (the same one again too) starts a fresh listing.
  void _pickTriageFilter(CaptureTriageFilter filter) {
    setState(() {
      _triageFilter = filter;
      _keptUnderTriage.clear();
    });
  }

  bool _matchesFilters(Note n) =>
      (matchesCaptureTriage(n, _triageFilter) || _keptUnderTriage.contains(n.id)) &&
      matchesCaptureStatus(n, _statusFilter);

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceElevated,
        duration: const Duration(seconds: 2),
        content: Text(message, style: const TextStyle(color: AppColors.textPrimary)),
      ),
    );
  }

  /// Brings thought [noteId] into view: it is looked for among all stored thoughts, any filter
  /// that would hide it is reset, its card is scrolled to and glows for a moment. The request is
  /// consumed either way.
  Future<void> _handleFocusRequest(int? noteId) async {
    if (noteId == null) return;
    ref.read(captureFocusRequestProvider.notifier).clear();
    final List<Note> stored;
    try {
      stored = await ref.read(recentNotesProvider.future);
    } catch (_) {
      return;
    }
    if (!mounted) return;
    final target = stored.where((n) => n.id == noteId).firstOrNull;
    if (target == null) {
      _showMessage('That thought no longer exists.');
      return;
    }
    setState(() {
      _panelOpen = false;
      if (!matchesCaptureTriage(target, _triageFilter)) _triageFilter = CaptureTriageFilter.all;
      if (!matchesCaptureStatus(target, _statusFilter)) _statusFilter = CaptureStatusFilter.all;
      _keptUnderTriage.clear();
      _buildAllCards = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_revealCard(noteId)));
  }

  Future<void> _revealCard(int noteId) async {
    final cardContext = _cardKeys[noteId]?.currentContext;
    if (!mounted) return;
    if (cardContext != null && cardContext.mounted) {
      await Scrollable.ensureVisible(
        cardContext,
        alignment: 0.1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
    if (!mounted) return;
    _highlightTimer?.cancel();
    setState(() {
      _buildAllCards = false;
      _highlightedId = noteId;
    });
    _highlightTimer = Timer(_highlightDuration, () {
      if (mounted) setState(() => _highlightedId = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.listen(captureFocusRequestProvider, (_, noteId) => unawaited(_handleFocusRequest(noteId)));
    final notesAsync = ref.watch(recentNotesProvider);
    final queueItems = ref.watch(queueItemsProvider);

    // Back closes the view panel before it leaves the screen.
    return PopScope(
      canPop: !_panelOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _panelOpen = false);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: notesAsync.when(
            skipLoadingOnReload: true,
            data: (persistedNotes) => _buildFeed(_unifiedThoughts(persistedNotes, queueItems)),
            loading: () => const Center(child: PulseDotsLoader()),
            error: (err, stack) => Center(
              child: Text('Error: $err', style: const TextStyle(color: AppColors.textSecondary)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeed(List<Note> allThoughts) {
    final displayed = allThoughts.where(_matchesFilters).toList();
    if (_triageFilter != CaptureTriageFilter.all) _keptUnderTriage.addAll(displayed.map((n) => n.id));

    // Flatten day headers and cards into one lazily built list.
    final rows = <Object>[];
    String? currentDay;
    for (final note in displayed) {
      final day = dayHeaderLabel(note.createdAt);
      if (day != currentDay) {
        currentDay = day;
        rows.add(day);
      }
      rows.add(note);
    }

    _cardKeys.removeWhere((id, _) => !allThoughts.any((n) => n.id == id));

    final list = ListView.builder(
      controller: _scrollController,
      // While a thought is scrolled to, all cards exist so it can be found wherever it is.
      scrollCacheExtent: _buildAllCards ? const ScrollCacheExtent.pixels(1e7) : null,
      // Bottom padding keeps the last card clear of the floating capsule.
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: rows.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) return _buildHeader();
        if (index == rows.length + 1) {
          return displayed.isEmpty ? _buildEmptyState(allThoughts.isEmpty) : const SizedBox.shrink();
        }
        final row = rows[index - 1];
        return row is Note ? _buildCard(row) : DayHeader(label: row as String);
      },
    );

    final counts = CaptureViewCounts.of(allThoughts, triage: _triageFilter, statusFilter: _statusFilter);
    return Column(
      children: [
        CaptureViewBar(
          title: captureViewTitle(_triageFilter, _statusFilter),
          filterActive: _triageFilter != CaptureTriageFilter.all || _statusFilter != CaptureStatusFilter.all,
          onTap: () => setState(() => _panelOpen = !_panelOpen),
        ),
        Expanded(
          child: FolderPanelOverlay(
            open: _panelOpen,
            onDismiss: () => setState(() => _panelOpen = false),
            panel: CaptureViewPanel(
              triage: _triageFilter,
              status: _statusFilter,
              counts: counts,
              onTriageChanged: _pickTriageFilter,
              onStatusChanged: (f) => setState(() => _statusFilter = f),
            ),
            child: list,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPermissionBanner(),
        _buildSpeechModelBanner(),
        const SizedBox(height: 8),
      ],
    );
  }

  /// Ambient warning shown while capture is not ready: the microphone first, then the
  /// notification permission that carries the lock-screen Record button.
  Widget _buildPermissionBanner() {
    final permAsync = ref.watch(backgroundPermissionStatusProvider);
    final permService = ref.watch(backgroundPermissionServiceProvider);
    return permAsync.maybeWhen(
      data: (status) {
        final String message;
        final String action;
        final Future<void> Function() onAction;
        if (!status.isMicrophoneGranted) {
          message = 'Microphone access is needed to capture thoughts.';
          action = 'Allow';
          onAction = permService.requestMicrophone;
        } else if (!status.areNotificationsEnabled) {
          message = 'Notifications are off, so the Record button on your lock screen is hidden.';
          action = 'Turn on';
          onAction = permService.requestNotifications;
        } else {
          return const SizedBox.shrink();
        }
        return Container(
          key: const Key('capture_readiness_banner'),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade400),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: Colors.amber.shade900,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  backgroundColor: Colors.amber.shade300,
                ),
                child: Text(action, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: () async {
                  await onAction();
                  ref.invalidate(backgroundPermissionStatusProvider);
                },
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  /// Shown while the speech model is missing: recordings are kept and transcribed once it is
  /// downloaded (FR16.2), and the banner is the way to start that download.
  Widget _buildSpeechModelBanner() {
    final availability = ref.watch(speechModelAvailabilityProvider);
    if (availability.isReady) return const SizedBox.shrink();
    final downloading = availability.kind == ModelAvailabilityKind.downloading;
    final message = switch (availability.kind) {
      ModelAvailabilityKind.downloading =>
        'Downloading speech model… ${(availability.fraction * 100).floor()}%',
      ModelAvailabilityKind.paused => describeModelReason(availability.reason, failed: false),
      ModelAvailabilityKind.verifying => 'Checking speech model…',
      _ => 'Speech model needed to turn recordings into text.',
    };
    return Container(
      key: const Key('capture_speech_model_banner'),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.accentAI.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentAI.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => openModelSetup(Navigator.of(context)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.download_for_offline_outlined, color: AppColors.accentAI),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
                if (!downloading) ...[
                  const SizedBox(width: 8),
                  const Text(
                    'Set up',
                    key: Key('capture_speech_model_setup'),
                    style: TextStyle(color: AppColors.accentAction, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool hasNoThoughtsAtAll) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        hasNoThoughtsAtAll
            ? 'No thoughts yet.\nTap the mic below, the Record button in your notifications, or the home-screen widget.'
            : 'No thoughts matching active filters',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
      ),
    );
  }

  Widget _buildCard(Note note) {
    final playbackState = ref.watch(audioPlaybackControllerProvider);
    final audioPath = note.originalAudioPath;
    final hasAudio = audioPath != null && audioPath.isNotEmpty;
    final isPersisted = note.id > 0;

    String? sessionLabel;
    if (note.state == ThoughtState.synthesized) {
      ref.watch(synthesisRepositoryProvider);
      final session = ref.read(synthesisRepositoryProvider.notifier).sessionOfThought(note.id);
      if (session != null) {
        sessionLabel = sessionReferenceLabel(session, relativeTo: note.createdAt ?? session.sessionStart);
      }
    }

    Future<void> markRead() async {
      if (note.isRead || !isPersisted) return;
      await ref.read(notesRepositoryProvider).markAsRead(note.id);
    }

    final card = ThoughtCard(
      key: ValueKey(note.id),
      note: note,
      sequenceNumber: note.dailySequenceNumber,
      synthesizedSessionLabel: sessionLabel,
      onOpenSession: note.state == ThoughtState.synthesized ? () => _openSession(note) : null,
      isPlaying: playbackState.isPlaying && playbackState.currentlyPlayingPath == audioPath,
      onPlayAudio: hasAudio
          ? () => ref.read(audioPlaybackControllerProvider.notifier).togglePlayback(audioPath)
          : null,
      onEdit: (newText) async {
        if (!isPersisted) return;
        await ref.read(thoughtActionsProvider).editText(note, newText);
      },
      onCopy: (text) => copyToClipboard(context, text),
      onDelete: () async {
        // Tells the user what else goes with the thought: the note written from it.
        final session = isPersisted ? ref.read(synthesisRepositoryProvider.notifier).sessionOfThought(note.id) : null;
        final confirmed = await confirmDelete(
          context,
          question: deleteThoughtQuestion(note.dailySequenceNumber),
          consequence: describeThoughtDeleteConsequence(
            session: session,
            noteId: note.id,
            thoughtCreatedAt: note.createdAt,
          ),
        );
        if (!confirmed || !mounted) return;
        if (isPersisted) {
          await ref.read(thoughtActionsProvider).delete(note);
        } else if (hasAudio) {
          await ref.read(audioQueueServiceProvider).removeItemByAudioPath(audioPath);
        }
      },
      onRetry: () => ref.read(audioQueueServiceProvider).retryFailed(),
      onTap: markRead,
      highlighted: _highlightedId == note.id,
    );
    // A thought is also read once it has stayed on screen for a while (while this tab is in front).
    return KeyedSubtree(
      key: _cardKeys.putIfAbsent(note.id, () => GlobalKey(debugLabel: 'thought_${note.id}')),
      child: ReadOnDwell(
        key: ValueKey('dwell_${note.id}'),
        enabled: isPersisted && !note.isRead,
        active: ref.watch(shellTabActiveProvider(ShellTab.capture)),
        onRead: markRead,
        child: card,
      ),
    );
  }

  /// The session number on a synthesized thought opens that note in the Synthesis tab.
  void _openSession(Note note) {
    final session = ref.read(synthesisRepositoryProvider.notifier).sessionOfThought(note.id);
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.surfaceElevated,
          duration: Duration(seconds: 2),
          content: Text('That note no longer exists.', style: TextStyle(color: AppColors.textPrimary)),
        ),
      );
      return;
    }
    ref.read(synthesisFocusRequestProvider.notifier).request(session.clusterId);
  }
}
