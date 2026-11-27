import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../../../theme/tokens/app_typography.dart';
import '../../settings/services/search_engine_settings_service.dart';
import '../models/search_engine.dart';
import '../services/search_suggestions_service.dart';
import 'search_suggestions_overlay.dart';

/// Top address bar with omnibox, star, lock, and live search suggestions.
/// Complies with rules.md §13, §25.1, §25.2, §25.7, and §29.2 (< 250 lines).
class BrowserAddressBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final bool isBookmarked;
  final VoidCallback? onToggleBookmark;
  final VoidCallback? onOpenPageInfo;
  final VoidCallback onReload;
  final bool isLoading;
  final SearchEngine selectedEngine;
  final ValueChanged<SearchEngine>? onEngineChanged;
  final bool isHome;
  final bool isPrivate;

  const BrowserAddressBar({
    super.key,
    required this.controller,
    required this.onSubmitted,
    this.isBookmarked = false,
    this.onToggleBookmark,
    this.onOpenPageInfo,
    required this.onReload,
    this.isLoading = false,
    this.selectedEngine = SearchEngine.google,
    this.onEngineChanged,
    this.isHome = false,
    this.isPrivate = false,
  });

  @override
  State<BrowserAddressBar> createState() => _BrowserAddressBarState();
}

class _BrowserAddressBarState extends State<BrowserAddressBar> {
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  final Object _tapRegionGroupId = Object();
  OverlayEntry? _overlayEntry;
  List<SearchSuggestionItem> _suggestions = [];
  Timer? _debounceTimer;
  bool _wasFocused = false;
  bool _pendingSelectAll = false;
  bool _didSubmit = false;
  String _textBeforeFocus = '';

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _removeOverlay();
    _focusNode.removeListener(_onFocusChange);
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    final hasFocus = _focusNode.hasFocus;
    final gainedFocus = !_wasFocused && hasFocus;
    final lostFocus = _wasFocused && !hasFocus;
    _wasFocused = hasFocus;

