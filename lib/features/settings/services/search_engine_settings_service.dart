import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../browser/models/search_engine.dart';
import '../../browser/utils/storage_persistence_helper.dart';

/// Persistent model for search engine preferences.
/// Complies with rules.md §13, §29.2 (< 200 lines).
class SearchEngineSettingsModel {
  final SearchEngine defaultEngine;
  final bool searchSuggestions;
  final String safeSearchMode; // 'Strict', 'Moderate', 'Off'
  final String customEngineName;
  final String customEngineUrl;

  const SearchEngineSettingsModel({
    this.defaultEngine = SearchEngine.duckDuckGo,
    this.searchSuggestions = true,
    this.safeSearchMode = 'Moderate',
    this.customEngineName = '',
    this.customEngineUrl = '',
  });

  SearchEngineSettingsModel copyWith({
    SearchEngine? defaultEngine,
    bool? searchSuggestions,
    String? safeSearchMode,
    String? customEngineName,
    String? customEngineUrl,
  }) {
    return SearchEngineSettingsModel(
      defaultEngine: defaultEngine ?? this.defaultEngine,
      searchSuggestions: searchSuggestions ?? this.searchSuggestions,
      safeSearchMode: safeSearchMode ?? this.safeSearchMode,
      customEngineName: customEngineName ?? this.customEngineName,
      customEngineUrl: customEngineUrl ?? this.customEngineUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'defaultEngine': defaultEngine.name,
        'searchSuggestions': searchSuggestions,
        'safeSearchMode': safeSearchMode,
        'customEngineName': customEngineName,
        'customEngineUrl': customEngineUrl,
      };

  factory SearchEngineSettingsModel.fromJson(Map<String, dynamic> json) {
    SearchEngine type = SearchEngine.duckDuckGo;
    final rawName = json['defaultEngine'] as String?;
    if (rawName != null) {
      for (final t in SearchEngine.values) {
        if (t.name == rawName) {
          type = t;
          break;
        }
      }
    }
    return SearchEngineSettingsModel(
      defaultEngine: type,
      searchSuggestions: json['searchSuggestions'] as bool? ?? true,
      safeSearchMode: json['safeSearchMode'] as String? ?? 'Moderate',
      customEngineName: json['customEngineName'] as String? ?? '',
      customEngineUrl: json['customEngineUrl'] as String? ?? '',
    );
  }
}

/// Persistent service managing search engine settings across the app.
class SearchEngineSettingsService extends ChangeNotifier {
  static final SearchEngineSettingsService instance = SearchEngineSettingsService._internal();

  SearchEngineSettingsService._internal();

  static const String _fileName = 'search_engine_settings.json';
  SearchEngineSettingsModel _settings = const SearchEngineSettingsModel();
  bool _isInitialized = false;

  SearchEngineSettingsModel get settings => _settings;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;
    try {
      final content = await StoragePersistenceHelper.readData(_fileName);
      if (content != null && content.trim().isNotEmpty) {
        final decoded = jsonDecode(content) as Map<String, dynamic>;
        _settings = SearchEngineSettingsModel.fromJson(decoded);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('SearchEngineSettingsService.init error: $e');
    }
  }

  Future<void> updateSettings(SearchEngineSettingsModel Function(SearchEngineSettingsModel current) updater) async {
    _settings = updater(_settings);
    notifyListeners();
    try {
      final data = jsonEncode(_settings.toJson());
      await StoragePersistenceHelper.writeData(_fileName, data);
    } catch (e) {
      debugPrint('SearchEngineSettingsService.updateSettings error: $e');
    }
  }
}
