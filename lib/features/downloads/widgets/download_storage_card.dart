import 'package:flutter/material.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../../../theme/tokens/app_typography.dart';
import '../services/download_service.dart';

/// Real storage card displaying actual device disk space from native StatFs.
/// Complies with rules.md §13, §25.1, §25.2, §25.7, and §29.2 (< 250 lines).
class DownloadStorageCard extends StatefulWidget {
  const DownloadStorageCard({super.key});

  @override
  State<DownloadStorageCard> createState() => _DownloadStorageCardState();
}

class _DownloadStorageCardState extends State<DownloadStorageCard> {
  int _availableBytes = 0;
  int _totalBytes = 0;

  @override
  void initState() {
    super.initState();
    _fetchSpace();
  }

  Future<void> _fetchSpace() async {
    final info = await DownloadService().getDiskSpace();
    final avail = info['available'] ?? 0;
    final total = info['total'] ?? 0;
    if (mounted) {
      setState(() {
        _availableBytes = avail;
        _totalBytes = total;
      });
    }
  }

  String _formatGb(int bytes) {
    if (bytes <= 0) return '--';
    final gb = bytes / (1024 * 1024 * 1024);
    return '${gb.toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF131722) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFEDF0F5);
    final trackColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final barColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final used = (_totalBytes - _availableBytes).clamp(0, _totalBytes);
    final usedRatio = _totalBytes > 0 ? (used / _totalBytes).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4, vertical: AppSpacing.x4),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Free Space: ${_formatGb(_availableBytes)}',
                style: AppTypography.bodyMd.copyWith(
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              Text(
                '${_formatGb(_totalBytes)} Total',
                style: AppTypography.bodySm.copyWith(
                  fontWeight: FontWeight.w500,
                  color: subColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  Container(color: trackColor),
                  if (usedRatio > 0)
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: usedRatio,
                      child: Container(
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
