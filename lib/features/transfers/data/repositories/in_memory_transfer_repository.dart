import 'dart:async';

import 'package:neo_sapien/features/recipients/domain/entities/recipient.dart';
import 'package:neo_sapien/features/transfers/domain/entities/network_policy.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_batch.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_direction.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_file.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_file_status.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_status.dart';
import 'package:neo_sapien/features/transfers/domain/repositories/transfer_repository.dart';

class InMemoryTransferRepository implements TransferRepository {
  final StreamController<List<TransferBatch>> _controller =
      StreamController<List<TransferBatch>>.broadcast();
  final List<TransferBatch> _batches = <TransferBatch>[];

  int _sequence = 0;

  @override
  Stream<List<TransferBatch>> watchBatches() async* {
    yield _snapshot();
    yield* _controller.stream;
  }

  @override
  Future<String> createDraft({
    required Recipient recipient,
    required List<TransferFile> files,
    required NetworkPolicy networkPolicy,
  }) async {
    final createdAt = DateTime.now().toUtc();
    final sequence = _sequence;
    _sequence += 1;
    final batchId =
        'draft-${createdAt.microsecondsSinceEpoch.toRadixString(36)}-${sequence.toRadixString(36)}';
    final totalBytes = files.fold<int>(
      0,
      (sum, file) => sum + file.byteCount,
    );

    _batches.insert(
      0,
      TransferBatch(
        id: batchId,
        direction: TransferDirection.outgoing,
        status: TransferStatus.draft,
        files: List<TransferFile>.unmodifiable(files),
        createdAt: createdAt,
        networkPolicy: networkPolicy,
        recipientCode: recipient.code,
        totalBytes: totalBytes,
      ),
    );
    _emit();
    return batchId;
  }

  @override
  Future<void> cancelBatch(String batchId) async {
    await _updateBatchStatus(batchId, TransferStatus.cancelled);
  }

  @override
  Future<void> acceptBatch(String batchId) async {
    await _updateBatchStatus(batchId, TransferStatus.queued);
  }

  @override
  Future<void> rejectBatch(String batchId) async {
    await _updateBatchStatus(batchId, TransferStatus.rejected);
  }

  Future<void> _updateBatchStatus(
    String batchId,
    TransferStatus status,
  ) async {
    final batchIndex = _batches.indexWhere((batch) => batch.id == batchId);
    if (batchIndex < 0) {
      return;
    }

    final batch = _batches[batchIndex];
    final fileStatus = switch (status) {
      TransferStatus.cancelled || TransferStatus.rejected =>
        TransferFileStatus.cancelled,
      TransferStatus.completed => TransferFileStatus.completed,
      TransferStatus.uploading || TransferStatus.downloading =>
        TransferFileStatus.inProgress,
      TransferStatus.failed || TransferStatus.corrupted =>
        TransferFileStatus.failed,
      _ => TransferFileStatus.pending,
    };
    _batches[batchIndex] = batch.copyWith(
      status: status,
      files: batch.files
          .map(
            (file) => file.copyWith(status: fileStatus),
          )
          .toList(growable: false),
    );
    _emit();
  }

  void dispose() {
    _controller.close();
  }

  void _emit() {
    if (_controller.isClosed) {
      return;
    }

    _controller.add(_snapshot());
  }

  List<TransferBatch> _snapshot() {
    return List<TransferBatch>.unmodifiable(_batches);
  }
}
