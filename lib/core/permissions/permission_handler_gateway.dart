import 'dart:io';

import 'package:neo_sapien/core/permissions/permission_gateway.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Production [PermissionGateway] backed by `permission_handler`.
class PermissionHandlerGateway implements PermissionGateway {
  const PermissionHandlerGateway();

  @override
  Future<PermissionOutcome> ensureNotifications() async {
    final status = await ph.Permission.notification.request();
    return _map(status);
  }

  @override
  Future<PermissionOutcome> ensurePhotosAddOnly() async {
    // Android has no equivalent of iOS photos add-only at the Permissions API
    // surface; writes go through MediaStore scoped storage.
    if (!Platform.isIOS) {
      return PermissionOutcome.granted;
    }
    final status = await ph.Permission.photosAddOnly.request();
    return _map(status);
  }

  @override
  Future<bool> openSettings() {
    return ph.openAppSettings();
  }

  PermissionOutcome _map(ph.PermissionStatus status) {
    if (status.isGranted || status.isLimited || status.isProvisional) {
      return PermissionOutcome.granted;
    }
    if (status.isPermanentlyDenied) {
      return PermissionOutcome.permanentlyDenied;
    }
    if (status.isRestricted) {
      return PermissionOutcome.restricted;
    }
    return PermissionOutcome.denied;
  }
}
