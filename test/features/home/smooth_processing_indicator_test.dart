import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/home/presentation/smooth_processing_indicator.dart';

void main() {
  group('TASK-036 Widget Tests: Hardware-Accelerated Smooth Processing Indicator', () {
    testWidgets('1. Indicator renders without throwing framework layout assertions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SmoothProcessingIndicator(
                size: 24.0,
                strokeWidth: 3.0,
                color: Colors.blue,
              ),
            ),
          ),
        ),
      );

      // Verify widget exists in tree and renders CustomPaint with RepaintBoundary
      expect(find.byType(SmoothProcessingIndicator), findsOneWidget);
      expect(find.byKey(const Key('smooth_indicator_custom_paint')), findsOneWidget);
      expect(find.byType(RepaintBoundary), findsWidgets);

      // Verify no framework assertions or RenderBox layout errors
      expect(tester.takeException(), isNull);
    });

    testWidgets('2. Ticking animation controller drives painter sweep angle continuously', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SmoothProcessingIndicator(
              size: 20.0,
            ),
          ),
        ),
      );

      final initialCustomPaint = tester.widget<CustomPaint>(find.byKey(const Key('smooth_indicator_custom_paint')));
      final initialPainter = initialCustomPaint.painter as dynamic;
      final double initialProgress = initialPainter.progress;

      // Advance time by 200ms
      await tester.pump(const Duration(milliseconds: 200));

      final updatedCustomPaint = tester.widget<CustomPaint>(find.byKey(const Key('smooth_indicator_custom_paint')));
      final updatedPainter = updatedCustomPaint.painter as dynamic;
      final double updatedProgress = updatedPainter.progress;

      // Verify the progress has updated with time tick
      expect(updatedProgress, isNot(equals(initialProgress)));
      expect(updatedProgress, greaterThan(initialProgress));
    });
  });
}
