import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neo_sapien/core/permissions/permission_gateway.dart';
import 'package:neo_sapien/core/providers/firebase_providers.dart';
import 'package:neo_sapien/core/providers/permission_providers.dart';
import 'package:neo_sapien/features/identity/application/identity_controller.dart';
import 'package:neo_sapien/features/notifications/application/incoming_transfer_event_bus.dart';
import 'package:neo_sapien/features/notifications/application/incoming_transfer_fcm_listener.dart';
import 'package:neo_sapien/features/notifications/data/services/fcm_token_registrar.dart';
import 'package:neo_sapien/features/notifications/data/services/local_notification_service.dart';
import 'package:neo_sapien/features/transfers/application/transfer_draft_controller.dart';

final localNotificationServiceProvider = Provider<LocalNotificationService>((
  ref,
) {
  return LocalNotificationService(
    eventBus: ref.watch(incomingTransferEventBusProvider),
  );
});

final fcmTokenRegistrarProvider = Provider<FcmTokenRegistrar>((ref) {
  return FcmTokenRegistrar(
    firestore: ref.watch(firebaseFirestoreProvider),
    messaging: ref.watch(firebaseMessagingProvider),
  );
});

final incomingTransferFcmListenerProvider =
    Provider<IncomingTransferFcmListener>((ref) {
      final listener = IncomingTransferFcmListener(
        messaging: ref.watch(firebaseMessagingProvider),
        eventBus: ref.watch(incomingTransferEventBusProvider),
        localNotifications: ref.watch(localNotificationServiceProvider),
      );
      ref.onDispose(listener.stop);
      return listener;
    });

/// One-shot boot sequence that:
///   1. Waits for identity + auth to be ready
///   2. Requests notification permission (best-effort)
///   3. Initializes local notifications
///   4. Registers the FCM token on users/{uid}/private/fcm
///   5. Starts listening for FCM foreground / opened-app / cold-launch events
///
/// Fires when watched from the app shell. Failures are swallowed so a
/// missing APNs key or denied permission does not block the app.
final notificationBootProvider = FutureProvider<void>((ref) async {
  final identity = await ref.watch(currentIdentityProvider.future);

  try {
    final permissionResult = await ref
        .read(permissionGatewayProvider)
        .ensureNotifications();
    if (permissionResult == PermissionOutcome.granted) {
      await ref.read(localNotificationServiceProvider).initialize();
      await ref.read(incomingTransferFcmListenerProvider).start();
    }

    // Token registration attempted independently — even without the local
    // notification permission, silent data pushes can still reach the app.
    final remoteContext = await ref
        .read(transferRemoteContextResolverProvider)
        .tryResolve();
    if (remoteContext != null) {
      await ref
          .read(fcmTokenRegistrarProvider)
          .registerForUser(currentUserUid: remoteContext.uid);
    }
  } on Object {
    // Best-effort; missing Firebase config / APNs key must not crash the app.
  }

  // Keep the ref so the linter doesn't warn.
  identity.shortCode;
});
