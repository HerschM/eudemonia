import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/home/application/shell_state.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/search/presentation/search_page.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';

SynthesisCluster cluster(String id, String content, {String number = '#S-01', String folder = 'Ideas'}) =>
    SynthesisCluster(
      clusterId: id,
      sequenceNumber: number,
      folder: folder,
      synthesizedContent: content,
      sessionStart: DateTime(2026, 11, 21, 9, 5),
      sessionEnd: DateTime(2026, 11, 21, 9, 10),
      sessionDuration: const Duration(minutes: 5),
      originNotes: const [],
    );

void main() {
  late ProviderContainer container;

  Future<void> pumpHome(WidgetTester tester, {List<Note> thoughts = const [], List<SynthesisCluster> notes = const []}) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = NotesRepository();
    for (final t in thoughts) {
      await repo.saveNote(t);
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container = ProviderContainer(overrides: [
          notesRepositoryProvider.overrideWithValue(repo),
          synthesisRepositoryProvider.overrideWith(() => SynthesisRepository(notes)),
        ]),
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(child: TextButton(onPressed: () => openSearchPage(context), child: const Text('open'))),
            ),
          ),
        ),
      ),
    );
    addTearDown(container.dispose);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('search_field')), text);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
  }

  testWidgets('opens with an autofocused field and a quiet hint, nothing listed', (tester) async {
    await pumpHome(tester, thoughts: [Note(correctedText: 'Buy milk')]);

    final field = tester.widget<TextField>(find.byKey(const Key('search_field')));
    expect(field.autofocus, isTrue);
    expect(field.decoration!.hintText, 'Search thoughts and notes');
    expect(find.byKey(const Key('search_hint')), findsOneWidget);
    expect(find.byKey(const Key('search_source_label')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('results of both screens appear in one list, each labelled with its screen', (tester) async {
    final thought = Note(correctedText: 'Garden tomatoes need sun', dailySequenceNumber: 4, createdAt: DateTime(2026, 11, 20, 14, 37));
    await pumpHome(tester, thoughts: [thought], notes: [cluster('c1', '# Garden plan\n\nPlant tomatoes in May', number: '#S-02')]);

    await type(tester, 'garden');

    expect(find.byKey(Key('search_result_capture_${thought.id}')), findsOneWidget);
    expect(find.byKey(const Key('search_result_synthesis_c1')), findsOneWidget);
    final labels = tester.widgetList<Text>(find.byKey(const Key('search_source_label'))).map((t) => t.data).toList();
    // Newest first: the note (21/11) before the thought (20/11).
    expect(labels, ['Synthesis', 'Capture']);
    expect(find.text('#S-02 · Garden plan'), findsOneWidget);
    expect(find.text('#04 · 20/11  02:37 PM'), findsOneWidget);
    expect(find.textContaining('21/11'), findsOneWidget, reason: 'the note row shows its date');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the matched words are bold in the snippet', (tester) async {
    await pumpHome(tester, thoughts: [Note(correctedText: 'Buy Milk today')]);

    await type(tester, 'milk');

    final rich = tester.widgetList<RichText>(find.descendant(
      of: find.byType(ListView),
      matching: find.byType(RichText),
    )).firstWhere((r) => r.text.toPlainText() == 'Buy Milk today');
    final spans = <TextSpan>[];
    rich.text.visitChildren((s) {
      if (s is TextSpan && s.text != null) spans.add(s);
      return true;
    });
    expect(spans.map((s) => s.text), ['Buy ', 'Milk', ' today']);
    expect(spans[1].style!.fontWeight, FontWeight.w700);
    expect(spans[0].style?.fontWeight, isNot(FontWeight.w700));
  });

  testWidgets('typing is debounced: the list follows the field only after the pause', (tester) async {
    await pumpHome(tester, thoughts: [Note(correctedText: 'alpha'), Note(correctedText: 'beta')]);

    await tester.enterText(find.byKey(const Key('search_field')), 'alpha');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('search_source_label')), findsNothing);
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byKey(const Key('search_source_label')), findsOneWidget);
  });

  testWidgets('a query that matches nothing says so, and clearing it brings the hint back', (tester) async {
    await pumpHome(tester, thoughts: [Note(correctedText: 'Buy milk')]);

    await type(tester, 'zebra');
    expect(find.text('Nothing matches "zebra"'), findsOneWidget);
    expect(find.byKey(const Key('search_hint')), findsNothing);

    await type(tester, '');
    expect(find.byKey(const Key('search_hint')), findsOneWidget);
    expect(find.textContaining('Nothing matches'), findsNothing);
  });

  testWidgets('choosing a thought closes the page and asks Capture for it', (tester) async {
    final thought = Note(correctedText: 'Buy milk', dailySequenceNumber: 1);
    await pumpHome(tester, thoughts: [thought], notes: [cluster('c1', '# Other')]);

    await type(tester, 'milk');
    await tester.tap(find.byKey(Key('search_result_capture_${thought.id}')));
    await tester.pumpAndSettle();

    expect(find.byType(SearchPage), findsNothing);
    expect(container.read(captureFocusRequestProvider), thought.id);
    expect(container.read(synthesisFocusRequestProvider), isNull);
  });

  testWidgets('choosing a note closes the page and asks Synthesis for it', (tester) async {
    await pumpHome(tester, thoughts: [Note(correctedText: 'unrelated')], notes: [cluster('c1', '# Garden plan\n\ntomatoes')]);

    await type(tester, 'garden');
    await tester.tap(find.byKey(const Key('search_result_synthesis_c1')));
    await tester.pumpAndSettle();

    expect(find.byType(SearchPage), findsNothing);
    expect(container.read(synthesisFocusRequestProvider), 'c1');
    expect(container.read(captureFocusRequestProvider), isNull);
  });

  testWidgets('the back arrow closes the page without any request', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byKey(const Key('search_back_button')));
    await tester.pumpAndSettle();

    expect(find.byType(SearchPage), findsNothing);
    expect(container.read(captureFocusRequestProvider), isNull);
    expect(container.read(synthesisFocusRequestProvider), isNull);
  });
}
