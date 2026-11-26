import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/home/main_navigation_shell.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/settings/background_permission_service.dart';
import 'package:eudemonia/features/settings/settings_screen.dart';
import 'package:eudemonia/features/settings/system_telemetry_service.dart';
import 'package:eudemonia/features/synthesis/application/folder_settings.dart';

import 'fake_permission_gateway.dart';
import 'settings_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const telemetryChannel = MethodChannel('com.eudemonia/system_telemetry');
  const hardwareChannel = MethodChannel('com.eudemonia/hardware_buttons');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  const gb = 1024 * 1024 * 1024;
  const mb = 1024 * 1024;

  void mockTelemetry(Object? Function() reading) {
    messenger.setMockMethodCallHandler(telemetryChannel, (call) async {
      expect(call.method, 'getSnapshot');
      return reading();
    });
  }

  setUp(() {
    messenger.setMockMethodCallHandler(hardwareChannel, (call) async {
      return call.method.startsWith('is') ? true : null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(telemetryChannel, null);
    messenger.setMockMethodCallHandler(hardwareChannel, null);
  });

  group('SystemTelemetry model', () {
    test('maps a full OS reading and derives display values', () {
      final telemetry = SystemTelemetry.fromMap(const {
        'thermalStatus': 0,
        'thermalHeadroom': 0.16,
        'appMemoryBytes': 1536 * mb,
        'deviceAvailableBytes': 2 * gb,
        'deviceTotalBytes': 8 * gb,
        'isLowMemory': false,
      });

      expect(telemetry.thermalSummary, '84% (Nominal)');
      expect(telemetry.isThermallyThrottled, isFalse);
      expect(telemetry.appMemoryLabel, '1.50 GB');
      expect(telemetry.deviceMemoryLabel, '2.00 GB free of 8.00 GB');
    });

    test('headroom beyond the severe threshold clamps to 0% and flags throttling', () {
      final telemetry = SystemTelemetry.fromMap(const {'thermalStatus': 3, 'thermalHeadroom': 1.2});

      expect(telemetry.thermalSummary, '0% (Severe)');
      expect(telemetry.isThermallyThrottled, isTrue);
    });

    test('values the device cannot report stay unavailable instead of being estimated', () {
      final telemetry = SystemTelemetry.fromMap(const {});

      expect(telemetry.thermalSummary, 'Unavailable on this device');
      expect(telemetry.appMemoryLabel, isNull);
      expect(telemetry.deviceMemoryLabel, isNull);

      final statusOnly = SystemTelemetry.fromMap(const {'thermalStatus': 2});
      expect(statusOnly.thermalSummary, 'Moderate');
    });

    test('small footprints are formatted in megabytes', () {
      expect(SystemTelemetry.formatBytes(58 * mb), '58 MB');
    });
  });

  group('SystemTelemetryService', () {
    test('reads a snapshot from the platform channel', () async {
      mockTelemetry(() => {'thermalStatus': 1, 'appMemoryBytes': 64 * mb});

      final telemetry = await const SystemTelemetryService().read();

      expect(telemetry?.thermalStatusLabel, 'Light');
      expect(telemetry?.appMemoryBytes, 64 * mb);
    });

    test('returns null when the platform cannot be queried', () async {
      expect(await const SystemTelemetryService().read(), isNull);

      mockTelemetry(() => throw PlatformException(code: 'UNAVAILABLE'));
      expect(await const SystemTelemetryService().read(), isNull);
    });
  });

  group('Settings shows live device readings', () {
    Future<void> pumpSettings(WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            runtimePermissionGatewayProvider.overrideWithValue(FakePermissionGateway()),
            notesRepositoryProvider.overrideWithValue(NotesRepository()),
            folderStoreProvider.overrideWithValue(InMemoryFolderStore()),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      // The memory section starts collapsed; its readings are only taken once it is open.
      await expandSection(tester, 'settings_memory_header');
      await tester.scrollUntilVisible(
        find.byKey(const Key('evict_models_button')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    String textOf(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

    testWidgets('thermal headroom and memory come from the OS reading and refresh while open',
        (tester) async {
      var appBytes = 1536 * mb;
      mockTelemetry(() => {
            'thermalStatus': 1,
            'thermalHeadroom': 0.35,
            'appMemoryBytes': appBytes,
            'deviceAvailableBytes': 3 * gb,
            'deviceTotalBytes': 8 * gb,
            'isLowMemory': false,
          });

      await pumpSettings(tester);

      expect(textOf(tester, 'thermal_headroom_value'), '65% (Light)');
      expect(textOf(tester, 'app_memory_value'), '1.50 GB');
      expect(textOf(tester, 'device_memory_value'), 'Device: 3.00 GB free of 8.00 GB');
      expect(tester.takeException(), isNull);

      // The next periodic refresh picks up the new footprint.
      appBytes = 60 * mb;
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      expect(textOf(tester, 'app_memory_value'), '60 MB');
    });

    testWidgets('shows Unavailable rather than invented figures when there is no reading', (tester) async {
      await pumpSettings(tester);

      expect(textOf(tester, 'thermal_headroom_value'), 'Unavailable');
      expect(textOf(tester, 'app_memory_value'), 'Unavailable');
      expect(find.byKey(const Key('device_memory_value')), findsNothing);
      expect(find.textContaining('84%'), findsNothing);
      expect(find.textContaining('1.58 GB'), findsNothing);
      expect(find.textContaining('<60 MB'), findsNothing);
    });
  });

  group('Pipeline HUD memory line', () {
    testWidgets('opens immediately and fills in the live reading', (tester) async {
      mockTelemetry(() => {
            'appMemoryBytes': 72 * mb,
            'deviceAvailableBytes': 4 * gb,
            'deviceTotalBytes': 8 * gb,
          });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            runtimePermissionGatewayProvider.overrideWithValue(FakePermissionGateway()),
            notesRepositoryProvider.overrideWithValue(NotesRepository()),
          ],
          child: const MaterialApp(home: MainNavigationShell()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('top_ai_pipeline_pill')));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const Key('hud_memory_telemetry'))).data,
        'AI models unloaded • App memory 72 MB • Device 4.00 GB free of 8.00 GB',
      );
    });

    test('describes an unavailable reading without inventing numbers', () {
      expect(
        describePipelineMemory(modelsLoaded: true, telemetry: null),
        'AI models loaded • live memory reading unavailable',
      );
    });
  });
}
