import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neo_sapien/app/router/app_section.dart';
import 'package:neo_sapien/core/utils/byte_count_formatter.dart';
import 'package:neo_sapien/features/transfers/application/native_save_controller.dart';
import 'package:neo_sapien/features/transfers/application/transfer_batch_action_controller.dart';
import 'package:neo_sapien/features/transfers/application/transfer_draft_controller.dart';
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
        if (actionState.errorMessage != null) ...<Widget>[
          _InlineMessage(message: actionState.errorMessage!, isError: true),
          const SizedBox(height: 16),
        ],
        transferBatches.when(
          data: (batches) {
            final incomingBatches = batches
                .where(
                  (batch) => batch.direction == TransferDirection.incoming,
                )
                .toList(growable: false);

            final activeBatches = incomingBatches
                .where((batch) => !_isCompletedHistoryBatch(batch))
                .toList(growable: false);
            final completedBatches = incomingBatches
                .where(_isCompletedHistoryBatch)
                .toList(growable: false);

            if (incomingBatches.isEmpty) {
              return _EmptyState(
                message: 'No incoming transfers yet.',
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (activeBatches.isNotEmpty) ...<Widget>[
                  const _SectionHeader('Active'),
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
                  const SizedBox(height: 24),
                ],
                if (completedBatches.isNotEmpty) ...<Widget>[
                  const _SectionHeader('Saved'),
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
              ],
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (error, stackTrace) =>
              _InlineMessage(message: error.toString(), isError: true),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
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
                  'From ${batch.senderCode?.displayValue ?? 'Unknown'}',
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
            ],
          ),
          const SizedBox(height: 12),
          TransferProgressSummary(
            batch: batch,
            statusOverride: switch (batch.status) {
              TransferStatus.awaitingAcceptance => 'Waiting for you to accept',
              TransferStatus.queued => 'Waiting for sender to upload',
              TransferStatus.pendingRecipient => 'Ready to download',
              TransferStatus.downloading => 'Downloading',
              TransferStatus.completed => 'Saved',
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
                          ? 'Retry'
                          : 'Download',
                    ),
                  ),
                if (canCancelDownload)
                  FilledButton.tonalIcon(
                    onPressed: isActionPending ? null : onCancelDownload,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancel'),
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
                  'From ${batch.senderCode?.displayValue ?? 'Unknown'}',
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

class _SavedFilesList extends ConsumerWidget {
  const _SavedFilesList({required this.batch});

  final TransferBatch batch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedFiles = batch.files
        .where((file) => file.localPath != null && file.localPath!.isNotEmpty)
        .toList(growable: false);

    if (savedFiles.isEmpty) {
      return const SizedBox.shrink();
    }

    ref.listen<NativeSaveState>(nativeSaveControllerProvider, (previous, next) {
      final outcome = next.lastOutcome;
      if (outcome == null) {
        return;
      }
      if (previous?.lastOutcome == outcome) {
        return;
      }
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) {
        return;
      }
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            outcome.success
                ? 'Saved ${outcome.fileName} to the device.'
                : (outcome.message ?? 'Save failed for ${outcome.fileName}.'),
          ),
          backgroundColor: outcome.success
              ? null
              : Theme.of(context).colorScheme.errorContainer,
        ),
      );
    });

    final saveState = ref.watch(nativeSaveControllerProvider);
    final saveController = ref.read(nativeSaveControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var index = 0; index < savedFiles.length; index += 1) ...<Widget>[
          _SavedFileRow(
            file: savedFiles[index],
            isSaving: saveState.isPending(savedFiles[index].id),
            onSave: () => saveController.save(savedFiles[index]),
          ),
          if (index < savedFiles.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _SavedFileRow extends StatelessWidget {
  const _SavedFileRow({
    required this.file,
    required this.isSaving,
    required this.onSave,
  });

  final TransferFile file;
  final bool isSaving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                ByteCountFormatter.format(file.byteCount),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: isSaving ? null : onSave,
          tooltip: 'Save to device',
          icon: isSaving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_alt_rounded),
        ),
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
