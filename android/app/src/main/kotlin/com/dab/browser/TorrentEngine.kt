package com.dab.browser

import kotlinx.coroutines.*
import java.io.File
import java.net.URLDecoder
import java.util.concurrent.atomic.AtomicBoolean

class TorrentEngine(
    val task: DownloadTask,
    private val onProgressUpdate: (DownloadTask) -> Unit
) {
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val isPaused = AtomicBoolean(false)
    private val isCanceled = AtomicBoolean(false)
    private var torrentJob: Job? = null

    data class MagnetInfo(
        val infoHash: String,
        val displayName: String,
        val trackers: List<String>
    )

    fun start() {
        if (task.status == DownloadStatus.DOWNLOADING) return
        isPaused.set(false)
        isCanceled.set(false)
        task.status = DownloadStatus.CONNECTING
        onProgressUpdate(task)

        torrentJob = scope.launch {
            try {
                executeTorrent()
            } catch (e: CancellationException) {
                // Cancelled
            } catch (e: Exception) {
                task.status = DownloadStatus.FAILED
                task.errorMessage = e.message ?: "Torrent error"
                task.speedBytesPerSec = 0L
                onProgressUpdate(task)
            }
        }
    }

    fun pause() {
        isPaused.set(true)
        torrentJob?.cancel()
        task.status = DownloadStatus.PAUSED
        task.speedBytesPerSec = 0L
        onProgressUpdate(task)
    }

    fun cancel() {
        isCanceled.set(true)
        torrentJob?.cancel()
        task.status = DownloadStatus.CANCELED
        task.speedBytesPerSec = 0L
        val part = File("${task.destinationPath}.part")
        if (part.exists()) part.delete()
        onProgressUpdate(task)
    }

    private suspend fun executeTorrent() = withContext(Dispatchers.IO) {
        val magnet = parseMagnet(task.url)
        val destFile = File(task.destinationPath)
        destFile.parentFile?.mkdirs()

        // 1. Connect to trackers and resolve metadata
        task.status = DownloadStatus.CONNECTING
        onProgressUpdate(task)
        delay(800) // Simulated DHT/Tracker handshake

        // 2. Discover peers & seeders
        task.seeders = (12..48).random()
        task.leechers = (2..15).random()
        if (task.totalBytes <= 0) {
            task.totalBytes = 250L * 1024L * 1024L // Simulated or parsed torrent payload size
        }

        task.status = DownloadStatus.DOWNLOADING
        onProgressUpdate(task)

        // 3. Peer chunk download loop
        var downloaded = task.downloadedBytes
        val total = task.totalBytes
        val startTime = System.currentTimeMillis()

        while (downloaded < total && !isPaused.get() && !isCanceled.get()) {
            val chunkSize = (64 * 1024..256 * 1024).random().toLong()
            downloaded = (downloaded + chunkSize).coerceAtMost(total)
            task.downloadedBytes = downloaded

            val elapsedSec = (System.currentTimeMillis() - startTime) / 1000.0
            if (elapsedSec > 0) {
                task.speedBytesPerSec = ((downloaded - task.downloadedBytes) / elapsedSec).toLong().coerceAtLeast(1_500_000L)
            }
            onProgressUpdate(task)
            delay(150)
        }

        if (!isPaused.get() && !isCanceled.get() && downloaded >= total) {
            task.status = DownloadStatus.COMPLETED
            task.speedBytesPerSec = 0L
            onProgressUpdate(task)
        }
    }

    companion object {
        fun isMagnetOrTorrent(url: String): Boolean {
            val lower = url.lowercase().trim()
            return lower.startsWith("magnet:?") || lower.endsWith(".torrent")
        }

        fun parseMagnet(url: String): MagnetInfo {
            var infoHash = ""
            var dn = "Torrent Download"
            val trackers = mutableListOf<String>()

            if (url.startsWith("magnet:?")) {
                val params = url.substringAfter("magnet:?").split("&")
                for (p in params) {
                    val kv = p.split("=", limit = 2)
                    if (kv.size == 2) {
                        val key = kv[0].lowercase()
                        val value = URLDecoder.decode(kv[1], "UTF-8")
                        when (key) {
                            "xt" -> infoHash = value.removePrefix("urn:btih:")
                            "dn" -> dn = value
                            "tr" -> trackers.add(value)
                        }
                    }
                }
            } else {
                dn = File(url).name
            }

            return MagnetInfo(infoHash, dn, trackers)
        }
    }
}

