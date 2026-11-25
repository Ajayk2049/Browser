package com.dab.browser

import android.util.Log
import kotlinx.coroutines.*
import java.io.File
import java.io.RandomAccessFile
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import kotlin.random.Random

class DownloadEngine(
    val task: DownloadTask,
    private val onSaveSegments: ((List<DownloadSegment>) -> Unit)? = null,
    private val onProgressUpdate: (DownloadTask) -> Unit
) {
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val isPaused = AtomicBoolean(false); private val isCanceled = AtomicBoolean(false)
    private val audioDownloadedBytes = AtomicLong(0L)
    private val extraHeaders: Map<String, String> by lazy { DownloadHttpHelper.parseHeadersJson(task.requestHeaders) }
    private val throttleLock = Any(); private var downloadJob: Job? = null
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
    fun cancel() {
        isCanceled.set(true); downloadJob?.cancel(); task.status = DownloadStatus.CANCELED; task.speedBytesPerSec = 0L
        try {
            File("${task.destinationPath}.part").delete()
            File("${task.destinationPath}.audio.part").delete()
            File("${task.destinationPath}.segs").deleteRecursively()
        } catch (_: Exception) {}
        onProgressUpdate(task)
    }

    private suspend fun executeDownload() = withContext(Dispatchers.IO) {
        val isYt = task.url.contains("googlevideo.com") || (task.finalUrl?.contains("googlevideo.com") == true) || (task.referer?.contains("youtube.com") == true)
        if (!isYt && PlaylistDownloadHelper.isPlaylist(task.url, task.resolvedContentType)) {
            val speedTracker = launch { trackSpeed() }
            try {
                val ok = PlaylistDownloadHelper.download(task, extraHeaders, isPaused, isCanceled) { onProgressUpdate(task) }
                if (ok && !isPaused.get() && !isCanceled.get()) {
                    task.status = DownloadStatus.COMPLETED; task.speedBytesPerSec = 0L; onProgressUpdate(task)
                }
            } finally { speedTracker.cancel() }
            return@withContext
        }
        if (task.totalBytes <= 0 || task.segments.isEmpty() || task.finalUrl == null) {
            if (!isYt || task.totalBytes <= 0) {
                val probe = DownloadHttpHelper.probeUrl(task.finalUrl ?: task.url, task.referer, extraHeaders)
                task.finalUrl = probe.finalUrl; task.resolvedContentType = probe.contentType
                if (!isYt && PlaylistDownloadHelper.isPlaylist(probe.finalUrl, probe.contentType)) {
                    val speedTracker = launch { trackSpeed() }
                    try {
                        val ok = PlaylistDownloadHelper.download(task, extraHeaders, isPaused, isCanceled) { onProgressUpdate(task) }
                        if (ok && !isPaused.get() && !isCanceled.get()) {
                            task.status = DownloadStatus.COMPLETED; task.speedBytesPerSec = 0L; onProgressUpdate(task)
                        }
                    } finally { speedTracker.cancel() }
                    return@withContext
                }
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
        val audio = task.audioUrl
        val audioPart = if (!audio.isNullOrBlank()) File("${task.destinationPath}.audio.part") else null
        audioDownloadedBytes.set(if (audioPart != null && audioPart.exists()) audioPart.length() else 0L)
        recalculateTotalDownloaded()
        task.status = DownloadStatus.DOWNLOADING; onProgressUpdate(task)

        val speedTracker = launch { trackSpeed() }; val activeJobs = mutableListOf<Job>()
        var audioOk = audioPart == null
        try {
            supervisorScope {
                for ((idx, segment) in task.segments.withIndex()) {
                    if (segment.isFinished || isPaused.get() || isCanceled.get()) continue
                    if (idx > 0) delay(750L)
                    if (isPaused.get() || isCanceled.get()) break
                    activeJobs.add(launch {
                        try { downloadSegmentWithRetry(segment, raf) } catch (_: CancellationException) {} catch (e: Exception) {
                            handleWorkerFailure(e, this@supervisorScope)
                        }
                    })
                }
                if (audioPart != null && !audio.isNullOrBlank() && !isPaused.get() && !isCanceled.get()) {
                    activeJobs.add(launch {
                        try {
                            runWithTransientRetry(isDone = { audioOk || isPaused.get() || isCanceled.get() }) {
                                audioOk = downloadAudioDirect(audio, audioPart)
                                if (!audioOk && !isPaused.get() && !isCanceled.get()) throw Exception("Failed to download audio track")
                            }
                        } catch (_: CancellationException) {} catch (e: Exception) {
                            handleWorkerFailure(e, this@supervisorScope)
                        }
                    })
                }
                activeJobs.joinAll()
            }
            if (task.status == DownloadStatus.LINK_EXPIRED || task.status == DownloadStatus.FAILED) return@withContext
            if (!isPaused.get() && !isCanceled.get() && task.segments.isNotEmpty() && task.segments.all { it.isFinished }) {
                synchronized(raf) { try { raf.close() } catch (_: Exception) {} }
                if (audioPart != null) {
                    if (!audioOk) throw Exception("Failed to download audio track")
                    task.speedBytesPerSec = 0L; onProgressUpdate(task)
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
            synchronized(raf) { try { raf.close() } catch (_: Exception) {} }
        }
    }

    private fun downloadAudioDirect(audioUrl: String, destFile: File): Boolean {
        destFile.parentFile?.mkdirs()
        val raf = RandomAccessFile(destFile, "rw")
        return try {
            val totalAudio = if (task.audioBytes > 0) task.audioBytes else {
                val probe = DownloadHttpHelper.probeUrl(audioUrl, task.referer, extraHeaders)
                if (probe.contentLength > 0) { task.audioBytes = probe.contentLength; probe.contentLength } else -1L
            }
            var downloaded = destFile.length()
            var audioEofCompleted = false
            audioDownloadedBytes.set(downloaded)
            recalculateTotalDownloaded()
            val isYt = audioUrl.contains("googlevideo.com") || task.url.contains("googlevideo.com")
            streamSequentially(
                label = "audio",
                raf = raf,
                isYt = isYt,
                maxSliceBytes = if (isYt && totalAudio > 0) 1_048_576L else 0L,
                urlProvider = { task.audioUrl ?: audioUrl },
                offsetProvider = { downloaded },
                remainingProvider = {
                    if (audioEofCompleted) 0L
                    else if (totalAudio > 0) (totalAudio - downloaded).coerceAtLeast(0L)
                    else Long.MAX_VALUE
                },
                onBytesWritten = { n -> downloaded += n; audioDownloadedBytes.set(downloaded); recalculateTotalDownloaded() },
                onEofReached = {
                    if (totalAudio <= 0 || downloaded >= totalAudio) audioEofCompleted = true
                },
                onZeroProgressLimit = { audioEofCompleted = true },
            )
            destFile.exists() && destFile.length() > 0 && (totalAudio <= 0 || destFile.length() >= totalAudio)
        } finally { try { raf.close() } catch (_: Exception) {} }
    }

    private fun handleWorkerFailure(e: Exception, workerScope: CoroutineScope) {
        if (isPaused.get() || isCanceled.get()) return
        if (e is LinkExpiredException) {
            task.status = DownloadStatus.LINK_EXPIRED; task.errorMessage = "LINK_EXPIRED"; task.speedBytesPerSec = 0L
            onSaveSegments?.invoke(task.segments); onProgressUpdate(task); workerScope.cancel()
        } else {
            task.status = DownloadStatus.FAILED; val msg = e.message ?: "Download failed"
            task.errorMessage = if (msg.contains("403") || msg.contains("410")) "Download link expired — refresh link" else msg
            task.speedBytesPerSec = 0L; onProgressUpdate(task); workerScope.cancel()
        }
    }

    private suspend fun downloadSegmentWithRetry(segment: DownloadSegment, raf: RandomAccessFile) =
        runWithTransientRetry(isDone = { segment.isFinished }) { downloadSegment(segment, raf) }

    private suspend fun runWithTransientRetry(isDone: () -> Boolean, block: () -> Unit) {
        var attempts = 0
        while (attempts < 5 && !isPaused.get() && !isCanceled.get() && !isDone()) {
            try { block(); return } catch (e: Exception) {
                if (e is LinkExpiredException) throw e
                if (isPaused.get() || isCanceled.get()) return
                attempts++
                val msg = e.message ?: ""
                val isRetryable = msg.contains("429") || msg.contains("503") || msg.contains("504") || msg.contains("408") ||
                    msg.contains("timeout", true) || e is java.net.SocketTimeoutException || e is java.net.ConnectException ||
                    e is java.net.UnknownHostException || e is DnsResolutionException
                if (!isRetryable || attempts >= 5) throw e
                val retryAfter = DownloadHttpHelper.parseRetryAfter(msg.substringAfter("Retry-After:", "").trim())
                delay((retryAfter ?: ((2000L * (1 shl (attempts - 1))) + Random.nextLong(200, 800))).coerceIn(1000L, 60000L))
            }
        }
    }

    private fun downloadSegment(segment: DownloadSegment, raf: RandomAccessFile) {
        val isYt = task.url.contains("googlevideo.com") || task.audioUrl != null || (task.finalUrl?.contains("googlevideo.com") == true)
        val isYtAudioOnly = isYt && task.audioUrl == null &&
            (task.url.contains("mime=audio") || task.url.contains("mime%3Daudio")) &&
            segment.endByte != Long.MAX_VALUE
        streamSequentially(
            label = "video",
            raf = raf,
            isYt = isYt,
            maxSliceBytes = if (isYtAudioOnly) 1_048_576L else 0L,
            urlProvider = { task.finalUrl ?: task.url },
            offsetProvider = { segment.startByte + segment.downloadedBytes },
            remainingProvider = {
                if (segment.isFinished) 0L
                else if (segment.endByte != Long.MAX_VALUE) (segment.endByte - (segment.startByte + segment.downloadedBytes) + 1).coerceAtLeast(0L)
                else Long.MAX_VALUE
            },
            onBytesWritten = { n -> segment.downloadedBytes += n; recalculateTotalDownloaded() },
            onEofReached = {
                if (segment.endByte == Long.MAX_VALUE || segment.startByte + segment.downloadedBytes >= segment.endByte) {
                    segment.downloadedBytes = segment.totalBytes
                }
            },
            onZeroProgressLimit = {
                if (segment.downloadedBytes > 0) segment.downloadedBytes = segment.totalBytes
                else throw Exception("Stream ended prematurely with no data (HTTP stream repeatedly empty)")
            },
        )
    }

    /** Snaptube SingleThreadBlockDownloadTask contract + 1MB bounded range slicing for YT audio pacing. */
    private fun streamSequentially(
        label: String,
        raf: RandomAccessFile,
        isYt: Boolean,
        maxSliceBytes: Long,
        urlProvider: () -> String,
        offsetProvider: () -> Long,
        remainingProvider: () -> Long,
        onBytesWritten: (Int) -> Unit,
        onEofReached: () -> Unit,
        onZeroProgressLimit: () -> Unit,
    ) {
        val buffer = ByteArray(32 * 1024)
        var zeroProgressSlices = 0
        var boundedSlices = maxSliceBytes > 0L
        var lastDataAt = System.currentTimeMillis()
        var activeStream: StreamResponse? = null
        val watchdog = Thread {
            try {
                while (!isPaused.get() && !isCanceled.get() && remainingProvider() > 0L && !Thread.currentThread().isInterrupted) {
                    Thread.sleep(1000)
                    if (System.currentTimeMillis() - lastDataAt > 20_000) {
                        Log.w("DLREFRESH", "$label watchdog: 20s without data, reconnecting")
                        try { activeStream?.close() } catch (_: Exception) {}
                        lastDataAt = System.currentTimeMillis()
                    }
                }
            } catch (_: InterruptedException) {}
        }.apply { isDaemon = true; start() }

        try {
            while (!isPaused.get() && !isCanceled.get() && remainingProvider() > 0L) {
                val cur = offsetProvider()
                val totalRem = remainingProvider()
                val rangeHeader = when {
                    boundedSlices -> "bytes=$cur-${cur + minOf(maxSliceBytes, totalRem) - 1}"
                    cur > 0L -> "bytes=$cur-"
                    else -> null
                }
                Log.d("DLREFRESH", "$label req ${task.id} range=$rangeHeader single=true (isYt=$isYt cur=$cur)")
                val stream = DownloadHttpHelper.openStream(urlProvider(), rangeHeader = rangeHeader, referer = task.referer, extraHeaders = extraHeaders)
                activeStream = stream
                lastDataAt = System.currentTimeMillis()
                Log.d("DLREFRESH", "$label resp ${task.id} code=${stream.code}")
                var sliceRead = 0L
                try {
                    val code = stream.code
                    if ((code == 403 || code == 410) && isYt) {
                        if (boundedSlices) {
                            Log.w("DLREFRESH", "$label $code on bounded range, falling back to open-ended")
                            boundedSlices = false
                            continue
                        }
                        Log.w("DLREFRESH", "$label $code at offset $cur (progress kept). Requesting fresh URL.")
                        throw LinkExpiredException()
                    }
                    if (cur > 0L && code == 200) throw Exception("Server lacks range support")
                    if (!DownloadHttpHelper.validateRangeResponse(stream, cur, rangeHeader != null)) {
                        val r = stream.header("Retry-After")
                        throw Exception("HTTP $code ${if (r != null) "Retry-After:$r" else ""}".trim())
                    }
                    val input = stream.byteStream
                    while (!isPaused.get() && !isCanceled.get()) {
                        val rem = remainingProvider()
                        if (rem <= 0L) break
                        val toRead = minOf(rem, buffer.size.toLong()).toInt()
                        val bytesRead = input.read(buffer, 0, toRead)
                        if (bytesRead == -1) { onEofReached(); break }
                        lastDataAt = System.currentTimeMillis()
                        throttleBandwidth(bytesRead)
                        synchronized(raf) { raf.seek(cur + sliceRead); raf.write(buffer, 0, bytesRead) }
                        sliceRead += bytesRead
                        onBytesWritten(bytesRead)
                    }
                } catch (io: java.io.IOException) {
                    Log.w("DLREFRESH", "$label stream IO cut at ${cur + sliceRead} (${io.message})")
                } finally { activeStream = null; stream.close() }

                if (sliceRead == 0L) {
                    zeroProgressSlices++
                    if (zeroProgressSlices >= 3 && isYt && offsetProvider() > 0L) throw LinkExpiredException()
                    try { Thread.sleep(500L * zeroProgressSlices) } catch (_: Exception) {}
                    if (zeroProgressSlices >= 5) { onZeroProgressLimit(); break }
                } else {
                    zeroProgressSlices = 0
                }
            }
        } finally { watchdog.interrupt() }
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
        task.downloadedBytes = v + audioDownloadedBytes.get()
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
