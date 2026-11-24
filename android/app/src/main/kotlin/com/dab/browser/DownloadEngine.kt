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
    companion object {
        // googlevideo 403s open-ended (bytes=N-) and ranges larger than ~16MB.
        // YouTube's own player fetches bounded slices; we do the same (8MB, safe margin).
        }

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
                task.errorMessage = if (msg.contains("403") || msg.contains("410")) "Download link expired â€” refresh link" else msg
                task.speedBytesPerSec = 0L; onProgressUpdate(task)
            }
        }
    }
    fun pause() { isPaused.set(true); downloadJob?.cancel(); task.status = DownloadStatus.PAUSED; task.speedBytesPerSec = 0L; onSaveSegments?.invoke(task.segments); onProgressUpdate(task) }
    fun cancel() { isCanceled.set(true); downloadJob?.cancel(); task.status = DownloadStatus.CANCELED; task.speedBytesPerSec = 0L; try { File("${task.destinationPath}.part").delete() } catch (_: Exception) {}; onProgressUpdate(task) }

    private suspend fun executeDownload() = withContext(Dispatchers.IO) {
        val isYt = task.url.contains("googlevideo.com") || task.audioUrl != null || (task.finalUrl?.contains("googlevideo.com") == true)
        if (task.totalBytes <= 0 || task.segments.isEmpty() || task.finalUrl == null) {
            if (!isYt || task.totalBytes <= 0) {
                val probe = DownloadHttpHelper.probeUrl(task.finalUrl ?: task.url, task.referer)
                task.finalUrl = probe.finalUrl; task.resolvedContentType = probe.contentType
                if (task.totalBytes <= 0 && probe.contentLength > 0) task.totalBytes = probe.contentLength + task.audioBytes
                if (!probe.suggestedFileName.isNullOrBlank()) {
                    val cur = File(task.destinationPath)
                    if (cur.name.startsWith("download_") || cur.name.startsWith("Resolving") || cur.name.endsWith(".bin")) { val p = cur.parent ?: ""; task.destinationPath = if (p.isNotEmpty()) "$p/${probe.suggestedFileName}" else probe.suggestedFileName }
                }
                onProgressUpdate(task)
                if (probe.contentType?.contains("text/html") == true && !task.destinationPath.endsWith(".html", true) && !task.destinationPath.endsWith(".htm", true)) throw Exception("Server returned a webpage instead of a file.")
            } else task.finalUrl = task.url
            val streamLen = if (task.audioBytes > 0 && task.totalBytes > task.audioBytes) task.totalBytes - task.audioBytes else task.totalBytes
            if (!isYt && streamLen > 0) partitionSegments(streamLen, task.segmentsCount) else { task.segments.clear(); task.segments.add(DownloadSegment(0, 0, if (streamLen > 0) streamLen - 1 else Long.MAX_VALUE)) }
        }

        val destFile = File(task.destinationPath); val partFile = File("${task.destinationPath}.part"); destFile.parentFile?.mkdirs()
        val raf = RandomAccessFile(partFile, "rw")
        val streamLen = if (task.audioBytes > 0 && task.totalBytes > task.audioBytes) task.totalBytes - task.audioBytes else task.totalBytes
        if (!isYt && streamLen > 0 && partFile.length() < streamLen) try { raf.setLength(streamLen) } catch (_: Exception) {}
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
                            task.errorMessage = if (msg.contains("403") || msg.contains("410")) "Download link expired â€” refresh link" else msg
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
            var zeroProgressSlices = 0
            val isYt = audioUrl.contains("googlevideo.com") || task.url.contains("googlevideo.com")
            val buf = ByteArray(32 * 1024)
            // Watchdog: googlevideo can leave a response open with no bytes for
            // minutes. If that happens, close the stream so the read fails and
            // the loop resumes with an open-ended range.
            var lastDataAt = System.currentTimeMillis()
            var activeStream: StreamResponse? = null
            val watchdog = Thread {
                try {
                    while (!isPaused.get() && !isCanceled.get()) {
                        Thread.sleep(1000)
                        if (System.currentTimeMillis() - lastDataAt > 20_000) {
                            Log.w("DLREFRESH", "audio watchdog: 20s without data, reconnecting")
                            try { activeStream?.close() } catch (_: Exception) {}
                            return@Thread
                        }
                    }
                } catch (_: InterruptedException) {}
            }
            watchdog.isDaemon = true
            watchdog.start()
            while (!isPaused.get() && !isCanceled.get()) {
                if (totalAudio > 0 && downloaded >= totalAudio) break
                val audioBase = task.audioUrl ?: audioUrl
                // Same contract as the video stream: one sequential GET, no
                // Range on a fresh start, open-ended range only when resuming.
                val requestUrl = audioBase
                val range = if (downloaded > 0L) "bytes=$downloaded-" else null
                Log.d("DLREFRESH", "downloadAudio req ${task.id} range=$range single=true cur=$downloaded")
                val stream = DownloadHttpHelper.openStream(requestUrl, rangeHeader = range, referer = task.referer)
                activeStream = stream
                lastDataAt = System.currentTimeMillis()
                Log.d("DLREFRESH", "downloadAudio resp ${task.id} code=${stream.code}")
                var sliceRead = 0L
                try {
                    val code = stream.code
                    if ((code == 403 || code == 410) && isYt) {
                        // Keep the bytes we have; the refreshed URL resumes here.
                        Log.w("DLREFRESH", "audio 403 at $downloaded (progress kept)")
                        throw LinkExpiredException()
                    }
                    val input = stream.byteStream
                    try {
                        while (!isPaused.get() && !isCanceled.get()) {
                            val n = input.read(buf, 0, buf.size)
                            if (n == -1) break
                            lastDataAt = System.currentTimeMillis()
                            synchronized(rafLock) { raf.seek(downloaded + sliceRead); raf.write(buf, 0, n) }
                            sliceRead += n; task.downloadedBytes += n; recalculateTotalDownloaded()
                        }
                    } catch (io: java.io.IOException) {
                        // Socket stall / reset: keep the bytes and resume with an
                        // open-ended range on the next pass (Snaptube behaviour).
                        Log.w("DLREFRESH", "audio stream cut at ${downloaded + sliceRead} (${io.message})")
                    }
                } finally { stream.close() }
                if (sliceRead == 0L) {
                    // Stream ended early with no new data. Retry a few times before giving up
                    // (YouTube routinely cuts connections; a fresh ranged request resumes fine).
                    zeroProgressSlices++
                    try { Thread.sleep(500L * zeroProgressSlices) } catch (_: Exception) {}
                    if (zeroProgressSlices >= 5) break
                } else { zeroProgressSlices = 0; downloaded += sliceRead }
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

    /// True when this task downloads YouTube's progressive (muxed) mp4, which
    /// is served as a plain file: no range parameter, no per-URL 8 MB quota.
    private fun downloadSegment(segment: DownloadSegment, raf: RandomAccessFile) {
        val isYt = task.url.contains("googlevideo.com") || task.audioUrl != null || (task.finalUrl?.contains("googlevideo.com") == true)
        val buffer = ByteArray(32 * 1024)
        var zeroProgressSlices = 0
        while (!isPaused.get() && !isCanceled.get() && !segment.isFinished) {
            val cur = segment.startByte + segment.downloadedBytes
            if (segment.endByte != Long.MAX_VALUE && cur > segment.endByte) break
            // Snaptube's engine contract (SingleThreadBlockDownloadTask):
            // exactly one request per URL, strictly sequential, no slicing.
            //  - fresh start: plain GET, no Range header at all
            //  - resume:      open-ended "bytes=$offset-" only
            // Closed chunks / sub-chunk loops are what trip the 403 firewall.
            val sliceEnd = segment.endByte
            val baseUrl = task.finalUrl ?: task.url
            val requestUrl = baseUrl
            val rangeHeader = if (cur > 0) "bytes=$cur-" else null
            val sliceStartBytes = segment.downloadedBytes
            Log.d("DLREFRESH", "downloadSegment req ${task.id} range=$rangeHeader single=true (isYt=$isYt cur=$cur)")
            val stream = DownloadHttpHelper.openStream(requestUrl, rangeHeader = rangeHeader, referer = task.referer)
            Log.d("DLREFRESH", "downloadSegment resp ${task.id} code=${stream.code}")
            try {
                val code = stream.code
                if ((code == 403 || code == 410) && isYt) {
                    // Keep what we already wrote: the refreshed URL continues
                    // from this offset instead of starting over.
                    Log.w("DLREFRESH", "YouTube 403 at offset $cur (progress kept). Requesting fresh URL.")
                    throw LinkExpiredException()
                }
                if (rangeHeader != null && code == 200) throw Exception("Server lacks range support")
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
                    if (bytesRead == -1) {
                        // Connection closed by the server (YouTube does this).
                        // If we are not at EOF the URL is spent: ask for a new
                        // one and resume from here with an open-ended range.
                        if (segment.startByte + segment.downloadedBytes < segment.endByte) {
                            if (isYt && segment.downloadedBytes > sliceStartBytes) {
                                Log.w("DLREFRESH", "stream cut at $cur/${segment.endByte}, reminting")
                                throw LinkExpiredException()
                            }
                        } else {
                            segment.downloadedBytes = segment.totalBytes
                        }
                        break
                    }
                    throttleBandwidth(bytesRead)
                    synchronized(rafLock) { raf.seek(segment.startByte + segment.downloadedBytes); raf.write(buffer, 0, bytesRead) }
                    segment.downloadedBytes += bytesRead; recalculateTotalDownloaded()
                }
            } finally { stream.close() }
            // Slice ended. Track zero-progress retries to avoid an infinite resume loop.
            if (segment.downloadedBytes == sliceStartBytes) { zeroProgressSlices++; try { Thread.sleep(500L * zeroProgressSlices) } catch (_: Exception) {} } else zeroProgressSlices = 0
            if (zeroProgressSlices >= 5) {
                if (segment.downloadedBytes > 0) {
                    // Fall back to treating the segment as done so mux can still be attempted.
                    segment.downloadedBytes = segment.totalBytes
                } else throw Exception("Stream ended prematurely with no data (HTTP stream repeatedly empty)")
            }
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
