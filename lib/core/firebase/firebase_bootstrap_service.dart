import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:neo_sapien/core/config/app_environment.dart';

enum FirebaseBootstrapStatus { ready, unconfigured, failed }

@immutable
class FirebaseBootstrapState {
  const FirebaseBootstrapState._({
    required this.status,
    required this.message,
    this.error,
  });

  const FirebaseBootstrapState.ready()
    : this._(
        status: FirebaseBootstrapStatus.ready,
        message: 'Firebase is ready for the current platform.',
      );

  const FirebaseBootstrapState.unconfigured(String message)
    : this._(status: FirebaseBootstrapStatus.unconfigured, message: message);

  const FirebaseBootstrapState.failed(String message, {Object? error})
    : this._(
        status: FirebaseBootstrapStatus.failed,
        message: message,
        error: error,
      );

  final FirebaseBootstrapStatus status;
  final String message;
  final Object? error;

  bool get isReady => status == FirebaseBootstrapStatus.ready;
}

class FirebaseBootstrapService {
  FirebaseBootstrapService(this._environment);

  final AppEnvironment _environment;

  Future<FirebaseBootstrapState>? _initialization;

  Future<FirebaseBootstrapState> ensureInitialized() {
    return _initialization ??= _initialize();
  }

  Future<FirebaseBootstrapState> _initialize() async {
    final options = _environment.firebase.currentPlatformOptions;
    if (options == null) {
      return FirebaseBootstrapState.unconfigured(
        'Firebase runtime options are missing for this platform. '
        'Set: ${_environment.firebase.missingConfigurationHint}.',
      );
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: options);
      }

      return const FirebaseBootstrapState.ready();
    } on Object catch (error) {
      return FirebaseBootstrapState.failed(
        'Firebase failed to initialize. Verify the runtime configuration '
        'for the current platform.',
        error: error,
      );
    }
  }
}
