import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

@immutable
class FirebaseRuntimeOptions {
  const FirebaseRuntimeOptions({
    required this.apiKey,
    required this.projectId,
    required this.messagingSenderId,
    required this.storageBucket,
    required this.androidAppId,
    required this.iosAppId,
    required this.iosBundleId,
    this.androidApiKey,
    this.iosApiKey,
  });

  final String? apiKey;
  final String? projectId;
  final String? messagingSenderId;
  final String? storageBucket;
  final String? androidAppId;
  final String? iosAppId;
  final String? iosBundleId;
  final String? androidApiKey;
  final String? iosApiKey;

  FirebaseOptions? get currentPlatformOptions {
    final sharedProjectId = projectId;
    final sharedMessagingSenderId = messagingSenderId;

    if (sharedProjectId == null || sharedMessagingSenderId == null) {
      return null;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final appId = androidAppId;
        final platformApiKey = androidApiKey ?? apiKey;
        if (appId == null || platformApiKey == null) {
          return null;
        }
        return FirebaseOptions(
          apiKey: platformApiKey,
          appId: appId,
          messagingSenderId: sharedMessagingSenderId,
          projectId: sharedProjectId,
          storageBucket: storageBucket,
        );
      case TargetPlatform.iOS:
        final appId = iosAppId;
        final bundleId = iosBundleId;
        final platformApiKey = iosApiKey ?? apiKey;
        if (appId == null || bundleId == null || platformApiKey == null) {
          return null;
        }
        return FirebaseOptions(
          apiKey: platformApiKey,
          appId: appId,
          messagingSenderId: sharedMessagingSenderId,
          projectId: sharedProjectId,
          storageBucket: storageBucket,
          iosBundleId: bundleId,
        );
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return null;
    }
  }

  bool get isConfiguredForCurrentPlatform => currentPlatformOptions != null;

  String get missingConfigurationHint {
    final missingKeys = <String>[
      if (apiKey == null && androidApiKey == null && iosApiKey == null)
        'FIREBASE_API_KEY (or FIREBASE_ANDROID_API_KEY + FIREBASE_IOS_API_KEY)',
      if (projectId == null) 'FIREBASE_PROJECT_ID',
      if (messagingSenderId == null) 'FIREBASE_MESSAGING_SENDER_ID',
      ..._platformSpecificMissingKeys(),
    ];

    return missingKeys.join(', ');
  }

  List<String> _platformSpecificMissingKeys() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return <String>[if (androidAppId == null) 'FIREBASE_ANDROID_APP_ID'];
      case TargetPlatform.iOS:
        return <String>[
          if (iosAppId == null) 'FIREBASE_IOS_APP_ID',
          if (iosBundleId == null) 'FIREBASE_IOS_BUNDLE_ID',
        ];
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return <String>[
          'Firebase runtime bootstrap currently supports Android and iOS only',
        ];
    }
  }
}
