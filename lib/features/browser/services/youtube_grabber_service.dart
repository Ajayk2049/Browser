import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../downloads/services/yt_dlp_service.dart';
import 'youtube_downloader.dart';
import '../widgets/media_grabber_sheet.dart';

/// Helper service utilizing youtube_explode_dart to resolve direct
/// media streams from any YouTube URL for 1DM downloading.
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

    // Preferred: the bundled yt-dlp extractor. It tracks YouTube's signature /
    // poToken changes, lists every quality (up to 4K) and merges A+V itself.
    try {
      final viaYtDlp = await YtDlpService.instance.probe(url, videoId: vId);
      if (viaYtDlp.isNotEmpty) {
        for (final item in viaYtDlp) {
          if (item.videoId != null) recordVideoId(item.url, item.videoId!);
        }
        return viaYtDlp;
      }
    } catch (e) {
      debugPrint('YoutubeGrabberService yt-dlp probe failed for $url: $e');
    }

    try {
      // Heavy YouTube player JSON parsing runs off the main isolate
      // to avoid jank while the browser UI is rendering.
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

      // Only muxed progressive MP4 is offered: YouTube's CDN 403s adaptive
      // streams for non-player clients, so listing them produced endless
      // "refreshing links" loops. Progressive downloads complete reliably.
      final prog = await YoutubeDownloader.rawProgressive(videoId);
      if (prog[0] == null) return const [];
      final bytes = int.tryParse(prog[1] ?? '0') ?? 0;
      final itag = prog[2] ?? '18';
      final quality = switch (itag) { '22' => '720p', '18' => '360p', '17' => '144p', _ => '360p' };
      return [
        DetectedMedia(
          url: prog[0]!,
          referer: 'https://www.youtube.com/watch?v=$videoId',
          title: title,
          quality: quality,
          size: '${(bytes / 1048576).toStringAsFixed(1)} MB',
          totalBytes: bytes,
          format: 'MP4',
          type: 'video',
          videoId: videoId,
          videoItag: itag,
        ),
      ];
    } catch (e) {
      debugPrint('YoutubeGrabberService extract failed for $videoId: $e');
      return const [];
    } finally {
      yt.close();
    }
  }
}
