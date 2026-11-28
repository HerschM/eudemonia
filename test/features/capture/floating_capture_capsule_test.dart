import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/capture/presentation/floating_capture_capsule.dart';

void main() {
  Future<void> pumpCapsule(WidgetTester tester, {required DateTime startedAt, Duration? maxDuration}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: FloatingCaptureCapsule(
            isRecording: true,
            startedAt: startedAt,
            maxDuration: maxDuration,
            onTap: () {},
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('without a limit the timer shows elapsed time only, as before', (tester) async {
    await pumpCapsule(tester, startedAt: DateTime.now().subtract(const Duration(seconds: 65, milliseconds: 200)));
    expect(find.text('01:05 • Tap to Stop'), findsOneWidget);
  });

  testWidgets('with a limit the timer reads elapsed / limit', (tester) async {
    await pumpCapsule(
      tester,
      startedAt: DateTime.now().subtract(const Duration(seconds: 90, milliseconds: 200)),
      maxDuration: const Duration(minutes: 5),
    );
    expect(find.text('01:30 / 05:00 • Tap to Stop'), findsOneWidget);
  });

  testWidgets('idle capsule is unchanged by a limit', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FloatingCaptureCapsule(isRecording: false, maxDuration: const Duration(minutes: 5), onTap: () {}),
      ),
    ));
    expect(find.text('Tap to capture'), findsOneWidget);
    expect(find.byKey(const Key('floating_capture_button')), findsOneWidget);
  });
}
