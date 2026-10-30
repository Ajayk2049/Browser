import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_motion.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../../../theme/tokens/app_typography.dart';

/// 1DM+-style expandable Speed Dial Floating Action Button.
/// Options stack directly on top of the plus icon.
/// The plus icon rotates by 45 degrees to become an X; pressing it closes the menu.
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
    required Color buttonColor,
    required Color onButtonColor,
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: buttonColor,
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: AppTypography.bodyMd.copyWith(
                color: onButtonColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.x3),
        // Mini circular action button (44x44)
        Material(
          color: buttonColor,
          shape: const CircleBorder(),
          elevation: 4,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, color: onButtonColor, size: 22),
            ),
          ),
        ),
        // 6px right spacing so 44px mini-button center aligns with 56px FAB center:
        // (56 - 44) / 2 = 6px
        const SizedBox(width: 6),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Speed dial options stacked directly on top of the FAB
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
                        buttonColor: const Color(0xFFF07038),
                        onButtonColor: Colors.white,
                        onTap: widget.onFromClipboard,
                      ),
                      const SizedBox(height: AppSpacing.x3),
                      _buildSpeedDialOption(
                        label: 'Add link',
                        icon: PhosphorIcons.link,
                        buttonColor: const Color(0xFF3872F0),
                        onButtonColor: Colors.white,
                        onTap: widget.onAddLink,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        // Primary Floating Action Button: rotates 45 deg from + to X
        SizedBox(
          width: 56,
          height: 56,
          child: FloatingActionButton(
            onPressed: widget.onToggle,
            backgroundColor: widget.isOpen
                ? colorScheme.surfaceContainerHighest
                : colorScheme.primaryContainer,
            foregroundColor: widget.isOpen
                ? colorScheme.onSurface
                : colorScheme.onPrimaryContainer,
            elevation: 4,
            shape: const CircleBorder(),
            child: AnimatedBuilder(
              animation: _expandAnimation,
              builder: (context, _) {
                // Rotating + by 45 degrees (pi / 4) cleanly produces X
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
