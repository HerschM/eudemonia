import 'dart:async';

import 'package:eudemonia/features/synthesis/application/synthesis_runner.dart';
import 'package:eudemonia/features/synthesis/application/synthesis_settings.dart';
import 'package:eudemonia/features/synthesis/application/synthesis_trigger_controller.dart';
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

  @override
  Future<SynthesisRunResult> run({required bool manual}) async {
    expect(manual, isFalse);
    runs++;
    return results.isEmpty ? SynthesisRunResult.completed : results.removeAt(0);
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
}
