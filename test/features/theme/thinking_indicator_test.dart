import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/theme/widgets/busy_action_button.dart';
import 'package:eudemonia/features/theme/widgets/thinking_indicator.dart';

Future<void> pumpAt360(WidgetTester tester, Widget child, {bool disableAnimations = false}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: const Size(360, 800), disableAnimations: disableAnimations),
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}

void main() {
  group('ThinkingIndicator', () {
    testWidgets('shows a spark and the label with a light band sweeping across it, without a spinner',
        (tester) async {
      await pumpAt360(tester, const ThinkingIndicator(label: 'Synthesizing…'));

      expect(find.byKey(const Key('thinking_spark')), findsOneWidget);
      expect(find.text('Synthesizing…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byKey(const Key('thinking_sweep')), findsOneWidget);
      expect(find.byType(ShaderMask), findsOneWidget);
      expect(tester.takeException(), isNull);

      Offset sparkScale() {
        final t = tester.widget<Transform>(
          find.ancestor(of: find.byKey(const Key('thinking_spark')), matching: find.byType(Transform)).first,
        );
        return Offset(t.transform.storage[0], t.transform.storage[1]);
      }

      final before = sparkScale();
      await tester.pump(const Duration(milliseconds: 400));
      expect(sparkScale(), isNot(before), reason: 'the spark pulses');
      expect(tester.hasRunningAnimations, isTrue);
    });

    testWidgets('is still when the system asks for no animation', (tester) async {
      await pumpAt360(tester, const ThinkingIndicator(label: 'Synthesizing…'), disableAnimations: true);

      expect(find.text('Synthesizing…'), findsOneWidget);
      expect(find.byKey(const Key('thinking_sweep')), findsNothing);
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('can be drawn without motion', (tester) async {
      await pumpAt360(tester, const ThinkingIndicator(label: 'Rewriting this note…', animate: false));

      expect(find.text('Rewriting this note…'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('BusyActionButton', () {
    Widget button({required bool busy, VoidCallback? onPressed}) => BusyActionButton(
          label: 'Synthesize Now',
          busyLabel: 'Synthesizing…',
          icon: Icons.bolt,
          busy: busy,
          onPressed: onPressed,
        );

    testWidgets('idle: tappable with its label; busy: disabled, indicator in the same place and size',
        (tester) async {
      var taps = 0;
      await pumpAt360(tester, button(busy: false, onPressed: () => taps++));
      final idleSize = tester.getSize(find.byType(BusyActionButton));
      final idleCenter = tester.getCenter(find.byType(BusyActionButton));
      expect(find.text('Synthesize Now'), findsOneWidget);
      expect(find.text('Synthesizing…'), findsNothing);

      await tester.tap(find.byType(BusyActionButton));
      expect(taps, 1);

      await pumpAt360(tester, button(busy: true, onPressed: () => taps++));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Synthesizing…'), findsOneWidget);
      expect(find.text('Synthesize Now'), findsNothing);
      expect(tester.getSize(find.byType(BusyActionButton)), idleSize, reason: 'no layout jump');
      expect(tester.getCenter(find.byType(BusyActionButton)), idleCenter);

      await tester.tap(find.byType(BusyActionButton), warnIfMissed: false);
      expect(taps, 1, reason: 'disabled while busy');
      expect(tester.takeException(), isNull);
    });
  });
}
