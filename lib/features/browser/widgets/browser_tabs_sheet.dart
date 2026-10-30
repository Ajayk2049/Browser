import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../../../theme/tokens/app_typography.dart';
import '../models/browser_tab.dart';

/// Tab manager presented as a bottom sheet.
///
/// Lists every open tab, highlights the active one, and offers switching,
/// closing, and opening a new tab. Purely presentational — the browser screen
/// owns the tab list and reacts to [onSelect], [onClose] and [onNewTab].
class BrowserTabsSheet extends StatelessWidget {
  final List<BrowserTabInfo> tabs;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onClose;
  final VoidCallback onNewTab;

  const BrowserTabsSheet({
    super.key,
    required this.tabs,
    required this.onSelect,
    required this.onClose,
    required this.onNewTab,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.m3Xl),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.x3),
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x4,
                  AppSpacing.x3,
                  AppSpacing.x2,
                  AppSpacing.x2,
                ),
                child: Row(
                  children: [
                    Text(
                      'Tabs',
                      style: AppTypography.displaySm.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    _CountBadge(count: tabs.length),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: onNewTab,
                      icon: const Icon(PhosphorIcons.plus, size: 18),
                      label: const Text('New tab'),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.x4,
                    0,
                    AppSpacing.x4,
                    AppSpacing.x4,
                  ),
                  itemCount: tabs.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.x2),
                  itemBuilder: (context, index) {
                    final tab = tabs[index];
                    return _TabTile(
                      tab: tab,
                      onSelect: () => onSelect(tab.id),
                      onClose: () => onClose(tab.id),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '$count',
        style: AppTypography.bodyXs.copyWith(
          fontWeight: FontWeight.w700,
          color: colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _TabTile extends StatelessWidget {
  final BrowserTabInfo tab;
  final VoidCallback onSelect;
  final VoidCallback onClose;

  const _TabTile({
    required this.tab,
    required this.onSelect,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: tab.isActive
          ? colorScheme.secondaryContainer.withValues(alpha: 0.5)
          : colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(AppRadius.m3Lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onSelect,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.m3Lg),
            border: Border.all(
              color: tab.isActive
                  ? colorScheme.primary.withValues(alpha: 0.6)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x3,
            vertical: AppSpacing.x3,
          ),
          child: Row(
            children: [
              Icon(
                PhosphorIcons.globeSimple,
                size: 20,
                color: tab.isActive
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tab.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMd.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tab.displayUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyXs.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.x2),
              IconButton(
                tooltip: 'Close tab',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
                icon: Icon(
                  PhosphorIcons.x,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                onPressed: onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
