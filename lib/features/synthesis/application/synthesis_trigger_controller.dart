import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/core/logger/app_logger.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/synthesis/application/synthesis_runner.dart';
import 'package:eudemonia/features/synthesis/application/synthesis_settings.dart';

typedef TimerFactory = Timer Function(Duration duration, void Function() callback);

/// Starts automatic synthesis runs (FR11.8): when enough thoughts wait in Capture, and when
/// capture has been quiet for the configured window.
class SynthesisTriggerController {
  /// Wait after the threshold is reached, restarted by every new thought, so dictating
  /// several thoughts in a row does not start (and then preempt) a run each time.
  static const Duration settleDelay = Duration(seconds: 20);
  static const Duration busyRetryDelay = Duration(seconds: 60);

  final SynthesisRunner _runner;
  final Future<int> Function() _eligibleCount;
  final SynthesisSettings Function() _settings;
  final TimerFactory _createTimer;
  final AppLogger? _logger;

  Timer? _settleTimer;
  Timer? _quietTimer;
  Timer? _retryTimer;
  bool _disposed = false;

  SynthesisTriggerController({
    required this._runner,
    required this._eligibleCount,
    required this._settings,
    this._createTimer = Timer.new,
    this._logger,
  });

  /// App launch: thoughts left from earlier wait for the quiet window. A run is never started
  /// right after launch, because the user has just opened the app to use it.
  Future<void> start() async {
    if (_disposed) return;
    _armQuietTimer();
  }

  void _armQuietTimer() {
    _quietTimer?.cancel();
    _quietTimer = _createTimer(Duration(minutes: _settings().inactivityMinutes), () => _fire('quiet window'));
  }

  /// A new thought reached Capture.
  Future<void> onThoughtSaved() async {
    if (_disposed) return;
    _armQuietTimer();
    final count = await _countOrZero();
    if (_disposed || count < _settings().noteThreshold) return;
    _settleTimer?.cancel();
    _settleTimer = _createTimer(settleDelay, () => _fire('note threshold'));
  }

  Future<int> _countOrZero() async {
    try {
      return await _eligibleCount();
    } catch (e) {
      _logger?.warning('[SynthesisTrigger] Could not count waiting thoughts: $e');
      return 0;
    }
  }

  Future<void> _fire(String reason) async {
    if (_disposed || await _countOrZero() == 0 || _disposed) return;
    _logger?.info('[SynthesisTrigger] Starting automatic synthesis ($reason).');
    final result = await _runner.run(manual: false);
    // A preempting recording may never produce a thought, so a preempted run is retried like a busy one.
    if (_disposed || (result != SynthesisRunResult.busy && result != SynthesisRunResult.preempted)) return;
    if (await _countOrZero() == 0 || _disposed) return;
    _retryTimer?.cancel();
    _retryTimer = _createTimer(busyRetryDelay, () => _fire('retry after busy'));
  }

  void dispose() {
    _disposed = true;
    _settleTimer?.cancel();
    _quietTimer?.cancel();
    _retryTimer?.cancel();
  }
}

final synthesisTriggerControllerProvider = Provider<SynthesisTriggerController>((ref) {
  final controller = SynthesisTriggerController(
    runner: ref.watch(synthesisRunnerProvider),
    // Only thoughts no run has failed on start a run: the model is deterministic, so a failed
    // thought fails again until something changes. A run started by new thoughts retries them.
    eligibleCount: () async => (await ref.read(notesRepositoryProvider).getAllNotes())
        .where((n) => isSynthesisCandidate(n, manual: false, maxAttempts: 1))
        .length,
    settings: () => ref.read(synthesisSettingsProvider),
    logger: ref.watch(appLoggerProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});
