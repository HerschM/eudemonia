import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Immutable model representing the status of background permissions.
@immutable
class BackgroundPermissionStatus {
  final bool isAccessibilityEnabled;
  final bool isBatteryOptimizationIgnored;
  final bool isForegroundServiceRunning;

  const BackgroundPermissionStatus({
    required this.isAccessibilityEnabled,
    required this.isBatteryOptimizationIgnored,
    this.isForegroundServiceRunning = false,
  });

  bool get areAllGranted => isAccessibilityEnabled && isBatteryOptimizationIgnored;

  BackgroundPermissionStatus copyWith({
    bool? isAccessibilityEnabled,
    bool? isBatteryOptimizationIgnored,
    bool? isForegroundServiceRunning,
  }) {
    return BackgroundPermissionStatus(
      isAccessibilityEnabled: isAccessibilityEnabled ?? this.isAccessibilityEnabled,
      isBatteryOptimizationIgnored:
          isBatteryOptimizationIgnored ?? this.isBatteryOptimizationIgnored,
      isForegroundServiceRunning:
          isForegroundServiceRunning ?? this.isForegroundServiceRunning,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackgroundPermissionStatus &&
          runtimeType == other.runtimeType &&
          isAccessibilityEnabled == other.isAccessibilityEnabled &&
          isBatteryOptimizationIgnored == other.isBatteryOptimizationIgnored &&
          isForegroundServiceRunning == other.isForegroundServiceRunning;

  @override
  int get hashCode =>
      isAccessibilityEnabled.hashCode ^
      isBatteryOptimizationIgnored.hashCode ^
      isForegroundServiceRunning.hashCode;

  @override
  String toString() =>
      'BackgroundPermissionStatus(accessibility: $isAccessibilityEnabled, batteryOptimizationIgnored: $isBatteryOptimizationIgnored, foregroundServiceRunning: $isForegroundServiceRunning)';
}

/// Service managing background and accessibility permission checks and coordinated requests.
class BackgroundPermissionService {
  final MethodChannel channel;

  const BackgroundPermissionService({
    this.channel = const MethodChannel('com.eudemonia/hardware_buttons'),
  });

  /// Checks the current state of both accessibility and battery optimization exemption.
  Future<BackgroundPermissionStatus> checkStatus() async {
    try {
      final isAccessibility =
          await channel.invokeMethod<bool>('isAccessibilityServiceEnabled') ?? false;
      final isBatteryIgnored =
          await channel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? false;
      final isForegroundRunning =
          await channel.invokeMethod<bool>('isForegroundServiceRunning') ?? false;

      return BackgroundPermissionStatus(
        isAccessibilityEnabled: isAccessibility,
        isBatteryOptimizationIgnored: isBatteryIgnored,
        isForegroundServiceRunning: isForegroundRunning,
      );
    } catch (e) {
      debugPrint('[BackgroundPermissionService] Error querying permission status: $e');
      return const BackgroundPermissionStatus(
        isAccessibilityEnabled: false,
        isBatteryOptimizationIgnored: false,
        isForegroundServiceRunning: false,
      );
    }
  }

  /// Starts the persistent background foreground service.
  Future<void> startForegroundService() async {
    try {
      await channel.invokeMethod('startForegroundService');
    } catch (e) {
      debugPrint('[BackgroundPermissionService] Error starting foreground service: $e');
    }
  }

  /// Stops the persistent background foreground service.
  Future<void> stopForegroundService() async {
    try {
      await channel.invokeMethod('stopForegroundService');
    } catch (e) {
      debugPrint('[BackgroundPermissionService] Error stopping foreground service: $e');
    }
  }

  /// Prompts for battery optimization exemption (direct system prompt on Android).
  Future<void> requestBatteryOptimizationExemption() async {
    try {
      await channel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (e) {
      debugPrint('[BackgroundPermissionService] Error requesting battery exemption: $e');
    }
  }

  /// Opens the system Battery Optimization management screen allowing users to view or toggle exemption.
  Future<void> openBatteryOptimizationSettings() async {
    try {
      await channel.invokeMethod('openBatteryOptimizationSettings');
    } catch (e) {
      debugPrint('[BackgroundPermissionService] Error opening battery optimization settings: $e');
    }
  }

  /// Opens system Accessibility settings.
  Future<void> openAccessibilitySettings() async {
    try {
      await channel.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      debugPrint('[BackgroundPermissionService] Error opening accessibility settings: $e');
    }
  }

  /// Initiates the simultaneous permission request flow.
  /// Requests battery optimization exemption and guides into accessibility settings.
  Future<void> requestSimultaneousPermissions() async {
    try {
      await channel.invokeMethod('requestSimultaneousPermissions');
    } catch (e) {
      debugPrint('[BackgroundPermissionService] Error in requestSimultaneousPermissions: $e');
    }
  }

  /// Displays an informative modal bottom sheet explaining both permissions and prompting to enable them.
  Future<void> showSimultaneousPermissionModal(
    BuildContext context, {
    VoidCallback? onPermissionsUpdated,
  }) async {
    final status = await checkStatus();
    if (!context.mounted) return;

    if (status.areAllGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All background capture permissions are already active!'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.bolt, color: Theme.of(context).colorScheme.primary, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Background Permissions Required',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'To capture voice notes instantly in the background without the app getting killed, Android requires two simultaneous permissions:',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                ),
                const SizedBox(height: 16),
                _buildPermissionItem(
                  context,
                  title: '1. Unrestricted Background Running',
                  subtitle:
                      'Exempts Eudemonia from battery optimization and Doze mode so the background engine stays alive.',
                  isGranted: status.isBatteryOptimizationIgnored,
                  icon: Icons.battery_charging_full_rounded,
                  onTap: () async {
                    await requestBatteryOptimizationExemption();
                    onPermissionsUpdated?.call();
                  },
                ),
                const SizedBox(height: 12),
                _buildPermissionItem(
                  context,
                  title: '2. Accessibility Service',
                  subtitle:
                      'Intercepts simultaneous volume button clicks globally while the screen is on or locked.',
                  isGranted: status.isAccessibilityEnabled,
                  icon: Icons.accessibility_new_rounded,
                  onTap: () async {
                    await openAccessibilitySettings();
                    onPermissionsUpdated?.call();
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text(
                      'Grant Both Permissions Simultaneously',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      Navigator.pop(modalContext);
                      await requestSimultaneousPermissions();
                      onPermissionsUpdated?.call();
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPermissionItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool isGranted,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isGranted ? Colors.green.shade400 : Colors.amber.shade400,
          width: 1.2,
        ),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isGranted ? Colors.green : Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Chip(
          label: Text(
            isGranted ? 'Enabled' : 'Disabled',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isGranted ? Colors.green.shade900 : Colors.black87,
            ),
          ),
          backgroundColor: isGranted ? Colors.green.shade100 : Colors.amber.shade300,
          padding: EdgeInsets.zero,
        ),
        onTap: onTap,
      ),
    );
  }
}

final backgroundPermissionServiceProvider = Provider<BackgroundPermissionService>((ref) {
  return const BackgroundPermissionService();
});

final backgroundPermissionStatusProvider =
    FutureProvider<BackgroundPermissionStatus>((ref) async {
  final service = ref.watch(backgroundPermissionServiceProvider);
  return service.checkStatus();
});
