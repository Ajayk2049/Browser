import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../services/homepage_settings_service.dart';
import '../widgets/settings_app_bar.dart';
import '../widgets/settings_group_card.dart';

/// Full-screen Homepage Settings matching Figma frames 818 (Light) / 425 (Dark).
/// Complies with rules.md §13, §29.2 (< 300 lines).
class HomepageSettingsScreen extends StatelessWidget {
  const HomepageSettingsScreen({super.key});

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
        listenable: HomepageSettingsService.instance,
        builder: (context, _) {
          final s = HomepageSettingsService.instance.settings;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 32.0),
            children: [
              // 1. ON STARTUP
              _buildSectionHeader('ON STARTUP', headerColor),
              SettingsGroupCard(
                items: [
                  SettingsRowItem(
                    icon: PhosphorIcons.house,
                    title: 'Open homepage on startup',
                    subtitle: 'Always start on your homepage',
                    trailing: _buildSwitch(s.openOnStartup, isDark, (val) {
                      HomepageSettingsService.instance.updateSettings((cur) => cur.copyWith(openOnStartup: val));
                    }),
                    onTap: () {
                      HomepageSettingsService.instance.updateSettings((cur) => cur.copyWith(openOnStartup: !cur.openOnStartup));
                    },
                  ),
                  SettingsRowItem(
                    icon: PhosphorIcons.browsers,
                    title: 'New tab opens homepage',
                    subtitle: 'Skip the blank new tab page',
                    trailing: _buildSwitch(s.newTabOpensHomepage, isDark, (val) {
                      HomepageSettingsService.instance.updateSettings((cur) => cur.copyWith(newTabOpensHomepage: val));
                    }),
                    onTap: () {
                      HomepageSettingsService.instance.updateSettings((cur) => cur.copyWith(newTabOpensHomepage: !cur.newTabOpensHomepage));
                    },
                  ),
                  SettingsRowItem(
                    icon: PhosphorIcons.arrowUpRight,
                    title: 'Custom homepage address',
                    subtitle: s.customHomepageUrl.isNotEmpty ? s.customHomepageUrl : 'Set a specific URL or page',
                    trailing: _buildChevron(isDark),
                    onTap: () => _editCustomUrlDialog(context, s.customHomepageUrl),
                  ),
                ],
              ),

              // 2. HOMEPAGE CONTENT
              const SizedBox(height: 20.0),
              _buildSectionHeader('HOMEPAGE CONTENT', headerColor),
              SettingsGroupCard(
                items: [
                  SettingsRowItem(
                    icon: PhosphorIcons.squaresFour,
                    title: 'Top sites & shortcuts',
                    subtitle: 'Show frequently visited sites',
                    trailing: _buildSwitch(s.showTopSites, isDark, (val) {
                      HomepageSettingsService.instance.updateSettings((cur) => cur.copyWith(showTopSites: val));
                    }),
                    onTap: () {
                      HomepageSettingsService.instance.updateSettings((cur) => cur.copyWith(showTopSites: !cur.showTopSites));
                    },
                  ),
                  SettingsRowItem(
                    icon: PhosphorIcons.listDashes,
                    title: 'Show bookmarks bar',
                    subtitle: 'Show saved bookmarks below',
                    trailing: _buildSwitch(s.showBookmarksBar, isDark, (val) {
                      HomepageSettingsService.instance.updateSettings((cur) => cur.copyWith(showBookmarksBar: val));
                    }),
                    onTap: () {
                      HomepageSettingsService.instance.updateSettings((cur) => cur.copyWith(showBookmarksBar: !cur.showBookmarksBar));
                    },
                  ),
                  SettingsRowItem(
                    icon: PhosphorIcons.magnifyingGlass,
                    title: 'Show search bar',
                    subtitle: 'Search from your homepage',
                    trailing: _buildSwitch(s.showSearchBar, isDark, (val) {
                      HomepageSettingsService.instance.updateSettings((cur) => cur.copyWith(showSearchBar: val));
                    }),
                    onTap: () {
                      HomepageSettingsService.instance.updateSettings((cur) => cur.copyWith(showSearchBar: !cur.showSearchBar));
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11.0,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: color,
        ),
      ),
    );
  }

  Widget _buildChevron(bool isDark) {
    return Icon(
      PhosphorIcons.caretRight,
      size: 18.0,
      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
    );
  }

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

  void _editCustomUrlDialog(BuildContext context, String currentUrl) {
    final controller = TextEditingController(text: currentUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom Homepage URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'https://example.com (leave empty for default)',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              HomepageSettingsService.instance.updateSettings(
                (cur) => cur.copyWith(customHomepageUrl: controller.text.trim()),
              );
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

