import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/home_content_item.dart';

/// Real persistent storage service for user-saved bookmarks.
/// Persists entries to local JSON disk storage and notifies reactive listeners.
/// Complies with rules.md §13, §25.1, §25.2, §25.7, and §29.2 (< 250 lines).
class BookmarksService extends ChangeNotifier {
  static final BookmarksService instance = BookmarksService._internal();

  BookmarksService._internal();

  final List<BookmarkItem> _bookmarks = [];
  bool _isInitialized = false;

  List<BookmarkItem> get bookmarks => List.unmodifiable(_bookmarks);
  int get count => _bookmarks.length;

  /// Loads bookmarks from disk if not yet initialized.
  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;
    try {
      final file = await _getStorageFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content) as List<dynamic>;
          _bookmarks.clear();
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              _bookmarks.add(BookmarkItem.fromJson(item));
            }
          }
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('BookmarksService.init error: $e');
    }
  }

  /// Checks if a URL is already saved in bookmarks.
  bool isBookmarked(String url) {
    final clean = _normalizeUrl(url);
    if (clean.isEmpty || clean == 'welcome to dab browser' || clean == 'dab.app/home') return false;
    return _bookmarks.any((b) => _normalizeUrl(b.url) == clean);
  }

  /// Toggles bookmark state for [url]. Returns true if added, false if removed.
  Future<bool> toggleBookmark({required String url, required String title}) async {
    final clean = _normalizeUrl(url);
    if (clean.isEmpty || clean == 'welcome to dab browser' || clean == 'dab.app/home') return false;

    final existingIndex = _bookmarks.indexWhere((b) => _normalizeUrl(b.url) == clean);
    if (existingIndex >= 0) {
      _bookmarks.removeAt(existingIndex);
      notifyListeners();
      await _persist();
      return false;
    }

    final host = Uri.tryParse(url)?.host ?? '';
    final displayTitle = title.trim().isNotEmpty ? title.trim() : (host.isNotEmpty ? host : url);
    final subtitle = host.isNotEmpty ? host : 'Saved page';

    final newItem = BookmarkItem(
      id: 'bm-${DateTime.now().millisecondsSinceEpoch}',
      title: displayTitle,
      url: url,
      subtitle: subtitle,
    );

    _bookmarks.insert(0, newItem);
    notifyListeners();
    await _persist();
    return true;
  }

  /// Removes a bookmark by its unique [id].
  Future<void> removeBookmark(String id) async {
    _bookmarks.removeWhere((b) => b.id == id);
    notifyListeners();
    await _persist();
  }

  /// Clears all bookmarks.
  Future<void> clearAll() async {
    _bookmarks.clear();
    notifyListeners();
    await _persist();
  }

  @visibleForTesting
  void setBookmarksForTesting(List<BookmarkItem> items) {
    _bookmarks.clear();
    _bookmarks.addAll(items);
    _isInitialized = true;
    notifyListeners();
  }

  String _normalizeUrl(String raw) {
    var trimmed = raw.trim().toLowerCase();
    if (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  Future<File> _getStorageFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/bookmarks.json');
  }

  Future<void> _persist() async {
    try {
      final file = await _getStorageFile();
      final data = jsonEncode(_bookmarks.map((b) => b.toJson()).toList());
      await file.writeAsString(data);
    } catch (e) {
      debugPrint('BookmarksService._persist error: $e');
    }
  }
}

