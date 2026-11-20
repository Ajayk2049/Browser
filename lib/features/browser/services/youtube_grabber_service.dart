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

      // 1. Muxed streams (both video + audio in MP4/WebM)
      for (final stream in manifest.muxed.sortByVideoQuality()) {
        final mb = stream.size.totalMegaBytes.toStringAsFixed(1);
        final tag = stream.container.name.toUpperCase();
        items.add(DetectedMedia(
          url: stream.url.toString(),
          title: video.title.trim(),
          quality: stream.videoQualityLabel,
          size: '$mb MB',
          format: tag,
          type: 'video',
        ));
      }

      // 2. High-res video only (1080p, 1440p, 4K)
      for (final stream in manifest.videoOnly.sortByVideoQuality()) {
        if (stream.videoResolution.height > 720) {
          final mb = stream.size.totalMegaBytes.toStringAsFixed(1);
          final tag = stream.container.name.toUpperCase();
          items.add(DetectedMedia(
            url: stream.url.toString(),
            title: video.title.trim(),
            quality: '${stream.videoQualityLabel} (Video only)',
            size: '$mb MB',
            format: tag,
            type: 'video',
          ));
        }
      }

      // 3. Audio only (MP4/M4A/WebM)
      for (final stream in manifest.audioOnly.sortByBitrate()) {
        final mb = stream.size.totalMegaBytes.toStringAsFixed(1);
        final kbps = stream.bitrate.kiloBitsPerSecond.round();
        final tag = stream.container.name.toUpperCase();
        items.add(DetectedMedia(
          url: stream.url.toString(),
          title: video.title.trim(),
          quality: '$kbps kbps',
          size: '$mb MB',
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
