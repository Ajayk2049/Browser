import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_motion.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../../../theme/tokens/app_typography.dart';

/// Pure B&W theme-based 1DM+ Speed Dial Floating Action Button.
/// Eliminates colored backgrounds, adhering strictly to monochrome tokens.
/// Complies with rules.md §13, §25.1, §25.2, §25.4, §25.7, and §29.2 (< 250 lines).
class DownloadSpeedDialFab extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onToggle;
  final VoidCallback onAddLink;
  final VoidCallback onFromClipboard;

  const DownloadSpeedDialFab({
    super.key,
    required this.isOpen,
    required this.onToggle,
    required this.onAddLink,
    required this.onFromClipboard,
  });

  @override
  State<DownloadSpeedDialFab> createState() => _DownloadSpeedDialFabState();
}

class _DownloadSpeedDialFabState extends State<DownloadSpeedDialFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: AppMotion.base,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animController,
      curve: AppMotion.spring,
      reverseCurve: Curves.easeIn,
    );
    if (widget.isOpen) _animController.value = 1.0;
  }

  @override
  void didUpdateWidget(DownloadSpeedDialFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen != oldWidget.isOpen) {
      if (widget.isOpen) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Widget _buildSpeedDialOption({
    required String label,
    required IconData icon,
    required Color buttonBg,
    required Color textColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Label pill on the left
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: buttonBg,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: borderColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: AppTypography.bodyMd.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.x3),
        // Mini circular action button (44x44)
        Material(
          color: buttonBg,
          shape: CircleBorder(side: BorderSide(color: borderColor, width: 1)),
          elevation: 3,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, color: textColor, size: 20),
            ),
          ),
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final optionBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final optionTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final optionBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final fabBg = isDark ? Colors.white : const Color(0xFF0F172A);
    final fabFg = isDark ? const Color(0xFF0F172A) : Colors.white;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Stacked options
        AnimatedBuilder(
          animation: _expandAnimation,
          builder: (context, child) {
            final isVisible = _expandAnimation.value > 0.01;
            if (!isVisible) return const SizedBox.shrink();

            return FadeTransition(
              opacity: _expandAnimation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.2),
                  end: Offset.zero,
                ).animate(_expandAnimation),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.x3),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildSpeedDialOption(
                        label: 'From clipboard',
                        icon: PhosphorIcons.clipboardText,
                        buttonBg: optionBg,
                        textColor: optionTextColor,
                        borderColor: optionBorder,
                        onTap: widget.onFromClipboard,
                      ),
                      const SizedBox(height: AppSpacing.x3),
                      _buildSpeedDialOption(
                        label: 'Add link',
                        icon: PhosphorIcons.link,
                        buttonBg: optionBg,
                        textColor: optionTextColor,
                        borderColor: optionBorder,
                        onTap: widget.onAddLink,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        // Primary Floating Action Button (56x56)
        SizedBox(
          width: 56,
          height: 56,
          child: FloatingActionButton(
            onPressed: widget.onToggle,
            backgroundColor: fabBg,
            foregroundColor: fabFg,
            elevation: 4,
            shape: const CircleBorder(),
            child: AnimatedBuilder(
              animation: _expandAnimation,
              builder: (context, _) {
                return Transform.rotate(
                  angle: _expandAnimation.value * (math.pi / 4),
                  child: const Icon(
                    PhosphorIcons.plus,
                    size: 26,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
