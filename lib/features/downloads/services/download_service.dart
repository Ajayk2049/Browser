import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import '../models/download_task.dart';

/// Platform channel wrapper providing control and progress streaming
/// for the native multi-threaded Android download engine.
/// Complies with rules.md §26.1, §26.5, §29.1, and §29.2.
class DownloadService {
  static const MethodChannel _methodChannel =
      MethodChannel('com.dab/downloader');
  static const EventChannel _eventChannel =
      EventChannel('com.dab/downloads/updates');

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
        .map((dynamic event) {
          final map = Map<dynamic, dynamic>.from(event as Map);
          return DownloadTask.fromMap(map);
        })
        .asBroadcastStream();
    return _downloadUpdatesStream!;
  }

  /// Listens to the progress stream and logs structured progress to console.
  void _initLoggingSubscriber() {
    downloadUpdates.listen(
      (task) => developer.log(
        '[Downloader] ${task.id}: ${task.progressPercentage} | ${task.speedFormatted}',
        name: 'Downloader',
      ),
      onError: (dynamic error) => developer.log('Error: $error', name: 'Downloader', error: error),
    );
  }

  /// Starts a new multi-threaded parallel download or adds it queued/paused.
  Future<bool> startDownload({
    required String taskId,
    required String url,
    required String destinationPath,
    int segmentsCount = 8,
    bool startNow = true,
    String? referer,
  }) async {
    try {
      final success = await _methodChannel.invokeMethod<bool>('startDownload', {
        'taskId': taskId,
        'url': url,
        'destinationPath': destinationPath,
        'segmentsCount': segmentsCount,
        'startNow': startNow,
        'referer': ?referer,
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
      final res = await _methodChannel.invokeMapMethod<String, dynamic>(
        'getDiskSpace',
        path != null ? {'path': path} : null,
      );
      return {
        'available': (res?['available'] as num?)?.toInt() ?? 0,
        'total': (res?['total'] as num?)?.toInt() ?? 0,
      };
    } catch (_) {
      return {'available': 0, 'total': 0};
    }
  }

  /// Returns the public shared storage directory (e.g. /storage/emulated/0/Download/Dab Browser)
  Future<String?> getPublicDownloadDirectory() async {
    try {
      return await _methodChannel.invokeMethod<String>('getPublicDownloadDirectory');
    } catch (_) {
      return null;
    }
  }

  /// Requests Android runtime storage permission if applicable.
  Future<bool> requestStoragePermission() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('requestStoragePermission');
      return res ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Probes URL directly via native engine (single source of truth for size & filename).
  Future<Map<String, dynamic>?> probeUrl(String url, {String? referer}) async {
    try {
      return await _methodChannel.invokeMapMethod<String, dynamic>(
        'probeUrl',
        {'url': url, 'referer': ?referer},
      );
    } catch (_) {
      return null;
    }
  }

  /// Pauses an active download, preserving downloaded segment offsets.
  Future<bool> pauseDownload(String taskId) async {
    try {
      return await _methodChannel.invokeMethod<bool>('pauseDownload', {'taskId': taskId}) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Resumes a paused download from its existing byte offsets.
  Future<bool> resumeDownload(String taskId) async {
    try {
      return await _methodChannel.invokeMethod<bool>('resumeDownload', {'taskId': taskId}) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Cancels an active download and cleans up temporary .part files.
  Future<bool> cancelDownload(String taskId) async {
    try {
      return await _methodChannel.invokeMethod<bool>('cancelDownload', {'taskId': taskId}) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Pauses all active and queued downloads.
  Future<bool> pauseAll() async {
    try {
      final success = await _methodChannel.invokeMethod<bool>('pauseAll');
      return success ?? false;
    } on PlatformException catch (e) {
      developer.log('Failed to pause all: ${e.message}', name: 'Downloader', error: e);
      return false;
    }
  }

  /// Resumes all paused downloads subject to concurrency limits.
  Future<bool> resumeAll() async {
    try {
      final success = await _methodChannel.invokeMethod<bool>('resumeAll');
      return success ?? false;
    } on PlatformException catch (e) {
      developer.log('Failed to resume all: ${e.message}', name: 'Downloader', error: e);
      return false;
    }
  }

  /// Sets maximum concurrent active downloads allowed (queue kicks in for excess).
  Future<bool> setMaxConcurrentDownloads(int limit) async {
    try {
      final success = await _methodChannel.invokeMethod<bool>(
        'setMaxConcurrent',
        {'limit': limit},
      );
      return success ?? false;
    } on PlatformException catch (e) {
      developer.log('Failed to set max concurrent: ${e.message}', name: 'Downloader', error: e);
      return false;
    }
  }

  /// Caps download speed in bytes/sec (0 = unlimited).
  /// If [taskId] is omitted, applies globally to all tasks.
  Future<bool> setSpeedLimit({String? taskId, required int bytesPerSecond}) async {
    try {
      final success = await _methodChannel.invokeMethod<bool>(
        'setSpeedLimit',
        {'taskId': taskId, 'bytesPerSec': bytesPerSecond},
      );
      return success ?? false;
    } on PlatformException catch (e) {
      developer.log('Failed to set speed limit: ${e.message}', name: 'Downloader', error: e);
      return false;
    }
  }

  /// Schedules background seeding via WorkManager with unmetered/charging constraints.
  /// Dynamically promotes to foreground only when active peer uploads occur.
  Future<bool> scheduleTorrentSeeding({
    required String taskId,
    bool wifiOnly = true,
    bool requiresCharging = true,
  }) async {
    try {
      final success = await _methodChannel.invokeMethod<bool>(
        'scheduleSeeding',
        {
          'taskId': taskId,
          'wifiOnly': wifiOnly,
          'requiresCharging': requiresCharging,
        },
      );
      return success ?? false;
    } on PlatformException catch (e) {
      developer.log('Failed to schedule seeding: ${e.message}', name: 'Downloader', error: e);
      return false;
    }
  }

  /// Cancels background seeding worker for a given torrent task.
  Future<bool> stopTorrentSeeding(String taskId) async {
    try {
      final success = await _methodChannel.invokeMethod<bool>(
        'stopSeeding',
        {'taskId': taskId},
      );
      return success ?? false;
    } on PlatformException catch (e) {
      developer.log('Failed to stop seeding: ${e.message}', name: 'Downloader', error: e);
      return false;
    }
  }

  /// Fetches the current list of active/cached download tasks from the native engine.
  Future<List<DownloadTask>> getActiveTasks() async {
    try {
      final rawTasks = await _methodChannel.invokeMethod<List<dynamic>>('getTasks');
      if (rawTasks == null) return [];
      return rawTasks
          .map((dynamic item) => DownloadTask.fromMap(Map<dynamic, dynamic>.from(item as Map)))
          .toList();
    } on PlatformException catch (e) {
      developer.log('Failed to fetch tasks: ${e.message}', name: 'Downloader', error: e);
      return [];
    }
  }
}

