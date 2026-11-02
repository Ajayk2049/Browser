import 'package:flutter/material.dart';

/// One row entry model inside a settings group card.
class SettingsRowItem {
  final IconData? icon;
  final Widget? customLeading;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const SettingsRowItem({
    this.icon,
    this.customLeading,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });
}

/// Grouped card container with 18dp rounded corners and subtle border
/// matching Figma nodes 436 / 329. Complies with rules.md §13, §29.2 (< 250 lines).
class SettingsGroupCard extends StatelessWidget {
  final List<SettingsRowItem> items;

  const SettingsGroupCard({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF131722) : const Color(0xFFFFFFFF);
    final cardBorder = isDark ? const Color(0xFF272E3F) : const Color(0xFFE2E8F0);
    final dividerColor = isDark ? const Color(0xFF1A202E) : const Color(0xFFF1F5F9);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18.0),
        border: Border.all(color: cardBorder, width: 1.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18.0),
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                Container(
                  height: 1.0,
                  margin: const EdgeInsets.only(left: 62.0, right: 12.0),
                  color: dividerColor,
                ),
              _SettingsRow(item: items[i], isDark: isDark),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final SettingsRowItem item;
  final bool isDark;

  const _SettingsRow({
    required this.item,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final iconBoxBg = isDark ? const Color(0xFF1E2433) : const Color(0xFFF1F5F9);
    final iconBoxBorder = isDark ? const Color(0xFF2A3245) : const Color(0xFFE2E8F0);
    final iconColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
          constraints: const BoxConstraints(minHeight: 64.0),
          child: Row(
            children: [
              if (item.customLeading != null)
                item.customLeading!
              else
                Container(
                  width: 38.0,
                  height: 38.0,
                  decoration: BoxDecoration(
                    color: iconBoxBg,
                    borderRadius: BorderRadius.circular(10.0),
                    border: Border.all(color: iconBoxBorder, width: 1.0),
                  ),
                  child: Center(
                    child: Icon(
                      item.icon ?? Icons.circle,
                      size: 19.0,
                      color: iconColor,
                    ),
                  ),
                ),
              const SizedBox(width: 12.0),
              // Two-line Text Column
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14.0,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      item.subtitle,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.0,
                        color: subColor,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),
              if (item.trailing != null) item.trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
