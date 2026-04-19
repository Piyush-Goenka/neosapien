import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sapien/core/config/app_environment.dart';
import 'package:neo_sapien/core/firebase/firebase_runtime_options.dart';
import 'package:neo_sapien/core/providers/app_environment_provider.dart';
import 'package:neo_sapien/features/recipients/domain/value_objects/recipient_code.dart';
import 'package:neo_sapien/features/transfers/application/transfer_draft_controller.dart';
import 'package:neo_sapien/features/transfers/domain/entities/network_policy.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_batch.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_direction.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_file.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_file_status.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_status.dart';
import 'package:neo_sapien/features/transfers/domain/repositories/transfer_repository.dart';
import 'package:neo_sapien/features/transfers/domain/services/transfer_file_selector.dart';

void main() {
  test('picks files and creates a local transfer draft', () async {
    final repository = _FakeTransferRepository();
    final container = ProviderContainer(
      overrides: [
        appEnvironmentProvider.overrideWithValue(_testEnvironment()),
        transferFileSelectorProvider.overrideWithValue(
          _FakeTransferFileSelector(
            <TransferFile>[
              const TransferFile(
                id: 'file-a',
                name: 'photo.heic',
                byteCount: 120,
                status: TransferFileStatus.pending,
                mimeType: 'image/heic',
                localPath: '/tmp/photo.heic',
              ),
            ],
          ),
        ),
        transferRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(transferDraftComposerProvider.notifier);

    await controller.pickFiles();
    var state = container.read(transferDraftComposerProvider);
    expect(state.selectedFiles, hasLength(1));
    expect(state.totalSelectedBytes, 120);

    controller.updateNetworkPolicy(NetworkPolicy.wifiOnly);
    await controller.createDraft(
      recipientCode: RecipientCode.fromRaw('WXYZ2345'),
    );

    state = container.read(transferDraftComposerProvider);
    expect(state.selectedFiles, isEmpty);
    expect(state.createdBatchId, 'draft-001');
    expect(repository.createdBatches, hasLength(1));
    expect(repository.createdBatches.single.networkPolicy, NetworkPolicy.wifiOnly);
    expect(
      repository.createdBatches.single.recipientCode?.normalizedValue,
      'WXYZ2345',
    );
  });
}

AppEnvironment _testEnvironment() {
  return const AppEnvironment(
    relayBaseUrl: 'https://relay.example.com',
    transferTtl: Duration(hours: 24),
    maxFileSizeBytes: 500 * 1024 * 1024,
    maxBatchSizeBytes: 1024 * 1024 * 1024,
    maxFilesPerBatch: 20,
    meteredWarningThresholdBytes: 50 * 1024 * 1024,
    firebase: FirebaseRuntimeOptions(
      apiKey: null,
      projectId: null,
      messagingSenderId: null,
      storageBucket: null,
      androidAppId: null,
      iosAppId: null,
      iosBundleId: null,
    ),
  );
}

final class _FakeTransferFileSelector implements TransferFileSelector {
  _FakeTransferFileSelector(this._files);

  final List<TransferFile> _files;

  @override
  Future<List<TransferFile>> pickFiles() async {
    return _files;
  }
}

final class _FakeTransferRepository implements TransferRepository {
  final List<TransferBatch> createdBatches = <TransferBatch>[];
  final StreamController<List<TransferBatch>> _controller =
      StreamController<List<TransferBatch>>.broadcast();

  @override
  Future<void> cancelBatch(String batchId) async {}

  @override
  Future<String> createDraft({
    required RecipientCode recipientCode,
    required List<TransferFile> files,
    required NetworkPolicy networkPolicy,
  }) async {
    createdBatches.add(
      TransferBatch(
        id: 'draft-001',
        direction: TransferDirection.outgoing,
        status: TransferStatus.draft,
        files: files,
        createdAt: DateTime.utc(2026, 4, 19),
        networkPolicy: networkPolicy,
        recipientCode: recipientCode,
        totalBytes: files.fold<int>(0, (sum, file) => sum + file.byteCount),
      ),
    );
    _controller.add(createdBatches);
    return 'draft-001';
  }

  @override
  Stream<List<TransferBatch>> watchBatches() async* {
    yield createdBatches;
    yield* _controller.stream;
  }
}
