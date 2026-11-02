import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../models/web_extension_item.dart';
import '../services/web_extension_service.dart';
import '../widgets/extension_row_tile.dart';
import '../widgets/settings_app_bar.dart';

/// Screen displaying user extensions and curated AMO marketplace.
/// Strictly governed by rules.md §13, §29.2 (< 300 lines).
class ExtensionsScreen extends StatefulWidget {
  const ExtensionsScreen({super.key});

  @override
  State<ExtensionsScreen> createState() => _ExtensionsScreenState();
}

class _ExtensionsScreenState extends State<ExtensionsScreen> {
  @override
  void initState() {
    super.initState();
    WebExtensionService.instance.init();
  }

  Future<void> _handleInstall(WebExtensionItem ext) async {
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
      SnackBar(content: Text('Downloading "${ext.name}"...'), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)),
    );
    final ok = await WebExtensionService.instance.install(ext.downloadUrl);
    if (!mounted) return;
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
      SnackBar(content: Text(ok ? 'Installed "${ext.name}"' : 'Failed to install "${ext.name}"'), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _handleUninstall(WebExtensionItem ext) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${ext.name}?'),
        content: Text('Are you sure you want to uninstall ${ext.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await WebExtensionService.instance.uninstall(ext.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
        SnackBar(content: Text('Removed "${ext.name}"'), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF0C0E14) : const Color(0xFFF8FAFC);
    const headerColor = Color(0xFF64748B);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: SettingsAppBar(
        title: 'Extensions',
        showSearch: false,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: ListenableBuilder(
        listenable: WebExtensionService.instance,
        builder: (context, _) {
          final installed = WebExtensionService.instance.installed;
          final marketplace = WebExtensionService.curatedMarketplace;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 48.0),
            children: [
              _buildSectionHeader('INSTALLED EXTENSIONS', 'Manage (${installed.length})', headerColor, isDark),
              const SizedBox(height: 8.0),
              _buildCardContainer(
                isDark,
                children: [
                  if (installed.isEmpty)
                    _buildEmptyNotice('No extensions installed yet', isDark)
                  else
                    for (int i = 0; i < installed.length; i++) ...[
                      if (i > 0) _buildDivider(isDark),
                      ExtensionRowTile(
                        item: installed[i],
                        onToggle: (val) => WebExtensionService.instance.toggleEnabled(installed[i]),
                        onUninstall: () => _handleUninstall(installed[i]),
                      ),
                    ],
                ],
              ),
              const SizedBox(height: 24.0),
              _buildSectionHeader('MORE EXTENSIONS', '', headerColor, isDark),
              const SizedBox(height: 8.0),
              _buildCardContainer(
                isDark,
                children: [
                  for (int i = 0; i < marketplace.length; i++) ...[
                    if (i > 0) _buildDivider(isDark),
                    ExtensionRowTile(
                      item: marketplace[i],
                      isMarketplace: true,
                      onInstall: () => _handleInstall(marketplace[i]),
                    ),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, String action, Color headerColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontFamily: 'Inter', fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: headerColor)),
          Text(action, style: TextStyle(fontFamily: 'Inter', fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildCardContainer(bool isDark, {required List<Widget> children}) {
    final cardBg = isDark ? const Color(0xFF131722) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF1E293B) : const Color(0xFFEDF0F5);
    return Container(
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16.0), border: Border.all(color: cardBorder)),
      child: Column(children: children),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(height: 1, thickness: 1, color: isDark ? const Color(0xFF1A2232) : const Color(0xFFF1F5F9));
  }

  Widget _buildEmptyNotice(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Center(
        child: Text(text, style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, fontWeight: FontWeight.w500, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
      ),
    );
  }
}

