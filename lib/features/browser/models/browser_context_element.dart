/// Media type of a long-pressed element inside GeckoView.
enum BrowserContextMediaType {
  none,
  image,
  video,
  audio;

  static BrowserContextMediaType fromRaw(String? raw) {
    return switch (raw?.toLowerCase()) {
      'image' => BrowserContextMediaType.image,
      'video' => BrowserContextMediaType.video,
      'audio' => BrowserContextMediaType.audio,
      _ => BrowserContextMediaType.none,
    };
  }
}

/// Payload delivered from GeckoView ContentDelegate.onContextMenu.
class BrowserContextElement {
  final String baseUri;
  final String linkUri;
  final String srcUri;
  final String title;
  final String altText;
  final String textContent;
  final BrowserContextMediaType mediaType;

  const BrowserContextElement({
    this.baseUri = '',
    this.linkUri = '',
    this.srcUri = '',
    this.title = '',
    this.altText = '',
    this.textContent = '',
    this.mediaType = BrowserContextMediaType.none,
  });

  factory BrowserContextElement.fromMap(Map<dynamic, dynamic> map) {
    return BrowserContextElement(
      baseUri: map['baseUri'] as String? ?? '',
      linkUri: map['linkUri'] as String? ?? '',
      srcUri: map['srcUri'] as String? ?? '',
      title: map['title'] as String? ?? '',
      altText: map['altText'] as String? ?? '',
      textContent: map['textContent'] as String? ?? '',
      mediaType: BrowserContextMediaType.fromRaw(map['type'] as String?),
    );
  }

  bool get hasLink => linkUri.isNotEmpty;
  bool get hasMedia => srcUri.isNotEmpty && mediaType != BrowserContextMediaType.none;
  bool get isImage => mediaType == BrowserContextMediaType.image && srcUri.isNotEmpty;
  String get primaryUrl => hasLink ? linkUri : srcUri;

  String get displayTitle {
    final candidates = [title.trim(), textContent.trim(), altText.trim()];
    for (final c in candidates) {
      if (c.isNotEmpty) return c;
    }
    final uri = Uri.tryParse(primaryUrl);
    if (uri != null && uri.host.isNotEmpty) return uri.host;
    return primaryUrl;
  }
}
