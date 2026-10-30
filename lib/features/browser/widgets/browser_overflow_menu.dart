import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../../../theme/tokens/app_typography.dart';

/// Actions exposed by the browser's vertical three-dot overflow menu.
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

/// Vertical three-dot overflow menu anchored to the omnibox toolbar.
/// Visual treatment mirrors the search engine picker for consistency.
/// Complies with rules.md §13, §25.1, §25.2, §25.7, and §29.2 (< 250 lines).
class BrowserOverflowMenu extends StatelessWidget {
  final ValueChanged<BrowserMenuAction> onSelected;

  const BrowserOverflowMenu({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopupMenuButton<BrowserMenuAction>(
      tooltip: 'More options',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      elevation: 4,
      padding: EdgeInsets.zero,
      color: colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.m3Md),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      onSelected: onSelected,
      // Matches the 44dp omnibox height so the toolbar reads as one row.
      // Center keeps the glyph at its natural size: a bare SizedBox hands the
      // Icon tight 44dp constraints, and the ellipsis only inks ~22dp of that
      // box, which left the dots looking short next to the pill.
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Icon(
            PhosphorIcons.dotsThreeVertical,
            size: 28,
            color: colorScheme.onSurface,
          ),
        ),
      ),
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
          Text(
            action.label,
            style: AppTypography.bodyMd.copyWith(
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
