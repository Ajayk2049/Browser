/// Immutable snapshot of one open tab, as rendered by the tabs sheet.
/// The live, mutable tab state lives in the browser screen; this is the
/// presentation-only view of it.
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

    final host = Uri.tryParse(url)?.host ?? '';
    if (host.isNotEmpty) return host;

    return 'New tab';
  }

  String get displayUrl => url.isEmpty ? 'Blank page' : url;
}
