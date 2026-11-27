import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../../../theme/tokens/app_typography.dart';
import 'browser_overflow_menu.dart';

/// Floating/docked bottom action bar matching user layout specifications:
/// 1. Share, 2. Home, 3. Downloads (centered), 4. Tabs, 5. New Tab, 6. Menu.
/// Complies with rules.md §13, §25.1, §25.2, §25.7, and §29.2 (< 250 lines).
class BrowserBottomBar extends StatelessWidget {
  final VoidCallback? onForward;
  final bool canGoForward;
  final VoidCallback onShare;
  final bool canShare;
  final VoidCallback onHome;
  final bool isHome;
  final VoidCallback? onDownloads;
  final int tabCount;
  final VoidCallback onOpenTabs;
  final VoidCallback? onNewTab;
  final ValueChanged<BrowserMenuAction>? onMenuAction;
  final VoidCallback? onMenu;
  final bool isPrivate;

  const BrowserBottomBar({
    super.key,
    this.onForward,
    this.canGoForward = false,
    required this.onShare,
    this.canShare = false,
    required this.onHome,
    this.isHome = false,
    this.onDownloads,
    this.tabCount = 1,
    required this.onOpenTabs,
    this.onNewTab,
    this.onMenuAction,
    this.onMenu,
    this.isPrivate = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final darkStyle = isDark || isPrivate;

    final barColor = darkStyle ? const Color(0xFF131620) : colorScheme.surfaceContainerLowest;
    final borderColor = isPrivate
        ? Colors.white.withValues(alpha: 0.6)
        : (isDark ? const Color(0xFF1E293B) : colorScheme.outlineVariant.withValues(alpha: 0.5));

    return Container(
      decoration: BoxDecoration(
        color: barColor,
        border: Border(top: BorderSide(color: borderColor, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // 1. Share button (left)
              Expanded(
                child: _BarItem(
                  icon: PhosphorIcons.shareNetwork,
                  label: 'Share',
                  enabled: canShare,
                  darkStyle: darkStyle,
                  onTap: canShare ? onShare : null,
                ),
              ),
              // 2. Home button (left)
              Expanded(
                child: _BarItem(
                  icon: PhosphorIcons.house,
                  label: 'Home',
                  isSelected: isHome,
                  darkStyle: darkStyle,
                  onTap: onHome,
                ),
              ),
              // 3. Download Manager button (center)
              Expanded(
                child: _BarItem(
                  icon: PhosphorIcons.downloadSimple,
                  label: 'Downloads',
                  darkStyle: darkStyle,
                  onTap: onDownloads,
                ),
              ),
              // 4. Tabs button
              Expanded(
                child: _BarItem(
                  customIcon: _buildTabChip(colorScheme, isDark),
                  label: 'Tabs',
                  darkStyle: darkStyle,
                  onTap: onOpenTabs,
                ),
              ),
              // 5. New Tab button (+)
              Expanded(
                child: _BarItem(
                  icon: PhosphorIcons.plus,
                  label: 'New Tab',
                  darkStyle: darkStyle,
                  onTap: onNewTab,
                ),
              ),
              // 6. Menu button
              Expanded(
                child: onMenuAction != null
                    ? BrowserMenuPopup(
                        onSelected: onMenuAction!,
                        canGoForward: canGoForward,
                        child: _BarItem(
                          icon: PhosphorIcons.list,
                          label: 'Menu',
                          darkStyle: darkStyle,
                        ),
                      )
                    : _BarItem(
                        icon: PhosphorIcons.list,
                        label: 'Menu',
                        darkStyle: darkStyle,
                        onTap: onMenu,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabChip(ColorScheme colorScheme, bool isDark) {
    final chipColor = isPrivate ? Colors.white : colorScheme.onSurfaceVariant;
    final chipBorder = isPrivate ? Colors.white : colorScheme.onSurfaceVariant;
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: chipBorder, width: 1.6),
      ),
      child: Text(
        '$tabCount',
        style: AppTypography.bodyXs.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: chipColor,
          height: 1,
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  final IconData? icon;
  final Widget? customIcon;
  final String label;
  final bool enabled;
  final bool isSelected;
  final bool darkStyle;
  final VoidCallback? onTap;

  const _BarItem({
    this.icon,
    this.customIcon,
    required this.label,
    this.enabled = true,
    this.isSelected = false,
    this.darkStyle = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseVariant = darkStyle ? const Color(0xFFCBD5E1) : colorScheme.onSurfaceVariant;
    final itemColor = !enabled
        ? (darkStyle ? Colors.white38 : colorScheme.onSurface.withValues(alpha: 0.3))
        : isSelected
            ? (darkStyle ? Colors.white : colorScheme.primary)
            : baseVariant;

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x1),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (customIcon != null)
            customIcon!
          else if (icon != null)
            Icon(icon, size: 22, color: itemColor),
          const SizedBox(height: 3),
          Text(
            label,
            style: AppTypography.bodyXs.copyWith(
              color: itemColor,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.m3Sm),
      child: content,
    );
  }
}
