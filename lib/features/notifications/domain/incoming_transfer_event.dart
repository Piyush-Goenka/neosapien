import 'package:flutter/foundation.dart';

/// Event emitted when the user triggers or receives an incoming-transfer
/// signal (FCM data message in the foreground, or a notification tap from
/// background/cold launch).
///
/// Origin lets the UI react differently — a foreground event should surface
/// a toast; a `notificationTap` event should deep-link into the inbox.
enum IncomingTransferEventOrigin {
  foregroundMessage,
  notificationTap,
  coldLaunchNotification,
}

@immutable
class IncomingTransferEvent {
  const IncomingTransferEvent({
    required this.batchId,
    required this.origin,
    this.senderCode,
    this.fileCount,
  });

  final String batchId;
  final IncomingTransferEventOrigin origin;
  final String? senderCode;
  final int? fileCount;
}
