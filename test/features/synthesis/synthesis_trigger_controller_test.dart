import 'dart:async';

import 'package:eudemonia/features/synthesis/application/synthesis_runner.dart';
import 'package:eudemonia/features/synthesis/application/synthesis_settings.dart';
import 'package:eudemonia/features/synthesis/application/synthesis_trigger_controller.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeTimer implements Timer {
  final FakeClock clock;
  final Duration due;
  final void Function() callback;
  bool _active = true;

  FakeTimer(this.clock, this.due, this.callback);

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;

  @override
  void cancel() => _active = false;

  void fire() {
    _active = false;
    callback();
  }
}

class FakeClock {
  Duration now = Duration.zero;
  final List<FakeTimer> timers = [];

  Timer create(Duration duration, void Function() callback) {
    final t = FakeTimer(this, now + duration, callback);
    timers.add(t);
    return t;
  }

  Future<void> elapse(Duration d) async {
    final end = now + d;
    while (true) {
      final due = timers.where((t) => t.isActive && t.due <= end).toList()..sort((a, b) => a.due.compareTo(b.due));
      if (due.isEmpty) break;
      now = due.first.due;
      due.first.fire();
      await pumpEventQueue();
    }
    now = end;
    await pumpEventQueue();
  }
}

class FakeRunner implements SynthesisRunner {
  final List<SynthesisRunResult> results = [];
  int runs = 0;
  bool running = false;

  /// Stands in for the app wiring that tells the controller how every run ended.
  void Function(SynthesisRunResult result)? onEnded;

  @override
  bool get isRunning => running;

