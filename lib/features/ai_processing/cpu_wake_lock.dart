import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/core/logger/app_logger.dart';

/// Keeps the CPU awake while a long on-device job runs with the screen off. Without it Android
/// suspends an unplugged phone and a model turn freezes mid-way. Every hold is bounded by its
/// timeout, so a job that hangs or dies never keeps the CPU awake for good.
abstract class CpuWakeLock {
  /// Keeps the CPU awake for at most [timeout]; calling again restarts the countdown.
  Future<void> hold(Duration timeout);

  Future<void> release();
}

/// Native-backed [CpuWakeLock] for one named owner; owners never affect each other's lock.
///
/// Never throws: processing must continue even when the lock cannot be taken.
class MethodChannelCpuWakeLock implements CpuWakeLock {
  static const MethodChannel _channel = MethodChannel('com.eudemonia.eudemonia/processing_wake_lock');

  final String owner;
  final AppLogger? _logger;

  MethodChannelCpuWakeLock({required this.owner, this._logger});

  @override
  Future<void> hold(Duration timeout) =>
      _invoke('hold', {'owner': owner, 'timeoutMs': timeout.inMilliseconds});

  @override
  Future<void> release() => _invoke('release', {'owner': owner});

  Future<void> _invoke(String method, Map<String, Object> arguments) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } catch (e) {
      _logger?.warning('[WakeLock] $method failed for "$owner": $e');
    }
  }
}

final synthesisWakeLockProvider = Provider<CpuWakeLock>((ref) {
  return MethodChannelCpuWakeLock(owner: 'synthesis', logger: ref.watch(appLoggerProvider));
});

final transcriptionWakeLockProvider = Provider<CpuWakeLock>((ref) {
  return MethodChannelCpuWakeLock(owner: 'transcription', logger: ref.watch(appLoggerProvider));
});
