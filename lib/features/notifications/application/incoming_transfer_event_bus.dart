import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neo_sapien/features/notifications/domain/incoming_transfer_event.dart';

/// App-wide single-emitter bus for incoming-transfer events.
///
/// FCM foreground handlers, local-notification tap handlers, and cold-launch
/// initial-message handlers all push through here. Consumers (router deep
/// link, inbox badge) subscribe via Riverpod.
class IncomingTransferEventBus {
  IncomingTransferEventBus();

  final StreamController<IncomingTransferEvent> _controller =
      StreamController<IncomingTransferEvent>.broadcast();

  Stream<IncomingTransferEvent> get stream => _controller.stream;

  void emit(IncomingTransferEvent event) {
    if (_controller.isClosed) {
      return;
    }
    _controller.add(event);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

final incomingTransferEventBusProvider =
    Provider<IncomingTransferEventBus>((ref) {
      final bus = IncomingTransferEventBus();
      ref.onDispose(bus.dispose);
      return bus;
    });

final incomingTransferEventStreamProvider =
    StreamProvider<IncomingTransferEvent>((ref) {
      return ref.watch(incomingTransferEventBusProvider).stream;
    });
