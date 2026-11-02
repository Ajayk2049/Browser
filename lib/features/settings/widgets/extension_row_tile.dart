import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../models/web_extension_item.dart';

/// Card row widgets for Installed and Marketplace extensions.
/// Complies with rules.md §13, §25.1, §25.2, and §29.2 (< 250 lines).
class ExtensionRowTile extends StatelessWidget {
  final WebExtensionItem item;
  final bool isMarketplace;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onInstall;
  final VoidCallback? onUninstall;

  const ExtensionRowTile({
    super.key,
    required this.item,
    this.isMarketplace = false,
    this.onTap,
    this.onToggle,
    this.onInstall,
    this.onUninstall,
  });

  IconData _getExtensionIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('ublock') || lower.contains('badger') || lower.contains('privacy')) return PhosphorIcons.shieldCheck;
    if (lower.contains('dark') || lower.contains('night')) return PhosphorIcons.moon;
    if (lower.contains('search') || lower.contains('google')) return PhosphorIcons.magnifyingGlass;
    if (lower.contains('video') || lower.contains('youtube') || lower.contains('play')) return PhosphorIcons.videoCamera;
    return PhosphorIcons.puzzlePiece;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fgColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final iconBg = isDark ? const Color(0xFF1E2533) : const Color(0xFFF1F5F9);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(_getExtensionIcon(item.name), size: 20, color: fgColor),
            ),
            const SizedBox(width: 14.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, color: fgColor),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    isMarketplace
                        ? '${item.category} • ★ ${item.rating.toStringAsFixed(1)}'
                        : 'v${item.version.isNotEmpty ? item.version : "1.0.0"} • ${item.isEnabled ? "Active" : "Disabled"}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w500, color: subColor),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8.0),
            if (isMarketplace)
              _buildMarketplaceAction(isDark, fgColor)
            else
              _buildInstalledTrailing(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildInstalledTrailing(bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.scale(
          scale: 0.8,
          child: Switch(
            value: item.isEnabled,
            activeThumbColor: Colors.white,
            activeTrackColor: isDark ? const Color(0xFF3B82F6) : const Color(0xFF0F172A),
            inactiveThumbColor: isDark ? const Color(0xFF64748B) : Colors.white,
            inactiveTrackColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
            onChanged: onToggle,
          ),
        ),
        if (onUninstall != null) ...[
          const SizedBox(width: 4.0),
          IconButton(
            icon: Icon(PhosphorIcons.trash, size: 18.0, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            splashRadius: 18.0,
            tooltip: 'Remove',
            onPressed: onUninstall,
          ),
        ],
      ],
    );
  }

  Widget _buildMarketplaceAction(bool isDark, Color fgColor) {
    return InkWell(
      onTap: onInstall,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIcons.downloadSimple, size: 14, color: fgColor),
            const SizedBox(width: 4),
            Text(
              'Get',
              style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: fgColor),
            ),
          ],
        ),
      ),
    );
  }
}
