import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/settings/background_permission_service.dart';
import 'package:eudemonia/features/settings/settings_screen.dart';
import 'package:eudemonia/features/synthesis/application/folder_settings.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/synthesis/presentation/notes_view_prefs.dart';

import '../synthesis/notes_view_test_support.dart';
import 'fake_permission_gateway.dart';
import 'settings_test_harness.dart';

void main() {
  setUp(mockHardwareChannel);

  Future<ProviderContainer> pumpSettings(WidgetTester tester, InMemoryNotesViewPrefsStore store) async {
    tester.view.physicalSize = const Size(360, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          runtimePermissionGatewayProvider.overrideWithValue(FakePermissionGateway()),
          folderStoreProvider.overrideWithValue(InMemoryFolderStore()),
          notesRepositoryProvider.overrideWithValue(NotesRepository()),
          notesViewPrefsStoreProvider.overrideWithValue(store),
          synthesisRepositoryProvider.overrideWith(() => SynthesisRepository(const [])),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)));
  }

  testWidgets('the NOTES section sits right after automatic synthesis, with its switch off and its helper text', (tester) async {
    await pumpSettings(tester, InMemoryNotesViewPrefsStore());

    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(find.text('NOTES'), findsOneWidget);
    expect(top('AUTOMATIC SYNTHESIS'), lessThan(top('NOTES')));
    expect(top('NOTES'), lessThan(top('ON-DEVICE MODELS')));
    expect(find.text('Show notes opened'), findsOneWidget);
    expect(find.text('Off: a list of titles that open when tapped. On: every note is shown in full.'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('notes_open_by_default_switch'))).value, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the switch changes the preference and stores it', (tester) async {
    final store = InMemoryNotesViewPrefsStore();
    final container = await pumpSettings(tester, store);

    await tester.tap(find.byKey(const Key('notes_open_by_default_switch')));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('notes_open_by_default_switch'))).value, isTrue);
    expect(container.read(notesViewPrefsProvider).notesOpenByDefault, isTrue);
    expect(store.stored!.notesOpenByDefault, isTrue);
    expect(store.stored!.readMode, isTrue, reason: 'the other preference is kept');

    await tester.tap(find.byKey(const Key('notes_open_by_default_switch')));
    await tester.pumpAndSettle();
    expect(container.read(notesViewPrefsProvider).notesOpenByDefault, isFalse);
    expect(store.stored!.notesOpenByDefault, isFalse);
  });

  testWidgets('a stored preference is shown when Settings opens', (tester) async {
    await pumpSettings(tester, InMemoryNotesViewPrefsStore(openEditPrefs));
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('notes_open_by_default_switch'))).value, isTrue);
  });
}
