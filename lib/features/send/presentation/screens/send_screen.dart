import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neo_sapien/app/router/app_section.dart';
import 'package:neo_sapien/features/home/presentation/widgets/overview_card.dart';
import 'package:neo_sapien/features/recipients/application/recipient_lookup_controller.dart';
import 'package:neo_sapien/features/recipients/domain/entities/recipient.dart';
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

class _SendScreenBody extends ConsumerWidget {
  const _SendScreenBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lookupState = ref.watch(recipientLookupControllerProvider);
    final lookupController = ref.read(
      recipientLookupControllerProvider.notifier,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: <Widget>[
        OverviewCard(
          eyebrow: 'Composer',
          title:
              'Recipient lookup is now wired to the real addressing contract.',
          subtitle:
              'This is the first backend-backed slice of the send flow. '
              'It validates the code format, blocks self-send, and checks '
              'Firestore for a matching recipient.',
          children: <Widget>[
            TextField(
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Recipient code',
                hintText: 'ABCD-EFGH',
                border: OutlineInputBorder(),
              ),
              onChanged: lookupController.updateInput,
            ),
            FilledButton.icon(
              onPressed: lookupState.isSubmitting
                  ? null
                  : lookupController.resolveRecipient,
              icon: lookupState.isSubmitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_search_rounded),
              label: Text(
                lookupState.isSubmitting
                    ? 'Resolving recipient'
                    : 'Resolve recipient',
              ),
            ),
            if (lookupState.errorMessage != null)
              _MessageRow(
                icon: Icons.error_outline_rounded,
                message: lookupState.errorMessage!,
                isError: true,
              ),
            if (lookupState.resolvedRecipient != null)
              _ResolvedRecipientCard(recipient: lookupState.resolvedRecipient!),
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

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.icon,
    required this.message,
    this.isError = false,
  });

  final IconData icon;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, color: isError ? colorScheme.error : colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isError ? colorScheme.error : colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _ResolvedRecipientCard extends StatelessWidget {
  const _ResolvedRecipientCard({required this.recipient});

  final Recipient recipient;

  @override
  Widget build(BuildContext context) {
    final subtitle = recipient.isOnline
        ? 'Recipient is currently online.'
        : 'Recipient is registered but not confirmed online.';

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          const Icon(Icons.verified_user_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  recipient.displayName ?? recipient.code.displayValue,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
