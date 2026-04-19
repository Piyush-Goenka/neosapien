import 'dart:async';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:neo_sapien/core/errors/app_exception.dart';
import 'package:neo_sapien/features/transfers/data/data_sources/firestore_transfer_remote_data_source.dart';
import 'package:neo_sapien/features/transfers/data/data_sources/transfer_download_local_data_source.dart';
import 'package:neo_sapien/features/transfers/data/services/received_transfer_file_store.dart';
import 'package:neo_sapien/features/transfers/data/services/transfer_remote_context_resolver.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_batch.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_direction.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_failure.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_failure_code.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_file.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_file_status.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_status.dart';
import 'package:neo_sapien/features/transfers/domain/repositories/transfer_repository.dart';
import 'package:neo_sapien/features/transfers/domain/services/transfer_engine.dart';

class FirebaseStorageTransferEngine implements TransferEngine {
  FirebaseStorageTransferEngine({
    required FirebaseStorage firebaseStorage,
    required FirestoreTransferRemoteDataSource remoteDataSource,
    required TransferRepository transferRepository,
    required TransferDownloadLocalDataSource downloadLocalDataSource,
    required ReceivedTransferFileStore receivedTransferFileStore,
    required TransferRemoteContextResolver remoteContextResolver,
  }) : _firebaseStorage = firebaseStorage,
       _remoteDataSource = remoteDataSource,
       _transferRepository = transferRepository,
       _downloadLocalDataSource = downloadLocalDataSource,
       _receivedTransferFileStore = receivedTransferFileStore,
       _remoteContextResolver = remoteContextResolver;

  final FirebaseStorage _firebaseStorage;
  final FirestoreTransferRemoteDataSource _remoteDataSource;
  final TransferRepository _transferRepository;
  final TransferDownloadLocalDataSource _downloadLocalDataSource;
  final ReceivedTransferFileStore _receivedTransferFileStore;
  final TransferRemoteContextResolver _remoteContextResolver;
  final Map<String, Future<void>> _runningTransfers = <String, Future<void>>{};
  final Map<String, Task> _activeTransferTasks = <String, Task>{};
  final Set<String> _cancelRequestedBatchIds = <String>{};

  @override
  Future<void> enqueue(String batchId) async {
    if (_runningTransfers.containsKey(batchId)) {
      return;
    }

    final context = await _remoteContextResolver.tryResolve();
    if (context == null) {
      throw const TransferEngineException(
        'Firebase must be configured before transfers can start.',
      );
    }

    final batch = await _transferRepository.getBatch(batchId);
    if (batch == null) {
      throw const TransferEngineException('Transfer batch not found.');
    }

    _cancelRequestedBatchIds.remove(batchId);

    if (batch.direction == TransferDirection.outgoing) {
      if (batch.status == TransferStatus.completed ||
          batch.status == TransferStatus.pendingRecipient) {
        return;
      }

      _validateStartableOutgoingBatch(batch);
      final preparedBatch = _prepareBatchForUpload(batch);
      final uploadFuture = _runUpload(
        batchId: batchId,
        context: context,
        batch: preparedBatch,
      );
      _trackRunningTransfer(batchId, uploadFuture);
      return;
    }

    if (_allFilesSavedLocally(batch)) {
      return;
    }

    _validateStartableIncomingBatch(batch);
    final preparedBatch = _prepareBatchForDownload(batch);
    final downloadFuture = _runDownload(
      batchId: batchId,
      context: context,
      batch: preparedBatch,
    );
    _trackRunningTransfer(batchId, downloadFuture);
  }

  @override
  Future<void> pause(String batchId) async {
    final transferTask = _activeTransferTasks[batchId];
    if (transferTask == null) {
      return;
    }

    await transferTask.pause();
  }

  @override
  Future<void> resume(String batchId) async {
    final transferTask = _activeTransferTasks[batchId];
    if (transferTask != null) {
      await transferTask.resume();
      return;
    }

    await enqueue(batchId);
  }

