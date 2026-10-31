import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_typography.dart';
import '../models/browser_tab.dart';
import 'tab_favicon.dart';

/// Modal bottom sheet for managing tabs matching Figma specification.
class BrowserTabsSheet extends StatefulWidget {
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
  State<BrowserTabsSheet> createState() => _BrowserTabsSheetState();
}

class _BrowserTabsSheetState extends State<BrowserTabsSheet> {
  int _seg = 0;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF131620) : const Color(0xFFFFFFFF);
    final border = dark ? const Color(0xFF1E2433) : const Color(0xFFE2E8F0);
    final handle = dark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

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
                    _SegControl(dark: dark, count: widget.tabs.length, seg: _seg, onSeg: (i) => setState(() => _seg = i)),
                    _NewTabBtn(dark: dark, onTap: widget.onNewTab),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: widget.tabs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => TabItemTile(
                    tab: widget.tabs[i],
                    dark: dark,
                    onSelect: () => widget.onSelect(widget.tabs[i].id),
                    onClose: () => widget.onClose(widget.tabs[i].id),
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

class _SegControl extends StatelessWidget {
  final bool dark;
  final int count;
  final int seg;
  final ValueChanged<int> onSeg;

  const _SegControl({required this.dark, required this.count, required this.seg, required this.onSeg});

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
          _Btn('Tabs', PhosphorIcons.browsers, count, seg == 0, dark, () => onSeg(0)),
          const SizedBox(width: 4),
          _Btn('Private', PhosphorIcons.eyeglasses, null, seg == 1, dark, () => onSeg(1)),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final IconData icon;
  final int? count;
  final bool active;
  final bool dark;
  final VoidCallback onTap;

  const _Btn(this.label, this.icon, this.count, this.active, this.dark, this.onTap);

  @override
  Widget build(BuildContext context) {
    final bg = active ? (dark ? const Color(0xFF242C3F) : const Color(0xFFFFFFFF)) : Colors.transparent;
    final shadows = active && !dark
        ? const [BoxShadow(color: Color(0x140F172A), offset: Offset(0, 1), blurRadius: 3)]
        : null;
    final fg = active
        ? (dark ? const Color(0xFFFFFFFF) : const Color(0xFF0F172A))
        : (dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(15), boxShadow: shadows),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
            Text(label, style: AppTypography.bodySm.copyWith(color: fg, fontWeight: active ? FontWeight.w600 : FontWeight.w500, fontSize: 13)),
            if (count != null) ...[
              const SizedBox(width: 6),
              Text('$count', style: AppTypography.bodyXs.copyWith(color: dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }
}

class _NewTabBtn extends StatelessWidget {
  final bool dark;
  final VoidCallback onTap;

  const _NewTabBtn({required this.dark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFFEDF0F6) : const Color(0xFF0F172A);
    final fg = dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    final brd = dark ? const Color(0xFF3B4B6E) : Colors.transparent;

    return Material(
      color: bg,
      shape: StadiumBorder(side: BorderSide(color: brd)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PhosphorIcons.plusBold, size: 14, color: fg),
              const SizedBox(width: 6),
              Text('New Tab', style: AppTypography.bodySm.copyWith(color: fg, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
