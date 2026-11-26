import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:eudemonia/features/settings/background_permission_service.dart';

import 'fake_permission_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackgroundPermissionStatus', () {
    test('copyWith updates only the named fields', () {
      const initial = BackgroundPermissionStatus(
        isMicrophoneGranted: false,
        areNotificationsEnabled: false,
        isForegroundServiceRunning: false,
      );
      final updated = initial.copyWith(
        isMicrophoneGranted: true,
        isForegroundServiceRunning: true,
      );
      expect(updated.isMicrophoneGranted, isTrue);
      expect(updated.areNotificationsEnabled, isFalse);
      expect(updated.isForegroundServiceRunning, isTrue);
    });

    test('equality covers every field', () {
      const a = BackgroundPermissionStatus(
        isMicrophoneGranted: true,
        areNotificationsEnabled: true,
      );
      expect(a, a.copyWith());
      expect(a.hashCode, a.copyWith().hashCode);
      expect(a, isNot(a.copyWith(areNotificationsEnabled: false)));
    });
  });

  group('BackgroundPermissionService', () {
    const channel = MethodChannel('test_hardware_buttons');
    late BackgroundPermissionService service;
    late FakePermissionGateway permissions;
    late List<MethodCall> methodCalls;

    setUp(() {
      methodCalls = [];
      permissions = FakePermissionGateway();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        methodCalls.add(call);
        switch (call.method) {
          case 'isForegroundServiceRunning':
            return true;
          default:
            return null;
        }
      });
      service = BackgroundPermissionService(channel: channel, permissions: permissions);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('checkStatus reports every prerequisite and never asks native about accessibility', () async {
      final status = await service.checkStatus();

      expect(status.isMicrophoneGranted, isTrue);
      expect(status.areNotificationsEnabled, isTrue);
      expect(status.isForegroundServiceRunning, isTrue);
      expect(methodCalls.map((m) => m.method), ['isForegroundServiceRunning']);
    });

    test('checkStatus reflects denied runtime permissions', () async {
      permissions = FakePermissionGateway(
        microphone: PermissionStatus.denied,
        notification: PermissionStatus.permanentlyDenied,
      );
      service = BackgroundPermissionService(channel: channel, permissions: permissions);

      final status = await service.checkStatus();

      expect(status.isMicrophoneGranted, isFalse);
      expect(status.areNotificationsEnabled, isFalse);
    });

    test('a failing query reports false for that prerequisite only', () async {
      permissions.throwOn.add(Permission.notification);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'isForegroundServiceRunning') {
          throw PlatformException(code: 'ERROR', message: 'Failed');
        }
        return true;
      });

      final status = await service.checkStatus();

      expect(status.isMicrophoneGranted, isTrue);
      expect(status.areNotificationsEnabled, isFalse);
      expect(status.isForegroundServiceRunning, isFalse);
    });

    test('requestMicrophone asks once when denied and does nothing when already granted', () async {
      permissions.statuses[Permission.microphone] = PermissionStatus.denied;
      await service.requestMicrophone();
      expect(permissions.requested, [Permission.microphone]);
      expect(permissions.settingsOpened, 0);

      await service.requestMicrophone();
      expect(permissions.requested, [Permission.microphone]);
    });

    test('a permanently denied permission opens the system settings instead of asking', () async {
      permissions.statuses[Permission.microphone] = PermissionStatus.permanentlyDenied;
      await service.requestMicrophone();
      expect(permissions.requested, isEmpty);
      expect(permissions.settingsOpened, 1);
    });

    test('requestNotifications asks for the notification permission', () async {
      permissions.statuses[Permission.notification] = PermissionStatus.denied;
      await service.requestNotifications();
      expect(permissions.requested, [Permission.notification]);
    });

    test('startForegroundService and stopForegroundService invoke native methods', () async {
      await service.startForegroundService();
      expect(methodCalls.any((m) => m.method == 'startForegroundService'), isTrue);

      await service.stopForegroundService();
      expect(methodCalls.any((m) => m.method == 'stopForegroundService'), isTrue);
    });
  });
}
