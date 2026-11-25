import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Snaptube-style multi-client InnerTube resolver with Kotlin BotGuard PoToken.
/// Zero yt-dlp dependency: all player JSON parsing runs in background isolates.
/// Complies with rules.md §13, §26.5, §29.2 (< 250 lines).
class YoutubeDownloader {
  static final YoutubeDownloader instance = YoutubeDownloader._();
  YoutubeDownloader._();

  static const _ch = MethodChannel('com.dab/downloader');
  static const _socsCookie = 'SOCS=CAE=';
  static const _webUa =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36';

  static const Set<String> avcItags = {
    '137', '299', '136', '298', '135', '134', '133', '160',
  };

  static final List<List<YoutubeApiClient>?> clientSets = [
    [YoutubeApiClient.androidVr],
    [YoutubeApiClient.androidVr, YoutubeApiClient.tv],
    [YoutubeApiClient.tv],
    null,
  ];

  static String? _cachedVisitor;
  static DateTime? _visitorAt;
  static String? _cachedPot;
  static DateTime? _potAt;

  /// Fetches cached `(visitorData, poToken)` on the root isolate before handing
  /// extraction/resolution off to a background isolate.
  static Future<({String visitorData, String? poToken})> fetchSessionTokens(String videoId) async {
    final now = DateTime.now();
    final String? cachedVisitor = (_cachedVisitor != null &&
            _visitorAt != null &&
            now.difference(_visitorAt!).inMinutes < 25)
        ? _cachedVisitor
        : null;
    final String visitor = cachedVisitor ??
        await Isolate.run<String>(() => _obtainVisitorData(videoId));
    _cachedVisitor = visitor;
    _visitorAt = now;

    var pot = (_cachedPot != null && _potAt != null &&
            now.difference(_potAt!).inMinutes < 5)
        ? _cachedPot
        : null;
    if (pot == null) {
      try {
        pot = await _ch
            .invokeMethod<String>('mintPoToken', {'identifier': visitor})
            .timeout(const Duration(seconds: 12));
        if (pot != null && pot.isNotEmpty) {
          _cachedPot = pot;
          _potAt = DateTime.now();
        }
      } catch (e) {
        debugPrint('[POT] mintPoToken failed, continuing without pot: $e');
      }
    }
    return (visitorData: visitor, poToken: pot);
  }

  static Future<StreamManifest> _getManifest(String videoId, List<YoutubeApiClient>? clients) async {
    final yt = YoutubeExplode();
    try {
      return clients == null
          ? await yt.videos.streamsClient.getManifest(videoId).timeout(const Duration(seconds: 20))
          : await yt.videos.streamsClient.getManifest(videoId, ytClients: clients).timeout(const Duration(seconds: 20));
    } finally {
      yt.close();
    }
  }

  static Future<StreamManifest> getManifestBestEffort(String videoId) async {
    Object? lastErr;
    for (final clients in clientSets) {
      try {
        final m = await _getManifest(videoId, clients);
        if (m.streams.isNotEmpty) return m;
      } catch (e) {
        lastErr = e;
      }
    }
    throw lastErr ?? 'No streams available';
  }

