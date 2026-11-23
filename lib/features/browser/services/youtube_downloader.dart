import 'dart:isolate';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Resolves fresh YouTube stream URLs off the main isolate.
/// Manifest fetching parses large player JSON — it must never run on the
/// UI isolate (frame skips / low-memory kills).
/// Complies with rules.md §13, §26.5, §29.2.
class YoutubeDownloader {
  static final YoutubeDownloader instance = YoutubeDownloader._();
  YoutubeDownloader._();

  /// Manifest client sets, best-first. androidVr serves multi-use URLs
  /// (the default androidSdkless URLs 403 on second use); tv covers
  /// restricted videos; the library default is the last resort so listing
  /// keeps working even when the newer clients fail for a given video.
  static final List<List<YoutubeApiClient>?> clientSets = [
    [YoutubeApiClient.androidVr],
    [YoutubeApiClient.androidVr, YoutubeApiClient.tv],
    [YoutubeApiClient.tv],
    null, // library default (androidSdkless)
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

  static Future<List<String?>> _resolve(String videoId, String videoItag, String? audioItag) async {
    Object? lastErr;
    for (final clients in clientSets) {
      try {
        final m = await _getManifest(videoId, clients);
        final picked = _pickStreams(m, videoItag, audioItag);
        if (picked[0] != null) return picked;
      } catch (e) { lastErr = e; }
    }
    throw lastErr ?? 'Stream resolution failed';
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
