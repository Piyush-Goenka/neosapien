import 'dart:io';

import 'package:neo_sapien/features/recipients/domain/entities/recipient.dart';
import 'package:neo_sapien/features/transfers/data/data_sources/firestore_transfer_remote_data_source.dart';
import 'package:neo_sapien/features/transfers/data/data_sources/transfer_download_local_data_source.dart';
import 'package:neo_sapien/features/transfers/data/repositories/in_memory_transfer_repository.dart';
import 'package:neo_sapien/features/transfers/data/services/transfer_remote_context_resolver.dart';
import 'package:neo_sapien/features/transfers/domain/entities/network_policy.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_batch.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_direction.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_file.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_file_status.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_status.dart';
import 'package:neo_sapien/features/transfers/domain/repositories/transfer_repository.dart';

class HybridTransferRepository implements TransferRepository {
  HybridTransferRepository({
    required InMemoryTransferRepository localRepository,
    required FirestoreTransferRemoteDataSource remoteDataSource,
    required TransferDownloadLocalDataSource downloadLocalDataSource,
    required TransferRemoteContextResolver remoteContextResolver,
    required Duration transferTtl,
  }) : _localRepository = localRepository,
       _remoteDataSource = remoteDataSource,
       _downloadLocalDataSource = downloadLocalDataSource,
       _remoteContextResolver = remoteContextResolver,
       _transferTtl = transferTtl;

  final InMemoryTransferRepository _localRepository;
  final FirestoreTransferRemoteDataSource _remoteDataSource;
  final TransferDownloadLocalDataSource _downloadLocalDataSource;
  final TransferRemoteContextResolver _remoteContextResolver;
  final Duration _transferTtl;
  final Map<String, List<TransferFile>> _outgoingSourceFiles =
      <String, List<TransferFile>>{};

  @override
  Stream<List<TransferBatch>> watchBatches() async* {
    final context = await _remoteContextResolver.tryResolve();
    if (context == null) {
      yield* _localRepository.watchBatches();
      return;
    }

    await for (final batches in _remoteDataSource.watchUserTransfers(
      currentUserUid: context.uid,
    )) {
      final downloadedBatches = await _downloadLocalDataSource.readAllBatches();
      yield batches
          .map(
            (batch) => _mergeIncomingDownloadState(
              _mergeOutgoingSourceFiles(batch),
              downloadedBatches[batch.id],
            ),
          )
          .toList(growable: false);
    }
  }

  @override
  Future<String> createDraft({
    required Recipient recipient,
    required List<TransferFile> files,
    required NetworkPolicy networkPolicy,
  }) async {
    final context = await _remoteContextResolver.tryResolve();
    if (context == null || recipient.userId == null) {
      return _localRepository.createDraft(
        recipient: recipient,
        files: files,
        networkPolicy: networkPolicy,
      );
    }

    final batchId = await _remoteDataSource.createTransferDraft(
      senderUid: context.uid,
      senderCode: context.identity.shortCode,
      recipient: recipient,
      files: files,
      networkPolicy: networkPolicy,
      transferTtl: _transferTtl,
    );
    _outgoingSourceFiles[batchId] = List<TransferFile>.unmodifiable(files);
    return batchId;
  }

  @override
  Future<TransferBatch?> getBatch(String batchId) async {
    final context = await _remoteContextResolver.tryResolve();
    if (context == null) {
      return _localRepository.getBatch(batchId);
    }

    final batch = await _remoteDataSource.fetchTransferBatch(
      batchId: batchId,
      currentUserUid: context.uid,
    );
    if (batch == null) {
      return null;
    }

    final downloadedBatch = await _downloadLocalDataSource.readBatch(batchId);
    return _mergeIncomingDownloadState(
      _mergeOutgoingSourceFiles(batch),
      downloadedBatch,
    );
  }

