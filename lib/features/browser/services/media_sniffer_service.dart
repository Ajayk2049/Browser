import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../downloads/services/download_service.dart';
import '../widgets/media_grabber_sheet.dart';
import 'youtube_grabber_service.dart';

/// A YouTube stream URL observed from the page's own player traffic.
class SniffedMedia {
  final String url, pageUrl, itag, mime;
  const SniffedMedia({required this.url, required this.pageUrl, required this.itag, required this.mime});

  String? get videoId => YoutubeGrabberService.extractVideoId(pageUrl);
  bool get isVideo => mime.startsWith('video/');
  bool get isAudio => mime.startsWith('audio/');
}

/// Any-site media captured by the WebExtension bridge.
class GenericSniffedMedia {
  final String url, pageUrl, originUrl, mime, mediaType, format, filename, quality;
  final String? audioUrl, replacesUrl;
  final int size;
  final Map<String, String> headers;
  final bool isPreview;
  const GenericSniffedMedia({
    required this.url,
    required this.pageUrl,
    required this.originUrl,
    required this.mime,
    required this.mediaType,
    required this.format,
    required this.filename,
    this.quality = '',
    this.audioUrl,
    this.replacesUrl,
    required this.size,
    required this.headers,
    this.isPreview = false,
  });

  String get dedupKey => '${MediaSnifferService.stripQuery(url)}::$mediaType::$quality';
}

/// Receives sniffed stream URLs from the native extension bridge:
/// - YouTube URLs stay strictly in [buildItems] keyed by videoId.
/// - Non-YouTube captures go into [genericStream] & per-page cache for any-site grabbing,
///   filtering out non-media (JSON/TXT/docs) and isolating hover previews in the background.
class MediaSnifferService {
  static final MediaSnifferService instance = MediaSnifferService._();
  MediaSnifferService._();

  static const Map<String, String> avcVideoItags = {
    '17': '144p', '18': '360p', '22': '720p',
    '133': '240p', '134': '360p', '135': '480p', '136': '720p', '137': '1080p',
    '264': '1440p', '298': '720p60', '299': '1080p60',
  };
  static const Set<String> m4aAudioItags = {'139', '140', '141', '256', '258'};

  static final RegExp _nonMediaExtRe = RegExp(
    r'\.(json|jsonp|txt|text|vtt|srt|ass|ssa|sub|sbv|ttml|dfxp|xml|csv|tsv|log|ini|conf|cfg|yaml|yml|toml|md|js|mjs|cjs|css|html?|xhtml|svg|png|jpe?g|gif|webp|avif|bmp|ico|woff2?|ttf|otf|eot|map|wasm|pdf|zip|rar|7z|tar|gz|apk|xapk|exe|msi|dmg|iso|bin|dat|key)$',
    caseSensitive: false,
  );
  static final RegExp _genericNameRe = RegExp(
    r'^(master|index[^.]*|playlist[^.]*|manifest[^.]*|chunklist[^.]*|video|stream|media|clip)(\.[a-z0-9]+)?$',
    caseSensitive: false,
  );

  final Map<String, Map<String, SniffedMedia>> _byVideo = {};
  final StreamController<SniffedMedia> _ctrl = StreamController<SniffedMedia>.broadcast();
  Stream<SniffedMedia> get stream => _ctrl.stream;

  final Map<String, Map<String, GenericSniffedMedia>> _genericByPage = {};
  final Map<String, Map<String, GenericSniffedMedia>> _previewsByPage = {};
  final Map<String, Set<String>> _previewUrlKeysByPage = {};
  final Map<String, Set<String>> _knownVariantUrlsByPage = {};
  final Set<String> _inspectedPlaylists = {};
  final StreamController<GenericSniffedMedia> _genericCtrl = StreamController<GenericSniffedMedia>.broadcast();
  final StreamController<String> _removedCtrl = StreamController<String>.broadcast();
  Stream<GenericSniffedMedia> get genericStream => _genericCtrl.stream;
  Stream<String> get removedUrlStream => _removedCtrl.stream;

