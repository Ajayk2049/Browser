import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../../../theme/tokens/app_typography.dart';
import '../models/download_task.dart';
import '../services/download_service.dart';

/// Material 3 Expressive Download Manager screen.
/// Adheres strictly to rules.md §25.1, §25.2, §25.7, and §29.2 (< 300 lines).
class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final DownloadService _service = DownloadService();
  final Map<String, DownloadTask> _tasks = {};
  StreamSubscription<DownloadTask>? _sub;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialTasks();
    _sub = _service.downloadUpdates.listen((task) {
      if (mounted) {
        setState(() {
          _tasks[task.id] = task;
        });
      }
    });
  }

  Future<void> _loadInitialTasks() async {
    final tasks = await _service.getActiveTasks();
    if (mounted) {
      setState(() {
        for (final t in tasks) {
          _tasks[t.id] = t;
        }
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final taskList = _tasks.values.toList().reversed.toList();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Downloads',
          style: AppTypography.displaySm.copyWith(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Pause All',
            icon: Icon(PhosphorIcons.pauseCircle, color: colorScheme.onSurface),
            onPressed: () => _service.pauseAll(),
          ),
          IconButton(
            tooltip: 'Resume All',
            icon: Icon(PhosphorIcons.playCircle, color: colorScheme.primary),
            onPressed: () => _service.resumeAll(),
          ),
          const SizedBox(width: AppSpacing.x1),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : taskList.isEmpty
              ? _buildEmptyState(colorScheme)
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.x4),
                  itemCount: taskList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x2),
                  itemBuilder: (context, index) => _buildTaskCard(taskList[index], colorScheme),
                ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PhosphorIcons.tray, size: 64, color: colorScheme.outlineVariant),
          const SizedBox(height: AppSpacing.x4),
          Text(
            'No downloads yet',
            style: AppTypography.displaySm.copyWith(color: colorScheme.onSurface),
          ),
          const SizedBox(height: AppSpacing.x1),
          Text(
            'Links downloaded from the browser will appear here',
            style: AppTypography.bodySm.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(DownloadTask task, ColorScheme colorScheme) {
    final fileName = File(task.destinationPath).uri.pathSegments.lastOrNull ??
        Uri.tryParse(task.url)?.pathSegments.lastOrNull ??
        'download_${task.id}';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(120)),
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
              color: task.status == DownloadStatus.failed ? colorScheme.error : colorScheme.primary,
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
                '${task.progressPercentage} • ${task.speedFormatted}${task.status == DownloadStatus.downloading && task.etaSeconds > 0 ? " • ETA: ${task.etaFormatted}" : ""}${task.isTorrent ? " • S:${task.seeders} P:${task.leechers}" : ""}',
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
        if (task.status == DownloadStatus.downloading || task.status == DownloadStatus.connecting)
          IconButton(
            icon: Icon(PhosphorIcons.pause, size: 20, color: colorScheme.onSurface),
            tooltip: 'Pause',
            onPressed: () => _service.pauseDownload(task.id),
          )
        else if (task.status == DownloadStatus.paused || task.status == DownloadStatus.queued)
          IconButton(
            icon: Icon(PhosphorIcons.play, size: 20, color: colorScheme.primary),
            tooltip: 'Resume',
            onPressed: () => _service.resumeDownload(task.id),
          ),
        IconButton(
          icon: Icon(PhosphorIcons.trash, size: 20, color: colorScheme.error),
          tooltip: 'Delete / Cancel',
          onPressed: () {
            _service.cancelDownload(task.id);
            setState(() => _tasks.remove(task.id));
          },
        ),
      ],
    );
  }
}
