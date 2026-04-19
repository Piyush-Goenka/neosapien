import 'package:flutter/material.dart';
import 'package:neo_sapien/app/router/app_section.dart';
import 'package:neo_sapien/features/home/presentation/widgets/overview_card.dart';
import 'package:neo_sapien/shared/presentation/widgets/app_scaffold.dart';

class SendScreen extends StatelessWidget {
  const SendScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      currentSection: AppSection.send,
      title: 'Send',
      child: _SendScreenBody(),
    );
  }
}

class _SendScreenBody extends StatelessWidget {
  const _SendScreenBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: const <Widget>[
        OverviewCard(
          eyebrow: 'Composer',
          title: 'The sender workflow is the next functional surface.',
          subtitle:
              'Recipient lookup, batch composition, validation, and progress '
              'orchestration will be connected here.',
          children: <Widget>[
            _PendingRow(
              label: 'Code entry with fast invalid-recipient failure',
            ),
            _PendingRow(label: 'Batch validation against size and count caps'),
            _PendingRow(label: 'Per-file and aggregate progress timeline'),
          ],
        ),
        SizedBox(height: 16),
        OverviewCard(
          eyebrow: 'Transport path',
          title:
              'This screen will talk to the transfer engine, not the network directly.',
          subtitle:
              'The UI stays thin while repository and native-bridge layers own '
              'resume, retry, and background behavior.',
          children: <Widget>[
            _PendingRow(label: 'TransferRepository draft creation'),
            _PendingRow(label: 'Relay-backed upload execution'),
            _PendingRow(label: 'Retry, cancel, and metered network prompts'),
          ],
        ),
      ],
    );
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(
          Icons.schedule_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
      ],
    );
  }
}
