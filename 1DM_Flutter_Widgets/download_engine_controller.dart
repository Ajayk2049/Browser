import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'download_item_widget.dart';
import 'multi_part_chunk_visualizer.dart';

/// Controller managing multi-threaded downloads inspired by 1DM+'s architecture
class DownloadEngineController extends ChangeNotifier {
  final Map<String, DownloadItemData> _tasks = {};
  final Map<String, List<ChunkInfo>> _taskChunks = {};
  final Map<String, bool> _activeFlags = {};

  List<DownloadItemData> get tasks => _tasks.values.toList();

  List<ChunkInfo> getChunks(String taskId) => _taskChunks[taskId] ?? [];

  /// Initiates a multi-part download matching 1DM+'s partitioning logic
  Future<void> startDownload({
    required String url,
    required String savePath,
    int parts = 4,
  }) async {
    final uri = Uri.parse(url);
    final taskId = DateTime.now().millisecondsSinceEpoch.toString();
    final filename = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'download.bin';

    _tasks[taskId] = DownloadItemData(
      id: taskId,
      title: filename,
      url: url,
      status: DownloadStatus.connecting,
      downloadedBytes: 0,
      totalBytes: 0,
      speedBps: 0,
      parts: parts,
    );
    _activeFlags[taskId] = true;
    notifyListeners();

    try {
      // 1. Probe HEAD request for Content-Length and Range acceptance
      final headResp = await http.head(uri);
      final acceptsRanges = headResp.headers['accept-ranges']?.toLowerCase().contains('bytes') ?? false;
      final totalLen = int.tryParse(headResp.headers['content-length'] ?? '0') ?? 0;

      final actualParts = (acceptsRanges && totalLen > 1024 * 1024) ? parts.clamp(1, 32) : 1;

      // 2. Compute chunk boundaries
      final chunks = <ChunkInfo>[];
      final chunkSize = (totalLen / actualParts).ceil();

      for (int i = 0; i < actualParts; i++) {
        final start = i * chunkSize;
        final end = (i == actualParts - 1) ? (totalLen - 1) : ((i + 1) * chunkSize - 1);
        chunks.add(ChunkInfo(
          index: i,
          startByte: start,
          endByte: end,
          downloadedBytes: 0,
          state: ChunkState.pending,
        ));
      }

      _taskChunks[taskId] = chunks;
      _tasks[taskId] = _tasks[taskId]!.copyWith(
        totalBytes: totalLen,
        parts: actualParts,
        status: DownloadStatus.downloading,
      );
      notifyListeners();

      // 3. Spawn thread downloads per chunk
      final file = File(savePath);
      final raf = await file.open(mode: FileMode.write);
      if (totalLen > 0) {
        await raf.truncate(totalLen);
      }

      int totalDownloaded = 0;
      var lastTick = DateTime.now();
      int bytesSinceLastTick = 0;

      final futures = chunks.map((chunk) async {
        if (!(_activeFlags[taskId] ?? false)) return;

        final req = http.Request('GET', uri);
        if (totalLen > 0 && actualParts > 1) {
          req.headers['Range'] = 'bytes=${chunk.startByte}-${chunk.endByte}';
        }

        final streamed = await req.send();
        int chunkDownloaded = 0;

        await for (final data in streamed.stream) {
          if (!(_activeFlags[taskId] ?? false)) break;

          // Write slice at byte offset
          final writeOffset = chunk.startByte + chunkDownloaded;
          await raf.setPosition(writeOffset);
          await raf.writeFrom(data);

          chunkDownloaded += data.length;
          totalDownloaded += data.length;
          bytesSinceLastTick += data.length;

          // Throttle notification updates (e.g. every 200ms)
          final now = DateTime.now();
          final elapsedMs = now.difference(lastTick).inMilliseconds;
          if (elapsedMs > 200) {
            final speed = (bytesSinceLastTick * 1000) / elapsedMs;
            bytesSinceLastTick = 0;
            lastTick = now;

            _tasks[taskId] = _tasks[taskId]!.copyWith(
              downloadedBytes: totalDownloaded,
              speedBps: speed.toInt(),
            );
            notifyListeners();
          }
        }
      });

      await Future.wait(futures);
      await raf.close();

      _tasks[taskId] = _tasks[taskId]!.copyWith(
        downloadedBytes: totalLen > 0 ? totalLen : totalDownloaded,
        speedBps: 0,
        status: (_activeFlags[taskId] ?? false) ? DownloadStatus.completed : DownloadStatus.paused,
      );
      notifyListeners();
    } catch (e) {
      _tasks[taskId] = _tasks[taskId]!.copyWith(
        status: DownloadStatus.error,
        speedBps: 0,
      );
      notifyListeners();
    }
  }

  void pauseTask(String taskId) {
    _activeFlags[taskId] = false;
    if (_tasks.containsKey(taskId)) {
      _tasks[taskId] = _tasks[taskId]!.copyWith(status: DownloadStatus.paused, speedBps: 0);
      notifyListeners();
    }
  }

  void cancelTask(String taskId) {
    _activeFlags[taskId] = false;
    _tasks.remove(taskId);
    _taskChunks.remove(taskId);
    notifyListeners();
  }
}
