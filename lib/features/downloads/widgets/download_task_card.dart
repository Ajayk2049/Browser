import 'dart:io';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../../../theme/tokens/app_typography.dart';
import '../models/download_task.dart';
import '../services/download_service.dart';

/// Card widget displaying active, paused, or finished download metrics.
/// Complies with rules.md §13, §25.1, §25.2, §25.7, and §29.2 (< 250 lines).
class DownloadTaskCard extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback onDelete;

  const DownloadTaskCard({
    super.key,
    required this.task,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fileName = File(task.destinationPath).uri.pathSegments.lastOrNull ??
        Uri.tryParse(task.url)?.pathSegments.lastOrNull ??
        'download_${task.id}';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.fileArrowDown, color: colorScheme.primary, size: 24),
              const SizedBox(width: AppSpacing.x2),
              Expanded(
                child: Text(
                  fileName,
                  style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildStatusPill(task.status, colorScheme),
            ],
          ),
          const SizedBox(height: AppSpacing.x2),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: task.totalBytes > 0 ? task.progress : null,
              minHeight: 6,
              color: task.status == DownloadStatus.failed
                  ? colorScheme.error
                  : colorScheme.primary,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: AppSpacing.x1),
          if (task.status == DownloadStatus.failed && task.errorMessage != null) ...[
            Text(
              task.errorMessage!,
              style: AppTypography.bodySm.copyWith(color: colorScheme.error, fontSize: 11),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.x1),
          ],
          Row(
            children: [
              Text(
                '${task.progressPercentage} • ${task.speedFormatted}'
                '${task.status == DownloadStatus.downloading && task.etaSeconds > 0 ? " • ETA: ${task.etaFormatted}" : ""}'
                '${task.isTorrent ? " • S:${task.seeders} P:${task.leechers}" : ""}',
                style: AppTypography.monoMd.copyWith(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              _buildActions(task, colorScheme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(DownloadStatus status, ColorScheme colorScheme) {
    Color bg;
    Color fg;
    switch (status) {
      case DownloadStatus.downloading:
        bg = colorScheme.primaryContainer;
        fg = colorScheme.onPrimaryContainer;
        break;
      case DownloadStatus.queued:
      case DownloadStatus.connecting:
      case DownloadStatus.pending:
        bg = colorScheme.tertiaryContainer;
        fg = colorScheme.onTertiaryContainer;
        break;
      case DownloadStatus.completed:
        bg = colorScheme.secondaryContainer;
        fg = colorScheme.onSecondaryContainer;
        break;
      case DownloadStatus.failed:
        bg = colorScheme.errorContainer;
        fg = colorScheme.onErrorContainer;
        break;
      case DownloadStatus.paused:
      case DownloadStatus.canceled:
        bg = colorScheme.surfaceContainerHighest;
        fg = colorScheme.onSurfaceVariant;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text(
        status.name.toUpperCase(),
        style: AppTypography.monoMd.copyWith(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  Widget _buildActions(DownloadTask task, ColorScheme colorScheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (task.status == DownloadStatus.downloading ||
            task.status == DownloadStatus.connecting)
          IconButton(
            icon: Icon(PhosphorIcons.pause, size: 20, color: colorScheme.onSurface),
            tooltip: 'Pause',
            onPressed: () => DownloadService().pauseDownload(task.id),
          )
        else if (task.status == DownloadStatus.paused ||
            task.status == DownloadStatus.queued)
          IconButton(
            icon: Icon(PhosphorIcons.play, size: 20, color: colorScheme.primary),
            tooltip: 'Resume',
            onPressed: () => DownloadService().resumeDownload(task.id),
          ),
        IconButton(
          icon: Icon(PhosphorIcons.trash, size: 20, color: colorScheme.error),
          tooltip: 'Delete / Cancel',
          onPressed: onDelete,
        ),
      ],
    );
  }
}

