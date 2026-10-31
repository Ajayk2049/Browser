import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../../../theme/tokens/app_typography.dart';

/// Settings hub — structure only.
///
/// Rows are placeholders describing the settings this browser will expose.
/// No control is wired yet; tapping a row reports that the control is pending.
/// Complies with rules.md §13, §25.1, §25.2, §25.7, and §29.2 (< 300 lines).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: AppTypography.displaySm.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x4,
          AppSpacing.x2,
          AppSpacing.x4,
          AppSpacing.x8,
        ),
        children: [
          Text(
            'Placeholder entries. Each control will be wired in a later step.',
            style: AppTypography.bodyXs.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          for (var i = 0; i < _sections.length; i++) ...[
            SizedBox(height: i == 0 ? AppSpacing.x4 : AppSpacing.x6),
            _SectionHeader(title: _sections[i].title, colorScheme: colorScheme),
            const SizedBox(height: AppSpacing.x2),
            _SectionCard(
              entries: _sections[i].entries,
              colorScheme: colorScheme,
              onTap: (entry) => _reportPending(context, entry.title),
            ),
          ],
        ],
      ),
    );
  }

  void _reportPending(BuildContext context, String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$label settings are not wired up yet'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

/// One tappable line inside a settings card.
class _SettingEntry {
  final IconData icon;
  final String title;
  final String description;

  const _SettingEntry(this.icon, this.title, this.description);
}

/// A titled group of [_SettingEntry] rows.
class _SettingsSection {
  final String title;
  final List<_SettingEntry> entries;

  const _SettingsSection(this.title, this.entries);
}

const List<_SettingsSection> _sections = [
  _SettingsSection('Browsing', [
    _SettingEntry(
      PhosphorIcons.house,
      'Homepage',
      'Choose the page that opens on every new tab',
    ),
    _SettingEntry(
      PhosphorIcons.magnifyingGlass,
      'Default search engine',
      'Pick the engine that powers the omnibox',
    ),
    _SettingEntry(
      PhosphorIcons.translate,
      'Language',
      'Interface language and preferred content language',
    ),
  ]),
  _SettingsSection('Appearance', [
    _SettingEntry(
      PhosphorIcons.palette,
      'Theme',
      'Follow system, light, or dark',
    ),
    _SettingEntry(
      PhosphorIcons.textAa,
      'Text size',
      'Scale page text for easier reading',
    ),
  ]),
  _SettingsSection('Privacy & data', [
    _SettingEntry(
      PhosphorIcons.shieldCheck,
      'Privacy & security',
      'Tracking protection, cookies, and site permissions',
    ),
    _SettingEntry(
      PhosphorIcons.broom,
      'Clear browsing data',
      'Erase history, cache, and cookies',
    ),
  ]),
  _SettingsSection('Downloads', [
    _SettingEntry(
      PhosphorIcons.downloadSimple,
      'Downloads',
      'Save location, concurrent connections, and speed limits',
    ),
  ]),
  _SettingsSection('About', [
    _SettingEntry(
      PhosphorIcons.info,
      'About Dab Browser',
      'Version, engine, and open-source licenses',
    ),
  ]),
];

class _SectionHeader extends StatelessWidget {
  final String title;
  final ColorScheme colorScheme;

  const _SectionHeader({required this.title, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.x1),
      child: Text(
        title.toUpperCase(),
        style: AppTypography.bodyXs.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final List<_SettingEntry> entries;
  final ColorScheme colorScheme;
  final ValueChanged<_SettingEntry> onTap;

  const _SectionCard({
    required this.entries,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(AppRadius.m3Lg),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: AppSpacing.x12,
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            _EntryRow(
              entry: entries[i],
              colorScheme: colorScheme,
              onTap: () => onTap(entries[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  final _SettingEntry entry;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _EntryRow({
    required this.entry,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x3,
          vertical: AppSpacing.x3,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.m3Sm),
              ),
              child: Icon(entry.icon, size: 20, color: colorScheme.onSurface),
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: AppTypography.bodyMd.copyWith(
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.description,
                    style: AppTypography.bodyXs.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.x2),
            Icon(
              PhosphorIcons.caretRight,
              size: 14,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}
