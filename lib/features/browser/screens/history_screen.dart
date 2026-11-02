import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../models/history_item.dart';
import '../services/history_service.dart';
import '../widgets/history_item_tile.dart';

/// Full-screen History management matching Figma nodes 941 (Light) / 839 (Dark).
/// Complies with rules.md §13, §29.2 (< 300 lines).
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    HistoryService.instance.init();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF0C0E14) : const Color(0xFFF8FAFC);
    final btnBg = isDark ? const Color(0xFF1E2433) : const Color(0xFFF1F5F9);
    final btnBorder = isDark ? const Color(0xFF2A3245) : const Color(0xFFE2E8F0);
    final fg = isDark ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60.0),
        child: SafeArea(
          bottom: false,
          child: Container(
            height: 60.0,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                _circleBtn(() => Navigator.of(context).maybePop(), btnBg, btnBorder, Icon(PhosphorIcons.caretLeft, size: 20, color: fg)),
                Expanded(
                  child: Center(
                    child: Text('History', style: TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w600, color: fg)),
                  ),
                ),
                _buildMoreMenu(btnBg, btnBorder, fg),
              ],
            ),
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: HistoryService.instance,
        builder: (context, _) {
          final allItems = HistoryService.instance.items;
          final filtered = _searchQuery.isEmpty
              ? allItems
              : allItems.where((h) => h.title.toLowerCase().contains(_searchQuery) || h.url.toLowerCase().contains(_searchQuery)).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 32.0),
            children: [
              _buildSearchPill(isDark),
              const SizedBox(height: 16.0),
              if (allItems.isEmpty)
                _buildEmptyState(isDark)
              else if (filtered.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.only(top: 60), child: Text('No results found', style: TextStyle(color: Color(0xFF64748B)))))
              else
                ..._buildGroupedHistory(filtered, isDark),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchPill(bool isDark) {
    final bg = isDark ? const Color(0xFF131722) : const Color(0xFFFFFFFF);
    final border = isDark ? const Color(0xFF272E3F) : const Color(0xFFE2E8F0);
    final textCol = isDark ? Colors.white : const Color(0xFF0F172A);

    return Container(
      height: 44.0,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(22.0), border: Border.all(color: border, width: 1.0)),
      padding: const EdgeInsets.symmetric(horizontal: 14.0),
      child: Row(
        children: [
          const Icon(PhosphorIcons.magnifyingGlass, size: 18.0, color: Color(0xFF64748B)),
          const SizedBox(width: 8.0),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(fontFamily: 'Inter', fontSize: 13.0, color: textCol),
              decoration: const InputDecoration(
                hintText: 'Search history',
                hintStyle: TextStyle(fontFamily: 'Inter', fontSize: 13.0, color: Color(0xFF64748B)),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () => _searchCtrl.clear(),
              child: const Icon(PhosphorIcons.xCircleFill, size: 18.0, color: Color(0xFF94A3B8)),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedHistory(List<HistoryItem> items, bool isDark) {
    final now = DateTime.now();
    final today = <HistoryItem>[];
    final yesterday = <HistoryItem>[];
    final earlier = <HistoryItem>[];

    for (final item in items) {
      final diff = DateTime(now.year, now.month, now.day).difference(DateTime(item.timestamp.year, item.timestamp.month, item.timestamp.day)).inDays;
      if (diff == 0) today.add(item);
      else if (diff == 1) yesterday.add(item);
      else earlier.add(item);
    }

    final groups = <Widget>[];
    if (today.isNotEmpty) groups.add(_buildSection('TODAY', today, isDark, showClearAll: true));
    if (yesterday.isNotEmpty) groups.add(_buildSection('YESTERDAY', yesterday, isDark));
    if (earlier.isNotEmpty) groups.add(_buildSection('EARLIER', earlier, isDark));
    return groups;
  }

  Widget _buildSection(String title, List<HistoryItem> items, bool isDark, {bool showClearAll = false}) {
    final cardBg = isDark ? const Color(0xFF131722) : const Color(0xFFFFFFFF);
    final cardBorder = isDark ? const Color(0xFF272E3F) : const Color(0xFFE2E8F0);
    final dividerColor = isDark ? const Color(0xFF1A202E) : const Color(0xFFF1F5F9);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4.0, right: 4.0, bottom: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontFamily: 'Inter', fontSize: 11.0, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: Color(0xFF64748B))),
                if (showClearAll)
                  GestureDetector(
                    onTap: () => _confirmWipeHistory(context),
                    child: Text('Clear all', style: TextStyle(fontFamily: 'Inter', fontSize: 11.0, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF0F172A))),
                  ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(18.0), border: Border.all(color: cardBorder, width: 1.0)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18.0),
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) Container(height: 1.0, margin: const EdgeInsets.only(left: 64.0, right: 12.0), color: dividerColor),
                    HistoryItemTile(
                      item: items[i],
                      isDark: isDark,
                      onTap: () => Navigator.of(context).pop(items[i].url),
                      onDelete: () => HistoryService.instance.removeItem(items[i].id),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreMenu(Color bg, Color border, Color iconColor) {
    return PopupMenuButton<String>(
      onSelected: (val) {
        if (val == 'clear_all') _confirmWipeHistory(context);
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)),
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'clear_all',
          child: Row(
            children: [
              Icon(PhosphorIcons.trash, size: 18.0, color: Colors.redAccent),
              SizedBox(width: 10.0),
              Text('Wipe all history', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
      child: _circleBtn(null, bg, border, Icon(PhosphorIcons.dotsThreeVertical, size: 20.0, color: iconColor)),
    );
  }

  Widget _circleBtn(VoidCallback? onTap, Color bg, Color border, Widget child) {
    return Container(
      width: 40.0,
      height: 40.0,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle, border: Border.all(color: border)),
      child: IconButton(padding: EdgeInsets.zero, icon: child, onPressed: onTap),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 80.0),
      child: Column(
        children: [
          Icon(PhosphorIcons.clockCounterClockwise, size: 48.0, color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          const SizedBox(height: 12.0),
          Text('No browsing history', style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
          const SizedBox(height: 4.0),
          const Text('Websites you visit will appear here', style: TextStyle(fontSize: 12.0, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  void _confirmWipeHistory(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Wipe browsing history?'),
        content: const Text('This will erase all your visited pages. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              HistoryService.instance.clearAll();
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(content: Text('History wiped'), duration: Duration(seconds: 2)));
            },
            child: const Text('Wipe All'),
          ),
        ],
      ),
    );
  }
}
