import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/settings/background_permission_service.dart';
import 'package:eudemonia/features/theme/app_colors.dart';
import 'package:eudemonia/features/theme/widgets/pulse_dots_loader.dart';
import 'settings_card.dart';

/// Microphone and notification permissions, collapsed until opened. While one is missing the
/// header carries a `Needs attention` badge so a problem is not hidden by the collapse.
class PermissionsSection extends ConsumerWidget {
  const PermissionsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permStatusAsync = ref.watch(backgroundPermissionStatusProvider);
    final status = permStatusAsync.value;
    final needsAttention = status != null && (!status.isMicrophoneGranted || !status.areNotificationsEnabled);
    return CollapsibleSettingsSection(
      headerKey: const Key('settings_permissions_header'),
      title: 'PERMISSIONS',
      badge: needsAttention
          ? Container(
              key: const Key('settings_permissions_attention_badge'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.amber.shade300,
                borderRadius: BorderRadius.circular(AppColors.badgeRadius),
              ),
              child: const Text(
                'Needs attention',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            )
          : null,
      bodyBuilder: (_) => Consumer(
        builder: (context, ref, _) {
          final permService = ref.watch(backgroundPermissionServiceProvider);
          return ref.watch(backgroundPermissionStatusProvider).when(
                data: (status) => Column(
                  children: [
                    _PermissionRow(
                      key: const Key('settings_microphone_row'),
                      granted: status.isMicrophoneGranted,
                      grantedIcon: Icons.check_circle,
                      missingIcon: Icons.mic_off,
                      title: 'Microphone',
                      subtitle: status.isMicrophoneGranted
                          ? 'Thoughts are recorded on this device.'
                          : 'Needed to capture thoughts. Tap to allow.',
                      onTap: () async {
                        await permService.requestMicrophone();
                        ref.invalidate(backgroundPermissionStatusProvider);
                      },
                    ),
                    const Divider(color: AppColors.borderSubtle, height: 16),
                    _PermissionRow(
                      key: const Key('settings_notifications_row'),
                      granted: status.areNotificationsEnabled,
                      grantedIcon: Icons.check_circle,
                      missingIcon: Icons.notifications_off,
                      title: 'Notifications (lock-screen Record button)',
                      subtitle: status.areNotificationsEnabled
                          ? 'Start a capture from the lock screen.'
                          : 'Turn on to show the Record button on your lock screen.',
                      onTap: () async {
                        await permService.requestNotifications();
                        ref.invalidate(backgroundPermissionStatusProvider);
                      },
                    ),
                  ],
                ),
                loading: () => const Center(
                  child: Padding(padding: EdgeInsets.all(16.0), child: PulseDotsLoader()),
                ),
                error: (err, _) => ListTile(
                  title: const Text('Error loading permission status'),
                  subtitle: Text(err.toString()),
                ),
              );
        },
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final bool granted;
  final IconData grantedIcon;
  final IconData missingIcon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PermissionRow({
    super.key,
    required this.granted,
    required this.grantedIcon,
    required this.missingIcon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        granted ? grantedIcon : missingIcon,
        color: granted ? Colors.green : Colors.amber.shade700,
      ),
      title: Text(title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      trailing: Chip(
        label: Text(
          granted ? 'Enabled' : 'Disabled',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: granted ? Colors.green.shade900 : Colors.black87,
          ),
        ),
        backgroundColor: granted ? Colors.green.shade100 : Colors.amber.shade300,
      ),
      onTap: onTap,
    );
  }
}
