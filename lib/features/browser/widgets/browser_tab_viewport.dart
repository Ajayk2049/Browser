import 'package:flutter/material.dart';
import '../models/browser_page_error.dart';
import '../models/browser_tab.dart';
import '../services/history_service.dart';
import '../utils/url_helper.dart';
import 'gecko_browser_view.dart';

export 'gecko_browser_view.dart';

/// Renders a single active or background GeckoView browser tab session.
/// Complies with rules.md §13, §25.1, §25.2, §25.7, and §29.2 (< 250 lines).
class BrowserTabViewport extends StatelessWidget {
  final BrowserTabSession tab;
  final bool isActive;
  final ValueChanged<String> onUrlChanged;
  final ValueChanged<String> onDownloadPrompt;
  final void Function(String url, String title, String type)? onMediaDetected;
  final void Function(int current, int total)? onFinderResult;
  final VoidCallback onSync;

  const BrowserTabViewport({
    super.key,
    required this.tab,
    required this.isActive,
    required this.onUrlChanged,
    required this.onDownloadPrompt,
    this.onMediaDetected,
    this.onFinderResult,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: ValueKey(tab.id),
      child: GeckoBrowserView(
        initialUrl: tab.url,
        controller: tab.controller,
        isPrivate: tab.isPrivate,
        onPageStarted: (url) {
          tab..url = url..isLoading = true..error = null..pageError = null;
          if (isActive) onUrlChanged(url);
        },
        onPageFinished: (ok) {
          tab.isLoading = false;
          if (ok && tab.url.isNotEmpty && !tab.isHome && !tab.isPrivate) {
            HistoryService.instance.recordVisit(url: tab.url, title: tab.title);
          }
          if (isActive) onSync();
        },
        onProgressChanged: (p) {
          final newProgress = p / 100.0;
          final shouldSync = (newProgress - tab.progress).abs() >= 0.1 || newProgress >= 1.0;
          tab.progress = newProgress;
          if (isActive && shouldSync) onSync();
        },
        onTitleChanged: (title) {
          if (title.isNotEmpty) {
            tab.title = title;
            if (isActive) onSync();
          }
        },
        onLocationChanged: (url) {
          if (url.isEmpty) return;
          tab.url = url;
          if (isActive) {
            onUrlChanged(url);
            if (UrlHelper.isDownloadable(url)) onDownloadPrompt(url);
          }
        },
        onDownloadPrompt: (url) {
          if (isActive) onDownloadPrompt(url);
        },
        onMediaDetected: (url, title, type) {
          if (isActive) onMediaDetected?.call(url, title, type);
        },
        onFinderResult: (cur, tot) {
          if (isActive) onFinderResult?.call(cur, tot);
        },
        onCanGoBack: (can) {
          tab.canGoBack = can;
          if (isActive) onSync();
        },
        onCanGoForward: (can) {
          tab.canGoForward = can;
          if (isActive) onSync();
        },
        onWebResourceError: (uri, code, errorKey, categoryName) {
          tab
            ..pageError = BrowserPageError(
              uri: uri.isNotEmpty ? uri : tab.url,
              errorKey: errorKey,
              categoryName: categoryName,
              code: code,
            )
            ..error = null
            ..isLoading = false;
          if (isActive) onSync();
        },
      ),
    );
  }
}
