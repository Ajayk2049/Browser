package com.dab.browser

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
    @Volatile var destinationPath: String,
    val segmentsCount: Int = 8,
    @Volatile var totalBytes: Long = -1L,
    @Volatile var downloadedBytes: Long = 0L,
    @Volatile var speedBytesPerSec: Long = 0L,
    @Volatile var speedLimitBytesPerSec: Long = 0L,
    @Volatile var status: DownloadStatus = DownloadStatus.PENDING,
    @Volatile var errorMessage: String? = null,
    val isTorrent: Boolean = false,
    @Volatile var seeders: Int = 0,
    @Volatile var leechers: Int = 0,
    @Volatile var finalUrl: String? = null,
    @Volatile var resolvedContentType: String? = null,
    @Volatile var referer: String? = null,
    val segments: MutableList<DownloadSegment> = mutableListOf()
) {
    val progress: Double
        get() = if (totalBytes > 0) (downloadedBytes.toDouble() / totalBytes.toDouble()).coerceIn(0.0, 1.0) else 0.0

    val etaSeconds: Long
        get() = if (speedBytesPerSec > 0 && totalBytes > downloadedBytes) {
            (totalBytes - downloadedBytes) / speedBytesPerSec
        } else 0L

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
            "etaSeconds" to etaSeconds,
            "status" to status.name.lowercase(),
            "errorMessage" to errorMessage,
            "isTorrent" to isTorrent,
            "seeders" to seeders,
            "leechers" to leechers,
            "finalUrl" to finalUrl,
            "resolvedContentType" to resolvedContentType,
            "referer" to referer
        )
    }
}

