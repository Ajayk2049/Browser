enum DownloadStatus {
  pending,
  queued,
  connecting,
  downloading,
  paused,
  completed,
  failed,
  canceled;

  static DownloadStatus fromString(String? value) {
    return DownloadStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value?.toLowerCase(),
      orElse: () => DownloadStatus.pending,
    );
  }
}

/// Represents the immutable state of a segmented download task.
/// Complies with rules.md §29.1 and §29.2.
class DownloadTask {
  final String id;
  final String url;
  final String destinationPath;
  final int segmentsCount;
  final int totalBytes;
  final int downloadedBytes;
  final int speedBytesPerSec;
  final int speedLimitBytesPerSec;
  final double progress;
  final int etaSeconds;
  final DownloadStatus status;
  final String? errorMessage;
  final bool isTorrent;
  final int seeders;
  final int leechers;

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
  });

  String get speedFormatted {
    if (speedBytesPerSec >= 1024 * 1024) {
      return '${(speedBytesPerSec / (1024 * 1024)).toStringAsFixed(2)} MB/s';
    } else if (speedBytesPerSec >= 1024) {
      return '${(speedBytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    }
    return '$speedBytesPerSec B/s';
  }

  String get etaFormatted {
    if (etaSeconds <= 0) return '--';
    if (etaSeconds >= 3600) {
      final h = etaSeconds ~/ 3600;
      final m = (etaSeconds % 3600) ~/ 60;
      return '${h}h ${m}m';
    } else if (etaSeconds >= 60) {
      final m = etaSeconds ~/ 60;
      final s = etaSeconds % 60;
      return '${m}m ${s}s';
    }
    return '${etaSeconds}s';
  }

  String get progressPercentage => '${(progress * 100).toStringAsFixed(1)}%';

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
    );
  }

  Map<String, dynamic> toMap() {
    return {
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
    };
  }

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
    );
  }
}