  @override
  Future<SynthesisRunResult> run({required bool manual}) async {
    expect(manual, isFalse);
    runs++;
    final result = results.isEmpty ? SynthesisRunResult.completed : results.removeAt(0);
    onEnded?.call(result);
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

void main() {
  late FakeClock clock;
  late FakeRunner runner;
  late int eligible;
  late SynthesisSettings settings;
  late SynthesisTriggerController controller;

  setUp(() {
    clock = FakeClock();
    runner = FakeRunner();
    eligible = 0;
    settings = const SynthesisSettings(noteThreshold: 3, inactivityMinutes: 15);
    controller = SynthesisTriggerController(
      runner: runner,
      eligibleCount: () async => eligible,
      settings: () => settings,
      createTimer: clock.create,
    );
  });

  tearDown(() => controller.dispose());

  Future<void> saved() async {
    eligible++;
    await controller.onThoughtSaved();
  }

  test('reaching the threshold runs after the settle delay', () async {
    await saved();
    await saved();
    await clock.elapse(const Duration(minutes: 1));
    expect(runner.runs, 0);

    await saved();
    await clock.elapse(const Duration(seconds: 19));
    expect(runner.runs, 0);
    await clock.elapse(const Duration(seconds: 1));
    expect(runner.runs, 1);
  });

  test('every new thought restarts the settle delay', () async {
    eligible = 2;
    await saved();
    await clock.elapse(const Duration(seconds: 15));
    await saved();
    await clock.elapse(const Duration(seconds: 15));
    expect(runner.runs, 0);
    await clock.elapse(const Duration(seconds: 5));
    expect(runner.runs, 1);
  });

  test('the quiet window runs with a single waiting thought', () async {
    await saved();
    await clock.elapse(const Duration(minutes: 10));
    await saved();
    await clock.elapse(const Duration(minutes: 14));
    expect(runner.runs, 0);
    await clock.elapse(const Duration(minutes: 1));
    // Two thoughts are below the threshold; only the quiet window fires.
    expect(runner.runs, 1);
  });

  test('the quiet window does not run without waiting thoughts', () async {
    await controller.start();
    await clock.elapse(const Duration(minutes: 30));
    expect(runner.runs, 0);
  });

  test('start does not run thoughts left from before until the quiet window passes', () async {
    eligible = 4;
    await controller.start();
    await clock.elapse(const Duration(minutes: 14));
    expect(runner.runs, 0);
    await clock.elapse(const Duration(minutes: 1));
    expect(runner.runs, 1);
  });

  test('a busy run is retried once after 60 s while thoughts wait', () async {
    eligible = 3;
    runner.results.add(SynthesisRunResult.busy);
    await controller.onThoughtSaved();
    await clock.elapse(SynthesisTriggerController.settleDelay);
    expect(runner.runs, 1);
    await clock.elapse(const Duration(seconds: 59));
    expect(runner.runs, 1);
    await clock.elapse(const Duration(seconds: 1));
    expect(runner.runs, 2);
    // The retry completed; nothing else is scheduled before the quiet window.
    await clock.elapse(const Duration(minutes: 13));
    expect(runner.runs, 2);
  });

  test('no retry for a busy run once no thoughts wait', () async {
    eligible = 3;
    runner.results.add(SynthesisRunResult.busy);
    await controller.onThoughtSaved();
    await clock.elapse(const Duration(seconds: 19));
    eligible = 0;
    await clock.elapse(const Duration(seconds: 1));
    await clock.elapse(const Duration(minutes: 2));
    expect(runner.runs, 0);
  });

  for (final result in [SynthesisRunResult.failed, SynthesisRunResult.completed, SynthesisRunResult.noModel]) {
    test('no reschedule after a ${result.name} run', () async {
      eligible = 3;
      runner.results.add(result);
      await controller.onThoughtSaved();
      await clock.elapse(SynthesisTriggerController.settleDelay);
      expect(runner.runs, 1);
      await clock.elapse(const Duration(minutes: 5));
      expect(runner.runs, 1);
    });
  }

  test('a preempted run is retried after 60 s while thoughts wait', () async {
    eligible = 3;
    runner.results.add(SynthesisRunResult.preempted);
    await controller.onThoughtSaved();
    await clock.elapse(SynthesisTriggerController.settleDelay);
    expect(runner.runs, 1);
    await clock.elapse(const Duration(seconds: 60));
    expect(runner.runs, 2);
  });

  test('dispose cancels every timer', () async {
    eligible = 3;
    await controller.start();
    await controller.onThoughtSaved();
    controller.dispose();
    await clock.elapse(const Duration(hours: 1));
    expect(runner.runs, 0);
  });

  group('a session flagged for rewrite never sits without a run', () {
    late List<SynthesisCluster> sessions;
    late bool captureActive;

    SynthesisCluster session(String id, {bool flagged = true, String style = 'organised'}) => SynthesisCluster(
          clusterId: id,
          sequenceNumber: '#S-01',
          folder: 'Work',
          synthesizedContent: 'Note $id',
          sessionStart: DateTime(2026, 11, 27, 9),
          sessionEnd: DateTime(2026, 11, 27, 9),
          sessionDuration: Duration.zero,
          originNotes: [
            SynthesisOriginNote(id: 1, formattedSequence: '#01', cleanedText: 'Thought', timestamp: DateTime(2026, 11, 27, 9)),
          ],
          isReprocessing: flagged,
          appliedStyleId: style,
        );

    setUp(() {
      controller.dispose();
      sessions = [];
      captureActive = false;
      controller = SynthesisTriggerController(
        runner: runner,
        eligibleCount: () async => eligible,
        settings: () => settings,
        createTimer: clock.create,
        sessions: () => sessions,
        isCaptureActive: () => captureActive,
      );
      // A completed run rewrites the flagged sessions, as the real runner does.
      runner.onEnded = (result) {
        if (result == SynthesisRunResult.completed) {
          sessions = [for (final s in sessions) s.copyWith(isReprocessing: false)];
        }
        controller.onRunEnded(result);
      };
    });

    test('a flag (a merge, a moved thought) starts a run at once, without waiting for thoughts', () async {
      sessions = [session('a')];
      controller.onSessionsChanged();
      await pumpEventQueue();
      expect(runner.runs, 1);
    });

    test('no run without flagged sessions', () async {
      sessions = [session('a', flagged: false)];
      controller.onSessionsChanged();
      controller.onCaptureChanged();
      await controller.start();
      await clock.elapse(const Duration(minutes: 30));
      expect(runner.runs, 0);
    });

    test('sessions left flagged from before start a run at app start', () async {
      sessions = [session('a')];
      await controller.start();
      await pumpEventQueue();
      expect(runner.runs, 1);
    });

    test('while capture is active nothing starts; the run starts when capture clears', () async {
      sessions = [session('a')];
      captureActive = true;
      controller.onSessionsChanged();
      await pumpEventQueue();
      expect(runner.runs, 0);

      captureActive = false;
      controller.onCaptureChanged();
      await pumpEventQueue();
      expect(runner.runs, 1);
    });

    test('while capture is active a retry is also armed, for a recording that never reaches the queue', () async {
      sessions = [session('a')];
      captureActive = true;
      controller.onSessionsChanged();
      await pumpEventQueue();
      captureActive = false;
      await clock.elapse(SynthesisTriggerController.busyRetryDelay);
      expect(runner.runs, 1);
    });

    test('while another run is going nothing starts; its end starts the rewrite', () async {
      sessions = [session('a')];
      runner.running = true;
      controller.onSessionsChanged();
      await pumpEventQueue();
      expect(runner.runs, 0);

      runner.running = false;
      controller.onRunEnded(SynthesisRunResult.completed);
      await pumpEventQueue();
      expect(runner.runs, 1);
    });

    test('a busy run is retried after 60 s while sessions are flagged, not at once', () async {
      sessions = [session('a')];
      runner.results.add(SynthesisRunResult.busy);
      controller.onSessionsChanged();
      await pumpEventQueue();
      expect(runner.runs, 1);
      await clock.elapse(const Duration(seconds: 59));
      expect(runner.runs, 1);
      await clock.elapse(const Duration(seconds: 1));
      expect(runner.runs, 2);
      expect(sessions.single.isReprocessing, isFalse);
    });

    test('a preempted rewrite runs again once capture clears', () async {
      sessions = [session('a')];
      runner.results.add(SynthesisRunResult.preempted);
      controller.onSessionsChanged();
      await pumpEventQueue();
      expect(runner.runs, 1);

      captureActive = true;
      controller.onCaptureChanged();
      await pumpEventQueue();
      expect(runner.runs, 1);
      captureActive = false;
      controller.onCaptureChanged();
      await pumpEventQueue();
      expect(runner.runs, 2);
    });

    for (final result in [SynthesisRunResult.failed, SynthesisRunResult.noModel]) {
      test('a ${result.name} run is not repeated for the same flags; a change to them starts one', () async {
        sessions = [session('a')];
        runner.results.add(result);
        controller.onSessionsChanged();
        await pumpEventQueue();
        expect(runner.runs, 1);

        controller.onSessionsChanged();
        controller.onCaptureChanged();
        await clock.elapse(const Duration(minutes: 5));
        expect(runner.runs, 1);

        sessions = [session('a', style: 'bullets')];
        controller.onSessionsChanged();
        await pumpEventQueue();
        expect(runner.runs, 2);
      });
    }

    test('a writing model chosen after a run found none starts the rewrite', () async {
      sessions = [session('a')];
      runner.results.add(SynthesisRunResult.noModel);
      controller.onSessionsChanged();
      await pumpEventQueue();
      expect(runner.runs, 1);

      controller.onModelChanged();
      await pumpEventQueue();
      expect(runner.runs, 2);
    });

    test('flags a completed run left are run once more, but a run that leaves them unchanged is not repeated',
        () async {
      sessions = [session('a')];
      // A run that leaves the flags as they were, e.g. flagged again in the same style meanwhile.
      runner.onEnded = controller.onRunEnded;
      controller.onSessionsChanged();
      await pumpEventQueue();
      expect(runner.runs, 2, reason: 'flagged again while the first run was ending');
      await clock.elapse(const Duration(minutes: 5));
      expect(runner.runs, 2);
    });

    test('several changes at once start one run', () async {
      sessions = [session('a')];
      runner.results.add(SynthesisRunResult.busy);
      controller.onSessionsChanged();
      controller.onSessionsChanged();
      controller.onCaptureChanged();
      await pumpEventQueue();
      expect(runner.runs, 1);
    });

    test('dispose stops every rewrite check', () async {
      sessions = [session('a')];
      controller.onSessionsChanged();
      controller.dispose();
      await pumpEventQueue();
      controller.onRunEnded(SynthesisRunResult.busy);
      await clock.elapse(const Duration(hours: 1));
      expect(runner.runs, 0);
    });
  });
}
