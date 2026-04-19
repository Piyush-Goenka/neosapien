import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sapien/features/transfers/data/services/received_transfer_file_store.dart';

void main() {
  test(
    'creates deterministic conflict-safe target paths inside the batch folder',
    () async {
      final rootDirectory = await Directory.systemTemp.createTemp(
        'neo_sapien_received_store_test',
      );
      addTearDown(() async {
        if (await rootDirectory.exists()) {
          await rootDirectory.delete(recursive: true);
        }
      });

      final store = ReceivedTransferFileStore(
        rootDirectoryResolver: () async => rootDirectory,
      );

      final firstTarget = await store.createTargetFile(
        batchId: 'batch-001',
        fileName: 'photo.heic',
      );
      await firstTarget.create(recursive: true);

      final secondTarget = await store.createTargetFile(
        batchId: 'batch-001',
        fileName: 'photo.heic',
      );

      expect(
        secondTarget.path,
        endsWith('neo_sapien_received/batch-001/photo (2).heic'),
      );
    },
  );

  test('sanitizes path separators in incoming file names', () async {
    final rootDirectory = await Directory.systemTemp.createTemp(
      'neo_sapien_received_store_sanitize_test',
    );
    addTearDown(() async {
      if (await rootDirectory.exists()) {
        await rootDirectory.delete(recursive: true);
      }
    });

    final store = ReceivedTransferFileStore(
      rootDirectoryResolver: () async => rootDirectory,
    );

    final target = await store.createTargetFile(
      batchId: 'batch-002',
      fileName: 'nested/path\\\\clip.mov',
    );

    expect(
      target.path,
      endsWith('neo_sapien_received/batch-002/nested_path__clip.mov'),
    );
  });
}
