import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../browser/models/search_engine.dart';
import '../../../theme/tokens/app_radius.dart';

/// Shared UI primitives for the 4-step Onboarding flow matching Browser_UI_mockup.fig.
class OnboardingHeaderBar extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;
  final bool isDark;

  const OnboardingHeaderBar({
    super.key,
    this.title = '',
    this.onBack,
    this.onSkip,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF131620) : Colors.white;
    final border = isDark ? const Color(0xFF1E2230) : const Color(0xFFE2E8F0);
    final pillBg = isDark ? const Color(0xFF1A2130) : const Color(0xFFF1F5F9);
    final pillBorder = isDark ? const Color(0xFF272E3F) : const Color(0xFFCBD5E1);
    final fg = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: border, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            alignment: Alignment.centerLeft,
            child: onBack != null
                ? InkWell(
                    onTap: onBack,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: pillBg,
                        shape: BoxShape.circle,
                        border: Border.all(color: pillBorder),
                      ),
                      child: Icon(PhosphorIcons.caretLeft, size: 16, color: fg),
                    ),
                  )
                : null,
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
          Container(
            width: 56,
            alignment: Alignment.centerRight,
            child: onSkip != null
                ? InkWell(
                    onTap: onSkip,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: pillBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: pillBorder),
                      ),
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: muted,
                        ),
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final active = index == currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 3.5),
          width: active ? 24 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active
                ? (isDark ? Colors.white : const Color(0xFF0F172A))
                : (isDark ? const Color(0xFF272E3F) : const Color(0xFFCBD5E1)),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        );
      }),
    );
  }
}

class OnboardingSectionCard extends StatelessWidget {
  final List<Widget> children;
  final bool isDark;

  const OnboardingSectionCard({
    super.key,
    required this.children,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF131722) : Colors.white;
    final border = isDark ? const Color(0xFF272E3F) : const Color(0xFFE2E8F0);
    final dividerColor = isDark ? const Color(0xFF1E2433) : const Color(0xFFF1F5F9);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(height: 1, thickness: 1, color: dividerColor),
          ],
        ],
      ),
    );
  }
}

class OnboardingInfoBanner extends StatelessWidget {
  final String text;
  final bool isDark;

  const OnboardingInfoBanner({
    super.key,
    required this.text,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1A2130) : const Color(0xFFF1F5F9);
    final border = isDark ? const Color(0xFF272E3F) : const Color(0xFFE2E8F0);
    final fg = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(PhosphorIcons.info, size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, height: 1.4, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingEngineRow extends StatelessWidget {
  final SearchEngine engine;
  final String letter;
  final String domain;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const OnboardingEngineRow({
    super.key,
    required this.engine,
    required this.letter,
    required this.domain,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final boxBg = isDark ? const Color(0xFF1E2433) : const Color(0xFFF1F5F9);
    final boxBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final fg = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: boxBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: boxBorder),
              ),
              alignment: Alignment.center,
              child: Text(
                letter,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    engine.displayName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    domain,
                    style: TextStyle(fontSize: 12.5, color: muted),
                  ),
                ],
              ),
            ),
            _buildRadio(isSelected, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildRadio(bool selected, bool isDark) {
    if (selected) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      );
    }
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
          width: 1.5,
        ),
      ),
    );
  }
}
