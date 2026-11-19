import 'package:flutter/material.dart';
import '../../../theme/tokens/app_radius.dart';

/// Reusable UI components for the Onboarding flow.
/// Complies with rules.md §13, §29.2 (< 250 lines).
class OnboardingPageIndicator extends StatelessWidget {
  final int count;
  final int currentPage;
  final bool isDark;

  const OnboardingPageIndicator({
    super.key,
    required this.count,
    required this.currentPage,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (index) {
          final active = index == currentPage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: active ? 28 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: active
                  ? (isDark ? Colors.white : const Color(0xFF0F172A))
                  : (isDark ? const Color(0xFF272E3F) : const Color(0xFFCBD5E1)),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          );
        }),
      ),
    );
  }
}

class OnboardingBadge extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final Color borderColor;

  const OnboardingBadge({
    super.key,
    required this.icon,
    required this.isDark,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2638) : const Color(0xFFEEF2F6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Icon(
        icon,
        size: 40,
        color: isDark ? Colors.white : const Color(0xFF0F172A),
      ),
    );
  }
}

class OnboardingFeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDark;

  const OnboardingFeatureRow({
    super.key,
    required this.icon,
    required this.text,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
