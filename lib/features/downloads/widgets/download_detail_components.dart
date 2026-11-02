import 'package:flutter/material.dart';

/// Reusable details row and card widgets for download details screens.
/// Complies with rules.md §13, §29.2 (< 250 lines).
class DownloadDetailComponents {
  static Widget buildSectionLabel(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11.0,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: color,
        ),
      ),
    );
  }

  static Widget buildStatBox(String caption, String value, Color fgColor, Color subColor, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F121A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Column(
          children: [
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w700, color: fgColor)),
            const SizedBox(height: 2.0),
            Text(caption, style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w700, color: subColor)),
          ],
        ),
      ),
    );
  }

  static Widget buildDetailRow(String label, String value, Color fgColor, Color subColor, {bool isPath = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w500, color: subColor)),
          const SizedBox(width: 16.0),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: isPath ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: fgColor),
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildDivider(Color color) => Divider(height: 1, thickness: 1, color: color);

  static Widget buildCircleButton(IconData icon, Color fg, bool isDark, VoidCallback onTap) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131722) : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEDF0F5)),
        ),
        child: IconButton(padding: EdgeInsets.zero, icon: Icon(icon, size: 20, color: fg), onPressed: onTap),
      );

  static Widget buildBottomActionBar({
    required BuildContext context,
    required Color scaffoldBg,
    required Color borderColor,
    required Color fgColor,
    required bool isDark,
    required bool isDownloading,
    required bool isCompleted,
    required VoidCallback onTogglePlayPause,
    required VoidCallback onShare,
    required VoidCallback onDelete,
  }) {
    return Container(
      color: scaffoldBg,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131722) : Colors.white,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionItem(
              icon: isCompleted ? Icons.refresh : (isDownloading ? Icons.pause : Icons.play_arrow),
              label: isCompleted ? 'Redownload' : (isDownloading ? 'Pause' : 'Resume'),
              color: fgColor,
              onTap: onTogglePlayPause,
            ),
            Container(width: 1, height: 28, color: borderColor),
            _buildActionItem(
              icon: Icons.share,
              label: 'Share',
              color: fgColor,
              onTap: onShare,
            ),
            Container(width: 1, height: 28, color: borderColor),
            _buildActionItem(
              icon: Icons.delete_outline,
              label: 'Delete',
              color: const Color(0xFFEF4444),
              onTap: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildActionItem({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

