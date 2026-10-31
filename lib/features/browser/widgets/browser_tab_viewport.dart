import 'package:flutter/material.dart';
import '../models/browser_tab.dart';
import '../utils/url_helper.dart';
import 'gecko_browser_view.dart';

export 'gecko_browser_view.dart';

/// Renders a single active or background GeckoView browser tab session.
/// Complies with rules.md §13, §25.1, §25.2, §25.7, and §29.2 (< 250 lines).
class BrowserTabViewport extends StatelessWidget {
  final BrowserTabSession tab;
  final bool isActive;
  final ValueChanged<String> onUrlChanged;
  final ValueChanged<Uri> onDownloadPrompt;
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
          if (isActive) onSync();
        },
        onProgressChanged: (p) {
          tab.progress = p / 100.0;
          if (isActive) onSync();
        },
        onLocationChanged: (url) {
          if (url.isEmpty) return;
          tab.url = url;
          if (isActive) {
            onUrlChanged(url);
            final uri = Uri.tryParse(url);
            if (uri != null && UrlHelper.isDownloadable(url)) {
              onDownloadPrompt(uri);
            }
          }
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

