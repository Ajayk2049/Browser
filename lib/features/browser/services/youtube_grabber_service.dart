import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:extractor/extractor.dart' show VideoFormat;
import 'youtube_downloader.dart';
import 'yt_dlp_minter.dart';
import '../widgets/media_grabber_sheet.dart';

/// Helper service utilizing youtube_explode_dart to resolve direct
/// media streams from any YouTube URL for 1DM downloading.
/// Complies with rules.md Â§13, Â§26.5, Â§29.2 (< 250 lines).
class YoutubeGrabberService {
  static final YoutubeGrabberService instance = YoutubeGrabberService._internal();
  YoutubeGrabberService._internal();

  static bool isYouTubeUrl(String url) {
    if (url.isEmpty) return false;
    final lower = url.toLowerCase();
    return (lower.contains('youtube.com/watch') ||
            lower.contains('m.youtube.com/watch') ||
            lower.contains('youtu.be/') ||
            lower.contains('youtube.com/shorts/') ||
            lower.contains('m.youtube.com/shorts/')) &&
        !lower.contains('youtube.com/results') &&
        !lower.contains('youtube.com/feed');
  }

  static final Map<String, String> knownVideoIds = {};
  static void recordVideoId(String url, String id) {
    if (knownVideoIds.length >= 32) knownVideoIds.remove(knownVideoIds.keys.first);
    knownVideoIds[url] = id;
  }

  static String? extractVideoId(String url, {String? referer, String? finalUrl}) {
    if (knownVideoIds.containsKey(url)) return knownVideoIds[url];
    if (finalUrl != null && knownVideoIds.containsKey(finalUrl)) return knownVideoIds[finalUrl];
    if (referer != null && knownVideoIds.containsKey(referer)) return knownVideoIds[referer];

    for (final target in [referer, url, finalUrl]) {
      if (target == null || target.isEmpty) continue;
      if (target.length == 11 && RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(target)) return target;
      final uri = Uri.tryParse(target);
      if (uri == null) continue;
      if (uri.queryParameters.containsKey('v')) return uri.queryParameters['v'];
      if (uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty) return uri.pathSegments.last;
      if ((uri.pathSegments.contains('shorts') || uri.pathSegments.contains('embed')) && uri.pathSegments.isNotEmpty) {
        return uri.pathSegments.last;
      }
      final idParam = uri.queryParameters['id'];
      if (idParam != null && idParam.isNotEmpty) {
        final stripped = idParam.startsWith('o-') ? idParam.substring(2) : idParam;
        if (stripped.length == 11) return stripped;
      }
    }
    return null;
  }

  Future<String?> searchVideoIdByTitle(String title) async {
    final yt = YoutubeExplode();
    try {
      final results = await yt.search.search(title).timeout(const Duration(seconds: 10));
      return results.firstOrNull?.id.value;
    } catch (_) {
      return null;
    } finally {
      yt.close();
    }
  }

  Future<({String videoUrl, String? audioUrl})?> refreshStreams({
    required String videoId,
    required String targetVideoItag,
    String? targetAudioItag,
  }) async {
    try {
      // Runs off the main isolate: manifest parsing is too heavy for the UI thread.
      final picked = await Isolate.run(() => _refreshIsolated(videoId, targetVideoItag, targetAudioItag));
      if (picked[0] == null) {
        debugPrint('[DLREFRESH] itag $targetVideoItag not found in refreshed manifest');
        return null;
      }
      return (videoUrl: picked[0]!, audioUrl: picked[1]);
    } catch (e) {
      debugPrint('[DLREFRESH] Error refreshing streams for $videoId: $e');
      return null;
    }
  }

  /// Returns [videoUrl, audioUrl?]; [0] == null means nothing usable was found.
  static Future<List<String?>> _refreshIsolated(String videoId, String targetVideoItag, String? targetAudioItag) async {
    // Raw player response first: it uses the client recipe that still works.
    try {
      final raw = await YoutubeDownloader.rawPick(videoId, targetVideoItag, targetAudioItag);
      if (raw[0] != null) return [raw[0], raw[2]];
    } catch (_) {}
    // Same best-effort client chain used for downloads.
    final m = await YoutubeDownloader.getManifestBestEffort(videoId);
    final v = m.videoOnly.where((s) => s.tag.toString() == targetVideoItag).firstOrNull ??
        m.muxed.where((s) => s.tag.toString() == targetVideoItag).firstOrNull ??
        m.muxed.sortByVideoQuality().firstOrNull ??
        m.videoOnly.where((s) => s.videoCodec.toLowerCase().contains('avc')).sortByVideoQuality().firstOrNull;
    if (v == null) return List<String?>.filled(2, null);
    if (targetAudioItag != null) {
      final a = m.audioOnly.where((s) => s.tag.toString() == targetAudioItag).firstOrNull ??
          m.audioOnly.where((s) => s.container.name.toLowerCase() == 'mp4').sortByBitrate().lastOrNull;
      if (a == null) return List<String?>.filled(2, null);
      return [v.url.toString(), a.url.toString()];
    }
    return [v.url.toString(), null];
  }

