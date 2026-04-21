import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neo_sapien/app/bootstrap.dart';
import 'package:neo_sapien/core/config/app_environment.dart';

/// Top-level FCM handler invoked by the plugin when the app is backgrounded
/// or terminated. The Cloud Function already ships a `notification` payload,
/// so the OS shows the banner and plays the sound without us doing anything.
/// This entry point exists so the plugin can process the data payload when
/// the app is in background — we intentionally keep it minimal to avoid
/// work on a cold isolate.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase in the background isolate if not already done.
  final options = AppEnvironment.current.firebase.currentPlatformOptions;
  if (options == null) {
    return;
  }
  try {
    await Firebase.initializeApp(options: options);
  } on Object {
    // If init races with the foreground isolate, ignore — the OS still
    // renders the notification from the payload.
  }
  // No further action; tap routing is handled by onMessageOpenedApp /
  // getInitialMessage in the foreground isolate.
  message.messageId;
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Runtime diagnostic — logged once at startup to confirm dart-defines reached
  // the app. Safe to keep during development; remove for a release build.
  final env = AppEnvironment.current;
  // ignore: avoid_print
  print(
    '[NeoSapien boot] projectId=${env.firebase.projectId} '
    'senderId=${env.firebase.messagingSenderId} '
    'androidApp=${env.firebase.androidAppId != null} '
    'iosApp=${env.firebase.iosAppId != null} '
    'androidKey=${env.firebase.androidApiKey != null} '
    'iosKey=${env.firebase.iosApiKey != null} '
    'sharedKey=${env.firebase.apiKey != null}',
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const ProviderScope(child: NeoSapienBootstrap()));
}
