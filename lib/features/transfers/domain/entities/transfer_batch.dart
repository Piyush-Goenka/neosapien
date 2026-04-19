import 'package:flutter/foundation.dart';
import 'package:neo_sapien/features/recipients/domain/value_objects/recipient_code.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_direction.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_failure.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_file.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_status.dart';

@immutable
class TransferBatch {
  const TransferBatch({
    required this.id,
    required this.direction,
    required this.status,
    required this.files,
    required this.createdAt,
    this.recipientCode,
    this.failure,
    this.bytesTransferred = 0,
    this.totalBytes = 0,
  });

  final String id;
  final TransferDirection direction;
  final TransferStatus status;
  final List<TransferFile> files;
  final DateTime createdAt;
  final RecipientCode? recipientCode;
  final TransferFailure? failure;
  final int bytesTransferred;
  final int totalBytes;

  double get progress {
    if (totalBytes <= 0) {
      return 0;
    }
    return bytesTransferred / totalBytes;
  }
}
