import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../../../theme/tokens/app_typography.dart';
import '../models/home_content_item.dart';
import 'quick_link_squircle.dart';

/// Full-fidelity start page ("Explore & Discover") matching the Figma mockup.
/// Displays user-saved bookmarks and clean empty state in production.
/// Complies with rules.md §13, §25.1, §25.2, §25.7, and §29.2 (< 250 lines).
class BrowserHomeView extends StatelessWidget {
  final ValueChanged<String> onOpenUrl;
  final VoidCallback onSeeAllBookmarks;
  final VoidCallback onAddQuickLink;
  final ValueChanged<QuickLink>? onRemoveQuickLink;
  final List<QuickLink> quickLinks;
  final List<BookmarkItem> bookmarks;
  final List<BookmarkItem> savedPages;

  const BrowserHomeView({
    super.key,
    required this.onOpenUrl,
    required this.onSeeAllBookmarks,
    required this.onAddQuickLink,
    this.onRemoveQuickLink,
    this.quickLinks = QuickLink.defaults,
    this.bookmarks = const [],
    this.savedPages = const [],
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF0C0E14) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF131722) : colorScheme.surfaceContainerLowest;
    final borderColor = isDark ? const Color(0xFF1E293B) : colorScheme.outlineVariant.withValues(alpha: 0.4);

    return Container(
      color: bgColor,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4, vertical: AppSpacing.x6),
        children: [
          Text(
            'Explore & Discover',
            style: AppTypography.displaySm.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.x4),
          _buildQuickLinksGrid(colorScheme, isDark, borderColor),
          const SizedBox(height: AppSpacing.x6),
          _buildSectionHeader(
            title: 'Bookmarks',
            trailing: TextButton(
              onPressed: onSeeAllBookmarks,
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              child: Text(
                'See all (${bookmarks.length})',
                style: AppTypography.bodyXs.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w600),
              ),
            ),
            colorScheme: colorScheme,
          ),
          const SizedBox(height: AppSpacing.x2),
          _buildCardList(
            bookmarks,
            cardBg,
            borderColor,
            colorScheme,
            PhosphorIcons.bookmarkSimple,
            'No bookmarks yet. Tap the star icon to save pages.',
          ),
          const SizedBox(height: AppSpacing.x6),
          _buildSectionHeader(
            title: 'Saved Pages',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                '${savedPages.length} saved',
                style: AppTypography.bodyXs.copyWith(
                  color: isDark ? Colors.white70 : colorScheme.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            colorScheme: colorScheme,
          ),
          const SizedBox(height: AppSpacing.x2),
          _buildCardList(
            savedPages,
            cardBg,
            borderColor,
            colorScheme,
            PhosphorIcons.article,
            'No saved offline pages yet.',
          ),
        ],
      ),
    );
  }

  Widget _buildQuickLinksGrid(ColorScheme colorScheme, bool isDark, Color borderColor) {
    final allItems = [
      ...quickLinks,
      const QuickLink(id: 'add', title: 'Add', url: '', letter: '+'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth / 4;
        return Wrap(
          runSpacing: AppSpacing.x4,
          children: [
            for (final item in allItems)
              SizedBox(
                width: itemWidth,
                child: Center(
                  child: QuickLinkSquircle(
                    item: item,
                    isDark: isDark,
                    borderColor: borderColor,
                    onTap: item.isAddButton ? onAddQuickLink : () => onOpenUrl(item.url),
                    onLongPress: item.isAddButton ? null : () => onRemoveQuickLink?.call(item),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required Widget trailing,
    required ColorScheme colorScheme,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: AppTypography.bodyLg.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        trailing,
      ],
    );
  }

  Widget _buildCardList(
    List<BookmarkItem> items,
    Color cardBg,
    Color borderColor,
    ColorScheme colorScheme,
    IconData defaultIcon,
    String emptyMessage,
  ) {
    if (items.isEmpty) {
      return Material(
        color: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: borderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4, vertical: AppSpacing.x4),
          child: Row(
            children: [
              Icon(defaultIcon, size: 20, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Text(
                  emptyMessage,
                  style: AppTypography.bodySm.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Material(
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: borderColor),
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3, vertical: 2),
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.m3Sm),
                ),
                child: Icon(defaultIcon, size: 18, color: colorScheme.onSurfaceVariant),
              ),
              title: Text(
                items[i].title,
                style: AppTypography.bodySm.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                items[i].subtitle,
                style: AppTypography.bodyXs.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
              trailing: Icon(PhosphorIcons.caretRight, size: 14, color: colorScheme.onSurfaceVariant),
              onTap: () => onOpenUrl(items[i].url),
            ),
          ],
        ],
      ),
    );
  }
}

