import 'package:flutter/foundation.dart';
import 'package:neo_sapien/features/recipients/domain/value_objects/recipient_code.dart';
import 'package:neo_sapien/features/transfers/domain/entities/network_policy.dart';
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
    required this.networkPolicy,
    this.senderCode,
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
  final NetworkPolicy networkPolicy;
  final RecipientCode? senderCode;
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

  TransferBatch copyWith({
    String? id,
    TransferDirection? direction,
    TransferStatus? status,
    List<TransferFile>? files,
    DateTime? createdAt,
    NetworkPolicy? networkPolicy,
    Object? senderCode = _transferBatchSentinel,
    Object? recipientCode = _transferBatchSentinel,
    Object? failure = _transferBatchSentinel,
    int? bytesTransferred,
    int? totalBytes,
  }) {
    return TransferBatch(
      id: id ?? this.id,
      direction: direction ?? this.direction,
      status: status ?? this.status,
      files: files ?? this.files,
      createdAt: createdAt ?? this.createdAt,
      networkPolicy: networkPolicy ?? this.networkPolicy,
      senderCode: senderCode == _transferBatchSentinel
          ? this.senderCode
          : senderCode as RecipientCode?,
      recipientCode: recipientCode == _transferBatchSentinel
          ? this.recipientCode
          : recipientCode as RecipientCode?,
      failure: failure == _transferBatchSentinel
          ? this.failure
          : failure as TransferFailure?,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      totalBytes: totalBytes ?? this.totalBytes,
    );
  }
}

const Object _transferBatchSentinel = Object();
