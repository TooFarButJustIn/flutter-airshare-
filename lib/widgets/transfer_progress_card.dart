import 'package:flutter/material.dart';
import '../models/device_model.dart';

class TransferProgressCard extends StatelessWidget {
  final TransferProgress progress;
  final VoidCallback onCancel;

  const TransferProgressCard({
    Key? key,
    required this.progress,
    required this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getStatusColor(progress.status).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getStatusIcon(progress.status),
                color: _getStatusColor(progress.status),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  progress.fileName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (progress.status == TransferStatus.transferring)
                IconButton(
                  onPressed: onCancel,
                  icon: const Icon(Icons.close),
                  iconSize: 18,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (progress.status == TransferStatus.transferring) ...[
            LinearProgressIndicator(
              value: progress.progress,
              backgroundColor: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation(_getStatusColor(progress.status)),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(progress.progress * 100).toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                Text(
                  progress.speedFormatted,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
            if (progress.estimatedTimeRemaining.inSeconds > 0) ...[
              const SizedBox(height: 4),
              Text(
                'ETA: ${_formatDuration(progress.estimatedTimeRemaining)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ] else ...[
            Text(
              _getStatusText(progress.status),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _getStatusColor(progress.status),
                fontWeight: FontWeight.w500,
              ),
            ),
            if (progress.error != null) ...[
              const SizedBox(height: 4),
              Text(
                progress.error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ],
      ),
    );
  }

  IconData _getStatusIcon(TransferStatus status) {
    switch (status) {
      case TransferStatus.pending:
        return Icons.schedule;
      case TransferStatus.connecting:
        return Icons.connecting_airports;
      case TransferStatus.transferring:
        return Icons.swap_horiz;
      case TransferStatus.completed:
        return Icons.check_circle;
      case TransferStatus.failed:
        return Icons.error;
      case TransferStatus.cancelled:
        return Icons.cancel;
    }
  }

  Color _getStatusColor(TransferStatus status) {
    switch (status) {
      case TransferStatus.pending:
        return Colors.orange;
      case TransferStatus.connecting:
        return Colors.blue;
      case TransferStatus.transferring:
        return Colors.green;
      case TransferStatus.completed:
        return Colors.green;
      case TransferStatus.failed:
        return Colors.red;
      case TransferStatus.cancelled:
        return Colors.grey;
    }
  }

  String _getStatusText(TransferStatus status) {
    switch (status) {
      case TransferStatus.pending:
        return 'Pending...';
      case TransferStatus.connecting:
        return 'Connecting...';
      case TransferStatus.transferring:
        return 'Transferring...';
      case TransferStatus.completed:
        return 'Complete';
      case TransferStatus.failed:
        return 'Failed';
      case TransferStatus.cancelled:
        return 'Cancelled';
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}
