import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'youtube_downloader.dart';
import '../widgets/media_grabber_sheet.dart';

/// Resolves direct YouTube streams via Snaptube's multi-client InnerTube recipe
/// (IOS_API, VISIONOS, ANDROID_VR, ANDROID) + BotGuard PoToken.
/// Complies with rules.md §13, §26.5, §29.2 (< 250 lines).
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
      final tokens = await YoutubeDownloader.fetchSessionTokens(videoId);
      final picked = await Isolate.run(
        () => YoutubeDownloader.resolveWithTokens(
          videoId, targetVideoItag, targetAudioItag, tokens.visitorData, tokens.poToken,
        ),
      );
      if (picked[0] == null) {
        debugPrint('[DLREFRESH] itag $targetVideoItag not found in refreshed manifest');
        return null;
      }
      return (videoUrl: picked[0]!, audioUrl: picked[2]);
    } catch (e) {
      debugPrint('[DLREFRESH] Error refreshing streams for $videoId: $e');
      return null;
    }
  }

  Future<List<DetectedMedia>> extractStreams(String url) async {
    final vId = extractVideoId(url);
    if (vId == null && !isYouTubeUrl(url)) return [];
    final targetId = vId ?? url;
    try {
      final tokens = await YoutubeDownloader.fetchSessionTokens(targetId);
      final items = await Isolate.run(
        () => _extractStreamsIsolated(targetId, tokens.visitorData, tokens.poToken),
      );
      for (final item in items) {
        if (item.videoId != null) {
          recordVideoId(item.url, item.videoId!);
          if (item.audioUrl != null) recordVideoId(item.audioUrl!, item.videoId!);
        }
      }
      return items;
    } catch (e) {
      debugPrint('YoutubeGrabberService error extracting $url: $e');
      return [];
    }
  }

  static String _sizeLabel(int? bytes) =>
      (bytes ?? 0) > 0 ? '${((bytes ?? 0) / 1048576).toStringAsFixed(1)} MB' : '';

  static Future<List<DetectedMedia>> _extractFromManifest(String videoId, String title) async {
    final m = await YoutubeDownloader.getManifestBestEffort(videoId);
    final referer = 'https://www.youtube.com/watch?v=$videoId';
    final items = <DetectedMedia>[];

    final muxed = m.muxed.sortByVideoQuality().lastOrNull;
    if (muxed != null) {
      final bytes = muxed.size.totalBytes;
      items.add(DetectedMedia(
        url: muxed.url.toString(), referer: referer, title: title,
        quality: '${muxed.videoResolution.height}p',
        size: _sizeLabel(bytes), totalBytes: bytes,
        format: 'MP4', type: 'video', videoId: videoId, videoItag: muxed.tag.toString(),
      ));
    }

    final audio = m.audioOnly
            .where((s) => s.container.name.toLowerCase() == 'mp4')
            .sortByBitrate()
            .lastOrNull ??
        m.audioOnly.sortByBitrate().lastOrNull;
    if (audio != null) {
      final bytes = audio.size.totalBytes;
      items.add(DetectedMedia(
        url: audio.url.toString(), referer: referer, title: title,
        quality: 'Audio (M4A)', size: _sizeLabel(bytes), totalBytes: bytes,
        format: 'M4A', type: 'audio', videoId: videoId, videoItag: audio.tag.toString(),
      ));
    }

    final avcVideos = m.videoOnly
        .where((s) => s.videoCodec.toLowerCase().contains('avc'))
        .toList()
      ..sort((a, b) => b.videoResolution.height.compareTo(a.videoResolution.height));
    final seenHeights = <int>{};
    for (final v in avcVideos) {
      final h = v.videoResolution.height;
      if (!seenHeights.add(h)) continue;
      final bytes = v.size.totalBytes + (audio?.size.totalBytes ?? 0);
      items.add(DetectedMedia(
        url: v.url.toString(),
        audioUrl: audio?.url.toString(), audioBytes: audio?.size.totalBytes ?? 0,
        audioItag: audio?.tag.toString(),
        referer: referer, title: title, quality: '${h}p',
        size: _sizeLabel(bytes), totalBytes: bytes,
        format: 'MP4', type: 'video', videoId: videoId, videoItag: v.tag.toString(),
      ));
    }
    return items;
  }

  static Future<List<DetectedMedia>> _extractStreamsIsolated(
    String urlOrId,
    String visitorData,
    String? poToken,
  ) async {
    final videoId = urlOrId.length == 11 ? urlOrId : extractVideoId(urlOrId);
    if (videoId == null) return const [];
    final yt = YoutubeExplode();
    var title = 'YouTube video';
    try {
      title = (await yt.videos.get(videoId).timeout(const Duration(seconds: 10))).title.trim();
    } catch (_) {} finally {
      yt.close();
    }

    final referer = 'https://www.youtube.com/watch?v=$videoId';
    List<Map<String, dynamic>> fmts;
    try {
      fmts = await YoutubeDownloader.rawFormats(videoId, visitorData: visitorData, poToken: poToken);
    } catch (_) {
      fmts = const [];
    }
    if (fmts.isEmpty) return _extractFromManifest(videoId, title);

    final items = <DetectedMedia>[];

    // Progressive muxed MP4 (itag 22 / 18 / 17): single file, no native mux needed.
    for (final itag in const ['22', '18', '17']) {
      final f = fmts.where((x) => x['itag'] == itag).firstOrNull;
      if (f == null) continue;
      final bytes = f['clen'] as int? ?? 0;
      final quality = switch (itag) { '22' => '720p', '18' => '360p', _ => '144p' };
      items.add(DetectedMedia(
        url: f['url'] as String, referer: referer, title: title, quality: quality,
        size: _sizeLabel(bytes), totalBytes: bytes, format: 'MP4', type: 'video',
        videoId: videoId, videoItag: itag,
      ));
    }

    // Audio-only (AAC M4A) — prefer 140 / highest bitrate audio/mp4.
    final bestAudio = fmts.where((x) => (x['mime'] as String) == 'audio/mp4').toList()
      ..sort((a, b) => (b['clen'] as int).compareTo(a['clen'] as int));
    final audio = bestAudio.isNotEmpty ? bestAudio.first : null;
    if (audio != null) {
      final bytes = audio['clen'] as int? ?? 0;
      items.add(DetectedMedia(
        url: audio['url'] as String, referer: referer, title: title,
        quality: 'Audio (M4A)', size: _sizeLabel(bytes), totalBytes: bytes,
        format: 'M4A', type: 'audio', videoId: videoId, videoItag: audio['itag'] as String,
      ));
    }

    // Adaptive H.264/AVC video paired with AAC audio for native MediaMuxerHelper.
    // Strictly excludes AV1 (av01) and VP9 so pre-Android 14 MediaMuxer never fails.
    if (audio != null) {
      final audioBytes = audio['clen'] as int? ?? 0;
      final progressives = items.map((i) => i.videoItag).toSet();
      final video = fmts
          .where((x) => x['muxed'] != true && YoutubeDownloader.isMuxableAvc(x))
          .where((x) => (x['height'] as int? ?? 0) > 0 && x['url'] != null)
          .toList()
        ..sort((a, b) {
          final hc = (b['height'] as int).compareTo(a['height'] as int);
          if (hc != 0) return hc;
          final fc = (b['fps'] as int).compareTo(a['fps'] as int);
          return fc != 0 ? fc : (b['clen'] as int).compareTo(a['clen'] as int);
        });
      final seenKeys = <String>{};
      for (final f in video) {
        final itag = f['itag'] as String;
        if (progressives.contains(itag)) continue;
        final h = f['height'] as int;
        final fps = (f['fps'] as int? ?? 0) >= 50 ? '60' : '';
        if (!seenKeys.add('$h:$fps')) continue;
        final bytes = (f['clen'] as int? ?? 0) + audioBytes;
        items.add(DetectedMedia(
          url: f['url'] as String,
          audioUrl: audio['url'] as String, audioBytes: audioBytes, audioItag: audio['itag'] as String,
          referer: referer, title: title, quality: '${h}p$fps',
          size: _sizeLabel(bytes), totalBytes: bytes, format: 'MP4', type: 'video',
          videoId: videoId, videoItag: itag,
        ));
      }
    }
    return items;
  }
}
