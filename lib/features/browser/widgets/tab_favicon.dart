import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_typography.dart';
import '../models/browser_tab.dart';

/// Favicon squircle box used across tab tiles.
class TabFavicon extends StatelessWidget {
  final String url;
  final bool dark;

  const TabFavicon({super.key, required this.url, required this.dark});

  @override
  Widget build(BuildContext context) {
    final host = Uri.tryParse(url)?.host ?? '';
    final bg = dark ? const Color(0xFF1E2433) : const Color(0xFFFFFFFF);
    final brd = dark ? const Color(0xFF27334D) : const Color(0xFFE2E8F0);
    final iconCol = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final isHome = url.isEmpty || url == 'Welcome to Dab Browser' || url == 'dab.app/home';
    if (isHome) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: brd),
        ),
        alignment: Alignment.center,
        child: Icon(PhosphorIcons.house, size: 18, color: iconCol),
      );
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: brd),
      ),
      alignment: Alignment.center,
      child: host.isNotEmpty && !host.contains('dab.app')
          ? Image.network(
              'https://www.google.com/s2/favicons?domain=$host&sz=128',
              width: 18,
              height: 18,
              errorBuilder: (_, _, _) => Icon(PhosphorIcons.globeSimple, size: 18, color: iconCol),
            )
          : Icon(PhosphorIcons.globeSimple, size: 18, color: iconCol),
    );
  }
}

class TabItemTile extends StatelessWidget {
  final BrowserTabInfo tab;
  final bool dark;
  final VoidCallback onSelect;
  final VoidCallback onClose;

  const TabItemTile({
    super.key,
    required this.tab,
    required this.dark,
    required this.onSelect,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final bg = tab.isActive ? (dark ? const Color(0xFF1F283B) : const Color(0xFFF1F5F9)) : (dark ? const Color(0xFF1A1F2C) : const Color(0xFFF8FAFC));
    final brd = tab.isActive ? (dark ? const Color(0xFF38455E) : const Color(0xFF0F172A)) : (dark ? const Color(0xFF242C3F) : const Color(0xFFE2E8F0));
    final cBg = tab.isActive ? (dark ? const Color(0xFF27334D) : const Color(0xFFE2E8F0)) : (dark ? const Color(0xFF1E2433) : const Color(0xFFF1F5F9));
    final tCol = dark ? const Color(0xFFFFFFFF) : const Color(0xFF0F172A);
    final uCol = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: brd, width: tab.isActive ? 1.5 : 1.0)),
          child: Row(
            children: [
              TabFavicon(url: tab.url, dark: dark),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tab.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMd.copyWith(
                    color: tCol,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onClose,
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: cBg, shape: BoxShape.circle),
                  child: Icon(PhosphorIcons.xBold, size: 12, color: uCol),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TabSheetSegmentBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final int? count;
  final bool active;
  final bool dark;
  final VoidCallback onTap;

  const TabSheetSegmentBtn(this.label, this.icon, this.count, this.active, this.dark, this.onTap, {super.key});

  @override
  Widget build(BuildContext context) {
    final bg = active ? (dark ? const Color(0xFF242C3F) : const Color(0xFFFFFFFF)) : Colors.transparent;
    final fg = active ? (dark ? const Color(0xFFFFFFFF) : const Color(0xFF0F172A)) : const Color(0xFF94A3B8);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(15)),
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

class TabSheetNewTabBtn extends StatelessWidget {
  final bool dark;
  final VoidCallback onTap;

  const TabSheetNewTabBtn({super.key, required this.dark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFFEDF0F6) : const Color(0xFF0F172A);
    final fg = dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);

    return Material(
      color: bg,
      shape: const StadiumBorder(),
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
