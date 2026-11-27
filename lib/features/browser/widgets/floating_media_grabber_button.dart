import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_radius.dart';

/// Floating tactile media grabber pill button overlaid on the active browser webpage.
/// Adheres strictly to monochrome design principles and rules.md §13, §29.2 (< 150 lines).
class FloatingMediaGrabberButton extends StatelessWidget {
  final int count;
  final bool loading;
  final VoidCallback onTap;

  const FloatingMediaGrabberButton({
    super.key,
    required this.count,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVisible = count > 0 || loading;

    final bg = isDark ? const Color(0xFF161B26) : Colors.white;
    final border = isDark ? const Color(0xFF272E3F) : const Color(0xFFE2E8F0);
    final iconColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final badgeBg = isDark ? Colors.white : const Color(0xFF0F172A);
    final badgeFg = isDark ? const Color(0xFF0F172A) : Colors.white;

    if (!isVisible) return const SizedBox.shrink();

    return Positioned(
      right: 16,
      bottom: 16,
      child: RepaintBoundary(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: border, width: 1.5),
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
                  if (loading)
                    Text(
                      'Finding streams…',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: iconColor,
                      ),
                    )
                  else
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