    if (gainedFocus) {
      _didSubmit = false;
      _textBeforeFocus = widget.controller.text;
      if (!widget.isHome && widget.controller.text.isNotEmpty) {
        _pendingSelectAll = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _selectAllIfFocused());
      }
    } else if (lostFocus) {
      _pendingSelectAll = false;
      _debounceTimer?.cancel();
      _removeOverlay();
      if (!_didSubmit && widget.controller.text != _textBeforeFocus) {
        widget.controller.text = _textBeforeFocus;
      }
    }
    if (mounted) setState(() {});
  }

  void _selectAllIfFocused() {
    if (mounted && _focusNode.hasFocus && widget.controller.text.isNotEmpty) {
      widget.controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.controller.text.length,
      );
    }
  }

  void _onTextChanged() {
    if (!_focusNode.hasFocus) return;
    setState(() {});
    _debounceTimer?.cancel();
    final text = widget.controller.text;
    if (text == _textBeforeFocus && !widget.isHome) {
      _removeOverlay();
      return;
    }
    _debounceTimer = Timer(
      const Duration(milliseconds: 200),
      () => _triggerSuggestions(widget.controller.text),
    );
  }

  Future<void> _triggerSuggestions(String text) async {
    final enabled = SearchEngineSettingsService.instance.settings.searchSuggestions;
    if (!enabled || text.trim().isEmpty) {
      _suggestions = [];
      _removeOverlay();
      return;
    }
    final items = await SearchSuggestionsService.instance.getSuggestions(text, widget.selectedEngine);
    if (!mounted || !_focusNode.hasFocus) return;
    _suggestions = items;
    if (_suggestions.isNotEmpty) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _submitInput(String raw) {
    _didSubmit = true;
    _debounceTimer?.cancel();
    _removeOverlay();
    _focusNode.unfocus();
    widget.onSubmitted(raw);
  }

  void _showOverlay() {
    _removeOverlay();
    final overlayState = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (ctx) => Positioned(
        width: MediaQuery.of(ctx).size.width - 24,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 50),
          child: SearchSuggestionsOverlay(
            suggestions: _suggestions,
            tapRegionGroupId: _tapRegionGroupId,
            onSelectSuggestion: _submitInput,
          ),
        ),
      ),
    );
    overlayState.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasFocus = _focusNode.hasFocus;
    final isPriv = widget.isPrivate;
    final fgText = isPriv ? Colors.white : colorScheme.onSurface;
    final fgVariant = isPriv ? const Color(0xFFCBD5E1) : colorScheme.onSurfaceVariant;
    final idleBorder = isPriv ? Colors.white.withValues(alpha: 0.85) : colorScheme.outlineVariant.withValues(alpha: 0.5);
    final borderCol = hasFocus ? (isPriv ? Colors.white : colorScheme.primary.withValues(alpha: 0.8)) : idleBorder;
    final boxBg = isPriv ? const Color(0xFF1E2433) : colorScheme.surfaceContainerHighest;
    final showClear = hasFocus && widget.controller.text.isNotEmpty;

    return TapRegion(
      groupId: _tapRegionGroupId,
      onTapOutside: (_) {
        if (hasFocus) _focusNode.unfocus();
      },
      child: CompositedTransformTarget(
        link: _layerLink,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3, vertical: AppSpacing.x2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: boxBg,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: borderCol, width: hasFocus || isPriv ? 1.4 : 1.0),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: isPriv
                            ? const Icon(PhosphorIcons.eyeglasses, size: 20, color: Colors.white)
                            : IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: widget.onToggleBookmark == null ? null : (widget.isBookmarked ? 'Remove bookmark' : 'Bookmark this page'),
                                icon: Icon(
                                  widget.isBookmarked ? PhosphorIcons.starFill : PhosphorIcons.star,
                                  size: 20,
                                  color: widget.isBookmarked
                                      ? const Color(0xFFEAB308)
                                      : (widget.onToggleBookmark == null ? colorScheme.onSurfaceVariant.withValues(alpha: 0.35) : colorScheme.onSurfaceVariant),
                                ),
                                onPressed: widget.onToggleBookmark,
                              ),
                      ),
                      const SizedBox(width: 4),
                      Tooltip(
                        message: 'View site information',
                        child: InkWell(
                          onTap: widget.onOpenPageInfo,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                            child: Icon(PhosphorIcons.lockSimple, size: 16, color: fgVariant),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: TextField(
                          controller: widget.controller,
                          focusNode: _focusNode,
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.search,
                          autocorrect: false,
                          maxLines: 1,
                          scrollPhysics: const ClampingScrollPhysics(),
                          textAlign: hasFocus ? TextAlign.start : TextAlign.center,
                          textAlignVertical: TextAlignVertical.center,
                          onTap: () {
                            if (_pendingSelectAll && !widget.isHome && widget.controller.text.isNotEmpty) {
                              _pendingSelectAll = false;
                              WidgetsBinding.instance.addPostFrameCallback((_) => _selectAllIfFocused());
                            }
                          },
                          onSubmitted: _submitInput,
                          style: AppTypography.bodyMd.copyWith(color: fgText, fontWeight: FontWeight.w600, height: 1.2),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: false,
                            fillColor: Colors.transparent,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: hasFocus
                                ? 'Search or enter address'
                                : (widget.isHome ? (isPriv ? 'Private Browsing' : 'Welcome to Dab Browser') : 'Search or enter address'),
                            hintStyle: AppTypography.bodyMd.copyWith(
                              color: isPriv
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : (!hasFocus && widget.isHome ? colorScheme.onSurface : colorScheme.onSurfaceVariant),
                              fontWeight: !hasFocus && widget.isHome ? FontWeight.w600 : FontWeight.w400,
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: showClear
                            ? IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Clear',
                                icon: Icon(PhosphorIcons.xCircle, size: 20, color: fgVariant),
                                onPressed: () {
                                  widget.controller.clear();
                                  _suggestions = [];
                                  _removeOverlay();
                                },
                              )
                            : IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Reload',
                                icon: Icon(PhosphorIcons.arrowClockwise, size: 20, color: fgVariant),
                                onPressed: widget.onReload,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
