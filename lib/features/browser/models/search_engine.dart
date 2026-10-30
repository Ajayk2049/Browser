/// Supported search engines for omnibox querying.
/// Complies with rules.md §13, §29.1, and §29.2 (< 200 lines).
enum SearchEngine {
  duckDuckGo,
  google;

  String get displayName {
    switch (this) {
      case SearchEngine.duckDuckGo:
        return 'DuckDuckGo';
      case SearchEngine.google:
        return 'Google';
    }
  }

  String get homeUrl {
    switch (this) {
      case SearchEngine.duckDuckGo:
        return 'https://duckduckgo.com';
      case SearchEngine.google:
        return 'https://www.google.com';
    }
  }

  String buildSearchUrl(String query) {
    final encoded = Uri.encodeComponent(query.trim());
    switch (this) {
      case SearchEngine.duckDuckGo:
        return 'https://duckduckgo.com/?q=$encoded';
      case SearchEngine.google:
        return 'https://www.google.com/search?q=$encoded';
    }
  }
}
