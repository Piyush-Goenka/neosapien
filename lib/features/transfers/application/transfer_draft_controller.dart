import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neo_sapien/core/errors/app_exception.dart';
import 'package:neo_sapien/core/providers/app_environment_provider.dart';
import 'package:neo_sapien/core/providers/firebase_providers.dart';
import 'package:neo_sapien/core/providers/secure_storage_provider.dart';
import 'package:neo_sapien/features/identity/application/identity_controller.dart';
import 'package:neo_sapien/features/recipients/domain/entities/recipient.dart';
import 'package:neo_sapien/features/transfers/data/data_sources/firestore_transfer_remote_data_source.dart';
import 'package:neo_sapien/features/transfers/data/data_sources/transfer_download_local_data_source.dart';
import 'package:neo_sapien/features/transfers/data/repositories/hybrid_transfer_repository.dart';
import 'package:neo_sapien/features/transfers/data/repositories/in_memory_transfer_repository.dart';
import 'package:neo_sapien/features/transfers/data/services/file_picker_transfer_file_selector.dart';
import 'package:neo_sapien/features/transfers/data/services/firebase_storage_transfer_engine.dart';
import 'package:neo_sapien/features/transfers/data/services/received_transfer_file_store.dart';
import 'package:neo_sapien/features/transfers/data/services/transfer_integrity_service.dart';
import 'package:neo_sapien/features/transfers/data/services/transfer_recovery_service.dart';
import 'package:neo_sapien/features/transfers/data/services/transfer_remote_context_resolver.dart';
import 'package:neo_sapien/features/transfers/domain/entities/network_policy.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_batch.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_file.dart';
import 'package:neo_sapien/features/transfers/domain/repositories/transfer_repository.dart';
import 'package:neo_sapien/features/transfers/domain/services/transfer_draft_validator.dart';
import 'package:neo_sapien/features/transfers/domain/services/transfer_engine.dart';
import 'package:neo_sapien/features/transfers/domain/services/transfer_file_selector.dart';

