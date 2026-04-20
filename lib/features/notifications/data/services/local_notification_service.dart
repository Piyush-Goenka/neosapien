import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:neo_sapien/features/notifications/application/incoming_transfer_event_bus.dart';
import 'package:neo_sapien/features/notifications/domain/incoming_transfer_event.dart';

/// Wraps `flutter_local_notifications` for the one notification we raise
/// ourselves: the foreground incoming-transfer banner. Background and
/// terminated-app notifications are auto-shown by FCM because the Cloud
/// Function sends a `notification` payload alongside the data payload.
class LocalNotificationService {
  LocalNotificationService({required IncomingTransferEventBus eventBus})
    : _eventBus = eventBus;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final IncomingTransferEventBus _eventBus;

  static const String incomingTransfersChannelId = 'incoming_transfers';
  static const String _incomingTransfersChannelName = 'Incoming transfers';
  static const String _incomingTransfersChannelDescription =
      'Notifies you when another device wants to send you files.';

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );

    if (Platform.isAndroid) {
      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidImpl?.createNotificationChannel(
        const AndroidNotificationChannel(
          incomingTransfersChannelId,
          _incomingTransfersChannelName,
          description: _incomingTransfersChannelDescription,
          importance: Importance.high,
        ),
      );
    }

    _initialized = true;
  }

  Future<void> showIncomingTransfer({
    required String batchId,
    String? senderCode,
    int? fileCount,
  }) async {
    await initialize();

    final title = 'Incoming file transfer';
    final body = _buildBody(senderCode: senderCode, fileCount: fileCount);

    const androidDetails = AndroidNotificationDetails(
      incomingTransfersChannelId,
      _incomingTransfersChannelName,
      channelDescription: _incomingTransfersChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      batchId.hashCode,
      title,
      body,
      details,
      payload: _encodePayload(
        batchId: batchId,
        senderCode: senderCode,
        fileCount: fileCount,
      ),
    );
  }

  String _buildBody({String? senderCode, int? fileCount}) {
    final who = (senderCode != null && senderCode.isNotEmpty)
        ? senderCode
        : 'Someone';
    if (fileCount == null || fileCount <= 1) {
      return '$who wants to send you a file.';
    }
    return '$who wants to send you $fileCount files.';
  }

  String _encodePayload({
    required String batchId,
    String? senderCode,
    int? fileCount,
  }) {
    final parts = <String>['batchId=$batchId'];
    if (senderCode != null && senderCode.isNotEmpty) {
      parts.add('senderCode=$senderCode');
    }
    if (fileCount != null) {
      parts.add('fileCount=$fileCount');
    }
    return parts.join('&');
  }

  Map<String, String> _decodePayload(String payload) {
    final decoded = <String, String>{};
    for (final part in payload.split('&')) {
      final eq = part.indexOf('=');
      if (eq <= 0) continue;
      decoded[part.substring(0, eq)] = part.substring(eq + 1);
    }
    return decoded;
  }

  void _handleNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) {
      return;
    }
    final decoded = _decodePayload(payload);
    final batchId = decoded['batchId'];
    if (batchId == null || batchId.isEmpty) {
      return;
    }
    _eventBus.emit(
      IncomingTransferEvent(
        batchId: batchId,
        origin: IncomingTransferEventOrigin.notificationTap,
        senderCode: decoded['senderCode'],
        fileCount: int.tryParse(decoded['fileCount'] ?? ''),
      ),
    );
  }
}