  @override
  Future<void> cancel(String batchId) async {
    _cancelRequestedBatchIds.add(batchId);
    final transferTask = _activeTransferTasks[batchId];
    if (transferTask != null) {
      await transferTask.cancel();
      return;
    }

    if (_runningTransfers.containsKey(batchId)) {
      return;
    }

    final batch = await _transferRepository.getBatch(batchId);
    if (batch == null) {
      _cancelRequestedBatchIds.remove(batchId);
      return;
    }

    if (batch.direction == TransferDirection.outgoing) {
      await _transferRepository.cancelBatch(batchId);
      _cancelRequestedBatchIds.remove(batchId);
      return;
    }

    if (batch.status == TransferStatus.downloading) {
      final context = await _remoteContextResolver.tryResolve();
      if (context != null) {
        await _resetIncomingBatch(
          batchId: batchId,
          currentUserUid: context.uid,
          batch: batch,
        );
      }
    }

    _cancelRequestedBatchIds.remove(batchId);
  }

  Future<void> _runUpload({
    required String batchId,
    required TransferRemoteContext context,
    required TransferBatch batch,
  }) async {
    var activeBatch = batch;

    try {
      await _persistRemoteBatch(
        batchId: batchId,
        currentUserUid: context.uid,
        batch: activeBatch,
      );

      if (_cancelRequestedBatchIds.contains(batchId)) {
        await _markOutgoingCancelled(
          batchId: batchId,
          currentUserUid: context.uid,
          batch: activeBatch,
        );
        return;
      }

      for (var index = 0; index < activeBatch.files.length; index += 1) {
        final file = activeBatch.files[index];
        if (_isUploadedFileComplete(file)) {
          continue;
        }

        final localPath = file.localPath;
        if (localPath == null || localPath.isEmpty) {
          await _markFailed(
            batchId: batchId,
            currentUserUid: context.uid,
            batch: activeBatch,
            fileIndex: index,
            failure: const TransferFailure(
              code: TransferFailureCode.unknown,
              message:
                  'The selected file is no longer available locally. Pick it again and retry.',
              isRecoverable: true,
            ),
          );
          return;
        }

        final localFile = File(localPath);
        if (!localFile.existsSync()) {
          await _markFailed(
            batchId: batchId,
            currentUserUid: context.uid,
            batch: activeBatch,
            fileIndex: index,
            failure: TransferFailure(
              code: TransferFailureCode.unknown,
              message:
                  '${file.name} is no longer available at $localPath. Pick it again and retry.',
              isRecoverable: true,
            ),
          );
          return;
        }

        final storagePath =
            file.storagePath ?? _buildStoragePath(batchId, file);
        activeBatch = _replaceFile(
          activeBatch,
          index,
          activeBatch.files[index].copyWith(
            status: TransferFileStatus.inProgress,
            storagePath: storagePath,
            failure: null,
            downloadUrl: null,
          ),
        );
        await _persistRemoteBatch(
          batchId: batchId,
          currentUserUid: context.uid,
          batch: activeBatch,
        );

        final uploadTask = _firebaseStorage
            .ref(storagePath)
            .putFile(
              localFile,
              SettableMetadata(
                contentType: file.mimeType,
                customMetadata: <String, String>{
                  'transferBatchId': batchId,
                  'transferFileId': file.id,
                },
              ),
            );
        _activeTransferTasks[batchId] = uploadTask;

        var lastSyncedAt = DateTime.fromMillisecondsSinceEpoch(0).toUtc();
        var lastSyncedBytes = activeBatch.bytesTransferred;

        try {
          await for (final snapshot in uploadTask.snapshotEvents) {
            if (_cancelRequestedBatchIds.contains(batchId)) {
              await uploadTask.cancel();
              break;
            }

            final transferredBytes = _clampTransferredBytes(
              snapshot.bytesTransferred,
              activeBatch.files[index].byteCount,
            );
            activeBatch = _replaceFile(
              activeBatch,
              index,
              activeBatch.files[index].copyWith(
                transferredBytes: transferredBytes,
                status: transferredBytes >= activeBatch.files[index].byteCount
                    ? TransferFileStatus.completed
                    : TransferFileStatus.inProgress,
                storagePath: storagePath,
              ),
            );

            final aggregateBytes = activeBatch.bytesTransferred;
            final now = DateTime.now().toUtc();
            if (_shouldSyncProgress(
              now: now,
              lastSyncedAt: lastSyncedAt,
              currentBytes: aggregateBytes,
              lastSyncedBytes: lastSyncedBytes,
              totalBytes: activeBatch.totalBytes,
            )) {
              await _persistRemoteBatch(
                batchId: batchId,
                currentUserUid: context.uid,
                batch: activeBatch,
              );
              lastSyncedAt = now;
              lastSyncedBytes = aggregateBytes;
            }
          }

          if (_cancelRequestedBatchIds.contains(batchId)) {
            await _markOutgoingCancelled(
              batchId: batchId,
              currentUserUid: context.uid,
              batch: activeBatch,
            );
            return;
          }

          final completedSnapshot = await uploadTask;
          final downloadUrl = await completedSnapshot.ref.getDownloadURL();
          activeBatch = _replaceFile(
            activeBatch,
            index,
            activeBatch.files[index].copyWith(
              transferredBytes: activeBatch.files[index].byteCount,
              status: TransferFileStatus.completed,
              storagePath: storagePath,
              downloadUrl: downloadUrl,
              failure: null,
            ),
          );
          await _persistRemoteBatch(
            batchId: batchId,
            currentUserUid: context.uid,
            batch: activeBatch,
          );
        } on FirebaseException catch (error) {
          if (error.code == 'canceled' ||
              _cancelRequestedBatchIds.contains(batchId)) {
            await _markOutgoingCancelled(
              batchId: batchId,
              currentUserUid: context.uid,
              batch: activeBatch,
            );
            return;
          }

          await _markFailed(
            batchId: batchId,
            currentUserUid: context.uid,
            batch: activeBatch,
            fileIndex: index,
            failure: _uploadFailureFromFirebaseError(file.name, error),
          );
          return;
        } finally {
          final _ = _activeTransferTasks.remove(batchId);
        }
      }

      final completedFiles = activeBatch.files
          .map(
            (file) => file.copyWith(
              status: TransferFileStatus.completed,
              failure: null,
            ),
          )
          .toList(growable: false);
      final finishedBatch = activeBatch.copyWith(
        status: TransferStatus.pendingRecipient,
        files: completedFiles,
        failure: null,
        bytesTransferred: _aggregateTransferredBytes(completedFiles),
      );
      await _persistRemoteBatch(
        batchId: batchId,
        currentUserUid: context.uid,
        batch: finishedBatch,
      );
    } on Object catch (error) {
      await _markFailedSafely(
        batchId: batchId,
        currentUserUid: context.uid,
        batch: activeBatch,
        failure: TransferFailure(
          code: TransferFailureCode.unknown,
          message: error is AppException
              ? error.message
              : 'Upload failed unexpectedly: $error',
          isRecoverable: true,
        ),
      );
    }
  }

