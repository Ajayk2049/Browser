import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../../../theme/tokens/app_typography.dart';
import '../models/home_content_item.dart';

/// Modal bottom sheet displaying bookmarks and saved reading list.
/// Complies with rules.md §13, §25.1, §25.2, §25.7, and §29.2 (< 200 lines).
class BrowserBookmarksSheet extends StatelessWidget {
  final ValueChanged<String> onSelect;
  final List<BookmarkItem> bookmarks;
  final List<BookmarkItem> savedPages;

  const BrowserBookmarksSheet({
    super.key,
    required this.onSelect,
    this.bookmarks = BookmarkItem.defaultBookmarks,
    this.savedPages = BookmarkItem.defaultSavedPages,
  });

  static Future<void> show(BuildContext context, {required ValueChanged<String> onSelect}) {
    return showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.modal)),
      ),
      builder: (_) => BrowserBookmarksSheet(onSelect: onSelect),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bookmarks & Reading List',
              style: AppTypography.displaySm.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.x3),
            ...bookmarks.map((bm) => ListTile(
              leading: const Icon(PhosphorIcons.bookmarkSimple),
              title: Text(bm.title, style: AppTypography.bodyMd),
              subtitle: Text(bm.subtitle),
              onTap: () {
                Navigator.of(context).pop();
                onSelect(bm.url);
              },
            )),
          ],
        ),
      ),
    );
  }
}

