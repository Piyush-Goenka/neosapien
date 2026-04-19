import 'package:flutter/material.dart';
import 'package:neo_sapien/core/utils/byte_count_formatter.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_batch.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_file.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_status.dart';

class TransferProgressSummary extends StatelessWidget {
  const TransferProgressSummary({
    required this.batch,
    this.statusOverride,
    super.key,
  });

  final TransferBatch batch;
  final String? statusOverride;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transferredText =
        '${ByteCountFormatter.format(batch.bytesTransferred)} / '
        '${ByteCountFormatter.format(batch.totalBytes)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LinearProgressIndicator(value: _normalizedProgress(batch.progress)),
        const SizedBox(height: 8),
        Text(
          '${statusOverride ?? formatTransferStatus(batch.status)} • $transferredText',
          style: theme.textTheme.bodyMedium,
        ),
        if (batch.failure != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            batch.failure!.message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 12),
        for (var index = 0; index < batch.files.length; index += 1) ...<Widget>[
          _TransferFileProgressRow(file: batch.files[index]),
          if (index < batch.files.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  double _normalizedProgress(double progress) {
    if (progress.isNaN || progress.isInfinite) {
      return 0;
    }

    if (progress < 0) {
      return 0;
    }

    if (progress > 1) {
      return 1;
    }

    return progress;
  }
}

class _TransferFileProgressRow extends StatelessWidget {
  const _TransferFileProgressRow({required this.file});

  final TransferFile file;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detailText =
        '${ByteCountFormatter.format(file.transferredBytes)} / '
        '${ByteCountFormatter.format(file.byteCount)} • '
        '${_formatFileStatus(file)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          file.name,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(value: _normalizedProgress(file.progress)),
        const SizedBox(height: 4),
        Text(detailText, style: theme.textTheme.bodySmall),
        if (file.failure != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            file.failure!.message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  double _normalizedProgress(double progress) {
    if (progress.isNaN || progress.isInfinite) {
      return 0;
    }

    if (progress < 0) {
      return 0;
    }

    if (progress > 1) {
      return 1;
    }

    return progress;
  }
}

String formatTransferStatus(TransferStatus status) {
  return switch (status) {
    TransferStatus.draft => 'Draft',
    TransferStatus.validating => 'Validating',
    TransferStatus.queued => 'Queued',
    TransferStatus.uploading => 'Uploading',
    TransferStatus.pendingRecipient => 'Uploaded',
    TransferStatus.awaitingAcceptance => 'Awaiting acceptance',
    TransferStatus.downloading => 'Downloading',
    TransferStatus.completed => 'Completed',
    TransferStatus.failed => 'Failed',
    TransferStatus.cancelled => 'Cancelled',
    TransferStatus.expired => 'Expired',
    TransferStatus.rejected => 'Rejected',
    TransferStatus.corrupted => 'Corrupted',
  };
}

String _formatFileStatus(TransferFile file) {
  if (file.failure != null) {
    return file.failure!.isRecoverable ? 'Needs retry' : 'Failed';
  }

  return switch (file.status.name) {
    'pending' => 'Pending',
    'inProgress' => 'In progress',
    'completed' => 'Completed',
    'failed' => 'Failed',
    'cancelled' => 'Cancelled',
    _ => 'Pending',
  };
}
