import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neo_sapien/app/router/app_router.dart';
import 'package:neo_sapien/app/theme/app_theme.dart';
import 'package:neo_sapien/features/notifications/application/incoming_transfer_event_bus.dart';
import 'package:neo_sapien/features/notifications/application/notification_bootstrap.dart';
import 'package:neo_sapien/features/notifications/domain/incoming_transfer_event.dart';
import 'package:neo_sapien/features/transfers/application/transfer_draft_controller.dart';

class NeoSapienApp extends ConsumerWidget {
  const NeoSapienApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    // Fire one-shot boot side effects.
    ref.watch(transferRecoveryBootProvider);
    ref.watch(notificationBootProvider);

    // Deep link: any incoming-transfer event routes the user to the inbox
    // with the batch id carried as a query param so the inbox can highlight.
    ref.listen<AsyncValue<IncomingTransferEvent>>(
      incomingTransferEventStreamProvider,
      (previous, next) {
        final event = next.whenOrNull(data: (value) => value);
        if (event == null) {
          return;
        }
        if (event.origin == IncomingTransferEventOrigin.foregroundMessage) {
          // Foreground already raises a local notification; don't steal
          // the user's current screen on its own.
          return;
        }
        router.go('/inbox?batch=${event.batchId}');
      },
    );

    return MaterialApp.router(
      title: 'NeoSapien',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
