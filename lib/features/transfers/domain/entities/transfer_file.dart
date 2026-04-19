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
  });

  final String id;
  final String name;
  final int byteCount;
  final String mimeType;
  final String? checksumSha256;
  final int transferredBytes;
  final TransferFileStatus status;
  final TransferFailure? failure;

  double get progress {
    if (byteCount == 0) {
      return 1;
    }
    return transferredBytes / byteCount;
  }
}
