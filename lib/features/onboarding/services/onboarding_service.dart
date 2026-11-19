import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../browser/utils/storage_persistence_helper.dart';

/// Service managing first-run onboarding completion and state persistence.
/// Complies with rules.md §13, §25.1, §25.2, and §29.2 (< 200 lines).
class OnboardingService extends ChangeNotifier {
  static final OnboardingService instance = OnboardingService._internal();

  OnboardingService._internal();

  static const String _fileName = 'onboarding_state.json';

  bool _hasCompletedOnboarding = false;
  bool _isInitialized = false;

  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  bool get isInitialized => _isInitialized;

  /// Loads persisted onboarding state from atomic dual-mirror storage.
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final jsonStr = await StoragePersistenceHelper.readData(_fileName);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final data = jsonDecode(jsonStr);
        if (data is Map<String, dynamic>) {
          _hasCompletedOnboarding = data['hasCompleted'] == true;
        }
      }
    } catch (e) {
      debugPrint('OnboardingService.init error: $e');
      _hasCompletedOnboarding = false;
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Marks the onboarding flow as complete and persists to disk.
  Future<void> completeOnboarding() async {
    _hasCompletedOnboarding = true;
    notifyListeners();
    try {
      final data = {
        'hasCompleted': true,
        'completedAt': DateTime.now().toIso8601String(),
      };
      await StoragePersistenceHelper.writeData(_fileName, jsonEncode(data));
    } catch (e) {
      debugPrint('OnboardingService.completeOnboarding error: $e');
    }
  }

  /// Resets onboarding state (useful for settings or debug testing).
  Future<void> resetOnboarding() async {
    _hasCompletedOnboarding = false;
    notifyListeners();
    try {
      final data = {'hasCompleted': false};
      await StoragePersistenceHelper.writeData(_fileName, jsonEncode(data));
    } catch (e) {
      debugPrint('OnboardingService.resetOnboarding error: $e');
    }
  }
}
