import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../../../theme/tokens/app_typography.dart';
import '../models/home_content_item.dart';

/// Squircle icon tile displaying genuine website icon files for quick links.
/// Complies with rules.md §13, §25.1, §25.2, §25.7, and §29.2 (< 250 lines).
class QuickLinkSquircle extends StatelessWidget {
  final QuickLink item;
  final bool isDark;
  final Color borderColor;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const QuickLinkSquircle({
    super.key,
    required this.item,
    required this.isDark,
    required this.borderColor,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cardBg = isDark ? const Color(0xFF131722) : colorScheme.surfaceContainerLowest;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(AppRadius.m3Md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.m3Md),
              side: BorderSide(color: borderColor),
            ),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: 56,
              height: 56,
              child: Center(
                child: _buildIconContent(colorScheme),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x1),
          SizedBox(
            width: 56,
            child: Text(
              item.title,
              textAlign: TextAlign.center,
              style: AppTypography.bodyXs.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconContent(ColorScheme colorScheme) {
    if (item.isAddButton) {
      return Icon(PhosphorIcons.plus, size: 22, color: colorScheme.primary);
    }

    final faviconUrl = item.faviconUrl;
    if (faviconUrl.isEmpty) {
      return _buildFallbackLetter(colorScheme);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.m3Sm),
      child: Image.network(
        faviconUrl,
        width: 30,
        height: 30,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildFallbackLetter(colorScheme),
      ),
    );
  }

  Widget _buildFallbackLetter(ColorScheme colorScheme) {
    return Text(
      item.letter,
      style: AppTypography.displaySm.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: colorScheme.onSurface,
      ),
    );
  }
}
