import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:eudemonia/features/capture/native_capture_channel.dart';
import 'package:eudemonia/features/settings/background_permission_service.dart';
import 'package:eudemonia/features/settings/settings_screen.dart';
import 'package:eudemonia/features/synthesis/application/folder_settings.dart';

import '../capture/capture_test_doubles.dart';
import 'fake_permission_gateway.dart';
import 'settings_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.eudemonia/hardware_buttons');

  group('Settings capture-readiness rows', () {
    late List<MethodCall> methodCalls;
    late FakePermissionGateway permissions;
    late FakeNativeCaptureChannel capture;
    bool mockForegroundRunning = false;

    setUp(() {
      methodCalls = [];
      mockForegroundRunning = false;
      permissions = FakePermissionGateway(
        microphone: PermissionStatus.denied,
        notification: PermissionStatus.denied,
      );
      capture = FakeNativeCaptureChannel();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        methodCalls.add(call);
        switch (call.method) {
          case 'isForegroundServiceRunning':
            return mockForegroundRunning;
          default:
            return null;
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    Future<void> pumpSettings(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            runtimePermissionGatewayProvider.overrideWithValue(permissions),
            nativeCaptureChannelProvider.overrideWithValue(capture),
            folderStoreProvider.overrideWithValue(InMemoryFolderStore()),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// Permissions start collapsed; open them.
    Future<void> openPermissions(WidgetTester tester) => expandSection(tester, 'settings_permissions_header');

    Finder badgeIn(String rowKey) => find.descendant(
          of: find.byKey(Key(rowKey)),
          matching: find.byType(Chip),
        );

    testWidgets('shows Microphone and Notifications rows with Disabled badges, and no accessibility, volume or battery wording',
        (tester) async {
      await pumpSettings(tester);
      await openPermissions(tester);

      expect(find.text('Microphone'), findsOneWidget);
      expect(find.text('Notifications (lock-screen Record button)'), findsOneWidget);
      expect(find.text('PERMISSIONS'), findsOneWidget);
      expect(find.text('CAPTURE PERMISSIONS'), findsNothing);
      expect(find.textContaining('Battery'), findsNothing);
      expect(find.descendant(of: badgeIn('settings_microphone_row'), matching: find.text('Disabled')),
          findsOneWidget);
      expect(find.descendant(of: badgeIn('settings_notifications_row'), matching: find.text('Disabled')),
          findsOneWidget);
      expect(find.textContaining('Accessibility'), findsNothing);
      expect(find.textContaining('volume', findRichText: true), findsNothing);
      expect(find.textContaining('Grant Both'), findsNothing);
      expect(find.text('Active'), findsNothing);
      expect(find.text('Granted'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows Enabled badges once everything is granted', (tester) async {
      permissions = FakePermissionGateway();
      mockForegroundRunning = true;

      await pumpSettings(tester);
      await openPermissions(tester);

      expect(find.text('Enabled'), findsNWidgets(2));
      expect(find.text('Disabled'), findsNothing);
    });

    testWidgets('tapping the Microphone and Notifications rows requests the permissions', (tester) async {
      await pumpSettings(tester);
      await openPermissions(tester);

      await tester.ensureVisible(find.byKey(const Key('settings_microphone_row')));
      await tester.tap(find.byKey(const Key('settings_microphone_row')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('settings_notifications_row')));
      await tester.tap(find.byKey(const Key('settings_notifications_row')));
      await tester.pumpAndSettle();

      expect(permissions.requested, [Permission.microphone, Permission.notification]);
      expect(find.text('Enabled'), findsWidgets);
    });

    testWidgets('Add capture widget asks the launcher to pin it and stays quiet on success', (tester) async {
      await pumpSettings(tester);
      final row = find.byKey(const Key('settings_add_widget_row'));
      await tester.scrollUntilVisible(row, 100, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();

      expect(find.text('Add capture widget to home screen'), findsOneWidget);
      await tester.tap(row);
      await tester.pump();

      expect(capture.pinCalls, 1);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('when the launcher cannot pin, a SnackBar explains how to add the widget by hand',
        (tester) async {
      capture.pinSucceeds = false;
      await pumpSettings(tester);
      final row = find.byKey(const Key('settings_add_widget_row'));
      await tester.scrollUntilVisible(row, 100, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();

      await tester.tap(row);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Long-press your home screen, choose Widgets, then Eudemonia.'), findsOneWidget);
    });

    testWidgets('Add Record tile asks the system to offer the Quick Settings tile and stays quiet on success',
        (tester) async {
      await pumpSettings(tester);
      final row = find.byKey(const Key('settings_add_tile_row'));
      await tester.scrollUntilVisible(row, 100, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();

      expect(find.text('Add Record tile to Quick Settings'), findsOneWidget);
      await tester.tap(row);
      await tester.pump();

      expect(capture.tileCalls, 1);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('when the system cannot offer the tile, a SnackBar explains how to add it by hand', (tester) async {
      capture.tileOffered = false;
      await pumpSettings(tester);
      final row = find.byKey(const Key('settings_add_tile_row'));
      await tester.scrollUntilVisible(row, 100, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();

      await tester.tap(row);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('drag "Record thought" into your tiles'), findsOneWidget);
    });
  });
}
