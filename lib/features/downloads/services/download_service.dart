import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../browser/services/youtube_grabber_service.dart';
import '../models/download_task.dart';

/// Platform channel wrapper providing control and progress streaming
/// for the native multi-threaded Android download engine.
/// Complies with rules.md §26.1, §26.5, §29.1, and §29.2 (< 250 lines).
class DownloadService {
  static const MethodChannel _methodChannel = MethodChannel('com.dab/downloader');
  static const EventChannel _eventChannel = EventChannel('com.dab/downloads/updates');

  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;

  DownloadService._internal() {
    _initLoggingSubscriber();
  }

  Stream<DownloadTask>? _downloadUpdatesStream;

  /// Broadcast stream of real-time download task updates from native service
  Stream<DownloadTask> get downloadUpdates {
    _downloadUpdatesStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((dynamic event) => DownloadTask.fromMap(Map<dynamic, dynamic>.from(event as Map)))
        .asBroadcastStream();
    return _downloadUpdatesStream!;
  }

  final Map<String, int> _refreshCounts = {};
  final Map<String, int> _lastDownloadedBytes = {};
  final Map<String, DateTime> _refreshingTasks = {};
  final Map<String, Timer> _resumeWatchdogs = {};

  void _log(String msg) { debugPrint(msg); developer.log(msg, name: 'DLREFRESH'); }

  void _initLoggingSubscriber() {
    downloadUpdates.listen(
      (task) {
        final prev = _lastDownloadedBytes[task.id] ?? 0;
        if (task.downloadedBytes > prev) {
          _lastDownloadedBytes[task.id] = task.downloadedBytes;
          _refreshCounts.remove(task.id);
          _resumeWatchdogs.remove(task.id)?.cancel();
        }
        if (task.status == DownloadStatus.linkExpired) {
          _handleLinkExpired(task);
        } else if (task.status == DownloadStatus.completed || task.status == DownloadStatus.failed || task.status == DownloadStatus.canceled) {
          _refreshCounts.remove(task.id);
          _refreshingTasks.remove(task.id);
          _resumeWatchdogs.remove(task.id)?.cancel();
        }
        _log('[DLREFRESH] ${task.id}: ${task.status.name} ${task.progressPercentage} | ${task.speedFormatted}');
      },
      onError: (dynamic error) => _log('Error: $error'),
    );
  }

  Future<void> handleLinkExpired(DownloadTask task) => _handleLinkExpired(task);

