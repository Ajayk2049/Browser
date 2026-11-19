import 'package:flutter/material.dart';

enum DownloadStatus { downloading, paused, completed, failed }

class DownloadItemWidget extends StatelessWidget {
  final String title;
  final String url;
  final int downloadedBytes;
  final int totalBytes;
  final double speedBytesPerSec;
  final int? etaSeconds;
  final int partsCount;
  final DownloadStatus status;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onDelete;
  final VoidCallback? onViewChunks;

  const DownloadItemWidget({
    Key? key,
    required this.title,
    required this.url,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.speedBytesPerSec,
    this.etaSeconds,
    this.partsCount = 8,
    required this.status,
    this.onPause,
    this.onResume,
    this.onDelete,
    this.onViewChunks,
  }) : super(key: key);

  String _formatBytes(int bytes) {
    if (bytes >= 1073741824) {
      return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
    } else if (bytes >= 1048576) {
      return '${(bytes / 1048576).toStringAsFixed(2)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '$bytes B';
    }
  }

  Color _getStatusColor() {
    switch (status) {
      case DownloadStatus.downloading:
        return const Color(0xFF00C853);
      case DownloadStatus.paused:
        return const Color(0xFFFFAB00);
      case DownloadStatus.completed:
        return const Color(0xFF2979FF);
      case DownloadStatus.failed:
        return const Color(0xFFFF1744);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double progress = totalBytes > 0
        ? (downloadedBytes / totalBytes).clamp(0.0, 1.0)
        : (status == DownloadStatus.completed ? 1.0 : 0.0);

    return Card(
      color: const Color(0xFF1E1E2C),
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insert_drive_file, color: Color(0xFF00B4D8), size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        url,
                        style: TextStyle(color: Colors.grey[400], fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor().withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _getStatusColor(), width: 1),
                  ),
                  child: Text(
                    status.name.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor()),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '${_formatBytes(downloadedBytes)} / ${_formatBytes(totalBytes)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const Spacer(),
                if (status == DownloadStatus.downloading) ...[
                  Text(
                    '${_formatBytes(speedBytesPerSec.toInt())}/s',
                    style: const TextStyle(color: Color(0xFF00B4D8), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  if (etaSeconds != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '• ETA: ${etaSeconds}s',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ],
              ],
            ),
            const Divider(color: Colors.white10, height: 20),
            Row(
              children: [
                Text(
                  'Parts: $partsCount',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
                if (onViewChunks != null) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onViewChunks,
                    icon: const Icon(Icons.analytics_outlined, size: 14, color: Color(0xFF00B4D8)),
                    label: const Text('Chunks', style: TextStyle(color: Color(0xFF00B4D8), fontSize: 11)),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                  ),
                ],
                const Spacer(),
                if (status == DownloadStatus.downloading && onPause != null)
                  IconButton(
                    icon: const Icon(Icons.pause_circle_filled, color: Color(0xFFFFAB00), size: 26),
                    onPressed: onPause,
                    tooltip: 'Pause',
                  ),
                if (status == DownloadStatus.paused && onResume != null)
                  IconButton(
                    icon: const Icon(Icons.play_circle_fill, color: Color(0xFF00C853), size: 26),
                    onPressed: onResume,
                    tooltip: 'Resume',
                  ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                    onPressed: onDelete,
                    tooltip: 'Delete',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
