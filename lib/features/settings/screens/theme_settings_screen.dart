import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../services/appearance_settings_service.dart';
import '../widgets/settings_app_bar.dart';
import '../widgets/settings_group_card.dart';

/// Screen allowing users to select their theme preference (Figma 2479 Dark / 2530 Light).
/// Complies with rules.md §13, §29.2 (< 300 lines).
class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = AppearanceSettingsService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF0C0E14) : const Color(0xFFF8FAFC);
    final headerColor = const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: SettingsAppBar(
        title: 'Theme',
        showSearch: false,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: ListenableBuilder(
        listenable: service,
        builder: (context, _) {
          final currentMode = service.themeMode;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 32.0),
            children: [
              _buildSectionHeader('THEME PREFERENCE', headerColor),
              SettingsGroupCard(
                items: [
                  SettingsRowItem(
                    icon: PhosphorIcons.gear,
                    title: 'Follow system',
                    subtitle: 'Matches your device display mode',
                    trailing: _buildRadio(currentMode == ThemeMode.system, isDark),
                    onTap: () => service.setThemeMode(ThemeMode.system),
                  ),
                  SettingsRowItem(
                    icon: PhosphorIcons.moon,
                    title: 'Dark mode',
                    subtitle: 'Always use deep dark theme',
                    trailing: _buildRadio(currentMode == ThemeMode.dark, isDark),
                    onTap: () => service.setThemeMode(ThemeMode.dark),
                  ),
                  SettingsRowItem(
                    icon: PhosphorIcons.sun,
                    title: 'Light mode',
                    subtitle: 'Always use clean light theme',
                    trailing: _buildRadio(currentMode == ThemeMode.light, isDark),
                    onTap: () => service.setThemeMode(ThemeMode.light),
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

  Widget _buildRadio(bool isSelected, bool isDark) {
    final borderColor = isDark ? const Color(0xFF272E3F) : const Color(0xFFCBD5E1);
    final selectedBg = isDark ? Colors.white : const Color(0xFF0F172A);
    final innerDotColor = isDark ? const Color(0xFF0C0E14) : Colors.white;

    return Container(
      width: 22.0,
      height: 22.0,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? selectedBg : Colors.transparent,
        border: Border.all(
          color: isSelected ? selectedBg : borderColor,
          width: 1.5,
        ),
      ),
      child: isSelected
          ? Center(
              child: Container(
                width: 10.0,
                height: 10.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: innerDotColor,
                ),
              ),
            )
          : null,
    );
  }
}

