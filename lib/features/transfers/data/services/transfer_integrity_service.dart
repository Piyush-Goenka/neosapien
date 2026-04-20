import 'dart:io';

import 'package:crypto/crypto.dart';

/// Streaming SHA-256 helper for transfer integrity verification.
///
/// Reads bytes in fixed-size chunks from disk rather than loading the entire
/// file, so it is safe to invoke on files up to the configured per-file
/// ceiling without risking OOM on mobile devices.
class TransferIntegrityService {
  const TransferIntegrityService();

  Future<String> computeSha256(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }
}
