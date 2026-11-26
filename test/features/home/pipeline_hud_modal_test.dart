import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/home/presentation/pipeline_hud_modal.dart';

void main() {
  Future<void> pump(WidgetTester tester, int ready) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PipelineHudModal(
          captureTranscribingCount: 0,
          synthesisReadyCount: ready,
          onSynthesizeNow: () {},
          memoryTelemetry: Future.value('Memory 40 MB'),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets('Synthesis stage counts waiting thoughts in plain words, singular and plural', (tester) async {
    await pump(tester, 1);
    expect(find.text('1 thought ready for Synthesis'), findsOneWidget);
    expect(find.textContaining('cluster'), findsNothing);

    await pump(tester, 3);
    expect(find.text('3 thoughts ready for Synthesis'), findsOneWidget);
  });
}