  static String stripQuery(String u) {
    final i = u.indexOf('?');
    final h = u.indexOf('#');
    final cut = (i >= 0 && h >= 0) ? (i < h ? i : h) : (i >= 0 ? i : h);
    return cut >= 0 ? u.substring(0, cut) : u;
  }

  /// Preserves query parameters (e.g. `?v=...`, `?viewkey=...`) while stripping `#fragment`.
  static String pageKey(String u) {
    final hash = u.indexOf('#');
    final noFrag = (hash >= 0 ? u.substring(0, hash) : u).trim();
    final uri = Uri.tryParse(noFrag);
    if (uri == null || uri.host.isEmpty) return noFrag;
    final cleanPath = (uri.path.length > 1 && uri.path.endsWith('/'))
        ? uri.path.substring(0, uri.path.length - 1)
        : uri.path;
    final q = uri.hasQuery ? '?${uri.query}' : '';
    return '${uri.scheme.toLowerCase()}://${uri.host.toLowerCase()}$cleanPath$q';
  }

  static bool isAllowedMedia({required String url, required String mediaType, String mime = '', String filename = ''}) {
    final t = mediaType.toLowerCase();
    if (t != 'video' && t != 'audio' && t != 'stream') return false;
    final cleanUrlPath = (Uri.tryParse(url)?.path ?? stripQuery(url)).toLowerCase();
    if (_nonMediaExtRe.hasMatch(cleanUrlPath)) return false;
    if (filename.isNotEmpty && _nonMediaExtRe.hasMatch(filename.toLowerCase())) return false;
    final m = mime.toLowerCase().split(';').first.trim();
    if (m.isNotEmpty &&
        m != 'application/vnd.apple.mpegurl' &&
        m != 'application/x-mpegurl' &&
        m != 'audio/mpegurl' &&
        m != 'application/dash+xml') {
      if (m.startsWith('text/') ||
          m.startsWith('image/') ||
          m.startsWith('font/') ||
          m == 'application/json' ||
          m.endsWith('+json') ||
          m == 'application/xml' ||
          m == 'application/xhtml+xml' ||
          m.contains('javascript') ||
          m == 'application/x-subrip' ||
          m == 'application/ttml+xml' ||
          m == 'application/wasm') {
        return false;
      }
    }
    return true;
  }

  void handleNativeCall(MethodCall call) {
    final args = Map<dynamic, dynamic>.from(call.arguments as Map? ?? {});
    if (call.method == 'onSniffedGeneric') {
      _handleGenericCall(args);
      return;
    }
    ingestUrl(
      url: args['url'] as String? ?? '',
      itag: args['itag'] as String? ?? '',
      pageUrl: args['pageUrl'] as String? ?? '',
      mime: args['mime'] as String? ?? '',
    );
  }

  bool ingestUrl({required String url, required String itag, required String pageUrl, String mime = ''}) {
    if (url.isEmpty || itag.isEmpty) return false;
    final known = avcVideoItags.containsKey(itag) || m4aAudioItags.contains(itag);
    if (!known) return false;
    final resolvedMime = mime.isNotEmpty ? mime : (m4aAudioItags.contains(itag) ? 'audio/mp4' : 'video/mp4');
    final m = SniffedMedia(url: url, pageUrl: pageUrl, itag: itag, mime: resolvedMime);
    final vid = m.videoId;
    if (vid == null) return false;
    debugPrint('[SNIFF] itag=$itag mime=$resolvedMime video=$vid');
    _byVideo.putIfAbsent(vid, () => {});
    _byVideo[vid]![itag] = m;
    _ctrl.add(m);
    return true;
  }

