import 'package:flutter/foundation.dart';
import 'package:neo_sapien/core/errors/app_exception.dart';
import 'package:neo_sapien/core/firebase/firebase_runtime_options.dart';

@immutable
class AppEnvironment {
  const AppEnvironment({
    required this.relayBaseUrl,
    required this.transferTtl,
    required this.maxFileSizeBytes,
    required this.maxBatchSizeBytes,
    required this.maxFilesPerBatch,
    required this.meteredWarningThresholdBytes,
    required this.firebase,
  });

  /// Reads dart-defines into an [AppEnvironment].
  ///
  /// Every `String.fromEnvironment` call below MUST take a compile-time
  /// string literal as its name. Wrapping in a helper `(String key)` breaks
  /// dart-define resolution at runtime — `key` is a non-const parameter by
  /// the time the call executes, and Dart silently returns the default.
  factory AppEnvironment.fromDartDefines() {
    const relayBaseUrl = String.fromEnvironment(
      'RELAY_BASE_URL',
      defaultValue: 'https://relay.example.com',
    );
    const transferTtlHoursRaw = String.fromEnvironment(
      'TRANSFER_TTL_HOURS',
      defaultValue: '24',
    );
    const maxFileSizeBytesRaw = String.fromEnvironment(
      'MAX_FILE_SIZE_BYTES',
      defaultValue: '524288000',
    );
    const maxBatchSizeBytesRaw = String.fromEnvironment(
      'MAX_BATCH_SIZE_BYTES',
      defaultValue: '1073741824',
    );
    const maxFilesPerBatchRaw = String.fromEnvironment(
      'MAX_FILES_PER_BATCH',
      defaultValue: '20',
    );
    const meteredWarningRaw = String.fromEnvironment(
      'METERED_WARNING_THRESHOLD_BYTES',
      defaultValue: '52428800',
    );

    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const androidApiKey = String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
    const iosApiKey = String.fromEnvironment('FIREBASE_IOS_API_KEY');
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    const messagingSenderId = String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
    );
    const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
    const androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
    const iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
    const iosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');

    return AppEnvironment(
      relayBaseUrl: _validatedUri(
        relayBaseUrl,
        keyName: 'RELAY_BASE_URL',
      ).toString(),
      transferTtl: Duration(
        hours: _parseInt(transferTtlHoursRaw, keyName: 'TRANSFER_TTL_HOURS'),
      ),
      maxFileSizeBytes: _parseInt(
        maxFileSizeBytesRaw,
        keyName: 'MAX_FILE_SIZE_BYTES',
      ),
      maxBatchSizeBytes: _parseInt(
        maxBatchSizeBytesRaw,
        keyName: 'MAX_BATCH_SIZE_BYTES',
      ),
      maxFilesPerBatch: _parseInt(
        maxFilesPerBatchRaw,
        keyName: 'MAX_FILES_PER_BATCH',
      ),
      meteredWarningThresholdBytes: _parseInt(
        meteredWarningRaw,
        keyName: 'METERED_WARNING_THRESHOLD_BYTES',
      ),
      firebase: FirebaseRuntimeOptions(
        apiKey: _nullIfEmpty(apiKey),
        androidApiKey: _nullIfEmpty(androidApiKey),
        iosApiKey: _nullIfEmpty(iosApiKey),
        projectId: _nullIfEmpty(projectId),
        messagingSenderId: _nullIfEmpty(messagingSenderId),
        storageBucket: _nullIfEmpty(storageBucket),
        androidAppId: _nullIfEmpty(androidAppId),
        iosAppId: _nullIfEmpty(iosAppId),
        iosBundleId: _nullIfEmpty(iosBundleId),
      ),
    );
  }

  static final AppEnvironment current = AppEnvironment.fromDartDefines();

  final String relayBaseUrl;
  final Duration transferTtl;
  final int maxFileSizeBytes;
  final int maxBatchSizeBytes;
  final int maxFilesPerBatch;
  final int meteredWarningThresholdBytes;
  final FirebaseRuntimeOptions firebase;

  static int _parseInt(String raw, {required String keyName}) {
    final parsed = int.tryParse(raw);
    if (parsed == null) {
      throw ConfigurationException('Invalid integer for $keyName: "$raw".');
    }
    return parsed;
  }

  static String? _nullIfEmpty(String value) {
    return value.isEmpty ? null : value;
  }

  static Uri _validatedUri(String value, {required String keyName}) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw ConfigurationException('Invalid URI for $keyName: "$value".');
    }

    return uri;
  }
}
