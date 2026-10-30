import 'package:dio/dio.dart';
import '../../../config/dio_client.dart';

/// Resolved metadata from an HTTP probe or URI analysis.
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
    if (totalBytes >= 1024 * 1024 * 1024) return '${(totalBytes / 1073741824).toStringAsFixed(2)} GB ($totalBytes bytes)';
    if (totalBytes >= 1024 * 1024) return '${(totalBytes / 1048576).toStringAsFixed(2)} MB ($totalBytes bytes)';
    return '${(totalBytes / 1024).toStringAsFixed(2)} KB ($totalBytes bytes)';
  }
}

/// Helper that inspects Content-Disposition, redirect hops, and query hints.
/// Complies with rules.md §13, §25.1, §25.2, and §29.2 (< 200 lines).
class UrlMetadataHelper {
  UrlMetadataHelper._();

  static Future<UrlMetadata> resolve(String rawUrl, {String? referer}) async {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return _fallback('download');
    if (trimmed.startsWith('magnet:?')) return _resolveMagnet(trimmed);

    try {
      final dio = DioClient.instance;
      final uri = Uri.tryParse(trimmed);
      final ref = (referer?.isNotEmpty == true) ? referer : (uri?.host.isNotEmpty == true ? '${uri!.scheme}://${uri.host}/' : null);

      final reqHeaders = <String, dynamic>{
        'Range': 'bytes=0-0',
        'User-Agent': 'Mozilla/5.0 (Android; Mobile; rv:144.0) Gecko/144.0 Firefox/144.0',
        'Accept': '*/*',
        if (ref != null) 'Referer': ref,
      };

      var response = await dio.get<dynamic>(
        trimmed,
        options: Options(headers: reqHeaders, followRedirects: true, maxRedirects: 8, responseType: ResponseType.stream, validateStatus: (s) => s != null && s < 500),
      );

      // Handle 429 Too Many Requests rate-limiting with Retry-After or backoff
      if (response.statusCode == 429) {
        final retrySec = int.tryParse(response.headers.value('retry-after') ?? '') ?? 3;
        await Future<void>.delayed(Duration(seconds: retrySec.clamp(1, 10)));
        response = await dio.get<dynamic>(
          trimmed,
          options: Options(headers: reqHeaders, followRedirects: true, maxRedirects: 8, responseType: ResponseType.stream, validateStatus: (s) => s != null && s < 500),
        );
      }

      // Immediately drain and release probe socket so connection budget isn't exhausted
      try {
        final body = response.data;
        if (body is ResponseBody) body.stream.listen(null).cancel();
      } catch (_) {}

      final headers = response.headers;
      final finalUrl = response.realUri.toString();

      String? name = _parseContentDisposition(headers.value('content-disposition')) ??
          _parseQueryParams(response.realUri) ??
          _parsePathSegment(response.realUri);

      final cleanName = _cleanFileName(name ?? 'download_${DateTime.now().millisecondsSinceEpoch}');
      final ext = _extractExtension(cleanName);

      var len = -1;
      final cr = headers.value('content-range');
      if (cr != null && cr.contains('/')) {
        len = int.tryParse(cr.substring(cr.lastIndexOf('/') + 1).trim()) ?? -1;
      }
      if (len <= 0) {
        final cl = int.tryParse(headers.value('content-length') ?? '') ?? -1;
        if (response.statusCode != 206 || cl > 1) len = cl;
      }

      // If size is still unknown, query final direct CDN URL via lightweight HEAD
      if (len <= 0) {
        try {
          final hRes = await dio.head<dynamic>(
            finalUrl,
            options: Options(
              headers: {'User-Agent': reqHeaders['User-Agent'], if (ref != null) 'Referer': ref},
              followRedirects: true, maxRedirects: 3, validateStatus: (s) => s != null && s < 400,
            ),
          );
          final hcr = hRes.headers.value('content-range');
          if (hcr != null && hcr.contains('/')) len = int.tryParse(hcr.substring(hcr.lastIndexOf('/') + 1).trim()) ?? -1;
          if (len <= 0) len = int.tryParse(hRes.headers.value('content-length') ?? '') ?? -1;
        } catch (_) {}
      }

      final acceptRanges = headers.value('accept-ranges');
      final resume = acceptRanges?.toLowerCase().contains('bytes') == true || headers.value('content-range') != null;

      return UrlMetadata(fileName: cleanName, fileExtension: ext, totalBytes: len, supportsResume: resume, finalUrl: finalUrl);
    } catch (_) {
      final uri = Uri.tryParse(trimmed);
      final raw = uri?.pathSegments.lastOrNull;
      final name = (raw?.isNotEmpty == true) ? _cleanFileName(Uri.decodeComponent(raw!)) : 'download_${DateTime.now().millisecondsSinceEpoch}';
      return UrlMetadata(fileName: name, fileExtension: _extractExtension(name), totalBytes: -1, supportsResume: true, finalUrl: trimmed);
    }
  }

