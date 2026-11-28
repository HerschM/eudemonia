import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/capture/native_capture_channel.dart';
import 'package:eudemonia/features/settings/background_permission_service.dart';
import 'package:eudemonia/features/theme/app_colors.dart';
import 'package:eudemonia/features/theme/widgets/pulse_dots_loader.dart';
import 'settings_card.dart';

/// Ways to start a capture without opening the app: the home-screen widget and the background
/// keep-alive that keeps the lock-screen Record button ready.
class CaptureSection extends ConsumerWidget {
  const CaptureSection({super.key});

  Future<void> _addCaptureWidget(BuildContext context, WidgetRef ref) async {
    final pinned = await ref.read(nativeCaptureChannelProvider).requestPinWidget();
    if (pinned || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Long-press your home screen, choose Widgets, then Eudemonia.'),
      ),
    );
  }

  Future<void> _addQuickSettingsTile(BuildContext context, WidgetRef ref) async {
    final offered = await ref.read(nativeCaptureChannelProvider).requestAddQuickSettingsTile();
    if (offered || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Open Quick Settings, tap the pencil, then drag "Record" into your tiles.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permStatusAsync = ref.watch(backgroundPermissionStatusProvider);
    final permService = ref.watch(backgroundPermissionServiceProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader('CAPTURE'),
        SettingsCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              ListTile(
                key: const Key('settings_add_widget_row'),
                leading: const Icon(Icons.widgets_outlined, color: AppColors.accentCapture),
                title: const Text('Add capture widget to home screen',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                subtitle: const Text(
                  'One tap on the home screen starts a capture.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                onTap: () => _addCaptureWidget(context, ref),
              ),
              const Divider(color: AppColors.borderSubtle, height: 16),
              ListTile(
                key: const Key('settings_add_tile_row'),
                leading: const Icon(Icons.dashboard_customize_outlined, color: AppColors.accentCapture),
                title: const Text('Add Record tile to Quick Settings',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                subtitle: const Text(
                  'One swipe and one tap records a thought, also on the lock screen.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                onTap: () => _addQuickSettingsTile(context, ref),
              ),
              const Divider(color: AppColors.borderSubtle, height: 16),
              permStatusAsync.when(
                data: (status) => SwitchListTile(
                  secondary: Icon(
                    status.isForegroundServiceRunning ? Icons.cloud_done : Icons.cloud_off,
                    color: status.isForegroundServiceRunning ? Colors.green : Colors.amber.shade700,
                  ),
                  title: const Text('Keep capture ready in the background',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  subtitle: const Text(
                      'Keeps the Record button on your lock screen and finishes transcription and notes while the app is closed.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  value: status.isForegroundServiceRunning,
                  onChanged: (enable) async {
                    if (enable) {
                      await permService.startForegroundService();
                    } else {
                      await permService.stopForegroundService();
                    }
                    ref.invalidate(backgroundPermissionStatusProvider);
                  },
                ),
                loading: () => const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: PulseDotsLoader()),
                ),
                error: (err, _) => ListTile(
                  title: const Text('Error loading permission status'),
                  subtitle: Text(err.toString()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
