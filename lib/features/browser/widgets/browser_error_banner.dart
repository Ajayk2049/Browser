import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../../../theme/tokens/app_typography.dart';

/// Error banner displayed when GeckoView fails to load a resource.
/// Complies with rules.md §13, §25.1, §25.2, §25.7, and §29.2 (< 200 lines).
class BrowserErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const BrowserErrorBanner({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      color: colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x2,
      ),
      child: Row(
        children: [
          Icon(PhosphorIcons.warningCircle, color: colorScheme.onErrorContainer, size: 18),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodyXs.copyWith(color: colorScheme.onErrorContainer),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Retry',
              style: TextStyle(color: colorScheme.onErrorContainer, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

