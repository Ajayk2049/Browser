/// Supported search engines for omnibox querying.
/// Complies with rules.md §13, §29.1, and §29.2 (< 200 lines).
enum SearchEngine {
  duckDuckGo,
  google,
  bing,
  brave,
  startpage,
  custom;

  String get displayName {
    switch (this) {
      case SearchEngine.duckDuckGo:
        return 'DuckDuckGo';
      case SearchEngine.google:
        return 'Google';
      case SearchEngine.bing:
        return 'Bing';
      case SearchEngine.brave:
        return 'Brave Search';
      case SearchEngine.startpage:
        return 'Startpage';
      case SearchEngine.custom:
        return 'Custom';
    }
  }

  String get homeUrl {
    switch (this) {
      case SearchEngine.duckDuckGo:
        return 'https://duckduckgo.com';
      case SearchEngine.google:
        return 'https://www.google.com';
      case SearchEngine.bing:
        return 'https://www.bing.com';
      case SearchEngine.brave:
        return 'https://search.brave.com';
      case SearchEngine.startpage:
        return 'https://www.startpage.com';
      case SearchEngine.custom:
        return 'https://duckduckgo.com';
    }
  }

  String buildSearchUrl(String query, {String? customQueryUrl}) {
    final encoded = Uri.encodeComponent(query.trim());
    switch (this) {
      case SearchEngine.duckDuckGo:
        return 'https://duckduckgo.com/?q=$encoded';
      case SearchEngine.google:
        return 'https://www.google.com/search?q=$encoded';
      case SearchEngine.bing:
        return 'https://www.bing.com/search?q=$encoded';
      case SearchEngine.brave:
        return 'https://search.brave.com/search?q=$encoded';
      case SearchEngine.startpage:
        return 'https://www.startpage.com/sp/search?query=$encoded';
      case SearchEngine.custom:
        if (customQueryUrl != null && customQueryUrl.isNotEmpty) {
          if (customQueryUrl.contains('%s')) {
            return customQueryUrl.replaceAll('%s', encoded);
          }
          return '$customQueryUrl$encoded';
        }
        return 'https://duckduckgo.com/?q=$encoded';
    }
  }
}
