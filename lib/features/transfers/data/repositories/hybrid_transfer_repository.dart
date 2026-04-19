import 'package:neo_sapien/features/recipients/domain/entities/recipient.dart';
import 'package:neo_sapien/features/transfers/data/data_sources/firestore_transfer_remote_data_source.dart';
import 'package:neo_sapien/features/transfers/data/repositories/in_memory_transfer_repository.dart';
import 'package:neo_sapien/features/transfers/data/services/transfer_remote_context_resolver.dart';
import 'package:neo_sapien/features/transfers/domain/entities/network_policy.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_batch.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_direction.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_file.dart';
import 'package:neo_sapien/features/transfers/domain/repositories/transfer_repository.dart';

class HybridTransferRepository implements TransferRepository {
  HybridTransferRepository({
    required InMemoryTransferRepository localRepository,
    required FirestoreTransferRemoteDataSource remoteDataSource,
    required TransferRemoteContextResolver remoteContextResolver,
    required Duration transferTtl,
  }) : _localRepository = localRepository,
       _remoteDataSource = remoteDataSource,
       _remoteContextResolver = remoteContextResolver,
       _transferTtl = transferTtl;

  final InMemoryTransferRepository _localRepository;
  final FirestoreTransferRemoteDataSource _remoteDataSource;
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

    yield* _remoteDataSource
        .watchUserTransfers(currentUserUid: context.uid)
        .map(
          (batches) =>
              batches.map(_mergeOutgoingSourceFiles).toList(growable: false),
        );
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

    return _mergeOutgoingSourceFiles(batch);
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
}