  Future<List<DetectedMedia>> extractStreams(String url) async {
    final vId = extractVideoId(url);
    if (vId == null && !isYouTubeUrl(url)) return [];

    // Preferred: attested format list from the bundled extractor (port of the
    // poToken/BotGuard + nsig challenge). These URLs are the only ones the CDN
    // serves for adaptive (720p/1080p) streams.
    try {
      final items = await _buildItemsFromYtDlp(url, vId);
      if (items.isNotEmpty) {
        for (final item in items) {
          if (item.videoId != null) recordVideoId(item.url, item.videoId!);
        }
        return items;
      }
    } catch (e) {
      debugPrint('YoutubeGrabberService attested probe failed for $url: $e');
    }

    try {
      // Fallback: raw InnerTube (un-attested -> progressive 360p only).
      final items = await Isolate.run(() => _extractStreamsIsolated(vId ?? url));
      for (final item in items) {
        recordVideoId(item.url, item.videoId!);
        if (item.audioUrl != null) recordVideoId(item.audioUrl!, item.videoId!);
      }
      return items;
    } catch (e) {
      debugPrint('YoutubeGrabberService error extracting $url: $e');
      return [];
    }
  }

  /// Builds the grabber list from yt-dlp's formats: progressive muxed mp4,
  /// AAC audio, and adaptive AVC video (paired with that audio for remuxing).
  static Future<List<DetectedMedia>> _buildItemsFromYtDlp(String url, String? videoId) async {
    final (fmts, infoTitle) = await YtDlpMinter.instance.formatsWithTitle(url);
    if (fmts.isEmpty) return const [];
    final title = infoTitle ?? 'YouTube video';
    final items = <DetectedMedia>[];

    VideoFormat? audio;
    for (final f in fmts) {
      if ((f.url ?? '').isEmpty) continue;
      if (!(f.vcodec == null || f.vcodec == 'none')) continue;
      if ((f.acodec ?? 'none') == 'none') continue;
      if (audio == null || (f.tbr ?? 0) > (audio.tbr ?? 0)) audio = f;
    }

    // Progressive (video + audio in one file).
    final progressive = fmts
        .where((f) => (f.url ?? '').isNotEmpty &&
            f.height != null && (f.height ?? 0) > 0 &&
            f.vcodec != null && f.vcodec != 'none' &&
            f.acodec != null && f.acodec != 'none')
        .toList()
      ..sort((a, b) => (b.height ?? 0).compareTo(a.height ?? 0));
    for (final f in progressive) {
      items.add(DetectedMedia(
        url: f.url!,
        referer: 'https://www.youtube.com/watch?v=${videoId ?? ''}',
        title: title,
        quality: '${f.height}p',
        size: _sizeLabel(f.filesize),
        totalBytes: f.filesize ?? 0,
        format: (f.ext ?? 'mp4').toUpperCase(),
        type: 'video',
        videoId: videoId,
        videoItag: f.formatId,
      ));
    }

    if (audio != null) {
      items.add(DetectedMedia(
        url: audio.url!,
        referer: 'https://www.youtube.com/watch?v=${videoId ?? ''}',
        title: title,
        quality: 'Audio (M4A)',
        size: _sizeLabel(audio.filesize),
        totalBytes: audio.filesize ?? 0,
        format: 'M4A',
        type: 'audio',
        videoId: videoId,
        videoItag: audio.formatId,
      ));
    }

    // Adaptive AVC video, paired with the audio track.
    final adaptive = fmts
        .where((f) => (f.url ?? '').isNotEmpty &&
            f.height != null && (f.height ?? 0) > 0 &&
            f.vcodec != null && f.vcodec != 'none' &&
            (f.acodec == null || f.acodec == 'none') &&
            (f.ext ?? '') == 'mp4')
        .toList()
      ..sort((a, b) => (b.height ?? 0).compareTo(a.height ?? 0));
    final seen = <int>{};
    for (final f in adaptive) {
      final h = f.height!;
      if (!seen.add(h)) continue;
      final bytes = (f.filesize ?? 0) + (audio?.filesize ?? 0);
      items.add(DetectedMedia(
        url: f.url!,
        audioUrl: audio?.url,
        audioBytes: audio?.filesize ?? 0,
        audioItag: audio?.formatId,
        referer: 'https://www.youtube.com/watch?v=${videoId ?? ''}',
        title: title,
        quality: '${h}p',
        size: _sizeLabel(bytes),
        totalBytes: bytes,
        format: 'MP4',
        type: 'video',
        videoId: videoId,
        videoItag: f.formatId,
      ));
    }

    return items;
  }

