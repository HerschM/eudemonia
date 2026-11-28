import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/settings/presentation/folder_style_sheet.dart';
import 'package:eudemonia/features/synthesis/application/folder_settings.dart';
import 'package:eudemonia/features/synthesis/domain/note_style.dart';

import 'settings_test_harness.dart';

/// TASK-106 A (user decision 2026-11-28): the folder editor names each field with a caption above
/// it, never a floating label on the border; the default style is a field that opens a sheet of
/// styles; the vertical rhythm is even. All on a 360 x 800 phone.
void main() {
  setUp(mockHardwareChannel);

  late InMemoryFolderStore store;
  late ProviderContainer container;

  setUp(() => store = InMemoryFolderStore());

  Future<void> pump(WidgetTester tester) async {
    container = await pumpSettingsScreen(tester, folderStore: store, height: 800);
    await container.read(foldersProvider.notifier).loaded;
    await tester.pumpAndSettle();
  }

  Future<void> openAdd(WidgetTester tester) async {
    final add = find.byKey(const Key('settings_add_folder_row'));
    await tester.scrollUntilVisible(add, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(add);
    await tester.pumpAndSettle();
  }

  Future<void> openRow(WidgetTester tester, String name) async {
    final row = find.byKey(Key('settings_folder_row_$name'));
    await tester.scrollUntilVisible(row, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  Finder caption(String text) => find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

  group('captions instead of floating labels', () {
    testWidgets('Name, Description and Default style have a caption above their field, none on its border',
        (tester) async {
      await pump(tester);
      await openAdd(tester);

      for (final key in ['folder_name_field', 'folder_description_field']) {
        final decoration = tester.widget<TextField>(find.byKey(Key(key))).decoration!;
        expect(decoration.labelText, isNull, reason: key);
        expect(decoration.label, isNull, reason: key);
      }
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);

      final pairs = {
        'Name': 'folder_name_field',
        'Description': 'folder_description_field',
        'Default style': 'folder_style_field',
      };
      for (final entry in pairs.entries) {
        expect(caption(entry.key), findsOneWidget, reason: entry.key);
        final text = tester.getRect(caption(entry.key));
        final field = tester.getRect(find.byKey(Key(entry.value)));
        expect(text.bottom, lessThanOrEqualTo(field.top), reason: '${entry.key}: above its field, not on its border');
        expect(field.top - text.bottom, closeTo(6, 0.5), reason: '${entry.key}: 6 between caption and field');
        expect(text.left, field.left + 0, reason: '${entry.key}: aligned with the field');
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('an even rhythm: 16 between the field groups, the help right under the description, counters kept',
        (tester) async {
      await pump(tester);
      await openAdd(tester);

      Rect rect(Finder f) => tester.getRect(f);
      final name = rect(find.byKey(const Key('folder_name_field')));
      final description = rect(find.byKey(const Key('folder_description_field')));
      final help = rect(find.byKey(const Key('folder_description_help')));
      expect(rect(caption('Description')).top - name.bottom, closeTo(16, 0.5));
      expect(help.top - description.bottom, lessThanOrEqualTo(4), reason: 'directly under the description field');
      expect(rect(caption('Default style')).top - help.bottom, closeTo(16, 0.5));
      expect(rect(find.byKey(const Key('folder_save_button'))).top - rect(find.byKey(const Key('folder_style_field'))).bottom,
          closeTo(16, 0.5));
      expect(find.text('0/$maxFolderNameLength'), findsOneWidget);
      expect(find.text('0/$maxFolderDescriptionLength'), findsOneWidget);

      for (final key in ['folder_name_field', 'folder_description_field', 'folder_style_field']) {
        final r = rect(find.byKey(Key(key)));
        expect(r.left, greaterThanOrEqualTo(0), reason: key);
        expect(r.right, lessThanOrEqualTo(360), reason: key);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits 360 x 800 with the keyboard up, the save button still reachable by scrolling',
        (tester) async {
      await pump(tester);
      await openAdd(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const Key('folder_save_button')));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(const Key('folder_save_button'))).bottom, lessThanOrEqualTo(800 - 300));
    });
  });

  group('the default style chooser', () {
    testWidgets('the field shows the chosen style with its description and a chevron; tapping opens a sheet of every style',
        (tester) async {
      await pump(tester);
      await openAdd(tester);

      final field = find.byKey(const Key('folder_style_field'));
      final organised = noteStyleById(defaultNoteStyleId);
      expect(find.descendant(of: field, matching: find.text(organised.label)), findsOneWidget);
      expect(find.descendant(of: field, matching: find.text(organised.description)), findsOneWidget);
      expect(find.descendant(of: field, matching: find.byIcon(Icons.unfold_more)), findsOneWidget);

      await tester.tap(field);
      await tester.pumpAndSettle();

      for (final s in noteStyles) {
        final option = find.byKey(Key('folder_style_option_${s.id}'));
        expect(option, findsOneWidget, reason: s.id);
        expect(find.descendant(of: option, matching: find.text(s.label)), findsOneWidget, reason: s.id);
        final description = find.descendant(of: option, matching: find.text(s.description));
        expect(description, findsOneWidget, reason: s.id);
        expect(tester.getTopLeft(description).dy, greaterThan(tester.getTopLeft(find.descendant(of: option, matching: find.text(s.label))).dy));
        final r = tester.getRect(option);
        expect(r.left, greaterThanOrEqualTo(0), reason: s.id);
        expect(r.right, lessThanOrEqualTo(360), reason: s.id);
      }
      // The list scrolls inside the sheet, which stays on the 360 x 800 screen (the test font is wide).
      final sheet = tester.getRect(find.byType(FolderStyleSheet));
      expect(sheet.top, greaterThanOrEqualTo(0));
      expect(sheet.bottom, lessThanOrEqualTo(800));
      await tester.ensureVisible(find.byKey(const Key('folder_style_option_casual')));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(const Key('folder_style_option_casual'))).bottom, lessThanOrEqualTo(800));
      // Only the chosen row is marked, with a check and no violet fill.
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.descendant(of: find.byKey(Key('folder_style_option_$defaultNoteStyleId')), matching: find.byIcon(Icons.check)),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('choosing a row closes the sheet, updates the field and Save stores the choice', (tester) async {
      await pump(tester);
      await openAdd(tester);
      await tester.enterText(find.byKey(const Key('folder_name_field')), 'Garden');
      await tester.pump();

      await tester.tap(find.byKey(const Key('folder_style_field')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('folder_style_option_journal')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('folder_style_option_journal')), findsNothing, reason: 'the style sheet closed');
      expect(find.byKey(const Key('folder_name_field')), findsOneWidget, reason: 'the editor stays open');
      final field = find.byKey(const Key('folder_style_field'));
      expect(find.descendant(of: field, matching: find.text(noteStyleById('journal').label)), findsOneWidget);
      expect(find.descendant(of: field, matching: find.text(noteStyleById('journal').description)), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('folder_save_button')));
      await tester.tap(find.byKey(const Key('folder_save_button')));
      await tester.pumpAndSettle();
      expect(container.read(foldersProvider).firstWhere((f) => f.name == 'Garden').defaultStyleId, 'journal');
    });

    testWidgets('dismissing the sheet keeps the style', (tester) async {
      await pump(tester);
      await openAdd(tester);
      await tester.tap(find.byKey(const Key('folder_style_field')));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byKey(const Key('folder_style_option_journal')))).pop();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('folder_style_option_journal')), findsNothing);
      expect(
        find.descendant(of: find.byKey(const Key('folder_style_field')), matching: find.text(noteStyleById(defaultNoteStyleId).label)),
        findsOneWidget,
      );
    });

    testWidgets('Uncategorized keeps its texts, gets the same chooser, and stores the style as soon as it is picked',
        (tester) async {
      await pump(tester);
      await openRow(tester, 'Uncategorized');

      expect(find.byKey(const Key('folder_protected_note')), findsOneWidget);
      expect(find.byKey(const Key('folder_readonly_description')), findsOneWidget);
      expect(caption('Default style'), findsOneWidget);
      await tester.tap(find.byKey(const Key('folder_style_field')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('folder_style_option_bullets')));
      await tester.pumpAndSettle();

      expect(container.read(foldersProvider).last.defaultStyleId, 'bullets');
      expect(find.descendant(of: find.byKey(const Key('folder_style_field')), matching: find.text(noteStyleById('bullets').label)),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
