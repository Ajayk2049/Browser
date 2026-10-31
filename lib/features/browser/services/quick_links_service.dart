import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/home_content_item.dart';

/// Real persistent storage service for user-customizable home quick links.
/// Persists entries to local JSON disk storage and notifies reactive listeners.
/// Complies with rules.md §13, §25.1, §25.2, §25.7, and §29.2 (< 250 lines).
class QuickLinksService extends ChangeNotifier {
  static final QuickLinksService instance = QuickLinksService._internal();

  QuickLinksService._internal();

  final List<QuickLink> _quickLinks = [];
  bool _isInitialized = false;

  List<QuickLink> get quickLinks => List.unmodifiable(_quickLinks);
  int get count => _quickLinks.length;

  /// Loads quick links from local disk or seeds defaults on first run.
  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;
    try {
      final file = await _getStorageFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content) as List<dynamic>;
          _quickLinks.clear();
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              _quickLinks.add(QuickLink.fromJson(item));
            }
          }
          notifyListeners();
          return;
        }
      }
    } catch (e) {
      debugPrint('QuickLinksService.init error: $e');
    }
    // Seed defaults if fresh installation
    if (_quickLinks.isEmpty) {
      _quickLinks.addAll(QuickLink.defaults);
      notifyListeners();
      await _persist();
    }
  }

  /// Adds a custom user quick link with automatic URL and icon normalization.
  Future<QuickLink?> addQuickLink({
    required String title,
    required String url,
  }) async {
    final cleanUrl = _normalizeUrl(url);
    if (cleanUrl.isEmpty) return null;

    final host = Uri.tryParse(cleanUrl)?.host ?? '';
    final cleanTitle = title.trim().isNotEmpty
        ? title.trim()
        : (host.isNotEmpty ? host : cleanUrl);
    final letter = cleanTitle.isNotEmpty ? cleanTitle[0].toUpperCase() : '?';

    final item = QuickLink(
      id: 'ql-${DateTime.now().millisecondsSinceEpoch}',
      title: cleanTitle,
      url: cleanUrl,
      letter: letter,
    );

    _quickLinks.add(item);
    notifyListeners();
    await _persist();
    return item;
  }

  /// Removes a quick link by its unique [id].
  Future<void> removeQuickLink(String id) async {
    _quickLinks.removeWhere((item) => item.id == id);
    notifyListeners();
    await _persist();
  }

  /// Resets quick links back to application defaults.
  Future<void> resetToDefaults() async {
    _quickLinks.clear();
    _quickLinks.addAll(QuickLink.defaults);
    notifyListeners();
    await _persist();
  }

  @visibleForTesting
  void setQuickLinksForTesting(List<QuickLink> items) {
    _quickLinks.clear();
    _quickLinks.addAll(items);
    _isInitialized = true;
    notifyListeners();
  }

  String _normalizeUrl(String raw) {
    var trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'https://$trimmed';
    }
    return trimmed;
  }

  Future<File> _getStorageFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/quick_links.json');
  }

  Future<void> _persist() async {
    try {
      final file = await _getStorageFile();
      final data = jsonEncode(_quickLinks.map((q) => q.toJson()).toList());
      await file.writeAsString(data);
    } catch (e) {
      debugPrint('QuickLinksService._persist error: $e');
    }
  }
}

