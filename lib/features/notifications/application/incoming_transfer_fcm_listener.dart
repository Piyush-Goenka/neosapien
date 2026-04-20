import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:neo_sapien/features/notifications/application/incoming_transfer_event_bus.dart';
import 'package:neo_sapien/features/notifications/data/services/local_notification_service.dart';
import 'package:neo_sapien/features/notifications/domain/incoming_transfer_event.dart';

/// Wires FCM message streams and cold-launch state into the app-wide
/// [IncomingTransferEventBus]. Separates Firebase-specific wiring from the
/// UI-facing event consumers.
class IncomingTransferFcmListener {
  IncomingTransferFcmListener({
    required FirebaseMessaging messaging,
    required IncomingTransferEventBus eventBus,
    required LocalNotificationService localNotifications,
  }) : _messaging = messaging,
       _eventBus = eventBus,
       _localNotifications = localNotifications;

  final FirebaseMessaging _messaging;
  final IncomingTransferEventBus _eventBus;
  final LocalNotificationService _localNotifications;

  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;
  bool _initialMessageConsumed = false;

  Future<void> start() async {
    await _localNotifications.initialize();
    await _consumeInitialMessage();
    _foregroundSub ??= FirebaseMessaging.onMessage.listen(_handleForeground);
    _openedAppSub ??= FirebaseMessaging.onMessageOpenedApp.listen(
      _handleOpenedApp,
    );
  }

  Future<void> stop() async {
    await _foregroundSub?.cancel();
    await _openedAppSub?.cancel();
    _foregroundSub = null;
    _openedAppSub = null;
  }

  Future<void> _consumeInitialMessage() async {
    if (_initialMessageConsumed) return;
    _initialMessageConsumed = true;
    try {
      final initial = await _messaging.getInitialMessage();
      if (initial != null) {
        final event = _toEvent(
          initial,
          IncomingTransferEventOrigin.coldLaunchNotification,
        );
        if (event != null) {
          _eventBus.emit(event);
        }
      }
    } on Object {
      // Ignore — cold-launch fetch is best-effort.
    }
  }

  Future<void> _handleForeground(RemoteMessage message) async {
    final batchId = message.data['batchId'];
    if (batchId is! String || batchId.isEmpty) {
      return;
    }

    final senderCode = message.data['senderCode'] as String?;
    final fileCountRaw = message.data['fileCount'];
    final fileCount = fileCountRaw is String
        ? int.tryParse(fileCountRaw)
        : null;

    await _localNotifications.showIncomingTransfer(
      batchId: batchId,
      senderCode: senderCode,
      fileCount: fileCount,
    );

    _eventBus.emit(
      IncomingTransferEvent(
        batchId: batchId,
        origin: IncomingTransferEventOrigin.foregroundMessage,
        senderCode: senderCode,
        fileCount: fileCount,
      ),
    );
  }

  void _handleOpenedApp(RemoteMessage message) {
    final event = _toEvent(
      message,
      IncomingTransferEventOrigin.notificationTap,
    );
    if (event != null) {
      _eventBus.emit(event);
    }
  }

  IncomingTransferEvent? _toEvent(
    RemoteMessage message,
    IncomingTransferEventOrigin origin,
  ) {
    final batchId = message.data['batchId'];
    if (batchId is! String || batchId.isEmpty) {
      return null;
    }
    final senderCode = message.data['senderCode'] as String?;
    final fileCountRaw = message.data['fileCount'];
    final fileCount = fileCountRaw is String
        ? int.tryParse(fileCountRaw)
        : null;

    return IncomingTransferEvent(
      batchId: batchId,
      origin: origin,
      senderCode: senderCode,
      fileCount: fileCount,
    );
  }
}