  static String _sizeLabel(int? bytes) =>
      (bytes ?? 0) > 0 ? '${((bytes ?? 0) / 1048576).toStringAsFixed(1)} MB' : '';

  /// Runs inside a background isolate: fetches video meta + manifest and
  /// builds the media list. DetectedMedia is a plain immutable class, so it
  /// transfers cleanly across the isolate boundary.
  static Future<List<DetectedMedia>> _extractStreamsIsolated(String urlOrId) async {
    final videoId = urlOrId.length == 11 ? urlOrId : extractVideoId(urlOrId);
    if (videoId == null) return const [];
    final yt = YoutubeExplode();
    try {
      String title = 'YouTube video';
      try {
        title = (await yt.videos.get(videoId).timeout(const Duration(seconds: 12))).title.trim();
      } catch (_) {}
      final referer = 'https://www.youtube.com/watch?v=$videoId';

      final fmts = await YoutubeDownloader.rawFormats(videoId);
      if (fmts.isEmpty) return const [];
      final items = <DetectedMedia>[];

      // Progressive muxed MP4 (17/18/22) downloads in one fast request and is
      // exempt from the CDN's per-URL 8 MB adaptive quota - always offer it.
      for (final itag in const ['22', '18', '17']) {
        Map<String, dynamic>? f;
        for (final x in fmts) {
          if (x['itag'] == itag) { f = x; break; }
        }
        if (f == null) continue;
        final bytes = f['clen'] as int? ?? 0;
        final quality = switch (itag) { '22' => '720p', '18' => '360p', _ => '144p' };
        items.add(DetectedMedia(
          url: f['url'] as String,
          referer: referer,
          title: title,
          quality: quality,
          size: bytes > 0 ? '${(bytes / 1048576).toStringAsFixed(1)} MB' : '',
          totalBytes: bytes,
          format: 'MP4',
          type: 'video',
          videoId: videoId,
          videoItag: itag,
        ));
      }

      // Audio-only (m4a) is small enough to fit the adaptive quota.
      final bestAudio = fmts
          .where((x) => (x['mime'] as String) == 'audio/mp4')
          .toList()
        ..sort((a, b) => (b['clen'] as int).compareTo(a['clen'] as int));
      final audio = bestAudio.isNotEmpty ? bestAudio.first : null;
      if (audio != null) {
        final bytes = audio['clen'] as int? ?? 0;
        items.add(DetectedMedia(
          url: audio['url'] as String,
          referer: referer,
          title: title,
          quality: 'Audio (M4A)',
          size: bytes > 0 ? '${(bytes / 1048576).toStringAsFixed(1)} MB' : '',
          totalBytes: bytes,
          format: 'M4A',
          type: 'audio',
          videoId: videoId,
          videoItag: audio['itag'] as String,
        ));
      }

      // Adaptive AVC video paired with that audio (remuxed by the engine).
      // This is where 720p/1080p actually come from - YouTube no longer ships
      // a progressive 720p stream for most videos.
      if (audio != null) {
        final audioBytes = audio['clen'] as int? ?? 0;
        final progressives = items.map((i) => i.videoItag).toSet();
        final video = fmts
            .where((x) => (x['mime'] as String) == 'video/mp4')
            .where((x) => (x['height'] as int? ?? 0) > 0)
            .where((x) => x['url'] != null)
            .toList()
          ..sort((a, b) => (b['height'] as int).compareTo(a['height'] as int));
        final seenHeights = <int>{};
        for (final f in video) {
          final itag = f['itag'] as String;
          if (progressives.contains(itag)) continue;
          final h = f['height'] as int;
          if (!seenHeights.add(h)) continue;
          final bytes = (f['clen'] as int? ?? 0) + audioBytes;
          final fps = (f['fps'] as int? ?? 0) >= 50 ? '60' : '';
          items.add(DetectedMedia(
            url: f['url'] as String,
            audioUrl: audio['url'] as String,
            audioBytes: audioBytes,
            audioItag: audio['itag'] as String,
            referer: referer,
            title: title,
            quality: '${h}p$fps',
            size: bytes > 0 ? '${(bytes / 1048576).toStringAsFixed(1)} MB' : '',
            totalBytes: bytes,
            format: 'MP4',
            type: 'video',
            videoId: videoId,
            videoItag: itag,
          ));
        }
      }

      return items;
    } catch (e) {
      debugPrint('YoutubeGrabberService extract failed for $videoId: $e');
      return const [];
    } finally {
      yt.close();
    }
  }
}
