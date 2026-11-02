import 'package:flutter/material.dart';
import '../models/home_content_item.dart';
import '../services/quick_links_service.dart';
import 'add_quick_link_dialog.dart';

/// Helper handling shortcuts management on home screen.
/// Adheres to rules.md §13, §29.2 (< 200 lines).
class BrowserShortcutHelper {
  static Future<void> openAddQuickLink(BuildContext context) async {
    final item = await AddQuickLinkDialog.show(context);
    if (item != null && context.mounted) {
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(
        content: Text('Added "${item.title}" to shortcuts'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
    }
  }

  static Future<void> confirmRemoveQuickLink(BuildContext context, QuickLink item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove shortcut?'),
        content: Text('Remove "${item.title}" from shortcuts?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok == true) await QuickLinksService.instance.removeQuickLink(item.id);
  }
}

