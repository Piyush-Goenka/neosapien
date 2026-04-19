import 'package:flutter/foundation.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_failure.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_file_status.dart';

@immutable
class TransferFile {
  const TransferFile({
    required this.id,
    required this.name,
    required this.byteCount,
    required this.status,
    this.mimeType = 'application/octet-stream',
    this.checksumSha256,
    this.transferredBytes = 0,
    this.failure,
    this.localPath,
    this.sourceIdentifier,
  });

  final String id;
  final String name;
  final int byteCount;
  final String mimeType;
  final String? checksumSha256;
  final int transferredBytes;
  final TransferFileStatus status;
  final TransferFailure? failure;
  final String? localPath;
  final String? sourceIdentifier;

  double get progress {
    if (byteCount == 0) {
      return 1;
    }
    return transferredBytes / byteCount;
  }

  bool get canReadSource {
    return (localPath != null && localPath!.isNotEmpty) ||
        (sourceIdentifier != null && sourceIdentifier!.isNotEmpty);
  }

  String get sourceKey {
    return sourceIdentifier ?? localPath ?? '$name:$byteCount';
  }

  TransferFile copyWith({
    String? id,
    String? name,
    int? byteCount,
    String? mimeType,
    Object? checksumSha256 = _transferFileSentinel,
    int? transferredBytes,
    TransferFileStatus? status,
    Object? failure = _transferFileSentinel,
    Object? localPath = _transferFileSentinel,
    Object? sourceIdentifier = _transferFileSentinel,
  }) {
    return TransferFile(
      id: id ?? this.id,
      name: name ?? this.name,
      byteCount: byteCount ?? this.byteCount,
      mimeType: mimeType ?? this.mimeType,
      checksumSha256: checksumSha256 == _transferFileSentinel
          ? this.checksumSha256
          : checksumSha256 as String?,
      transferredBytes: transferredBytes ?? this.transferredBytes,
      status: status ?? this.status,
      failure: failure == _transferFileSentinel
          ? this.failure
          : failure as TransferFailure?,
      localPath: localPath == _transferFileSentinel
          ? this.localPath
          : localPath as String?,
      sourceIdentifier: sourceIdentifier == _transferFileSentinel
          ? this.sourceIdentifier
          : sourceIdentifier as String?,
    );
  }
}

const Object _transferFileSentinel = Object();
