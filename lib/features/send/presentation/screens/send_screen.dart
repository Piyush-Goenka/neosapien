import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neo_sapien/app/router/app_section.dart';
import 'package:neo_sapien/core/utils/byte_count_formatter.dart';
import 'package:neo_sapien/features/home/presentation/widgets/overview_card.dart';
import 'package:neo_sapien/features/recipients/application/recipient_lookup_controller.dart';
import 'package:neo_sapien/features/recipients/domain/entities/recipient.dart';
import 'package:neo_sapien/features/transfers/application/transfer_batch_action_controller.dart';
import 'package:neo_sapien/features/transfers/application/transfer_draft_controller.dart';
import 'package:neo_sapien/features/transfers/domain/entities/network_policy.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_batch.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_direction.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_file.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_status.dart';
import 'package:neo_sapien/features/transfers/presentation/widgets/transfer_progress_summary.dart';
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
    final draftState = ref.watch(transferDraftComposerProvider);
    final draftController = ref.read(transferDraftComposerProvider.notifier);
    final transferBatches = ref.watch(transferBatchesProvider);
    final actionState = ref.watch(transferBatchActionControllerProvider);
    final actionController = ref.read(
      transferBatchActionControllerProvider.notifier,
    );
    final resolvedRecipient = lookupState.resolvedRecipient;
    final canCreateDraft =
        resolvedRecipient != null &&
        draftState.hasSelection &&
        !draftState.isPickingFiles &&
        !draftState.isCreatingDraft;

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
        const SizedBox(height: 16),
        OverviewCard(
          eyebrow: 'Draft batch',
          title: 'Pick files and create the first real transfer record.',
          subtitle:
              'The sender still validates locally first, but a configured app '
              'now escalates the batch into a shared remote transfer record so '
              'the recipient inbox can update in near real time.',
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed:
                        draftState.isPickingFiles || draftState.isCreatingDraft
                        ? null
                        : draftController.pickFiles,
                    icon: draftState.isPickingFiles
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.attach_file_rounded),
                    label: Text(
                      draftState.hasSelection ? 'Add files' : 'Select files',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.tonal(
                  onPressed: draftState.hasSelection
                      ? draftController.clearSelection
                      : null,
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<NetworkPolicy>(
              initialValue: draftState.networkPolicy,
              decoration: const InputDecoration(
                labelText: 'Network policy',
                border: OutlineInputBorder(),
              ),
              items: NetworkPolicy.values
                  .map(
                    (policy) => DropdownMenuItem<NetworkPolicy>(
                      value: policy,
                      child: Text(_networkPolicyLabel(policy)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: draftState.isCreatingDraft
                  ? null
                  : (policy) {
                      if (policy == null) {
                        return;
                      }
                      draftController.updateNetworkPolicy(policy);
                    },
            ),
            const SizedBox(height: 12),
            _MessageRow(
              icon: resolvedRecipient == null
                  ? Icons.info_outline_rounded
                  : Icons.verified_rounded,
              message: resolvedRecipient == null
                  ? 'Resolve a recipient before creating a draft batch.'
                  : 'Draft will target ${resolvedRecipient.code.displayValue}.',
            ),
            if (draftState.errorMessage != null) ...<Widget>[
              const SizedBox(height: 12),
              _MessageRow(
                icon: Icons.error_outline_rounded,
                message: draftState.errorMessage!,
                isError: true,
              ),
            ],
            if (draftState.createdBatchId != null) ...<Widget>[
              const SizedBox(height: 12),
              _MessageRow(
                icon: Icons.check_circle_outline_rounded,
                message:
                    'Transfer ${draftState.createdBatchId} created. '
                    'If Firebase is configured, the recipient inbox can now see it live.',
              ),
            ],
            const SizedBox(height: 16),
            if (!draftState.hasSelection)
              const _EmptySelectionState()
            else ...<Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  Chip(
                    label: Text(
                      '${draftState.selectedFiles.length} file'
                      '${draftState.selectedFiles.length == 1 ? '' : 's'}',
                    ),
                  ),
                  Chip(
                    label: Text(
                      ByteCountFormatter.format(draftState.totalSelectedBytes),
                    ),
                  ),
                  Chip(
                    label: Text(_networkPolicyLabel(draftState.networkPolicy)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (final file in draftState.selectedFiles) ...<Widget>[
                _SelectedFileRow(
                  file: file,
                  onRemove: () => draftController.removeSelectedFile(file.id),
                ),
                const SizedBox(height: 12),
              ],
            ],
            FilledButton.icon(
              onPressed: canCreateDraft
                  ? () => draftController.createDraft(
                      recipient: resolvedRecipient,
                    )
                  : null,
              icon: draftState.isCreatingDraft
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.playlist_add_check_circle_rounded),
              label: Text(
                draftState.isCreatingDraft
                    ? 'Creating draft'
                    : 'Create transfer draft',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        OverviewCard(
          eyebrow: 'Outgoing drafts',
          title: 'Outgoing transfers can now start upload and report progress.',
          subtitle:
              'Local fallback remains available, but Firebase-backed transfers '
              'now use the same queue surface so send-side state stays unified '
              'while the sender pushes bytes into Firebase Storage.',
          children: <Widget>[
            if (actionState.errorMessage != null) ...<Widget>[
              _MessageRow(
                icon: Icons.error_outline_rounded,
                message: actionState.errorMessage!,
                isError: true,
              ),
              const SizedBox(height: 12),
            ],
            transferBatches.when(
              data: (batches) {
                final outgoingBatches = batches
                    .where(
                      (batch) => batch.direction == TransferDirection.outgoing,
                    )
                    .toList(growable: false);
                if (outgoingBatches.isEmpty) {
                  return const _EmptyDraftsState();
                }

                return Column(
                  children: <Widget>[
                    for (
                      var index = 0;
                      index < outgoingBatches.length;
                      index += 1
                    ) ...<Widget>[
                      _DraftBatchCard(
                        batch: outgoingBatches[index],
                        isActionPending: actionState.isPending(
                          outgoingBatches[index].id,
                        ),
                        onStartUpload: () => actionController.startUpload(
                          outgoingBatches[index].id,
                        ),
                        onCancel: () =>
                            actionController.cancel(outgoingBatches[index].id),
                      ),
                      if (index < outgoingBatches.length - 1)
                        const SizedBox(height: 12),
                    ],
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, stackTrace) => _MessageRow(
                icon: Icons.error_outline_rounded,
                message: error.toString(),
                isError: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EmptySelectionState extends StatelessWidget {
  const _EmptySelectionState();

  @override
  Widget build(BuildContext context) {
    return Text(
      'No files selected yet. Pick one or more files and the app will '
      'validate file-count, per-file, and batch-size limits before creating a draft.',
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}

class _EmptyDraftsState extends StatelessWidget {
  const _EmptyDraftsState();

  @override
  Widget build(BuildContext context) {
    return Text(
      'No outgoing drafts yet. Resolve a recipient, pick files, and create a '
      'draft to populate the sender queue.',
      style: Theme.of(context).textTheme.bodyMedium,
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

class _SelectedFileRow extends StatelessWidget {
  const _SelectedFileRow({required this.file, required this.onRemove});

  final TransferFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.insert_drive_file_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  file.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${ByteCountFormatter.format(file.byteCount)} • ${file.mimeType}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (file.byteCount == 0) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    'Zero-byte files are allowed and will still be tracked.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Remove file',
          ),
        ],
      ),
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

class _DraftBatchCard extends StatelessWidget {
  const _DraftBatchCard({
    required this.batch,
    required this.isActionPending,
    required this.onStartUpload,
    required this.onCancel,
  });

  final TransferBatch batch;
  final bool isActionPending;
  final VoidCallback onStartUpload;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final canStartUpload =
        batch.status == TransferStatus.queued ||
        batch.status == TransferStatus.failed;
    final canCancel =
        batch.status != TransferStatus.cancelled &&
        batch.status != TransferStatus.rejected &&
        batch.status != TransferStatus.completed &&
        batch.status != TransferStatus.pendingRecipient;

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
                  batch.recipientCode?.displayValue ?? 'Unknown recipient',
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
                'Waiting for recipient acceptance',
              TransferStatus.pendingRecipient =>
                'Upload complete. Recipient download is next',
              _ => null,
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              if (canStartUpload)
                FilledButton.icon(
                  onPressed: isActionPending ? null : onStartUpload,
                  icon: isActionPending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          batch.status == TransferStatus.failed
                              ? Icons.restart_alt_rounded
                              : Icons.cloud_upload_rounded,
                        ),
                  label: Text(
                    batch.status == TransferStatus.failed
                        ? 'Retry upload'
                        : 'Start upload',
                  ),
                ),
              if (canCancel)
                FilledButton.tonalIcon(
                  onPressed: isActionPending ? null : onCancel,
                  icon: const Icon(Icons.cancel_outlined),
                  label: Text(
                    batch.status == TransferStatus.uploading
                        ? 'Cancel upload'
                        : 'Cancel transfer',
                  ),
                ),
            ],
          ),
          if (batch.status == TransferStatus.awaitingAcceptance) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              'Recipient must accept this transfer before upload can start.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
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
