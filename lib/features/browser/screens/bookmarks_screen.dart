import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../../../theme/tokens/app_typography.dart';
import '../models/home_content_item.dart';
import '../services/bookmarks_service.dart';

/// Full-screen dedicated Bookmarks management screen.
/// Replaces the legacy modal bottom sheet with a production-grade interface.
/// Complies with rules.md §13, §25.1, §25.2, §25.7, and §29.2 (< 300 lines).
class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final service = BookmarksService.instance;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Bookmarks',
          style: AppTypography.displaySm.copyWith(fontWeight: FontWeight.w700),
        ),
        actions: [
          ListenableBuilder(
            listenable: service,
            builder: (context, _) {
              if (service.bookmarks.isEmpty) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Clear All',
                icon: Icon(PhosphorIcons.trash, color: colorScheme.onSurfaceVariant),
                onPressed: () => _confirmClearAll(context, service),
              );
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: service,
        builder: (context, _) {
          final items = service.bookmarks;
          if (items.isEmpty) {
            return _buildEmptyState(colorScheme);
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x4,
              vertical: AppSpacing.x3,
            ),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.x2),
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildBookmarkTile(context, item, colorScheme, isDark, service);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                PhosphorIcons.bookmarkSimple,
                size: 40,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: AppSpacing.x4),
            Text(
              'No bookmarks yet',
              style: AppTypography.bodyLg.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.x2),
            Text(
              'Tap the star button in the address bar to save pages here for easy access.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookmarkTile(
    BuildContext context,
    BookmarkItem item,
    ColorScheme colorScheme,
    bool isDark,
    BookmarksService service,
  ) {
    final cardBg = isDark ? const Color(0xFF131722) : colorScheme.surfaceContainerLowest;
    final borderColor = isDark ? const Color(0xFF1E293B) : colorScheme.outlineVariant.withValues(alpha: 0.4);

    return Material(
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.m3Md),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(item.url),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x3,
            vertical: AppSpacing.x3,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppRadius.m3Sm),
                ),
                child: Icon(
                  PhosphorIcons.globeSimple,
                  size: 22,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: AppTypography.bodyMd.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle.isNotEmpty ? item.subtitle : item.url,
                      style: AppTypography.bodySm.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                iconSize: 18,
                tooltip: 'Remove',
                icon: Icon(
                  PhosphorIcons.trash,
                  size: 18,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                onPressed: () => service.removeBookmark(item.id),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmClearAll(BuildContext context, BookmarksService service) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Clear all bookmarks?'),
        content: const Text('This will remove all saved bookmarks. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              service.clearAll();
            },
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
  }
}

