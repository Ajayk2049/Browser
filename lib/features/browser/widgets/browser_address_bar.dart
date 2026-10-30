import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../../../theme/tokens/app_typography.dart';
import '../models/search_engine.dart';
import 'search_engine_icons.dart';

/// Material 3 Expressive omnibox address bar with embedded search engine selector.
/// Faithfully reproduces the capsule badge design and popup menu from reference UI.
/// Complies with rules.md §13, §25.1, §25.2, §25.7, and §29.2 (< 250 lines).
class BrowserAddressBar extends StatelessWidget {
  final TextEditingController controller;
  final SearchEngine selectedEngine;
  final ValueChanged<SearchEngine> onEngineChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onOpenDownloads;
  final int detectedMediaCount;
  final VoidCallback onOpenMediaGrabber;

  const BrowserAddressBar({
    super.key,
    required this.controller,
    required this.selectedEngine,
    required this.onEngineChanged,
    required this.onSubmitted,
    required this.onOpenDownloads,
    this.detectedMediaCount = 0,
    required this.onOpenMediaGrabber,
  });

  void _showEnginePicker(BuildContext context, GlobalKey buttonKey) {
    final renderBox = buttonKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (renderBox == null || overlay == null) return;

    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        renderBox.localToGlobal(Offset.zero, ancestor: overlay),
        renderBox.localToGlobal(renderBox.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final colorScheme = Theme.of(context).colorScheme;

    showMenu<SearchEngine>(
      context: context,
      position: RelativeRect.fromLTRB(position.left, position.bottom + 6, position.right, position.bottom),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: colorScheme.outlineVariant.withAlpha(80)),
      ),
      color: colorScheme.surfaceContainerLowest,
      items: [
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
    ).then((chosen) {
      if (chosen != null) {
        onEngineChanged(chosen);
        if (controller.text.trim().isNotEmpty) {
          onSubmitted(controller.text.trim());
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final engineButtonKey = GlobalKey();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3, vertical: AppSpacing.x2),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  // Left search engine selector capsule badge
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: engineButtonKey,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      onTap: () => _showEnginePicker(context, engineButtonKey),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(color: colorScheme.outlineVariant.withAlpha(60)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(12),
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
                  ),
                  const SizedBox(width: AppSpacing.x2),
                  // Center omnibox text input
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
                            hintText: 'Search or enter address',
                            hintStyle: AppTypography.bodyMd.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            suffixIcon: value.text.isNotEmpty
                                ? IconButton(
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
                icon: Icon(PhosphorIcons.broadcast, size: 20, color: colorScheme.primary),
                onPressed: onOpenMediaGrabber,
              ),
            ),
            const SizedBox(width: AppSpacing.x1),
          ],
          // Downloads screen action
          IconButton.filledTonal(
            tooltip: 'Downloads',
            icon: const Icon(PhosphorIcons.downloadSimple, size: 20),
            onPressed: onOpenDownloads,
          ),
        ],
      ),
    );
  }
}

