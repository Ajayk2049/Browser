import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../utils/storage_persistence_helper.dart';

/// Represents a persistent tab record for session restoration.
/// Complies with rules.md §13, §29.1, §29.2 (< 200 lines).
class TabPersistenceRecord {
  final String id;
  final String url;
  final String title;

  const TabPersistenceRecord({
    required this.id,
    required this.url,
    required this.title,
  });

  Map<String, dynamic> toJson() => {'id': id, 'url': url, 'title': title};

  factory TabPersistenceRecord.fromJson(Map<String, dynamic> json) => TabPersistenceRecord(
        id: json['id'] as String? ?? '',
        url: json['url'] as String? ?? '',
        title: json['title'] as String? ?? '',
      );
}

/// Service managing persistent tab sessions across app restarts.
class TabPersistenceService {
  static final TabPersistenceService instance = TabPersistenceService._internal();

  TabPersistenceService._internal();

  static const String _fileName = 'tabs_session.json';

  Future<List<TabPersistenceRecord>> loadSavedTabs() async {
    try {
      final content = await StoragePersistenceHelper.readData(_fileName);
      if (content != null && content.isNotEmpty) {
        final decoded = jsonDecode(content) as List<dynamic>;
        return decoded
            .whereType<Map<String, dynamic>>()
            .map((m) => TabPersistenceRecord.fromJson(m))
            .where((t) => t.url.isNotEmpty && t.url != 'Welcome to Dab Browser' && t.url != 'dab.app/home')
            .toList();
      }
    } catch (e) {
      debugPrint('TabPersistenceService.loadSavedTabs error: $e');
    }
    return [];
  }

  Future<void> saveTabs(List<TabPersistenceRecord> tabs) async {
    try {
      final valid = tabs.where((t) => t.url.isNotEmpty && t.url != 'Welcome to Dab Browser' && t.url != 'dab.app/home').toList();
      final data = jsonEncode(valid.map((t) => t.toJson()).toList());
      await StoragePersistenceHelper.writeData(_fileName, data);
    } catch (e) {
      debugPrint('TabPersistenceService.saveTabs error: $e');
    }
  }
}

