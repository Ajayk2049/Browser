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

  Future<List<DetectedMedia>> extractStreams(String url) async {
    if (!isYouTubeUrl(url)) return [];
    final yt = YoutubeExplode();
    try {
      final video = await yt.videos.get(url);
      final manifest = await yt.videos.streamsClient.getManifest(video.id);
      final List<DetectedMedia> items = [];
      final seenVideo = <String>{};

      // 1. Muxed streams (both video + audio in MP4/WebM)
      for (final stream in manifest.muxed.sortByVideoQuality()) {
        final res = stream.videoQualityLabel;
        final tag = stream.container.name.toUpperCase();
        final key = '${res}_$tag';
        if (seenVideo.contains(key)) continue;
        seenVideo.add(key);
        final mb = stream.size.totalMegaBytes.toStringAsFixed(1);
        items.add(DetectedMedia(
          url: stream.url.toString(),
          title: video.title.trim(),
          quality: res,
          size: '$mb MB',
          totalBytes: stream.size.totalBytes,
          format: tag,
          type: 'video',
        ));
      }

      // 2. Video-only streams (include 1080p, 720p, 480p, etc. if no muxed exists)
      for (final stream in manifest.videoOnly.sortByVideoQuality()) {
        final res = stream.videoQualityLabel;
        final tag = stream.container.name.toUpperCase();
        final key = '${res}_$tag';
        if (seenVideo.contains(key)) continue;
        seenVideo.add(key);
        final mb = stream.size.totalMegaBytes.toStringAsFixed(1);
        items.add(DetectedMedia(
          url: stream.url.toString(),
          title: video.title.trim(),
          quality: '$res (Video only)',
          size: '$mb MB',
          totalBytes: stream.size.totalBytes,
          format: tag,
          type: 'video',
        ));
      }

      // 3. Audio only (MP4/M4A/WebM)
      final seenAudio = <String>{};
      for (final stream in manifest.audioOnly.sortByBitrate()) {
        final kbps = stream.bitrate.kiloBitsPerSecond.round();
        final tag = stream.container.name.toUpperCase();
        final key = '${kbps}_$tag';
        if (seenAudio.contains(key)) continue;
        seenAudio.add(key);
        final mb = stream.size.totalMegaBytes.toStringAsFixed(1);
        items.add(DetectedMedia(
          url: stream.url.toString(),
          title: video.title.trim(),
          quality: '$kbps kbps',
          size: '$mb MB',
          totalBytes: stream.size.totalBytes,
          format: tag,
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
