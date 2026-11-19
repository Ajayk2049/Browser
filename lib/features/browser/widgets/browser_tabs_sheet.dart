import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_typography.dart';
import '../models/browser_tab.dart';
import 'tab_favicon.dart';

/// Modal bottom sheet for managing tabs with independent normal and private pools.
/// Complies with rules.md §13, §29.2 (< 250 lines).
class BrowserTabsSheet extends StatefulWidget {
  final List<BrowserTabInfo> normalTabs;
  final List<BrowserTabInfo> privateTabs;
  final int initialSegment;
  final void Function(String id, bool isPrivate) onSelect;
  final void Function(String id, bool isPrivate) onClose;
  final void Function(bool isPrivate) onNewTab;

  const BrowserTabsSheet({
    super.key,
    required this.normalTabs,
    required this.privateTabs,
    this.initialSegment = 0,
    required this.onSelect,
    required this.onClose,
    required this.onNewTab,
  });

  @override
  State<BrowserTabsSheet> createState() => _BrowserTabsSheetState();
}

class _BrowserTabsSheetState extends State<BrowserTabsSheet> {
  late final List<BrowserTabInfo> _normalTabs;
  late final List<BrowserTabInfo> _privateTabs;
  late int _seg;

  @override
  void initState() {
    super.initState();
    _normalTabs = List.from(widget.normalTabs);
    _privateTabs = List.from(widget.privateTabs);
    _seg = widget.initialSegment.clamp(0, 1);
  }

  void _handleClose(String id, bool isPriv) {
    setState(() {
      if (isPriv) {
        _privateTabs.removeWhere((t) => t.id == id);
      } else {
        _normalTabs.removeWhere((t) => t.id == id);
      }
    });
    widget.onClose(id, isPriv);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final isPriv = _seg == 1;
    final currentTabs = isPriv ? _privateTabs : _normalTabs;
    final bg = dark || isPriv ? const Color(0xFF131620) : const Color(0xFFFFFFFF);
    final border = dark || isPriv ? const Color(0xFF1E2433) : const Color(0xFFE2E8F0);
    final handle = dark || isPriv ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: 380,
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: border)),
          boxShadow: const [
            BoxShadow(color: Color(0x1A0F172A), offset: Offset(0, -8), blurRadius: 24),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: handle, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _SegControl(
                      dark: dark || isPriv,
                      normalCount: _normalTabs.length,
                      privateCount: _privateTabs.length,
                      seg: _seg,
                      onSeg: (i) => setState(() => _seg = i),
                    ),
                    if (currentTabs.isNotEmpty)
                      TabSheetNewTabBtn(dark: dark || isPriv, onTap: () => widget.onNewTab(isPriv)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: currentTabs.isEmpty
                    ? _buildEmptyState(isPriv, dark || isPriv)
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: currentTabs.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => TabItemTile(
                          tab: currentTabs[i],
                          dark: dark || isPriv,
                          onSelect: () => widget.onSelect(currentTabs[i].id, isPriv),
                          onClose: () => _handleClose(currentTabs[i].id, isPriv),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isPriv, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2433) : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(isPriv ? PhosphorIcons.eyeglasses : PhosphorIcons.browsers, size: 28, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 14),
          Text(
            isPriv ? 'Private Browsing' : 'No open tabs',
            style: AppTypography.displaySm.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isPriv
                ? "Pages in private tabs aren't saved in your history and disappear when closed."
                : 'Open a new tab to start browsing.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySm.copyWith(color: const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 20),
          TabSheetNewTabBtn(dark: isDark, onTap: () => widget.onNewTab(isPriv)),
        ],
      ),
    );
  }
}

class _SegControl extends StatelessWidget {
  final bool dark;
  final int normalCount;
  final int privateCount;
  final int seg;
  final ValueChanged<int> onSeg;

  const _SegControl({
    required this.dark,
    required this.normalCount,
    required this.privateCount,
    required this.seg,
    required this.onSeg,
  });

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF1A1F2C) : const Color(0xFFF1F5F9);
    final brd = dark ? const Color(0xFF272E3F) : const Color(0xFFE2E8F0);
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18), border: Border.all(color: brd)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TabSheetSegmentBtn('Tabs', PhosphorIcons.browsers, normalCount, seg == 0, dark, () => onSeg(0)),
          const SizedBox(width: 4),
          TabSheetSegmentBtn('Private', PhosphorIcons.eyeglasses, privateCount > 0 ? privateCount : null, seg == 1, dark, () => onSeg(1)),
        ],
      ),
    );
  }
}
