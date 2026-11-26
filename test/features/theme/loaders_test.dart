import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/theme/widgets/pulse_dots_loader.dart';
import 'package:eudemonia/features/theme/widgets/voice_wave_indicator.dart';

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
  group('PulseDotsLoader', () {
    List<double> opacities(WidgetTester tester) => [
          for (var i = 0; i < 3; i++)
            tester.widget<Opacity>(find.byKey(Key('pulse_dot_$i'))).opacity,
        ];

    testWidgets('renders three dots at 360dp without overflow', (tester) async {
      await pumpAt360(tester, const PulseDotsLoader());
      expect(find.byType(PulseDotsLoader), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        expect(find.byKey(Key('pulse_dot_$i')), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('dots pulse in sequence as frames advance', (tester) async {
      await pumpAt360(tester, const PulseDotsLoader());
      final before = opacities(tester);
      await tester.pump(const Duration(milliseconds: 150));
      final after = opacities(tester);
      expect(after, isNot(before));
      // Staggered: the dots are not all at the same level at the same moment.
      expect(after.toSet().length, greaterThan(1));
    });

    testWidgets('shows static dots when animations are disabled', (tester) async {
      await pumpAt360(tester, const PulseDotsLoader(), disableAnimations: true);
      final before = opacities(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(opacities(tester), before);
      expect(before.toSet().length, 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('stops ticking once removed from the tree', (tester) async {
      await pumpAt360(tester, const PulseDotsLoader());
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  group('VoiceWaveIndicator', () {
    List<double> heights(WidgetTester tester, int bars) => [
          for (var i = 0; i < bars; i++) tester.getSize(find.byKey(Key('voice_wave_bar_$i'))).height,
        ];

    testWidgets('renders the requested number of bars at 360dp without overflow', (tester) async {
      await pumpAt360(tester, const VoiceWaveIndicator());
      expect(find.byKey(const Key('voice_wave_bar_6')), findsOneWidget);
      expect(find.byKey(const Key('voice_wave_bar_7')), findsNothing);
      expect(tester.takeException(), isNull);

      await pumpAt360(tester, const VoiceWaveIndicator(bars: 5, height: 14));
      expect(find.byKey(const Key('voice_wave_bar_4')), findsOneWidget);
      expect(find.byKey(const Key('voice_wave_bar_5')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('bars rise and fall as frames advance and never exceed the height', (tester) async {
      await pumpAt360(tester, const VoiceWaveIndicator(height: 20));
      final before = heights(tester, 7);
      await tester.pump(const Duration(milliseconds: 250));
      final after = heights(tester, 7);
      expect(after, isNot(before));
      for (final h in [...before, ...after]) {
        expect(h, inInclusiveRange(6.0, 20.0));
      }
    });

    testWidgets('shows still bars when animations are disabled', (tester) async {
      await pumpAt360(tester, const VoiceWaveIndicator(), disableAnimations: true);
      final before = heights(tester, 7);
      await tester.pump(const Duration(milliseconds: 300));
      expect(heights(tester, 7), before);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('stops ticking once removed from the tree', (tester) async {
      await pumpAt360(tester, const VoiceWaveIndicator());
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.takeException(), isNull);
    });
  });
}
