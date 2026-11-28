import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/capture/presentation/written_note_sheet.dart';
import 'package:eudemonia/features/capture/written_note_capture.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';

void main() {
  late NotesRepository repo;

  setUp(() => repo = NotesRepository());

  Future<void> pumpHost(WidgetTester tester, {double keyboard = 0}) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          writtenNoteCaptureProvider.overrideWith(
            (ref) => WrittenNoteCapture(
              notes: repo,
              nextSequenceNumber: (day) async => (await repo.maxDailySequenceFor(day)) + 1,
              onSaved: () {},
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  key: const Key('open_sheet'),
                  onPressed: () => showWrittenNoteSheet(context),
                  child: const Text('Write'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('open_sheet')));
    await tester.pumpAndSettle();
  }

  Finder saveButton() => find.byKey(const Key('written_note_save'));

  bool saveEnabled(WidgetTester tester) => tester.widget<ButtonStyleButton>(saveButton()).onPressed != null;

  group('compose sheet', () {
    testWidgets('opens with a focused field, the hint, Save disabled and Cancel', (tester) async {
      await pumpHost(tester);
      await openSheet(tester);

      expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isTrue, reason: 'autofocused');
      expect(find.text('Write a thought'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(saveEnabled(tester), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Save is enabled by text and stays disabled for blank text', (tester) async {
      await pumpHost(tester);
      await openSheet(tester);

      await tester.enterText(find.byKey(const Key('written_note_field')), '   \n ');
      await tester.pump();
      expect(saveEnabled(tester), isFalse);

      await tester.enterText(find.byKey(const Key('written_note_field')), 'A real thought');
      await tester.pump();
      expect(saveEnabled(tester), isTrue);
    });

    testWidgets('Save stores the note, closes the sheet and says which number it got', (tester) async {
      await pumpHost(tester);
      await openSheet(tester);

      await tester.enterText(find.byKey(const Key('written_note_field')), '  Call the dentist.  ');
      await tester.pump();
      await tester.tap(saveButton());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('written_note_field')), findsNothing, reason: 'the sheet closed');
      expect(find.text('Saved a written note [#01]'), findsOneWidget);
      final stored = (await repo.getAllNotes()).single;
      expect(stored.correctedText, 'Call the dentist.');
      expect(stored.isWritten, isTrue);
    });

    testWidgets('Cancel with nothing typed closes without asking and stores nothing', (tester) async {
      await pumpHost(tester);
      await openSheet(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('written_note_field')), findsNothing);
      expect(find.text('Discard this note?'), findsNothing);
      expect(await repo.getAllNotes(), isEmpty);
    });

    testWidgets('closing with text asks first; Keep writing keeps the text, Discard drops it', (tester) async {
      await pumpHost(tester);
      await openSheet(tester);
      await tester.enterText(find.byKey(const Key('written_note_field')), 'Do not lose me');
      await tester.pump();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Discard this note?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('written_note_discard_keep')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('written_note_field')), findsOneWidget);
      expect(find.text('Do not lose me'), findsOneWidget, reason: 'nothing was lost');

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('written_note_discard_confirm')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('written_note_field')), findsNothing);
      expect(await repo.getAllNotes(), isEmpty);
    });

    testWidgets('the back button and a tap outside also ask while there is text', (tester) async {
      await pumpHost(tester);
      await openSheet(tester);
      await tester.enterText(find.byKey(const Key('written_note_field')), 'Accidental swipe');
      await tester.pump();

      await tester.tapAt(const Offset(180, 20));
      await tester.pumpAndSettle();
      expect(find.text('Discard this note?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('written_note_discard_keep')));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Discard this note?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('written_note_discard_keep')));
      await tester.pumpAndSettle();
      expect(find.text('Accidental swipe'), findsOneWidget);
    });

    testWidgets('fits 360x800 with no overflow, also with the keyboard up (Save stays visible)', (tester) async {
      await pumpHost(tester, keyboard: 300);
      await openSheet(tester);
      await tester.enterText(find.byKey(const Key('written_note_field')), List.filled(40, 'a long line of thinking').join('\n'));
      await tester.pump();

      expect(tester.takeException(), isNull);
      final save = tester.getRect(saveButton());
      expect(save.bottom, lessThanOrEqualTo(800 - 300), reason: 'above the keyboard');
      expect(save.left, greaterThanOrEqualTo(0));
      expect(save.right, lessThanOrEqualTo(360));
      expect(tester.getRect(find.byKey(const Key('written_note_field'))).right, lessThanOrEqualTo(360));
    });
  });
}
