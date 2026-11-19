import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../../../theme/tokens/app_typography.dart';

/// Industry-standard private/incognito start page.
/// Complies with rules.md §13, §25.1, §25.2, §25.7, and §29.2 (< 250 lines).
class PrivateHomeView extends StatelessWidget {
  final ValueChanged<String> onOpenUrl;

  const PrivateHomeView({
    super.key,
    required this.onOpenUrl,
  });

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0C0E14);
    const cardBg = Color(0xFF131722);
    const border = Color(0xFF334155);

    return Container(
      color: bg,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x6, vertical: AppSpacing.x8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: cardBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: border, width: 1.5),
                  ),
                  child: const Icon(PhosphorIcons.eyeglasses, size: 36, color: Color(0xFFE2E8F0)),
                ),
                const SizedBox(height: AppSpacing.x4),
                Text(
                  "You've gone Incognito",
                  textAlign: TextAlign.center,
                  style: AppTypography.displaySm.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  'Now you can browse privately. Other people who use this device won’t see your activity.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMd.copyWith(color: const Color(0xFF94A3B8)),
                ),
                const SizedBox(height: AppSpacing.x6),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.x4),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Dab Browser won't save:",
                        style: AppTypography.bodySm.copyWith(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFE2E8F0),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x3),
                      _buildBullet(PhosphorIcons.x, 'Your browsing history', const Color(0xFFEF4444)),
                      const SizedBox(height: AppSpacing.x2),
                      _buildBullet(PhosphorIcons.x, 'Cookies and site data', const Color(0xFFEF4444)),
                      const SizedBox(height: AppSpacing.x2),
                      _buildBullet(PhosphorIcons.x, 'Information entered in forms', const Color(0xFFEF4444)),
                      const Divider(color: border, height: 28),
                      Text(
                        'Your activity might still be visible to:',
                        style: AppTypography.bodySm.copyWith(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFE2E8F0),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x3),
                      _buildBullet(PhosphorIcons.eye, 'Websites you visit', const Color(0xFF94A3B8)),
                      const SizedBox(height: AppSpacing.x2),
                      _buildBullet(PhosphorIcons.buildings, 'Your employer or school', const Color(0xFF94A3B8)),
                      const SizedBox(height: AppSpacing.x2),
                      _buildBullet(PhosphorIcons.globeSimple, 'Your internet service provider', const Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBullet(IconData icon, String text, Color iconColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: AppSpacing.x2),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodySm.copyWith(color: const Color(0xFFCBD5E1)),
          ),
        ),
      ],
    );
  }
}

