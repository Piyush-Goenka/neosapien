import 'package:flutter/material.dart';

enum AppSection {
  dashboard(label: 'Home', path: '/', icon: Icons.space_dashboard_rounded),
  send(label: 'Send', path: '/send', icon: Icons.send_rounded),
  inbox(label: 'Inbox', path: '/inbox', icon: Icons.inbox_rounded),
  profile(label: 'Profile', path: '/profile', icon: Icons.person_rounded);

  const AppSection({
    required this.label,
    required this.path,
    required this.icon,
  });

  final String label;
  final String path;
  final IconData icon;
}