  static String? _parseContentDisposition(String? header) {
    if (header == null || header.isEmpty) return null;
    final utf8 = RegExp(r"filename\*\s*=\s*(?:UTF-8''|utf-8'')([^;]+)", caseSensitive: false).firstMatch(header);
    if (utf8 != null) {
      final raw = utf8.group(1)?.trim() ?? '';
      try { return Uri.decodeComponent(raw.replaceAll('"', '')); } catch (_) { return raw.replaceAll('"', ''); }
    }
    final std = RegExp(r'filename\s*=\s*"([^"]+)"|filename\s*=\s*([^; ]+)', caseSensitive: false).firstMatch(header);
    if (std != null) {
      final raw = std.group(1) ?? std.group(2) ?? '';
      try { return Uri.decodeComponent(raw.replaceAll('"', '').trim()); } catch (_) { return raw.replaceAll('"', '').trim(); }
    }
    return null;
  }

  static String? _parseQueryParams(Uri uri) {
    final q = uri.queryParameters;
    final cand = q['filename'] ?? q['file'] ?? q['name'] ?? q['title'] ?? q['dn'];
    return (cand?.isNotEmpty == true) ? Uri.decodeComponent(cand!.replaceAll('+', ' ')) : null;
  }

  static String? _parsePathSegment(Uri uri) {
    final seg = uri.pathSegments.lastOrNull;
    if (seg?.isNotEmpty == true) {
      final dec = Uri.decodeComponent(seg!);
      if (dec.contains('.')) return dec;
    }
    return null;
  }

  static String _extractExtension(String name) {
    final dot = name.lastIndexOf('.');
    if (dot != -1 && dot < name.length - 1) {
      final ext = name.substring(dot + 1).toLowerCase();
      if (ext.length <= 6 && RegExp(r'^[a-z0-9]+$').hasMatch(ext)) return ext;
    }
    return 'bin';
  }

  static String _cleanFileName(String name) {
    var c = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return c.isEmpty ? 'download_${DateTime.now().millisecondsSinceEpoch}' : c;
  }

  static UrlMetadata _resolveMagnet(String magnetUri) {
    final uri = Uri.tryParse(magnetUri);
    final raw = uri?.queryParameters['dn'];
    final dn = (raw?.isNotEmpty == true) ? _cleanFileName(Uri.decodeComponent(raw!.replaceAll('+', ' '))) : 'Torrent_${DateTime.now().millisecondsSinceEpoch}';
    return UrlMetadata(fileName: dn, fileExtension: _extractExtension(dn), totalBytes: -1, supportsResume: true, finalUrl: magnetUri);
  }

  static UrlMetadata _fallback(String def) => UrlMetadata(fileName: def, fileExtension: 'bin', totalBytes: -1, supportsResume: true, finalUrl: '');
}
