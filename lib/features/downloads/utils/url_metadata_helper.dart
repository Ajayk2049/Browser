import 'dart:async';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import '../../../config/dio_client.dart';
import '../../../config/env.dart';
import '../models/url_metadata.dart';
import '../services/download_service.dart';

export '../models/url_metadata.dart';

/// Helper that inspects Content-Disposition, redirect hops, and query hints.
/// Complies with rules.md §13, §25.1, §25.2, and §29.2 (< 200 lines).
class UrlMetadataHelper {
  UrlMetadataHelper._();

  static Future<UrlMetadata> resolve(String rawUrl, {String? referer}) async {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return _fallback('download');
    if (trimmed.toLowerCase().startsWith('magnet:')) return _resolveMagnet(trimmed);

    final uri = Uri.tryParse(trimmed);
    final ref = (referer?.isNotEmpty == true) ? referer : (uri?.host.isNotEmpty == true ? '${uri!.scheme}://${uri.host}/' : null);

    try {
      final nativeRes = await DownloadService().probeUrl(trimmed, referer: ref);
      if (nativeRes != null) {
        final fUrl = (nativeRes['finalUrl'] as String?)?.isNotEmpty == true ? nativeRes['finalUrl'] as String : trimmed;
        final cLen = (nativeRes['contentLength'] as num?)?.toInt() ?? -1;
        final sName = nativeRes['suggestedFileName'] as String?;
        final supRanges = nativeRes['supportsRanges'] as bool? ?? false;
        final fUri = Uri.tryParse(fUrl) ?? uri;
        final rawName = sName ?? (fUri != null ? (_parseQueryParams(fUri) ?? _parsePathSegment(fUri)) : null);
        final cleanName = _cleanFileName(rawName ?? 'download_${DateTime.now().millisecondsSinceEpoch}');
        if (Env.enableLogging) developer.log('NATIVE PROBE: url=$fUrl len=$cLen ranges=$supRanges name=$cleanName', name: 'Probe');
        if (cLen > 0) return UrlMetadata(fileName: cleanName, fileExtension: _extractExtension(cleanName), totalBytes: cLen, supportsResume: supRanges, finalUrl: fUrl);
      }
    } catch (e) {
      if (Env.enableLogging) developer.log('Native probe fallback: $e', name: 'Probe');
    }

    try {
      final dio = DioClient.instance;
      final opt = Options(
        headers: <String, dynamic>{'Range': 'bytes=0-0', 'User-Agent': 'Mozilla/5.0 (Android; Mobile; rv:144.0) Gecko/144.0 Firefox/144.0', 'Accept': '*/*', 'Referer': ?ref},
        followRedirects: true, maxRedirects: 8, responseType: ResponseType.stream, validateStatus: (s) => s != null && s < 500,
      );

      var response = await dio.get<dynamic>(trimmed, options: opt);
      if (response.statusCode == 429) {
        final retrySec = int.tryParse(response.headers.value('retry-after') ?? '') ?? 3;
        await Future<void>.delayed(Duration(seconds: retrySec.clamp(1, 10)));
        response = await dio.get<dynamic>(trimmed, options: opt);
      }
      try { final b = response.data; if (b is ResponseBody) unawaited(b.stream.listen(null).cancel()); } catch (_) {}

      final headers = response.headers, finalUrl = response.realUri.toString(), code = response.statusCode ?? 0;
      final cr = headers.value('content-range'), clRaw = int.tryParse(headers.value('content-length') ?? '') ?? -1;
      int len = -1;
      if (cr != null && cr.contains('/')) len = int.tryParse(cr.substring(cr.lastIndexOf('/') + 1).trim()) ?? -1;
      if (len <= 0 && (clRaw > 1 || code == 200)) len = clRaw;
      if (code != 200 && code != 206 && code != 416) len = -1;

      if (len <= 0 && (code == 200 || code == 206 || code == 416)) {
        try {
          final head = await dio.head<dynamic>(finalUrl, options: opt);
          final hl = int.tryParse(head.headers.value('content-length') ?? '') ?? -1;
          if (hl > 0) len = hl;
        } catch (_) {}
      }

      final String? name = _parseContentDisposition(headers.value('content-disposition')) ?? _parseQueryParams(response.realUri) ?? _parsePathSegment(response.realUri);
      final cleanName = _cleanFileName(name ?? 'download_${DateTime.now().millisecondsSinceEpoch}');
      final resume = headers.value('accept-ranges')?.toLowerCase().contains('bytes') == true || cr != null;
      return UrlMetadata(fileName: cleanName, fileExtension: _extractExtension(cleanName), totalBytes: len, supportsResume: resume, finalUrl: finalUrl);
    } catch (e) {
      if (Env.enableLogging) developer.log('Probe exception: $e', name: 'Probe');
      final raw = uri?.pathSegments.lastOrNull;
      final name = (raw?.isNotEmpty == true) ? _cleanFileName(Uri.decodeComponent(raw!)) : 'download_${DateTime.now().millisecondsSinceEpoch}';
      return UrlMetadata(fileName: name, fileExtension: _extractExtension(name), totalBytes: -1, supportsResume: true, finalUrl: trimmed);
    }
  }

