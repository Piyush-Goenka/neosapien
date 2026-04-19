import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sapien/core/errors/app_exception.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_file.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_file_status.dart';
import 'package:neo_sapien/features/transfers/domain/services/transfer_draft_validator.dart';

void main() {
  group('TransferDraftValidator', () {
    const validator = TransferDraftValidator(
      maxFilesPerBatch: 3,
      maxFileSizeBytes: 500,
      maxBatchSizeBytes: 900,
    );

    test('accepts zero-byte files when source metadata is valid', () {
      expect(
        () => validator.validateOrThrow(
          <TransferFile>[_file(name: 'empty.txt', bytes: 0)],
        ),
        returnsNormally,
      );
    });

    test('rejects files above the per-file limit', () {
      expect(
        () => validator.validateOrThrow(
          <TransferFile>[_file(name: 'movie.mov', bytes: 700)],
        ),
        throwsA(isA<TransferDraftException>()),
      );
    });

    test('rejects batches above the total size limit', () {
      expect(
        () => validator.validateOrThrow(
          <TransferFile>[
            _file(name: 'one.mp4', bytes: 450),
            _file(name: 'two.mp4', bytes: 460),
          ],
        ),
        throwsA(isA<TransferDraftException>()),
      );
    });

    test('rejects files that cannot be reopened for upload', () {
      expect(
        () => validator.validateOrThrow(
          <TransferFile>[
            const TransferFile(
              id: 'bad',
              name: 'cloud.bin',
              byteCount: 42,
              status: TransferFileStatus.pending,
            ),
          ],
        ),
        throwsA(isA<TransferDraftException>()),
      );
    });
  });
}

TransferFile _file({required String name, required int bytes}) {
  return TransferFile(
    id: name,
    name: name,
    byteCount: bytes,
    status: TransferFileStatus.pending,
    localPath: '/tmp/$name',
  );
}
