import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../../../theme/tokens/app_typography.dart';

/// Actions exposed by the browser's vertical three-dot overflow menu.
enum BrowserMenuAction {
  share,
  bookmarkPage,
  findInPage,
  history,
  bookmarks,
  settings,
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
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(
          PhosphorIcons.dotsThreeVertical,
          size: 22,
          color: colorScheme.onSurface,
        ),
      ),
      itemBuilder: (context) => [
        _item(BrowserMenuAction.share, PhosphorIcons.shareNetwork, 'Share'),
        _item(BrowserMenuAction.bookmarkPage, PhosphorIcons.bookmarkSimple, 'Bookmark page'),
        _item(BrowserMenuAction.findInPage, PhosphorIcons.magnifyingGlassPlus, 'Find in page'),
        const PopupMenuDivider(height: 1),
        _item(BrowserMenuAction.history, PhosphorIcons.clockCounterClockwise, 'History'),
        _item(BrowserMenuAction.bookmarks, PhosphorIcons.bookmarksSimple, 'Bookmarks'),
        const PopupMenuDivider(height: 1),
        _item(BrowserMenuAction.settings, PhosphorIcons.gearSix, 'Settings'),
      ],
    );
  }

  PopupMenuItem<BrowserMenuAction> _item(
    BrowserMenuAction action,
    IconData icon,
    String label,
  ) {
    return PopupMenuItem<BrowserMenuAction>(
      value: action,
      height: 44,
      child: Row(
        children: [
          Builder(
            builder: (context) => Icon(
              icon,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          Builder(
            builder: (context) => Text(
              label,
              style: AppTypography.bodyMd.copyWith(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
