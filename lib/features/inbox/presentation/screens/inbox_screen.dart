import 'package:flutter/material.dart';
import 'package:neo_sapien/app/router/app_section.dart';
import 'package:neo_sapien/features/home/presentation/widgets/overview_card.dart';
import 'package:neo_sapien/shared/presentation/widgets/app_scaffold.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      currentSection: AppSection.inbox,
      title: 'Inbox',
      child: _InboxScreenBody(),
    );
  }
}

class _InboxScreenBody extends StatelessWidget {
  const _InboxScreenBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: const <Widget>[
        OverviewCard(
          eyebrow: 'Recipient experience',
          title:
              'Incoming transfer discovery is reserved for a dedicated inbox.',
          subtitle:
              'This surface will become the home for accept/reject, download '
              'progress, hash verification, and save-to-device actions.',
          children: <Widget>[
            _InboxRow(label: 'FCM notification deep links'),
            _InboxRow(label: 'Queued transfer acceptance with TTL visibility'),
            _InboxRow(label: 'Download progress and recovery after relaunch'),
          ],
        ),
        SizedBox(height: 16),
        OverviewCard(
          eyebrow: 'Failure handling',
          title:
              'Receiver-side resilience is designed into the contract early.',
          subtitle:
              'Low storage, permission denial, duplicate delivery, and save '
              'conflicts will surface here with explicit actions.',
          children: <Widget>[
            _InboxRow(label: 'Low-storage rejection before download starts'),
            _InboxRow(label: 'Graceful permission fallback'),
            _InboxRow(label: 'Deterministic rename on file conflicts'),
          ],
        ),
      ],
    );
  }
}

class _InboxRow extends StatelessWidget {
  const _InboxRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(
          Icons.download_done_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
      ],
    );
  }
}
