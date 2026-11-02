import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Top header bar matching Figma header design.
/// Complies with rules.md §13, §29.2 (< 250 lines).
class SettingsAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onBack;
  final VoidCallback? onSearch;
  final String title;
  final bool showSearch;

  const SettingsAppBar({
    super.key,
    required this.onBack,
    this.onSearch,
    this.title = 'Settings',
    this.showSearch = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60.0);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final btnBg = isDark ? const Color(0xFF1E2433) : const Color(0xFFF1F5F9);
    final btnBorder = isDark ? const Color(0xFF2A3245) : const Color(0xFFE2E8F0);
    final iconColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return SafeArea(
      bottom: false,
      child: Container(
        height: 60.0,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          children: [
            // Squircle Back Button (36x36dp)
            _SquircleButton(
              onTap: onBack,
              bgColor: btnBg,
              borderColor: btnBorder,
              child: Icon(
                PhosphorIcons.caretLeft,
                size: 20.0,
                color: iconColor,
              ),
            ),
            // Title (17px Inter / Roboto Flex, w600)
            Expanded(
              child: Center(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 17.0,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
            // Squircle Search Button or placeholder to keep title centered
            if (showSearch)
              _SquircleButton(
                onTap: onSearch,
                bgColor: btnBg,
                borderColor: btnBorder,
                child: Icon(
                  PhosphorIcons.magnifyingGlass,
                  size: 18.0,
                  color: iconColor,
                ),
              )
            else
              const SizedBox(width: 36.0),
          ],
        ),
      ),
    );
  }
}

class _SquircleButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Color bgColor;
  final Color borderColor;
  final Widget child;

  const _SquircleButton({
    required this.onTap,
    required this.bgColor,
    required this.borderColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10.0),
        child: Ink(
          width: 36.0,
          height: 36.0,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10.0),
            border: Border.all(color: borderColor, width: 1.0),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
