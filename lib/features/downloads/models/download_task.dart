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
  final DownloadStatus status;
  final String? errorMessage;

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
    this.status = DownloadStatus.pending,
    this.errorMessage,
  });

  String get speedFormatted {
    if (speedBytesPerSec >= 1024 * 1024) {
      return '${(speedBytesPerSec / (1024 * 1024)).toStringAsFixed(2)} MB/s';
    } else if (speedBytesPerSec >= 1024) {
      return '${(speedBytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    }
    return '$speedBytesPerSec B/s';
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
      status: DownloadStatus.fromString(map['status'] as String?),
      errorMessage: map['errorMessage'] as String?,
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
      'status': status.name,
      'errorMessage': errorMessage,
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
    DownloadStatus? status,
    String? errorMessage,
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
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

