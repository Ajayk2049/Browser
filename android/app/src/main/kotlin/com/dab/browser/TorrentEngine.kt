package com.dab.browser

import kotlinx.coroutines.*
import org.libtorrent4j.Sha1Hash
import org.libtorrent4j.TorrentHandle
import org.libtorrent4j.TorrentInfo
import org.libtorrent4j.TorrentStatus
import org.libtorrent4j.swig.torrent_flags_t
import java.io.File
import java.net.URLDecoder
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Real BitTorrent & Magnet engine powered by libtorrent4j.
 * Complies with rules.md §13, §26.5, §29.2 (< 250 lines).
 */
class TorrentEngine(
    val task: DownloadTask,
    private val onProgressUpdate: (DownloadTask) -> Unit
) {
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val isPaused = AtomicBoolean(false)
    private val isCanceled = AtomicBoolean(false)
    private var torrentJob: Job? = null
    private var handle: TorrentHandle? = null

    data class MagnetInfo(
        val infoHash: String,
        val displayName: String,
        val trackers: List<String>,
        val exactSize: Long = -1L
    )

    fun start() {
        if (task.status == DownloadStatus.DOWNLOADING) return
        isPaused.set(false); isCanceled.set(false)
        task.status = DownloadStatus.CONNECTING; onProgressUpdate(task)

        torrentJob = scope.launch {
            try {
                executeTorrent()
            } catch (_: CancellationException) {
            } catch (e: Exception) {
                task.status = DownloadStatus.FAILED
                task.errorMessage = e.message ?: "Torrent error"
                task.speedBytesPerSec = 0L
                onProgressUpdate(task)
            }
        }
    }

    fun pause() {
        isPaused.set(true); handle?.pause(); torrentJob?.cancel()
        task.status = DownloadStatus.PAUSED; task.speedBytesPerSec = 0L
        onProgressUpdate(task)
    }

    fun cancel() {
        isCanceled.set(true); torrentJob?.cancel()
        val h = handle
        if (h != null && h.isValid) {
            try { TorrentSessionManager.session.remove(h) } catch (_: Exception) {}
        }
        task.status = DownloadStatus.CANCELED; task.speedBytesPerSec = 0L
        try {
            val dest = File(task.destinationPath)
            if (dest.exists()) dest.deleteRecursively()
            val part = File("${task.destinationPath}.part")
            if (part.exists()) part.delete()
        } catch (_: Exception) {}
        onProgressUpdate(task)
    }

    fun setSpeedLimit(bytesPerSec: Long) {
        task.speedLimitBytesPerSec = bytesPerSec
        val h = handle
        if (h != null && h.isValid) {
            try { h.setDownloadLimit(if (bytesPerSec > 0) bytesPerSec.toInt() else 0) } catch (_: Exception) {}
        }
    }

    private suspend fun executeTorrent() = withContext(Dispatchers.IO) {
        TorrentSessionManager.ensureStarted()
        val session = TorrentSessionManager.session

        val destFile = File(task.destinationPath)
        val saveDir = destFile.parentFile ?: File("/storage/emulated/0/Download/Dab Browser")
        saveDir.mkdirs()

        val magnet = parseMagnet(task.url)
        val sha1: Sha1Hash? = if (magnet.infoHash.length == 40) {
            try { Sha1Hash.parseHex(magnet.infoHash) } catch (_: Exception) { null }
        } else null

        var th = if (sha1 != null) session.find(sha1) else null
        if (th == null || !th.isValid) {
            if (task.url.startsWith("magnet:", true)) {
                session.download(task.url, saveDir, torrent_flags_t())
            } else if (task.url.endsWith(".torrent", true)) {
                val tFile = File(task.url)
                if (tFile.exists()) {
                    session.download(TorrentInfo(tFile), saveDir)
                } else {
                    session.download(task.url, saveDir, torrent_flags_t())
                }
            } else {
                session.download(task.url, saveDir, torrent_flags_t())
            }

            for (i in 0 until 60) {
                if (isPaused.get() || isCanceled.get()) return@withContext
                delay(250)
                if (sha1 != null) th = session.find(sha1)
                if (th != null && th.isValid) break
            }
        }

        if (th == null || !th.isValid) throw Exception("Failed to start torrent session for magnet")
        handle = th
        if (task.speedLimitBytesPerSec > 0) {
            try { th.setDownloadLimit(task.speedLimitBytesPerSec.toInt()) } catch (_: Exception) {}
        }
        th.resume()

        task.status = DownloadStatus.DOWNLOADING
        onProgressUpdate(task)

        var completed = false
        while (!completed && !isPaused.get() && !isCanceled.get()) {
            delay(500)
            if (!th.isValid) break
            val status = th.status()

            task.seeders = status.numSeeds()
            val peers = status.numPeers()
            task.leechers = (peers - status.numSeeds()).coerceAtLeast(0)

            val tf = try { th.torrentFile() } catch (_: Exception) { null }
            if (tf != null) {
                if (task.totalBytes <= 0) task.totalBytes = tf.totalSize()
                val realName = tf.name()
                if (realName.isNotEmpty() && destFile.name != realName) {
                    task.destinationPath = File(saveDir, realName).absolutePath
                }
            } else if (task.totalBytes <= 0) {
                val wanted = status.totalWanted()
                if (wanted > 0) task.totalBytes = wanted
            }

            val done = status.totalDone()
            task.downloadedBytes = done
            task.speedBytesPerSec = status.downloadRate().toLong().coerceAtLeast(0L)

            val state = status.state()
            if (state == TorrentStatus.State.DOWNLOADING || state == TorrentStatus.State.DOWNLOADING_METADATA) {
                task.status = DownloadStatus.DOWNLOADING
            } else if (state == TorrentStatus.State.CHECKING_FILES || state == TorrentStatus.State.CHECKING_RESUME_DATA) {
                task.status = DownloadStatus.CONNECTING
            }

            val isDone = status.isFinished || state == TorrentStatus.State.FINISHED || state == TorrentStatus.State.SEEDING || (task.totalBytes > 0 && done >= task.totalBytes)
            if (isDone) {
                completed = true
                task.status = DownloadStatus.COMPLETED
                task.speedBytesPerSec = 0L
                if (task.totalBytes > 0) task.downloadedBytes = task.totalBytes
            }
            onProgressUpdate(task)
        }
    }

    companion object {
        fun isMagnetOrTorrent(url: String): Boolean {
            val lower = url.lowercase().trim()
            return lower.startsWith("magnet:") || lower.endsWith(".torrent")
        }

        fun parseMagnet(url: String): MagnetInfo {
            var infoHash = ""
            var dn = "Torrent Download"
            var exactSize = -1L
            val trackers = mutableListOf<String>()

            if (url.startsWith("magnet:?", true)) {
                val query = url.substringAfter("magnet:?")
                query.split("&").forEach { param ->
                    val parts = param.split("=", limit = 2)
                    if (parts.size == 2) {
                        val key = parts[0].lowercase()
                        val value = try { URLDecoder.decode(parts[1], "UTF-8") } catch (_: Exception) { parts[1] }
                        when (key) {
                            "xt" -> if (value.startsWith("urn:btih:", true)) infoHash = value.substring(9)
                            "dn" -> dn = value
                            "tr" -> trackers.add(value)
                            "xl" -> exactSize = value.toLongOrNull() ?: -1L
                        }
                    }
                }
            } else if (url.endsWith(".torrent", true)) {
                dn = File(url).name
            }
            return MagnetInfo(infoHash, dn, trackers, exactSize)
        }
    }
}
