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
import 'package:neo_sapien/features/transfers/domain/entities/transfer_file.dart';
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
              'Incoming transfers can now be accepted, downloaded, and saved.',
          subtitle:
              'The inbox still listens to the shared Firestore transfer feed, '
              'but accepted uploads can now be downloaded into app storage, '
              'retried on failure, and shown again from local saved history.',
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

                final activeBatches = incomingBatches
                    .where((batch) => !_isCompletedHistoryBatch(batch))
                    .toList(growable: false);
                if (activeBatches.isEmpty) {
                  return const _EmptyActiveInboxState();
                }

                return Column(
                  children: <Widget>[
                    for (
                      var index = 0;
                      index < activeBatches.length;
                      index += 1
                    ) ...<Widget>[
                      _IncomingBatchCard(
                        batch: activeBatches[index],
                        isActionPending: actionState.isPending(
                          activeBatches[index].id,
                        ),
                        onAccept: () =>
                            actionController.accept(activeBatches[index].id),
                        onReject: () =>
                            actionController.reject(activeBatches[index].id),
                        onDownload: () =>
                            actionController.download(activeBatches[index].id),
                        onCancelDownload: () =>
                            actionController.cancel(activeBatches[index].id),
                      ),
                      if (index < activeBatches.length - 1)
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
        OverviewCard(
          eyebrow: 'Saved history',
          title: 'Completed downloads are kept in local receiver history.',
          subtitle:
              'Saved file paths are merged back into the shared transfer feed, '
              'so completed batches still render honestly after the app restarts.',
          children: <Widget>[
            transferBatches.when(
              data: (batches) {
                final completedBatches = batches
                    .where(
                      (batch) =>
                          batch.direction == TransferDirection.incoming &&
                          _isCompletedHistoryBatch(batch),
                    )
                    .toList(growable: false);
                if (completedBatches.isEmpty) {
                  return const _EmptyHistoryState();
                }

                return Column(
                  children: <Widget>[
                    for (
                      var index = 0;
                      index < completedBatches.length;
                      index += 1
                    ) ...<Widget>[
                      _CompletedBatchCard(batch: completedBatches[index]),
                      if (index < completedBatches.length - 1)
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
          eyebrow: 'Still to harden',
          title: 'Receiver reliability work is narrower now.',
          subtitle:
              'The happy-path download/save slice is in place. The remaining '
              'receiver gaps are preflight checks and closed-app discovery.',
          children: <Widget>[
            _InboxRow(label: 'Low-storage rejection before download starts'),
            _InboxRow(label: 'Graceful permission and notification fallback'),
            _InboxRow(label: 'Closed-app discovery with push and deep links'),
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

class _EmptyActiveInboxState extends StatelessWidget {
  const _EmptyActiveInboxState();

  @override
  Widget build(BuildContext context) {
    return Text(
      'No active incoming work right now. Accepted uploads that still need a '
      'download will appear here, while finished saves stay in the history card below.',
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}

class _EmptyHistoryState extends StatelessWidget {
  const _EmptyHistoryState();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Nothing has been saved to this device yet. Completed incoming batches '
      'will move here once their files finish downloading into app storage.',
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
    required this.onDownload,
    required this.onCancelDownload,
  });

  final TransferBatch batch;
  final bool isActionPending;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onDownload;
  final VoidCallback onCancelDownload;

  @override
  Widget build(BuildContext context) {
    final canDecide = batch.status == TransferStatus.awaitingAcceptance;
    final canDownload = _canDownload(batch);
    final canCancelDownload = batch.status == TransferStatus.downloading;

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
              TransferStatus.queued =>
                'Accepted. Waiting for the sender to start the upload',
              TransferStatus.pendingRecipient =>
                'Upload complete. Download and save to this device',
              TransferStatus.downloading =>
                'Downloading into this device storage',
              TransferStatus.completed => 'Saved to this device',
              _ => null,
            },
          ),
          if (_hasSavedFiles(batch)) ...<Widget>[
            const SizedBox(height: 12),
            _SavedFilesList(batch: batch),
          ],
          const SizedBox(height: 12),
          if (canDecide)
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isActionPending ? null : onAccept,
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
                    onPressed: isActionPending ? null : onReject,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Reject'),
                  ),
                ),
              ],
            )
          else if (canDownload || canCancelDownload)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                if (canDownload)
                  FilledButton.icon(
                    onPressed: isActionPending ? null : onDownload,
                    icon: isActionPending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            batch.status == TransferStatus.failed
                                ? Icons.restart_alt_rounded
                                : Icons.download_rounded,
                          ),
                    label: Text(
                      batch.status == TransferStatus.failed
                          ? 'Retry download'
                          : batch.status == TransferStatus.completed
                          ? 'Download again'
                          : 'Download & save',
                    ),
                  ),
                if (canCancelDownload)
                  FilledButton.tonalIcon(
                    onPressed: isActionPending ? null : onCancelDownload,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancel download'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CompletedBatchCard extends StatelessWidget {
  const _CompletedBatchCard({required this.batch});

  final TransferBatch batch;

  @override
  Widget build(BuildContext context) {
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
              const Chip(label: Text('Saved')),
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
            ],
          ),
          const SizedBox(height: 12),
          _SavedFilesList(batch: batch),
        ],
      ),
    );
  }
}

class _SavedFilesList extends StatelessWidget {
  const _SavedFilesList({required this.batch});

  final TransferBatch batch;

  @override
  Widget build(BuildContext context) {
    final savedFiles = batch.files
        .where((file) => file.localPath != null && file.localPath!.isNotEmpty)
        .toList(growable: false);

    if (savedFiles.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Saved locally',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < savedFiles.length; index += 1) ...<Widget>[
          _SavedFileRow(file: savedFiles[index]),
          if (index < savedFiles.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _SavedFileRow extends StatelessWidget {
  const _SavedFileRow({required this.file});

  final TransferFile file;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          Icons.download_done_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                file.name,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                file.localPath!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
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

bool _canDownload(TransferBatch batch) {
  if (_isCompletedHistoryBatch(batch)) {
    return false;
  }

  return switch (batch.status) {
    TransferStatus.pendingRecipient ||
    TransferStatus.failed ||
    TransferStatus.completed => true,
    _ => false,
  };
}

bool _hasSavedFiles(TransferBatch batch) {
  return batch.files.any(
    (file) => file.localPath != null && file.localPath!.isNotEmpty,
  );
}

bool _isCompletedHistoryBatch(TransferBatch batch) {
  return batch.files.isNotEmpty &&
      batch.files.every(
        (file) => file.localPath != null && file.localPath!.isNotEmpty,
      );
}

String _networkPolicyLabel(NetworkPolicy policy) {
  return switch (policy) {
    NetworkPolicy.confirmOnMetered => 'Confirm on metered',
    NetworkPolicy.wifiOnly => 'Wi-Fi only',
    NetworkPolicy.allowMetered => 'Allow metered',
  };
}
