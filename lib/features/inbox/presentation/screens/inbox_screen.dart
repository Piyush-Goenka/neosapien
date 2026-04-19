import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neo_sapien/app/router/app_section.dart';
import 'package:neo_sapien/core/utils/byte_count_formatter.dart';
import 'package:neo_sapien/features/home/presentation/widgets/overview_card.dart';
import 'package:neo_sapien/features/transfers/application/transfer_batch_action_controller.dart';
import 'package:neo_sapien/features/transfers/application/transfer_draft_controller.dart';
import 'package:neo_sapien/features/transfers/domain/entities/network_policy.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_batch.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_direction.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_status.dart';
import 'package:neo_sapien/features/transfers/presentation/widgets/transfer_progress_summary.dart';
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

class _InboxScreenBody extends ConsumerWidget {
  const _InboxScreenBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transferBatches = ref.watch(transferBatchesProvider);
    final actionState = ref.watch(transferBatchActionControllerProvider);
    final actionController = ref.read(
      transferBatchActionControllerProvider.notifier,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: <Widget>[
        OverviewCard(
          eyebrow: 'Recipient experience',
          title:
              'Incoming transfer discovery is now backed by the shared transfer repository.',
          subtitle:
              'Firestore-backed transfer metadata can now appear here in near '
              'real time when Firebase is configured. Accept/reject is wired, '
              'and sender upload progress now streams here while download and '
              'save flows remain the next slice.',
          children: <Widget>[
            if (actionState.errorMessage != null)
              _InlineMessage(message: actionState.errorMessage!, isError: true),
            transferBatches.when(
              data: (batches) {
                final incomingBatches = batches
                    .where(
                      (batch) => batch.direction == TransferDirection.incoming,
                    )
                    .toList(growable: false);
                if (incomingBatches.isEmpty) {
                  return const _EmptyInboxState();
                }

                return Column(
                  children: <Widget>[
                    for (
                      var index = 0;
                      index < incomingBatches.length;
                      index += 1
                    ) ...<Widget>[
                      _IncomingBatchCard(
                        batch: incomingBatches[index],
                        isActionPending: actionState.isPending(
                          incomingBatches[index].id,
                        ),
                        onAccept: () =>
                            actionController.accept(incomingBatches[index].id),
                        onReject: () =>
                            actionController.reject(incomingBatches[index].id),
                      ),
                      if (index < incomingBatches.length - 1)
                        const SizedBox(height: 12),
                    ],
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, stackTrace) =>
                  _InlineMessage(message: error.toString(), isError: true),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const OverviewCard(
          eyebrow: 'Next in queue',
          title: 'Receiver-side persistence is still ahead.',
          subtitle:
              'This inbox now proves cross-device metadata arrival, recipient '
              'decision flow, and sender-side upload progress. The next slice '
              'connects actual download and save-to-device behavior.',
          children: <Widget>[
            _InboxRow(label: 'Recipient download and save-to-device flow'),
            _InboxRow(label: 'Push notifications and deep links'),
          ],
        ),
        const SizedBox(height: 16),
        const OverviewCard(
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

class _EmptyInboxState extends StatelessWidget {
  const _EmptyInboxState();

  @override
  Widget build(BuildContext context) {
    return Text(
      'No incoming transfers yet. When Firebase is configured and another '
      'device creates a transfer for this user, it will appear here without a manual refresh.',
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
          color: isError ? colorScheme.error : colorScheme.primary,
        ),
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

class _IncomingBatchCard extends StatelessWidget {
  const _IncomingBatchCard({
    required this.batch,
    required this.isActionPending,
    required this.onAccept,
    required this.onReject,
  });

  final TransferBatch batch;
  final bool isActionPending;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final canDecide = batch.status == TransferStatus.awaitingAcceptance;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  batch.senderCode?.displayValue ?? 'Unknown sender',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Chip(label: Text(formatTransferStatus(batch.status))),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              Chip(
                label: Text(
                  '${batch.files.length} file${batch.files.length == 1 ? '' : 's'}',
                ),
              ),
              Chip(label: Text(ByteCountFormatter.format(batch.totalBytes))),
              Chip(label: Text(_networkPolicyLabel(batch.networkPolicy))),
            ],
          ),
          const SizedBox(height: 12),
          TransferProgressSummary(
            batch: batch,
            statusOverride: switch (batch.status) {
              TransferStatus.awaitingAcceptance =>
                'Waiting for your decision before upload starts',
              TransferStatus.pendingRecipient =>
                'Upload complete. Download flow is next',
              _ => null,
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: !canDecide || isActionPending ? null : onAccept,
                  icon: isActionPending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Accept'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: !canDecide || isActionPending ? null : onReject,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Reject'),
                ),
              ),
            ],
          ),
        ],
      ),
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

String _networkPolicyLabel(NetworkPolicy policy) {
  return switch (policy) {
    NetworkPolicy.confirmOnMetered => 'Confirm on metered',
    NetworkPolicy.wifiOnly => 'Wi-Fi only',
    NetworkPolicy.allowMetered => 'Allow metered',
  };
}
