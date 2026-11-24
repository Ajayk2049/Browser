import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Resolves fresh YouTube stream URLs off the main isolate.
/// Manifest fetching parses large player JSON — it must never run on the
/// UI isolate (frame skips / low-memory kills).
/// Complies with rules.md §13, §26.5, §29.2.
class YoutubeDownloader {
  static final YoutubeDownloader instance = YoutubeDownloader._();
  YoutubeDownloader._();

  /// Browser UA used to open the watch page (a real page view is what makes
  /// YouTube hand out usable player responses for this network).
  static const _webUa =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  /// The client YouTube still serves direct stream URLs to, provided the
  /// request carries the page's `visitorData`. Older versions (and the older
  /// sdkless android client) now fail with FAILED_PRECONDITION.
  static const _androidUa = 'com.google.android.youtube/20.10.38 (Linux; U; Android 14) gzip';
  static const _clientVersion = '20.10.38';
  static const _clientName = 3; // ANDROID

  /// Manifest client sets for the youtube_explode fallback path, best-first.
  static final List<List<YoutubeApiClient>?> clientSets = [
    [YoutubeApiClient.androidVr],
    [YoutubeApiClient.androidVr, YoutubeApiClient.tv],
    [YoutubeApiClient.tv],
    null, // library default
  ];

  static Future<StreamManifest> _getManifest(String videoId, List<YoutubeApiClient>? clients) async {
    final yt = YoutubeExplode();
    try {
      return clients == null
          ? await yt.videos.streamsClient.getManifest(videoId).timeout(const Duration(seconds: 20))
          : await yt.videos.streamsClient.getManifest(videoId, ytClients: clients).timeout(const Duration(seconds: 20));
    } finally { yt.close(); }
  }

  /// First manifest (from the client chain) that has any stream. Throws if all fail.
  static Future<StreamManifest> getManifestBestEffort(String videoId) async {
    Object? lastErr;
    for (final clients in clientSets) {
      try {
        final m = await _getManifest(videoId, clients);
        if (m.streams.isNotEmpty) return m;
      } catch (e) { lastErr = e; }
    }
    throw lastErr ?? 'No streams available';
  }

