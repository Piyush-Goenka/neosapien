import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:neo_sapien/app/router/app_section.dart';
import 'package:neo_sapien/features/home/presentation/screens/dashboard_screen.dart';
import 'package:neo_sapien/features/inbox/presentation/screens/inbox_screen.dart';
import 'package:neo_sapien/features/profile/presentation/screens/profile_screen.dart';
import 'package:neo_sapien/features/send/presentation/screens/send_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppSection.dashboard.path,
    routes: <RouteBase>[
      GoRoute(
        path: AppSection.dashboard.path,
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: AppSection.send.path,
        builder: (context, state) => const SendScreen(),
      ),
      GoRoute(
        path: AppSection.inbox.path,
        builder: (context, state) => const InboxScreen(),
      ),
      GoRoute(
        path: AppSection.profile.path,
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
});
