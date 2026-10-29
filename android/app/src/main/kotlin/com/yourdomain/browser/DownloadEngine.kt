package com.yourdomain.browser

import kotlinx.coroutines.*
import java.io.File
import java.io.InputStream
import java.io.RandomAccessFile
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.atomic.AtomicBoolean

class DownloadEngine(
    val task: DownloadTask,
    private val onProgressUpdate: (DownloadTask) -> Unit
) {
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val isPaused = AtomicBoolean(false)
    private val isCanceled = AtomicBoolean(false)
    private val rafLock = Any()
    private val throttleLock = Any()
    private var downloadJob: Job? = null
    @Volatile var speedLimitBytesPerSec: Long = task.speedLimitBytesPerSec
    private var lastThrottleTime = System.currentTimeMillis()
    private var bytesInWindow = 0L

    fun setSpeedLimit(bytesPerSec: Long) {
        speedLimitBytesPerSec = bytesPerSec
        task.speedLimitBytesPerSec = bytesPerSec
    }

    fun start() {
        if (task.status == DownloadStatus.DOWNLOADING) return
        isPaused.set(false)
        isCanceled.set(false)
        task.status = DownloadStatus.CONNECTING
        onProgressUpdate(task)

        downloadJob = scope.launch {
            try {
                executeDownload()
            } catch (e: CancellationException) {
                // Normal coroutine cancellation
            } catch (e: Exception) {
                task.status = DownloadStatus.FAILED
                task.errorMessage = e.message ?: "Unknown download error"
                onProgressUpdate(task)
            }
        }
    }

    fun pause() {
        isPaused.set(true)
        downloadJob?.cancel()
        task.status = DownloadStatus.PAUSED
        task.speedBytesPerSec = 0L
        onProgressUpdate(task)
    }

    fun cancel() {
        isCanceled.set(true)
        downloadJob?.cancel()
        task.status = DownloadStatus.CANCELED
        task.speedBytesPerSec = 0L
        val partFile = File("${task.destinationPath}.part")
        if (partFile.exists()) partFile.delete()
        onProgressUpdate(task)
    }

    private suspend fun executeDownload() = withContext(Dispatchers.IO) {
        val destFile = File(task.destinationPath)
        val partFile = File("${task.destinationPath}.part")
        destFile.parentFile?.mkdirs()

        // 1. Probe server for file size and range capabilities if not yet known
        if (task.totalBytes <= 0) {
            val headInfo = probeUrl(task.url)
            task.totalBytes = headInfo.contentLength
            val supportsRanges = headInfo.supportsRanges

            if (supportsRanges && task.totalBytes > 0) {
                partitionSegments(task.totalBytes, task.segmentsCount)
            } else {
                task.segments.clear()
                task.segments.add(DownloadSegment(0, 0, if (task.totalBytes > 0) task.totalBytes - 1 else Long.MAX_VALUE))
            }
        }

        val raf = RandomAccessFile(partFile, "rw")
        if (task.totalBytes > 0 && partFile.length() < task.totalBytes) {
            raf.setLength(task.totalBytes)
        }

        task.status = DownloadStatus.DOWNLOADING
        onProgressUpdate(task)

        // 2. Start speed tracker loop
        val speedTracker = launch { trackSpeed() }

        try {
            // 3. Download each segment concurrently
            val segmentJobs = task.segments.map { segment ->
                launch {
                    if (!segment.isFinished && !isPaused.get() && !isCanceled.get()) {
                        downloadSegment(segment, raf)
                    }
                }
            }
            segmentJobs.joinAll()

            if (!isPaused.get() && !isCanceled.get()) {
                raf.close()
                if (destFile.exists()) destFile.delete()
                partFile.renameTo(destFile)
                task.status = DownloadStatus.COMPLETED
                task.speedBytesPerSec = 0L
                onProgressUpdate(task)
            }
        } finally {
            speedTracker.cancel()
            try { raf.close() } catch (_: Exception) {}
        }
    }

    private fun downloadSegment(segment: DownloadSegment, raf: RandomAccessFile) {
        val currentStart = segment.startByte + segment.downloadedBytes
        if (segment.endByte != Long.MAX_VALUE && currentStart > segment.endByte) return

        val connection = (URL(task.url).openConnection() as HttpURLConnection).apply {
            connectTimeout = 15000
            readTimeout = 30000
            instanceFollowRedirects = true
            setRequestProperty("User-Agent", "Mozilla/5.0 (Android; Mobile; rv:144.0) Gecko/144.0 Firefox/144.0")
            if (task.segments.size > 1 || segment.endByte != Long.MAX_VALUE) {
                val rangeHeader = if (segment.endByte != Long.MAX_VALUE) "bytes=$currentStart-${segment.endByte}" else "bytes=$currentStart-"
                setRequestProperty("Range", rangeHeader)
            }
        }

        connection.connect()
        val responseCode = connection.responseCode
        if (responseCode !in 200..206) {
            throw Exception("HTTP Error $responseCode loading segment ${segment.index}")
        }

        val input: InputStream = connection.inputStream
        val buffer = ByteArray(32 * 1024)
        var bytesRead: Int

        try {
            while (input.read(buffer).also { bytesRead = it } != -1) {
                if (isPaused.get() || isCanceled.get()) break
                throttleBandwidth(bytesRead)
                synchronized(rafLock) {
                    raf.seek(segment.startByte + segment.downloadedBytes)
                    raf.write(buffer, 0, bytesRead)
                }
                segment.downloadedBytes += bytesRead
                recalculateTotalDownloaded()
            }
        } finally {
            try { input.close() } catch (_: Exception) {}
            connection.disconnect()
        }
    }

    private fun throttleBandwidth(bytesRead: Int) {
        val limit = speedLimitBytesPerSec
        if (limit <= 0) return
        synchronized(throttleLock) {
            bytesInWindow += bytesRead
            val now = System.currentTimeMillis()
            val elapsed = now - lastThrottleTime
            if (elapsed < 1000) {
                if (bytesInWindow >= limit) {
                    val waitMs = 1000 - elapsed
                    if (waitMs > 0) {
                        try { Thread.sleep(waitMs) } catch (_: Exception) {}
                    }
                    bytesInWindow = 0L
                    lastThrottleTime = System.currentTimeMillis()
                }
            } else {
                bytesInWindow = 0L
                lastThrottleTime = now
            }
        }
    }

    private fun recalculateTotalDownloaded() {
        var sum = 0L
        for (seg in task.segments) {
            sum += seg.downloadedBytes
        }
        task.downloadedBytes = sum
    }

    private suspend fun trackSpeed() {
        var lastBytes = task.downloadedBytes
        var lastTime = System.currentTimeMillis()
        while (true) {
            delay(500)
            val now = System.currentTimeMillis()
            val currentBytes = task.downloadedBytes
            val elapsedSec = (now - lastTime) / 1000.0
            if (elapsedSec > 0) {
                task.speedBytesPerSec = ((currentBytes - lastBytes) / elapsedSec).toLong().coerceAtLeast(0L)
            }
            lastBytes = currentBytes
            lastTime = now
            if (task.status == DownloadStatus.DOWNLOADING) {
                onProgressUpdate(task)
            }
        }
    }

    private fun partitionSegments(total: Long, count: Int) {
        task.segments.clear()
        val actualCount = count.coerceIn(1, 16)
        val chunkSize = total / actualCount
        for (i in 0 until actualCount) {
            val start = i * chunkSize
            val end = if (i == actualCount - 1) total - 1 else (start + chunkSize - 1)
            task.segments.add(DownloadSegment(i, start, end))
        }
    }

    private data class HeadInfo(val contentLength: Long, val supportsRanges: Boolean)

    private fun probeUrl(urlString: String): HeadInfo {
        val conn = (URL(urlString).openConnection() as HttpURLConnection).apply {
            requestMethod = "HEAD"
            connectTimeout = 15000
            readTimeout = 15000
            instanceFollowRedirects = true
            setRequestProperty("User-Agent", "Mozilla/5.0 (Android; Mobile; rv:144.0) Gecko/144.0 Firefox/144.0")
        }
        conn.connect()
        val length = conn.contentLengthLong
        val ranges = conn.getHeaderField("Accept-Ranges")
        val supports = ranges != null && ranges.contains("bytes", ignoreCase = true)
        conn.disconnect()
        return HeadInfo(length, supports)
    }
}

