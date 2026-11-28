import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:eudemonia/features/settings/presentation/phone_memory_section.dart';

import 'fake_permission_gateway.dart';
import 'settings_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const telemetryChannel = MethodChannel('com.eudemonia/system_telemetry');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var telemetryReads = 0;

  setUp(() {
    mockHardwareChannel();
    telemetryReads = 0;
    messenger.setMockMethodCallHandler(telemetryChannel, (call) async {
      telemetryReads++;
      return {'thermalStatus': 0, 'thermalHeadroom': 0.2, 'appMemoryBytes': 100 * 1024 * 1024};
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(telemetryChannel, null));

  const memoryHeader = 'settings_memory_header';
  const permissionsHeader = 'settings_permissions_header';

  group('Phone memory and temperature', () {
    testWidgets('starts collapsed, opens on tap and collapses again', (tester) async {
      await pumpSettingsScreen(tester, height: 3000);

      expect(find.text('PHONE MEMORY AND TEMPERATURE'), findsOneWidget);
      expect(find.text('ON-DEVICE AI MEMORY & THERMAL GATING'), findsNothing);
      expect(find.text('Thermal Headroom'), findsNothing);
      expect(find.byKey(const Key('evict_models_button')), findsNothing);

      await expandSection(tester, memoryHeader);
      expect(find.text('Thermal Headroom'), findsOneWidget);
      expect(find.text('App Memory In Use'), findsOneWidget);
      expect(find.text('Free model memory now'), findsOneWidget);
      expect(find.text('Evict Models Now'), findsNothing);
      expect(tester.takeException(), isNull);

      await expandSection(tester, memoryHeader);
      expect(find.text('Thermal Headroom'), findsNothing);
      await unmountScreen(tester);
    });

    testWidgets('readings refresh every 5 seconds only while it is open', (tester) async {
      await pumpSettingsScreen(tester, height: 3000);

      // Collapsed: nothing is read, however long the screen stays open.
      await tester.pump(const Duration(seconds: 12));
      expect(telemetryReads, 0);

      await expandSection(tester, memoryHeader);
      final afterOpen = telemetryReads;
      expect(afterOpen, greaterThan(0));

      await tester.pump(telemetryRefreshInterval + const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(telemetryReads, afterOpen + 1);

      // Collapsed again: the timer stops.
      await expandSection(tester, memoryHeader);
      final afterClose = telemetryReads;
      await tester.pump(const Duration(seconds: 12));
      expect(telemetryReads, afterClose);

      // Open, then leave the screen: the timer is cancelled with it.
      await expandSection(tester, memoryHeader);
      await unmountScreen(tester);
      final afterLeave = telemetryReads;
      await tester.pump(const Duration(seconds: 12));
      expect(telemetryReads, afterLeave);
    });
  });

  group('Permissions', () {
    testWidgets('starts collapsed and expands to the Microphone and Notifications rows', (tester) async {
      await pumpSettingsScreen(tester, height: 3000);

      expect(find.text('PERMISSIONS'), findsOneWidget);
      expect(find.text('CAPTURE PERMISSIONS'), findsNothing);
      expect(find.byKey(const Key('settings_microphone_row')), findsNothing);
      expect(find.byKey(const Key('settings_notifications_row')), findsNothing);

      await expandSection(tester, permissionsHeader);
      expect(find.byKey(const Key('settings_microphone_row')), findsOneWidget);
      expect(find.byKey(const Key('settings_notifications_row')), findsOneWidget);
      expect(find.text('Enabled'), findsNWidgets(2));

      await expandSection(tester, permissionsHeader);
      expect(find.byKey(const Key('settings_microphone_row')), findsNothing);
      await unmountScreen(tester);
    });

    testWidgets('no badge while both are granted', (tester) async {
      await pumpSettingsScreen(tester, height: 3000);
      expect(find.text('Needs attention'), findsNothing);
    });

    testWidgets('a missing microphone shows an amber Needs attention badge on the collapsed header',
        (tester) async {
      await pumpSettingsScreen(
        tester,
        permissions: FakePermissionGateway(microphone: PermissionStatus.denied),
        height: 3000,
      );

      expect(find.byKey(const Key('settings_microphone_row')), findsNothing, reason: 'still collapsed');
      final badge = find.byKey(const Key('settings_permissions_attention_badge'));
      expect(find.descendant(of: find.byKey(const Key(permissionsHeader)), matching: badge), findsOneWidget);
      expect(find.text('Needs attention'), findsOneWidget);
      final decoration = tester.widget<Container>(badge).decoration! as BoxDecoration;
      expect(decoration.color, Colors.amber.shade300);
    });

    testWidgets('a missing notification permission shows the badge too, and it goes once granted', (tester) async {
      await pumpSettingsScreen(
        tester,
        permissions: FakePermissionGateway(notification: PermissionStatus.denied),
        height: 3600,
      );
      expect(find.text('Needs attention'), findsOneWidget);

      await expandSection(tester, permissionsHeader);
      await tester.tap(find.byKey(const Key('settings_notifications_row')));
      await tester.pumpAndSettle();

      expect(find.text('Needs attention'), findsNothing);
      await unmountScreen(tester);
    });
  });
}
