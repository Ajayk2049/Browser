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
        isPaused.set(false); isCanceled.set(false); task.status = DownloadStatus.CONNECTING; onProgressUpdate(task)
        downloadJob = scope.launch {
            try { executeDownload() } catch (_: CancellationException) {} catch (e: Exception) {
                task.status = DownloadStatus.FAILED; task.errorMessage = e.message ?: "Download failed"; task.speedBytesPerSec = 0L; onProgressUpdate(task)
            }
        }
    }
    fun pause() { isPaused.set(true); downloadJob?.cancel(); task.status = DownloadStatus.PAUSED; task.speedBytesPerSec = 0L; onSaveSegments?.invoke(task.segments); onProgressUpdate(task) }
    fun cancel() { isCanceled.set(true); downloadJob?.cancel(); task.status = DownloadStatus.CANCELED; task.speedBytesPerSec = 0L; try { File("${task.destinationPath}.part").delete() } catch (_: Exception) {}; onProgressUpdate(task) }

    private suspend fun executeDownload() = withContext(Dispatchers.IO) {
        // 1. Single pre-flight request (resolves final URL, Content-Range size & Content-Type)
        if (task.totalBytes <= 0 || task.segments.isEmpty() || task.finalUrl == null) {
            val probe = DownloadHttpHelper.probeUrl(task.finalUrl ?: task.url, task.referer)
            task.finalUrl = probe.finalUrl
            task.resolvedContentType = probe.contentType
            if (task.totalBytes <= 0 && probe.contentLength > 0) task.totalBytes = probe.contentLength

            if (!probe.suggestedFileName.isNullOrBlank()) {
                val currentFile = File(task.destinationPath)
                val currentName = currentFile.name
                if (currentName.startsWith("download_") || currentName.startsWith("Resolving") || currentName.endsWith(".bin")) {
                    val parent = currentFile.parent ?: ""
                    task.destinationPath = if (parent.isNotEmpty()) "$parent/${probe.suggestedFileName}" else probe.suggestedFileName!!
                }
            }
            onProgressUpdate(task)

            val isHtml = probe.contentType?.contains("text/html") == true
            val isExpectedHtml = task.destinationPath.endsWith(".html", true) || task.destinationPath.endsWith(".htm", true)
            if (isHtml && !isExpectedHtml) throw Exception("Server returned a webpage instead of a file.")
            if (probe.supportsRanges && task.totalBytes > 0) {
                partitionSegments(task.totalBytes, task.segmentsCount)
            } else {
                task.segments.clear(); task.segments.add(DownloadSegment(0, 0, if (task.totalBytes > 0) task.totalBytes - 1 else Long.MAX_VALUE))
            }
        }

        val destFile = File(task.destinationPath)
        val partFile = File("${task.destinationPath}.part")
        destFile.parentFile?.mkdirs()

        val raf = RandomAccessFile(partFile, "rw")
        if (task.totalBytes > 0 && partFile.length() < task.totalBytes) {
            try { raf.setLength(task.totalBytes) } catch (_: Exception) {}
        }

        task.status = DownloadStatus.DOWNLOADING
        onProgressUpdate(task)

        val speedTracker = launch { trackSpeed() }
        val activeJobs = mutableListOf<Job>()
        try {
            supervisorScope {
                for ((idx, segment) in task.segments.withIndex()) {
                    if (segment.isFinished || isPaused.get() || isCanceled.get()) continue
                    if (idx > 0) delay(750L)
                    if (isPaused.get() || isCanceled.get()) break
                    val job = launch { downloadSegmentWithRetry(segment, raf) }
                    activeJobs.add(job)
                }
                activeJobs.joinAll()
            }

            if (!isPaused.get() && !isCanceled.get()) {
                val allFinished = task.segments.isNotEmpty() && task.segments.all { it.isFinished }
                if (allFinished) {
                    synchronized(rafLock) { try { raf.close() } catch (_: Exception) {} }
                    val audio = task.audioUrl
                    if (!audio.isNullOrBlank()) {
                        task.status = DownloadStatus.CONNECTING; onProgressUpdate(task)
                        val audioPart = File("${task.destinationPath}.audio.part")
                        val audioOk = downloadAudioDirect(audio, audioPart)
                        if (audioOk && MediaMuxerHelper.mux(partFile, audioPart, destFile)) {
                            try { partFile.delete(); audioPart.delete() } catch (_: Exception) {}
                        } else {
                            if (destFile.exists()) destFile.delete()
                            partFile.renameTo(destFile)
                        }
                    } else {
                        if (destFile.exists()) destFile.delete()
                        partFile.renameTo(destFile)
                    }
                    task.status = DownloadStatus.COMPLETED
                    task.speedBytesPerSec = 0L
                    onProgressUpdate(task)
                }
            }
        } finally {
            speedTracker.cancel()
            activeJobs.forEach { it.cancel() }
            activeJobs.joinAll()
            synchronized(rafLock) { try { raf.close() } catch (_: Exception) {} }
        }
    }

    private fun downloadAudioDirect(audioUrl: String, destFile: File): Boolean = try {
        val conn = DownloadHttpHelper.openConnection(audioUrl, referer = task.referer)
        val input = conn.inputStream
        val output = destFile.outputStream()
        val buf = ByteArray(32 * 1024)
        var n: Int
        while (input.read(buf).also { n = it } != -1) {
            if (isPaused.get() || isCanceled.get()) break
            output.write(buf, 0, n)
        }
        output.flush()
        try { input.close() } catch (_: Exception) {}
        try { output.close() } catch (_: Exception) {}
        conn.disconnect()
        true
    } catch (_: Exception) { false }

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
            while (!isPaused.get() && !isCanceled.get()) {
                val remaining = if (segment.endByte != Long.MAX_VALUE) {
                    (segment.endByte - (segment.startByte + segment.downloadedBytes) + 1).coerceAtLeast(0L)
                } else Long.MAX_VALUE
                if (remaining <= 0) break
                val toRead = if (remaining < buffer.size) remaining.toInt() else buffer.size
                bytesRead = input.read(buffer, 0, toRead)
                if (bytesRead == -1) break
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
            conn.disconnect()
        }
    }

    private fun throttleBandwidth(bytesRead: Int) {
        val limit = speedLimitBytesPerSec
        if (limit <= 0) return
        synchronized(throttleLock) {
            bytesInWindow += bytesRead
            val now = System.currentTimeMillis(); val elapsed = now - lastThrottleTime
            if (elapsed < 1000 && bytesInWindow >= limit) {
                val waitMs = 1000 - elapsed
                if (waitMs > 0) try { Thread.sleep(waitMs) } catch (e: Exception) {}
                bytesInWindow = 0L; lastThrottleTime = System.currentTimeMillis()
            } else if (elapsed >= 1000) { bytesInWindow = 0L; lastThrottleTime = now }
        }
    }

    private fun recalculateTotalDownloaded() { task.downloadedBytes = synchronized(task.segments) { task.segments.sumOf { it.downloadedBytes } } }

    private suspend fun trackSpeed() {
        var lastBytes = task.downloadedBytes; var lastTime = System.currentTimeMillis()
        while (true) {
            delay(250)
            val now = System.currentTimeMillis(); val currentBytes = task.downloadedBytes; val elapsedSec = (now - lastTime) / 1000.0
            if (elapsedSec > 0) task.speedBytesPerSec = ((currentBytes - lastBytes) / elapsedSec).toLong().coerceAtLeast(0L)
            lastBytes = currentBytes; lastTime = now
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
