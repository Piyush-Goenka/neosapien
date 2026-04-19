import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:neo_sapien/core/errors/app_exception.dart';
import 'package:neo_sapien/features/recipients/domain/entities/recipient.dart';
import 'package:neo_sapien/features/recipients/domain/value_objects/recipient_code.dart';
import 'package:neo_sapien/features/transfers/domain/entities/network_policy.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_batch.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_direction.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_failure.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_failure_code.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_file.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_file_status.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_status.dart';

class FirestoreTransferRemoteDataSource {
  FirestoreTransferRemoteDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _transfersCollection {
    return _firestore.collection('transfers');
  }

  Future<String> createTransferDraft({
    required String senderUid,
    required RecipientCode senderCode,
    required Recipient recipient,
    required List<TransferFile> files,
    required NetworkPolicy networkPolicy,
    required Duration transferTtl,
  }) async {
    final recipientUid = recipient.userId;
    if (recipientUid == null || recipientUid.isEmpty) {
      throw const TransferRepositoryException(
        'Recipient lookup did not provide a stable user ID.',
      );
    }

    final createdAt = DateTime.now().toUtc();
    final batchId = _transfersCollection.doc().id;
    final totalBytes = files.fold<int>(
      0,
      (total, file) => total + file.byteCount,
    );

    try {
      await _transfersCollection.doc(batchId).set(<String, Object?>{
        'id': batchId,
        'senderUid': senderUid,
        'senderCode': senderCode.normalizedValue,
        'recipientUid': recipientUid,
        'recipientCode': recipient.code.normalizedValue,
        'status': TransferStatus.awaitingAcceptance.name,
        'networkPolicy': networkPolicy.name,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(createdAt),
        'expiresAt': Timestamp.fromDate(createdAt.add(transferTtl)),
        'bytesTransferred': 0,
        'totalBytes': totalBytes,
        'files': _serializeFiles(files),
      });
      return batchId;
    } on FirebaseException catch (error) {
      throw TransferRepositoryException(
        'Failed to create the remote transfer draft: '
        '${error.message ?? error.code}.',
        cause: error,
      );
    }
  }

  Stream<List<TransferBatch>> watchUserTransfers({
    required String currentUserUid,
  }) {
    return Stream<List<TransferBatch>>.multi((controller) {
      final outgoingBatches = <String, TransferBatch>{};
      final incomingBatches = <String, TransferBatch>{};

      void emit() {
        final merged = <String, TransferBatch>{
          ...incomingBatches,
          ...outgoingBatches,
        };
        final values = merged.values.toList(growable: false)
          ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
        controller.add(values);
      }

      StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? outgoingSub;
      StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? incomingSub;

      outgoingSub = _transfersCollection
          .where('senderUid', isEqualTo: currentUserUid)
          .snapshots()
          .listen((snapshot) {
            outgoingBatches
              ..clear()
              ..addEntries(
                snapshot.docs.map(
                  (doc) => MapEntry(
                    doc.id,
                    _batchFromSnapshot(
                      doc: doc,
                      currentUserUid: currentUserUid,
                    ),
                  ),
                ),
              );
            emit();
          }, onError: controller.addError);

      incomingSub = _transfersCollection
          .where('recipientUid', isEqualTo: currentUserUid)
          .snapshots()
          .listen((snapshot) {
            incomingBatches
              ..clear()
              ..addEntries(
                snapshot.docs.map(
                  (doc) => MapEntry(
                    doc.id,
                    _batchFromSnapshot(
                      doc: doc,
                      currentUserUid: currentUserUid,
                    ),
                  ),
                ),
              );
            emit();
          }, onError: controller.addError);

      controller.onCancel = () async {
        await outgoingSub?.cancel();
        await incomingSub?.cancel();
      };
    });
  }