  static String? _parseContentDisposition(String? header) {
    if (header == null || header.isEmpty) return null;
    final utf8 = RegExp(r"filename\*\s*=\s*(?:UTF-8''|utf-8'')([^;]+)", caseSensitive: false).firstMatch(header);
    if (utf8 != null) return _decodeDisp(utf8.group(1));
    final std = RegExp(r'filename\s*=\s*"([^"]+)"|filename\s*=\s*([^; ]+)', caseSensitive: false).firstMatch(header);
    return std != null ? _decodeDisp(std.group(1) ?? std.group(2)) : null;
  }

  static String _decodeDisp(String? raw) {
    final s = (raw ?? '').trim().replaceAll('"', '');
    try { return Uri.decodeComponent(s); } catch (_) { return s; }
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

  static String extractExtension(String name) => _extractExtension(name);

  static String extractCandidateName(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return 'download_${DateTime.now().millisecondsSinceEpoch}.bin';
    if (trimmed.toLowerCase().startsWith('magnet:')) {
      final m = RegExp(r'[?&]dn=([^&]+)', caseSensitive: false).firstMatch(trimmed);
      if (m != null) {
        try { return _cleanFileName(Uri.decodeQueryComponent(m.group(1)!)); } catch (_) { return _cleanFileName(m.group(1)!); }
      }
      return 'Torrent_${DateTime.now().millisecondsSinceEpoch}';
    }
    final uri = Uri.tryParse(trimmed);
    if (uri != null) {
      final cand = _parseQueryParams(uri) ?? _parsePathSegment(uri);
      if (cand != null && cand.isNotEmpty) return _cleanFileName(cand);
      final lastSeg = uri.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => '');
      if (lastSeg.isNotEmpty) return _cleanFileName(Uri.decodeComponent(lastSeg));
    }
    return 'download_${DateTime.now().millisecondsSinceEpoch}.bin';
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
    final c = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return c.isEmpty ? 'download_${DateTime.now().millisecondsSinceEpoch}' : c;
  }

  static UrlMetadata _resolveMagnet(String magnetUri) {
    final dn = extractCandidateName(magnetUri);
    final ext = dn.contains('.') ? _extractExtension(dn) : 'torrent';
    final size = extractTorrentSize(magnetUri, dn);
    return UrlMetadata(fileName: dn, fileExtension: ext, totalBytes: size, supportsResume: true, finalUrl: magnetUri);
  }

  static int extractTorrentSize(String magnetUri, String name) {
    final xlMatch = RegExp(r'[?&]xl=([0-9]+)', caseSensitive: false).firstMatch(magnetUri);
    if (xlMatch != null) {
      final xl = int.tryParse(xlMatch.group(1)!);
      if (xl != null && xl > 0) return xl;
    }
    final sizeMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(GB|MB|GiB|MiB)\b', caseSensitive: false).firstMatch(name);
    if (sizeMatch != null) {
      final numVal = double.tryParse(sizeMatch.group(1)!) ?? 0.0;
      final mult = sizeMatch.group(2)!.toUpperCase().startsWith('G') ? 1024 * 1024 * 1024 : 1024 * 1024;
      final bytes = (numVal * mult).toInt();
      if (bytes > 0) return bytes;
    }
    final lower = name.toLowerCase();
    if (lower.contains('2160p') || lower.contains('4k')) return 8 * 1024 * 1024 * 1024;
    if (lower.contains('1080p')) return 3 * 1024 * 1024 * 1024;
    if (lower.contains('720p')) return 1400 * 1024 * 1024;
    if (lower.contains('480p') || lower.contains('dvdrip')) return 700 * 1024 * 1024;
    if (lower.contains('season') || lower.contains('complete')) return 12 * 1024 * 1024 * 1024;
    return 2800 * 1024 * 1024;
  }

  static UrlMetadata _fallback(String def) => UrlMetadata(fileName: def, fileExtension: 'bin', totalBytes: -1, supportsResume: true, finalUrl: '');
}
