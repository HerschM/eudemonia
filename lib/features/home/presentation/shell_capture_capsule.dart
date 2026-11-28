import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/capture/capture_controller.dart';
import 'package:eudemonia/features/capture/presentation/floating_capture_capsule.dart';
import 'package:eudemonia/features/theme/app_colors.dart';

/// The in-app record capsule of the navigation shell, shown on every tab and wired to the one
/// [captureControllerProvider]. It sits in the shell Scaffold's floating-action-button slot, so a
/// SnackBar (the `Captured a new note [#NN]` message included) is laid out beside it, never over it.
/// The timer shows the recording length limit native reports (`01:30 / 05:00`).
class ShellCaptureCapsule extends ConsumerWidget {
  const ShellCaptureCapsule({super.key});

  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
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
    final startedAt = controller.startedAt;
    final maxDuration = controller.maxDuration;
    // A little extra room below keeps the capsule clear of the system gesture area.
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FloatingCaptureCapsule(
        isRecording: isRecording,
        startedAt: startedAt,
        maxDuration: maxDuration,
        onTap: () => _onTap(context, ref),
      ),
    );
  }
}
