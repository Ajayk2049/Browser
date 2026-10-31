import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../../../theme/tokens/app_typography.dart';
import 'browser_overflow_menu.dart';

/// Floating/docked bottom action bar matching user layout specifications:
/// 1. Forward, 2. Share, 3. Home (centered), 4. Tabs, 5. Menu.
/// Complies with rules.md §13, §25.1, §25.2, §25.7, and §29.2 (< 250 lines).
class BrowserBottomBar extends StatelessWidget {
  final VoidCallback? onForward;
  final bool canGoForward;
  final VoidCallback onShare;
  final VoidCallback onHome;
  final bool isHome;
  final int tabCount;
  final VoidCallback onOpenTabs;
  final ValueChanged<BrowserMenuAction>? onMenuAction;
  final VoidCallback? onMenu;

  const BrowserBottomBar({
    super.key,
    this.onForward,
    this.canGoForward = false,
    required this.onShare,
    required this.onHome,
    this.isHome = false,
    this.tabCount = 1,
    required this.onOpenTabs,
    this.onMenuAction,
    this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final barColor = isDark
        ? const Color(0xFF131620)
        : colorScheme.surfaceContainerLowest;
    final borderColor = isDark
        ? const Color(0xFF1E293B)
        : colorScheme.outlineVariant.withValues(alpha: 0.5);

    return Container(
      decoration: BoxDecoration(
        color: barColor,
        border: Border(top: BorderSide(color: borderColor, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // 1. Forward button
              Expanded(
                child: _BarItem(
                  icon: PhosphorIcons.arrowRight,
                  label: 'Forward',
                  enabled: canGoForward,
                  onTap: canGoForward ? onForward : null,
                ),
              ),
              // 2. Share button
              Expanded(
                child: _BarItem(
                  icon: PhosphorIcons.shareNetwork,
                  label: 'Share',
                  onTap: onShare,
                ),
              ),
              // 3. Home button in Center
              Expanded(
                child: _BarItem(
                  icon: PhosphorIcons.house,
                  label: 'Home',
                  isSelected: isHome,
                  onTap: onHome,
                ),
              ),
              // 4. Tabs button
              Expanded(
                child: _BarItem(
                  customIcon: _buildTabChip(colorScheme, isDark),
                  label: 'Tabs',
                  onTap: onOpenTabs,
                ),
              ),
              // 5. Menu button
              Expanded(
                child: onMenuAction != null
                    ? BrowserMenuPopup(
                        onSelected: onMenuAction!,
                        child: const _BarItem(
                          icon: PhosphorIcons.list,
                          label: 'Menu',
                        ),
                      )
                    : _BarItem(
                        icon: PhosphorIcons.list,
                        label: 'Menu',
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
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: colorScheme.onSurfaceVariant,
          width: 1.6,
        ),
      ),
      child: Text(
        '$tabCount',
        style: AppTypography.bodyXs.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurfaceVariant,
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
  final VoidCallback? onTap;

  const _BarItem({
    this.icon,
    this.customIcon,
    required this.label,
    this.enabled = true,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final itemColor = !enabled
        ? colorScheme.onSurface.withValues(alpha: 0.3)
        : isSelected
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant;

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
