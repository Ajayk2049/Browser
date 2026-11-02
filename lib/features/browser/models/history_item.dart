/// Represents a single visited page entry in browser history.
/// Complies with rules.md §13, §29.2 (< 200 lines).
class HistoryItem {
  final String id;
  final String title;
  final String url;
  final DateTime timestamp;

  const HistoryItem({
    required this.id,
    required this.title,
    required this.url,
    required this.timestamp,
  });

  String get host {
    try {
      final uri = Uri.parse(url);
      return uri.host.isNotEmpty ? uri.host : url;
    } catch (_) {
      return url;
    }
  }

  String get letter {
    final clean = (title.isNotEmpty ? title : host).trim();
    return clean.isNotEmpty ? clean[0].toUpperCase() : 'H';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        'timestamp': timestamp.toIso8601String(),
      };

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['id'] as String? ?? 'hist-${DateTime.now().millisecondsSinceEpoch}',
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

