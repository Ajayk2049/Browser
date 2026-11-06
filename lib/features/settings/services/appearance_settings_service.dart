import 'dart:convert';
import 'package:flutter/material.dart';
import '../../browser/utils/storage_persistence_helper.dart';
import '../models/appearance_settings_model.dart';

/// Persistent service managing appearance and font zoom settings.
/// Complies with rules.md §13, §29.2 (< 250 lines).
class AppearanceSettingsService extends ChangeNotifier {
  static final AppearanceSettingsService instance = AppearanceSettingsService._internal();

  AppearanceSettingsService._internal();

  static const String _fileName = 'appearance_settings.json';
  AppearanceSettingsModel _settings = const AppearanceSettingsModel();
  bool _isInitialized = false;

  AppearanceSettingsModel get settings => _settings;
  ThemeMode get themeMode => _settings.themeMode;
  int get textZoomPercent => _settings.textZoomPercent;
  double get fontSizeFactor => _settings.fontSizeFactor;

  /// Callback registered by Gecko runtime / browser session to update text zoom live.
  static void Function(double factor)? onFontSizeFactorChanged;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;
    try {
      final content = await StoragePersistenceHelper.readData(_fileName);
      if (content != null && content.trim().isNotEmpty) {
        final decoded = jsonDecode(content) as Map<String, dynamic>;
        _settings = AppearanceSettingsModel.fromJson(decoded);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('AppearanceSettingsService.init error: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_settings.themeMode == mode) return;
    _settings = _settings.copyWith(themeMode: mode);
    notifyListeners();
    await _persist();
  }

  Future<void> setTextZoomPercent(int percent) async {
    final clamped = percent.clamp(50, 200);
    if (_settings.textZoomPercent == clamped) return;
    _settings = _settings.copyWith(textZoomPercent: clamped);
    notifyListeners();
    onFontSizeFactorChanged?.call(_settings.fontSizeFactor);
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final data = jsonEncode(_settings.toJson());
      await StoragePersistenceHelper.writeData(_fileName, data);
    } catch (e) {
      debugPrint('AppearanceSettingsService._persist error: $e');
    }
  }
}