  Future<void> _runDownload({
    required String batchId,
    required TransferRemoteContext context,
    required TransferBatch batch,
  }) async {
    var activeBatch = batch;

    try {
      await _persistRemoteBatch(
        batchId: batchId,
        currentUserUid: context.uid,
        batch: activeBatch,
      );

      if (_cancelRequestedBatchIds.contains(batchId)) {
        await _resetIncomingBatch(
          batchId: batchId,
          currentUserUid: context.uid,
          batch: activeBatch,
        );
        return;
      }

      for (var index = 0; index < activeBatch.files.length; index += 1) {
        final file = activeBatch.files[index];
        if (_hasLocalCopy(file)) {
          continue;
        }

        final reference = _storageReferenceForFile(file);
        if (reference == null) {
          await _markFailed(
            batchId: batchId,
            currentUserUid: context.uid,
            batch: activeBatch,
            fileIndex: index,
            failure: TransferFailure(
              code: TransferFailureCode.unknown,
              message:
                  'Download details for ${file.name} are not available yet. Try again once the upload finishes.',
              isRecoverable: true,
            ),
          );
          return;
        }

        final targetFile = await _receivedTransferFileStore.createTargetFile(
          batchId: batchId,
          fileName: file.name,
        );
        activeBatch = _replaceFile(
          activeBatch,
          index,
          activeBatch.files[index].copyWith(
            transferredBytes: 0,
            status: TransferFileStatus.inProgress,
            failure: null,
            localPath: null,
          ),
        );
        await _persistRemoteBatch(
          batchId: batchId,
          currentUserUid: context.uid,
          batch: activeBatch,
        );

        final downloadTask = reference.writeToFile(targetFile);
        _activeTransferTasks[batchId] = downloadTask;

        var lastSyncedAt = DateTime.fromMillisecondsSinceEpoch(0).toUtc();
        var lastSyncedBytes = activeBatch.bytesTransferred;

        try {
          await for (final snapshot in downloadTask.snapshotEvents) {
            if (_cancelRequestedBatchIds.contains(batchId)) {
              await downloadTask.cancel();
              break;
            }

            final transferredBytes = _clampTransferredBytes(
              snapshot.bytesTransferred,
              activeBatch.files[index].byteCount,
            );
            activeBatch = _replaceFile(
              activeBatch,
              index,
              activeBatch.files[index].copyWith(
                transferredBytes: transferredBytes,
                status: transferredBytes >= activeBatch.files[index].byteCount
                    ? TransferFileStatus.completed
                    : TransferFileStatus.inProgress,
                failure: null,
              ),
            );

            final aggregateBytes = activeBatch.bytesTransferred;
            final now = DateTime.now().toUtc();
            if (_shouldSyncProgress(
              now: now,
              lastSyncedAt: lastSyncedAt,
              currentBytes: aggregateBytes,
              lastSyncedBytes: lastSyncedBytes,
              totalBytes: activeBatch.totalBytes,
            )) {
              await _persistRemoteBatch(
                batchId: batchId,
                currentUserUid: context.uid,
                batch: activeBatch,
              );
              lastSyncedAt = now;
              lastSyncedBytes = aggregateBytes;
            }
          }

          if (_cancelRequestedBatchIds.contains(batchId)) {
            await _receivedTransferFileStore.deleteIfExists(targetFile.path);
            await _resetIncomingBatch(
              batchId: batchId,
              currentUserUid: context.uid,
              batch: activeBatch,
            );
            return;
          }

          await downloadTask;
          final completedFile = activeBatch.files[index].copyWith(
            transferredBytes: activeBatch.files[index].byteCount,
            status: TransferFileStatus.completed,
            localPath: targetFile.path,
            failure: null,
          );
          activeBatch = _replaceFile(activeBatch, index, completedFile);
          await _downloadLocalDataSource.upsertDownloadedFile(
            batchId: batchId,
            fileId: completedFile.id,
            localPath: targetFile.path,
            savedAt: DateTime.now().toUtc(),
          );
          await _persistRemoteBatch(
            batchId: batchId,
            currentUserUid: context.uid,
            batch: activeBatch,
          );
        } on FirebaseException catch (error) {
          await _receivedTransferFileStore.deleteIfExists(targetFile.path);
          if (error.code == 'canceled' ||
              _cancelRequestedBatchIds.contains(batchId)) {
            await _resetIncomingBatch(
              batchId: batchId,
              currentUserUid: context.uid,
              batch: activeBatch,
            );
            return;
          }

          await _markFailed(
            batchId: batchId,
            currentUserUid: context.uid,
            batch: activeBatch,
            fileIndex: index,
            failure: _downloadFailureFromFirebaseError(file.name, error),
          );
          return;
        } finally {
          final _ = _activeTransferTasks.remove(batchId);
        }
      }

      final completedFiles = activeBatch.files
          .map(
            (file) => file.copyWith(
              transferredBytes: file.byteCount,
              status: TransferFileStatus.completed,
              failure: null,
            ),
          )
          .toList(growable: false);
      final finishedBatch = activeBatch.copyWith(
        status: TransferStatus.completed,
        files: completedFiles,
        failure: null,
        bytesTransferred: _aggregateTransferredBytes(completedFiles),
      );
      await _persistRemoteBatch(
        batchId: batchId,
        currentUserUid: context.uid,
        batch: finishedBatch,
      );
    } on Object catch (error) {
      await _markFailedSafely(
        batchId: batchId,
        currentUserUid: context.uid,
        batch: activeBatch,
        failure: TransferFailure(
          code: TransferFailureCode.unknown,
          message: error is AppException
              ? error.message
              : 'Download failed unexpectedly: $error',
          isRecoverable: true,
        ),
      );
    }
  }

