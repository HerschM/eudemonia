import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/settings/background_permission_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackgroundPermissionStatus', () {
    test('areAllGranted returns true only when both are true', () {
      const allTrue = BackgroundPermissionStatus(
        isAccessibilityEnabled: true,
        isBatteryOptimizationIgnored: true,
      );
      expect(allTrue.areAllGranted, isTrue);

      const onlyAccess = BackgroundPermissionStatus(
        isAccessibilityEnabled: true,
        isBatteryOptimizationIgnored: false,
      );
      expect(onlyAccess.areAllGranted, isFalse);

      const onlyBattery = BackgroundPermissionStatus(
        isAccessibilityEnabled: false,
        isBatteryOptimizationIgnored: true,
      );
      expect(onlyBattery.areAllGranted, isFalse);

      const allFalse = BackgroundPermissionStatus(
        isAccessibilityEnabled: false,
        isBatteryOptimizationIgnored: false,
      );
      expect(allFalse.areAllGranted, isFalse);
    });

    test('copyWith updates fields correctly', () {
      const initial = BackgroundPermissionStatus(
        isAccessibilityEnabled: false,
        isBatteryOptimizationIgnored: false,
      );
      final updated = initial.copyWith(isBatteryOptimizationIgnored: true);
      expect(updated.isAccessibilityEnabled, isFalse);
      expect(updated.isBatteryOptimizationIgnored, isTrue);
    });
  });

  group('BackgroundPermissionService', () {
    const channel = MethodChannel('test_hardware_buttons');
    late BackgroundPermissionService service;
    late List<MethodCall> methodCalls;

    setUp(() {
      methodCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        methodCalls.add(call);
        switch (call.method) {
          case 'isAccessibilityServiceEnabled':
            return true;
          case 'isIgnoringBatteryOptimizations':
            return true;
          case 'requestIgnoreBatteryOptimizations':
          case 'openAccessibilitySettings':
          case 'requestSimultaneousPermissions':
            return null;
          default:
            return null;
        }
      });

      service = const BackgroundPermissionService(channel: channel);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('checkStatus returns correct status when both are true', () async {
      final status = await service.checkStatus();
      expect(status.isAccessibilityEnabled, isTrue);
      expect(status.isBatteryOptimizationIgnored, isTrue);
      expect(status.areAllGranted, isTrue);

      expect(
        methodCalls.map((m) => m.method),
        containsAll(['isAccessibilityServiceEnabled', 'isIgnoringBatteryOptimizations']),
      );
    });

    test('checkStatus handles exceptions gracefully and returns false', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'ERROR', message: 'Failed');
      });

      final status = await service.checkStatus();
      expect(status.isAccessibilityEnabled, isFalse);
      expect(status.isBatteryOptimizationIgnored, isFalse);
      expect(status.areAllGranted, isFalse);
    });

    test('requestSimultaneousPermissions invokes native method', () async {
      await service.requestSimultaneousPermissions();
      expect(methodCalls.any((m) => m.method == 'requestSimultaneousPermissions'), isTrue);
    });

    test('requestBatteryOptimizationExemption invokes native method', () async {
      await service.requestBatteryOptimizationExemption();
      expect(methodCalls.any((m) => m.method == 'requestIgnoreBatteryOptimizations'), isTrue);
    });

    test('openAccessibilitySettings invokes native method', () async {
      await service.openAccessibilitySettings();
      expect(methodCalls.any((m) => m.method == 'openAccessibilitySettings'), isTrue);
    });
  });
}