  void _handleGenericCall(Map<dynamic, dynamic> args) {
    final url = args['url'] as String? ?? '';
    final pageUrl = args['pageUrl'] as String? ?? '';
    final originUrl = args['originUrl'] as String? ?? '';
    if (url.isEmpty || url.contains('googlevideo.com') || url.contains('/videoplayback')) return;
    if (YoutubeGrabberService.isYouTubeUrl(pageUrl) || YoutubeGrabberService.isYouTubeUrl(originUrl)) return;

    final mime = args['mime'] as String? ?? '';
    final mediaType = (args['mediaType'] as String? ?? '').toLowerCase();
    final filename = args['filename'] as String? ?? '';
    if (!isAllowedMedia(url: url, mediaType: mediaType, mime: mime, filename: filename)) return;

    final rawHdrs = args['headers'] as Map? ?? {};
    final headers = <String, String>{};
    rawHdrs.forEach((k, v) { if (k != null && v != null && '$v'.isNotEmpty) headers['$k'] = '$v'; });

    final keySource = pageUrl.isNotEmpty ? pageUrl : (originUrl.isNotEmpty ? originUrl : url);
    final pKey = pageKey(keySource);
    final cleanUrl = stripQuery(url);

    // Ignore child media playlists already owned by a parent master playlist.
    if (mediaType == 'stream' && (_knownVariantUrlsByPage[pKey]?.contains(cleanUrl) ?? false)) {
      return;
    }

    final previewFlag = (args['isPreview'] as bool? ?? false) ||
        (_previewUrlKeysByPage[pKey]?.contains(cleanUrl) ?? false);

    final item = GenericSniffedMedia(
      url: url,
      pageUrl: pageUrl,
      originUrl: originUrl,
      mime: mime,
      mediaType: mediaType,
      format: args['format'] as String? ?? '',
      filename: filename,
      size: (args['size'] as num?)?.toInt() ?? -1,
      headers: headers,
      isPreview: previewFlag,
    );

    if (previewFlag) {
      _previewUrlKeysByPage.putIfAbsent(pKey, () => {}).add(cleanUrl);
      final mainBucket = _genericByPage[pKey];
      if (mainBucket != null) {
        final keys = mainBucket.entries.where((e) => stripQuery(e.value.url) == cleanUrl).map((e) => e.key).toList();
        for (final k in keys) {
          mainBucket.remove(k);
        }
        if (keys.isNotEmpty) _removedCtrl.add(cleanUrl);
      }
      if (_previewsByPage.length > 24 && !_previewsByPage.containsKey(pKey)) {
        _previewsByPage.remove(_previewsByPage.keys.first);
      }
      final prevBucket = _previewsByPage.putIfAbsent(pKey, () => {});
      if (prevBucket.length < 40) prevBucket[item.dedupKey] = item;
      return;
    }

    if (_genericByPage.length > 24 && !_genericByPage.containsKey(pKey)) {
      final oldest = _genericByPage.keys.first;
      _genericByPage.remove(oldest);
      _previewsByPage.remove(oldest);
      _previewUrlKeysByPage.remove(oldest);
      _knownVariantUrlsByPage.remove(oldest);
    }
    final bucket = _genericByPage.putIfAbsent(pKey, () => {});
    final dKey = item.dedupKey;
    final prev = bucket[dKey];
    if (prev != null) {
      final merged = GenericSniffedMedia(
        url: item.headers.isNotEmpty || prev.headers.isEmpty ? item.url : prev.url,
        pageUrl: item.pageUrl.isNotEmpty ? item.pageUrl : prev.pageUrl,
        originUrl: item.originUrl.isNotEmpty ? item.originUrl : prev.originUrl,
        mime: item.mime.isNotEmpty ? item.mime : prev.mime,
        mediaType: item.mediaType,
        format: item.format.isNotEmpty ? item.format : prev.format,
        filename: item.filename.isNotEmpty ? item.filename : prev.filename,
        size: item.size > 0 ? item.size : prev.size,
        headers: {...prev.headers, ...item.headers},
      );
      if (merged.size == prev.size && merged.filename == prev.filename && merged.headers.length == prev.headers.length && merged.url == prev.url) return;
      bucket[dKey] = merged;
      _genericCtrl.add(merged);
      if (merged.mediaType == 'stream') unawaited(_expandPlaylistVariants(pKey, merged));
      return;
    }
    if (bucket.length >= 60) return;
    bucket[dKey] = item;
    debugPrint('[SNIFF-ANY] ${item.mediaType}/${item.format} size=${item.size} url=${item.url}');
    _genericCtrl.add(item);
    if (item.mediaType == 'stream') unawaited(_expandPlaylistVariants(pKey, item));
  }

