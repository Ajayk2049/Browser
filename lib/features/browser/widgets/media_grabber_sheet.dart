import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../../../theme/tokens/app_typography.dart';
import '../../downloads/widgets/add_download_dialog.dart';

class DetectedMedia {
  final String url;
  final String title;
  final String type; // 'video' | 'audio' | 'stream'

  const DetectedMedia({
    required this.url,
    required this.title,
    required this.type,
  });
}

/// 1DM+-inspired Media Grabber bottom sheet strictly following monochrome design principles.
/// Complies with rules.md §13, §25.1, §25.2, §25.7, and §29.2 (< 250 lines).
class MediaGrabberSheet extends StatefulWidget {
  final List<DetectedMedia> items;

  const MediaGrabberSheet({super.key, required this.items});

  @override
  State<MediaGrabberSheet> createState() => _MediaGrabberSheetState();
}

class _MediaGrabberSheetState extends State<MediaGrabberSheet> {
  String _selectedCategory = 'ALL';

  List<DetectedMedia> get _filteredItems {
    if (_selectedCategory == 'ALL') return widget.items;
    return widget.items.where((i) => i.type.toUpperCase() == _selectedCategory).toList();
  }

  Future<void> _startDownload(BuildContext context, DetectedMedia media) async {
    Navigator.of(context).pop();
    await AddDownloadDialog.show(context, initialUrl: media.url);
  }

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'audio':
        return PhosphorIcons.musicNotes;
      case 'stream':
        return PhosphorIcons.broadcast;
      default:
        return PhosphorIcons.filmStrip;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF131722) : Colors.white;
    final border = isDark ? const Color(0xFF272E3F) : const Color(0xFFE2E8F0);
    final cardBg = isDark ? const Color(0xFF1E2533) : const Color(0xFFF8FAFC);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final buttonBg = isDark ? Colors.white : const Color(0xFF0F172A);
    final buttonFg = isDark ? const Color(0xFF0F172A) : Colors.white;

    final categories = ['ALL', 'VIDEO', 'AUDIO', 'STREAM'];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4, vertical: 8),
            child: Row(
              children: [
                Icon(PhosphorIcons.broadcast, size: 22, color: textPrimary),
                const SizedBox(width: AppSpacing.x2),
                Text(
                  'Captured Media (${widget.items.length})',
                  style: AppTypography.bodyMd.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(PhosphorIcons.x, size: 18, color: textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          // Category filter pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4, vertical: 4),
            child: Row(
              children: categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                    selectedColor: buttonBg,
                    backgroundColor: cardBg,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? buttonFg : textSecondary,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      side: BorderSide(color: isSelected ? buttonBg : border),
                    ),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: border),
          // Stream Items
          Flexible(
            child: _filteredItems.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.x6),
                    child: Center(
                      child: Text(
                        'No media found for $_selectedCategory',
                        style: TextStyle(color: textSecondary, fontSize: 13),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.x4),
                    shrinkWrap: true,
                    itemCount: _filteredItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x2),
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];
                      final icon = _iconForType(item.type);
                      final host = Uri.tryParse(item.url)?.host ?? 'Web Media';

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF131722) : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: border),
                              ),
                              child: Icon(icon, size: 20, color: textPrimary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title.isNotEmpty ? item.title : 'Media Stream ${index + 1}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$host • ${item.type.toUpperCase()}',
                                    style: TextStyle(fontSize: 11, color: textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 34,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: buttonBg,
                                  foregroundColor: buttonFg,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(PhosphorIcons.downloadSimple, size: 16),
                                label: const Text('Download', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                onPressed: () => _startDownload(context, item),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
