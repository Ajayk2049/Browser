import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../../../theme/tokens/app_typography.dart';

/// Actions exposed by the browser's menu.
/// Each action owns its label and Phosphor icon so the menu and the handler
/// cannot drift apart.
enum BrowserMenuAction {
  share(PhosphorIcons.shareNetwork, 'Share'),
  bookmarkPage(PhosphorIcons.bookmarkSimple, 'Bookmark page'),
  findInPage(PhosphorIcons.magnifyingGlassPlus, 'Find in page'),
  history(PhosphorIcons.clockCounterClockwise, 'History'),
  bookmarks(PhosphorIcons.bookmarksSimple, 'Bookmarks'),
  downloadManager(PhosphorIcons.downloadSimple, 'Download Manager'),
  settings(PhosphorIcons.gearSix, 'Settings');

  const BrowserMenuAction(this.icon, this.label);

  final IconData icon;
  final String label;
}

/// Material 3 Expressive popup menu of browser actions anchored to a child widget.
/// Used by the bottom bar's Menu button to present browser actions.
/// Complies with rules.md §13, §25.1, §25.2, §25.7, and §29.2 (< 250 lines).
class BrowserMenuPopup extends StatelessWidget {
  final ValueChanged<BrowserMenuAction> onSelected;
  final Widget child;

  const BrowserMenuPopup({
    super.key,
    required this.onSelected,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final menuColor = isDark
        ? const Color(0xFF1E2433)
        : colorScheme.surfaceContainerLowest;
    final borderColor = isDark
        ? const Color(0xFF2D3748)
        : colorScheme.outlineVariant.withValues(alpha: 0.5);

    return PopupMenuButton<BrowserMenuAction>(
      tooltip: 'Menu',
      position: PopupMenuPosition.over,
      offset: const Offset(0, -8),
      elevation: 6,
      padding: EdgeInsets.zero,
      color: menuColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.m3Md),
        side: BorderSide(color: borderColor),
      ),
      onSelected: onSelected,
      itemBuilder: (context) => [
        _item(context, BrowserMenuAction.share),
        _item(context, BrowserMenuAction.bookmarkPage),
        _item(context, BrowserMenuAction.findInPage),
        const PopupMenuDivider(height: 1),
        _item(context, BrowserMenuAction.history),
        _item(context, BrowserMenuAction.bookmarks),
        _item(context, BrowserMenuAction.downloadManager),
        const PopupMenuDivider(height: 1),
        _item(context, BrowserMenuAction.settings),
      ],
      child: child,
    );
  }

  PopupMenuItem<BrowserMenuAction> _item(
    BuildContext context,
    BrowserMenuAction action,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopupMenuItem<BrowserMenuAction>(
      value: action,
      height: 44,
      child: Row(
        children: [
          Icon(action.icon, size: 20, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Text(
              action.label,
              style: AppTypography.bodyMd.copyWith(
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Backwards-compatibility alias.
typedef BrowserOverflowMenu = BrowserMenuPopup;
