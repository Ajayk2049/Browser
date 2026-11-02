/// Resolved metadata from an HTTP probe or URI analysis.
/// Complies with rules.md §13, §29.1, §29.2 (< 200 lines).
class UrlMetadata {
  final String fileName;
  final String fileExtension;
  final int totalBytes;
  final bool supportsResume;
  final String finalUrl;

  const UrlMetadata({
    required this.fileName,
    required this.fileExtension,
    required this.totalBytes,
    required this.supportsResume,
    required this.finalUrl,
  });

  String get formattedSize {
    if (totalBytes <= 0) return 'Unknown size';
    if (totalBytes >= (1 << 30)) return '${(totalBytes / (1 << 30)).toStringAsFixed(2)} GB ($totalBytes bytes)';
    if (totalBytes >= (1 << 20)) return '${(totalBytes / (1 << 20)).toStringAsFixed(2)} MB ($totalBytes bytes)';
    if (totalBytes >= (1 << 10)) return '${(totalBytes / (1 << 10)).toStringAsFixed(2)} KB ($totalBytes bytes)';
    return '$totalBytes bytes';
  }
}