  /// Returns [videoUrl, videoBytes, audioUrl?, audioBytes?].
  /// [0] == null when no usable stream exists. Throws after 3 attempts.
  Future<List<String?>> resolveStreams(String videoId, String videoItag, String? audioItag) async {
    Object? lastErr;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        return await Isolate.run(() => _resolve(videoId, videoItag, audioItag));
      } catch (e) { lastErr = e; }
      await Future<void>.delayed(Duration(seconds: 2 * (attempt + 1)));
    }
    throw lastErr ?? 'Stream resolution failed';
  }

  /// Muxed progressive formats (video+audio in one MP4). These are the only
  /// YouTube streams still served to non-player clients on blocked networks.
  static const _muxedItags = {'17', '18', '22'};

  /// Best progressive MP4 for [videoId]: returns [url, bytes, itag, null]
  /// ([0] == null when the player response offered none). Must be called from
  /// a background isolate.
  static Future<List<String?>> rawProgressive(String videoId) async {
    final fmts = await _playerFormats(videoId);
    final muxed = fmts.where((f) => _muxedItags.contains(f['itag'])).toList()
      ..sort((a, b) => (b['clen'] as int).compareTo(a['clen'] as int));
    final best = muxed.firstOrNull;
    if (best == null) return List<String?>.filled(4, null);
    return [best['url'] as String, '${best['clen']}', best['itag'] as String, null];
  }

  /// Picks [videoUrl, videoBytes, audioUrl, audioBytes] from the raw player
  /// response. Runs in whatever isolate calls it.
  static Future<List<String?>> rawPick(String videoId, String videoItag, String? audioItag) async {
    final fmts = await _playerFormats(videoId);
    return _pickRaw(fmts, videoItag, audioItag);
  }

  static Future<List<String?>> _resolve(String videoId, String videoItag, String? audioItag) async {
    Object? lastErr;
    // Preferred: raw player response from a page-view session.
    try {
      final fmts = await _playerFormats(videoId);
      final picked = _pickRaw(fmts, videoItag, audioItag);
      if (picked[0] != null) return picked;
    } catch (e) { lastErr = e; }

    // Fallback: youtube_explode client chain.
    for (final clients in clientSets) {
      try {
        final m = await _getManifest(videoId, clients);
        final picked = _pickStreams(m, videoItag, audioItag);
        if (picked[0] != null) return picked;
      } catch (e) { lastErr = e; }
    }
    throw lastErr ?? 'Stream resolution failed';
  }

  // ---------------------------------------------------------------------------
  // Raw InnerTube path
  // ---------------------------------------------------------------------------

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 30),
    followRedirects: true,
    validateStatus: (s) => s != null && s < 500,
  ));

  /// The `visitorData` token the watch page embeds; InnerTube's precondition
  /// check rejects clients that don't echo it back.
  static Future<String> _visitorData(String videoId) async {
    final r = await _dio.get<String>(
      'https://www.youtube.com/watch?v=$videoId',
      options: Options(
        responseType: ResponseType.plain,
        headers: {'User-Agent': _webUa, 'Accept-Language': 'en-US,en;q=0.9'},
      ),
    );
    final m = RegExp(r'"visitorData":"([^"]+)"').firstMatch(r.data ?? '');
    if (m == null) throw StateError('visitorData not found');
    return m.group(1)!;
  }

  /// Player response formats that already carry a direct `url`.
  static Future<List<Map<String, dynamic>>> _playerFormats(String videoId) async {
    final visitor = await _visitorData(videoId);
    final res = await _dio.post<Map<String, dynamic>>(
      'https://www.youtube.com/youtubei/v1/player?prettyPrint=false',
      data: {
        'context': {
          'client': {
            'clientName': 'ANDROID',
            'clientVersion': _clientVersion,
            'androidSdkVersion': 34,
            'hl': 'en',
            'gl': 'US',
            'utcOffsetMinutes': 0,
            'visitorData': visitor,
          },
        },
        'videoId': videoId,
        'contentCheckOk': true,
        'racyCheckOk': true,
      },
      options: Options(headers: {
        'User-Agent': _androidUa,
        'Content-Type': 'application/json',
        'X-Youtube-Client-Name': '$_clientName',
        'X-Youtube-Client-Version': _clientVersion,
        'X-Goog-Visitor-Id': visitor,
      }),
    );
    final body = res.data;
    if (body == null) throw StateError('empty player response');
    if (body['error'] != null) {
      throw StateError('player ${body['error']['status']}: ${body['error']['message']}');
    }
    final status = (body['playabilityStatus'] as Map?)?['status'];
    if (status != null && status != 'OK') {
      throw StateError('playability $status: ${(body['playabilityStatus'] as Map?)?['reason']}');
    }
    final sd = body['streamingData'] as Map?;
    if (sd == null) throw StateError('no streamingData');
    final out = <Map<String, dynamic>>[];
    for (final key in const ['adaptiveFormats', 'formats']) {
      final list = sd[key];
      if (list is! List) continue;
      for (final f in list) {
        if (f is! Map) continue;
        final url = f['url'];
        if (url is! String || url.isEmpty) continue; // signatureCipher only
        out.add({
          'itag': f['itag']?.toString() ?? '',
          'mime': (f['mimeType'] ?? '').toString().split(';').first,
          'clen': int.tryParse('${f['contentLength'] ?? 0}') ?? 0,
          'url': url,
        });
      }
    }
    if (out.isEmpty) throw StateError('no direct urls (sabr-only response)');
    return out;
  }

  static List<String?> _pickRaw(List<Map<String, dynamic>> fmts, String videoItag, String? audioItag) {
    Map<String, dynamic>? pick(String itag, String mimePrefix) {
      for (final f in fmts) {
        if (f['itag'] == itag && (f['mime'] as String).startsWith(mimePrefix)) return f;
      }
      return null;
    }

    // Audio-only download (itag 139/140/…).
    final audioReq = pick(videoItag, 'audio/');
    if (audioReq != null) {
      return [audioReq['url'] as String, '${audioReq['clen']}', null, '0'];
    }

    var video = pick(videoItag, 'video/') ??
        pick('18', 'video/') ??
        // Best AVC (mp4) video available — muxable by the native pipeline.
        (fmts.where((f) => (f['mime'] as String) == 'video/mp4' && f['itag'] != '18')
            .toList()
          ..sort((a, b) => (b['clen'] as int).compareTo(a['clen'] as int)))
            .firstOrNull ??
        (fmts.where((f) => (f['mime'] as String).startsWith('video/')).toList()
          ..sort((a, b) => (b['clen'] as int).compareTo(a['clen'] as int)))
            .firstOrNull;
    if (video == null) return List<String?>.filled(4, null);

    // Progressive muxed stream: no separate audio needed.
    final isMuxed = video['itag'] == '18' || video['itag'] == '22' || video['itag'] == '17';
    Map<String, dynamic>? audio;
    if (!isMuxed) {
      audio = (audioItag != null ? pick(audioItag, 'audio/') : null) ??
          (fmts.where((f) => (f['mime'] as String) == 'audio/mp4').toList()
            ..sort((a, b) => (b['clen'] as int).compareTo(a['clen'] as int)))
              .firstOrNull;
    }
    return [
      video['url'] as String,
      '${video['clen']}',
      audio?['url'] as String?,
      '${audio?['clen'] ?? 0}',
    ];
  }

  static List<String?> _pickStreams(StreamManifest m, String videoItag, String? audioItag) {
    final aOnly = m.audioOnly.where((s) => s.tag.toString() == videoItag).firstOrNull;
    if (aOnly != null) { // Audio-only request (m4a): single stream, no muxing.
      return [aOnly.url.toString(), aOnly.size.totalBytes.toString(), null, '0'];
    }
    final v = m.videoOnly.where((s) => s.tag.toString() == videoItag).firstOrNull ??
        m.muxed.where((s) => s.tag.toString() == videoItag).firstOrNull ??
        m.muxed.sortByVideoQuality().firstOrNull ??
        m.videoOnly.where((s) => s.videoCodec.toLowerCase().contains('avc')).sortByVideoQuality().firstOrNull;
    if (v == null) return List<String?>.filled(4, null);
    final isVideoOnly = m.videoOnly.contains(v);
    var audio = audioItag != null
        ? m.audioOnly.where((s) => s.tag.toString() == audioItag).firstOrNull
        : (isVideoOnly ? m.audioOnly.sortByBitrate().lastOrNull : null);
    if (audioItag != null && audio == null) audio = m.audioOnly.sortByBitrate().lastOrNull;
    return [
      v.url.toString(), v.size.totalBytes.toString(),
      audio?.url.toString(), (audio?.size.totalBytes ?? 0).toString(),
    ];
  }
}
