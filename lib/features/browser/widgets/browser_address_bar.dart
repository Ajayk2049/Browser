import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../../../theme/tokens/app_typography.dart';
import '../models/search_engine.dart';
import 'browser_overflow_menu.dart';
import 'search_engine_icons.dart';

/// Material 3 Expressive omnibox address bar with embedded search engine selector.
/// Fully unified pill-shaped address box with anchored contextual engine picker.
/// Complies with rules.md §13, §25.1, §25.2, §25.7, and §29.2 (< 250 lines).
class BrowserAddressBar extends StatelessWidget {
  final TextEditingController controller;
  final SearchEngine selectedEngine;
  final ValueChanged<SearchEngine> onEngineChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onOpenDownloads;
  final int detectedMediaCount;
  final VoidCallback onOpenMediaGrabber;
  final ValueChanged<BrowserMenuAction>? onMenuAction;

  const BrowserAddressBar({
    super.key,
    required this.controller,
    required this.selectedEngine,
    required this.onEngineChanged,
    required this.onSubmitted,
    required this.onOpenDownloads,
    this.detectedMediaCount = 0,
    required this.onOpenMediaGrabber,
    this.onMenuAction,
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
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 6),
                  // Left search engine selector capsule badge with anchored popup
                  PopupMenuButton<SearchEngine>(
                    padding: EdgeInsets.zero,
                    tooltip: 'Search engine options',
                    initialValue: selectedEngine,
                    position: PopupMenuPosition.under,
                    offset: const Offset(0, 8),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.m3Md),
                      side: BorderSide(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    color: colorScheme.surfaceContainerLowest,
                    onSelected: (chosen) {
                      onEngineChanged(chosen);
                      if (controller.text.trim().isNotEmpty) {
                        onSubmitted(controller.text.trim());
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem<SearchEngine>(
                        enabled: false,
                        height: 36,
                        child: Text(
                          'This time search in:',
                          style: AppTypography.bodySm.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const PopupMenuDivider(height: 1),
                      ...SearchEngine.values.map((engine) {
                        final isSelected = engine == selectedEngine;
                        return PopupMenuItem<SearchEngine>(
                          value: engine,
                          height: 48,
                          child: Row(
                            children: [
                              SearchEngineIcon(engine: engine, size: 22),
                              const SizedBox(width: AppSpacing.x3),
                              Expanded(
                                child: Text(
                                  engine.displayName,
                                  style: AppTypography.bodyMd.copyWith(
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(PhosphorIcons.check, size: 18, color: colorScheme.primary),
                            ],
                          ),
                        );
                      }),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SearchEngineIcon(engine: selectedEngine, size: 20),
                          const SizedBox(width: 4),
                          Icon(
                            PhosphorIcons.caretDown,
                            size: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x2),
                  // Center omnibox text input (completely borderless and seamless)
                  Expanded(
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller,
                      builder: (context, value, _) {
                        return TextField(
                          controller: controller,
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.search,
                          onSubmitted: onSubmitted,
                          style: AppTypography.bodyMd.copyWith(color: colorScheme.onSurface),
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
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            suffixIconConstraints: const BoxConstraints.tightFor(
                              width: 32,
                              height: 32,
                            ),
                            suffixIcon: value.text.isNotEmpty
                                ? IconButton(
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    iconSize: 18,
                                    icon: Icon(
                                      PhosphorIcons.xCircle,
                                      size: 18,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    onPressed: () => controller.clear(),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.x2),
          // Media Sniffer Grabber button (dynamic badge)
          if (detectedMediaCount > 0) ...[
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
            const SizedBox(width: AppSpacing.x1),
          ],
          // Downloads screen action
          IconButton.filledTonal(
            tooltip: 'Downloads',
            style: IconButton.styleFrom(
              fixedSize: const Size(44, 44),
              padding: EdgeInsets.zero,
            ),
            icon: const Icon(PhosphorIcons.downloadSimple, size: 20),
            onPressed: onOpenDownloads,
          ),
          // Vertical three-dot overflow menu
          BrowserOverflowMenu(
            onSelected: onMenuAction ?? (_) {},
          ),
        ],
      ),
    );
  }
}
