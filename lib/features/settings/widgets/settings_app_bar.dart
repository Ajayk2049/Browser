import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Top header bar matching the circular button aesthetic of Download Manager.
/// Complies with rules.md §13, §29.2 (< 250 lines).
class SettingsAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onBack;
  final VoidCallback? onSearch;
  final VoidCallback? onMore;
  final Widget? customTrailing;
  final String title;
  final bool showSearch;

  const SettingsAppBar({
    super.key,
    required this.onBack,
    this.onSearch,
    this.onMore,
    this.customTrailing,
    this.title = 'Settings',
    this.showSearch = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60.0);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fgColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return SafeArea(
      bottom: false,
      child: Container(
        height: 60.0,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          children: [
            // Circular Back Button (40x40dp matching Download Manager)
            _CircleButton(
              onTap: onBack,
              isDark: isDark,
              child: Icon(PhosphorIcons.caretLeft, size: 20.0, color: fgColor),
            ),
            // Centered Title
            Expanded(
              child: Center(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 17.0,
                    fontWeight: FontWeight.w600,
                    color: fgColor,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
            // Trailing action or placeholder to keep title centered
            if (customTrailing != null)
              customTrailing!
            else if (onMore != null)
              _CircleButton(
                onTap: onMore,
                isDark: isDark,
                child: Icon(PhosphorIcons.dotsThreeVertical, size: 20.0, color: fgColor),
              )
            else if (showSearch)
              _CircleButton(
                onTap: onSearch,
                isDark: isDark,
                child: Icon(PhosphorIcons.magnifyingGlass, size: 20.0, color: fgColor),
              )
            else
              const SizedBox(width: 40.0),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isDark;
  final Widget child;

  const _CircleButton({
    required this.onTap,
    required this.isDark,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF131722) : Colors.white;
    final border = isDark ? const Color(0xFF1E293B) : const Color(0xFFEDF0F5);

    return Container(
      width: 40.0,
      height: 40.0,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: border),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: child,
        onPressed: onTap,
      ),
    );
  }
}
