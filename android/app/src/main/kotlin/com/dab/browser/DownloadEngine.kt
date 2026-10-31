package com.dab.browser

import kotlinx.coroutines.*
import java.io.File
import java.io.InputStream
import java.io.RandomAccessFile
import java.net.HttpURLConnection
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.random.Random

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
        isPaused.set(true); downloadJob?.cancel()
        task.status = DownloadStatus.PAUSED; task.speedBytesPerSec = 0L
        onSaveSegments?.invoke(task.segments); onProgressUpdate(task)
    }

    fun cancel() {
        isCanceled.set(true); downloadJob?.cancel()
        task.status = DownloadStatus.CANCELED; task.speedBytesPerSec = 0L
        val part = File("${task.destinationPath}.part")
        if (part.exists()) part.delete()
        onProgressUpdate(task)
    }

    private suspend fun executeDownload() = withContext(Dispatchers.IO) {
        val destFile = File(task.destinationPath)
        val partFile = File("${task.destinationPath}.part")
        destFile.parentFile?.mkdirs()

        // 1. Single pre-flight request (resolves final URL, Content-Range size & Content-Type)
        if (task.totalBytes <= 0 || task.segments.isEmpty() || task.finalUrl == null) {
            val probe = DownloadHttpHelper.probeUrl(task.finalUrl ?: task.url, task.referer)
            task.finalUrl = probe.finalUrl
            task.resolvedContentType = probe.contentType
            if (task.totalBytes <= 0 && probe.contentLength > 0) task.totalBytes = probe.contentLength

            // Intercept HTML error/preview pages (e.g. Drive viewer or expired token page)
            val isHtml = probe.contentType?.contains("text/html") == true
            val isExpectedHtml = task.destinationPath.endsWith(".html", true) || task.destinationPath.endsWith(".htm", true)
            if (isHtml && !isExpectedHtml) throw Exception("Server returned a webpage instead of a file. The link may have expired or requires login.")

            if (probe.supportsRanges && task.totalBytes > 0) {
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
            supervisorScope {
                // Connection ladder: start worker 0, then stagger siblings by 750ms if range supported
                val activeJobs = mutableListOf<Job>()
                for ((idx, segment) in task.segments.withIndex()) {
                    if (segment.isFinished || isPaused.get() || isCanceled.get()) continue
                    if (idx > 0) delay(750L) // Ladder connection to avoid sudden socket burst
                    if (isPaused.get() || isCanceled.get()) break
                    val job = launch {
                        downloadSegmentWithRetry(segment, raf)
                    }
                    activeJobs.add(job)
                }
                activeJobs.joinAll()
            }

            if (!isPaused.get() && !isCanceled.get()) {
                val allFinished = task.segments.all { it.isFinished } || (task.totalBytes > 0 && task.downloadedBytes >= task.totalBytes)
                if (allFinished) {
                    raf.close()
                    if (destFile.exists()) destFile.delete()
                    partFile.renameTo(destFile)
                    task.status = DownloadStatus.COMPLETED
                    task.speedBytesPerSec = 0L
                    onProgressUpdate(task)
                }
            }
        } finally {
            speedTracker.cancel()
            try { raf.close() } catch (_: Exception) {}
        }
    }

    private suspend fun downloadSegmentWithRetry(segment: DownloadSegment, raf: RandomAccessFile) {
        var attempts = 0
        val maxAttempts = 5
        while (attempts < maxAttempts && !isPaused.get() && !isCanceled.get() && !segment.isFinished) {
            try {
                downloadSegment(segment, raf)
                return
            } catch (e: Exception) {
                if (isPaused.get() || isCanceled.get()) return
                attempts++
                val msg = e.message ?: ""
                val is429 = msg.contains("429")
                val isRetryable = is429 || msg.contains("503") || msg.contains("504") || msg.contains("408") || msg.contains("timeout", true)
                if (!isRetryable || attempts >= maxAttempts) throw e

                // Parse Retry-After or apply exponential backoff with jitter
                val retryAfterMs = DownloadHttpHelper.parseRetryAfter(e.message?.substringAfter("Retry-After:", "")?.trim())
                val backoff = retryAfterMs ?: ((2000L * (1 shl (attempts - 1))) + Random.nextLong(200, 800))
                delay(backoff.coerceIn(1000L, 60000L))
            }
        }
    }

    private fun downloadSegment(segment: DownloadSegment, raf: RandomAccessFile) {
        val currentStart = segment.startByte + segment.downloadedBytes
        if (segment.endByte != Long.MAX_VALUE && currentStart > segment.endByte) return
        val rangeHeader = if (segment.endByte != Long.MAX_VALUE) "bytes=$currentStart-${segment.endByte}" else if (currentStart > 0) "bytes=$currentStart-" else null
        
        // Use resolved direct CDN URL so the token/redirect gateway is never replayed
        val targetUrl = task.finalUrl ?: task.url
        val conn = DownloadHttpHelper.openConnection(targetUrl, rangeHeader = rangeHeader, referer = task.referer)
        val code = conn.responseCode

        // Strict HTTP 206 vs 200 validation
        if (rangeHeader != null && code == 200 && segment.index > 0) {
            conn.disconnect()
            throw Exception("Server does not support ranges (HTTP 200 on chunk ${segment.index})")
        }
        if (!DownloadHttpHelper.validateRangeResponse(conn, currentStart, rangeHeader != null)) {
            val retryHeader = conn.getHeaderField("Retry-After")
            conn.disconnect()
            throw Exception("HTTP $code ${conn.responseMessage ?: ""} ${if (retryHeader != null) "Retry-After:$retryHeader" else ""}".trim())
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
        // Default cap 4 for safety, up to count
        val effectiveCount = if (total < 5 * 1024 * 1024) 1 else count.coerceIn(1, 6)
        val chunkSize = total / effectiveCount
        for (i in 0 until effectiveCount) {
            val start = i * chunkSize
            val end = if (i == effectiveCount - 1) total - 1 else (start + chunkSize - 1)
            task.segments.add(DownloadSegment(i, start, end))
        }
    }
}
