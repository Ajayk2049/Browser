import 'package:flutter/material.dart';

/// User preferences model for theme mode and text zoom factor.
/// Complies with rules.md §13, §29.2 (< 200 lines).
class AppearanceSettingsModel {
  final ThemeMode themeMode;
  final int textZoomPercent;

  const AppearanceSettingsModel({
    this.themeMode = ThemeMode.system,
    this.textZoomPercent = 100,
  });

  double get fontSizeFactor => textZoomPercent / 100.0;

  String get themeModeName {
    switch (themeMode) {
      case ThemeMode.system:
        return 'Follow system';
      case ThemeMode.dark:
        return 'Dark mode';
      case ThemeMode.light:
        return 'Light mode';
    }
  }

  AppearanceSettingsModel copyWith({
    ThemeMode? themeMode,
    int? textZoomPercent,
  }) {
    return AppearanceSettingsModel(
      themeMode: themeMode ?? this.themeMode,
      textZoomPercent: textZoomPercent ?? this.textZoomPercent,
    );
  }

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.name,
        'textZoomPercent': textZoomPercent,
      };

  factory AppearanceSettingsModel.fromJson(Map<String, dynamic> json) {
    final modeStr = json['themeMode'] as String? ?? 'system';
    final mode = ThemeMode.values.firstWhere(
      (m) => m.name == modeStr,
      orElse: () => ThemeMode.system,
    );
    final zoom = (json['textZoomPercent'] as num?)?.toInt() ?? 100;
    return AppearanceSettingsModel(
      themeMode: mode,
      textZoomPercent: zoom.clamp(50, 200),
    );
  }
}

