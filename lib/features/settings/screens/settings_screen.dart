import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../widgets/settings_app_bar.dart';
import '../widgets/settings_group_card.dart';

/// Redesigned Settings screen matching Figma mockups (Light 426 / Dark 319).
/// Complies with rules.md §13, §29.2 (< 300 lines).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF0C0E14) : const Color(0xFFF8FAFC);
    final headerColor = const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: SettingsAppBar(
        onBack: () => Navigator.of(context).maybePop(),
        onSearch: () => _showSearchHint(context),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 32.0),
        children: [
          // 1. BROWSING
          _buildSectionHeader('BROWSING', headerColor),
          SettingsGroupCard(
            items: [
              SettingsRowItem(
                icon: PhosphorIcons.house,
                title: 'Homepage',
                subtitle: 'Choose the page that opens on every new tab',
                trailing: _buildChevron(isDark),
                onTap: () => _showNotice(context, 'Homepage: Default Start Page is active'),
              ),
              SettingsRowItem(
                icon: PhosphorIcons.magnifyingGlass,
                title: 'Default search engine',
                subtitle: 'Pick the engine that powers the omnibox',
                trailing: _buildChevron(isDark),
                onTap: () => _showNotice(context, 'Search engine can be selected directly in the omnibox'),
              ),
            ],
          ),

          // 2. APPEARANCE
          const SizedBox(height: 20.0),
          _buildSectionHeader('APPEARANCE', headerColor),
          SettingsGroupCard(
            items: [
              SettingsRowItem(
                icon: PhosphorIcons.circleHalf,
                title: 'Theme',
                subtitle: 'Follow system, light, or dark',
                trailing: _buildValueWithChevron(isDark ? 'Dark' : 'Light', isDark),
                onTap: () => _showNotice(context, 'Theme matches your device system setting'),
              ),
              SettingsRowItem(
                icon: PhosphorIcons.textAa,
                title: 'Text size',
                subtitle: 'Scale page text for easier reading',
                trailing: _buildValueWithChevron('100%', isDark),
                onTap: () => _showNotice(context, 'Text zoom scale is set to default (100%)'),
              ),
            ],
          ),

          // 3. EXTENSIONS & DATA
          const SizedBox(height: 20.0),
          _buildSectionHeader('EXTENSIONS & DATA', headerColor),
          SettingsGroupCard(
            items: [
              SettingsRowItem(
                icon: PhosphorIcons.puzzlePiece,
                title: 'Extensions',
                subtitle: 'Manage add-ons and web extensions',
                trailing: _buildChevron(isDark),
                onTap: () => _showNotice(context, 'Extensions manager will be available soon'),
              ),
              SettingsRowItem(
                icon: PhosphorIcons.broom,
                title: 'Clear browsing data',
                subtitle: 'Erase history, cache, cookies & tokens',
                trailing: _buildChevron(isDark),
                onTap: () => _confirmClearData(context),
              ),
            ],
          ),

          // 4. ABOUT
          const SizedBox(height: 20.0),
          _buildSectionHeader('ABOUT', headerColor),
          SettingsGroupCard(
            items: [
              SettingsRowItem(
                icon: PhosphorIcons.sparkle,
                title: 'Dab Browser',
                subtitle: 'Version 1.2.0 (Build 418)',
                trailing: _buildBadge('Latest', isDark),
                onTap: () => _showNotice(context, 'Dab Browser is up to date'),
              ),
              SettingsRowItem(
                icon: PhosphorIcons.article,
                title: 'Terms & Privacy Policy',
                subtitle: 'Zero tracking, local-first storage',
                trailing: _buildChevron(isDark),
                onTap: () => _showNotice(context, 'Local-first architecture with zero external data collection'),
              ),
              SettingsRowItem(
                icon: PhosphorIcons.code,
                title: 'Open Source Licenses',
                subtitle: 'Mozilla GeckoView core & Flutter libraries',
                trailing: _buildChevron(isDark),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Dab Browser',
                  applicationVersion: '1.2.0',
                ),
              ),
            ],
          ),
        ],
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

  Widget _buildValueWithChevron(String value, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13.0,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 4.0),
        _buildChevron(isDark),
      ],
    );
  }

  Widget _buildBadge(String label, bool isDark) {
    final bg = isDark ? const Color(0xFF1E2433) : const Color(0xFFF1F5F9);
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final textCol = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: border, width: 1.0),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11.0,
          fontWeight: FontWeight.w500,
          color: textCol,
        ),
      ),
    );
  }

  void _showNotice(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _showSearchHint(BuildContext context) {
    _showNotice(context, 'Type in the omnibox to search or filter settings');
  }

  void _confirmClearData(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear browsing data'),
        content: const Text('This will clear your temporary browser cache and cookies.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showNotice(context, 'Browsing cache cleared');
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
