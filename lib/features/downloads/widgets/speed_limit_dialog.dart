import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../../../theme/tokens/app_typography.dart';
import '../services/download_service.dart';

/// Modal dialog for throttling per-task or global download speeds.
/// Adheres to monochrome design principles and rules.md §13, §29.2 (< 200 lines).
class SpeedLimitDialog extends StatelessWidget {
  final String? taskId;
  final int currentLimitBytes;

  const SpeedLimitDialog({
    super.key,
    this.taskId,
    required this.currentLimitBytes,
  });

  static const List<Map<String, dynamic>> _presets = [
    {'label': 'No Limit (Max speed)', 'bytes': 0},
    {'label': '512 KB/s', 'bytes': 512 * 1024},
    {'label': '1.0 MB/s', 'bytes': 1024 * 1024},
    {'label': '2.5 MB/s', 'bytes': 2560 * 1024},
    {'label': '5.0 MB/s', 'bytes': 5 * 1024 * 1024},
    {'label': '10.0 MB/s', 'bytes': 10 * 1024 * 1024},
  ];

  static Future<int?> show(
    BuildContext context, {
    String? taskId,
    required int currentLimitBytes,
  }) {
    return showDialog<int>(
      context: context,
      builder: (ctx) => SpeedLimitDialog(
        taskId: taskId,
        currentLimitBytes: currentLimitBytes,
      ),
    );
  }

  void _selectLimit(BuildContext context, int bytes) {
    DownloadService().setSpeedLimit(
      taskId: taskId,
      bytesPerSecond: bytes,
    );
    Navigator.of(context).pop(bytes);
    final text = bytes > 0
        ? 'Speed limit set to ${_formatBytes(bytes)}/s'
        : 'Speed limit removed';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF131722) : Colors.white;
    final border = isDark ? const Color(0xFF272E3F) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final activeBg = isDark ? const Color(0xFF1E2533) : const Color(0xFFF1F5F9);

    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card * 2),
        side: BorderSide(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(PhosphorIcons.gauge, size: 22, color: textPrimary),
                const SizedBox(width: AppSpacing.x2),
                Text(
                  'Speed Throttler',
                  style: AppTypography.bodyMd.copyWith(
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(PhosphorIcons.x, size: 18, color: textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Throttle maximum download throughput rate',
              style: AppTypography.bodySm.copyWith(color: textSecondary, fontSize: 11),
            ),
            const SizedBox(height: AppSpacing.x3),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _presets.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (ctx, idx) {
                  final preset = _presets[idx];
                  final bytes = preset['bytes'] as int;
                  final label = preset['label'] as String;
                  final isSelected = currentLimitBytes == bytes;

                  return Material(
                    color: isSelected ? activeBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      onTap: () => _selectLimit(context, bytes),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          border: Border.all(
                            color: isSelected ? textPrimary : border.withAlpha(80),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: textPrimary,
                              ),
                            ),
                            if (isSelected)
                              Icon(PhosphorIcons.check, size: 16, color: textPrimary),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
