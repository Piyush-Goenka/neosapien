/// Platform-abstract check for free bytes available to save downloads.
abstract class DeviceStorageChecker {
  /// Free bytes available to write into the app's documents / cache area.
  /// Returns `null` when the platform does not expose disk info.
  Future<int?> freeBytes();
}
