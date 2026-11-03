import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
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

  void _initLoggingSubscriber() {
    downloadUpdates.listen(
      (task) => developer.log('[Downloader] ${task.id}: ${task.progressPercentage} | ${task.speedFormatted}', name: 'Downloader'),
      onError: (dynamic error) => developer.log('Error: $error', name: 'Downloader', error: error),
    );
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
    } catch (_) {
      return {'available': 0, 'total': 0};
    }
  }

  /// Returns the public shared storage directory (e.g. /storage/emulated/0/Download/Dab Browser)
  Future<String?> getPublicDownloadDirectory() async {
    try { return await _methodChannel.invokeMethod<String>('getPublicDownloadDirectory'); } catch (_) { return null; }
  }

  /// Requests Android runtime storage permission if applicable.
  Future<bool> requestStoragePermission() async {
    try { return await _methodChannel.invokeMethod<bool>('requestStoragePermission') ?? true; } catch (_) { return true; }
  }

  /// Probes URL directly via native engine.
  Future<Map<String, dynamic>?> probeUrl(String url, {String? referer}) async {
    try { return await _methodChannel.invokeMapMethod<String, dynamic>('probeUrl', {'url': url, 'referer': ?referer}); } catch (_) { return null; }
  }

  Future<bool> pauseDownload(String taskId) async {
    try { return await _methodChannel.invokeMethod<bool>('pauseDownload', {'taskId': taskId}) ?? false; } catch (_) { return false; }
  }

  Future<bool> resumeDownload(String taskId) async {
    try { return await _methodChannel.invokeMethod<bool>('resumeDownload', {'taskId': taskId}) ?? false; } catch (_) { return false; }
  }

  Future<bool> cancelDownload(String taskId) async {
    try { return await _methodChannel.invokeMethod<bool>('cancelDownload', {'taskId': taskId}) ?? false; } catch (_) { return false; }
  }

  /// Cancels task, purges database record, and optionally deletes file and .part file from storage.
  Future<bool> deleteDownload(String taskId, {bool deleteFile = false}) async {
    try {
      return await _methodChannel.invokeMethod<bool>('deleteDownload', {
        'taskId': taskId,
        'deleteFile': deleteFile,
      }) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> pauseAll() async {
    try { return await _methodChannel.invokeMethod<bool>('pauseAll') ?? false; } catch (_) { return false; }
  }

  Future<bool> resumeAll() async {
    try { return await _methodChannel.invokeMethod<bool>('resumeAll') ?? false; } catch (_) { return false; }
  }

  Future<bool> setMaxConcurrentDownloads(int limit) async {
    try { return await _methodChannel.invokeMethod<bool>('setMaxConcurrent', {'limit': limit}) ?? false; } catch (_) { return false; }
  }

  Future<bool> setSpeedLimit({String? taskId, required int bytesPerSecond}) async {
    try {
      return await _methodChannel.invokeMethod<bool>('setSpeedLimit', {'taskId': taskId, 'bytesPerSec': bytesPerSecond}) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> scheduleTorrentSeeding({required String taskId, bool wifiOnly = true, bool requiresCharging = true}) async {
    try {
      return await _methodChannel.invokeMethod<bool>('scheduleSeeding', {'taskId': taskId, 'wifiOnly': wifiOnly, 'requiresCharging': requiresCharging}) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> stopTorrentSeeding(String taskId) async {
    try { return await _methodChannel.invokeMethod<bool>('stopSeeding', {'taskId': taskId}) ?? false; } catch (_) { return false; }
  }

  Future<List<DownloadTask>> getActiveTasks() async {
    try {
      final raw = await _methodChannel.invokeMethod<List<dynamic>>('getTasks');
      if (raw == null) return [];
      return raw.map((dynamic item) => DownloadTask.fromMap(Map<dynamic, dynamic>.from(item as Map))).toList();
    } catch (_) {
      return [];
    }
  }
}
