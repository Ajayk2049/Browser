import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../models/history_item.dart';

/// One row in a history group card matching Figma node 957 / 855.
/// Moves the timestamp to the bottom subtitle row alongside host, and adds a dedicated delete icon button.
/// Complies with rules.md §13, §29.2 (< 250 lines).
class HistoryItemTile extends StatelessWidget {
  final HistoryItem item;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const HistoryItemTile({
    super.key,
    required this.item,
    required this.isDark,
    required this.onTap,
    required this.onDelete,
  });

  String _formatTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final iconBoxBg = isDark ? const Color(0xFF1E2433) : const Color(0xFFF1F5F9);
    final iconBoxBorder = isDark ? const Color(0xFF2A3245) : const Color(0xFFE2E8F0);
    final iconTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final delColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

    final displayTitle = item.title.isNotEmpty ? item.title : item.host;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
          child: Row(
            children: [
              // Squircle Favicon / Letter container (38x38dp)
              Container(
                width: 38.0,
                height: 38.0,
                decoration: BoxDecoration(
                  color: iconBoxBg,
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(color: iconBoxBorder, width: 1.0),
                ),
                alignment: Alignment.center,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: item.host.isNotEmpty
                      ? Image.network(
                          'https://www.google.com/s2/favicons?domain=${item.host}&sz=128',
                          width: 20.0,
                          height: 20.0,
                          errorBuilder: (_, _, _) => Text(
                            item.letter,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15.0,
                              fontWeight: FontWeight.w600,
                              color: iconTextColor,
                            ),
                          ),
                        )
                      : Text(
                          item.letter,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15.0,
                            fontWeight: FontWeight.w600,
                            color: iconTextColor,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12.0),
              // Two-line Text Column (Title on top, URL • Time on bottom)
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayTitle,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14.0,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                        height: 1.25,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3.0),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.host,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11.0,
                              color: subColor,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Text(
                            '•',
                            style: TextStyle(fontSize: 10.0, color: subColor),
                          ),
                        ),
                        Text(
                          _formatTime(item.timestamp),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11.0,
                            color: subColor,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6.0),
              // Individual Delete Icon Button
              IconButton(
                icon: Icon(PhosphorIcons.trash, size: 18.0, color: delColor),
                splashRadius: 20.0,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36.0, minHeight: 36.0),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