  void _trackRunningTransfer(String batchId, Future<void> transferFuture) {
    _runningTransfers[batchId] = transferFuture;
    unawaited(
      transferFuture.whenComplete(() {
        _runningTransfers.remove(batchId);
        _activeTransferTasks.remove(batchId);
        _cancelRequestedBatchIds.remove(batchId);
      }),
    );
  }

  void _validateStartableOutgoingBatch(TransferBatch batch) {
    if (batch.direction != TransferDirection.outgoing) {
      throw const TransferEngineException(
        'Only outgoing transfers can be uploaded from this device.',
      );
    }

    if (batch.status == TransferStatus.awaitingAcceptance) {
      throw const TransferEngineException(
        'Recipient must accept the transfer before upload can start.',
      );
    }

    if (batch.status == TransferStatus.rejected) {
      throw const TransferEngineException(
        'Recipient rejected this transfer, so upload cannot start.',
      );
    }

    if (batch.status == TransferStatus.cancelled ||
        batch.status == TransferStatus.expired) {
      throw const TransferEngineException(
        'This transfer can no longer be started.',
      );
    }

    for (final file in batch.files) {
      if (_isUploadedFileComplete(file)) {
        continue;
      }

      final localPath = file.localPath;
      if (localPath == null || localPath.isEmpty) {
        throw TransferEngineException(
          'The source file for ${file.name} is not available on this device.',
        );
      }
    }
  }

