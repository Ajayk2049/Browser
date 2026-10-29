package com.yourdomain.browser

enum class DownloadStatus {
    PENDING,
    QUEUED,
    CONNECTING,
    DOWNLOADING,
    PAUSED,
    COMPLETED,
    FAILED,
    CANCELED
}

data class DownloadSegment(
    val index: Int,
    val startByte: Long,
    val endByte: Long,
    @Volatile var downloadedBytes: Long = 0L
) {
    val totalBytes: Long get() = if (endByte >= startByte) (endByte - startByte + 1) else 0L
    val isFinished: Boolean get() = downloadedBytes >= totalBytes
}

data class DownloadTask(
    val id: String,
    val url: String,
    val destinationPath: String,
    val segmentsCount: Int = 8,
    @Volatile var totalBytes: Long = -1L,
    @Volatile var downloadedBytes: Long = 0L,
    @Volatile var speedBytesPerSec: Long = 0L,
    @Volatile var speedLimitBytesPerSec: Long = 0L,
    @Volatile var status: DownloadStatus = DownloadStatus.PENDING,
    @Volatile var errorMessage: String? = null,
    val segments: MutableList<DownloadSegment> = mutableListOf()
) {
    val progress: Double
        get() = if (totalBytes > 0) (downloadedBytes.toDouble() / totalBytes.toDouble()).coerceIn(0.0, 1.0) else 0.0

    fun toMap(): Map<String, Any?> {
        return mapOf(
            "id" to id,
            "url" to url,
            "destinationPath" to destinationPath,
            "segmentsCount" to segmentsCount,
            "totalBytes" to totalBytes,
            "downloadedBytes" to downloadedBytes,
            "speedBytesPerSec" to speedBytesPerSec,
            "speedLimitBytesPerSec" to speedLimitBytesPerSec,
            "progress" to progress,
            "status" to status.name.lowercase(),
            "errorMessage" to errorMessage
        )
    }
}

