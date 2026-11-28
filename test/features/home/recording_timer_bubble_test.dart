import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/home/presentation/recording_timer_bubble.dart';
import 'package:eudemonia/features/theme/widgets/voice_wave_indicator.dart';

/// The timer of the middle bubble while recording. Carries over the checks of the removed
/// `FloatingCaptureCapsule` timer; user decision 13 (2026-11-28) drops its ` • Tap to Stop` suffix.
void main() {
  Future<void> pumpBubble(WidgetTester tester, {required DateTime startedAt, Duration? maxDuration}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 200, child: RecordingTimerBubble(startedAt: startedAt, maxDuration: maxDuration)),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('without a limit the timer shows elapsed time only, from the real start', (tester) async {
    await pumpBubble(tester, startedAt: DateTime.now().subtract(const Duration(seconds: 65, milliseconds: 200)));
    expect(find.byKey(const Key('recording_timer_text')), findsOneWidget);
    expect(find.text('01:05'), findsOneWidget);
    expect(find.byKey(const Key('recording_dot')), findsOneWidget);
    expect(find.byType(VoiceWaveIndicator), findsOneWidget, reason: 'the voice wave of the old capsule is kept');
  });

  testWidgets('with a limit the timer reads elapsed / limit', (tester) async {
    await pumpBubble(
      tester,
      startedAt: DateTime.now().subtract(const Duration(seconds: 90, milliseconds: 200)),
      maxDuration: const Duration(minutes: 5),
    );
    expect(find.text('01:30 / 05:00'), findsOneWidget);
  });

  testWidgets('a tick rebuilds the timer text every second without errors', (tester) async {
    await pumpBubble(tester, startedAt: DateTime.now().subtract(const Duration(milliseconds: 200)));
    expect(find.text('00:00'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('recording_timer_text')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a start time that turns up later moves the timer', (tester) async {
    final now = DateTime.now();
    await pumpBubble(tester, startedAt: now.subtract(const Duration(seconds: 10, milliseconds: 200)));
    expect(find.text('00:10'), findsOneWidget);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 200,
            child: RecordingTimerBubble(startedAt: now.subtract(const Duration(seconds: 30, milliseconds: 200))),
          ),
        ),
      ),
    ));
    expect(find.text('00:30'), findsOneWidget);
  });

  testWidgets('the bubble stops its ticker when it goes away', (tester) async {
    await pumpBubble(tester, startedAt: DateTime.now());
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });
}