  void _validateStartableIncomingBatch(TransferBatch batch) {
    if (batch.direction != TransferDirection.incoming) {
      throw const TransferEngineException(
        'Only incoming transfers can be downloaded from this device.',
      );
    }

    if (batch.status == TransferStatus.awaitingAcceptance) {
      throw const TransferEngineException(
        'Accept this transfer before trying to download it.',
      );
    }

    if (batch.status == TransferStatus.queued ||
        batch.status == TransferStatus.uploading) {
      throw const TransferEngineException(
        'The sender is still uploading this transfer. Try again once it finishes.',
      );
    }

    if (batch.status == TransferStatus.rejected ||
        batch.status == TransferStatus.cancelled ||
        batch.status == TransferStatus.expired) {
      throw const TransferEngineException(
        'This transfer is no longer available for download.',
      );
    }

    for (final file in batch.files) {
      if (_hasLocalCopy(file)) {
        continue;
      }

      if (_storageReferenceForFile(file) == null) {
        throw TransferEngineException(
          'Download details for ${file.name} are not available yet.',
        );
      }
    }
  }

  TransferBatch _prepareBatchForUpload(TransferBatch batch) {
    final preparedFiles = batch.files
        .map((file) {
          if (_isUploadedFileComplete(file)) {
            return file.copyWith(failure: null);
          }

          return file.copyWith(
            transferredBytes: 0,
            status: TransferFileStatus.pending,
            failure: null,
            downloadUrl: null,
          );
        })
        .toList(growable: false);

    return batch.copyWith(
      status: TransferStatus.uploading,
      files: preparedFiles,
      failure: null,
      bytesTransferred: _aggregateTransferredBytes(preparedFiles),
      totalBytes: preparedFiles.fold<int>(
        0,
        (total, file) => total + file.byteCount,
      ),
    );
  }

  TransferBatch _prepareBatchForDownload(TransferBatch batch) {
    final preparedFiles = batch.files
        .map((file) {
          if (_hasLocalCopy(file)) {
            return file.copyWith(
              transferredBytes: file.byteCount,
              status: TransferFileStatus.completed,
              failure: null,
            );
          }

          return file.copyWith(
            transferredBytes: 0,
            status: TransferFileStatus.pending,
            failure: null,
            localPath: null,
          );
        })
        .toList(growable: false);

    final allCompleted =
        preparedFiles.isNotEmpty && preparedFiles.every(_hasLocalCopy);

    return batch.copyWith(
      status: allCompleted
          ? TransferStatus.completed
          : TransferStatus.downloading,
      files: preparedFiles,
      failure: null,
      bytesTransferred: _aggregateTransferredBytes(preparedFiles),
      totalBytes: preparedFiles.fold<int>(
        0,
        (total, file) => total + file.byteCount,
      ),
    );
  }

