import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/capture/capture_controller.dart';
import 'package:eudemonia/features/capture/presentation/written_note_sheet.dart';
import 'package:eudemonia/features/home/presentation/glass_bubble.dart';
import 'package:eudemonia/features/home/presentation/recording_timer_bubble.dart';
import 'package:eudemonia/features/search/presentation/search_page.dart';
import 'package:eudemonia/features/theme/app_colors.dart';
import 'package:eudemonia/features/theme/app_icons.dart';

/// The bottom row of the navigation shell, shown on every tab: a round pen bubble (write a
/// thought), an obround search bubble taking the remaining width, and a round microphone bubble
/// wired to the one [captureControllerProvider]. While recording, the search bubble shows the
/// recording timer instead. It sits in the shell Scaffold's floating-action-button slot, so a
/// SnackBar (the `Captured a new note [#NN]` message included) is laid out above it, never over it.
class ShellActionBar extends ConsumerWidget {
  const ShellActionBar({super.key});

  Future<void> _onRecordTap(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final captured = await ref.read(captureControllerProvider.notifier).handleTrigger();
    final sequence = captured?.sequenceNumber;
    if (!context.mounted || sequence == null) return;
    messenger.showSnackBar(
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
  Widget build(BuildContext context, WidgetRef ref) {
    final isRecording = ref.watch(captureControllerProvider);
    final controller = ref.read(captureControllerProvider.notifier);
    // A little extra room below keeps the bubbles clear of the system gesture area.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SizedBox(
        width: double.infinity,
        child: Row(
          children: [
            GlassBubble(
              key: const Key('write_note_button'),
              label: 'Write a thought',
              width: glassBubbleHeight,
              onTap: () => showWrittenNoteSheet(context),
              child: const Icon(AppIcons.writtenNote, color: AppColors.textPrimary, size: 26),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: isRecording
                  ? RecordingTimerBubble(startedAt: controller.startedAt, maxDuration: controller.maxDuration)
                  : GlassBubble(
                      key: const Key('shell_search_button'),
                      label: 'Search',
                      alignment: Alignment.centerLeft,
                      onTap: () => openSearchPage(context),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 18),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search, color: AppColors.textSecondary, size: 22),
                            SizedBox(width: 8),
                            Text('Search', style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            isRecording
                ? GlassBubble(
                    key: const Key('floating_capture_button_active'),
                    label: 'Stop recording',
                    width: glassBubbleHeight,
                    solidTint: const Color(0xFF0F291E),
                    borderColor: AppColors.accentCapture,
                    onTap: () => _onRecordTap(context, ref),
                    child: const Icon(Icons.stop_rounded, color: AppColors.accentCapture, size: 26),
                  )
                : GlassBubble(
                    key: const Key('floating_capture_button'),
                    label: 'Record a thought',
                    width: glassBubbleHeight,
                    borderColor: AppColors.accentCapture.withValues(alpha: 0.45),
                    onTap: () => _onRecordTap(context, ref),
                    child: const Icon(Icons.mic, color: AppColors.accentCapture, size: 24),
                  ),
          ],
        ),
      ),
    );
  }
}