  @override
  Future<void> cancelBatch(String batchId) async {
    final context = await _remoteContextResolver.tryResolve();
    if (context == null) {
      return _localRepository.cancelBatch(batchId);
    }

    _outgoingSourceFiles.remove(batchId);
    return _remoteDataSource.cancelBatch(
      batchId: batchId,
      currentUserUid: context.uid,
    );
  }

  @override
  Future<void> acceptBatch(String batchId) async {
    final context = await _remoteContextResolver.tryResolve();
    if (context == null) {
      return _localRepository.acceptBatch(batchId);
    }

    return _remoteDataSource.acceptBatch(
      batchId: batchId,
      currentUserUid: context.uid,
    );
  }

  @override
  Future<void> rejectBatch(String batchId) async {
    final context = await _remoteContextResolver.tryResolve();
    if (context == null) {
      return _localRepository.rejectBatch(batchId);
    }

    return _remoteDataSource.rejectBatch(
      batchId: batchId,
      currentUserUid: context.uid,
    );
  }

  void dispose() {
    _localRepository.dispose();
  }

  TransferBatch _mergeOutgoingSourceFiles(TransferBatch batch) {
    if (batch.direction != TransferDirection.outgoing) {
      return batch;
    }

    final cachedFiles = _outgoingSourceFiles[batch.id];
    if (cachedFiles == null || cachedFiles.isEmpty) {
      return batch;
    }

    final cachedById = <String, TransferFile>{
      for (final file in cachedFiles) file.id: file,
    };
    final mergedFiles = batch.files
        .map((file) {
          final cachedFile = cachedById[file.id];
          if (cachedFile == null) {
            return file;
          }

          return file.copyWith(
            checksumSha256: cachedFile.checksumSha256,
            localPath: cachedFile.localPath,
            sourceIdentifier: cachedFile.sourceIdentifier,
          );
        })
        .toList(growable: false);

    return batch.copyWith(files: mergedFiles);
  }

  TransferBatch _mergeIncomingDownloadState(
    TransferBatch batch,
    LocalDownloadedTransferBatch? downloadedBatch,
  ) {
    if (batch.direction != TransferDirection.incoming ||
        downloadedBatch == null ||
        downloadedBatch.files.isEmpty) {
      return batch;
    }

    final downloadedById = <String, LocalDownloadedTransferFile>{
      for (final file in downloadedBatch.files) file.fileId: file,
    };
    var completedFileCount = 0;
    final mergedFiles = batch.files
        .map((file) {
          final downloadedFile = downloadedById[file.id];
          if (downloadedFile == null ||
              !File(downloadedFile.localPath).existsSync()) {
            return file;
          }

          completedFileCount += 1;
          return file.copyWith(
            localPath: downloadedFile.localPath,
            transferredBytes: file.byteCount,
            status: TransferFileStatus.completed,
            failure: null,
          );
        })
        .toList(growable: false);

    final mergedStatus =
        completedFileCount == batch.files.length && batch.files.isNotEmpty
        ? _completedOverride(batch.status)
        : batch.status;

    return batch.copyWith(
      status: mergedStatus,
      files: mergedFiles,
      bytesTransferred: mergedFiles.fold<int>(
        0,
        (total, file) => total + _clampedTransferredBytes(file),
      ),
      totalBytes: mergedFiles.fold<int>(
        0,
        (total, file) => total + file.byteCount,
      ),
    );
  }

  TransferStatus _completedOverride(TransferStatus status) {
    return switch (status) {
      TransferStatus.cancelled ||
      TransferStatus.rejected ||
      TransferStatus.expired => status,
      _ => TransferStatus.completed,
    };
  }

  int _clampedTransferredBytes(TransferFile file) {
    if (file.byteCount <= 0) {
      return 0;
    }
    if (file.transferredBytes < 0) {
      return 0;
    }
    if (file.transferredBytes > file.byteCount) {
      return file.byteCount;
    }
    return file.transferredBytes;
  }
}