  Future<void> _expandPlaylistVariants(String pKey, GenericSniffedMedia playlist) async {
    final cleanPlaylistUrl = stripQuery(playlist.url);
    final inspectKey = '$pKey::$cleanPlaylistUrl';
    if (!_inspectedPlaylists.add(inspectKey)) return;
    if (_inspectedPlaylists.length > 200) _inspectedPlaylists.clear();
    final ref = playlist.headers['Referer'] ?? (playlist.pageUrl.isNotEmpty ? playlist.pageUrl : null);
    final variants = await DownloadService().inspectPlaylist(playlist.url, referer: ref, headers: playlist.headers);
    if (variants.isEmpty) return;

    final bucket = _genericByPage[pKey];
    if (bucket == null) return;

    // Replace raw stream item whenever variants resolve (including single-variant streams).
    bucket.remove(playlist.dedupKey);
    _removedCtrl.add(cleanPlaylistUrl);

    final knownVars = _knownVariantUrlsByPage.putIfAbsent(pKey, () => {});
    final streamTag = playlist.format.isNotEmpty ? playlist.format : 'HLS';
    for (final v in variants) {
      final vUrl = v['url'] as String? ?? '';
      if (vUrl.isEmpty) continue;
      final cleanVar = stripQuery(vUrl);
      if (cleanVar != cleanPlaylistUrl) {
        knownVars.add(cleanVar);
        final staleKeys = bucket.entries
            .where((e) => e.value.mediaType == 'stream' || (stripQuery(e.value.url) == cleanVar && e.value.quality.startsWith('Default Stream')))
            .where((e) => stripQuery(e.value.url) == cleanVar)
            .map((e) => e.key)
            .toList();
        for (final k in staleKeys) {
          bucket.remove(k);
        }
        if (staleKeys.isNotEmpty) _removedCtrl.add(cleanVar);
      }
      final aUrl = v['audioUrl'] as String?;
      if (aUrl != null && aUrl.isNotEmpty) knownVars.add(stripQuery(aUrl));

      final label = v['label'] as String? ?? '';
      final vType = (v['type'] as String? ?? 'video').toLowerCase();
      final fmt = (v['format'] as String? ?? 'MP4').toUpperCase();
      final qLabel = label.isNotEmpty ? '$label ($streamTag)' : streamTag;
      final expanded = GenericSniffedMedia(
        url: vUrl,
        pageUrl: playlist.pageUrl,
        originUrl: playlist.originUrl,
        mime: playlist.mime,
        mediaType: vType,
        format: fmt,
        filename: playlist.filename,
        quality: qLabel,
        audioUrl: aUrl,
        replacesUrl: playlist.url,
        size: -1,
        headers: playlist.headers,
      );
      bucket[expanded.dedupKey] = expanded;
      _genericCtrl.add(expanded);
    }
  }

