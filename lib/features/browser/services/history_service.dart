import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/history_item.dart';
import '../utils/storage_persistence_helper.dart';

/// Real persistent storage service for browser history.
/// Saves visited pages, supports full wipe and individual item deletion.
/// Dual-mirrors to persistent storage so history survives APK re-installs.
/// Complies with rules.md §13, §29.2 (< 250 lines).
class HistoryService extends ChangeNotifier {
  static final HistoryService instance = HistoryService._internal();

  HistoryService._internal();

  static const String _fileName = 'history.json';
  final List<HistoryItem> _items = [];
  bool _isInitialized = false;

  List<HistoryItem> get items => List.unmodifiable(_items);
  int get count => _items.length;

  static String normalizeUrl(String raw) {
    try {
      final uri = Uri.parse(raw.trim());
      // Rebuild normalized URL: lower-case scheme and host, stripped trailing slash on path
      var path = uri.path;
      while (path.endsWith('/') && path.length > 1) {
        path = path.substring(0, path.length - 1);
      }
      if (path == '/') path = '';

      var query = uri.hasQuery ? '?${uri.query}' : '';
      return '${uri.scheme.toLowerCase()}://${uri.host.toLowerCase()}${uri.hasPort ? ':${uri.port}' : ''}$path$query';
    } catch (_) {
      var u = raw.trim().toLowerCase();
      while (u.endsWith('/')) {
        u = u.substring(0, u.length - 1);
      }
      return u;
    }
  }

  static bool isHomeUrl(String raw) {
    final lower = raw.trim().toLowerCase();
    return lower.isEmpty ||
        lower == 'welcome to dab browser' ||
        lower == 'dab.app/home' ||
        lower.contains('dab.app') ||
        lower.startsWith('about:blank') ||
        lower.startsWith('about:home');
  }

  /// Loads history from local disk or backup if not yet loaded.
  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;
    try {
      final content = await StoragePersistenceHelper.readData(_fileName);
      if (content != null && content.trim().isNotEmpty) {
        final decoded = jsonDecode(content) as List<dynamic>;
        _items.clear();
        final seenUrls = <String>{};
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            final parsed = HistoryItem.fromJson(item);
            final norm = normalizeUrl(parsed.url);
            if (!isHomeUrl(norm) && seenUrls.add(norm)) {
              _items.add(parsed);
            }
          }
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('HistoryService.init error: $e');
    }
  }

  /// Adds a new page visit to history.
  Future<void> recordVisit({required String url, required String title}) async {
    final clean = url.trim();
    if (isHomeUrl(clean)) return;

    final norm = normalizeUrl(clean);

    String displayTitle;
    final cleanTitle = title.trim();
    if (cleanTitle.isNotEmpty &&
        cleanTitle.toLowerCase() != 'home' &&
        cleanTitle.toLowerCase() != 'welcome to dab browser' &&
        cleanTitle.toLowerCase() != 'explore & discover') {
      displayTitle = cleanTitle;
    } else {
      final host = Uri.tryParse(clean)?.host ?? '';
      displayTitle = host.isNotEmpty ? host : clean;
    }

    // Check if the entry already exists
    final existingIndex = _items.indexWhere((h) => normalizeUrl(h.url) == norm);
    if (existingIndex >= 0) {
      final existing = _items[existingIndex];
      // Update existing entry with better title or updated time, without creating a second item
      _items.removeAt(existingIndex);
      final updated = HistoryItem(
        id: existing.id,
        title: (displayTitle.isNotEmpty && displayTitle != clean) ? displayTitle : existing.title,
        url: clean,
        timestamp: DateTime.now(),
      );
      _items.insert(0, updated);
    } else {
      final newItem = HistoryItem(
        id: 'h-${DateTime.now().millisecondsSinceEpoch}',
        title: displayTitle,
        url: clean,
        timestamp: DateTime.now(),
      );
      _items.insert(0, newItem);
    }
    notifyListeners();
    await _persist();
  }

  /// Removes an individual history item by its unique [id].
  Future<void> removeItem(String id) async {
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
    await _persist();
  }

  /// Completely wipes all history.
  Future<void> clearAll() async {
    _items.clear();
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final data = jsonEncode(_items.map((i) => i.toJson()).toList());
      await StoragePersistenceHelper.writeData(_fileName, data);
    } catch (e) {
      debugPrint('HistoryService._persist error: $e');
    }
  }
}

