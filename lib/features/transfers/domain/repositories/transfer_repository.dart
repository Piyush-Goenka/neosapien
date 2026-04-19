import 'package:neo_sapien/features/recipients/domain/entities/recipient.dart';
import 'package:neo_sapien/features/transfers/domain/entities/network_policy.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_batch.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_file.dart';

abstract interface class TransferRepository {
  Stream<List<TransferBatch>> watchBatches();

  Future<String> createDraft({
    required Recipient recipient,
    required List<TransferFile> files,
    required NetworkPolicy networkPolicy,
  });

  Future<void> cancelBatch(String batchId);

  Future<void> acceptBatch(String batchId);

  Future<void> rejectBatch(String batchId);
}
