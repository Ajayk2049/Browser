import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_radius.dart';

/// Floating tactile media grabber pill button overlaid on the active browser webpage.
/// Adheres strictly to monochrome design principles and rules.md §13, §29.2 (< 150 lines).
class FloatingMediaGrabberButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const FloatingMediaGrabberButton({
    super.key,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVisible = count > 0;

    final bg = isDark ? const Color(0xFF161B26) : Colors.white;
    final border = isDark ? const Color(0xFF272E3F) : const Color(0xFFE2E8F0);
    final iconColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final badgeBg = isDark ? Colors.white : const Color(0xFF0F172A);
    final badgeFg = isDark ? const Color(0xFF0F172A) : Colors.white;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      right: 16,
      bottom: isVisible ? 76 : -80,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: isVisible ? 1.0 : 0.0,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isVisible ? onTap : null,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: border, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 80 : 30),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    PhosphorIcons.downloadSimple,
                    size: 20,
                    color: iconColor,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      count > 9 ? '9+' : '$count',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: badgeFg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
