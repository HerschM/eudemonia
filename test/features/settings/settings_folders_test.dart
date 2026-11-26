import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/settings/presentation/folder_texts.dart';
import 'package:eudemonia/features/synthesis/application/folder_settings.dart';
import 'package:eudemonia/features/synthesis/domain/folder_definition.dart';
import 'package:eudemonia/features/synthesis/domain/note_style.dart';

import 'settings_test_harness.dart';

void main() {
  setUp(mockHardwareChannel);

  late InMemoryFolderStore store;
  late ProviderContainer container;

  setUp(() => store = InMemoryFolderStore());

  Future<void> pumpFolders(WidgetTester tester) async {
    container = await pumpSettingsScreen(tester, folderStore: store, height: 3000);
    await container.read(foldersProvider.notifier).loaded;
    await tester.pumpAndSettle();
  }

  Finder row(String name) => find.byKey(Key('settings_folder_row_$name'));
  List<String> names() => [for (final f in container.read(foldersProvider)) f.name];

  Future<void> openRow(WidgetTester tester, String name) async {
    await tester.ensureVisible(row(name));
    await tester.tap(row(name));
    await tester.pumpAndSettle();
  }

  Future<void> openAdd(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('settings_add_folder_row')));
    await tester.tap(find.byKey(const Key('settings_add_folder_row')));
    await tester.pumpAndSettle();
  }

  Future<void> typeName(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('folder_name_field')), text);
    await tester.pump();
  }

  Future<void> typeDescription(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('folder_description_field')), text);
    await tester.pump();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('folder_save_button')));
    await tester.tap(find.byKey(const Key('folder_save_button')));
    await tester.pumpAndSettle();
  }

  String? errorText(WidgetTester tester) {
    final finder = find.byKey(const Key('folder_error_text'));
    return finder.evaluate().isEmpty ? null : tester.widget<Text>(finder).data;
  }

  group('folder list', () {
    testWidgets('shows the intro, every folder with its description and an edit affordance', (tester) async {
      await pumpFolders(tester);

      expect(find.text('FOLDERS'), findsOneWidget);
      expect(
        find.text('Synthesis files each note in one of these folders. The description tells it what belongs there.'),
        findsOneWidget,
      );
      final list = find.byKey(const Key('settings_folder_list'));
      for (final folder in defaultFolders) {
        expect(find.descendant(of: list, matching: find.text(folder.name)), findsOneWidget);
        final description = tester.widget<Text>(find.descendant(of: list, matching: find.text(folder.description)));
        expect(description.maxLines, 2);
        expect(description.overflow, TextOverflow.ellipsis);
      }
      final name = tester.widget<Text>(find.descendant(of: list, matching: find.text('Work')));
      expect(name.style!.fontWeight, FontWeight.w700);
      expect(find.descendant(of: row('Work'), matching: find.byIcon(Icons.edit_outlined)), findsOneWidget);
      expect(find.text('Add folder'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows stored folders and their own descriptions', (tester) async {
      store.stored = const [
        FolderDefinition(name: 'Garden', description: 'plants and seeds.'),
        FolderDefinition(name: 'Uncategorized', description: 'ignored: fixed by the app.'),
      ];
      await pumpFolders(tester);

      expect(names(), ['Garden', 'Uncategorized']);
      expect(find.text('plants and seeds.'), findsOneWidget);
      expect(find.text('Work'), findsNothing);
    });
  });

  group('add', () {
    testWidgets('Add folder opens an empty editor; Save adds the folder at once', (tester) async {
      await pumpFolders(tester);
      await openAdd(tester);

      expect(find.text('New folder'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('folder_name_field'))).controller!.text, isEmpty);
      expect(find.byKey(const Key('folder_delete_button')), findsNothing);
      // Counters show the limits.
      expect(find.text('0/$maxFolderNameLength'), findsOneWidget);
      expect(find.text('0/$maxFolderDescriptionLength'), findsOneWidget);

      await typeName(tester, 'Garden');
      await typeDescription(tester, 'plants, the allotment, seeds.');
      await save(tester);

      expect(find.byKey(const Key('folder_name_field')), findsNothing, reason: 'sheet closed');
      expect(names(), ['Work', 'Personal', 'Journal', 'Garden', 'Uncategorized']);
      expect(find.text('plants, the allotment, seeds.'), findsOneWidget);
      expect(row('Garden'), findsOneWidget);
      expect(store.stored!.map((f) => f.name), contains('Garden'));
    });

    testWidgets('an empty name says to give the folder a name and keeps the editor open', (tester) async {
      await pumpFolders(tester);
      await openAdd(tester);
      await typeDescription(tester, 'something');
      await save(tester);

      expect(errorText(tester), 'Give the folder a name.');
      expect(names(), ['Work', 'Personal', 'Journal', 'Uncategorized']);
    });

    testWidgets('a name already in use says so, whatever the case', (tester) async {
      await pumpFolders(tester);
      await openAdd(tester);
      await typeName(tester, 'journal');
      await save(tester);

      expect(errorText(tester), 'There is already a folder with this name.');
      expect(find.byKey(const Key('folder_name_field')), findsOneWidget);
    });

    testWidgets('the limit is enforced while typing and shown by the counters', (tester) async {
      await pumpFolders(tester);
      await openAdd(tester);

      await typeName(tester, 'x' * 40);
      await typeDescription(tester, 'y' * 300);

      expect(find.text('$maxFolderNameLength/$maxFolderNameLength'), findsOneWidget);
      expect(find.text('$maxFolderDescriptionLength/$maxFolderDescriptionLength'), findsOneWidget);
    });

    testWidgets('at the limit Add folder is disabled with a hint', (tester) async {
      store.stored = [
        for (var i = 1; i < maxFolderCount; i++) FolderDefinition(name: 'Folder $i', description: 'd$i'),
      ];
      await pumpFolders(tester);

      expect(container.read(foldersProvider), hasLength(maxFolderCount));
      expect(find.text('You can have up to 12 folders.'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('settings_add_folder_row')));
      await tester.tap(find.byKey(const Key('settings_add_folder_row')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('folder_name_field')), findsNothing);
    });

    testWidgets('below the limit there is no hint', (tester) async {
      await pumpFolders(tester);
      expect(find.text('You can have up to 12 folders.'), findsNothing);
    });
  });

  group('edit', () {
    testWidgets('the editor starts filled with the folder; a new description is saved without renaming',
        (tester) async {
      await pumpFolders(tester);
      await openRow(tester, 'Work');

      expect(find.text('Edit folder'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('folder_name_field'))).controller!.text, 'Work');
      expect(
        tester.widget<TextField>(find.byKey(const Key('folder_description_field'))).controller!.text,
        defaultFolders.first.description,
      );

      await typeDescription(tester, 'the day job and clients.');
      await save(tester);

      expect(names(), ['Work', 'Personal', 'Journal', 'Uncategorized']);
      expect(find.text('the day job and clients.'), findsOneWidget);
    });

    testWidgets('a new name renames the folder in the list at once', (tester) async {
      await pumpFolders(tester);
      await openRow(tester, 'Personal');
      await typeName(tester, 'Home');
      await save(tester);

      expect(names(), ['Work', 'Home', 'Journal', 'Uncategorized']);
      expect(find.byKey(const Key('settings_folder_row_Home')), findsOneWidget);
      expect(row('Personal'), findsNothing);
    });

    testWidgets('changing both renames first, then updates the description under the new name', (tester) async {
      await pumpFolders(tester);
      await openRow(tester, 'Journal');
      await typeName(tester, 'Diary');
      await typeDescription(tester, 'how I feel.');
      await save(tester);

      final diary = container.read(foldersProvider).firstWhere((f) => f.name == 'Diary');
      expect(diary.description, 'how I feel.');
      expect(names(), ['Work', 'Personal', 'Diary', 'Uncategorized']);
    });

    testWidgets('renaming to a taken name shows the message and changes nothing', (tester) async {
      await pumpFolders(tester);
      await openRow(tester, 'Work');
      await typeName(tester, 'Personal');
      await typeDescription(tester, 'should not be saved either.');
      await save(tester);

      expect(errorText(tester), 'There is already a folder with this name.');
      expect(names(), ['Work', 'Personal', 'Journal', 'Uncategorized']);
      expect(container.read(foldersProvider).first.description, defaultFolders.first.description);
    });

    testWidgets('an emptied name asks for a name', (tester) async {
      await pumpFolders(tester);
      await openRow(tester, 'Work');
      await typeName(tester, '   ');
      await save(tester);

      expect(errorText(tester), 'Give the folder a name.');
    });

    testWidgets('after a refused change a corrected Save goes through', (tester) async {
      await pumpFolders(tester);
      await openRow(tester, 'Work');
      await typeName(tester, 'Journal');
      await save(tester);
      expect(errorText(tester), isNotNull);

      await typeName(tester, 'Office');
      await save(tester);

      expect(names(), ['Office', 'Personal', 'Journal', 'Uncategorized']);
    });
  });

  group('delete', () {
    testWidgets('Delete folder asks first, naming where notes go; Cancel keeps the folder', (tester) async {
      await pumpFolders(tester);
      await openRow(tester, 'Personal');
      await tester.ensureVisible(find.byKey(const Key('folder_delete_button')));
      await tester.tap(find.byKey(const Key('folder_delete_button')));
      await tester.pumpAndSettle();

      expect(find.text('Notes in "Personal" will move to Uncategorized.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('folder_delete_cancel')));
      await tester.pumpAndSettle();

      expect(names(), contains('Personal'));
      expect(find.byKey(const Key('folder_name_field')), findsOneWidget, reason: 'editor still open');
    });

    testWidgets('confirming removes the folder from the list at once', (tester) async {
      await pumpFolders(tester);
      await openRow(tester, 'Personal');
      await tester.ensureVisible(find.byKey(const Key('folder_delete_button')));
      await tester.tap(find.byKey(const Key('folder_delete_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('folder_delete_confirm')));
      await tester.pumpAndSettle();

      expect(names(), ['Work', 'Journal', 'Uncategorized']);
      expect(row('Personal'), findsNothing);
      expect(find.byKey(const Key('folder_name_field')), findsNothing, reason: 'sheet closed');
    });
  });

  group('Uncategorized', () {
    testWidgets('opens read-only with its description and the note, and cannot be saved or deleted', (tester) async {
      await pumpFolders(tester);
      expect(find.descendant(of: row('Uncategorized'), matching: find.byIcon(Icons.lock_outline)), findsOneWidget);
      await openRow(tester, 'Uncategorized');

      expect(
        tester.widget<Text>(find.byKey(const Key('folder_readonly_description'))).data,
        defaultFolders.last.description,
      );
      expect(find.text('Catches whatever fits no other folder. It cannot be changed.'), findsOneWidget);
      expect(find.byKey(const Key('folder_name_field')), findsNothing);
      expect(find.byKey(const Key('folder_description_field')), findsNothing);
      expect(find.byKey(const Key('folder_save_button')), findsNothing);
      expect(find.byKey(const Key('folder_delete_button')), findsNothing);
    });
  });

  group('default style', () {
    Finder styleField() => find.byKey(const Key('folder_style_field'));

    Future<void> pickStyle(WidgetTester tester, String label) async {
      await tester.ensureVisible(styleField());
      await tester.tap(styleField());
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    String? rowStyle(WidgetTester tester, String name) {
      final finder = find.byKey(Key('settings_folder_style_$name'));
      return finder.evaluate().isEmpty ? null : tester.widget<Text>(finder).data;
    }

    testWidgets('the editor lists every selectable style by label, starts on the folder\'s and describes it',
        (tester) async {
      await pumpFolders(tester);
      await openRow(tester, 'Work');

      expect(find.text('Default style'), findsOneWidget);
      expect(find.descendant(of: styleField(), matching: find.text('Organised')), findsOneWidget);
      expect(find.text(noteStyleById('organised').description), findsOneWidget);

      await tester.ensureVisible(styleField());
      await tester.tap(styleField());
      await tester.pumpAndSettle();
      for (final s in noteStyles) {
        expect(find.text(s.label), findsWidgets, reason: s.id);
      }
      expect(find.text(manualStyleLabel), findsNothing);
      await tester.tap(find.text('Journal entry').last);
      await tester.pumpAndSettle();
      expect(find.text(noteStyleById('journal').description), findsOneWidget);
    });

    testWidgets('Save stores a changed style; the row then shows it, organised rows show none', (tester) async {
      await pumpFolders(tester);
      expect(rowStyle(tester, 'Work'), isNull);
      await openRow(tester, 'Work');
      await pickStyle(tester, 'Journal entry');
      await save(tester);

      expect(find.byKey(const Key('folder_name_field')), findsNothing, reason: 'sheet closed');
      expect(container.read(foldersProvider).first.defaultStyleId, 'journal');
      expect(store.stored!.first.defaultStyleId, 'journal');
      expect(rowStyle(tester, 'Work'), 'Style: Journal entry');
      expect(rowStyle(tester, 'Personal'), isNull);
    });

    testWidgets('a new folder is added with the style picked in its editor', (tester) async {
      await pumpFolders(tester);
      await openAdd(tester);
      await typeName(tester, 'Garden');
      await pickStyle(tester, 'Actionable next steps');
      await save(tester);

      expect(container.read(foldersProvider).firstWhere((f) => f.name == 'Garden').defaultStyleId, 'actionable');
      expect(rowStyle(tester, 'Garden'), 'Style: Actionable next steps');
    });

    testWidgets('renaming and restyling together applies both', (tester) async {
      await pumpFolders(tester);
      await openRow(tester, 'Journal');
      await typeName(tester, 'Diary');
      await pickStyle(tester, 'Casual note');
      await save(tester);

      final diary = container.read(foldersProvider).firstWhere((f) => f.name == 'Diary');
      expect(diary.defaultStyleId, 'casual');
    });

    testWidgets('Uncategorized keeps its name and description read-only but its style can be changed',
        (tester) async {
      await pumpFolders(tester);
      await openRow(tester, 'Uncategorized');

      expect(find.byKey(const Key('folder_name_field')), findsNothing);
      expect(find.byKey(const Key('folder_description_field')), findsNothing);
      await pickStyle(tester, 'Key points');

      expect(container.read(foldersProvider).last.defaultStyleId, 'bullets');
      expect(container.read(foldersProvider).last.description, defaultFolders.last.description);
      await tester.tap(find.byKey(const Key('folder_editor_close')));
      await tester.pumpAndSettle();
      expect(rowStyle(tester, 'Uncategorized'), 'Style: Key points');
    });
  });

  group('messages', () {
    test('every refusal has its own plain message', () {
      final messages = {
        for (final change in FolderChange.values.where((c) => c != FolderChange.done))
          change: folderChangeMessage(change),
      };
      expect(messages[FolderChange.nameEmpty], 'Give the folder a name.');
      expect(messages[FolderChange.nameTaken], 'There is already a folder with this name.');
      expect(messages[FolderChange.nameTooLong], 'A folder name can be up to 24 characters.');
      expect(messages[FolderChange.nameInvalid], 'A folder name must be a single line of text.');
      expect(messages[FolderChange.descriptionTooLong], 'A description can be up to 200 characters.');
      expect(messages[FolderChange.tooManyFolders], 'You can have up to 12 folders.');
      expect(messages[FolderChange.protectedFolder], 'Uncategorized cannot be changed.');
      expect(messages[FolderChange.notFound], 'This folder no longer exists.');
      expect(messages[FolderChange.styleUnknown], 'Choose one of the listed styles.');
      expect(messages.values.toSet(), hasLength(messages.length), reason: 'no two share a message');
      expect(folderChangeMessage(FolderChange.done), isEmpty);
    });
  });
}