  static String _formatSize(int bytes) {
    if (bytes <= 0) return '';
    if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  static bool _isGenericFilename(String name) {
    final trimmed = name.trim().toLowerCase();
    if (trimmed.isEmpty) return true;
    return trimmed.endsWith('.m3u8') || trimmed.endsWith('.mpd') || _genericNameRe.hasMatch(trimmed);
  }

  DetectedMedia toDetectedMedia(GenericSniffedMedia g, {String pageTitle = ''}) {
    final host = Uri.tryParse(g.url)?.host ?? 'Web';
    final cleanPageTitle = pageTitle.trim();
    final usePageTitle = cleanPageTitle.isNotEmpty &&
        cleanPageTitle != 'Home' &&
        (g.mediaType == 'stream' || _isGenericFilename(g.filename));
    final title = usePageTitle ? cleanPageTitle : (g.filename.isNotEmpty ? g.filename : (cleanPageTitle.isNotEmpty ? cleanPageTitle : host));
    return DetectedMedia(
      url: g.url,
      audioUrl: g.audioUrl,
      referer: g.headers['Referer'] ?? (g.pageUrl.isNotEmpty ? g.pageUrl : (g.originUrl.isNotEmpty ? g.originUrl : null)),
      title: title,
      type: g.mediaType,
      quality: g.quality.isNotEmpty ? g.quality : null,
      size: _formatSize(g.size),
      totalBytes: g.size > 0 ? g.size : null,
      format: g.format.isNotEmpty ? g.format : null,
      headers: g.headers.isEmpty ? null : g.headers,
      sniffed: true,
    );
  }

  List<DetectedMedia> _buildFromStore(Map<String, Map<String, GenericSniffedMedia>> store, String activeUrl, {String pageTitle = ''}) {
    if (activeUrl.isEmpty || YoutubeGrabberService.isYouTubeUrl(activeUrl)) return const [];
    final targetKey = pageKey(activeUrl);
    final activeHost = Uri.tryParse(activeUrl)?.host.toLowerCase() ?? '';
    final out = <String, DetectedMedia>{};
    for (final entry in store.entries) {
      for (final g in entry.value.values) {
        final originHost = Uri.tryParse(g.originUrl)?.host.toLowerCase() ?? '';
        final matchesExactPage = entry.key == targetKey || (g.pageUrl.isNotEmpty && pageKey(g.pageUrl) == targetKey);
        final matchesHostFallback = g.pageUrl.isEmpty && activeHost.isNotEmpty && originHost == activeHost;
        if (matchesExactPage || matchesHostFallback) {
          out[g.dedupKey] = toDetectedMedia(g, pageTitle: pageTitle);
        }
      }
    }
    return out.values.toList();
  }

  List<DetectedMedia> buildGenericItemsForPage(String activeUrl, {String pageTitle = ''}) =>
      _buildFromStore(_genericByPage, activeUrl, pageTitle: pageTitle);

  List<DetectedMedia> buildPreviewItemsForPage(String activeUrl, {String pageTitle = ''}) =>
      _buildFromStore(_previewsByPage, activeUrl, pageTitle: pageTitle);

  void clearFor(String videoId) => _byVideo.remove(videoId);

  List<DetectedMedia> buildItems(String videoId, String title) {
    final reg = _byVideo[videoId];
    if (reg == null || reg.isEmpty) return [];
    final audios = reg.values.where((m) => m.isAudio && m4aAudioItags.contains(m.itag)).toList();
    SniffedMedia? bestAudio;
    int bestRank = -1;
    for (final a in audios) {
      final rank = m4aAudioItags.toList().indexOf(a.itag);
      if (rank > bestRank) { bestRank = rank; bestAudio = a; }
    }
    final videos = reg.values.where((m) => m.isVideo && avcVideoItags.containsKey(m.itag)).toList()
      ..sort((a, b) {
        int q(String it) => int.tryParse(avcVideoItags[it]?.replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? 0;
        return q(b.itag).compareTo(q(a.itag));
      });
    final referer = reg.values.first.pageUrl;
    final items = <DetectedMedia>[];
    for (final v in videos) {
      items.add(DetectedMedia(
        url: v.url,
        audioUrl: bestAudio?.url,
        audioItag: bestAudio?.itag,
        referer: referer,
        title: title,
        quality: avcVideoItags[v.itag],
        format: 'MP4',
        type: 'video',
        videoId: videoId,
        videoItag: v.itag,
        sniffed: true,
      ));
    }
    if (bestAudio != null && videos.isEmpty) {
      items.add(DetectedMedia(
        url: bestAudio.url,
        referer: referer,
        title: title,
        quality: 'Audio (M4A)',
        format: 'M4A',
        type: 'audio',
        videoId: videoId,
        videoItag: bestAudio.itag,
        sniffed: true,
      ));
    }
    return items;
  }
}
