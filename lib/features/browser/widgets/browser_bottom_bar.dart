import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../../../theme/tokens/app_typography.dart';
import 'browser_overflow_menu.dart';

/// Floating/docked bottom action bar matching Figma "Bottom Floating Action Bar".
/// Complies with rules.md §13, §25.1, §25.2, §25.7, and §29.2 (< 250 lines).
class BrowserBottomBar extends StatelessWidget {
  final VoidCallback? onBack;
  final bool canGoBack;
  final VoidCallback onHome;
  final bool isHome;
  final VoidCallback onDownloads;
  final int activeDownloadsCount;
  final VoidCallback onBookmarks;
  final ValueChanged<BrowserMenuAction>? onMenuAction;
  final VoidCallback? onMenu;

  const BrowserBottomBar({
    super.key,
    this.onBack,
    this.canGoBack = false,
    required this.onHome,
    this.isHome = false,
    required this.onDownloads,
    this.activeDownloadsCount = 0,
    required this.onBookmarks,
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
              Expanded(
                child: _BarItem(
                  icon: PhosphorIcons.arrowLeft,
                  label: 'Back',
                  enabled: canGoBack,
                  onTap: canGoBack ? onBack : null,
                ),
              ),
              Expanded(
                child: _BarItem(
                  icon: PhosphorIcons.house,
                  label: 'Home',
                  isSelected: isHome,
                  onTap: onHome,
                ),
              ),
              Expanded(
                child: _BarItem(
                  icon: PhosphorIcons.downloadSimple,
                  label: 'Downloads',
                  badgeCount: activeDownloadsCount > 0 ? activeDownloadsCount : null,
                  onTap: onDownloads,
                ),
              ),
              Expanded(
                child: _BarItem(
                  icon: PhosphorIcons.bookmarkSimple,
                  label: 'Saved',
                  onTap: onBookmarks,
                ),
              ),
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
}

class _BarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final bool isSelected;
  final int? badgeCount;
  final VoidCallback? onTap;

  const _BarItem({
    required this.icon,
    required this.label,
    this.enabled = true,
    this.isSelected = false,
    this.badgeCount,
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
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, size: 22, color: itemColor),
              if (badgeCount != null)
                Positioned(
                  top: -4,
                  right: -8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: AppTypography.bodyXs.copyWith(
                        color: colorScheme.onPrimary,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
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
