import 'package:neo_sapien/core/firebase/firebase_bootstrap_service.dart';
import 'package:neo_sapien/features/identity/data/data_sources/firebase_auth_data_source.dart';
import 'package:neo_sapien/features/identity/domain/entities/user_identity.dart';
import 'package:neo_sapien/features/identity/domain/repositories/identity_repository.dart';
import 'package:neo_sapien/features/recipients/domain/entities/recipient.dart';
import 'package:neo_sapien/features/transfers/data/data_sources/firestore_transfer_remote_data_source.dart';
import 'package:neo_sapien/features/transfers/data/repositories/in_memory_transfer_repository.dart';
import 'package:neo_sapien/features/transfers/domain/entities/network_policy.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_batch.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_file.dart';
import 'package:neo_sapien/features/transfers/domain/repositories/transfer_repository.dart';

class HybridTransferRepository implements TransferRepository {
  HybridTransferRepository({
    required InMemoryTransferRepository localRepository,
    required FirestoreTransferRemoteDataSource remoteDataSource,
    required FirebaseBootstrapService firebaseBootstrapService,
    required FirebaseAuthDataSource firebaseAuthDataSource,
    required IdentityRepository identityRepository,
    required Duration transferTtl,
  }) : _localRepository = localRepository,
       _remoteDataSource = remoteDataSource,
       _firebaseBootstrapService = firebaseBootstrapService,
       _firebaseAuthDataSource = firebaseAuthDataSource,
       _identityRepository = identityRepository,
       _transferTtl = transferTtl;

  final InMemoryTransferRepository _localRepository;
  final FirestoreTransferRemoteDataSource _remoteDataSource;
  final FirebaseBootstrapService _firebaseBootstrapService;
  final FirebaseAuthDataSource _firebaseAuthDataSource;
  final IdentityRepository _identityRepository;
  final Duration _transferTtl;

  @override
  Stream<List<TransferBatch>> watchBatches() async* {
    final context = await _tryRemoteContext();
    if (context == null) {
      yield* _localRepository.watchBatches();
      return;
    }

    yield* _remoteDataSource.watchUserTransfers(currentUserUid: context.uid);
  }

  @override
  Future<String> createDraft({
    required Recipient recipient,
    required List<TransferFile> files,
    required NetworkPolicy networkPolicy,
  }) async {
    final context = await _tryRemoteContext();
    if (context == null || recipient.userId == null) {
      return _localRepository.createDraft(
        recipient: recipient,
        files: files,
        networkPolicy: networkPolicy,
      );
    }

    return _remoteDataSource.createTransferDraft(
      senderUid: context.uid,
      senderCode: context.identity.shortCode,
      recipient: recipient,
      files: files,
      networkPolicy: networkPolicy,
      transferTtl: _transferTtl,
    );
  }

  @override
  Future<void> cancelBatch(String batchId) async {
    final context = await _tryRemoteContext();
    if (context == null) {
      return _localRepository.cancelBatch(batchId);
    }

    return _remoteDataSource.cancelBatch(
      batchId: batchId,
      currentUserUid: context.uid,
    );
  }

  @override
  Future<void> acceptBatch(String batchId) async {
    final context = await _tryRemoteContext();
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
    final context = await _tryRemoteContext();
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

  Future<_RemoteTransferContext?> _tryRemoteContext() async {
    final bootstrapState = await _firebaseBootstrapService.ensureInitialized();
    if (!bootstrapState.isReady) {
      return null;
    }

    final identity =
        await _identityRepository.getCurrentIdentity() ??
        await _identityRepository.ensureProvisionedIdentity();
    final authenticatedUser = await _firebaseAuthDataSource
        .ensureAnonymousSession();

    return _RemoteTransferContext(
      uid: authenticatedUser.uid,
      identity: identity,
    );
  }
}

class _RemoteTransferContext {
  const _RemoteTransferContext({required this.uid, required this.identity});

  final String uid;
  final UserIdentity identity;
}
