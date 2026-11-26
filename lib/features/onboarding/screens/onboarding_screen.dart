import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../browser/models/search_engine.dart';
import '../../settings/services/search_engine_settings_service.dart';
import '../../settings/services/web_extension_service.dart';
import '../services/onboarding_service.dart';
import '../widgets/onboarding_steps.dart';

/// 4-step first-run onboarding flow matching Browser_UI_mockup.fig.
/// Handles uBlock Origin ad-blocking opt-in and default search engine selection.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  bool _isInstallingUBlock = false;
  bool _adBlockingEnabled = false;
  SearchEngine _selectedEngine = SearchEngine.google;

  static const String _ublockAmoUrl =
      'https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi';

  @override
  void initState() {
    super.initState();
    final current = SearchEngineSettingsService.instance.settings.defaultEngine;
    _selectedEngine = current == SearchEngine.custom ? SearchEngine.google : current;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _handleEnableAdBlocking() async {
    setState(() {
      _isInstallingUBlock = true;
      _adBlockingEnabled = true;
    });
    unawaited(
      WebExtensionService.instance.install(_ublockAmoUrl).then((_) {
        debugPrint('Onboarding: uBlock Origin background installation completed');
      }).catchError((Object e) {
        debugPrint('Onboarding: uBlock Origin background installation error: $e');
      }),
    );

    if (mounted) {
      setState(() => _isInstallingUBlock = false);
      _nextPage();
    }
  }

  void _handleSkipAdBlocking() {
    setState(() => _adBlockingEnabled = false);
    _nextPage();
  }

  Future<void> _handleSelectEngine(SearchEngine engine) async {
    setState(() => _selectedEngine = engine);
    await SearchEngineSettingsService.instance.updateSettings(
      (cur) => cur.copyWith(defaultEngine: engine),
    );
  }

  void _handleSearchContinue() {
    unawaited(
      SearchEngineSettingsService.instance.updateSettings(
        (cur) => cur.copyWith(defaultEngine: _selectedEngine),
      ),
    );
    _nextPage();
  }

  Future<void> _handleFinishOnboarding() async {
    await SearchEngineSettingsService.instance.updateSettings(
      (cur) => cur.copyWith(defaultEngine: _selectedEngine),
    );
    await OnboardingService.instance.completeOnboarding();
    if (mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0C0E14) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            WelcomeStepView(
              isDark: isDark,
              onGetStarted: _nextPage,
            ),
            AdBlockingStepView(
              isDark: isDark,
              isInstalling: _isInstallingUBlock,
              onBack: _previousPage,
              onSkip: _handleSkipAdBlocking,
              onEnable: _handleEnableAdBlocking,
              onNotNow: _handleSkipAdBlocking,
            ),
            SearchEngineStepView(
              isDark: isDark,
              selectedEngine: _selectedEngine,
              onSelectEngine: _handleSelectEngine,
              onBack: _previousPage,
              onSkip: () => _goToPage(3),
              onContinue: _handleSearchContinue,
            ),
            FinishSetupStepView(
              isDark: isDark,
              adBlockingEnabled: _adBlockingEnabled,
              selectedEngine: _selectedEngine,
              onStartBrowsing: _handleFinishOnboarding,
            ),
          ],
        ),
      ),
    );
  }
}