  Future<void> _persistRemoteBatch({
    required String batchId,
    required String currentUserUid,
    required TransferBatch batch,
  }) {
    return _remoteDataSource.updateTransferBatch(
      batchId: batchId,
      currentUserUid: currentUserUid,
      status: batch.status,
      files: batch.files,
      bytesTransferred: batch.bytesTransferred,
      failure: batch.failure,
    );
  }

  Future<void> _markOutgoingCancelled({
    required String batchId,
    required String currentUserUid,
    required TransferBatch batch,
  }) {
    final cancelledFiles = batch.files
        .map(
          (file) => file.status == TransferFileStatus.completed
              ? file
              : file.copyWith(status: TransferFileStatus.cancelled),
        )
        .toList(growable: false);

    return _persistRemoteBatch(
      batchId: batchId,
      currentUserUid: currentUserUid,
      batch: batch.copyWith(
        status: TransferStatus.cancelled,
        files: cancelledFiles,
        failure: null,
        bytesTransferred: _aggregateTransferredBytes(cancelledFiles),
      ),
    );
  }

  Future<void> _resetIncomingBatch({
    required String batchId,
    required String currentUserUid,
    required TransferBatch batch,
  }) {
    final resetFiles = batch.files
        .map((file) {
          if (_hasLocalCopy(file)) {
            return file.copyWith(
              transferredBytes: file.byteCount,
              status: TransferFileStatus.completed,
              failure: null,
            );
          }

          return file.copyWith(
            transferredBytes: 0,
            status: TransferFileStatus.pending,
            failure: null,
            localPath: null,
          );
        })
        .toList(growable: false);

    final allCompleted =
        resetFiles.isNotEmpty && resetFiles.every(_hasLocalCopy);

    return _persistRemoteBatch(
      batchId: batchId,
      currentUserUid: currentUserUid,
      batch: batch.copyWith(
        status: allCompleted
            ? TransferStatus.completed
            : TransferStatus.pendingRecipient,
        files: resetFiles,
        failure: null,
        bytesTransferred: _aggregateTransferredBytes(resetFiles),
      ),
    );
  }

  Future<void> _markFailed({
    required String batchId,
    required String currentUserUid,
    required TransferBatch batch,
    required TransferFailure failure,
    int? fileIndex,
  }) {
    var failedBatch = batch;
    if (fileIndex != null && fileIndex >= 0 && fileIndex < batch.files.length) {
      failedBatch = _replaceFile(
        failedBatch,
        fileIndex,
        batch.files[fileIndex].copyWith(
          status: TransferFileStatus.failed,
          failure: failure,
          localPath: batch.files[fileIndex].localPath,
        ),
      );
    }

    return _persistRemoteBatch(
      batchId: batchId,
      currentUserUid: currentUserUid,
      batch: failedBatch.copyWith(
        status: TransferStatus.failed,
        failure: failure,
        bytesTransferred: _aggregateTransferredBytes(failedBatch.files),
      ),
    );
  }

  Future<void> _markFailedSafely({
    required String batchId,
    required String currentUserUid,
    required TransferBatch batch,
    required TransferFailure failure,
    int? fileIndex,
  }) async {
    try {
      await _markFailed(
        batchId: batchId,
        currentUserUid: currentUserUid,
        batch: batch,
        failure: failure,
        fileIndex: fileIndex,
      );
    } on Object {
      // If Firestore writes fail we still avoid crashing the transfer worker.
    }
  }

  TransferBatch _replaceFile(
    TransferBatch batch,
    int index,
    TransferFile replacement,
  ) {
    final files = <TransferFile>[...batch.files];
    files[index] = replacement;
    return batch.copyWith(
      files: files,
      bytesTransferred: _aggregateTransferredBytes(files),
      totalBytes: files.fold<int>(0, (total, file) => total + file.byteCount),
    );
  }

  int _aggregateTransferredBytes(List<TransferFile> files) {
    return files.fold<int>(
      0,
      (total, file) =>
          total + _clampTransferredBytes(file.transferredBytes, file.byteCount),
    );
  }

