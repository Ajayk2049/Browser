import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../downloads/widgets/add_download_dialog.dart';
import '../models/browser_tab.dart';
import '../models/home_content_item.dart';
import '../services/bookmarks_service.dart';
import '../services/quick_links_service.dart';
import 'add_quick_link_dialog.dart';
import 'browser_tabs_sheet.dart';
import 'media_grabber_sheet.dart';

export 'media_grabber_sheet.dart' show DetectedMedia;

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

  static Future<void> openMediaGrabber(BuildContext context, List<DetectedMedia> items) {
    return showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.modal))),
      builder: (_) => MediaGrabberSheet(items: items),
    );
  }

  static Future<void> promptDownload(BuildContext context, String url) async {
    if (url.isNotEmpty && context.mounted) {
      await AddDownloadDialog.show(context, initialUrl: url);
    }
  }

  static Future<void> toggleBookmark(BuildContext context, BrowserTabSession tab) async {
    if (tab.isHome || tab.url.isEmpty) return;
    final title = tab.title.isNotEmpty ? tab.title : tab.url;
    final wasAdded = await BookmarksService.instance.toggleBookmark(url: tab.url, title: title);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(
      content: Text(wasAdded ? 'Page added to bookmarks' : 'Bookmark removed'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  static void sharePage(String url, String title) {
    if (url.isNotEmpty) {
      const MethodChannel('com.dab/downloader').invokeMethod('shareUrl', {'url': url, 'title': title});
    }
  }

  static Future<void> openTabsSheet(
    BuildContext context, {
    required List<BrowserTabInfo> tabs,
    required ValueChanged<String> onSelect,
    required ValueChanged<String> onClose,
    required VoidCallback onNewTab,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => BrowserTabsSheet(
          tabs: tabs,
          onSelect: (id) { onSelect(id); Navigator.of(sCtx).pop(); },
          onClose: (id) { onClose(id); setSheetState(() {}); },
          onNewTab: () { onNewTab(); Navigator.of(sCtx).pop(); },
        ),
      ),
    );
  }
}

