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
    private val onSaveSegments: ((List<DownloadSegment>) -> Unit)? = null,
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

    fun setSpeedLimit(bytesPerSec: Long) { speedLimitBytesPerSec = bytesPerSec; task.speedLimitBytesPerSec = bytesPerSec }
    fun start() {
        if (task.status == DownloadStatus.DOWNLOADING) return
        isPaused.set(false)
        isCanceled.set(false)
        task.status = DownloadStatus.CONNECTING
        onProgressUpdate(task)

        downloadJob = scope.launch {
            try {
                executeDownload()
            } catch (_: CancellationException) {
            } catch (e: Exception) {
                task.status = DownloadStatus.FAILED
                task.errorMessage = e.message ?: "Download failed"
                task.speedBytesPerSec = 0L
                onProgressUpdate(task)
            }
        }
    }

    fun pause() {
        isPaused.set(true)
        downloadJob?.cancel()
        task.status = DownloadStatus.PAUSED
        task.speedBytesPerSec = 0L
        onSaveSegments?.invoke(task.segments)
        onProgressUpdate(task)
    }
    fun cancel() {
        isCanceled.set(true)
        downloadJob?.cancel()
        task.status = DownloadStatus.CANCELED
        task.speedBytesPerSec = 0L
        val part = File("${task.destinationPath}.part")
        if (part.exists()) part.delete()
        onProgressUpdate(task)
    }

    private suspend fun executeDownload() = withContext(Dispatchers.IO) {
        val destFile = File(task.destinationPath)
        val partFile = File("${task.destinationPath}.part")
        destFile.parentFile?.mkdirs()

        // 1. Probe server for file size and range capabilities
        if (task.totalBytes <= 0 || task.segments.isEmpty()) {
            val headInfo = probeUrl(task.url)
            task.totalBytes = headInfo.contentLength
            if (headInfo.supportsRanges && task.totalBytes > 0) {
                partitionSegments(task.totalBytes, task.segmentsCount)
            } else {
                task.segments.clear()
                val end = if (task.totalBytes > 0) task.totalBytes - 1 else Long.MAX_VALUE
                task.segments.add(DownloadSegment(0, 0, end))
            }
        }

        val raf = RandomAccessFile(partFile, "rw")
        if (task.totalBytes > 0 && partFile.length() < task.totalBytes) {
            raf.setLength(task.totalBytes)
        }

        task.status = DownloadStatus.DOWNLOADING
        onProgressUpdate(task)

        val speedTracker = launch { trackSpeed() }
        try {
            try {
                val segmentJobs = task.segments.map { segment ->
                    launch {
                        if (!segment.isFinished && !isPaused.get() && !isCanceled.get()) {
                            downloadSegment(segment, raf)
                        }
                    }
                }
                segmentJobs.joinAll()
            } catch (e: Exception) {
                if (e.message?.contains("429") == true && !isPaused.get() && !isCanceled.get()) {
                    delay(1200)
                    task.segments.clear()
                    val end = if (task.totalBytes > 0) task.totalBytes - 1 else Long.MAX_VALUE
                    val fallback = DownloadSegment(0, 0, end, downloadedBytes = task.downloadedBytes)
                    task.segments.add(fallback)
                    downloadSegment(fallback, raf)
                } else throw e
            }

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
        val rangeHeader = if (segment.endByte != Long.MAX_VALUE) "bytes=$currentStart-${segment.endByte}" else if (currentStart > 0) "bytes=$currentStart-" else null
        val conn = openConnection(task.url, rangeHeader)
        val code = conn.responseCode
        if (code !in 200..206) {
            conn.disconnect()
            throw Exception("HTTP $code ${conn.responseMessage ?: ""}".trim())
        }
        val input: InputStream = conn.inputStream
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
                onProgressUpdate(task)
            }
        } finally {
            try { input.close() } catch (_: Exception) {}
            conn.disconnect()
        }
    }

    private fun openConnection(urlStr: String, rangeHeader: String? = null, method: String = "GET"): HttpURLConnection {
        var current = urlStr
        for (i in 0 until 8) {
            val conn = (URL(current).openConnection() as HttpURLConnection).apply {
                requestMethod = method
                connectTimeout = 15000
                readTimeout = 30000
                instanceFollowRedirects = false
                setRequestProperty("User-Agent", "Mozilla/5.0 (Android; Mobile; rv:144.0) Gecko/144.0 Firefox/144.0")
                setRequestProperty("Accept", "*/*")
                if (rangeHeader != null) setRequestProperty("Range", rangeHeader)
            }
            conn.connect()
            val code = conn.responseCode
            if (code in 300..399) {
                val loc = conn.getHeaderField("Location") ?: break
                current = if (loc.startsWith("http")) loc else URL(URL(current), loc).toString()
                conn.disconnect()
                continue
            }
            return conn
        }
        return (URL(current).openConnection() as HttpURLConnection)
    }

    private fun throttleBandwidth(bytesRead: Int) {
        val limit = speedLimitBytesPerSec
        if (limit <= 0) return
        synchronized(throttleLock) {
            bytesInWindow += bytesRead
            val now = System.currentTimeMillis()
            val elapsed = now - lastThrottleTime
            if (elapsed < 1000 && bytesInWindow >= limit) {
                val waitMs = 1000 - elapsed
                if (waitMs > 0) try { Thread.sleep(waitMs) } catch (_: Exception) {}
                bytesInWindow = 0L
                lastThrottleTime = System.currentTimeMillis()
            } else if (elapsed >= 1000) {
                bytesInWindow = 0L
                lastThrottleTime = now
            }
        }
    }

    private fun recalculateTotalDownloaded() {
        task.downloadedBytes = task.segments.sumOf { it.downloadedBytes }
    }
    private suspend fun trackSpeed() {
        var lastBytes = task.downloadedBytes
        var lastTime = System.currentTimeMillis()
        while (true) {
            delay(250)
            val now = System.currentTimeMillis()
            val currentBytes = task.downloadedBytes
            val elapsedSec = (now - lastTime) / 1000.0
            if (elapsedSec > 0) task.speedBytesPerSec = ((currentBytes - lastBytes) / elapsedSec).toLong().coerceAtLeast(0L)
            lastBytes = currentBytes
            lastTime = now
            if (task.status == DownloadStatus.DOWNLOADING) onProgressUpdate(task)
        }
    }

    private fun partitionSegments(total: Long, count: Int) {
        task.segments.clear()
        val effectiveCount = if (total < 5 * 1024 * 1024) 1 else count.coerceIn(1, 16)
        val chunkSize = total / effectiveCount
        for (i in 0 until effectiveCount) {
            val start = i * chunkSize
            val end = if (i == effectiveCount - 1) total - 1 else (start + chunkSize - 1)
            task.segments.add(DownloadSegment(i, start, end))
        }
    }

    private data class HeadInfo(val contentLength: Long, val supportsRanges: Boolean)

    private fun probeUrl(urlString: String): HeadInfo = try {
        val conn = openConnection(urlString, method = "HEAD")
        if (conn.responseCode in 200..299) {
            val len = conn.contentLengthLong
            val supports = conn.getHeaderField("Accept-Ranges")?.contains("bytes", true) == true
            conn.disconnect()
            HeadInfo(len, supports)
        } else {
            conn.disconnect()
            HeadInfo(-1L, false)
        }
    } catch (_: Exception) {
        HeadInfo(-1L, false)
    }
}
