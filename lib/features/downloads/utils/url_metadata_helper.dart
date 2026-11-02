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
    if (trimmed.startsWith('magnet:?')) return _resolveMagnet(trimmed);

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
        final ext = _extractExtension(cleanName);

        if (Env.enableLogging) developer.log('NATIVE PROBE: url=$fUrl len=$cLen ranges=$supRanges name=$cleanName', name: 'Probe');
        if (cLen > 0) return UrlMetadata(fileName: cleanName, fileExtension: ext, totalBytes: cLen, supportsResume: supRanges, finalUrl: fUrl);
      }
    } catch (e) {
      if (Env.enableLogging) developer.log('Native probe fallback: $e', name: 'Probe');
    }

    try {
      final dio = DioClient.instance;
      final reqHeaders = <String, dynamic>{
        'Range': 'bytes=0-0',
        'User-Agent': 'Mozilla/5.0 (Android; Mobile; rv:144.0) Gecko/144.0 Firefox/144.0',
        'Accept': '*/*',
        'Referer': ?ref,
      };

      var response = await dio.get<dynamic>(
        trimmed,
        options: Options(headers: reqHeaders, followRedirects: true, maxRedirects: 8, responseType: ResponseType.stream, validateStatus: (s) => s != null && s < 500),
      );

      if (response.statusCode == 429) {
        final retrySec = int.tryParse(response.headers.value('retry-after') ?? '') ?? 3;
        await Future<void>.delayed(Duration(seconds: retrySec.clamp(1, 10)));
        response = await dio.get<dynamic>(
          trimmed,
          options: Options(headers: reqHeaders, followRedirects: true, maxRedirects: 8, responseType: ResponseType.stream, validateStatus: (s) => s != null && s < 500),
        );
      }

      try {
        final body = response.data;
        if (body is ResponseBody) unawaited(body.stream.listen(null).cancel());
      } catch (_) {}

      final headers = response.headers;
      final finalUrl = response.realUri.toString();
      final code = response.statusCode ?? 0;
      final cr = headers.value('content-range');
      final clRaw = int.tryParse(headers.value('content-length') ?? '') ?? -1;
      int len = -1;

      if (cr != null && cr.contains('/')) {
        final total = int.tryParse(cr.substring(cr.lastIndexOf('/') + 1).trim()) ?? -1;
        if (total > 0) len = total;
      }
      if (len <= 0 && (clRaw > 1 || code == 200)) len = clRaw;
      if (code != 200 && code != 206 && code != 416) len = -1;

      if (len <= 0 && (code == 200 || code == 206 || code == 416)) {
        try {
          final head = await dio.head<dynamic>(
            finalUrl,
            options: Options(
              headers: <String, dynamic>{
                'User-Agent': 'Mozilla/5.0 (Android; Mobile; rv:144.0) Gecko/144.0 Firefox/144.0',
                'Accept': '*/*',
                'Referer': ?ref,
              },
              followRedirects: true,
              maxRedirects: 8,
              validateStatus: (s) => s != null && s < 500,
            ),
          );
          final hl = int.tryParse(head.headers.value('content-length') ?? '') ?? -1;
          if (hl > 0) len = hl;
        } catch (_) {}
      }

      final String? name = _parseContentDisposition(headers.value('content-disposition')) ??
          _parseQueryParams(response.realUri) ??
          _parsePathSegment(response.realUri);

      final cleanName = _cleanFileName(name ?? 'download_${DateTime.now().millisecondsSinceEpoch}');
      final ext = _extractExtension(cleanName);
      final acceptRanges = headers.value('accept-ranges');
      final resume = acceptRanges?.toLowerCase().contains('bytes') == true || cr != null;

      return UrlMetadata(fileName: cleanName, fileExtension: ext, totalBytes: len, supportsResume: resume, finalUrl: finalUrl);
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

  static String extractExtension(String name) => _extractExtension(name);

  static String extractCandidateName(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return 'download_${DateTime.now().millisecondsSinceEpoch}.bin';
    if (trimmed.startsWith('magnet:?')) {
      final uri = Uri.tryParse(trimmed);
      final dn = uri?.queryParameters['dn'];
      if (dn != null && dn.isNotEmpty) return _cleanFileName(Uri.decodeComponent(dn.replaceAll('+', ' ')));
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
    final uri = Uri.tryParse(magnetUri);
    final raw = uri?.queryParameters['dn'];
    final dn = (raw?.isNotEmpty == true) ? _cleanFileName(Uri.decodeComponent(raw!.replaceAll('+', ' '))) : 'Torrent_${DateTime.now().millisecondsSinceEpoch}';
    return UrlMetadata(fileName: dn, fileExtension: _extractExtension(dn), totalBytes: -1, supportsResume: true, finalUrl: magnetUri);
  }

  static UrlMetadata _fallback(String def) => UrlMetadata(fileName: def, fileExtension: 'bin', totalBytes: -1, supportsResume: true, finalUrl: '');
}
