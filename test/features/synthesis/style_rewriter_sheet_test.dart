import 'package:eudemonia/features/synthesis/domain/note_style.dart';
import 'package:eudemonia/features/synthesis/presentation/style_rewriter_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<List<StylePreset>> open(WidgetTester tester, {String selected = 'organised'}) async {
    final chosen = <StylePreset>[];
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => StyleRewriterModal.show(
              context,
              sequenceLabel: '#S-01',
              selectedPresetId: selected,
              onSelectPreset: chosen.add,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return chosen;
  }

  testWidgets('lists the seven styles with their labels and descriptions', (tester) async {
    await open(tester);
    expect(tester.takeException(), isNull);
    expect(StylePreset.defaultPresets.map((p) => p.id), noteStyles.map((s) => s.id));
    for (final s in noteStyles) {
      await tester.scrollUntilVisible(find.text(s.label), 50, scrollable: find.byType(Scrollable).last);
      expect(find.text(s.label), findsOneWidget);
      expect(find.text(s.description), findsOneWidget);
    }
  });

  testWidgets('marks the session\'s current style', (tester) async {
    await open(tester, selected: 'journal');
    expect(find.text('Active'), findsOneWidget);
    final row = find.ancestor(of: find.text('Journal entry'), matching: find.byType(InkWell));
    expect(find.descendant(of: row, matching: find.byIcon(Icons.check)), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('Active')), findsOneWidget);
  });

  testWidgets('returns the chosen style and closes', (tester) async {
    final chosen = await open(tester);
    await tester.scrollUntilVisible(find.text('Actionable next steps'), 50, scrollable: find.byType(Scrollable).last);
    await tester.ensureVisible(find.text('Actionable next steps'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Actionable next steps'));
    await tester.pumpAndSettle();
    expect(chosen.single.id, 'actionable');
    expect(chosen.single.name, 'Actionable next steps');
    expect(find.text('Actionable next steps'), findsNothing);
  });

  testWidgets('an unknown or old style id marks nothing', (tester) async {
    await open(tester, selected: 'concise-old');
    expect(find.text('Active'), findsNothing);
  });
}
