import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../browser/models/search_engine.dart';
import 'onboarding_components.dart';
import 'onboarding_icons.dart';

/// Step 1: Welcome Screen ("Dab Browser").
class WelcomeStepView extends StatelessWidget {
  final bool isDark;
  final VoidCallback onGetStarted;

  const WelcomeStepView({
    super.key,
    required this.isDark,
    required this.onGetStarted,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final iconBg = isDark ? const Color(0xFF1A2130) : const Color(0xFFF1F5F9);
    final iconBorder = isDark ? const Color(0xFF272E3F) : const Color(0xFFE2E8F0);

    return Column(
      children: [
        OnboardingHeaderBar(isDark: isDark),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const Spacer(),
                      DabAppLogoWidget(isDark: isDark),
                      const SizedBox(height: 24),
                      Text(
                        'Dab Browser',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: fg),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'A faster, cleaner, more private way to browse the web.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, height: 1.45, color: muted),
                      ),
                      const SizedBox(height: 28),
                      OnboardingSectionCard(
                        isDark: isDark,
                        children: [
                          _featureRow(
                            iconBg: iconBg,
                            iconBorder: iconBorder,
                            leading: UBlockShieldIcon(
                              size: 20,
                              shieldColor: fg,
                              textColor: isDark ? const Color(0xFF1A2130) : Colors.white,
                            ),
                            label: 'uBlock Origin built-in',
                            fg: fg,
                          ),
                          _featureRow(
                            iconBg: iconBg,
                            iconBorder: iconBorder,
                            leading: TorrentSwirlIcon(size: 20, color: fg),
                            label: 'Direct torrent downloads',
                            fg: fg,
                          ),
                          _featureRow(
                            iconBg: iconBg,
                            iconBorder: iconBorder,
                            leading: Container(
                              width: 20,
                              height: 16,
                              decoration: BoxDecoration(
                                color: fg,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                PhosphorIcons.playFill,
                                size: 10,
                                color: isDark ? const Color(0xFF1A2130) : Colors.white,
                              ),
                            ),
                            label: 'YouTube downloader built-in',
                            fg: fg,
                          ),
                        ],
                      ),
                      const Spacer(),
                      const SizedBox(height: 20),
                      OnboardingPageIndicator(count: 4, currentPage: 0, isDark: isDark),
                      const SizedBox(height: 16),
                      _primaryButton(label: 'Get started', isDark: isDark, onPressed: onGetStarted),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _featureRow({
    required Color iconBg,
    required Color iconBorder,
    required Widget leading,
    required String label,
    required Color fg,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: iconBorder),
            ),
            alignment: Alignment.center,
            child: leading,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: fg)),
          ),
        ],
      ),
    );
  }
}

/// Step 2: Ad Blocking Opt-In ("Block ads & trackers").
class AdBlockingStepView extends StatelessWidget {
  final bool isDark;
  final bool isInstalling;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final VoidCallback onEnable;
  final VoidCallback onNotNow;

  const AdBlockingStepView({
    super.key,
    required this.isDark,
    required this.isInstalling,
    required this.onBack,
    required this.onSkip,
    required this.onEnable,
    required this.onNotNow,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final badgeBg = isDark ? const Color(0xFF1A2130) : const Color(0xFFEEF2F6);
    final badgeBorder = isDark ? const Color(0xFF272E3F) : const Color(0xFFE2E8F0);

    return Column(
      children: [
        OnboardingHeaderBar(title: 'Ad blocking', onBack: onBack, onSkip: onSkip, isDark: isDark),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STEP 2 OF 4',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.9,
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: badgeBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: badgeBorder),
                        ),
                        alignment: Alignment.center,
                        child: UBlockShieldIcon(
                          size: 46,
                          shieldColor: fg,
                          textColor: badgeBg,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Block ads & trackers',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: fg),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Dab strips intrusive ads, pop-ups and trackers on every site. Pages load faster and use less data.',
                        style: TextStyle(fontSize: 13.5, height: 1.45, color: muted),
                      ),
                      const SizedBox(height: 20),
                      OnboardingSectionCard(
                        isDark: isDark,
                        children: [
                          _checkRow('No intrusive ads or pop-ups', fg, isDark),
                          _checkRow('Faster page loads, less data', fg, isDark),
                          _checkRow('Tracker blocking on every site', fg, isDark),
                        ],
                      ),
                      const SizedBox(height: 14),
                      OnboardingInfoBanner(
                        text: 'You can enable or disable ad blocking later in Settings › Extensions.',
                        isDark: isDark,
                      ),
                      const Spacer(),
                      const SizedBox(height: 20),
                      OnboardingPageIndicator(count: 4, currentPage: 1, isDark: isDark),
                      const SizedBox(height: 16),
                      _primaryButton(
                        label: 'Enable ad blocking',
                        isDark: isDark,
                        onPressed: isInstalling ? null : onEnable,
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: isInstalling ? null : onNotNow,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: fg,
                            side: BorderSide(
                              color: isDark ? const Color(0xFF272E3F) : const Color(0xFFCBD5E1),
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('Not now', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _checkRow(String text, Color fg, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(
              PhosphorIcons.checkBold,
              size: 12,
              color: isDark ? const Color(0xFF0C0E14) : Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: fg)),
          ),
        ],
      ),
    );
  }
}

