import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/core/logger/app_logger.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_service.dart';
import 'package:eudemonia/features/capture/capture_controller.dart';
import 'package:eudemonia/features/models/application/model_library_controller.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/synthesis/application/synthesis_runner.dart';
import 'package:eudemonia/features/synthesis/application/synthesis_settings.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';

typedef TimerFactory = Timer Function(Duration duration, void Function() callback);

/// Starts automatic synthesis runs (FR11.8): when enough thoughts wait in Capture, when capture
/// has been quiet for the configured window, and whenever a session is flagged for rewrite.
///
/// A flagged session (a merge, a moved, deleted or edited thought, a style or folder change, or
/// a flag left from before a restart) never sits without a run: one starts as soon as no run is
/// going and capture is idle (no recording, nothing waiting to be transcribed), also at app
/// start. A run that ends without rewriting it starts the next one: at once after it completed,
/// when capture clears or after [busyRetryDelay] when it was busy or preempted. A run that failed
/// or found no writing model is not repeated for the same flagged sessions until they change or
/// a writing model is chosen, so a model that cannot load is not loaded again and again.
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
  final List<SynthesisCluster> Function() _sessions;

  /// The runner's own rule: no run starts while this is true.
  final bool Function() _isCaptureActive;

  Timer? _settleTimer;
  Timer? _quietTimer;
  Timer? _retryTimer;
  bool _disposed = false;
  bool _rewriteCheckScheduled = false;

  /// The flagged sessions a failed or model-less run left ([_flagSignature]); not retried as such.
  String? _blockedFlags;

  /// The flagged sessions the last completed run left, so a run that leaves them unchanged is
  /// run only once more.
  String? _flagsAfterCompletedRun;

  SynthesisTriggerController({
    required this._runner,
    required this._eligibleCount,
    required this._settings,
    this._createTimer = Timer.new,
    this._logger,
    this._sessions = _noSessions,
    this._isCaptureActive = _never,
  });

  static List<SynthesisCluster> _noSessions() => const [];
  static bool _never() => false;

  /// App launch: thoughts left from earlier wait for the quiet window, because the user has just
  /// opened the app to use it. Sessions left flagged for rewrite are rewritten now.
  Future<void> start() async {
    if (_disposed) return;
    _armQuietTimer();
    _scheduleRewriteCheck();
  }

  /// The sessions changed (a flag may have been set, or the stored ones finished loading).
  void onSessionsChanged() => _scheduleRewriteCheck();

  /// A recording started or stopped, or the transcription queue changed.
  void onCaptureChanged() => _scheduleRewriteCheck();

  /// Another writing model was chosen: flags a run could not take may be taken now.
  void onModelChanged() {
    _blockedFlags = null;
    _flagsAfterCompletedRun = null;
    _scheduleRewriteCheck();
  }

  /// A run ended, whoever started it.
  void onRunEnded(SynthesisRunResult result) {
    if (_disposed) return;
    final flags = _flagSignature();
    if (flags == null) {
      _flagsAfterCompletedRun = null;
      return;
    }
    switch (result) {
      case SynthesisRunResult.failed || SynthesisRunResult.noModel:
        _blockedFlags = flags;
      case SynthesisRunResult.busy || SynthesisRunResult.preempted:
        // Capture clearing starts it sooner; never at once, which would spin while capture is busy.
        _armRetry();
      case SynthesisRunResult.completed || SynthesisRunResult.nothingToDo:
        // Flagged again while the run was ending: once more, but not for flags it left as they were.
        if (_flagsAfterCompletedRun == flags) {
          _blockedFlags = flags;
          return;
        }
        _flagsAfterCompletedRun = flags;
        _scheduleRewriteCheck();
    }
  }

  /// Several changes in a row (a merge sets several sessions) lead to one check, after the code
  /// that made them has run, so an action that starts its own run is not raced.
  void _scheduleRewriteCheck() {
    if (_disposed || _rewriteCheckScheduled) return;
    _rewriteCheckScheduled = true;
    scheduleMicrotask(() {
      _rewriteCheckScheduled = false;
      _rewriteIfFlagged();
    });
  }

  void _rewriteIfFlagged() {
    if (_disposed || _rewriteDue() == null) return;
    // The end of the run in progress checks again.
    if (_runner.isRunning) return;
    if (_isCaptureActive()) {
      // Capture clearing checks again; the retry covers a recording that never reaches the queue.
      _armRetry();
      return;
    }
    _logger?.info('[SynthesisTrigger] Starting synthesis to rewrite flagged session(s).');
    // Not awaited: [onRunEnded] handles how it ends, as for runs started elsewhere.
    unawaited(_runner.run(manual: false));
  }

  /// The flagged sessions, by what decides how they are written; null when none is flagged.
  String? _flagSignature() {
    final flagged = [
      for (final s in _sessions())
        if (s.isReprocessing)
          [s.clusterId, s.appliedStyleId, for (final o in s.originNotes) '${o.id}:${o.cleanedText}'].join('\u0000'),
    ];
    return flagged.isEmpty ? null : flagged.join('\u0001');
  }

  /// [_flagSignature] when a run should still take the flagged sessions.
  String? _rewriteDue() {
    final flags = _flagSignature();
    return flags == null || flags == _blockedFlags ? null : flags;
  }

  void _armRetry() {
    _retryTimer?.cancel();
    _retryTimer = _createTimer(busyRetryDelay, () => _fire('retry after busy'));
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
    if (_disposed || (await _countOrZero() == 0 && _rewriteDue() == null) || _disposed) return;
    _logger?.info('[SynthesisTrigger] Starting automatic synthesis ($reason).');
    final result = await _runner.run(manual: false);
    // A preempting recording may never produce a thought, so a preempted run is retried like a busy one.
    if (_disposed || (result != SynthesisRunResult.busy && result != SynthesisRunResult.preempted)) return;
    if ((await _countOrZero() == 0 && _rewriteDue() == null) || _disposed) return;
    _armRetry();
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
    sessions: () => ref.read(synthesisRepositoryProvider),
    // The same rule as the runner's.
    isCaptureActive: () => ref.read(captureControllerProvider) || ref.read(pendingQueueCountProvider) > 0,
  );
  // Container listeners, not ref.listen: this provider is only read, and Riverpod pauses the
  // listeners of a provider nobody watches.
  final container = ref.container;
  final subscriptions = [
    container.listen(synthesisRepositoryProvider, (_, _) => controller.onSessionsChanged()),
    container.listen(captureControllerProvider, (_, _) => controller.onCaptureChanged()),
    container.listen(pendingQueueCountProvider, (_, _) => controller.onCaptureChanged()),
    container.listen(activeSynthesisProfileProvider, (_, _) => controller.onModelChanged()),
    container.listen(synthesisRunEndProvider, (_, end) {
      final result = end.result;
      if (result != null) controller.onRunEnded(result);
    }),
  ];
  ref.onDispose(() {
    for (final subscription in subscriptions) {
      subscription.close();
    }
    controller.dispose();
  });
  return controller;
});
