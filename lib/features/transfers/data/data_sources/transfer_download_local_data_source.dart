import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:neo_sapien/core/errors/app_exception.dart';

class TransferDownloadLocalDataSource {
  TransferDownloadLocalDataSource(this._secureStorage);

  static const String _storageKey = 'transfer.downloads.v1';

  final FlutterSecureStorage _secureStorage;

  Future<Map<String, LocalDownloadedTransferBatch>> readAllBatches() async {
    try {
      final encoded = await _secureStorage.read(key: _storageKey);
      if (encoded == null || encoded.isEmpty) {
        return const <String, LocalDownloadedTransferBatch>{};
      }

      final json = jsonDecode(encoded);
      if (json is! Map<Object?, Object?>) {
        await clear();
        return const <String, LocalDownloadedTransferBatch>{};
      }

      final result = <String, LocalDownloadedTransferBatch>{};
      for (final entry in json.entries) {
        final batchId = entry.key?.toString();
        if (batchId == null || batchId.isEmpty) {
          continue;
        }

        final batchJson = _toMap(entry.value);
        if (batchJson == null) {
          continue;
        }

        final batch = LocalDownloadedTransferBatch.fromJson(
          batchId: batchId,
          json: batchJson,
        );
        result[batchId] = batch;
      }

      return result;
    } on FormatException {
      await clear();
      return const <String, LocalDownloadedTransferBatch>{};
    } on Object catch (error) {
      throw TransferRepositoryException(
        'Failed to read locally saved transfer history.',
        cause: error,
      );
    }
  }

  Future<LocalDownloadedTransferBatch?> readBatch(String batchId) async {
    final batches = await readAllBatches();
    return batches[batchId];
  }

  Future<void> upsertDownloadedFile({
    required String batchId,
    required String fileId,
    required String localPath,
    required DateTime savedAt,
  }) async {
    final batches = await readAllBatches();
    final existingBatch =
        batches[batchId] ??
        LocalDownloadedTransferBatch(
          batchId: batchId,
          savedAt: savedAt,
          files: const <LocalDownloadedTransferFile>[],
        );

    final files = <LocalDownloadedTransferFile>[
      for (final file in existingBatch.files)
        if (file.fileId != fileId) file,
      LocalDownloadedTransferFile(
        fileId: fileId,
        localPath: localPath,
        savedAt: savedAt,
      ),
    ]..sort((left, right) => left.fileId.compareTo(right.fileId));

    batches[batchId] = existingBatch.copyWith(savedAt: savedAt, files: files);
    await _writeAllBatches(batches);
  }

  Future<void> clear() async {
    try {
      await _secureStorage.delete(key: _storageKey);
    } on Object catch (error) {
      throw TransferRepositoryException(
        'Failed to clear locally saved transfer history.',
        cause: error,
      );
    }
  }

  Future<void> _writeAllBatches(
    Map<String, LocalDownloadedTransferBatch> batches,
  ) async {
    try {
      final payload = <String, Object?>{
        for (final entry in batches.entries) entry.key: entry.value.toJson(),
      };
      await _secureStorage.write(key: _storageKey, value: jsonEncode(payload));
    } on Object catch (error) {
      throw TransferRepositoryException(
        'Failed to persist locally saved transfer history.',
        cause: error,
      );
    }
  }

  Map<String, Object?>? _toMap(Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
    }
    return null;
  }
}

@immutable
class LocalDownloadedTransferBatch {
  const LocalDownloadedTransferBatch({
    required this.batchId,
    required this.savedAt,
    required this.files,
  });

  factory LocalDownloadedTransferBatch.fromJson({
    required String batchId,
    required Map<String, Object?> json,
  }) {
    final rawFiles = json['files'];
    final files = rawFiles is List<Object?>
        ? rawFiles
              .map(_mapToDownloadedFile)
              .whereType<LocalDownloadedTransferFile>()
              .toList(growable: false)
        : const <LocalDownloadedTransferFile>[];

    return LocalDownloadedTransferBatch(
      batchId: batchId,
      savedAt:
          _dateTimeFromString(json['savedAt'] as String?) ?? DateTime.now(),
      files: files,
    );
  }

  final String batchId;
  final DateTime savedAt;
  final List<LocalDownloadedTransferFile> files;

  LocalDownloadedTransferBatch copyWith({
    String? batchId,
    DateTime? savedAt,
    List<LocalDownloadedTransferFile>? files,
  }) {
    return LocalDownloadedTransferBatch(
      batchId: batchId ?? this.batchId,
      savedAt: savedAt ?? this.savedAt,
      files: files ?? this.files,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'savedAt': savedAt.toUtc().toIso8601String(),
      'files': files.map((file) => file.toJson()).toList(growable: false),
    };
  }
}

@immutable
class LocalDownloadedTransferFile {
  const LocalDownloadedTransferFile({
    required this.fileId,
    required this.localPath,
    required this.savedAt,
  });

  final String fileId;
  final String localPath;
  final DateTime savedAt;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'fileId': fileId,
      'localPath': localPath,
      'savedAt': savedAt.toUtc().toIso8601String(),
    };
  }
}

LocalDownloadedTransferFile? _mapToDownloadedFile(Object? value) {
  if (value is! Map) {
    return null;
  }

  final json = value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
  final fileId = json['fileId'] as String?;
  final localPath = json['localPath'] as String?;
  final savedAt = _dateTimeFromString(json['savedAt'] as String?);
  if (fileId == null ||
      fileId.isEmpty ||
      localPath == null ||
      localPath.isEmpty) {
    return null;
  }

  return LocalDownloadedTransferFile(
    fileId: fileId,
    localPath: localPath,
    savedAt: savedAt ?? DateTime.now(),
  );
}

DateTime? _dateTimeFromString(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }

  return DateTime.tryParse(value)?.toUtc();
}
