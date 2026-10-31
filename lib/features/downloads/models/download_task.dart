enum DownloadStatus {
  pending, queued, connecting, downloading, paused, completed, failed, canceled;

  static DownloadStatus fromString(String? value) => DownloadStatus.values.firstWhere(
        (e) => e.name.toLowerCase() == value?.toLowerCase(),
        orElse: () => DownloadStatus.pending,
      );
}

/// Represents the immutable state of a segmented download task.
/// Complies with rules.md §29.1 and §29.2 (< 200 lines).
class DownloadTask {
  final String id, url, destinationPath;
  final int segmentsCount, totalBytes, downloadedBytes, speedBytesPerSec, speedLimitBytesPerSec, etaSeconds, seeders, leechers;
  final double progress;
  final DownloadStatus status;
  final String? errorMessage, dateLabel;
  final bool isTorrent;
  final List<double>? segmentProgresses;

  const DownloadTask({
    required this.id,
    required this.url,
    required this.destinationPath,
    this.segmentsCount = 8,
    this.totalBytes = -1,
    this.downloadedBytes = 0,
    this.speedBytesPerSec = 0,
    this.speedLimitBytesPerSec = 0,
    this.progress = 0.0,
    this.etaSeconds = 0,
    this.status = DownloadStatus.pending,
    this.errorMessage,
    this.isTorrent = false,
    this.seeders = 0,
    this.leechers = 0,
    this.dateLabel,
    this.segmentProgresses,
  });

  String get speedFormatted {
    if (speedBytesPerSec >= 1024 * 1024) return '${(speedBytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    if (speedBytesPerSec >= 1024) return '${(speedBytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    return '$speedBytesPerSec B/s';
  }

  String get etaFormatted {
    if (etaSeconds <= 0) return '--';
    if (etaSeconds >= 3600) return '${etaSeconds ~/ 3600}h ${(etaSeconds % 3600) ~/ 60}m';
    if (etaSeconds >= 60) return '${etaSeconds ~/ 60}m ${etaSeconds % 60}s';
    return '${etaSeconds}s';
  }

  String get fileSizeFormatted {
    final bytes = totalBytes > 0 ? totalBytes : downloadedBytes;
    if (bytes >= 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }

  String get downloadedSizeFormatted {
    if (downloadedBytes >= 1024 * 1024 * 1024) return '${(downloadedBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    if (downloadedBytes >= 1024 * 1024) return '${(downloadedBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    if (downloadedBytes >= 1024) return '${(downloadedBytes / 1024).toStringAsFixed(1)} KB';
    return '$downloadedBytes B';
  }

  String get progressPercentage => '${(progress * 100).toStringAsFixed(1)}%';

  List<double> getChunks([int fallbackCount = 8]) {
    final count = segmentsCount > 0 ? segmentsCount : fallbackCount;
    if (segmentProgresses != null && segmentProgresses!.length >= count) {
      return segmentProgresses!.sublist(0, count);
    }
    final span = 1.0 / count;
    return List.generate(count, (i) {
      final start = i * span;
      if (progress <= start) return 0.0;
      if (progress >= start + span) return 1.0;
      return ((progress - start) / span).clamp(0.0, 1.0);
    });
  }

  factory DownloadTask.fromMap(Map<dynamic, dynamic> map) {
    return DownloadTask(
      id: map['id'] as String? ?? '',
      url: map['url'] as String? ?? '',
      destinationPath: map['destinationPath'] as String? ?? '',
      segmentsCount: (map['segmentsCount'] as num?)?.toInt() ?? 8,
      totalBytes: (map['totalBytes'] as num?)?.toInt() ?? -1,
      downloadedBytes: (map['downloadedBytes'] as num?)?.toInt() ?? 0,
      speedBytesPerSec: (map['speedBytesPerSec'] as num?)?.toInt() ?? 0,
      speedLimitBytesPerSec: (map['speedLimitBytesPerSec'] as num?)?.toInt() ?? 0,
      progress: (map['progress'] as num?)?.toDouble() ?? 0.0,
      etaSeconds: (map['etaSeconds'] as num?)?.toInt() ?? 0,
      status: DownloadStatus.fromString(map['status'] as String?),
      errorMessage: map['errorMessage'] as String?,
      isTorrent: map['isTorrent'] as bool? ?? false,
      seeders: (map['seeders'] as num?)?.toInt() ?? 0,
      leechers: (map['leechers'] as num?)?.toInt() ?? 0,
      dateLabel: map['dateLabel'] as String?,
      segmentProgresses: (map['segmentProgresses'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'url': url,
        'destinationPath': destinationPath,
        'segmentsCount': segmentsCount,
        'totalBytes': totalBytes,
        'downloadedBytes': downloadedBytes,
        'speedBytesPerSec': speedBytesPerSec,
        'speedLimitBytesPerSec': speedLimitBytesPerSec,
        'progress': progress,
        'etaSeconds': etaSeconds,
        'status': status.name,
        'errorMessage': errorMessage,
        'isTorrent': isTorrent,
        'seeders': seeders,
        'leechers': leechers,
        'dateLabel': dateLabel,
        'segmentProgresses': segmentProgresses,
      };

  DownloadTask copyWith({
    String? id,
    String? url,
    String? destinationPath,
    int? segmentsCount,
    int? totalBytes,
    int? downloadedBytes,
    int? speedBytesPerSec,
    int? speedLimitBytesPerSec,
    double? progress,
    int? etaSeconds,
    DownloadStatus? status,
    String? errorMessage,
    bool? isTorrent,
    int? seeders,
    int? leechers,
    String? dateLabel,
    List<double>? segmentProgresses,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      url: url ?? this.url,
      destinationPath: destinationPath ?? this.destinationPath,
      segmentsCount: segmentsCount ?? this.segmentsCount,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      speedBytesPerSec: speedBytesPerSec ?? this.speedBytesPerSec,
      speedLimitBytesPerSec: speedLimitBytesPerSec ?? this.speedLimitBytesPerSec,
      progress: progress ?? this.progress,
      etaSeconds: etaSeconds ?? this.etaSeconds,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      isTorrent: isTorrent ?? this.isTorrent,
      seeders: seeders ?? this.seeders,
      leechers: leechers ?? this.leechers,
      dateLabel: dateLabel ?? this.dateLabel,
      segmentProgresses: segmentProgresses ?? this.segmentProgresses,
    );
  }
}
