import 'package:flutter/material.dart';

enum MediaCategory { video, audio, image, document, other }

class SniffedMediaItem {
  final String id;
  final String url;
  final String title;
  final MediaCategory category;
  final int? sizeBytes;
  final String? extension;
  final String? mimeType;

  const SniffedMediaItem({
    required this.id,
    required this.url,
    required this.title,
    required this.category,
    this.sizeBytes,
    this.extension,
    this.mimeType,
  });

  String get formattedSize {
    if (sizeBytes == null || sizeBytes! <= 0) return 'Unknown size';
    const kb = 1024.0;
    const mb = kb * 1024.0;
    const gb = mb * 1024.0;
    if (sizeBytes! >= gb) return '${(sizeBytes! / gb).toStringAsFixed(2)} GB';
    if (sizeBytes! >= mb) return '${(sizeBytes! / mb).toStringAsFixed(2)} MB';
    if (sizeBytes! >= kb) return '${(sizeBytes! / kb).toStringAsFixed(1)} KB';
    return '$sizeBytes B';
  }
}

/// A 1DM+ inspired Bottom Sheet for displaying captured media links & streams
/// from web pages and webviews.
class MediaGrabberSheet extends StatefulWidget {
  final List<SniffedMediaItem> items;
  final Function(SniffedMediaItem item) onStartDownload;

  const MediaGrabberSheet({
    super.key,
    required this.items,
    required this.onStartDownload,
  });

  static void show(
    BuildContext context, {
    required List<SniffedMediaItem> items,
    required Function(SniffedMediaItem item) onStartDownload,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MediaGrabberSheet(
        items: items,
        onStartDownload: onStartDownload,
      ),
    );
  }

  @override
  State<MediaGrabberSheet> createState() => _MediaGrabberSheetState();
}

class _MediaGrabberSheetState extends State<MediaGrabberSheet> {
  MediaCategory? _selectedCategory;

  List<SniffedMediaItem> get _filteredItems {
    if (_selectedCategory == null) return widget.items;
    return widget.items.where((it) => it.category == _selectedCategory).toList();
  }

  IconData _iconForCategory(MediaCategory cat) {
    switch (cat) {
      case MediaCategory.video:
        return Icons.videocam;
      case MediaCategory.audio:
        return Icons.audiotrack;
      case MediaCategory.image:
        return Icons.image;
      case MediaCategory.document:
        return Icons.description;
      case MediaCategory.other:
        return Icons.insert_drive_file;
    }
  }

  Color _categoryColor(MediaCategory cat) {
    switch (cat) {
      case MediaCategory.video:
        return const Color(0xFFEF5350);
      case MediaCategory.audio:
        return const Color(0xFFAB47BC);
      case MediaCategory.image:
        return const Color(0xFF42A5F5);
      case MediaCategory.document:
        return const Color(0xFFFFA726);
      case MediaCategory.other:
        return const Color(0xFF78909C);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF16191D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: Colors.white24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.download_for_offline, color: Color(0xFF64B5F6)),
                const SizedBox(width: 8),
                Text(
                  'Captured Media (${widget.items.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Category filter pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedCategory == null,
                  onSelected: (_) => setState(() => _selectedCategory = null),
                  selectedColor: const Color(0xFF2E7D32),
                  backgroundColor: const Color(0xFF242A32),
                  labelStyle: TextStyle(
                    color: _selectedCategory == null ? Colors.white : Colors.white70,
                    fontSize: 12,
                  ),
                ),
                ...MediaCategory.values.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: FilterChip(
                      avatar: Icon(
                        _iconForCategory(cat),
                        size: 14,
                        color: isSelected ? Colors.white : _categoryColor(cat),
                      ),
                      label: Text(cat.name.toUpperCase()),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedCategory = cat),
                      selectedColor: _categoryColor(cat),
                      backgroundColor: const Color(0xFF242A32),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 16),
          // Media List
          Expanded(
            child: _filteredItems.isEmpty
                ? const Center(
                    child: Text(
                      'No media found for this filter',
                      style: TextStyle(color: Colors.white38),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    itemCount: _filteredItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final item = _filteredItems[idx];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF20262E),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _categoryColor(item.category).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _iconForCategory(item.category),
                                color: _categoryColor(item.category),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.formattedSize} • ${item.extension ?? 'link'}',
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E88E5),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(Icons.arrow_downward, size: 16),
                              label: const Text('Download', style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                widget.onStartDownload(item);
                                Navigator.pop(context);
                              },
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
