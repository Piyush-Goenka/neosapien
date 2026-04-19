import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:neo_sapien/app/router/app_section.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.currentSection,
    required this.title,
    required this.child,
    super.key,
    this.actions = const <Widget>[],
  });

  final AppSection currentSection;
  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: SafeArea(child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentSection.index,
        destinations: <Widget>[
          for (final section in AppSection.values)
            NavigationDestination(
              icon: Icon(section.icon),
              label: section.label,
            ),
        ],
        onDestinationSelected: (index) {
          final destination = AppSection.values[index];
          if (destination != currentSection) {
            context.go(destination.path);
          }
        },
      ),
    );
  }
}
