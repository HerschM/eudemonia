import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:eudemonia/features/settings/background_permission_service.dart';

/// Scripted runtime permissions. `throwOn` simulates a plugin failure for one permission.
class FakePermissionGateway implements RuntimePermissionGateway {
  final Map<Permission, PermissionStatus> statuses;
  final Set<Permission> throwOn = {};
  final List<Permission> requested = [];
  int settingsOpened = 0;

  FakePermissionGateway({
    PermissionStatus microphone = PermissionStatus.granted,
    PermissionStatus notification = PermissionStatus.granted,
  }) : statuses = {
          Permission.microphone: microphone,
          Permission.notification: notification,
        };

  @override
  Future<PermissionStatus> status(Permission permission) async {
    if (throwOn.contains(permission)) throw PlatformException(code: 'ERROR');
    return statuses[permission]!;
  }

  @override
  Future<PermissionStatus> request(Permission permission) async {
    requested.add(permission);
    return statuses[permission] = PermissionStatus.granted;
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }
}
