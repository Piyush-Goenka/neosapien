/// Result of a permission request.
///
/// `granted` covers iOS limited (photos) as an accepted outcome because the
/// scoped access is enough for the flows we support (add-only saves).
enum PermissionOutcome {
  granted,
  denied,
  permanentlyDenied,
  restricted,
}

/// Abstract seam over the platform permission system so features can be
/// tested without pulling in the platform channel.
abstract class PermissionGateway {
  Future<PermissionOutcome> ensureNotifications();
  Future<PermissionOutcome> ensurePhotosAddOnly();
  Future<bool> openSettings();
}