  int _clampTransferredBytes(int bytesTransferred, int byteCount) {
    if (byteCount <= 0) {
      return 0;
    }
    if (bytesTransferred < 0) {
      return 0;
    }
    if (bytesTransferred > byteCount) {
      return byteCount;
    }
    return bytesTransferred;
  }

  bool _shouldSyncProgress({
    required DateTime now,
    required DateTime lastSyncedAt,
    required int currentBytes,
    required int lastSyncedBytes,
    required int totalBytes,
  }) {
    if (currentBytes >= totalBytes) {
      return true;
    }

    if (currentBytes - lastSyncedBytes >= 256 * 1024) {
      return true;
    }

    return now.difference(lastSyncedAt) >= const Duration(milliseconds: 350);
  }

  bool _isUploadedFileComplete(TransferFile file) {
    return file.status == TransferFileStatus.completed &&
        file.storagePath != null &&
        file.storagePath!.isNotEmpty;
  }

  bool _hasLocalCopy(TransferFile file) {
    final localPath = file.localPath;
    return localPath != null &&
        localPath.isNotEmpty &&
        File(localPath).existsSync();
  }

  bool _allFilesSavedLocally(TransferBatch batch) {
    return batch.files.isNotEmpty && batch.files.every(_hasLocalCopy);
  }

  Reference? _storageReferenceForFile(TransferFile file) {
    final storagePath = file.storagePath;
    if (storagePath != null && storagePath.isNotEmpty) {
      return _firebaseStorage.ref(storagePath);
    }

    final downloadUrl = file.downloadUrl;
    if (downloadUrl == null || downloadUrl.isEmpty) {
      return null;
    }

    try {
      return _firebaseStorage.refFromURL(downloadUrl);
    } on Object {
      return null;
    }
  }

  String _buildStoragePath(String batchId, TransferFile file) {
    return 'transfers/$batchId/${file.id}';
  }

  TransferFailure _uploadFailureFromFirebaseError(
    String fileName,
    FirebaseException error,
  ) {
    return switch (error.code) {
      'unauthorized' => TransferFailure(
        code: TransferFailureCode.permissionDenied,
        message:
            'Upload permission was denied for $fileName. Check Firebase Storage rules and try again.',
        isRecoverable: false,
      ),
      'canceled' => TransferFailure(
        code: TransferFailureCode.backgroundExecutionInterrupted,
        message: 'Upload was cancelled before $fileName finished.',
        isRecoverable: true,
      ),
      'retry-limit-exceeded' || 'network-request-failed' => TransferFailure(
        code: TransferFailureCode.networkInterrupted,
        message:
            'Network interrupted while uploading $fileName. Retry will restart the incomplete file.',
        isRecoverable: true,
      ),
      _ => TransferFailure(
        code: TransferFailureCode.unknown,
        message: 'Failed to upload $fileName: ${error.message ?? error.code}.',
        isRecoverable: true,
      ),
    };
  }

  TransferFailure _downloadFailureFromFirebaseError(
    String fileName,
    FirebaseException error,
  ) {
    return switch (error.code) {
      'unauthorized' => TransferFailure(
        code: TransferFailureCode.permissionDenied,
        message:
            'Download permission was denied for $fileName. Check Firebase Storage rules and try again.',
        isRecoverable: false,
      ),
      'canceled' => TransferFailure(
        code: TransferFailureCode.backgroundExecutionInterrupted,
        message: 'Download was cancelled before $fileName finished saving.',
        isRecoverable: true,
      ),
      'retry-limit-exceeded' || 'network-request-failed' => TransferFailure(
        code: TransferFailureCode.networkInterrupted,
        message:
            'Network interrupted while downloading $fileName. Retry will restart that file cleanly.',
        isRecoverable: true,
      ),
      'object-not-found' => TransferFailure(
        code: TransferFailureCode.unknown,
        message:
            '$fileName is no longer available in storage. Retry after the sender uploads it again.',
        isRecoverable: false,
      ),
      _ => TransferFailure(
        code: TransferFailureCode.unknown,
        message:
            'Failed to download $fileName: ${error.message ?? error.code}.',
        isRecoverable: true,
      ),
    };
  }
}
