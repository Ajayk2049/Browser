import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../../../theme/tokens/app_typography.dart';
import '../models/search_engine.dart';

/// Top address bar matching the mobile mock-up with Star bookmark trigger,
/// secure lock indicator, centered URL/search omnibox, and reload button.
/// Complies with rules.md §13, §25.1, §25.2, §25.7, and §29.2 (< 250 lines).
class BrowserAddressBar extends StatefulWidget {
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
  final bool isHome;

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
    this.isHome = false,
  });

  @override
  State<BrowserAddressBar> createState() => _BrowserAddressBarState();
}

class _BrowserAddressBarState extends State<BrowserAddressBar> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasFocus = _focusNode.hasFocus;

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
                  // Left Star button
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: widget.onToggleBookmark == null
                          ? null
                          : (widget.isBookmarked ? 'Remove bookmark' : 'Bookmark this page'),
                      icon: Icon(
                        widget.isBookmarked ? PhosphorIcons.starFill : PhosphorIcons.star,
                        size: 20,
                        color: widget.isBookmarked
                            ? const Color(0xFFEAB308)
                            : (widget.onToggleBookmark == null
                                ? colorScheme.onSurfaceVariant.withValues(alpha: 0.35)
                                : colorScheme.onSurfaceVariant),
                      ),
                      onPressed: widget.onToggleBookmark,
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Lock indicator
                  Tooltip(
                    message: 'View site information',
                    child: InkWell(
                      onTap: widget.onOpenPageInfo,
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
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focusNode,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.search,
                      textAlign: TextAlign.center,
                      textAlignVertical: TextAlignVertical.center,
                      onSubmitted: widget.onSubmitted,
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
                        hintText: hasFocus
                            ? null
                            : (widget.isHome ? 'Welcome to Dab Browser' : 'Search or enter address'),
                        hintStyle: AppTypography.bodyMd.copyWith(
                          color: widget.isHome
                              ? colorScheme.onSurface
                              : colorScheme.onSurfaceVariant,
                          fontWeight: widget.isHome ? FontWeight.w600 : FontWeight.w400,
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
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
                      onPressed: widget.onReload,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Dynamic Media Grabber button
          if (widget.detectedMediaCount > 0) ...[
            const SizedBox(width: AppSpacing.x2),
            Badge(
              label: Text('${widget.detectedMediaCount}'),
              child: IconButton.filledTonal(
                tooltip: 'Grab Media',
                style: IconButton.styleFrom(
                  fixedSize: const Size(44, 44),
                  padding: EdgeInsets.zero,
                ),
                icon: Icon(PhosphorIcons.broadcast, size: 20, color: colorScheme.primary),
                onPressed: widget.onOpenMediaGrabber,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
