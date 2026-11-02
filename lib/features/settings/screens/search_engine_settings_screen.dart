import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../browser/models/search_engine.dart';
import '../services/search_engine_settings_service.dart';
import '../widgets/settings_app_bar.dart';
import '../widgets/settings_group_card.dart';

/// Search Engine Settings Screen matching Figma frames 1093 (Light) & 507 (Dark).
/// Complies with rules.md §13, §29.2 (< 300 lines).
class SearchEngineSettingsScreen extends StatelessWidget {
  const SearchEngineSettingsScreen({super.key});

  static const _engineMeta = [
    (SearchEngine.duckDuckGo, 'D', 'duckduckgo.com'),
    (SearchEngine.google, 'G', 'google.com'),
    (SearchEngine.bing, 'B', 'bing.com'),
    (SearchEngine.brave, '▲', 'search.brave.com'),
    (SearchEngine.startpage, 'S', 'startpage.com'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF0C0E14) : const Color(0xFFF8FAFC);
    const headerColor = Color(0xFF64748B);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: SettingsAppBar(
        onBack: () => Navigator.of(context).maybePop(),
        onSearch: () {},
      ),
      body: ListenableBuilder(
        listenable: SearchEngineSettingsService.instance,
        builder: (context, _) {
          final s = SearchEngineSettingsService.instance.settings;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 32.0),
            children: [
              _buildSectionHeader('SEARCH ENGINE', headerColor),
              SettingsGroupCard(
                items: [
                  for (final meta in _engineMeta)
                    SettingsRowItem(
                      customLeading: _buildEngineIconBox(meta.$2, isDark),
                      title: meta.$1.displayName,
                      subtitle: meta.$3,
                      trailing: _buildRadio(s.defaultEngine == meta.$1, isDark),
                      onTap: () => SearchEngineSettingsService.instance.updateSettings(
                        (cur) => cur.copyWith(defaultEngine: meta.$1),
                      ),
                    ),
                  if (s.customEngineName.isNotEmpty)
                    SettingsRowItem(
                      customLeading: _buildEngineIconBox('+', isDark),
                      title: s.customEngineName,
                      subtitle: s.customEngineUrl,
                      trailing: _buildRadio(s.defaultEngine == SearchEngine.custom, isDark),
                      onTap: () => SearchEngineSettingsService.instance.updateSettings(
                        (cur) => cur.copyWith(defaultEngine: SearchEngine.custom),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20.0),
              _buildSectionHeader('OPTIONS', headerColor),
              SettingsGroupCard(
                items: [
                  SettingsRowItem(
                    icon: PhosphorIcons.magnifyingGlass,
                    title: 'Search suggestions',
                    subtitle: 'Show suggestions as you type',
                    trailing: _buildSwitch(s.searchSuggestions, isDark, (val) {
                      SearchEngineSettingsService.instance.updateSettings((c) => c.copyWith(searchSuggestions: val));
                    }),
                    onTap: () => SearchEngineSettingsService.instance.updateSettings(
                      (c) => c.copyWith(searchSuggestions: !c.searchSuggestions),
                    ),
                  ),
                  SettingsRowItem(
                    icon: PhosphorIcons.check,
                    title: 'Safe search',
                    subtitle: 'Filter explicit results (${s.safeSearchMode})',
                    trailing: _buildChevron(isDark),
                    onTap: () => _chooseSafeSearchDialog(context, s.safeSearchMode),
                  ),
                ],
              ),
              const SizedBox(height: 20.0),
              _buildSectionHeader('MANAGE', headerColor),
              SettingsGroupCard(
                items: [
                  SettingsRowItem(
                    icon: PhosphorIcons.listBullets,
                    title: 'Manage search engines',
                    subtitle: 'Reorder or remove engines',
                    trailing: _buildChevron(isDark),
                    onTap: () => _manageEnginesDialog(context, s),
                  ),
                  SettingsRowItem(
                    icon: PhosphorIcons.plus,
                    title: 'Add search engine',
                    subtitle: 'Add a custom engine by URL',
                    trailing: _buildChevron(isDark),
                    onTap: () => _addEngineDialog(context, s),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) => Padding(
        padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
        child: Text(
          title,
          style: TextStyle(fontFamily: 'Inter', fontSize: 11.0, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: color),
        ),
      );

  Widget _buildEngineIconBox(String letter, bool isDark) => Container(
        width: 38.0,
        height: 38.0,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2433) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        alignment: Alignment.center,
        child: Text(
          letter,
          style: TextStyle(fontFamily: 'Inter', fontSize: 17.0, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
        ),
      );

  Widget _buildRadio(bool isSelected, bool isDark) {
    if (isSelected) {
      return Container(
        width: 22.0,
        height: 22.0,
        decoration: BoxDecoration(
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Container(
          width: 8.0,
          height: 8.0,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      );
    }
    return Container(
      width: 22.0,
      height: 22.0,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
          width: 1.5,
        ),
      ),
    );
  }

  Widget _buildChevron(bool isDark) => Icon(
        PhosphorIcons.caretRight,
        size: 18.0,
        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
      );

  Widget _buildSwitch(bool value, bool isDark, ValueChanged<bool> onChanged) {
    return SizedBox(
      height: 24.0,
      child: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: isDark ? Colors.white : const Color(0xFF0F172A),
        activeTrackColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        inactiveThumbColor: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
        inactiveTrackColor: isDark ? const Color(0xFF1E2433) : const Color(0xFFF1F5F9),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  void _chooseSafeSearchDialog(BuildContext context, String current) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('SafeSearch Filtering'),
        children: [
          for (final opt in const ['Strict', 'Moderate', 'Off'])
            RadioListTile<String>(
              value: opt,
              groupValue: current,
              title: Text(opt),
              onChanged: (val) {
                if (val != null) {
                  SearchEngineSettingsService.instance.updateSettings((c) => c.copyWith(safeSearchMode: val));
                  Navigator.of(ctx).pop();
                }
              },
            ),
        ],
      ),
    );
  }

  void _addEngineDialog(BuildContext context, SearchEngineSettingsModel s) {
    final nameCtrl = TextEditingController(text: s.customEngineName);
    final urlCtrl = TextEditingController(text: s.customEngineUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Search Engine'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Engine Name')),
            const SizedBox(height: 8),
            TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'Search URL (with %s)', hintText: 'https://example.com/search?q=%s')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final n = nameCtrl.text.trim(), u = urlCtrl.text.trim();
              if (n.isNotEmpty && u.isNotEmpty) {
                SearchEngineSettingsService.instance.updateSettings(
                  (cur) => cur.copyWith(customEngineName: n, customEngineUrl: u, defaultEngine: SearchEngine.custom),
                );
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Save & Select'),
          ),
        ],
      ),
    );
  }

  void _manageEnginesDialog(BuildContext context, SearchEngineSettingsModel s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Manage Search Engines'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Built-in engines: 5 active'),
            if (s.customEngineName.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Text('Custom: ${s.customEngineName}')),
                  IconButton(
                    icon: const Icon(PhosphorIcons.trash, size: 18),
                    onPressed: () {
                      SearchEngineSettingsService.instance.updateSettings(
                        (cur) => cur.copyWith(
                          customEngineName: '',
                          customEngineUrl: '',
                          defaultEngine: cur.defaultEngine == SearchEngine.custom ? SearchEngine.duckDuckGo : cur.defaultEngine,
                        ),
                      );
                      Navigator.of(ctx).pop();
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close'))],
      ),
    );
  }
}
