package com.dab.browser

import android.util.Log
import kotlinx.coroutines.*
import java.io.File
import java.io.RandomAccessFile
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.random.Random

class DownloadEngine(
    val task: DownloadTask,
    private val onSaveSegments: ((List<DownloadSegment>) -> Unit)? = null,
    private val onProgressUpdate: (DownloadTask) -> Unit
) {
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val isPaused = AtomicBoolean(false); private val isCanceled = AtomicBoolean(false)
    private val rafLock = Any(); private val throttleLock = Any(); private var downloadJob: Job? = null
    @Volatile var speedLimitBytesPerSec: Long = task.speedLimitBytesPerSec
    private var lastThrottleTime = System.currentTimeMillis(); private var bytesInWindow = 0L

    fun setSpeedLimit(bytesPerSec: Long) { speedLimitBytesPerSec = bytesPerSec; task.speedLimitBytesPerSec = bytesPerSec }; fun shutdown() { isPaused.set(true); downloadJob?.cancel() }
    fun start(forceRestart: Boolean = false) {
        if (!forceRestart && task.status == DownloadStatus.DOWNLOADING) { Log.d("DLREFRESH", "start() early return hit for ${task.id}"); return }
        isPaused.set(false); isCanceled.set(false); task.status = DownloadStatus.CONNECTING; onProgressUpdate(task)
        Log.d("DLREFRESH", "start() launching job for ${task.id} (force=$forceRestart)")
        downloadJob = scope.launch {
            try { executeDownload() } catch (_: CancellationException) {} catch (e: LinkExpiredException) {
                Log.w("DLREFRESH", "engine: emitted LINK_EXPIRED for ${task.id}")
                task.status = DownloadStatus.LINK_EXPIRED; task.errorMessage = "LINK_EXPIRED"; task.speedBytesPerSec = 0L; onSaveSegments?.invoke(task.segments); onProgressUpdate(task)
            } catch (e: Exception) {
                task.status = DownloadStatus.FAILED; val msg = e.message ?: "Download failed"
                task.errorMessage = if (msg.contains("403") || msg.contains("410")) "Download link expired — refresh link" else msg
                task.speedBytesPerSec = 0L; onProgressUpdate(task)
            }
        }
    }
    fun pause() { isPaused.set(true); downloadJob?.cancel(); task.status = DownloadStatus.PAUSED; task.speedBytesPerSec = 0L; onSaveSegments?.invoke(task.segments); onProgressUpdate(task) }
    fun cancel() { isCanceled.set(true); downloadJob?.cancel(); task.status = DownloadStatus.CANCELED; task.speedBytesPerSec = 0L; try { File("${task.destinationPath}.part").delete() } catch (_: Exception) {}; onProgressUpdate(task) }

    private suspend fun executeDownload() = withContext(Dispatchers.IO) {
        if (task.totalBytes <= 0 || task.segments.isEmpty() || task.finalUrl == null) {
            val probe = DownloadHttpHelper.probeUrl(task.finalUrl ?: task.url, task.referer)
            task.finalUrl = probe.finalUrl; task.resolvedContentType = probe.contentType
            if (task.totalBytes <= 0 && probe.contentLength > 0) task.totalBytes = probe.contentLength + task.audioBytes
            if (!probe.suggestedFileName.isNullOrBlank()) {
                val cur = File(task.destinationPath)
                if (cur.name.startsWith("download_") || cur.name.startsWith("Resolving") || cur.name.endsWith(".bin")) {
                    val p = cur.parent ?: ""; task.destinationPath = if (p.isNotEmpty()) "$p/${probe.suggestedFileName}" else probe.suggestedFileName
                }
            }
            onProgressUpdate(task)
            if (probe.contentType?.contains("text/html") == true && !task.destinationPath.endsWith(".html", true) && !task.destinationPath.endsWith(".htm", true)) throw Exception("Server returned a webpage instead of a file.")
            val streamLen = if (task.audioBytes > 0 && task.totalBytes > task.audioBytes) task.totalBytes - task.audioBytes else if (probe.contentLength > 0) probe.contentLength else task.totalBytes
            if (probe.supportsRanges && streamLen > 0) partitionSegments(streamLen, task.segmentsCount)
            else { task.segments.clear(); task.segments.add(DownloadSegment(0, 0, if (streamLen > 0) streamLen - 1 else Long.MAX_VALUE)) }
        }

        val destFile = File(task.destinationPath); val partFile = File("${task.destinationPath}.part"); destFile.parentFile?.mkdirs()
        val raf = RandomAccessFile(partFile, "rw")
        val streamLen = if (task.audioBytes > 0 && task.totalBytes > task.audioBytes) task.totalBytes - task.audioBytes else task.totalBytes
        if (streamLen > 0 && partFile.length() < streamLen) try { raf.setLength(streamLen) } catch (_: Exception) {}
        task.status = DownloadStatus.DOWNLOADING; onProgressUpdate(task)

        val speedTracker = launch { trackSpeed() }; val activeJobs = mutableListOf<Job>()
        try {
            supervisorScope {
                for ((idx, segment) in task.segments.withIndex()) {
                    if (segment.isFinished || isPaused.get() || isCanceled.get()) continue
                    if (idx > 0) delay(750L)
                    if (isPaused.get() || isCanceled.get()) break
                    activeJobs.add(launch {
                        try { downloadSegmentWithRetry(segment, raf) } catch (_: CancellationException) {} catch (e: LinkExpiredException) {
                            task.status = DownloadStatus.LINK_EXPIRED; task.errorMessage = "LINK_EXPIRED"; task.speedBytesPerSec = 0L
                            onSaveSegments?.invoke(task.segments); onProgressUpdate(task); this@supervisorScope.cancel()
                        } catch (e: Exception) {
                            task.status = DownloadStatus.FAILED; val msg = e.message ?: "Download failed"
                            task.errorMessage = if (msg.contains("403") || msg.contains("410")) "Download link expired — refresh link" else msg
                            task.speedBytesPerSec = 0L; onProgressUpdate(task)
                        }
                    })
                }
                activeJobs.joinAll()
            }
            if (task.status == DownloadStatus.LINK_EXPIRED) return@withContext
            if (!isPaused.get() && !isCanceled.get() && task.segments.isNotEmpty() && task.segments.all { it.isFinished }) {
                synchronized(rafLock) { try { raf.close() } catch (_: Exception) {} }
                val audio = task.audioUrl
                if (!audio.isNullOrBlank()) {
                    task.status = DownloadStatus.CONNECTING; onProgressUpdate(task)
                    val audioPart = File("${task.destinationPath}.audio.part")
                    val audioOk = downloadAudioDirect(audio, audioPart)
                    if (task.status == DownloadStatus.LINK_EXPIRED) return@withContext
                    if (!audioOk) throw Exception("Failed to download audio track")
                    val mux = MediaMuxerHelper.mux(partFile, audioPart, destFile)
                    if (!mux.success) throw Exception("Hardware muxing failed: ${mux.reason}")
                    try { partFile.delete(); audioPart.delete() } catch (_: Exception) {}
                } else {
                    if (destFile.exists()) destFile.delete(); partFile.renameTo(destFile)
                }
                task.status = DownloadStatus.COMPLETED; task.speedBytesPerSec = 0L; onProgressUpdate(task)
            }
        } finally {
            speedTracker.cancel(); activeJobs.forEach { it.cancel() }; activeJobs.joinAll()
            synchronized(rafLock) { try { raf.close() } catch (_: Exception) {} }
        }
    }

    private fun downloadAudioDirect(audioUrl: String, destFile: File): Boolean = try {
        destFile.parentFile?.mkdirs()
        val raf = RandomAccessFile(destFile, "rw")
        try {
            val totalAudio = if (task.audioBytes > 0) task.audioBytes else {
                val probe = DownloadHttpHelper.probeUrl(audioUrl, task.referer)
                if (probe.contentLength > 0) { task.audioBytes = probe.contentLength; probe.contentLength } else -1L
            }
            var downloaded = destFile.length()
            val isYt = audioUrl.contains("googlevideo.com") || task.url.contains("googlevideo.com")
            val buf = ByteArray(32 * 1024)
            while (!isPaused.get() && !isCanceled.get()) {
                if (totalAudio > 0 && downloaded >= totalAudio) break
                val sliceEnd = if (totalAudio > 0) totalAudio - 1 else Long.MAX_VALUE
                val range = if (sliceEnd != Long.MAX_VALUE) "bytes=$downloaded-$sliceEnd" else if (downloaded > 0) "bytes=$downloaded-" else null
                val stream = DownloadHttpHelper.openStream(task.audioUrl ?: audioUrl, rangeHeader = range, referer = task.referer)
                var sliceRead = 0L
                try {
                    val code = stream.code
                    if ((code == 403 || code == 410) && isYt) {
                        if (downloaded > 0) {
                            try { synchronized(rafLock) { raf.setLength(0L); raf.seek(0L) } } catch (_: Exception) {}
                            downloaded = 0L
                        }
                        throw LinkExpiredException()
                    }
                    val input = stream.byteStream
                    while (!isPaused.get() && !isCanceled.get()) {
                        val rem = if (sliceEnd != Long.MAX_VALUE) (sliceEnd - (downloaded + sliceRead) + 1).coerceAtLeast(0L) else Long.MAX_VALUE
                        if (rem <= 0) break
                        val toRead = if (rem < buf.size) rem.toInt() else buf.size
                        val n = input.read(buf, 0, toRead)
                        if (n == -1) break
                        synchronized(rafLock) { raf.seek(downloaded + sliceRead); raf.write(buf, 0, n) }
                        sliceRead += n; task.downloadedBytes += n; recalculateTotalDownloaded()
                    }
                } finally { stream.close() }
                if (sliceRead == 0L) break
                downloaded += sliceRead
            }
            destFile.exists() && destFile.length() > 0 && (totalAudio <= 0 || destFile.length() >= totalAudio)
        } finally { try { raf.close() } catch (_: Exception) {} }
    } catch (e: LinkExpiredException) {
        task.status = DownloadStatus.LINK_EXPIRED; task.errorMessage = "LINK_EXPIRED"; task.speedBytesPerSec = 0L; onSaveSegments?.invoke(task.segments); onProgressUpdate(task); false
    } catch (e: Exception) { Log.e("DownloadEngine", "Audio error: $e", e); false }

    private suspend fun downloadSegmentWithRetry(segment: DownloadSegment, raf: RandomAccessFile) {
        var attempts = 0
        while (attempts < 5 && !isPaused.get() && !isCanceled.get() && !segment.isFinished) {
            try { downloadSegment(segment, raf); return } catch (e: Exception) {
                if (e is LinkExpiredException) throw e
                if (isPaused.get() || isCanceled.get()) return
                attempts++
                val msg = e.message ?: ""
                val isRetryable = msg.contains("429") || msg.contains("503") || msg.contains("504") || msg.contains("408") ||
                    msg.contains("timeout", true) || e is java.net.SocketTimeoutException || e is java.net.ConnectException ||
                    e is java.net.UnknownHostException || e is DnsResolutionException
                if (!isRetryable || attempts >= 5) throw e
                val retryAfter = DownloadHttpHelper.parseRetryAfter(msg.substringAfter("Retry-After:", "").trim())
                val backoff = retryAfter ?: ((2000L * (1 shl (attempts - 1))) + Random.nextLong(200, 800))
                delay(backoff.coerceIn(1000L, 60000L))
            }
        }
    }

    private fun downloadSegment(segment: DownloadSegment, raf: RandomAccessFile) {
        val isYt = task.url.contains("googlevideo.com") || task.audioUrl != null || (task.finalUrl?.contains("googlevideo.com") == true)
        val buffer = ByteArray(32 * 1024)
        while (!isPaused.get() && !isCanceled.get() && !segment.isFinished) {
            val cur = segment.startByte + segment.downloadedBytes
            if (segment.endByte != Long.MAX_VALUE && cur > segment.endByte) break
            val sliceEnd = segment.endByte
            val rangeHeader = if (sliceEnd != Long.MAX_VALUE) "bytes=$cur-$sliceEnd" else if (cur > 0) "bytes=$cur-" else null
            Log.d("DLREFRESH", "downloadSegment req ${task.id} range=$rangeHeader")
            val stream = DownloadHttpHelper.openStream(task.finalUrl ?: task.url, rangeHeader = rangeHeader, referer = task.referer)
            Log.d("DLREFRESH", "downloadSegment resp ${task.id} code=${stream.code}")
            try {
                val code = stream.code
                if ((code == 403 || code == 410) && isYt) {
                    if (cur > 0) {
                        Log.w("DLREFRESH", "YouTube 403 at offset $cur. Truncating .part to 0 to restart.")
                        synchronized(rafLock) { try { raf.setLength(0L); raf.seek(0L) } catch (_: Exception) {} }
                        task.downloadedBytes = 0L; segment.downloadedBytes = 0L; recalculateTotalDownloaded()
                    }
                    throw LinkExpiredException()
                }
                if (rangeHeader != null && code == 200 && segment.index > 0) throw Exception("Server lacks range support")
                if (!DownloadHttpHelper.validateRangeResponse(stream, cur, rangeHeader != null)) {
                    val r = stream.header("Retry-After")
                    throw Exception("HTTP $code ${if (r != null) "Retry-After:$r" else ""}".trim())
                }
                val input = stream.byteStream
                while (!isPaused.get() && !isCanceled.get()) {
                    val rem = if (sliceEnd != Long.MAX_VALUE) (sliceEnd - (segment.startByte + segment.downloadedBytes) + 1).coerceAtLeast(0L) else Long.MAX_VALUE
                    if (rem <= 0) break
                    val toRead = if (rem < buffer.size) rem.toInt() else buffer.size
                    val bytesRead = input.read(buffer, 0, toRead)
                    if (bytesRead == -1) break
                    throttleBandwidth(bytesRead)
                    synchronized(rafLock) { raf.seek(segment.startByte + segment.downloadedBytes); raf.write(buffer, 0, bytesRead) }
                    segment.downloadedBytes += bytesRead; recalculateTotalDownloaded()
                }
            } finally { stream.close() }
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
                if (waitMs > 0) try { Thread.sleep(waitMs) } catch (_: Exception) {}
                bytesInWindow = 0L; lastThrottleTime = System.currentTimeMillis()
            } else if (elapsed >= 1000) { bytesInWindow = 0L; lastThrottleTime = now }
        }
    }

    private fun recalculateTotalDownloaded() {
        val v = synchronized(task.segments) { task.segments.sumOf { it.downloadedBytes } }
        task.downloadedBytes = v + if (task.audioUrl != null) (task.downloadedBytes - v).coerceAtLeast(0L) else 0L
    }

    private suspend fun trackSpeed() {
        var lastBytes = task.downloadedBytes; var lastTime = System.currentTimeMillis()
        while (true) {
            delay(250); val now = System.currentTimeMillis(); val cur = task.downloadedBytes; val el = (now - lastTime) / 1000.0
            if (el > 0) task.speedBytesPerSec = ((cur - lastBytes) / el).toLong().coerceAtLeast(0L)
            lastBytes = cur; lastTime = now; if (task.status == DownloadStatus.DOWNLOADING) onProgressUpdate(task)
        }
    }

    private fun partitionSegments(total: Long, count: Int) {
        task.segments.clear(); val isYt = task.url.contains("googlevideo.com") || task.audioUrl != null
        val cnt = if (isYt || total < 5 * 1024 * 1024) 1 else count.coerceIn(1, 6); val chunk = total / cnt
        for (i in 0 until cnt) task.segments.add(DownloadSegment(i, i * chunk, if (i == cnt - 1) total - 1 else ((i + 1) * chunk - 1)))
    }
}