  Future<TransferBatch?> fetchTransferBatch({
    required String batchId,
    required String currentUserUid,
  }) async {
    try {
      final snapshot = await _transfersCollection.doc(batchId).get();
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        return null;
      }

      final senderUid = data['senderUid'] as String?;
      final recipientUid = data['recipientUid'] as String?;
      if (senderUid != currentUserUid && recipientUid != currentUserUid) {
        throw const TransferRepositoryException(
          'This transfer cannot be read from the current device.',
        );
      }

      return _batchFromSnapshot(doc: snapshot, currentUserUid: currentUserUid);
    } on TransferRepositoryException {
      rethrow;
    } on FirebaseException catch (error) {
      throw TransferRepositoryException(
        'Failed to load the transfer batch: ${error.message ?? error.code}.',
        cause: error,
      );
    }
  }

  Future<void> updateOutgoingTransferBatch({
    required String batchId,
    required String currentUserUid,
    required TransferStatus status,
    required List<TransferFile> files,
    required int bytesTransferred,
    TransferFailure? failure,
  }) async {
    try {
      await _transfersCollection.doc(batchId).update(<String, Object?>{
        'status': status.name,
        'updatedAt': Timestamp.fromDate(DateTime.now().toUtc()),
        'bytesTransferred': bytesTransferred,
        'totalBytes': files.fold<int>(
          0,
          (total, file) => total + file.byteCount,
        ),
        'files': _serializeFiles(files),
        'failure': _serializeFailure(failure),
        'lastUpdatedBy': currentUserUid,
      });
    } on FirebaseException catch (error) {
      throw TransferRepositoryException(
        'Failed to persist the transfer progress: '
        '${error.message ?? error.code}.',
        cause: error,
      );
    }
  }

  Future<void> cancelBatch({
    required String batchId,
    required String currentUserUid,
  }) {
    return _updateTransferStatus(
      batchId: batchId,
      currentUserUid: currentUserUid,
      expectedRoleField: 'senderUid',
      status: TransferStatus.cancelled,
    );
  }

  Future<void> acceptBatch({
    required String batchId,
    required String currentUserUid,
  }) {
    return _updateTransferStatus(
      batchId: batchId,
      currentUserUid: currentUserUid,
      expectedRoleField: 'recipientUid',
      status: TransferStatus.queued,
    );
  }

  Future<void> rejectBatch({
    required String batchId,
    required String currentUserUid,
  }) {
    return _updateTransferStatus(
      batchId: batchId,
      currentUserUid: currentUserUid,
      expectedRoleField: 'recipientUid',
      status: TransferStatus.rejected,
    );
  }

  Future<void> _updateTransferStatus({
    required String batchId,
    required String currentUserUid,
    required String expectedRoleField,
    required TransferStatus status,
  }) async {
    final document = _transfersCollection.doc(batchId);

    try {
      await _firestore.runTransaction<void>((transaction) async {
        final snapshot = await transaction.get(document);
        final data = snapshot.data();
        if (!snapshot.exists || data == null) {
          throw const TransferRepositoryException('Transfer batch not found.');
        }

        final ownerUid = data[expectedRoleField];
        if (ownerUid is! String || ownerUid != currentUserUid) {
          throw const TransferRepositoryException(
            'This transfer cannot be updated from the current device.',
          );
        }

        transaction.update(document, <String, Object?>{
          'status': status.name,
          'updatedAt': Timestamp.fromDate(DateTime.now().toUtc()),
        });
      });
    } on TransferRepositoryException {
      rethrow;
    } on FirebaseException catch (error) {
      throw TransferRepositoryException(
        'Failed to update the transfer status: '
        '${error.message ?? error.code}.',
        cause: error,
      );
    }
  }

  TransferBatch _batchFromSnapshot({
    required DocumentSnapshot<Map<String, dynamic>> doc,
    required String currentUserUid,
  }) {
    final data = doc.data() ?? <String, dynamic>{};
    final senderUid = data['senderUid'] as String?;
    final createdAt = _timestampToUtc(data['createdAt']);
    final status = _statusFromName(data['status'] as String?);
    final files = _filesFromData(data['files'], status);
    final totalBytes =
        (data['totalBytes'] as num?)?.toInt() ??
        files.fold<int>(0, (total, file) => total + file.byteCount);
    final bytesTransferred =
        (data['bytesTransferred'] as num?)?.toInt() ??
        files.fold<int>(0, (total, file) => total + file.transferredBytes);

    return TransferBatch(
      id: doc.id,
      direction: senderUid == currentUserUid
          ? TransferDirection.outgoing
          : TransferDirection.incoming,
      status: status,
      files: files,
      createdAt: createdAt,
      networkPolicy: _networkPolicyFromName(data['networkPolicy'] as String?),
      senderCode: _recipientCodeFromString(data['senderCode'] as String?),
      recipientCode: _recipientCodeFromString(data['recipientCode'] as String?),
      failure: _failureFromData(data['failure']),
      bytesTransferred: bytesTransferred,
      totalBytes: totalBytes,
    );
  }

  List<Map<String, Object?>> _serializeFiles(List<TransferFile> files) {
    return files
        .map(
          (file) => <String, Object?>{
            'id': file.id,
            'name': file.name,
            'byteCount': file.byteCount,
            'mimeType': file.mimeType,
            'transferredBytes': file.transferredBytes,
            'status': file.status.name,
            'checksumSha256': file.checksumSha256,
            'storagePath': file.storagePath,
            'downloadUrl': file.downloadUrl,
            'failure': _serializeFailure(file.failure),
          },
        )
        .toList(growable: false);
  }

  List<TransferFile> _filesFromData(
    Object? rawFiles,
    TransferStatus batchStatus,
  ) {
    if (rawFiles is! List<Object?>) {
      return const <TransferFile>[];
    }

    return rawFiles
        .asMap()
        .entries
        .map((entry) => MapEntry(entry.key, _toMap(entry.value)))
        .where((entry) => entry.value != null)
        .map(
          (entry) => TransferFile(
            id: entry.value!['id'] as String? ?? 'file-${entry.key}',
            name: entry.value!['name'] as String? ?? 'unnamed-file',
            byteCount: (entry.value!['byteCount'] as num?)?.toInt() ?? 0,
            mimeType:
                entry.value!['mimeType'] as String? ??
                'application/octet-stream',
            checksumSha256: entry.value!['checksumSha256'] as String?,
            transferredBytes:
                (entry.value!['transferredBytes'] as num?)?.toInt() ?? 0,
            status: _fileStatusFromName(
              entry.value!['status'] as String?,
              fallbackStatus: batchStatus,
            ),
            failure: _failureFromData(entry.value!['failure']),
            storagePath: entry.value!['storagePath'] as String?,
            downloadUrl: entry.value!['downloadUrl'] as String?,
          ),
        )
        .toList(growable: false);
  }

  Map<String, dynamic>? _toMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
    }
    return null;
  }

  Map<String, Object?>? _serializeFailure(TransferFailure? failure) {
    if (failure == null) {
      return null;
    }

    return <String, Object?>{
      'code': failure.code.name,
      'message': failure.message,
      'isRecoverable': failure.isRecoverable,
    };
  }

  TransferFailure? _failureFromData(Object? rawFailure) {
    final data = _toMap(rawFailure);
    if (data == null) {
      return null;
    }

    final message = data['message'] as String?;
    if (message == null || message.isEmpty) {
      return null;
    }

    return TransferFailure(
      code: _failureCodeFromName(data['code'] as String?),
      message: message,
      isRecoverable: data['isRecoverable'] as bool? ?? false,
    );
  }

  RecipientCode? _recipientCodeFromString(String? value) {
    if (value == null || !RecipientCodeCodec.isValid(value)) {
      return null;
    }
    return RecipientCode.fromRaw(value);
  }

  DateTime _timestampToUtc(Object? value) {
    if (value is Timestamp) {
      return value.toDate().toUtc();
    }
    return DateTime.now().toUtc();
  }

  TransferStatus _statusFromName(String? value) {
    return switch (value) {
      'draft' => TransferStatus.draft,
      'validating' => TransferStatus.validating,
      'queued' => TransferStatus.queued,
      'uploading' => TransferStatus.uploading,
      'pendingRecipient' => TransferStatus.pendingRecipient,
      'awaitingAcceptance' => TransferStatus.awaitingAcceptance,
      'downloading' => TransferStatus.downloading,
      'completed' => TransferStatus.completed,
      'failed' => TransferStatus.failed,
      'cancelled' => TransferStatus.cancelled,
      'expired' => TransferStatus.expired,
      'rejected' => TransferStatus.rejected,
      'corrupted' => TransferStatus.corrupted,
      _ => TransferStatus.failed,
    };
  }

  TransferFileStatus _fileStatusFromName(
    String? value, {
    required TransferStatus fallbackStatus,
  }) {
    if (value != null) {
      return switch (value) {
        'pending' => TransferFileStatus.pending,
        'inProgress' => TransferFileStatus.inProgress,
        'completed' => TransferFileStatus.completed,
        'failed' => TransferFileStatus.failed,
        'cancelled' => TransferFileStatus.cancelled,
        _ => _fileStatusFromBatchStatus(fallbackStatus),
      };
    }

    return _fileStatusFromBatchStatus(fallbackStatus);
  }

  TransferFileStatus _fileStatusFromBatchStatus(TransferStatus batchStatus) {
    return switch (batchStatus) {
      TransferStatus.completed ||
      TransferStatus.pendingRecipient => TransferFileStatus.completed,
      TransferStatus.uploading ||
      TransferStatus.downloading => TransferFileStatus.inProgress,
      TransferStatus.failed ||
      TransferStatus.corrupted => TransferFileStatus.failed,
      TransferStatus.cancelled ||
      TransferStatus.rejected => TransferFileStatus.cancelled,
      _ => TransferFileStatus.pending,
    };
  }

  NetworkPolicy _networkPolicyFromName(String? value) {
    return switch (value) {
      'wifiOnly' => NetworkPolicy.wifiOnly,
      'allowMetered' => NetworkPolicy.allowMetered,
      _ => NetworkPolicy.confirmOnMetered,
    };
  }

  TransferFailureCode _failureCodeFromName(String? value) {
    return switch (value) {
      'invalidRecipient' => TransferFailureCode.invalidRecipient,
      'recipientOffline' => TransferFailureCode.recipientOffline,
      'networkInterrupted' => TransferFailureCode.networkInterrupted,
      'fileTooLarge' => TransferFailureCode.fileTooLarge,
      'lowStorage' => TransferFailureCode.lowStorage,
      'permissionDenied' => TransferFailureCode.permissionDenied,
      'duplicateTransfer' => TransferFailureCode.duplicateTransfer,
      'integrityCheckFailed' => TransferFailureCode.integrityCheckFailed,
      'backgroundExecutionInterrupted' =>
        TransferFailureCode.backgroundExecutionInterrupted,
      _ => TransferFailureCode.unknown,
    };
  }
}
