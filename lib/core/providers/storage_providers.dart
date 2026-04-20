import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neo_sapien/core/storage/device_storage_checker.dart';
import 'package:neo_sapien/core/storage/disk_space_plus_storage_checker.dart';

final deviceStorageCheckerProvider = Provider<DeviceStorageChecker>((ref) {
  return DiskSpacePlusStorageChecker();
});
