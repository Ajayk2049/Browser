import 'dart:async';
import 'dart:io';

import 'package:extractor/extractor.dart';
import 'package:flutter/foundation.dart';

import '../../browser/widgets/media_grabber_sheet.dart';

/// YouTube (and other yt-dlp-supported sites) download engine.
///
/// YouTube's direct stream URLs are unusable for third-party clients on many
/// networks (CDN 403s, SABR-only web player), tracked and re-broken by YouTube
/// every few weeks. Rather than reimplementing that arms race, this delegates
/// to the bundled yt-dlp extractor - the same engine NewPipe/yt-dlp users rely
/// on - and keeps the app's own native engine for plain HTTP downloads.
class YtDlpService {
  static final YtDlpService instance = YtDlpService._();
  YtDlpService._();

  final YoutubeDLFlutter _yt = YoutubeDLFlutter.instance;
  Future<bool>? _init;

  /// Resolves once yt-dlp/ffmpeg binaries are unpacked (first call is slow).
  Future<bool> ensureReady() => _init ??= _initialize();

  Future<bool> _initialize() async {
    try {
      final res = await _yt.initialize(enableFFmpeg: true);
      if (!res.success) {
        debugPrint('[YTDLP] init failed: ${res.errorMessage}');
        _init = null;
        return false;
      }
      try {
        final v = await _yt.getVersion();
        debugPrint('[YTDLP] ready yt-dlp=${v.youtubeDlVersion} ffmpeg=${v.ffmpegVersion} python=${v.pythonVersion}');
      } catch (_) {
        debugPrint('[YTDLP] ready (version unknown)');
      }
      // YouTube's SABR/extractor changes are only handled by current yt-dlp
      // releases, so refresh the bundled build in the background.
      unawaited(_refreshInBackground());
      return true;
    } catch (e) {
      debugPrint('[YTDLP] init error: $e');
      _init = null;
      return false;
    }
  }

  bool _refreshing = false;
  bool _updateChecked = false;

  /// yt-dlp releases that understand YouTube's SABR-only clients.
  static const _minYtDlpVersion = '2026.11.23';

  Future<void> _refreshInBackground() async {
    if (_refreshing || _updateChecked) return;
    _refreshing = true;
    _updateChecked = true;
    try {
      final v = await _yt.getVersion();
      final current = _dateOf(v.youtubeDlVersion);
      if (current != null && current.compareTo(_minYtDlpVersion) >= 0) {
        _refreshing = false;
        return;
      }
      final r = await _yt.updateYoutubeDL(channel: UpdateChannel.stable);
      if (r.status == OperationStatus.success) {
        debugPrint('[YTDLP] updated to ${r.version}');
      } else {
        debugPrint('[YTDLP] update failed: ${r.errorMessage}');
      }
    } catch (e) {
      debugPrint('[YTDLP] update error: $e');
    } finally {
      _refreshing = false;
    }
  }

  static String? _dateOf(String? version) {
    final m = RegExp(r'(\d{4})\.(\d{2})\.(\d{2})').firstMatch(version ?? '');
    return m == null ? null : '${m.group(1)}.${m.group(2)}.${m.group(3)}';
  }

  /// Lists downloadable formats for [url]. Empty when yt-dlp can't handle it,
  /// in which case callers fall back to the InnerTube resolver.
  Future<List<DetectedMedia>> probe(String url, {String? videoId, String? title}) async {
    if (!await ensureReady()) return const [];
    try {
      final info = await _yt.getVideoInfo(url);
      final formats = (info.formats ?? const <VideoFormat?>[]).whereType<VideoFormat>().toList();
      if (formats.isEmpty) return const [];
      final resolvedTitle = (title ?? info.title ?? 'Video').trim();
      final resolvedId = videoId ?? info.id ?? '';
      final durationSec = info.duration ?? 0;
      final items = <DetectedMedia>[];

      int bytesOf(VideoFormat f) {
        final known = f.filesize ?? 0;
        if (known > 0) return known;
        final tbr = f.tbr ?? 0; // kbit/s
        if (tbr > 0 && durationSec > 0) return (tbr * 1000 / 8 * durationSec).round();
        return 0;
      }

      // Best format per resolution (yt-dlp merges audio with "+bestaudio").
      final byHeight = <int, VideoFormat>{};
      for (final f in formats) {
        if (f.formatId == null || f.vcodec == null || f.vcodec == 'none') continue;
        final h = f.height ?? 0;
        if (h <= 0) continue;
        final cur = byHeight[h];
        if (cur == null || _rank(f) > _rank(cur)) byHeight[h] = f;
      }
      final heights = byHeight.keys.toList()..sort((a, b) => b.compareTo(a));
      for (final h in heights.take(6)) {
        final f = byHeight[h]!;
        final muxed = f.acodec != null && f.acodec != 'none';
        final selector = muxed ? '${f.formatId}/best' : '${f.formatId}+bestaudio/best';
        final bytes = bytesOf(f);
        final exact = (f.filesize ?? 0) > 0;
        final sizeLabel = bytes > 0
            ? '${exact ? '' : '~'}${(bytes / 1048576).toStringAsFixed(1)} MB'
            : '';
        items.add(DetectedMedia(
          url: url,
          referer: url,
          title: resolvedTitle,
          quality: _qualityLabel(f),
          size: sizeLabel,
          totalBytes: bytes,
          format: (f.ext ?? 'mp4').toUpperCase(),
          type: 'video',
          videoId: resolvedId,
          videoItag: selector,
        ));
      }

      // Best audio-only formats.
      final audio = formats
          .where((f) => f.formatId != null && (f.vcodec == null || f.vcodec == 'none') && f.acodec != null && f.acodec != 'none')
          .toList()
        ..sort((a, b) => (b.tbr ?? 0).compareTo(a.tbr ?? 0));
      for (final f in audio.take(2)) {
        final bytes = bytesOf(f);
        final exact = (f.filesize ?? 0) > 0;
        items.add(DetectedMedia(
          url: url,
          referer: url,
          title: resolvedTitle,
          quality: f.formatNote ?? 'Audio',
          size: bytes > 0
              ? '${exact ? '' : '~'}${(bytes / 1048576).toStringAsFixed(1)} MB'
              : '',
          totalBytes: bytes,
          format: 'M4A',
          type: 'audio',
          videoId: resolvedId,
          videoItag: '${f.formatId}/bestaudio/best',
        ));
      }
      debugPrint('[YTDLP] probe ok formats=${formats.length} items=${items.length} title=$resolvedTitle');
      return items;
    } catch (e) {
      debugPrint('[YTDLP] probe failed: $e');
      return const [];
    }
  }

