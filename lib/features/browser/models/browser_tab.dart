import '../widgets/gecko_browser_view.dart';

/// Immutable snapshot of one open tab, as rendered by the tabs sheet.
/// Complies with rules.md §13, §29.1, and §29.2 (< 200 lines).
class BrowserTabInfo {
  final String id;
  final String title;
  final String url;
  final bool isActive;

  const BrowserTabInfo({
    required this.id,
    required this.title,
    required this.url,
    required this.isActive,
  });

  /// Page title, falling back to the host so a tab is never a blank row.
  String get displayTitle {
    final trimmed = title.trim();
    if (trimmed.isNotEmpty) return trimmed;

    if (url == 'dab.app/home' || url.isEmpty) return 'Explore & Discover';

    final host = Uri.tryParse(url)?.host ?? '';
    if (host.isNotEmpty) return host;

    return 'New tab';
  }

  String get displayUrl => (url.isEmpty || url == 'dab.app/home') ? 'dab.app/home' : url;
}

/// Live mutable tab state maintained by the browser screen.
class BrowserTabSession {
  BrowserTabSession({
    required this.id,
    required this.controller,
    required this.url,
  });

  final String id;
  final GeckoBrowserController controller;
  String url;
  String title = '';
  bool isLoading = false;
  double progress = 0.0;
  String? error;
  bool canGoBack = false;

  bool get isHome => url == 'dab.app/home' || url.isEmpty;

  BrowserTabInfo info({required bool isActive}) => BrowserTabInfo(
        id: id,
        title: isHome ? 'Explore & Discover' : title,
        url: url,
        isActive: isActive,
      );
}
