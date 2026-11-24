import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../browser/services/youtube_downloader.dart';
import '../../browser/services/youtube_grabber_service.dart';
import '../models/download_task.dart';

/// Platform channel wrapper providing control and progress streaming
/// for native Android downloads (YouTube included: fresh stream URLs are
/// resolved in a background isolate, then handed to the native engine).
/// Complies with rules.md §26.1, §26.5, §29.1, and §29.2 (< 250 lines).
class DownloadService {
  static const MethodChannel _methodChannel = MethodChannel('com.dab/downloader');
  static const EventChannel _eventChannel = EventChannel('com.dab/downloads/updates');
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;

  final StreamController<DownloadTask> _taskStreamCtrl = StreamController<DownloadTask>.broadcast();
  final Map<String, _YouTubePending> _ytPending = {};

  DownloadService._internal() {
    _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) => _taskStreamCtrl.add(DownloadTask.fromMap(Map<dynamic, dynamic>.from(event as Map))),
      onError: (dynamic error) => debugPrint('Native stream error: $error'),
    );
    _initLoggingSubscriber();
  }

  Stream<DownloadTask> get downloadUpdates => _taskStreamCtrl.stream;

  final Map<String, int> _refreshCounts = {};
  final Map<String, DateTime> _refreshingTasks = {};

  void _log(String msg) { debugPrint(msg); developer.log(msg, name: 'DLREFRESH'); }

  void _initLoggingSubscriber() {
    downloadUpdates.listen((task) {
      if (task.status == DownloadStatus.linkExpired) _handleLinkExpired(task);
      else if (task.status == DownloadStatus.completed || task.status == DownloadStatus.failed) _refreshCounts.remove(task.id);
      _log('[DLREFRESH] ${task.id}: ${task.status.name} ${task.progressPercentage} | ${task.speedFormatted}'
          '${task.errorMessage != null ? ' | err: ${task.errorMessage}' : ''}');
    });
  }

  /// Extracts (videoItag, audioItag) from the referer fragment we attach at
  /// task creation ("https://www.youtube.com/watch?v=ID#itag=VI:AI") so that
  /// link-refresh works even after an app restart.
  (String, String?)? _parseItagFragment(String? referer) {
    if (referer == null) return null;
    final uri = Uri.tryParse(referer);
    final frag = uri?.fragment;
    if (frag == null || !frag.startsWith('itag=')) return null;
    final parts = frag.substring(5).split(':');
    if (parts.isEmpty || parts[0].isEmpty) return null;
    return (parts[0], parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null);
  }

  /// YouTube serves only ~8 MB per URL for adaptive streams, so a long
  /// download needs a freshly minted URL every few megabytes. The engine
  /// signals LINK_EXPIRED when a link is exhausted; we hand it a new one and
  /// it resumes from the same offset.
  Future<void> _handleLinkExpired(DownloadTask task) async {
    final lastRefresh = _refreshingTasks[task.id];
    if (lastRefresh != null && DateTime.now().difference(lastRefresh).inSeconds < 3) return;
    _refreshingTasks[task.id] = DateTime.now();
    try {
      final attempts = _refreshCounts[task.id] ?? 0;
      if (attempts >= 24) { await failDownload(task.id, 'Link expired — max refreshes exceeded'); return; }
      _refreshCounts[task.id] = attempts + 1;
      final videoId = YoutubeGrabberService.extractVideoId(task.url, referer: task.referer, finalUrl: task.finalUrl);
      if (videoId == null) { await failDownload(task.id, 'Link expired — video ID unresolvable'); return; }
      final itags = _parseItagFragment(task.referer);
      final videoItag = itags?.$1 ?? '18';
      final audioItag = task.audioUrl != null ? (itags?.$2 ?? '140') : null;
      final refreshed = await YoutubeGrabberService.instance.refreshStreams(
        videoId: videoId, targetVideoItag: videoItag, targetAudioItag: audioItag,
      );
      if (refreshed == null) { await failDownload(task.id, 'Failed to fetch fresh stream'); return; }
      await updateTaskUrls(
        taskId: task.id, newUrl: refreshed.videoUrl,
        newAudioUrl: task.audioUrl != null ? refreshed.audioUrl : null,
      );
    } catch (e) { await failDownload(task.id, 'Refresh error: $e'); }
    finally { _refreshingTasks.remove(task.id); }
  }

  Future<void> handleLinkExpired(DownloadTask task) => _handleLinkExpired(task);

  DownloadTask _pendingTask(_YouTubePending p, String taskId, DownloadStatus status) => DownloadTask(
    id: taskId, url: p.url, destinationPath: p.destinationPath, segmentsCount: 1,
    totalBytes: p.estBytes, status: status, referer: p.referer,
  );

  /// Resolves fresh stream URLs in a background isolate and starts the
  /// native engine with them (native handles the sequential download, resume,
  /// audio muxing, DB persistence and notifications).
  Future<void> _resolveAndStartNative(String taskId) async {
    final p = _ytPending[taskId];
    if (p == null || p.canceled) return;

    // Sniffed page-session URLs are already attested for this device.
    if (p.url.contains('googlevideo.com')) {
      var est = p.estBytes;
      if (est <= 0) {
        final probe = await probeUrl(p.url, referer: p.referer);
        est = (probe?['contentLength'] as num?)?.toInt() ?? -1;
        if (p.canceled) return;
      }
      final ref = 'https://www.youtube.com/watch?v=${p.videoId}#itag=${p.videoItag}:${p.audioItag ?? ''}';
      try {
        await _methodChannel.invokeMethod<bool>('startDownload', {
          'taskId': taskId, 'url': p.url, 'destinationPath': p.destinationPath,
          'segmentsCount': 1, 'startNow': p.startNow, 'referer': ref,
          'totalBytes': est > 0 ? est : -1,
          'audioUrl': ?p.providedAudioUrl, 'audioBytes': p.providedAudioBytes,
        });
        _ytPending.remove(taskId); // native task now owns this id
      } catch (e) {
        _failPending(taskId, 'Failed to start native download: $e');
      }
      return;
    }

    List<String?> picked;
    try { picked = await YoutubeDownloader.instance.resolveStreams(p.videoId, p.videoItag, p.audioItag); }
    catch (e) { _failPending(taskId, 'Failed to load streams: $e'); return; }
    if (p.canceled) return;
    if (picked[0] == null) { _failPending(taskId, 'Video stream not found for itag ${p.videoItag}'); return; }
    final videoBytes = int.parse(picked[1]!);
    final audioBytes = int.parse(picked[3] ?? '0');
    final audioUrl = picked[2];
    final ref = 'https://www.youtube.com/watch?v=${p.videoId}#itag=${p.videoItag}:${p.audioItag ?? ''}';
    try {
      await _methodChannel.invokeMethod<bool>('startDownload', {
        'taskId': taskId, 'url': picked[0], 'destinationPath': p.destinationPath,
        'segmentsCount': 1, 'startNow': p.startNow, 'referer': ref,
        'totalBytes': videoBytes + audioBytes, 'audioUrl': ?audioUrl, 'audioBytes': audioBytes,
      });
      _ytPending.remove(taskId); // native task now owns this id
    } catch (e) {
      _failPending(taskId, 'Failed to start native download: $e');
    }
  }

  void _failPending(String taskId, String err) {
    final p = _ytPending.remove(taskId);
    _log('[DLREFRESH] pending YT task $taskId failed: $err');
    _taskStreamCtrl.add(_pendingTask(p ?? _YouTubePending('', '', null, '', '', null, 0, true), taskId, DownloadStatus.failed).copyWith(errorMessage: err));
  }

  Future<bool> startDownload({
    required String taskId, required String url, required String destinationPath, int segmentsCount = 8,
    bool startNow = true, String? referer, int? totalBytes, String? audioUrl, int? audioBytes,
    String? videoId, String? videoItag, String? audioItag, bool audioOnly = false,
  }) async {
    final vId = videoId ?? YoutubeGrabberService.extractVideoId(url, referer: referer);
    final isYt = vId != null || url.contains('googlevideo.com') || audioUrl != null;

    if (isYt && vId != null) {
      final pending = _YouTubePending(
        vId, videoItag ?? '18', audioItag, destinationPath, url, referer, totalBytes ?? 0, startNow,
        providedAudioUrl: audioUrl, providedAudioBytes: audioBytes ?? 0,
      );
      _ytPending[taskId] = pending;
      _taskStreamCtrl.add(_pendingTask(pending, taskId, startNow ? DownloadStatus.connecting : DownloadStatus.paused));
      if (startNow) unawaited(_resolveAndStartNative(taskId));
      return true;
    }

    try {
      final success = await _methodChannel.invokeMethod<bool>('startDownload', {
        'taskId': taskId, 'url': url, 'destinationPath': destinationPath, 'segmentsCount': segmentsCount,
        'startNow': startNow, 'referer': ?referer, 'totalBytes': ?totalBytes, 'audioUrl': ?audioUrl, 'audioBytes': ?audioBytes,
      });
      return success ?? false;
    } catch (e) {
      developer.log('Failed to start download: $e', name: 'Downloader', error: e);
      return false;
    }
  }

  Future<Map<String, int>> getDiskSpace([String? path]) async {
    try {
      final res = await _methodChannel.invokeMapMethod<String, dynamic>('getDiskSpace', path != null ? {'path': path} : null);
      return {'available': (res?['available'] as num?)?.toInt() ?? 0, 'total': (res?['total'] as num?)?.toInt() ?? 0};
    } catch (_) { return {'available': 0, 'total': 0}; }
  }

  Future<String?> getPublicDownloadDirectory() async => _methodChannel.invokeMethod<String>('getPublicDownloadDirectory');
  Future<bool> requestStoragePermission() async => (await _methodChannel.invokeMethod<bool>('requestStoragePermission')) ?? true;
  Future<Map<String, dynamic>?> probeUrl(String url, {String? referer}) async => _methodChannel.invokeMapMethod<String, dynamic>('probeUrl', {'url': url, 'referer': ?referer});
  Future<bool> pauseDownload(String taskId) async {
    final p = _ytPending[taskId];
    if (p != null) {
      p.startNow = false;
      _taskStreamCtrl.add(_pendingTask(p, taskId, DownloadStatus.paused));
      return true;
    }
    return (await _methodChannel.invokeMethod<bool>('pauseDownload', {'taskId': taskId})) ?? false;
  }
  Future<bool> resumeDownload(String taskId) async {
    final p = _ytPending[taskId];
    if (p != null) {
      p.startNow = true;
      _taskStreamCtrl.add(_pendingTask(p, taskId, DownloadStatus.connecting));
      unawaited(_resolveAndStartNative(taskId));
      return true;
    }
    return (await _methodChannel.invokeMethod<bool>('resumeDownload', {'taskId': taskId})) ?? false;
  }
  Future<bool> cancelDownload(String taskId) async {
    final p = _ytPending.remove(taskId);
    if (p != null) {
      p.canceled = true;
      _taskStreamCtrl.add(_pendingTask(p, taskId, DownloadStatus.canceled));
      return true;
    }
    return (await _methodChannel.invokeMethod<bool>('cancelDownload', {'taskId': taskId})) ?? false;
  }
  Future<bool> deleteDownload(String taskId, {bool deleteFile = false}) async {
    final p = _ytPending.remove(taskId);
    if (p != null) {
      p.canceled = true;
      if (deleteFile) {
        try {
          final f = File(p.destinationPath); if (await f.exists()) await f.delete();
          for (final suffix in ['.part', '.audio.part']) {
            final part = File('${p.destinationPath}$suffix'); if (await part.exists()) await part.delete();
          }
        } catch (_) {}
      }
      _taskStreamCtrl.add(_pendingTask(p, taskId, DownloadStatus.canceled));
      return true;
    }
    return (await _methodChannel.invokeMethod<bool>('deleteDownload', {'taskId': taskId, 'deleteFile': deleteFile})) ?? false;
  }
  Future<bool> pauseAll() async {
    for (final id in _ytPending.keys.toList()) { await pauseDownload(id); }
    return (await _methodChannel.invokeMethod<bool>('pauseAll')) ?? false;
  }
  Future<bool> resumeAll() async {
    for (final id in _ytPending.keys.toList()) { await resumeDownload(id); }
    return (await _methodChannel.invokeMethod<bool>('resumeAll')) ?? false;
  }
  Future<bool> setMaxConcurrentDownloads(int limit) async => (await _methodChannel.invokeMethod<bool>('setMaxConcurrent', {'limit': limit})) ?? false;
  Future<bool> setSpeedLimit({String? taskId, required int bytesPerSecond}) async => (await _methodChannel.invokeMethod<bool>('setSpeedLimit', {'taskId': taskId, 'bytesPerSec': bytesPerSecond})) ?? false;
  Future<bool> scheduleTorrentSeeding({required String taskId, bool wifiOnly = true, bool requiresCharging = true}) async => (await _methodChannel.invokeMethod<bool>('scheduleSeeding', {'taskId': taskId, 'wifiOnly': wifiOnly, 'requiresCharging': requiresCharging})) ?? false;
  Future<bool> stopTorrentSeeding(String taskId) async => (await _methodChannel.invokeMethod<bool>('stopSeeding', {'taskId': taskId})) ?? false;
  Future<bool> failDownload(String taskId, String reason) async {
    final p = _ytPending[taskId];
    if (p != null) { _failPending(taskId, reason); return true; }
    return (await _methodChannel.invokeMethod<bool>('failDownload', {'taskId': taskId, 'reason': reason})) ?? false;
  }
  Future<bool> updateTaskUrls({required String taskId, required String newUrl, String? newAudioUrl}) async => (await _methodChannel.invokeMethod<bool>('updateTaskUrls', {'taskId': taskId, 'newUrl': newUrl, 'newAudioUrl': newAudioUrl})) ?? false;

  Future<List<DownloadTask>> getActiveTasks() async {
    final pendingTasks = _ytPending.entries.map((e) => _pendingTask(e.value, e.key, e.value.startNow ? DownloadStatus.connecting : DownloadStatus.paused)).toList();
    try {
      final raw = await _methodChannel.invokeMethod<List<dynamic>>('getTasks');
      final nativeList = raw == null ? <DownloadTask>[] : raw.map((dynamic item) => DownloadTask.fromMap(Map<dynamic, dynamic>.from(item as Map))).toList();
      return [...pendingTasks, ...nativeList];
    } catch (_) { return pendingTasks; }
  }
}

class _YouTubePending {
  final String videoId, videoItag, destinationPath, url;
  final String? audioItag, referer;
  final int estBytes;
  final String? providedAudioUrl;
  final int providedAudioBytes;
  bool startNow;
  bool canceled = false;
  _YouTubePending(this.videoId, this.videoItag, this.audioItag, this.destinationPath, this.url, this.referer, this.estBytes, this.startNow, {this.providedAudioUrl, this.providedAudioBytes = 0});
}
