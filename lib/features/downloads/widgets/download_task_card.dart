import 'dart:io';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../../../theme/tokens/app_typography.dart';
import '../models/download_task.dart';
import '../services/download_service.dart';

/// Production-grade 1DM+ download card supporting multithreaded chunk visualization.
/// Complies with rules.md §13, §25.1, §25.2, §25.7, and §29.2 (< 250 lines).
class DownloadTaskCard extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback onDelete;

  const DownloadTaskCard({
    super.key,
    required this.task,
    required this.onDelete,
  });

  String _getFileName() {
    final raw = task.destinationPath.isNotEmpty ? task.destinationPath : task.url;
    return File(raw).uri.pathSegments.lastOrNull ??
        Uri.tryParse(task.url)?.pathSegments.lastOrNull ??
        'download_${task.id}';
  }

  IconData _getFileIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.iso') || lower.endsWith('.img') || lower.endsWith('.dmg')) {
      return PhosphorIcons.disc;
    }
    if (lower.endsWith('.flac') || lower.endsWith('.mp3') || lower.endsWith('.wav') || lower.endsWith('.m4a')) {
      return PhosphorIcons.musicNote;
    }
    if (lower.endsWith('.pdf') || lower.endsWith('.doc') || lower.endsWith('.docx') || lower.endsWith('.txt')) {
      return PhosphorIcons.fileText;
    }
    if (lower.endsWith('.mp4') || lower.endsWith('.mkv') || lower.endsWith('.avi') || lower.endsWith('.mov')) {
      return PhosphorIcons.filmStrip;
    }
    if (lower.endsWith('.zip') || lower.endsWith('.rar') || lower.endsWith('.7z') || lower.endsWith('.tar')) {
      return PhosphorIcons.archive;
    }
    return PhosphorIcons.file;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fileName = _getFileName();
    final fileIcon = _getFileIcon(fileName);

    final cardBg = isDark ? const Color(0xFF131722) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFEDF0F5);
    final iconBg = isDark ? const Color(0xFF1E2533) : const Color(0xFFF1F5F9);
    final iconColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final trackColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final fillColor = isDark ? Colors.white : const Color(0xFF0F172A);

    final isCompleted = task.status == DownloadStatus.completed;
    final isActive = task.status == DownloadStatus.downloading ||
        task.status == DownloadStatus.connecting ||
        task.status == DownloadStatus.paused ||
        task.status == DownloadStatus.queued;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(fileIcon, size: 20, color: iconColor),
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: AppTypography.bodyMd.copyWith(
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _buildSubtitle(isCompleted),
                      style: AppTypography.bodySm.copyWith(
                        color: subColor,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.x2),
              _buildTrailingAction(isCompleted, textColor, subColor),
            ],
          ),
          if (isActive) ...[
            const SizedBox(height: AppSpacing.x3),
            _buildMultithreadedChunks(trackColor, fillColor),
          ],
        ],
      ),
    );
  }

  String _buildSubtitle(bool isCompleted) {
    if (isCompleted) {
      final date = task.dateLabel ?? 'Today';
      return '${task.fileSizeFormatted} • $date';
    }
    final dl = task.downloadedSizeFormatted;
    final total = task.fileSizeFormatted;
    final threads = '${task.segmentsCount} Threads';
    final speed = task.speedFormatted;
    return '$dl / $total • $threads • $speed';
  }

  Widget _buildTrailingAction(bool isCompleted, Color textColor, Color subColor) {
    if (isCompleted) {
      return Icon(PhosphorIcons.check, size: 20, color: subColor);
    }

    final isDownloading = task.status == DownloadStatus.downloading || task.status == DownloadStatus.connecting;
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      icon: Icon(
        isDownloading ? PhosphorIcons.pause : PhosphorIcons.play,
        size: 22,
        color: textColor,
      ),
      onPressed: () {
        if (isDownloading) {
          DownloadService().pauseDownload(task.id);
        } else {
          DownloadService().resumeDownload(task.id);
        }
      },
    );
  }

  Widget _buildMultithreadedChunks(Color trackColor, Color fillColor) {
    final chunks = task.getChunks(8);
    return Row(
      children: [
        for (int i = 0; i < chunks.length; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                height: 20,
                color: trackColor,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: chunks[i],
                  child: Container(color: fillColor),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
