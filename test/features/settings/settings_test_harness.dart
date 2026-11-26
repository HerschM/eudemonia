import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/capture/native_capture_channel.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/settings/background_permission_service.dart';
import 'package:eudemonia/features/settings/settings_screen.dart';
import 'package:eudemonia/features/synthesis/application/folder_settings.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/synthesis/domain/folder_definition.dart';

import '../capture/capture_test_doubles.dart';
import 'fake_permission_gateway.dart';

/// Folder storage in memory, so Settings tests never touch shared preferences.
class InMemoryFolderStore implements FolderStore {
  List<FolderDefinition>? stored;
  int saves = 0;

  InMemoryFolderStore([this.stored]);

  @override
  Future<List<FolderDefinition>?> load() async => stored;

  @override
  Future<void> save(List<FolderDefinition> folders) async {
    saves++;
    stored = List.of(folders);
  }
}

/// The hardware-button channel answers "running" so the background switch reads as on.
void mockHardwareChannel() {
  const channel = MethodChannel('com.eudemonia/hardware_buttons');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(channel, (call) async => call.method.startsWith('is') ? true : null);
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
}

/// Pumps [SettingsScreen] on a 360 dp phone. Returns the container so tests can read providers.
Future<ProviderContainer> pumpSettingsScreen(
  WidgetTester tester, {
  FakePermissionGateway? permissions,
  InMemoryFolderStore? folderStore,
  FakeNativeCaptureChannel? capture,
  NotesRepository? notes,
  double height = 1400,
}) async {
  tester.view.physicalSize = Size(360, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        runtimePermissionGatewayProvider.overrideWithValue(permissions ?? FakePermissionGateway()),
        folderStoreProvider.overrideWithValue(folderStore ?? InMemoryFolderStore()),
        notesRepositoryProvider.overrideWithValue(notes ?? NotesRepository()),
        synthesisRepositoryProvider.overrideWith(() => SynthesisRepository(const [])),
        if (capture != null) nativeCaptureChannelProvider.overrideWithValue(capture),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)));
}

/// Opens the collapsible section whose header has [headerKey], scrolling it into view first.
Future<void> expandSection(WidgetTester tester, String headerKey) async {
  final header = find.byKey(Key(headerKey));
  await tester.scrollUntilVisible(header, 200, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.tap(header);
  await tester.pumpAndSettle();
}

/// Removes the screen so periodic timers stop before the test ends.
Future<void> unmountScreen(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}