  Future<List<String?>> resolveStreams(String videoId, String videoItag, String? audioItag) async {
    Object? lastErr;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final tokens = await fetchSessionTokens(videoId);
        return await Isolate.run(
          () => resolveWithTokens(videoId, videoItag, audioItag, tokens.visitorData, tokens.poToken),
        );
      } catch (e) {
        lastErr = e;
      }
      await Future<void>.delayed(Duration(seconds: 2 * (attempt + 1)));
    }
    throw lastErr ?? 'Stream resolution failed';
  }

  static Future<List<Map<String, dynamic>>> rawFormats(
    String videoId, {
    required String visitorData,
    String? poToken,
  }) =>
      _playerFormatsMultiClient(videoId, visitorData, poToken);

  static Future<List<String?>> resolveWithTokens(
    String videoId,
    String videoItag,
    String? audioItag,
    String visitorData,
    String? poToken,
  ) async {
    Object? lastErr;
    try {
      final fmts = await _playerFormatsMultiClient(videoId, visitorData, poToken);
      final picked = pickRaw(fmts, videoItag, audioItag);
      if (picked[0] != null) return picked;
    } catch (e) {
      lastErr = e;
    }

    for (final clients in clientSets) {
      try {
        final m = await _getManifest(videoId, clients);
        final picked = _pickStreams(m, videoItag, audioItag);
        if (picked[0] != null) return picked;
      } catch (e) {
        lastErr = e;
      }
    }
    throw lastErr ?? 'Stream resolution failed';
  }

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 30),
    followRedirects: true,
    validateStatus: (s) => s != null && s < 500,
  ));

  /// Snaptube's YoutubeParsingHelper.getVisitorData(): `/youtubei/v1/visitor_id`
  /// with `Cookie: SOCS=CAE=`, falling back to the watch HTML if needed.
  static Future<String> _obtainVisitorData(String videoId) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        'https://www.youtube.com/youtubei/v1/visitor_id?prettyPrint=false',
        data: {
          'context': {
            'client': {
              'clientName': 'WEB',
              'clientVersion': '2.20260708.05.00',
              'clientScreen': 'WATCH',
            },
          },
        },
        options: Options(headers: {
          'User-Agent': _webUa,
          'Referer': 'https://www.youtube.com/',
          'Cookie': _socsCookie,
          'Content-Type': 'application/json',
          'X-YouTube-Client-Name': '1',
          'X-YouTube-Client-Version': '2.20260708.05.00',
        }),
      );
      final vd = (res.data?['responseContext'] as Map?)?['visitorData'];
      if (vd is String && vd.isNotEmpty) return vd;
    } catch (_) {}

    final r = await _dio.get<String>(
      'https://www.youtube.com/watch?v=$videoId',
      options: Options(
        responseType: ResponseType.plain,
        headers: {'User-Agent': _webUa, 'Cookie': _socsCookie, 'Accept-Language': 'en-US,en;q=0.9'},
      ),
    );
    final m = RegExp(r'"visitorData":"([^"]+)"').firstMatch(r.data ?? '');
    if (m == null) throw StateError('visitorData not found');
    return m.group(1)!;
  }

  static List<Map<String, dynamic>> get _clients => [
    {
      'name': 'IOS', 'version': '21.26.4', 'id': '5', 'host': 'm.youtube.com',
      'ua': 'com.google.ios.youtube/21.26.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)',
      'gvsPot': true,
      'fields': {
        'deviceMake': 'Apple', 'deviceModel': 'iPhone16,2',
        'osName': 'iPhone', 'osVersion': '18.3.2.22D82',
      },
    },
    {
      'name': 'VISIONOS', 'version': '1.02', 'id': '101', 'host': 'www.youtube.com',
      'ua': 'com.google.visionos.youtube/1.02(RealityDevice14,1; U; CPU visionOS 25_6_0 like Mac OS X;)',
      'gvsPot': false,
      'fields': {
        'deviceMake': 'Apple', 'deviceModel': 'RealityDevice14,1',
        'osName': 'visionOS', 'osVersion': '25.6.0.23O471', 'platform': 'MOBILE',
      },
    },
    {
      'name': 'ANDROID_VR', 'version': '1.65.10', 'id': '28', 'host': 'www.youtube.com',
      'ua': 'com.google.android.apps.youtube.vr.oculus/1.65.10 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip',
      'gvsPot': false,
      'fields': {
        'deviceMake': 'Oculus', 'deviceModel': 'Quest 3',
        'androidSdkVersion': 32, 'osName': 'Android', 'osVersion': '12L',
      },
    },
    {
      'name': 'ANDROID', 'version': '20.10.38', 'id': '3', 'host': 'www.youtube.com',
      'ua': 'com.google.android.youtube/20.10.38 (Linux; U; Android 14) gzip',
      'gvsPot': true,
      'fields': {'androidSdkVersion': 34},
    },
  ];

  static Future<List<Map<String, dynamic>>> _playerFormatsMultiClient(
    String videoId,
    String visitorData,
    String? poToken,
  ) async {
    Object? lastErr;
    for (final cfg in _clients) {
      try {
        final list = await _fetchClientFormats(videoId, visitorData, poToken, cfg);
        if (list.isNotEmpty) return list;
      } catch (e) {
        lastErr = e;
      }
    }
    throw lastErr ?? StateError('All InnerTube clients returned no direct formats');
  }

  static Future<List<Map<String, dynamic>>> _fetchClientFormats(
    String videoId,
    String visitorData,
    String? poToken,
    Map<String, dynamic> cfg,
  ) async {
    final host = cfg['host'] as String;
    final bodyMap = <String, dynamic>{
      'context': {
        'client': {
          'clientName': cfg['name'],
          'clientVersion': cfg['version'],
          'hl': 'en',
          'gl': 'US',
          'utcOffsetMinutes': 0,
          'visitorData': visitorData,
          ...(cfg['fields'] as Map<String, dynamic>),
        },
      },
      'videoId': videoId,
      'contentCheckOk': true,
      'racyCheckOk': true,
      'playbackContext': {
        'contentPlaybackContext': {'html5Preference': 'HTML5_PREF_WANTS'},
      },
    };
    if (poToken != null && poToken.isNotEmpty) {
      bodyMap['serviceIntegrityDimensions'] = {'poToken': poToken};
    }

    final res = await _dio.post<Map<String, dynamic>>(
      'https://$host/youtubei/v1/player?prettyPrint=false',
      data: bodyMap,
      options: Options(headers: {
        'User-Agent': cfg['ua'],
        'Content-Type': 'application/json',
        'Origin': 'https://$host',
        'Referer': 'https://$host/',
        'Cookie': _socsCookie,
        'X-Youtube-Client-Name': cfg['id'],
        'X-Youtube-Client-Version': cfg['version'],
        'X-Goog-Visitor-Id': visitorData,
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
    final attachPot = (cfg['gvsPot'] == true) && poToken != null && poToken.isNotEmpty;

    final out = <Map<String, dynamic>>[];
    for (final key in const ['formats', 'adaptiveFormats']) {
      final list = sd[key];
      if (list is! List) continue;
      for (final f in list) {
        if (f is! Map) continue;
        var url = f['url'];
        if (url is! String || url.isEmpty) continue;
        if (url.contains('.m3u8') || url.contains('manifest.googlevideo.com') || url.contains('/hls/')) {
          continue;
        }
        if (attachPot && !url.contains('pot=')) {
          final sep = url.contains('?') ? '&' : '?';
          url = '$url${sep}pot=${Uri.encodeQueryComponent(poToken)}';
        }
        final mimeFull = (f['mimeType'] ?? '').toString();
        final mime = mimeFull.split(';').first.trim().toLowerCase();
        final codecs = RegExp(r'codecs="([^"]+)"').firstMatch(mimeFull)?.group(1)?.toLowerCase() ?? '';
        out.add({
          'itag': f['itag']?.toString() ?? '',
          'mime': mime,
          'codecs': codecs,
          'muxed': key == 'formats',
          'clen': int.tryParse('${f['contentLength'] ?? 0}') ?? 0,
          'height': int.tryParse('${f['height'] ?? 0}') ?? 0,
          'fps': int.tryParse('${f['fps'] ?? 0}') ?? 0,
          'url': url,
        });
      }
    }
    if (out.isEmpty) throw StateError('no direct urls from ${cfg['name']}');
    return out;
  }

  static bool isMuxableAvc(Map<String, dynamic> f) {
    if ((f['mime'] as String) != 'video/mp4') return false;
    final codecs = (f['codecs'] as String? ?? '').toLowerCase();
    if (codecs.isNotEmpty) return codecs.contains('avc');
    return avcItags.contains(f['itag'] as String? ?? '');
  }

  static List<String?> pickRaw(List<Map<String, dynamic>> fmts, String videoItag, String? audioItag) {
    Map<String, dynamic>? pick(String itag, String mimePrefix) {
      for (final f in fmts) {
        if (f['itag'] == itag && (f['mime'] as String).startsWith(mimePrefix)) return f;
      }
      return null;
    }

    final audioReq = pick(videoItag, 'audio/');
    if (audioReq != null) return [audioReq['url'] as String, '${audioReq['clen']}', null, '0'];

    final requested = pick(videoItag, 'video/');
    final video = (requested != null && (requested['muxed'] == true || isMuxableAvc(requested)))
        ? requested
        : (fmts.where((f) => f['muxed'] == true && (f['itag'] == '22' || f['itag'] == '18')).toList()
              ..sort((a, b) => (b['height'] as int).compareTo(a['height'] as int)))
            .firstOrNull ??
          (fmts.where((f) => f['muxed'] != true && isMuxableAvc(f)).toList()
              ..sort((a, b) => (b['clen'] as int).compareTo(a['clen'] as int)))
            .firstOrNull;
    if (video == null) return List<String?>.filled(4, null);

    final isMuxed = video['muxed'] == true || video['itag'] == '18' || video['itag'] == '22' || video['itag'] == '17';
    Map<String, dynamic>? audio;
    if (!isMuxed) {
      audio = (audioItag != null ? pick(audioItag, 'audio/') : null) ??
          (fmts.where((f) => (f['mime'] as String) == 'audio/mp4').toList()
                ..sort((a, b) => (b['clen'] as int).compareTo(a['clen'] as int)))
              .firstOrNull;
    }
    return [video['url'] as String, '${video['clen']}', audio?['url'] as String?, '${audio?['clen'] ?? 0}'];
  }

  static List<String?> _pickStreams(StreamManifest m, String videoItag, String? audioItag) {
    final aOnly = m.audioOnly.where((s) => s.tag.toString() == videoItag).firstOrNull;
    if (aOnly != null) return [aOnly.url.toString(), aOnly.size.totalBytes.toString(), null, '0'];
    final v = m.videoOnly.where((s) => s.tag.toString() == videoItag && s.videoCodec.toLowerCase().contains('avc')).firstOrNull ??
        m.muxed.where((s) => s.tag.toString() == videoItag).firstOrNull ??
        m.muxed.sortByVideoQuality().firstOrNull ??
        m.videoOnly.where((s) => s.videoCodec.toLowerCase().contains('avc')).sortByVideoQuality().firstOrNull;
    if (v == null) return List<String?>.filled(4, null);
    final isVideoOnly = m.videoOnly.contains(v);
    var audio = audioItag != null
        ? m.audioOnly.where((s) => s.tag.toString() == audioItag).firstOrNull
        : (isVideoOnly ? m.audioOnly.where((s) => s.container.name.toLowerCase() == 'mp4').sortByBitrate().lastOrNull : null);
    if (audioItag != null && audio == null) audio = m.audioOnly.sortByBitrate().lastOrNull;
    return [v.url.toString(), v.size.totalBytes.toString(), audio?.url.toString(), (audio?.size.totalBytes ?? 0).toString()];
  }
}
