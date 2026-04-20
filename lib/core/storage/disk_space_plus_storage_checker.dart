import 'package:disk_space_plus/disk_space_plus.dart';
import 'package:neo_sapien/core/storage/device_storage_checker.dart';

/// Production [DeviceStorageChecker] backed by `disk_space_plus`.
/// The plugin reports free space in MB; we convert to bytes.
class DiskSpacePlusStorageChecker implements DeviceStorageChecker {
  DiskSpacePlusStorageChecker([DiskSpacePlus? plugin])
      : _plugin = plugin ?? DiskSpacePlus();

  final DiskSpacePlus _plugin;

  @override
  Future<int?> freeBytes() async {
    try {
      final freeMb = await _plugin.getFreeDiskSpace;
      if (freeMb == null) {
        return null;
      }
      return (freeMb * 1024 * 1024).toInt();
    } on Object {
      return null;
    }
  }
}