  static double _rank(VideoFormat f) =>
      (f.tbr ?? 0) + (f.fps ?? 0) * 10 + ((f.acodec != null && f.acodec != 'none') ? 1 : 0);

  static String _qualityLabel(VideoFormat f) {
    final h = f.height ?? 0;
    final fps = (f.fps ?? 0) >= 50 ? '60' : '';
    if (h > 0) return '${h}p$fps';
    return f.formatNote ?? 'Video';
  }

  /// Downloads into the folder of [destinationPath], keeping the chosen file
  /// name (yt-dlp appends the real container extension).
  /// Returns the final file path, or null on failure.
  Future<String?> download({
    required String taskId,
    required String url,
    required String destinationPath,
    required String? formatSelector,
    required bool audioOnly,
  }) async {
    if (!await ensureReady()) return null;
    final sep = destinationPath.lastIndexOf(RegExp(r'[\\/]'));
    final dir = sep > 0 ? destinationPath.substring(0, sep) : destinationPath;
    var name = sep > 0 ? destinationPath.substring(sep + 1) : destinationPath;
    final dot = name.lastIndexOf('.');
    if (dot > 0) name = name.substring(0, dot);
    final template = name.isEmpty ? '%(title).120s.%(ext)s' : '$name.%(ext)s';

    try {
      final request = DownloadRequest(
        url: url,
        outputPath: dir,
        outputTemplate: template,
        processId: taskId,
        format: audioOnly ? (formatSelector ?? 'bestaudio/best') : (formatSelector ?? 'bestvideo+bestaudio/best'),
        noPlaylist: true,
        extractAudio: audioOnly,
        audioFormat: audioOnly ? 'm4a' : null,
        embedMetadata: false,
        customOptions: audioOnly ? null : const {'--merge-output-format': 'mp4'},
      );
      final result = await _yt.download(request);
      if (result.status != OperationStatus.success) {
        debugPrint('[YTDLP] download failed: ${result.errorMessage}');
        return null;
      }
      final resolved = await _resolveOutput(dir, name, result.outputPath);
      debugPrint('[YTDLP] download done: raw=${result.outputPath} resolved=$resolved');
      return resolved;
    } catch (e) {
      debugPrint('[YTDLP] download error: $e');
      return null;
    }
  }

  /// The plugin sometimes reports the unexpanded output template, so fall back
  /// to the newest matching file in the destination folder. Also clears the
  /// intermediate `.part` / `.fNNN` files yt-dlp leaves behind.
  Future<String?> _resolveOutput(String dir, String base, String? hint) async {
    final folder = Directory(dir);
    if (!await folder.exists()) return null;

    if (hint != null && hint.isNotEmpty && !hint.contains('%(ext)')) {
      final hinted = File(hint);
      if (await hinted.exists()) {
        await _cleanupTemp(folder, base);
        return hint;
      }
    }

    File? best;
    DateTime? bestTime;
    await for (final entity in folder.list()) {
      if (entity is! File) continue;
      final fileName = entity.path.split(RegExp(r'[\\/]')).last;
      if (base.isNotEmpty && !fileName.startsWith(base)) continue;
      if (fileName.endsWith('.part') || fileName.endsWith('.ytdl')) continue;
      if (RegExp(r'\.f\d+\.').hasMatch(fileName)) continue;
      try {
        final stat = await entity.stat();
        if (bestTime == null || stat.modified.isAfter(bestTime)) {
          best = entity;
          bestTime = stat.modified;
        }
      } catch (_) {}
    }
    await _cleanupTemp(folder, base);
    return best?.path;
  }

  Future<void> _cleanupTemp(Directory folder, String base) async {
    if (base.isEmpty) return;
    try {
      await for (final entity in folder.list()) {
        if (entity is! File) continue;
        final fileName = entity.path.split(RegExp(r'[\\/]')).last;
        if (!fileName.startsWith(base)) continue;
        if (fileName.endsWith('.part') || fileName.endsWith('.ytdl')) {
          await entity.delete();
        }
      }
    } catch (_) {}
  }

  Future<bool> cancel(String taskId) async {
    try {
      return await _yt.cancelDownload(taskId);
    } catch (_) {
      return false;
    }
  }

  Stream<DownloadProgress> get onProgress => _yt.onProgress;
  Stream<DownloadState> get onStateChanged => _yt.onStateChanged;
  Stream<DownloadError> get onError => _yt.onError;
}
