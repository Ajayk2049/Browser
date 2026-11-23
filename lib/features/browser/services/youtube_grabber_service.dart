import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
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
    final yt = YoutubeExplode();
    try {
      final manifest = await yt.videos.streamsClient.getManifest(videoId).timeout(const Duration(seconds: 15));
      final videoStream = manifest.videoOnly.where((s) => s.tag.toString() == targetVideoItag).firstOrNull ??
          manifest.muxed.where((s) => s.tag.toString() == targetVideoItag).firstOrNull;
      if (videoStream == null) {
        debugPrint('[DLREFRESH] itag $targetVideoItag not found in refreshed manifest');
        return null;
      }
      String? audioUrl;
      if (targetAudioItag != null) {
        final audioStream = manifest.audioOnly.where((s) => s.tag.toString() == targetAudioItag).firstOrNull;
        if (audioStream == null) {
          debugPrint('[DLREFRESH] audio itag $targetAudioItag not found in refreshed manifest');
          return null;
        }
        audioUrl = audioStream.url.toString();
      }
      return (videoUrl: videoStream.url.toString(), audioUrl: audioUrl);
    } catch (e) {
      debugPrint('[DLREFRESH] Error refreshing streams for $videoId: $e');
      return null;
    } finally {
      yt.close();
    }
  }

  Future<List<DetectedMedia>> extractStreams(String url) async {
    final vId = extractVideoId(url);
    if (vId == null && !isYouTubeUrl(url)) return [];
    final yt = YoutubeExplode();
    try {
      final video = await yt.videos.get(vId ?? url).timeout(const Duration(seconds: 15));
      final manifest = await yt.videos.streamsClient.getManifest(video.id).timeout(const Duration(seconds: 15));
      final List<DetectedMedia> items = [];
      final seenVideo = <String>{};

      // Best M4A/AAC audio stream for muxing
      final aacStreams = manifest.audioOnly
          .where((s) => s.container.name.toLowerCase() == 'mp4' || s.codec.mimeType.contains('mp4') || s.codec.mimeType.contains('aac'))
          .sortByBitrate();
      final bestAudio = aacStreams.isNotEmpty ? aacStreams.last : null;

      // 1. Muxed streams (both video + audio in MP4, omit WebM)
      for (final stream in manifest.muxed.sortByVideoQuality()) {
        if (stream.container.name.toLowerCase() != 'mp4') continue;
        final res = stream.videoQualityLabel;
        final key = '${res}_MP4';
        if (seenVideo.contains(key)) continue;
        seenVideo.add(key);
        final mb = stream.size.totalMegaBytes.toStringAsFixed(1);
        final streamUrl = stream.url.toString();
        recordVideoId(streamUrl, video.id.value);
        items.add(DetectedMedia(
          url: streamUrl,
          referer: 'https://www.youtube.com/watch?v=${video.id.value}',
          title: video.title.trim(),
          quality: res,
          size: '$mb MB',
          totalBytes: stream.size.totalBytes,
          format: 'MP4',
          type: 'video',
        ));
      }

      // 2. Adaptive video streams (1080p, 720p, 480p, etc. MP4 only, paired with audio for native muxing)
      if (bestAudio != null) {
        for (final stream in manifest.videoOnly.sortByVideoQuality()) {
          if (stream.container.name.toLowerCase() != 'mp4') continue;
          final res = stream.videoQualityLabel;
          final key = '${res}_MP4';
          if (seenVideo.contains(key)) continue;
          seenVideo.add(key);
          final totalBytes = stream.size.totalBytes + bestAudio.size.totalBytes;
          final mb = (totalBytes / 1048576).toStringAsFixed(1);
          final streamUrl = stream.url.toString();
          recordVideoId(streamUrl, video.id.value);
          if (bestAudio != null) recordVideoId(bestAudio.url.toString(), video.id.value);
          items.add(DetectedMedia(
            url: streamUrl,
            audioUrl: bestAudio.url.toString(),
            audioBytes: bestAudio.size.totalBytes,
            referer: 'https://www.youtube.com/watch?v=${video.id.value}',
            title: video.title.trim(),
            quality: res,
            size: '$mb MB',
            totalBytes: totalBytes,
            format: 'MP4',
            type: 'video',
          ));
        }
      }

      // 3. Audio only (MP4 / M4A only, omit WebM)
      final seenAudio = <String>{};
      for (final stream in manifest.audioOnly.sortByBitrate()) {
        if (stream.container.name.toLowerCase() != 'mp4') continue;
        final kbps = stream.bitrate.kiloBitsPerSecond.round();
        final key = '${kbps}_M4A';
        if (seenAudio.contains(key)) continue;
        seenAudio.add(key);
        final mb = stream.size.totalMegaBytes.toStringAsFixed(1);
        items.add(DetectedMedia(
          url: stream.url.toString(),
          referer: 'https://www.youtube.com/watch?v=${video.id.value}',
          title: video.title.trim(),
          quality: '$kbps kbps',
          size: '$mb MB',
          totalBytes: stream.size.totalBytes,
          format: 'M4A',
          type: 'audio',
        ));
      }

      return items;
    } catch (e) {
      debugPrint('YoutubeGrabberService error extracting $url: $e');
      return [];
    } finally {
      yt.close();
    }
  }
}
