import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../settings/services/web_extension_service.dart';
import '../services/onboarding_service.dart';
import '../widgets/onboarding_components.dart';

/// Screen presenting first-run onboarding and uBlock Origin ad-blocker opt-in.
/// Complies with rules.md §13, §25.1, §25.2, and §29.2 (< 300 lines).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isInstallingUBlock = false;

  static const String _ublockAmoUrl =
      'https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi';

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _handleEnableAdBlocking() async {
    setState(() => _isInstallingUBlock = true);
    WebExtensionService.instance.install(_ublockAmoUrl).then((_) {
      debugPrint('Onboarding: uBlock Origin background installation completed');
    }).catchError((e) {
      debugPrint('Onboarding: uBlock Origin background installation error: $e');
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enabling uBlock Origin in the background...'),
          duration: Duration(seconds: 2),
        ),
      );
      _nextPage();
    }
  }

  void _handleSkipAdBlocking() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('uBlock Origin can be installed anytime from Settings > Extensions.'),
        duration: Duration(seconds: 2),
      ),
    );
    _nextPage();
  }

  Future<void> _handleFinishOnboarding() async {
    await OnboardingService.instance.completeOnboarding();
    if (mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0C0E14) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF131722) : Colors.white;
    final borderColor = isDark ? const Color(0xFF272E3F) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            OnboardingPageIndicator(count: 3, currentPage: _currentPage, isDark: isDark),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildWelcomeStep(theme, borderColor, isDark),
                  _buildAdBlockerStep(theme, cardBg, borderColor, isDark),
                  _buildReadyStep(theme, borderColor, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeStep(ThemeData theme, Color borderColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          OnboardingBadge(icon: PhosphorIcons.compass, isDark: isDark, borderColor: borderColor),
          const SizedBox(height: 24),
          Text(
            'Welcome to Dab Browser',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 26),
          ),
          const SizedBox(height: 12),
          Text(
            'A high-performance GeckoView browser with a 1DM+-style multi-threaded downloader and complete privacy.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _nextPage,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Get Started', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildAdBlockerStep(ThemeData theme, Color cardBg, Color borderColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          OnboardingBadge(icon: PhosphorIcons.shieldCheck, isDark: isDark, borderColor: borderColor),
          const SizedBox(height: 24),
          Text(
            'Block Ads & Trackers',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 26),
          ),
          const SizedBox(height: 12),
          Text(
            'Enable uBlock Origin for fast, clean browsing without intrusive popups, banners, or data-draining trackers.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                OnboardingFeatureRow(icon: PhosphorIcons.lightning, text: 'Faster Page Loads', isDark: isDark),
                const SizedBox(height: 12),
                OnboardingFeatureRow(icon: PhosphorIcons.database, text: 'Saves Mobile Data', isDark: isDark),
                const SizedBox(height: 12),
                OnboardingFeatureRow(icon: PhosphorIcons.lock, text: 'Blocks Invasive Trackers', isDark: isDark),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _isInstallingUBlock ? null : _handleEnableAdBlocking,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Enable Ad Blocking', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              onPressed: _handleSkipAdBlocking,
              child: Text(
                'Skip for now',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildReadyStep(ThemeData theme, Color borderColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          OnboardingBadge(icon: PhosphorIcons.checkCircle, isDark: isDark, borderColor: borderColor),
          const SizedBox(height: 24),
          Text(
            "You're All Set!",
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 26),
          ),
          const SizedBox(height: 12),
          Text(
            'Dab Browser is configured and ready to use. Manage your extensions, settings, and downloads from the bottom menu at any time.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _handleFinishOnboarding,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Start Browsing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