/// Step 3: Search Engine Selection ("Choose your default search").
/// Google is the first option and default selection.
class SearchEngineStepView extends StatelessWidget {
  final bool isDark;
  final SearchEngine selectedEngine;
  final ValueChanged<SearchEngine> onSelectEngine;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final VoidCallback onContinue;

  const SearchEngineStepView({
    super.key,
    required this.isDark,
    required this.selectedEngine,
    required this.onSelectEngine,
    required this.onBack,
    required this.onSkip,
    required this.onContinue,
  });

  static const _engines = [
    (SearchEngine.google, 'G', 'google.com'),
    (SearchEngine.duckDuckGo, 'D', 'duckduckgo.com'),
    (SearchEngine.bing, 'B', 'bing.com'),
    (SearchEngine.brave, '▲', 'search.brave.com'),
    (SearchEngine.startpage, 'S', 'startpage.com'),
  ];

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Column(
      children: [
        OnboardingHeaderBar(title: 'Search engine', onBack: onBack, onSkip: onSkip, isDark: isDark),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STEP 3 OF 4',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.9,
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Choose your default search',
                        style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700, color: fg),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pick the engine that powers your address bar searches.',
                        style: TextStyle(fontSize: 13.5, height: 1.4, color: muted),
                      ),
                      const SizedBox(height: 20),
                      OnboardingSectionCard(
                        isDark: isDark,
                        children: [
                          for (final item in _engines)
                            OnboardingEngineRow(
                              engine: item.$1,
                              letter: item.$2,
                              domain: item.$3,
                              isSelected: selectedEngine == item.$1,
                              isDark: isDark,
                              onTap: () => onSelectEngine(item.$1),
                            ),
                        ],
                      ),
                      const Spacer(),
                      const SizedBox(height: 20),
                      OnboardingPageIndicator(count: 4, currentPage: 2, isDark: isDark),
                      const SizedBox(height: 16),
                      _primaryButton(label: 'Continue', isDark: isDark, onPressed: onContinue),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          'You can change this later in Settings › Search engine.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Step 4: Setup Complete ("You're all set").
class FinishSetupStepView extends StatelessWidget {
  final bool isDark;
  final bool adBlockingEnabled;
  final SearchEngine selectedEngine;
  final VoidCallback onStartBrowsing;

  const FinishSetupStepView({
    super.key,
    required this.isDark,
    required this.adBlockingEnabled,
    required this.selectedEngine,
    required this.onStartBrowsing,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Column(
      children: [
        OnboardingHeaderBar(title: 'Setup complete', isDark: isDark),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const Spacer(),
                      Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Icon(
                          PhosphorIcons.checkBold,
                          size: 38,
                          color: isDark ? const Color(0xFF0C0E14) : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "You're all set",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: fg),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Dab is ready to go. Here is what we set up for you.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, height: 1.45, color: muted),
                      ),
                      const SizedBox(height: 24),
                      OnboardingSectionCard(
                        isDark: isDark,
                        children: [
                          _summaryRow(
                            label: 'Ad blocking',
                            value: adBlockingEnabled ? 'Enabled' : 'Not enabled',
                            fg: fg,
                            muted: muted,
                          ),
                          _summaryRow(
                            label: 'Search engine',
                            value: selectedEngine.displayName,
                            fg: fg,
                            muted: muted,
                          ),
                        ],
                      ),
                      const Spacer(),
                      const SizedBox(height: 20),
                      OnboardingPageIndicator(count: 4, currentPage: 3, isDark: isDark),
                      const SizedBox(height: 16),
                      _primaryButton(label: 'Start browsing', isDark: isDark, onPressed: onStartBrowsing),
                      const SizedBox(height: 10),
                      Text(
                        'Tip: open Settings anytime to fine-tune your browser.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryRow({
    required String label,
    required String value,
    required Color fg,
    required Color muted,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: fg)),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: muted)),
        ],
      ),
    );
  }
}

Widget _primaryButton({
  required String label,
  required bool isDark,
  required VoidCallback? onPressed,
}) {
  return SizedBox(
    width: double.infinity,
    height: 52,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
        foregroundColor: isDark ? const Color(0xFF0C0E14) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
    ),
  );
}
