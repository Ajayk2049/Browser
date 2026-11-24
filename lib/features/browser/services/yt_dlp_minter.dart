import 'dart:async';

import 'package:extractor/extractor.dart';
import 'package:flutter/foundation.dart';

/// Attested-URL source for YouTube.
///
/// YouTube only serves adaptive (720p/1080p) streams to clients that pass its
/// JS attestation challenge: those URLs carry `pot`/`n` parameters, and without
/// them googlevideo answers 403 at byte 0 no matter how the request is shaped.
/// The bundled yt-dlp extractor performs that challenge (BotGuard + nsig) and
/// hands back short-lived, attested URLs.
///
/// This class only *mints URLs*. The transfer itself stays in the native
/// engine (single sequential GET, no chunking - see DownloadEngine).
class YtDlpMinter {
  static final YtDlpMinter instance = YtDlpMinter._();
  YtDlpMinter._();

  final YoutubeDLFlutter _yt = YoutubeDLFlutter.instance;
  Future<bool>? _init;
  bool _updateChecked = false;
  static const _minYtDlpVersion = '2026.11.23';

  Future<bool> ensureReady() => _init ??= _initialize();

  Future<bool> _initialize() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final res = await _yt.initialize(enableFFmpeg: false);
        if (!res.success) {
          debugPrint('[MINT] init failed (try ${attempt + 1}): ${res.errorMessage}');
        } else {
          try {
            final v = await _yt.getVersion();
            debugPrint('[MINT] ready yt-dlp=${v.youtubeDlVersion}');
          } catch (_) {}
          unawaited(_refreshInBackground());
          return true;
        }
      } catch (e) {
        debugPrint('[MINT] init error (try ${attempt + 1}): $e');
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    _init = null;
    return false;
  }

  /// yt-dlp releases that understand YouTube's current attestation.
  Future<void> _refreshInBackground() async {
    if (_updateChecked) return;
    _updateChecked = true;
    try {
      final v = await _yt.getVersion();
      final current = _dateOf(v.youtubeDlVersion);
      if (current != null && current.compareTo(_minYtDlpVersion) >= 0) return;
      final r = await _yt.updateYoutubeDL(channel: UpdateChannel.stable);
      debugPrint('[MINT] update ${r.status} ${r.version} ${r.errorMessage ?? ''}');
    } catch (e) {
      debugPrint('[MINT] update error: $e');
    }
  }

  static String? _dateOf(String? version) {
    final m = RegExp(r'(\d{4})\.(\d{2})\.(\d{2})').firstMatch(version ?? '');
    return m == null ? null : '${m.group(1)}.${m.group(2)}.${m.group(3)}';
  }

  /// All formats yt-dlp can see, with attested URLs.
  Future<List<VideoFormat>> formats(String url) async {
    final r = await formatsWithTitle(url);
    return r.$1;
  }

  /// Real video title, kept for the grabber list.
  String? lastTitle;

  /// Formats plus the video title.
  Future<(List<VideoFormat>, String?)> formatsWithTitle(String url) async {
    if (!await ensureReady()) return (<VideoFormat>[], null);
    try {
      final info = await _yt.getVideoInfo(url);
      lastTitle = info.title?.trim();
      final list = (info.formats ?? const <VideoFormat?>[])
          .whereType<VideoFormat>()
          .where((f) => _usable(f))
          .toList();
      return (list, lastTitle);
    } catch (e) {
      debugPrint('[MINT] formats failed: $e');
      return (<VideoFormat>[], null);
    }
  }

  /// HLS/DASH-manifest URLs are playlists, not media: the native engine would
  /// happily "download" the 90 KB manifest. Only direct `videoplayback`
  /// endpoints are usable.
  static bool _usable(VideoFormat f) {
    final u = f.url ?? '';
    if (u.isEmpty) return false;
    if (u.contains('.m3u8')) return false;
    if (u.contains('manifest.googlevideo.com')) return false;
    if (u.contains('/hls/')) return false;
    return u.contains('/videoplayback') || u.contains('/videoplayback?');
  }

  /// Attested [videoUrl, videoBytes, audioUrl, audioBytes] for the requested
  /// itags. Video-only formats are paired with the best AAC track so the engine
  /// can remux them.
  Future<List<String?>> mint(String url, String videoItag, String? audioItag) async {
    final fmts = await formats(url);
    if (fmts.isEmpty) return List<String?>.filled(4, null);

    VideoFormat? find(String? itag) {
      if (itag == null || itag.isEmpty) return null;
      for (final f in fmts) {
        if (f.formatId == itag && (f.url ?? '').isNotEmpty) return f;
      }
      return null;
    }

    var video = find(videoItag);
    video ??= fmts.where((f) => f.height == int.tryParse(videoItag)).firstOrNull;

    // Audio-only request: the requested itag is an audio stream.
    final audioReq = find(videoItag);
    if (audioReq != null && (audioReq.vcodec == null || audioReq.vcodec == 'none')) {
      return [audioReq.url, '${audioReq.filesize ?? 0}', null, '0'];
    }

    video ??= fmts
        .where((f) => (f.url ?? '').isNotEmpty && f.vcodec != null && f.vcodec != 'none')
        .fold<VideoFormat?>(null, (best, f) => (best == null || (f.height ?? 0) > (best.height ?? 0)) ? f : best);
    if (video?.url == null) return List<String?>.filled(4, null);

    VideoFormat? audio = find(audioItag);
    audio ??= fmts
        .where((f) => (f.url ?? '').isNotEmpty && (f.vcodec == null || f.vcodec == 'none') && (f.acodec ?? 'none') != 'none')
        .fold<VideoFormat?>(null, (best, f) => (best == null || (f.tbr ?? 0) > (best.tbr ?? 0)) ? f : best);

    return [
      video!.url,
      '${video.filesize ?? 0}',
      audio?.url,
      '${audio?.filesize ?? 0}',
    ];
  }
}