  Future<void> _handleLinkExpired(DownloadTask task) async {
    final lastRefresh = _refreshingTasks[task.id];
    if (lastRefresh != null && DateTime.now().difference(lastRefresh).inSeconds < 10) {
      _log('[DLREFRESH] ${task.id} already refreshing, skipping duplicate');
      return;
    }
    _refreshingTasks[task.id] = DateTime.now();

    try {
      await _executeLinkRefresh(task).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          _log('[DLREFRESH] Link refresh timed out for ${task.id}');
          failDownload(task.id, 'Link refresh timed out (30s)');
        },
      );
    } catch (e) {
      _log('[DLREFRESH] Error in link refresh: $e');
      await failDownload(task.id, 'Refresh error: $e');
    } finally {
      _refreshingTasks.remove(task.id);
    }
  }

  Future<void> _executeLinkRefresh(DownloadTask task) async {
    final attempts = _refreshCounts[task.id] ?? 0;
    if (attempts >= 6) {
      _log('[DLREFRESH] Max refreshes (6) exceeded for ${task.id}');
      await failDownload(task.id, 'Link expired — max refreshes exceeded');
      return;
    }
    _refreshCounts[task.id] = attempts + 1;
    String? videoId = YoutubeGrabberService.extractVideoId(task.url, referer: task.referer, finalUrl: task.finalUrl);
    if (videoId == null) {
      final fName = task.destinationPath.split(RegExp(r'[/\\]')).lastOrNull ?? '';
      final clean = fName.replaceAll(RegExp(r'\.(mp4|m4a|webm|bin)$', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*\([^)]*\)'), '').replaceAll('_', ' ').trim();
      if (clean.isNotEmpty && !clean.toLowerCase().startsWith('download')) {
        videoId = await YoutubeGrabberService.instance.searchVideoIdByTitle(clean);
      }
    }
    if (videoId == null) {
      _log('[DLREFRESH] Could not extract videoId for ${task.id}');
      await failDownload(task.id, 'Link expired — video ID unresolvable');
      return;
    }
    final videoItag = Uri.tryParse(task.finalUrl ?? task.url)?.queryParameters['itag'] ?? '137';
    final audioItag = task.audioUrl != null ? Uri.tryParse(task.audioUrl!)?.queryParameters['itag'] : null;

    _log('[DLREFRESH] Refreshing streams for $videoId (itag: $videoItag, audio: $audioItag, attempt: ${attempts + 1}/6)');
    final refreshed = await YoutubeGrabberService.instance.refreshStreams(
      videoId: videoId,
      targetVideoItag: videoItag,
      targetAudioItag: audioItag,
    );
    if (refreshed == null) {
      _log('[DLREFRESH] refreshStreams returned null for ${task.id}');
      await failDownload(task.id, 'Failed to fetch fresh stream from YouTube');
      return;
    }
    final ok = await updateTaskUrls(taskId: task.id, newUrl: refreshed.videoUrl, newAudioUrl: refreshed.audioUrl);
    _log('[DLREFRESH] updateTaskUrls returned $ok for ${task.id}');
    if (!ok) {
      await failDownload(task.id, 'YouTube rejected the fresh link (403)');
      return;
    }
    YoutubeGrabberService.recordVideoId(refreshed.videoUrl, videoId);
    if (refreshed.audioUrl != null) YoutubeGrabberService.recordVideoId(refreshed.audioUrl!, videoId);
    _resumeWatchdogs[task.id]?.cancel();
    _resumeWatchdogs[task.id] = Timer(const Duration(seconds: 20), () {
      _log('[DLREFRESH] Resume stalled watchdog (20s) triggered for ${task.id}');
      failDownload(task.id, 'Resume stalled');
    });
  }

  /// Starts a new parallel download or adds it queued/paused.
  Future<bool> startDownload({
    required String taskId,
    required String url,
    required String destinationPath,
    int segmentsCount = 8,
    bool startNow = true,
    String? referer,
    int? totalBytes,
    String? audioUrl,
    int? audioBytes,
  }) async {
    try {
      final success = await _methodChannel.invokeMethod<bool>('startDownload', {
        'taskId': taskId,
        'url': url,
        'destinationPath': destinationPath,
        'segmentsCount': segmentsCount,
        'startNow': startNow,
        'referer': ?referer,
        'totalBytes': ?totalBytes,
        'audioUrl': ?audioUrl,
        'audioBytes': ?audioBytes,
      });
      return success ?? false;
    } on PlatformException catch (e) {
      developer.log('Failed to start download: ${e.message}', name: 'Downloader', error: e);
      return false;
    }
  }

  /// Queries Android StatFs for available and total storage space.
  Future<Map<String, int>> getDiskSpace([String? path]) async {
    try {
      final res = await _methodChannel.invokeMapMethod<String, dynamic>('getDiskSpace', path != null ? {'path': path} : null);
      return {'available': (res?['available'] as num?)?.toInt() ?? 0, 'total': (res?['total'] as num?)?.toInt() ?? 0};
    } catch (_) { return {'available': 0, 'total': 0}; }
  }

  Future<String?> getPublicDownloadDirectory() async => _methodChannel.invokeMethod<String>('getPublicDownloadDirectory');
  Future<bool> requestStoragePermission() async => (await _methodChannel.invokeMethod<bool>('requestStoragePermission')) ?? true;
  Future<Map<String, dynamic>?> probeUrl(String url, {String? referer}) async => _methodChannel.invokeMapMethod<String, dynamic>('probeUrl', {'url': url, 'referer': ?referer});
  Future<bool> pauseDownload(String taskId) async => (await _methodChannel.invokeMethod<bool>('pauseDownload', {'taskId': taskId})) ?? false;
  Future<bool> resumeDownload(String taskId) async {
    final tasks = await getActiveTasks();
    final t = tasks.where((e) => e.id == taskId).firstOrNull;
    if (t != null && t.status == DownloadStatus.linkExpired) {
      _handleLinkExpired(t);
      return true;
    }
    return (await _methodChannel.invokeMethod<bool>('resumeDownload', {'taskId': taskId})) ?? false;
  }
  Future<bool> cancelDownload(String taskId) async => (await _methodChannel.invokeMethod<bool>('cancelDownload', {'taskId': taskId})) ?? false;
  Future<bool> deleteDownload(String taskId, {bool deleteFile = false}) async => (await _methodChannel.invokeMethod<bool>('deleteDownload', {'taskId': taskId, 'deleteFile': deleteFile})) ?? false;
  Future<bool> pauseAll() async => (await _methodChannel.invokeMethod<bool>('pauseAll')) ?? false;
  Future<bool> resumeAll() async => (await _methodChannel.invokeMethod<bool>('resumeAll')) ?? false;
  Future<bool> setMaxConcurrentDownloads(int limit) async => (await _methodChannel.invokeMethod<bool>('setMaxConcurrent', {'limit': limit})) ?? false;
  Future<bool> setSpeedLimit({String? taskId, required int bytesPerSecond}) async => (await _methodChannel.invokeMethod<bool>('setSpeedLimit', {'taskId': taskId, 'bytesPerSec': bytesPerSecond})) ?? false;
  Future<bool> scheduleTorrentSeeding({required String taskId, bool wifiOnly = true, bool requiresCharging = true}) async => (await _methodChannel.invokeMethod<bool>('scheduleSeeding', {'taskId': taskId, 'wifiOnly': wifiOnly, 'requiresCharging': requiresCharging})) ?? false;
  Future<bool> stopTorrentSeeding(String taskId) async => (await _methodChannel.invokeMethod<bool>('stopSeeding', {'taskId': taskId})) ?? false;
  Future<bool> failDownload(String taskId, String reason) async => (await _methodChannel.invokeMethod<bool>('failDownload', {'taskId': taskId, 'reason': reason})) ?? false;
  Future<bool> updateTaskUrls({required String taskId, required String newUrl, String? newAudioUrl}) async => (await _methodChannel.invokeMethod<bool>('updateTaskUrls', {'taskId': taskId, 'newUrl': newUrl, 'newAudioUrl': newAudioUrl})) ?? false;

  Future<List<DownloadTask>> getActiveTasks() async {
    try {
      final raw = await _methodChannel.invokeMethod<List<dynamic>>('getTasks');
      if (raw == null) return [];
      return raw.map((dynamic item) => DownloadTask.fromMap(Map<dynamic, dynamic>.from(item as Map))).toList();
    } catch (_) { return []; }
  }
}
