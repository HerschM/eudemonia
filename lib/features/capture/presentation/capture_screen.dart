import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_item.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_service.dart';
import 'package:eudemonia/features/capture/capture_controller.dart';
import 'package:eudemonia/features/notes/audio_playback_controller.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/notes/presentation/thought_card.dart';
import 'package:eudemonia/features/settings/background_permission_service.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/theme/app_colors.dart';
import 'floating_capture_capsule.dart';

enum CaptureTriageFilter { all, unread, read }

enum CaptureStatusFilter { all, processing, processed, synthesized, failed }

/// Stage 1 — Capture: the unfiltered, state-coded stream of raw thoughts.
///
/// Thoughts carry no folder here (folders belong to Synthesis). Machine
/// pipeline status lives in the navigation shell's Pipeline HUD, not on this screen.
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> with WidgetsBindingObserver {
  CaptureTriageFilter _triageFilter = CaptureTriageFilter.all;
  CaptureStatusFilter _statusFilter = CaptureStatusFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(backgroundPermissionServiceProvider).startForegroundService();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

  static bool _isUnread(Note n) => !n.isRead && n.state == ThoughtState.processed;

  bool _matchesFilters(Note n) {
    final matchesTriage = switch (_triageFilter) {
      CaptureTriageFilter.all => true,
      CaptureTriageFilter.unread => _isUnread(n),
      CaptureTriageFilter.read => n.isRead,
    };
    final matchesStatus = switch (_statusFilter) {
      CaptureStatusFilter.all => true,
      CaptureStatusFilter.processing => n.state == ThoughtState.enqueued,
      CaptureStatusFilter.processed => n.state == ThoughtState.processed,
      CaptureStatusFilter.synthesized => n.state == ThoughtState.synthesized,
      CaptureStatusFilter.failed => n.state == ThoughtState.failed,
    };
    return matchesTriage && matchesStatus;
  }

  Future<void> _onCapsuleTapped() async {
    final captured = await ref.read(captureControllerProvider.notifier).handleTrigger();
    final sequence = captured?.sequenceNumber;
    if (!mounted || sequence == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceElevated,
        duration: const Duration(seconds: 2),
        content: Text(
          'Captured a new note [#${sequence.toString().padLeft(2, '0')}]',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRecording = ref.watch(captureControllerProvider);
    final notesAsync = ref.watch(recentNotesProvider);
    final queueItems = ref.watch(queueItemsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            notesAsync.when(
              skipLoadingOnReload: true,
              data: (persistedNotes) => _buildFeed(_unifiedThoughts(persistedNotes, queueItems)),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Text('Error: $err', style: const TextStyle(color: AppColors.textSecondary)),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 16,
              child: Center(
                child: FloatingCaptureCapsule(
                  isRecording: isRecording,
                  onTap: _onCapsuleTapped,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeed(List<Note> allThoughts) {
    final displayed = allThoughts.where(_matchesFilters).toList();

    // Flatten day headers and cards into one lazily built list.
    final rows = <Object>[];
    String? currentDay;
    for (final note in displayed) {
      final day = _dayLabel(note.createdAt);
      if (day != currentDay) {
        currentDay = day;
        rows.add(day);
      }
      rows.add(note);
    }

    return ListView.builder(
      // Bottom padding keeps the last card clear of the floating capsule.
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: rows.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) return _buildHeader();
        if (index == rows.length + 1) {
          return displayed.isEmpty ? _buildEmptyState(allThoughts.isEmpty) : const SizedBox.shrink();
        }
        final row = rows[index - 1];
        return row is Note ? _buildCard(row) : _buildDayHeader(row as String);
      },
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPermissionBanner(),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            _buildFilterDropdown<CaptureTriageFilter>(
              key: const Key('capture_triage_filter_dropdown'),
              value: _triageFilter,
              values: CaptureTriageFilter.values,
              label: (f) => switch (f) {
                CaptureTriageFilter.all => 'All Triage',
                CaptureTriageFilter.unread => 'Unread',
                CaptureTriageFilter.read => 'Read',
              },
              icon: (f) => switch (f) {
                CaptureTriageFilter.all => Icons.visibility_outlined,
                CaptureTriageFilter.unread => Icons.mark_email_unread_outlined,
                CaptureTriageFilter.read => Icons.drafts_outlined,
              },
              color: (f) => f == _triageFilter ? AppColors.accentAction : AppColors.textSecondary,
              onChanged: (f) => setState(() => _triageFilter = f),
            ),
            _buildFilterDropdown<CaptureStatusFilter>(
              key: const Key('capture_status_filter_dropdown'),
              value: _statusFilter,
              values: CaptureStatusFilter.values,
              label: (f) => switch (f) {
                CaptureStatusFilter.all => 'All Statuses',
                CaptureStatusFilter.processing => 'Processing',
                CaptureStatusFilter.processed => 'Processed',
                CaptureStatusFilter.synthesized => 'Synthesized',
                CaptureStatusFilter.failed => 'Failed',
              },
              icon: (f) => switch (f) {
                CaptureStatusFilter.all => Icons.layers_outlined,
                CaptureStatusFilter.processing => Icons.hourglass_top,
                CaptureStatusFilter.processed => Icons.chat_bubble_outline,
                CaptureStatusFilter.synthesized => Icons.auto_awesome,
                CaptureStatusFilter.failed => Icons.error_outline,
              },
              color: (f) => switch (f) {
                CaptureStatusFilter.all => AppColors.textSecondary,
                CaptureStatusFilter.processing => AppColors.accentWarning,
                CaptureStatusFilter.processed => AppColors.accentAction,
                CaptureStatusFilter.synthesized => AppColors.accentCapture,
                CaptureStatusFilter.failed => AppColors.accentError,
              },
              onChanged: (f) => setState(() => _statusFilter = f),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildFilterDropdown<T>({
    required Key key,
    required T value,
    required List<T> values,
    required String Function(T) label,
    required IconData Function(T) icon,
    required Color Function(T) color,
    required ValueChanged<T> onChanged,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppColors.buttonRadius),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          dropdownColor: AppColors.surfaceElevated,
          isDense: true,
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.accentAction, size: 20),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          items: [
            for (final option in values)
              DropdownMenuItem<T>(
                value: option,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon(option), size: 14, color: color(option)),
                    const SizedBox(width: 6),
                    Text(label(option)),
                  ],
                ),
              ),
          ],
          onChanged: (selected) {
            if (selected != null) onChanged(selected);
          },
        ),
      ),
    );
  }

  /// Ambient warning shown until both background capture permissions are granted.
  Widget _buildPermissionBanner() {
    final permAsync = ref.watch(backgroundPermissionStatusProvider);
    final permService = ref.watch(backgroundPermissionServiceProvider);
    return permAsync.maybeWhen(
      data: (status) {
        if (status.areAllGranted) return const SizedBox.shrink();
        return Container(
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
                  'Background capture permissions needed (Accessibility & Battery exemption).',
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
                child: const Text('Enable', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: () => permService.showSimultaneousPermissionModal(
                  context,
                  onPermissionsUpdated: () {
                    ref.invalidate(backgroundPermissionStatusProvider);
                  },
                ),
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _buildDayHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: AppColors.textSecondary.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool hasNoThoughtsAtAll) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        hasNoThoughtsAtAll
            ? 'No thoughts yet.\nPress both volume buttons to capture.'
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
      for (final cluster in ref.watch(synthesisRepositoryProvider)) {
        if (cluster.originNotes.any((origin) => origin.id == note.id)) {
          sessionLabel = cluster.sequenceNumber;
          break;
        }
      }
    }

    return ThoughtCard(
      key: ValueKey(note.id),
      note: note,
      sequenceNumber: note.dailySequenceNumber,
      synthesizedSessionLabel: sessionLabel,
      isPlaying: playbackState.isPlaying && playbackState.currentlyPlayingPath == audioPath,
      onPlayAudio: hasAudio
          ? () => ref.read(audioPlaybackControllerProvider.notifier).togglePlayback(audioPath)
          : null,
      onEdit: (newText) async {
        if (!isPersisted) return;
        await ref.read(notesRepositoryProvider).updateNoteText(note.id, newText);
        ref.invalidate(recentNotesProvider);
      },
      onDelete: () async {
        if (isPersisted) {
          await ref.read(notesRepositoryProvider).deleteNote(note.id);
          ref.invalidate(recentNotesProvider);
        } else if (hasAudio) {
          await ref.read(audioQueueServiceProvider).removeItemByAudioPath(audioPath);
        }
      },
      onRetry: () => ref.read(audioQueueServiceProvider).retryFailed(),
      onTap: () async {
        if (note.isRead || !isPersisted) return;
        await ref.read(notesRepositoryProvider).markAsRead(note.id);
        ref.invalidate(recentNotesProvider);
      },
    );
  }

  static String _dayLabel(DateTime? date) {
    if (date == null) return 'UNDATED';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final difference = today.difference(day).inDays;
    if (difference == 0) return 'TODAY — $dd/$mm';
    if (difference == 1) return 'YESTERDAY — $dd/$mm';
    return '$dd/$mm/${date.year}';
  }
}
