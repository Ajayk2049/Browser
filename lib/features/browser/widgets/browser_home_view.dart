import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../../../theme/tokens/app_typography.dart';
import '../models/home_content_item.dart';

/// Full-fidelity start page ("Explore & Discover") matching the Figma mockup.
/// Complies with rules.md §13, §25.1, §25.2, §25.7, and §29.2 (< 250 lines).
class BrowserHomeView extends StatelessWidget {
  final ValueChanged<String> onOpenUrl;
  final VoidCallback onSeeAllBookmarks;
  final VoidCallback onAddQuickLink;
  final List<QuickLink> quickLinks;
  final List<BookmarkItem> bookmarks;
  final List<BookmarkItem> savedPages;

  const BrowserHomeView({
    super.key,
    required this.onOpenUrl,
    required this.onSeeAllBookmarks,
    required this.onAddQuickLink,
    this.quickLinks = QuickLink.defaults,
    this.bookmarks = BookmarkItem.defaultBookmarks,
    this.savedPages = BookmarkItem.defaultSavedPages,
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
          _buildQuickLinksRow(colorScheme, isDark, borderColor),
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
          _buildCardList(bookmarks, cardBg, borderColor, colorScheme, PhosphorIcons.globe),
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
                '${savedPages.length} unread',
                style: AppTypography.bodyXs.copyWith(color: colorScheme.onSurfaceVariant, fontSize: 11),
              ),
            ),
            colorScheme: colorScheme,
          ),
          const SizedBox(height: AppSpacing.x2),
          _buildCardList(savedPages, cardBg, borderColor, colorScheme, PhosphorIcons.fileText),
          const SizedBox(height: 80), // Bottom padding for floating navigation bar
        ],
      ),
    );
  }

  Widget _buildQuickLinksRow(ColorScheme colorScheme, bool isDark, Color borderColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: quickLinks.map((link) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x1),
            child: InkWell(
              onTap: () => link.isAddButton ? onAddQuickLink() : onOpenUrl(link.url),
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161B26) : colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        link.letter,
                        style: AppTypography.displaySm.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: link.isAddButton ? colorScheme.onSurfaceVariant : colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  Text(
                    link.title,
                    style: AppTypography.bodyXs.copyWith(
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required Widget trailing,
    required ColorScheme colorScheme,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: AppTypography.bodyMd.copyWith(
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
  ) {
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
