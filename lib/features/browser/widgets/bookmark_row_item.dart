import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../models/home_content_item.dart';

/// Row widget rendering a single bookmark folder in the Folders group.
/// Highlights when selected, allows editing/deleting custom folders, keeps 'All' permanent.
/// Complies with rules.md §13, §29.2 (< 250 lines).
class BookmarkFolderRow extends StatelessWidget {
  final BookmarkFolder folder;
  final int count;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const BookmarkFolderRow({
    super.key,
    required this.folder,
    required this.count,
    this.isSelected = false,
    required this.isDark,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  bool get isPermanent => folder.id == 'all';

  @override
  Widget build(BuildContext context) {
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    const subColor = Color(0xFF64748B);
    final selectedBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

    return Material(
      color: isSelected ? selectedBg : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
          child: Row(
            children: [
              Container(
                width: 38.0,
                height: 38.0,
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
                      : (isDark ? const Color(0xFF1E2433) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(
                    color: isSelected
                        ? (isDark ? Colors.white54 : const Color(0xFF0F172A))
                        : (isDark ? const Color(0xFF2A3245) : const Color(0xFFE2E8F0)),
                  ),
                ),
                child: Icon(
                  isPermanent ? PhosphorIcons.bookmarks : PhosphorIcons.folder,
                  size: 19.0,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder.title,
                      style: TextStyle(
                        fontSize: 14.0,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text('$count bookmarks', style: const TextStyle(fontSize: 11.0, color: subColor)),
                  ],
                ),
              ),
              if (!isPermanent && (onEdit != null || onDelete != null))
                PopupMenuButton<String>(
                  icon: const Icon(PhosphorIcons.dotsThreeVertical, size: 18.0, color: subColor),
                  onSelected: (val) {
                    if (val == 'edit') onEdit?.call();
                    if (val == 'delete') onDelete?.call();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(PhosphorIcons.pencilSimple, size: 16),
                          SizedBox(width: 8),
                          Text('Edit name'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(PhosphorIcons.trash, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete folder', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                )
              else if (isSelected)
                const Icon(PhosphorIcons.check, size: 18.0, color: Color(0xFF3B82F6))
              else
                const Icon(PhosphorIcons.caretRight, size: 16.0, color: subColor),
            ],
          ),
        ),
      ),
    );
  }
}

/// Row widget rendering a single bookmark entry with favicon and multi-select support.
/// Complies with rules.md §13, §29.2 (< 250 lines).
class BookmarkItemRow extends StatelessWidget {
  final BookmarkItem item;
  final bool isSelected;
  final bool isSelectionMode;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const BookmarkItemRow({
    super.key,
    required this.item,
    required this.isSelected,
    required this.isSelectionMode,
    required this.isDark,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    const subColor = Color(0xFF64748B);
    final host = Uri.tryParse(item.url)?.host ?? '';
    final letter = item.title.isNotEmpty ? item.title[0].toUpperCase() : 'B';

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
        child: Row(
          children: [
            Container(
              width: 38.0,
              height: 38.0,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2433) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(color: isDark ? const Color(0xFF2A3245) : const Color(0xFFE2E8F0)),
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: host.isNotEmpty
                  ? Image.network(
                      'https://www.google.com/s2/favicons?domain=$host&sz=128',
                      width: 22,
                      height: 22,
                      errorBuilder: (_, _, _) => Text(
                        letter,
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: titleColor),
                      ),
                    )
                  : Text(letter, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: titleColor)),
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600, color: titleColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    item.subtitle.isNotEmpty ? item.subtitle : item.url,
                    style: const TextStyle(fontSize: 11.0, color: subColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isSelectionMode)
              Container(
                width: 22.0,
                height: 22.0,
                decoration: BoxDecoration(
                  color: isSelected ? (isDark ? Colors.white : const Color(0xFF0F172A)) : Colors.transparent,
                  shape: BoxShape.circle,
                  border: isSelected ? null : Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                ),
                child: isSelected
                    ? Icon(PhosphorIcons.check, size: 14.0, color: isDark ? const Color(0xFF0F172A) : Colors.white)
                    : null,
              )
            else
              const Icon(PhosphorIcons.caretRight, size: 16.0, color: subColor),
          ],
        ),
      ),
    );
  }
}
