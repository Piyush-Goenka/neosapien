import 'package:neo_sapien/core/errors/app_exception.dart';
import 'package:neo_sapien/core/utils/byte_count_formatter.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_file.dart';

class TransferDraftValidator {
  const TransferDraftValidator({
    required this.maxFilesPerBatch,
    required this.maxFileSizeBytes,
    required this.maxBatchSizeBytes,
  });

  final int maxFilesPerBatch;
  final int maxFileSizeBytes;
  final int maxBatchSizeBytes;

  void validateOrThrow(List<TransferFile> files) {
    if (files.isEmpty) {
      throw const TransferDraftException('Select at least one file to continue.');
    }

    if (files.length > maxFilesPerBatch) {
      throw TransferDraftException(
        'Select up to $maxFilesPerBatch files per batch.',
      );
    }

    var totalBytes = 0;
    for (final file in files) {
      if (!file.canReadSource) {
        throw TransferDraftException(
          'The file "${file.name}" could not be prepared for upload. '
          'Pick it again from a local provider and try once more.',
        );
      }

      if (file.byteCount < 0) {
        throw TransferDraftException(
          'The file "${file.name}" reported an invalid size.',
        );
      }

      if (file.byteCount > maxFileSizeBytes) {
        throw TransferDraftException(
          '"${file.name}" is ${ByteCountFormatter.format(file.byteCount)}. '
          'The current per-file limit is '
          '${ByteCountFormatter.format(maxFileSizeBytes)}.',
        );
      }

      totalBytes += file.byteCount;
    }

    if (totalBytes > maxBatchSizeBytes) {
      throw TransferDraftException(
        'This batch totals ${ByteCountFormatter.format(totalBytes)}. '
        'The current batch limit is '
        '${ByteCountFormatter.format(maxBatchSizeBytes)}.',
      );
    }
  }
}
