import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sapien/features/recipients/domain/entities/recipient.dart';
import 'package:neo_sapien/features/transfers/application/transfer_batch_action_controller.dart';
import 'package:neo_sapien/features/transfers/application/transfer_draft_controller.dart';
import 'package:neo_sapien/features/transfers/domain/entities/network_policy.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_batch.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_file.dart';
import 'package:neo_sapien/features/transfers/domain/repositories/transfer_repository.dart';
import 'package:neo_sapien/features/transfers/domain/services/transfer_engine.dart';

void main() {
  test('accepts an incoming batch through the repository', () async {
    final repository = _FakeTransferRepository();
    final engine = _FakeTransferEngine();
    final container = ProviderContainer(
      overrides: [
        transferRepositoryProvider.overrideWithValue(repository),
        transferEngineProvider.overrideWithValue(engine),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      transferBatchActionControllerProvider.notifier,
    );

    await controller.accept('batch-001');

    expect(repository.acceptedBatchIds, <String>['batch-001']);
    expect(
      container.read(transferBatchActionControllerProvider).errorMessage,
      isNull,
    );
  });

  test('starts upload through the transfer engine', () async {
    final repository = _FakeTransferRepository();
    final engine = _FakeTransferEngine();
    final container = ProviderContainer(
      overrides: [
        transferRepositoryProvider.overrideWithValue(repository),
        transferEngineProvider.overrideWithValue(engine),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      transferBatchActionControllerProvider.notifier,
    );

    await controller.startUpload('batch-002');

    expect(engine.enqueuedBatchIds, <String>['batch-002']);
    expect(
      container.read(transferBatchActionControllerProvider).errorMessage,
      isNull,
    );
  });

  test('starts download through the transfer engine', () async {
    final repository = _FakeTransferRepository();
    final engine = _FakeTransferEngine();
    final container = ProviderContainer(
      overrides: [
        transferRepositoryProvider.overrideWithValue(repository),
        transferEngineProvider.overrideWithValue(engine),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      transferBatchActionControllerProvider.notifier,
    );

    await controller.download('batch-003');

    expect(engine.enqueuedBatchIds, <String>['batch-003']);
    expect(
      container.read(transferBatchActionControllerProvider).errorMessage,
      isNull,
    );
  });
}

final class _FakeTransferRepository implements TransferRepository {
  final List<String> acceptedBatchIds = <String>[];
  final StreamController<List<TransferBatch>> _controller =
      StreamController<List<TransferBatch>>.broadcast();

  @override
  Future<void> acceptBatch(String batchId) async {
    acceptedBatchIds.add(batchId);
  }

  @override
  Future<void> cancelBatch(String batchId) async {}

  @override
  Future<String> createDraft({
    required Recipient recipient,
    required List<TransferFile> files,
    required NetworkPolicy networkPolicy,
  }) async {
    return 'draft-001';
  }

  @override
  Future<TransferBatch?> getBatch(String batchId) async {
    return null;
  }

  @override
  Future<void> rejectBatch(String batchId) async {}

  @override
  Stream<List<TransferBatch>> watchBatches() async* {
    yield const <TransferBatch>[];
    yield* _controller.stream;
  }
}

final class _FakeTransferEngine implements TransferEngine {
  final List<String> enqueuedBatchIds = <String>[];
  final List<String> cancelledBatchIds = <String>[];

  @override
  Future<void> cancel(String batchId) async {
    cancelledBatchIds.add(batchId);
  }

  @override
  Future<void> enqueue(String batchId) async {
    enqueuedBatchIds.add(batchId);
  }

  @override
  Future<void> pause(String batchId) async {}

  @override
  Future<void> resume(String batchId) async {}
}