final transferRepositoryProvider = Provider<TransferRepository>((ref) {
  final environment = ref.watch(appEnvironmentProvider);
  final repository = HybridTransferRepository(
    localRepository: InMemoryTransferRepository(),
    remoteDataSource: ref.watch(firestoreTransferRemoteDataSourceProvider),
    downloadLocalDataSource: ref.watch(transferDownloadLocalDataSourceProvider),
    remoteContextResolver: ref.watch(transferRemoteContextResolverProvider),
    transferTtl: environment.transferTtl,
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final firestoreTransferRemoteDataSourceProvider =
    Provider<FirestoreTransferRemoteDataSource>((ref) {
      final firestore = ref.watch(firebaseFirestoreProvider);
      return FirestoreTransferRemoteDataSource(firestore);
    });

final transferDownloadLocalDataSourceProvider =
    Provider<TransferDownloadLocalDataSource>((ref) {
      return TransferDownloadLocalDataSource(ref.watch(secureStorageProvider));
    });

final transferRemoteContextResolverProvider =
    Provider<TransferRemoteContextResolver>((ref) {
      return TransferRemoteContextResolver(
        firebaseBootstrapService: ref.watch(firebaseBootstrapServiceProvider),
        firebaseAuthDataSource: ref.watch(firebaseAuthDataSourceProvider),
        identityRepository: ref.watch(identityRepositoryProvider),
      );
    });

final transferEngineProvider = Provider<TransferEngine>((ref) {
  return FirebaseStorageTransferEngine(
    firebaseStorage: ref.watch(firebaseStorageProvider),
    remoteDataSource: ref.watch(firestoreTransferRemoteDataSourceProvider),
    transferRepository: ref.watch(transferRepositoryProvider),
    downloadLocalDataSource: ref.watch(transferDownloadLocalDataSourceProvider),
    receivedTransferFileStore: ref.watch(receivedTransferFileStoreProvider),
    remoteContextResolver: ref.watch(transferRemoteContextResolverProvider),
    integrityService: ref.watch(transferIntegrityServiceProvider),
  );
});

final receivedTransferFileStoreProvider = Provider<ReceivedTransferFileStore>((
  ref,
) {
  return ReceivedTransferFileStore();
});

final transferIntegrityServiceProvider = Provider<TransferIntegrityService>((
  ref,
) {
  return const TransferIntegrityService();
});

final transferRecoveryServiceProvider = Provider<TransferRecoveryService>((
  ref,
) {
  return TransferRecoveryService(
    remoteDataSource: ref.watch(firestoreTransferRemoteDataSourceProvider),
    contextResolver: ref.watch(transferRemoteContextResolverProvider),
  );
});

/// Fires once on app boot (after identity is provisioned) to reconcile any
/// batches that were mid-flight when the process died.
final transferRecoveryBootProvider = FutureProvider<int>((ref) async {
  // Wait until identity is available (which implies auth + Firebase ready).
  await ref.watch(currentIdentityProvider.future);
  return ref.read(transferRecoveryServiceProvider).reconcileOnBoot();
});

final transferFileSelectorProvider = Provider<TransferFileSelector>((ref) {
  return const FilePickerTransferFileSelector();
});

final transferDraftValidatorProvider = Provider<TransferDraftValidator>((ref) {
  final environment = ref.watch(appEnvironmentProvider);
  return TransferDraftValidator(
    maxFilesPerBatch: environment.maxFilesPerBatch,
    maxFileSizeBytes: environment.maxFileSizeBytes,
    maxBatchSizeBytes: environment.maxBatchSizeBytes,
  );
});

final transferBatchesProvider = StreamProvider<List<TransferBatch>>((ref) {
  return ref.watch(transferRepositoryProvider).watchBatches();
});

final transferDraftComposerProvider =
    NotifierProvider<
      TransferDraftComposerController,
      TransferDraftComposerState
    >(TransferDraftComposerController.new);

@immutable
class TransferDraftComposerState {
  const TransferDraftComposerState({
    this.selectedFiles = const <TransferFile>[],
    this.networkPolicy = NetworkPolicy.confirmOnMetered,
    this.isPickingFiles = false,
    this.isCreatingDraft = false,
    this.errorMessage,
    this.createdBatchId,
  });

  final List<TransferFile> selectedFiles;
  final NetworkPolicy networkPolicy;
  final bool isPickingFiles;
  final bool isCreatingDraft;
  final String? errorMessage;
  final String? createdBatchId;

  bool get hasSelection => selectedFiles.isNotEmpty;

  int get totalSelectedBytes {
    return selectedFiles.fold<int>(0, (sum, file) => sum + file.byteCount);
  }

  TransferDraftComposerState copyWith({
    List<TransferFile>? selectedFiles,
    NetworkPolicy? networkPolicy,
    bool? isPickingFiles,
    bool? isCreatingDraft,
    Object? errorMessage = _transferDraftStateSentinel,
    Object? createdBatchId = _transferDraftStateSentinel,
  }) {
    return TransferDraftComposerState(
      selectedFiles: selectedFiles ?? this.selectedFiles,
      networkPolicy: networkPolicy ?? this.networkPolicy,
      isPickingFiles: isPickingFiles ?? this.isPickingFiles,
      isCreatingDraft: isCreatingDraft ?? this.isCreatingDraft,
      errorMessage: errorMessage == _transferDraftStateSentinel
          ? this.errorMessage
          : errorMessage as String?,
      createdBatchId: createdBatchId == _transferDraftStateSentinel
          ? this.createdBatchId
          : createdBatchId as String?,
    );
  }
}

const Object _transferDraftStateSentinel = Object();

class TransferDraftComposerController
    extends Notifier<TransferDraftComposerState> {
  @override
  TransferDraftComposerState build() {
    return const TransferDraftComposerState();
  }

  Future<void> pickFiles() async {
    state = state.copyWith(
      isPickingFiles: true,
      errorMessage: null,
      createdBatchId: null,
    );

    try {
      final selectedFiles = await ref
          .read(transferFileSelectorProvider)
          .pickFiles();
      if (selectedFiles.isEmpty) {
        state = state.copyWith(isPickingFiles: false);
        return;
      }

      final mergedFiles = _mergeSelectedFiles(
        state.selectedFiles,
        selectedFiles,
      );
      ref.read(transferDraftValidatorProvider).validateOrThrow(mergedFiles);

      state = state.copyWith(
        isPickingFiles: false,
        selectedFiles: mergedFiles,
        errorMessage: null,
      );
    } on AppException catch (error) {
      state = state.copyWith(
        isPickingFiles: false,
        errorMessage: error.message,
      );
    } on Object catch (error) {
      state = state.copyWith(
        isPickingFiles: false,
        errorMessage: error.toString(),
      );
    }
  }

  void removeSelectedFile(String fileId) {
    state = state.copyWith(
      selectedFiles: state.selectedFiles
          .where((file) => file.id != fileId)
          .toList(growable: false),
      errorMessage: null,
      createdBatchId: null,
    );
  }

  void clearSelection() {
    state = state.copyWith(
      selectedFiles: const <TransferFile>[],
      errorMessage: null,
      createdBatchId: null,
    );
  }

  void updateNetworkPolicy(NetworkPolicy networkPolicy) {
    state = state.copyWith(
      networkPolicy: networkPolicy,
      errorMessage: null,
      createdBatchId: null,
    );
  }

  Future<void> createDraft({required Recipient recipient}) async {
    state = state.copyWith(
      isCreatingDraft: true,
      errorMessage: null,
      createdBatchId: null,
    );

    try {
      ref
          .read(transferDraftValidatorProvider)
          .validateOrThrow(state.selectedFiles);
      final batchId = await ref
          .read(transferRepositoryProvider)
          .createDraft(
            recipient: recipient,
            files: state.selectedFiles,
            networkPolicy: state.networkPolicy,
          );

      state = state.copyWith(
        isCreatingDraft: false,
        selectedFiles: const <TransferFile>[],
        errorMessage: null,
        createdBatchId: batchId,
      );
    } on AppException catch (error) {
      state = state.copyWith(
        isCreatingDraft: false,
        errorMessage: error.message,
      );
    } on Object catch (error) {
      state = state.copyWith(
        isCreatingDraft: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> cancelBatch(String batchId) {
    return ref.read(transferRepositoryProvider).cancelBatch(batchId);
  }

  List<TransferFile> _mergeSelectedFiles(
    List<TransferFile> existingFiles,
    List<TransferFile> incomingFiles,
  ) {
    final mergedFiles = <String, TransferFile>{};
    for (final file in <TransferFile>[...existingFiles, ...incomingFiles]) {
      mergedFiles[file.sourceKey] = file;
    }
    return mergedFiles.values.toList(growable: false);
  }
}
