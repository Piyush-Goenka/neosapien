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

  factory AppEnvironment.fromDartDefines() {
    final relayBaseUrl = String.fromEnvironment(
      'RELAY_BASE_URL',
      defaultValue: 'https://relay.example.com',
    );

    return AppEnvironment(
      relayBaseUrl: _validatedUri(
        relayBaseUrl,
        keyName: 'RELAY_BASE_URL',
      ).toString(),
      transferTtl: Duration(
        hours: _intFromDefine('TRANSFER_TTL_HOURS', fallback: 24),
      ),
      maxFileSizeBytes: _intFromDefine(
        'MAX_FILE_SIZE_BYTES',
        fallback: 500 * 1024 * 1024,
      ),
      maxBatchSizeBytes: _intFromDefine(
        'MAX_BATCH_SIZE_BYTES',
        fallback: 1024 * 1024 * 1024,
      ),
      maxFilesPerBatch: _intFromDefine('MAX_FILES_PER_BATCH', fallback: 20),
      meteredWarningThresholdBytes: _intFromDefine(
        'METERED_WARNING_THRESHOLD_BYTES',
        fallback: 50 * 1024 * 1024,
      ),
      firebase: FirebaseRuntimeOptions(
        apiKey: _optionalStringFromDefine('FIREBASE_API_KEY'),
        projectId: _optionalStringFromDefine('FIREBASE_PROJECT_ID'),
        messagingSenderId: _optionalStringFromDefine(
          'FIREBASE_MESSAGING_SENDER_ID',
        ),
        storageBucket: _optionalStringFromDefine('FIREBASE_STORAGE_BUCKET'),
        androidAppId: _optionalStringFromDefine('FIREBASE_ANDROID_APP_ID'),
        iosAppId: _optionalStringFromDefine('FIREBASE_IOS_APP_ID'),
        iosBundleId: _optionalStringFromDefine('FIREBASE_IOS_BUNDLE_ID'),
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

  static int _intFromDefine(String key, {required int fallback}) {
    final value = String.fromEnvironment(key, defaultValue: '');
    if (value.isEmpty) {
      return fallback;
    }

    final parsed = int.tryParse(value);
    if (parsed == null) {
      throw ConfigurationException('Invalid integer for $key: "$value".');
    }

    return parsed;
  }

  static String? _optionalStringFromDefine(String key) {
    final value = String.fromEnvironment(key, defaultValue: '');
    if (value.isEmpty) {
      return null;
    }

    return value;
  }

  static Uri _validatedUri(String value, {required String keyName}) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw ConfigurationException('Invalid URI for $keyName: "$value".');
    }

    return uri;
  }
}
