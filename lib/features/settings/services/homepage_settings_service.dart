import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../browser/utils/storage_persistence_helper.dart';

/// User preferences model for homepage behaviors and contents.
/// Complies with rules.md §13, §29.2 (< 200 lines).
class HomepageSettingsModel {
  final bool openOnStartup;
  final bool newTabOpensHomepage;
  final String customHomepageUrl;
  final bool showTopSites;
  final bool showBookmarksBar;
  final bool showSearchBar;

  const HomepageSettingsModel({
    this.openOnStartup = true,
    this.newTabOpensHomepage = true,
    this.customHomepageUrl = '',
    this.showTopSites = true,
    this.showBookmarksBar = false,
    this.showSearchBar = true,
  });

  HomepageSettingsModel copyWith({
    bool? openOnStartup,
    bool? newTabOpensHomepage,
    String? customHomepageUrl,
    bool? showTopSites,
    bool? showBookmarksBar,
    bool? showSearchBar,
  }) {
    return HomepageSettingsModel(
      openOnStartup: openOnStartup ?? this.openOnStartup,
      newTabOpensHomepage: newTabOpensHomepage ?? this.newTabOpensHomepage,
      customHomepageUrl: customHomepageUrl ?? this.customHomepageUrl,
      showTopSites: showTopSites ?? this.showTopSites,
      showBookmarksBar: showBookmarksBar ?? this.showBookmarksBar,
      showSearchBar: showSearchBar ?? this.showSearchBar,
    );
  }

  Map<String, dynamic> toJson() => {
        'openOnStartup': openOnStartup,
        'newTabOpensHomepage': newTabOpensHomepage,
        'customHomepageUrl': customHomepageUrl,
        'showTopSites': showTopSites,
        'showBookmarksBar': showBookmarksBar,
        'showSearchBar': showSearchBar,
      };

  factory HomepageSettingsModel.fromJson(Map<String, dynamic> json) {
    return HomepageSettingsModel(
      openOnStartup: json['openOnStartup'] as bool? ?? true,
      newTabOpensHomepage: json['newTabOpensHomepage'] as bool? ?? true,
      customHomepageUrl: json['customHomepageUrl'] as String? ?? '',
      showTopSites: json['showTopSites'] as bool? ?? true,
      showBookmarksBar: json['showBookmarksBar'] as bool? ?? false,
      showSearchBar: json['showSearchBar'] as bool? ?? true,
    );
  }
}

/// Persistent service managing homepage settings.
class HomepageSettingsService extends ChangeNotifier {
  static final HomepageSettingsService instance = HomepageSettingsService._internal();

  HomepageSettingsService._internal();

  static const String _fileName = 'homepage_settings.json';
  HomepageSettingsModel _settings = const HomepageSettingsModel();
  bool _isInitialized = false;

  HomepageSettingsModel get settings => _settings;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;
    try {
      final content = await StoragePersistenceHelper.readData(_fileName);
      if (content != null && content.trim().isNotEmpty) {
        final decoded = jsonDecode(content) as Map<String, dynamic>;
        _settings = HomepageSettingsModel.fromJson(decoded);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('HomepageSettingsService.init error: $e');
    }
  }

  Future<void> updateSettings(HomepageSettingsModel Function(HomepageSettingsModel current) updater) async {
    _settings = updater(_settings);
    notifyListeners();
    try {
      final data = jsonEncode(_settings.toJson());
      await StoragePersistenceHelper.writeData(_fileName, data);
    } catch (e) {
      debugPrint('HomepageSettingsService.updateSettings error: $e');
    }
  }
}

