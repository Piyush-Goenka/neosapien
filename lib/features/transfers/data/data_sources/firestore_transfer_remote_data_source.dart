import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:neo_sapien/core/errors/app_exception.dart';
import 'package:neo_sapien/features/recipients/domain/entities/recipient.dart';
import 'package:neo_sapien/features/recipients/domain/value_objects/recipient_code.dart';
import 'package:neo_sapien/features/transfers/domain/entities/network_policy.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_batch.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_direction.dart';
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
        'files': files
            .map(
              (file) => <String, Object?>{
                'id': file.id,
                'name': file.name,
                'byteCount': file.byteCount,
                'mimeType': file.mimeType,
                'transferredBytes': file.transferredBytes,
                'status': file.status.name,
              },
            )
            .toList(growable: false),
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
          .listen(
            (snapshot) {
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
            },
            onError: controller.addError,
          );

      incomingSub = _transfersCollection
          .where('recipientUid', isEqualTo: currentUserUid)
          .snapshots()
          .listen(
            (snapshot) {
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
            },
            onError: controller.addError,
          );

      controller.onCancel = () async {
        await outgoingSub?.cancel();
        await incomingSub?.cancel();
      };
    });
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
    final totalBytes = (data['totalBytes'] as num?)?.toInt() ??
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
      bytesTransferred: bytesTransferred,
      totalBytes: totalBytes,
    );
  }

  List<TransferFile> _filesFromData(Object? rawFiles, TransferStatus batchStatus) {
    if (rawFiles is! List<Object?>) {
      return const <TransferFile>[];
    }

    return rawFiles
        .whereType<Map<String, dynamic>>()
        .map(
          (data) => TransferFile(
            id: data['id'] as String? ?? 'file-${rawFiles.indexOf(data)}',
            name: data['name'] as String? ?? 'unnamed-file',
            byteCount: (data['byteCount'] as num?)?.toInt() ?? 0,
            mimeType:
                data['mimeType'] as String? ?? 'application/octet-stream',
            transferredBytes:
                (data['transferredBytes'] as num?)?.toInt() ?? 0,
            status: _fileStatusFromName(
              data['status'] as String?,
              fallbackStatus: batchStatus,
            ),
          ),
        )
        .toList(growable: false);
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
      TransferStatus.completed => TransferFileStatus.completed,
      TransferStatus.uploading || TransferStatus.downloading =>
        TransferFileStatus.inProgress,
      TransferStatus.failed || TransferStatus.corrupted =>
        TransferFileStatus.failed,
      TransferStatus.cancelled || TransferStatus.rejected =>
        TransferFileStatus.cancelled,
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
}
