import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Live thermal and memory readings reported by the operating system.
///
/// A field is `null` when the device or its Android version cannot provide it;
/// nothing here is estimated.
@immutable
class SystemTelemetry {
  /// Android `PowerManager.THERMAL_STATUS_*` (0 = none ... 6 = shutdown).
  final int? thermalStatus;

  /// Fraction of the way to severe throttling (1.0 = `THERMAL_STATUS_SEVERE`).
  final double? thermalHeadroom;

  /// RAM attributable to the app process (PSS), including native model weights.
  final int? appMemoryBytes;
  final int? deviceAvailableBytes;
  final int? deviceTotalBytes;
  final bool isLowMemory;

  const SystemTelemetry({
    this.thermalStatus,
    this.thermalHeadroom,
    this.appMemoryBytes,
    this.deviceAvailableBytes,
    this.deviceTotalBytes,
    this.isLowMemory = false,
  });

  factory SystemTelemetry.fromMap(Map<Object?, Object?> map) {
    return SystemTelemetry(
      thermalStatus: (map['thermalStatus'] as num?)?.toInt(),
      thermalHeadroom: (map['thermalHeadroom'] as num?)?.toDouble(),
      appMemoryBytes: (map['appMemoryBytes'] as num?)?.toInt(),
      deviceAvailableBytes: (map['deviceAvailableBytes'] as num?)?.toInt(),
      deviceTotalBytes: (map['deviceTotalBytes'] as num?)?.toInt(),
      isLowMemory: map['isLowMemory'] as bool? ?? false,
    );
  }

  static const List<String> _thermalStatusNames = [
    'Nominal',
    'Light',
    'Moderate',
    'Severe',
    'Critical',
    'Emergency',
    'Shutdown',
  ];

  String? get thermalStatusLabel {
    final status = thermalStatus;
    if (status == null || status < 0 || status >= _thermalStatusNames.length) return null;
    return _thermalStatusNames[status];
  }

  /// Share of thermal headroom left before severe throttling, 0–100.
  int? get thermalHeadroomRemainingPercent {
    final headroom = thermalHeadroom;
    if (headroom == null) return null;
    return ((1.0 - headroom) * 100).round().clamp(0, 100);
  }

  /// True from `THERMAL_STATUS_SEVERE` upwards, the level at which LLM work must be deferred.
  bool get isThermallyThrottled => (thermalStatus ?? 0) >= 3;

  /// e.g. `84% (Nominal)`, `Moderate`, or `Unavailable on this device`.
  String get thermalSummary {
    final percent = thermalHeadroomRemainingPercent;
    final label = thermalStatusLabel;
    if (percent != null && label != null) return '$percent% ($label)';
    if (percent != null) return '$percent%';
    return label ?? 'Unavailable on this device';
  }

  String? get appMemoryLabel => appMemoryBytes == null ? null : formatBytes(appMemoryBytes!);

  /// e.g. `2.1 GB free of 7.6 GB`.
  String? get deviceMemoryLabel {
    final available = deviceAvailableBytes;
    final total = deviceTotalBytes;
    if (available == null || total == null) return null;
    return '${formatBytes(available)} free of ${formatBytes(total)}';
  }

  static String formatBytes(int bytes) {
    const mb = 1024 * 1024;
    const gb = 1024 * mb;
    if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} GB';
    return '${(bytes / mb).round()} MB';
  }
}

/// Reads [SystemTelemetry] from the native platform.
class SystemTelemetryService {
  static const MethodChannel defaultChannel = MethodChannel('com.eudemonia/system_telemetry');
  final MethodChannel _channel;

  const SystemTelemetryService({this._channel = defaultChannel});

  /// Returns `null` when the platform cannot be queried (unsupported host, channel error).
  Future<SystemTelemetry?> read() async {
    try {
      final map = await _channel.invokeMethod<Map<Object?, Object?>>('getSnapshot');
      return map == null ? null : SystemTelemetry.fromMap(map);
    } catch (_) {
      return null;
    }
  }
}

final systemTelemetryServiceProvider = Provider<SystemTelemetryService>((ref) {
  return const SystemTelemetryService();
});

/// Latest reading. Screens that display it invalidate this provider on a timer while visible.
final systemTelemetryProvider = FutureProvider.autoDispose<SystemTelemetry?>((ref) {
  return ref.watch(systemTelemetryServiceProvider).read();
});
