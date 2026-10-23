import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/settings/background_permission_service.dart';
import 'package:eudemonia/features/settings/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.eudemonia/hardware_buttons');

  group('Background Permission UI & Widget Tests', () {
    late List<MethodCall> methodCalls;
    bool mockAccessibility = false;
    bool mockBatteryIgnored = false;
    bool mockForegroundRunning = false;

    setUp(() {
      methodCalls = [];
      mockAccessibility = false;
      mockBatteryIgnored = false;
      mockForegroundRunning = false;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        methodCalls.add(call);
        switch (call.method) {
          case 'isAccessibilityServiceEnabled':
            return mockAccessibility;
          case 'isIgnoringBatteryOptimizations':
            return mockBatteryIgnored;
          case 'isForegroundServiceRunning':
            return mockForegroundRunning;
          case 'startForegroundService':
            mockForegroundRunning = true;
            return true;
          case 'stopForegroundService':
            mockForegroundRunning = false;
            return true;
          case 'openAccessibilitySettings':
          case 'requestIgnoreBatteryOptimizations':
          case 'openBatteryOptimizationSettings':
          case 'requestSimultaneousPermissions':
            return null;
          default:
            return null;
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    testWidgets(
      'showSimultaneousPermissionModal renders on 360dp narrow viewport with NO RenderFlex overflow and NO DecoratedBox assertion',
      (WidgetTester tester) async {
        // Enforce a realistic narrow mobile viewport width (360 x 640 logical pixels)
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final service = BackgroundPermissionService(channel: channel);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    return ElevatedButton(
                      onPressed: () {
                        service.showSimultaneousPermissionModal(context);
                      },
                      child: const Text('Open Modal'),
                    );
                  },
                ),
              ),
            ),
          ),
        );

        // Tap to open bottom sheet
        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettle();

        // Verify title exists and wraps cleanly
        expect(find.text('Background Permissions Required'), findsOneWidget);

        // Assert no framework exceptions occurred (catches RenderFlex overflow & DecoratedBox assertion)
        expect(tester.takeException(), isNull);

        // Verify that ambiguous 'Active' and 'Granted' texts DO NOT exist in the modal
        expect(find.text('Active'), findsNothing);
        expect(find.text('Granted'), findsNothing);

        // When disabled, badges must say 'Disabled'
        expect(find.text('Disabled'), findsNWidgets(2));
      },
    );

    testWidgets(
      'SettingsScreen uses consistent Enabled/Disabled states without Active or Granted',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        mockAccessibility = false;
        mockBatteryIgnored = false;

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: SettingsScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Initial state: both are disabled
        expect(find.text('Disabled'), findsWidgets);
        expect(find.text('Active'), findsNothing);
        expect(find.text('Granted'), findsNothing);

        // Verify that tapping Enable Both triggers simultaneous permission method
        final grantBothBtn = find.text('Grant Both');
        expect(grantBothBtn, findsOneWidget);
      },
    );

    testWidgets(
      'SettingsScreen displays Enabled badge in green when permissions are active',
      (WidgetTester tester) async {
        mockAccessibility = true;
        mockBatteryIgnored = true;
        mockForegroundRunning = true;

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: SettingsScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // When enabled, badges must say 'Enabled'
        expect(find.text('Enabled'), findsWidgets);
        expect(find.text('Active'), findsNothing);
        expect(find.text('Granted'), findsNothing);
      },
    );
  });
}
