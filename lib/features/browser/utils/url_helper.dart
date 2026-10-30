import '../models/search_engine.dart';

/// URL and Search Query classification utility.
/// Complies with rules.md §13, §29.1, and §29.2 (< 200 lines).
class UrlHelper {
  UrlHelper._();

  static final RegExp _hasWhitespace = RegExp(r'\s');
  static final RegExp _domainRegex = RegExp(
    r'^(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(?::\d+)?(?:/.*)?$',
  );
  static final RegExp _ipRegex = RegExp(
    r'^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(?::\d+)?(?:/.*)?$',
  );
  static final RegExp _localhostRegex = RegExp(
    r'^localhost(?::\d+)?(?:/.*)?$',
    caseSensitive: false,
  );

  /// Resolves raw text from the address bar into either a valid URL or a search engine query.
  /// Guarantees that search terms never trigger browser host-resolution fallback failures.
  static String resolveInput(String rawInput, SearchEngine engine) {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) return engine.homeUrl;

    final lower = trimmed.toLowerCase();

    // 1. Explicit schemes are always direct URLs
    if (lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('magnet:?') ||
        lower.startsWith('file://') ||
        lower.startsWith('about:') ||
        lower.startsWith('chrome://') ||
        lower.startsWith('view-source:')) {
      return trimmed;
    }

    // 2. Multi-word phrases with whitespace are always search queries
    if (_hasWhitespace.hasMatch(trimmed)) {
      return engine.buildSearchUrl(trimmed);
    }

    // 3. Check for localhost
    if (_localhostRegex.hasMatch(trimmed)) {
      return 'http://$trimmed';
    }

    // 4. Check for IP address
    if (_ipRegex.hasMatch(trimmed)) {
      return 'http://$trimmed';
    }

    // 5. Check for valid domain name with TLD (e.g., github.com, flutter.dev, news.ycombinator.com/item)
    if (_domainRegex.hasMatch(trimmed)) {
      return 'https://$trimmed';
    }

    // 6. Otherwise (e.g., 'flutter', 'weather', 'cats', 'pizza'), treat as search query
    return engine.buildSearchUrl(trimmed);
  }

  /// Checks if the URL represents a downloadable binary or torrent resource.
  static bool isDownloadable(String urlStr) {
    final trimmed = urlStr.trim();
    if (trimmed.startsWith('magnet:?')) return true;
    final uri = Uri.tryParse(trimmed);
    final lastSegment = uri?.pathSegments.lastOrNull?.toLowerCase();
    if (lastSegment == null || lastSegment.isEmpty) return false;
    const downloadExtensions = [
      '.apk', '.zip', '.rar', '.7z', '.tar', '.gz', '.bin', '.iso',
      '.mp4', '.mkv', '.avi', '.mp3', '.pdf', '.dmg', '.exe', '.torrent'
    ];
    return downloadExtensions.any((ext) => lastSegment.endsWith(ext));
  }
}
