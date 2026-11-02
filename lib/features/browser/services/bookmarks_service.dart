import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/home_content_item.dart';
import '../utils/storage_persistence_helper.dart';

/// Real persistent storage service for user-saved bookmarks and folders.
/// Complies with rules.md §13, §29.2 (< 250 lines).
class BookmarksService extends ChangeNotifier {
  static final BookmarksService instance = BookmarksService._internal();

  BookmarksService._internal();

  final List<BookmarkItem> _bookmarks = [];
  static const BookmarkFolder allFolder = BookmarkFolder(id: 'all', title: 'All');

  final List<BookmarkFolder> _userFolders = [];
  bool _isInitialized = false;

  List<BookmarkItem> get bookmarks => List.unmodifiable(_bookmarks);
  
  /// Returns 'All' first, followed by all user-created folders.
  List<BookmarkFolder> get folders => [allFolder, ..._userFolders];
  List<BookmarkFolder> get userFolders => List.unmodifiable(_userFolders);
  int get count => _bookmarks.length;

  static const String _fileName = 'bookmarks.json';
  static const String _foldersFileName = 'bookmark_folders.json';

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;
    try {
      final fContent = await StoragePersistenceHelper.readData(_foldersFileName);
      if (fContent != null && fContent.trim().isNotEmpty) {
        final fDecoded = jsonDecode(fContent) as List<dynamic>;
        _userFolders.clear();
        for (final item in fDecoded) {
          if (item is Map<String, dynamic>) {
            final f = BookmarkFolder.fromJson(item);
            if (f.id != 'all' && f.id != 'all_bookmarks') {
              _userFolders.add(f);
            }
          }
        }
      }
      final content = await StoragePersistenceHelper.readData(_fileName);
      if (content != null && content.trim().isNotEmpty) {
        final decoded = jsonDecode(content) as List<dynamic>;
        _bookmarks.clear();
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            _bookmarks.add(BookmarkItem.fromJson(item));
          }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('BookmarksService.init error: $e');
    }
  }

  bool isBookmarked(String url) {
    final clean = _normalizeUrl(url);
    if (clean.isEmpty || clean == 'welcome to dab browser' || clean == 'dab.app/home') return false;
    return _bookmarks.any((b) => _normalizeUrl(b.url) == clean);
  }

  Future<bool> toggleBookmark({required String url, required String title, String folderId = 'all'}) async {
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

    _bookmarks.insert(
      0,
      BookmarkItem(
        id: 'bm-${DateTime.now().millisecondsSinceEpoch}',
        title: displayTitle,
        url: url,
        subtitle: subtitle,
        folderId: folderId,
      ),
    );
    notifyListeners();
    await _persist();
    return true;
  }

  Future<void> addFolder(String title) async {
    final id = 'folder-${DateTime.now().millisecondsSinceEpoch}';
    _userFolders.add(BookmarkFolder(id: id, title: title.trim()));
    notifyListeners();
    await _persistFolders();
  }

  Future<void> updateFolder(String id, String newTitle) async {
    if (id == 'all') return;
    final idx = _userFolders.indexWhere((f) => f.id == id);
    if (idx >= 0) {
      _userFolders[idx] = BookmarkFolder(id: id, title: newTitle.trim());
      notifyListeners();
      await _persistFolders();
    }
  }

  Future<void> deleteFolder(String id) async {
    if (id == 'all') return;
    _userFolders.removeWhere((f) => f.id == id);
    // Any bookmark in the deleted folder falls back to 'all'
    for (int i = 0; i < _bookmarks.length; i++) {
      if (_bookmarks[i].folderId == id) {
        _bookmarks[i] = _bookmarks[i].copyWith(folderId: 'all');
      }
    }
    notifyListeners();
    await _persistFolders();
    await _persist();
  }

  Future<void> updateBookmark({required String id, required String title, required String url, String? folderId}) async {
    final idx = _bookmarks.indexWhere((b) => b.id == id);
    if (idx >= 0) {
      _bookmarks[idx] = _bookmarks[idx].copyWith(
        title: title.trim(),
        url: url.trim(),
        folderId: folderId,
      );
      notifyListeners();
      await _persist();
    }
  }

  Future<void> moveBookmarks(List<String> ids, String targetFolderId) async {
    for (int i = 0; i < _bookmarks.length; i++) {
      if (ids.contains(_bookmarks[i].id)) {
        _bookmarks[i] = _bookmarks[i].copyWith(folderId: targetFolderId);
      }
    }
    notifyListeners();
    await _persist();
  }

  Future<void> removeBookmarks(List<String> ids) async {
    _bookmarks.removeWhere((b) => ids.contains(b.id));
    notifyListeners();
    await _persist();
  }

  Future<void> removeBookmark(String id) async => removeBookmarks([id]);

  Future<void> clearAll() async {
    _bookmarks.clear();
    notifyListeners();
    await _persist();
  }

  int getBookmarkCountForFolder(String folderId) {
    if (folderId == 'all') return _bookmarks.length;
    return _bookmarks.where((b) => b.folderId == folderId).length;
  }

  String _normalizeUrl(String raw) {
    var trimmed = raw.trim().toLowerCase();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  Future<void> _persist() async {
    try {
      final data = jsonEncode(_bookmarks.map((b) => b.toJson()).toList());
      await StoragePersistenceHelper.writeData(_fileName, data);
    } catch (e) {
      debugPrint('BookmarksService._persist error: $e');
    }
  }

  Future<void> _persistFolders() async {
    try {
      final data = jsonEncode(_userFolders.map((f) => f.toJson()).toList());
      await StoragePersistenceHelper.writeData(_foldersFileName, data);
    } catch (e) {
      debugPrint('BookmarksService._persistFolders error: $e');
    }
  }
}
