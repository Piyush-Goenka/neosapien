import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class ReceivedTransferFileStore {
  ReceivedTransferFileStore({
    Future<Directory> Function()? rootDirectoryResolver,
  }) : _rootDirectoryResolver =
           rootDirectoryResolver ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _rootDirectoryResolver;

  Future<File> createTargetFile({
    required String batchId,
    required String fileName,
  }) async {
    final batchDirectory = await _ensureBatchDirectory(batchId);
    final sanitizedName = _sanitizeFileName(fileName);
    final extension = path.extension(sanitizedName);
    final baseName = extension.isEmpty
        ? sanitizedName
        : sanitizedName.substring(0, sanitizedName.length - extension.length);

    var candidateName = sanitizedName;
    var sequence = 2;
    while (await File(path.join(batchDirectory.path, candidateName)).exists()) {
      candidateName = '$baseName ($sequence)$extension';
      sequence += 1;
    }

    return File(path.join(batchDirectory.path, candidateName));
  }

  Future<void> deleteIfExists(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<bool> exists(String filePath) {
    return File(filePath).exists();
  }

  Future<Directory> _ensureBatchDirectory(String batchId) async {
    final rootDirectory = await _rootDirectoryResolver();
    final directory = Directory(
      path.join(rootDirectory.path, 'neo_sapien_received', batchId),
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  String _sanitizeFileName(String fileName) {
    final trimmed = fileName.trim();
    if (trimmed.isEmpty) {
      return 'file';
    }

    final replacedSeparators = trimmed.replaceAll(RegExp(r'[\\/]'), '_');
    return replacedSeparators.isEmpty ? 'file' : replacedSeparators;
  }
}
