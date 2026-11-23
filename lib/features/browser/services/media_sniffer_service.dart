import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../widgets/media_grabber_sheet.dart';
import 'youtube_grabber_service.dart';

/// A media stream URL observed by the bundled media-sniffer extension while
/// the page's own player was actively using it. These URLs are minted by the
/// real player session (attested), so they are the most reliable download
/// source — unlike URLs re-derived from third-party API clients, which
/// YouTube's CDN now 403s for non-player traffic.
class SniffedMedia {
  final String url, pageUrl, itag, mime;
  const SniffedMedia({required this.url, required this.pageUrl, required this.itag, required this.mime});

  String? get videoId => YoutubeGrabberService.extractVideoId(pageUrl);
  bool get isVideo => mime.startsWith('video/');
  bool get isAudio => mime.startsWith('audio/');
}

/// Receives sniffed stream URLs from the native extension bridge and turns
/// them into grabber-ready media items (AVC video paired with best M4A audio).
/// Complies with rules.md §13, §26.5, §29.2.
class MediaSnifferService {
  static final MediaSnifferService instance = MediaSnifferService._();
  MediaSnifferService._() {
    // Registered by WebExtensionService when 'onSniffedMedia' arrives.
  }

  /// AVC/H.264 video itags (muxable by the native MediaMuxer pipeline).
  static const Map<String, String> avcVideoItags = {
    '17': '144p', '18': '360p', '22': '720p',
    '133': '240p', '134': '360p', '135': '480p', '136': '720p', '137': '1080p',
    '264': '1440p', '298': '720p60', '299': '1080p60',
  };

  /// M4A/AAC audio itags (muxable). Opus/Vorbis (webm) are rejected.
  static const Set<String> m4aAudioItags = {'139', '140', '141', '256', '258'};

  final Map<String, Map<String, SniffedMedia>> _byVideo = {};
  final StreamController<SniffedMedia> _ctrl = StreamController<SniffedMedia>.broadcast();
  Stream<SniffedMedia> get stream => _ctrl.stream;

  void handleNativeCall(MethodCall call) {
    final args = Map<dynamic, dynamic>.from(call.arguments as Map? ?? {});
    final url = args['url'] as String? ?? '';
    final itag = args['itag'] as String? ?? '';
    if (url.isEmpty || itag.isEmpty) return;
    final m = SniffedMedia(
      url: url,
      pageUrl: args['pageUrl'] as String? ?? '',
      itag: itag,
      mime: args['mime'] as String? ?? '',
    );
    final vid = m.videoId;
    if (vid == null) return;
    final known = avcVideoItags.containsKey(itag) || m4aAudioItags.contains(itag);
    if (!known) return; // VP9/AV1/webm audio can't be muxed by the native pipeline.
    debugPrint('[SNIFF] itag=$itag mime=${m.mime} video=$vid');
    _byVideo.putIfAbsent(vid, () => {});
    _byVideo[vid]![itag] = m; // newest URL per itag wins (fresh = playable)
    _ctrl.add(m);
  }

  void clearFor(String videoId) => _byVideo.remove(videoId);

  /// Grabber items for [videoId]: each AVC video paired with the best sniffed
  /// M4A audio track, plus the audio-only option. Empty when nothing sniffed.
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
