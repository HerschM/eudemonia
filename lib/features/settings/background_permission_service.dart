import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// Immutable model representing what capture needs from the system: the microphone, the
/// notification that carries the lock-screen Record button, and whether the capture service runs.
@immutable
class BackgroundPermissionStatus {
  final bool isMicrophoneGranted;
  final bool areNotificationsEnabled;
  final bool isForegroundServiceRunning;

  const BackgroundPermissionStatus({
    required this.isMicrophoneGranted,
    required this.areNotificationsEnabled,
    this.isForegroundServiceRunning = false,
  });

  BackgroundPermissionStatus copyWith({
    bool? isMicrophoneGranted,
    bool? areNotificationsEnabled,
    bool? isForegroundServiceRunning,
  }) {
    return BackgroundPermissionStatus(
      isMicrophoneGranted: isMicrophoneGranted ?? this.isMicrophoneGranted,
      areNotificationsEnabled: areNotificationsEnabled ?? this.areNotificationsEnabled,
      isForegroundServiceRunning:
          isForegroundServiceRunning ?? this.isForegroundServiceRunning,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackgroundPermissionStatus &&
          runtimeType == other.runtimeType &&
          isMicrophoneGranted == other.isMicrophoneGranted &&
          areNotificationsEnabled == other.areNotificationsEnabled &&
          isForegroundServiceRunning == other.isForegroundServiceRunning;

  @override
  int get hashCode => Object.hash(
        isMicrophoneGranted,
        areNotificationsEnabled,
        isForegroundServiceRunning,
      );

  @override
  String toString() =>
      'BackgroundPermissionStatus(microphone: $isMicrophoneGranted, notifications: $areNotificationsEnabled, foregroundServiceRunning: $isForegroundServiceRunning)';
}

/// Runtime-permission access (`permission_handler`), injectable so tests never touch the plugin.
class RuntimePermissionGateway {
  const RuntimePermissionGateway();

  Future<PermissionStatus> status(Permission permission) => permission.status;

  Future<PermissionStatus> request(Permission permission) => permission.request();

  Future<bool> openSettings() => openAppSettings();
}

/// Service managing capture-readiness checks (microphone, notifications)
/// and the coordinated requests for them.
class BackgroundPermissionService {
  final MethodChannel channel;
  final RuntimePermissionGateway permissions;

  const BackgroundPermissionService({
    this.channel = const MethodChannel('com.eudemonia/hardware_buttons'),
    this.permissions = const RuntimePermissionGateway(),
  });

  /// Checks the current state of every capture prerequisite. A query that fails reports `false`
  /// for that prerequisite only.
  Future<BackgroundPermissionStatus> checkStatus() async {
    final microphone = await _isGranted(Permission.microphone);
    final notifications = await _isGranted(Permission.notification);
    final foregroundRunning = await _queryNative('isForegroundServiceRunning');
    return BackgroundPermissionStatus(
      isMicrophoneGranted: microphone,
      areNotificationsEnabled: notifications,
      isForegroundServiceRunning: foregroundRunning,
    );
  }

  Future<bool> _isGranted(Permission permission) async {
    try {
      return (await permissions.status(permission)).isGranted;
    } catch (e) {
      debugPrint('[BackgroundPermissionService] Error querying $permission: $e');
      return false;
    }
  }

  Future<bool> _queryNative(String method) async {
    try {
      return await channel.invokeMethod<bool>(method) ?? false;
    } catch (e) {
      debugPrint('[BackgroundPermissionService] Error querying $method: $e');
      return false;
    }
  }

  /// Asks for the microphone; a permanently denied permission can only be changed in the
  /// system settings, so the user is sent there instead.
  Future<void> requestMicrophone() => _requestOrOpenSettings(Permission.microphone);

  /// Asks for the notification permission (needed for the lock-screen Record button).
  Future<void> requestNotifications() => _requestOrOpenSettings(Permission.notification);

  Future<void> _requestOrOpenSettings(Permission permission) async {
    try {
      final current = await permissions.status(permission);
      if (current.isGranted) return;
      if (current.isPermanentlyDenied) {
        await permissions.openSettings();
        return;
      }
      final result = await permissions.request(permission);
      if (result.isPermanentlyDenied) await permissions.openSettings();
    } catch (e) {
      debugPrint('[BackgroundPermissionService] Error requesting $permission: $e');
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
}

final runtimePermissionGatewayProvider = Provider<RuntimePermissionGateway>((ref) {
  return const RuntimePermissionGateway();
});

final backgroundPermissionServiceProvider = Provider<BackgroundPermissionService>((ref) {
  return BackgroundPermissionService(permissions: ref.watch(runtimePermissionGatewayProvider));
});

final backgroundPermissionStatusProvider =
    FutureProvider<BackgroundPermissionStatus>((ref) async {
  final service = ref.watch(backgroundPermissionServiceProvider);
  return service.checkStatus();
});
