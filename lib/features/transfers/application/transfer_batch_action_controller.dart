import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neo_sapien/core/errors/app_exception.dart';
import 'package:neo_sapien/core/providers/storage_providers.dart';
import 'package:neo_sapien/core/utils/byte_count_formatter.dart';
import 'package:neo_sapien/features/transfers/application/transfer_draft_controller.dart';

final transferBatchActionControllerProvider =
    NotifierProvider<TransferBatchActionController, TransferBatchActionState>(
      TransferBatchActionController.new,
    );

@immutable
class TransferBatchActionState {
  const TransferBatchActionState({
    this.pendingBatchIds = const <String>{},
    this.errorMessage,
  });

  final Set<String> pendingBatchIds;
  final String? errorMessage;

  bool isPending(String batchId) => pendingBatchIds.contains(batchId);

  TransferBatchActionState copyWith({
    Set<String>? pendingBatchIds,
    Object? errorMessage = _transferBatchActionSentinel,
  }) {
    return TransferBatchActionState(
      pendingBatchIds: pendingBatchIds ?? this.pendingBatchIds,
      errorMessage: errorMessage == _transferBatchActionSentinel
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const Object _transferBatchActionSentinel = Object();

class TransferBatchActionController extends Notifier<TransferBatchActionState> {
  @override
  TransferBatchActionState build() {
    return const TransferBatchActionState();
  }

  Future<void> accept(String batchId) {
    return _run(batchId, () async {
      await _ensureFreeStorageForBatch(batchId);
      await ref.read(transferRepositoryProvider).acceptBatch(batchId);
    });
  }

  Future<void> reject(String batchId) {
    return _run(
      batchId,
      () => ref.read(transferRepositoryProvider).rejectBatch(batchId),
    );
  }

  Future<void> startUpload(String batchId) {
    return _run(
      batchId,
      () => ref.read(transferEngineProvider).enqueue(batchId),
    );
  }

  Future<void> download(String batchId) {
    return _run(batchId, () async {
      await _ensureFreeStorageForBatch(batchId);
      await ref.read(transferEngineProvider).enqueue(batchId);
    });
  }

  Future<void> _ensureFreeStorageForBatch(String batchId) async {
    final batch = await ref.read(transferRepositoryProvider).getBatch(batchId);
    if (batch == null) {
      return;
    }

    final required = batch.totalBytes;
    if (required <= 0) {
      return;
    }

    final freeBytes = await ref.read(deviceStorageCheckerProvider).freeBytes();
    if (freeBytes == null) {
      return;
    }

    // Require ~10% headroom so we don't OOM the filesystem while writing
    // the last file.
    final minimumRequired = (required * 1.1).toInt();
    if (freeBytes < minimumRequired) {
      throw TransferRepositoryException(
        'Only ${ByteCountFormatter.format(freeBytes)} free on this device, '
        'but ${ByteCountFormatter.format(minimumRequired)} are required. '
        'Free up space and try again.',
      );
    }
  }

  Future<void> cancel(String batchId) {
    return _run(
      batchId,
      () => ref.read(transferEngineProvider).cancel(batchId),
    );
  }

  Future<void> _run(String batchId, Future<void> Function() action) async {
    state = state.copyWith(
      pendingBatchIds: <String>{...state.pendingBatchIds, batchId},
      errorMessage: null,
    );

    try {
      await action();
      final updatedPending = <String>{...state.pendingBatchIds}
        ..remove(batchId);
      state = state.copyWith(pendingBatchIds: updatedPending);
    } on AppException catch (error) {
      final updatedPending = <String>{...state.pendingBatchIds}
        ..remove(batchId);
      state = state.copyWith(
        pendingBatchIds: updatedPending,
        errorMessage: error.message,
      );
    } on Object catch (error) {
      final updatedPending = <String>{...state.pendingBatchIds}
        ..remove(batchId);
      state = state.copyWith(
        pendingBatchIds: updatedPending,
        errorMessage: error.toString(),
      );
    }
  }
}
