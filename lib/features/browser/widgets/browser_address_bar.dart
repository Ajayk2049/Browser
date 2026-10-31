import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../../../theme/tokens/app_typography.dart';
import '../models/search_engine.dart';

/// Top address bar matching the mobile mock-up with Star bookmark trigger,
/// secure lock indicator, centered URL/search omnibox, and reload button.
/// Complies with rules.md §13, §25.1, §25.2, §25.7, and §29.2 (< 250 lines).
class BrowserAddressBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final bool isBookmarked;
  final VoidCallback? onToggleBookmark;
  final VoidCallback? onOpenPageInfo;
  final VoidCallback onReload;
  final bool isLoading;
  final int detectedMediaCount;
  final VoidCallback onOpenMediaGrabber;
  final SearchEngine selectedEngine;
  final ValueChanged<SearchEngine>? onEngineChanged;

  const BrowserAddressBar({
    super.key,
    required this.controller,
    required this.onSubmitted,
    this.isBookmarked = false,
    this.onToggleBookmark,
    this.onOpenPageInfo,
    required this.onReload,
    this.isLoading = false,
    this.detectedMediaCount = 0,
    required this.onOpenMediaGrabber,
    this.selectedEngine = SearchEngine.duckDuckGo,
    this.onEngineChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x3,
        vertical: AppSpacing.x2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left Star button (toggle bookmark)
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: onToggleBookmark == null
                          ? null
                          : (isBookmarked ? 'Remove bookmark' : 'Bookmark this page'),
                      icon: Icon(
                        isBookmarked ? PhosphorIcons.starFill : PhosphorIcons.star,
                        size: 20,
                        color: isBookmarked
                            ? const Color(0xFFEAB308)
                            : (onToggleBookmark == null
                                ? colorScheme.onSurfaceVariant.withValues(alpha: 0.35)
                                : colorScheme.onSurfaceVariant),
                      ),
                      onPressed: onToggleBookmark,
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Secure lock indicator button
                  Tooltip(
                    message: 'View site information',
                    child: InkWell(
                      onTap: onOpenPageInfo,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        child: Icon(
                          PhosphorIcons.lockSimple,
                          size: 16,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Center omnibox text input
                  Expanded(
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller,
                      builder: (context, value, _) {
                        return TextField(
                          controller: controller,
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.search,
                          textAlign: TextAlign.center,
                          textAlignVertical: TextAlignVertical.center,
                          onSubmitted: onSubmitted,
                          style: AppTypography.bodyMd.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: false,
                            fillColor: Colors.transparent,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            hintText: 'Search or enter address',
                            hintStyle: AppTypography.bodyMd.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Right Reload button
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Reload',
                      icon: Icon(
                        PhosphorIcons.arrowClockwise,
                        size: 20,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      onPressed: onReload,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Dynamic Media Grabber button
          if (detectedMediaCount > 0) ...[
            const SizedBox(width: AppSpacing.x2),
            Badge(
              label: Text('$detectedMediaCount'),
              child: IconButton.filledTonal(
                tooltip: 'Grab Media',
                style: IconButton.styleFrom(
                  fixedSize: const Size(44, 44),
                  padding: EdgeInsets.zero,
                ),
                icon: Icon(PhosphorIcons.broadcast, size: 20, color: colorScheme.primary),
                onPressed: onOpenMediaGrabber,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
