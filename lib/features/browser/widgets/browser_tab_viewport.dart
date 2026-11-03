import 'package:flutter/material.dart';
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
  final VoidCallback onSync;

  const BrowserTabViewport({
    super.key,
    required this.tab,
    required this.isActive,
    required this.onUrlChanged,
    required this.onDownloadPrompt,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: ValueKey(tab.id),
      child: GeckoBrowserView(
        initialUrl: tab.url,
        controller: tab.controller,
        onPageStarted: (url) {
          tab..url = url..isLoading = true..error = null;
          if (isActive) onUrlChanged(url);
        },
        onPageFinished: (ok) {
          tab.isLoading = false;
          if (ok && tab.url.isNotEmpty && !tab.isHome) {
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
        onCanGoBack: (can) {
          tab.canGoBack = can;
          if (isActive) onSync();
        },
        onCanGoForward: (can) {
          tab.canGoForward = can;
          if (isActive) onSync();
        },
        onWebResourceError: (uri, code, cat) {
          tab..error = 'Could not reach this page ($cat error $code)'..isLoading = false;
          if (isActive) onSync();
        },
      ),
    );
  }
}

