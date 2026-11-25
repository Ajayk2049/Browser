package com.dab.browser

import android.util.Log
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit
import java.io.File
import java.io.FileOutputStream
import java.util.Locale
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong
import javax.crypto.Cipher
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.SecretKeySpec

object PlaylistDownloadHelper {
    private const val TAG = "PlaylistDL"

    fun isPlaylist(url: String, contentType: String?): Boolean {
        val clean = url.substringBefore('#').substringBefore('?').lowercase(Locale.ROOT)
        val ct = contentType?.lowercase(Locale.ROOT) ?: ""
        return clean.endsWith(".m3u8") || clean.endsWith(".mpd") ||
            ct.contains("mpegurl") || ct.contains("dash+xml")
    }

    private fun fetchText(url: String, referer: String?, headers: Map<String, String>): Pair<String, String> {
        val clean = url.substringBefore('#')
        DownloadHttpHelper.openStream(clean, referer = referer, extraHeaders = headers).use { s ->
            if (s.code !in 200..299) throw Exception("Playlist HTTP ${s.code}")
            val bytes = s.byteStream.readBytes()
            return String(bytes, Charsets.UTF_8) to s.finalUrl
        }
    }

    fun inspectVariants(url: String, referer: String?, headers: Map<String, String>): List<Map<String, Any?>> {
        val (text, finalUrl) = fetchText(url, referer, headers)
        val upper = text.trimStart().uppercase(Locale.ROOT)
        if (upper.contains("#EXTM3U")) {
            if (PlaylistParser.isHlsMaster(text)) {
                return PlaylistParser.parseHlsMaster(text, finalUrl).map { it.toMap() }
            }
            return listOf(PlaylistVariant("Default Stream", finalUrl, null, 0L, 0, 0, "MP4", "video").toMap())
        }
        if (upper.contains("<MPD") || upper.contains("<ADAPTATIONSET") || upper.contains("MEDIAPRESENTATIONDURATION")) {
            return PlaylistParser.inspectMpdVariants(text, finalUrl).map { it.toMap() }
        }
        return emptyList()
    }

    suspend fun download(
        task: DownloadTask,
        extraHeaders: Map<String, String>,
        isPaused: AtomicBoolean,
        isCanceled: AtomicBoolean,
        onProgress: () -> Unit
    ): Boolean = withContext(Dispatchers.IO) {
        val (primaryTrack, audioTrack, isAudioOnly) = resolveTracks(task, extraHeaders)
        val destBefore = File(task.destinationPath)
        val curName = destBefore.name
        if (curName.endsWith(".m3u8", true) || curName.endsWith(".mpd", true)) {
            val base = curName.substringBeforeLast('.')
            val targetExt = if (isAudioOnly) "m4a" else "mp4"
            task.destinationPath = File(destBefore.parentFile, "$base.$targetExt").path
        }
        val destFile = File(task.destinationPath)
        destFile.parentFile?.mkdirs()
        val segRoot = File("${task.destinationPath}.segs").apply { mkdirs() }

        val keyCache = ConcurrentHashMap<String, ByteArray>()
        val completedSegs = AtomicInteger(0)
        val totalBytesDown = AtomicLong(0L)
        val totalSegCount = (primaryTrack.segments.size + (audioTrack?.segments?.size ?: 0)).coerceAtLeast(1)

        task.status = DownloadStatus.DOWNLOADING
        onProgress()

        val vDir = File(segRoot, "track0").apply { mkdirs() }
        val aDir = if (audioTrack != null) File(segRoot, "track1").apply { mkdirs() } else null

        supervisorScope {
            val sem = Semaphore(4)
            val jobs = mutableListOf<Job>()
            suspend fun enqueueTrack(track: ParsedMediaTrack, dir: File) {
                if (!track.initUrl.isNullOrBlank()) {
                    val initFile = File(dir, "init.bin")
                    if (!initFile.exists() || initFile.length() == 0L) {
                        fetchSegmentToFile(track.initUrl, track.initStart, track.initEnd, null, null, null, task.referer, extraHeaders, initFile, keyCache)
                    }
                }
                for ((idx, seg) in track.segments.withIndex()) {
                    val out = File(dir, "seg_%06d.bin".format(Locale.US, idx))
                    if (out.exists() && out.length() > 0L) {
                        totalBytesDown.addAndGet(out.length())
                        completedSegs.incrementAndGet()
                        continue
                    }
                    jobs.add(launch {
                        sem.withPermit {
                            if (isPaused.get() || isCanceled.get()) return@withPermit
                            val written = downloadSegmentWithRetry(seg, task.referer, extraHeaders, out, keyCache, isPaused, isCanceled)
                            if (isPaused.get() || isCanceled.get()) return@withPermit
                            totalBytesDown.addAndGet(written)
                            val done = completedSegs.incrementAndGet().coerceAtLeast(1)
                            val bytesNow = totalBytesDown.get()
                            task.downloadedBytes = bytesNow
                            val est = (bytesNow.toDouble() / done.toDouble() * totalSegCount).toLong()
                            if (est > task.totalBytes) task.totalBytes = est.coerceAtLeast(bytesNow)
                            if (done == totalSegCount) task.totalBytes = bytesNow
                            onProgress()
                        }
                    })
                }
            }

            enqueueTrack(primaryTrack, vDir)
            if (audioTrack != null && aDir != null) enqueueTrack(audioTrack, aDir)
            jobs.joinAll()
        }

        if (isPaused.get() || isCanceled.get()) return@withContext false

        val track0File = File(segRoot, "track0.part")
        assembleTrack(vDir, primaryTrack, track0File)

        if (audioTrack != null && aDir != null) {
            val track1File = File(segRoot, "track1.part")
            assembleTrack(aDir, audioTrack, track1File)
            task.speedBytesPerSec = 0L; onProgress()
            val mux = MediaMuxerHelper.mux(track0File, track1File, destFile)
            if (!mux.success) throw Exception("Playlist mux failed: ${mux.reason}")
        } else {
            task.speedBytesPerSec = 0L; onProgress()
            val remux = MediaMuxerHelper.remuxToMp4(track0File, destFile)
            if (!remux.success) {
                Log.w(TAG, "MP4 remux failed (${remux.reason}), keeping raw .ts/.m4a container")
                val fallbackExt = if (isAudioOnly) "aac" else "ts"
                val fbFile = File("${destFile.path.substringBeforeLast('.')}.$fallbackExt")
                track0File.copyTo(fbFile, overwrite = true)
                task.destinationPath = fbFile.path
            }
        }

        try { segRoot.deleteRecursively() } catch (_: Exception) {}
        val finalSize = File(task.destinationPath).length()
        task.downloadedBytes = finalSize
        task.totalBytes = finalSize
        true
    }

    private fun resolveTracks(task: DownloadTask, extraHeaders: Map<String, String>): Triple<ParsedMediaTrack, ParsedMediaTrack?, Boolean> {
        val rawUrl = task.url
        val dashRep = rawUrl.substringAfter("#dashRep=", "").takeIf { rawUrl.contains("#dashRep=") && it.isNotEmpty() }
        val (text, finalUrl) = fetchText(rawUrl, task.referer, extraHeaders)
        val upper = text.trimStart().uppercase(Locale.ROOT)

        if (upper.contains("<MPD") || upper.contains("<ADAPTATIONSET") || upper.contains("MEDIAPRESENTATIONDURATION")) {
            val (reps, drmErr) = PlaylistParser.parseMpdReps(text, finalUrl)
            if (drmErr != null) throw Exception(drmErr)
            val chosen = (if (dashRep != null) reps.firstOrNull { it.id == dashRep } else null)
                ?: reps.filter { it.type == "video" }.maxByOrNull { it.height * 1_000_000L + it.bandwidth }
                ?: reps.firstOrNull()
                ?: throw Exception("No playable DASH representations found")
            val isAudioOnly = chosen.type == "audio"
            val audioRepId = task.audioUrl?.substringAfter("#dashRep=", "")
            val audio = if (!isAudioOnly) {
                (if (!audioRepId.isNullOrEmpty()) reps.firstOrNull { it.id == audioRepId } else null)
                    ?: reps.filter { it.type == "audio" }.maxByOrNull { it.bandwidth }
            } else null
            return Triple(chosen.track, audio?.track, isAudioOnly)
        }

        var mediaText = text
        var mediaBase = finalUrl
        var companionAudioUrl = task.audioUrl
        if (PlaylistParser.isHlsMaster(text)) {
            val variants = PlaylistParser.parseHlsMaster(text, finalUrl)
            val best = variants.firstOrNull { it.type == "video" } ?: variants.firstOrNull()
                ?: throw Exception("No variants found in HLS master playlist")
            if (companionAudioUrl.isNullOrBlank()) companionAudioUrl = best.audioUrl
            val fetched = fetchText(best.url, task.referer, extraHeaders)
            mediaText = fetched.first; mediaBase = fetched.second
        }

        val primary = PlaylistParser.parseHlsMedia(mediaText, mediaBase)
        if (primary.drmError != null) throw Exception(primary.drmError)
        if (primary.segments.isEmpty()) throw Exception("HLS playlist has 0 segments")

        var audioTrack: ParsedMediaTrack? = null
        if (!companionAudioUrl.isNullOrBlank()) {
            val (aText, aBase) = fetchText(companionAudioUrl, task.referer, extraHeaders)
            val aParsed = PlaylistParser.parseHlsMedia(aText, aBase)
            if (aParsed.drmError == null && aParsed.segments.isNotEmpty()) audioTrack = aParsed
        }
        return Triple(primary, audioTrack, false)
    }

    private suspend fun downloadSegmentWithRetry(
        seg: MediaSegment, referer: String?, headers: Map<String, String>,
        outFile: File, keyCache: ConcurrentHashMap<String, ByteArray>,
        isPaused: AtomicBoolean, isCanceled: AtomicBoolean
    ): Long {
        var lastErr: Exception? = null
        for (attempt in 0 until 4) {
            if (isPaused.get() || isCanceled.get()) return 0L
            try {
                return fetchSegmentToFile(seg.url, seg.rangeStart, seg.rangeEnd, seg.keyMethod, seg.keyUrl, seg.ivBytes, referer, headers, outFile, keyCache)
            } catch (e: Exception) {
                lastErr = e
                if (isPaused.get() || isCanceled.get()) return 0L
                delay(400L * (attempt + 1))
            }
        }
        throw lastErr ?: Exception("Segment failed: ${seg.url}")
    }

    private fun fetchSegmentToFile(
        url: String, rangeStart: Long, rangeEnd: Long,
        keyMethod: String?, keyUrl: String?, ivBytes: ByteArray?,
        referer: String?, headers: Map<String, String>,
        outFile: File, keyCache: ConcurrentHashMap<String, ByteArray>
    ): Long {
        val keyBytes = if (keyMethod == "AES-128" && !keyUrl.isNullOrBlank()) {
            keyCache.getOrPut(keyUrl) {
                val merged = LinkedHashMap<String, String>(headers)
                merged.putAll(PlaylistKeyCache.headersFor(keyUrl))
                DownloadHttpHelper.openStream(keyUrl, referer = referer, extraHeaders = merged).use { ks ->
                    if (ks.code !in 200..299) throw Exception("AES key HTTP ${ks.code}")
                    val kb = ks.byteStream.readBytes()
                    if (kb.size != 16) throw Exception("Invalid AES key length ${kb.size}")
                    kb
                }
            }
        } else null

        val rangeHdr = if (rangeStart >= 0L && rangeEnd >= rangeStart) "bytes=$rangeStart-$rangeEnd" else null
        var rawBytes = DownloadHttpHelper.openStream(url, rangeHeader = rangeHdr, referer = referer, extraHeaders = headers).use { s ->
            if (s.code !in 200..299) throw Exception("Segment HTTP ${s.code}")
            s.byteStream.readBytes()
        }
        if (keyBytes != null) {
            val cipher = Cipher.getInstance("AES/CBC/PKCS5Padding")
            cipher.init(Cipher.DECRYPT_MODE, SecretKeySpec(keyBytes, "AES"), IvParameterSpec(ivBytes ?: ByteArray(16)))
            rawBytes = cipher.doFinal(rawBytes)
        }
        val tmp = File("${outFile.path}.tmp")
        FileOutputStream(tmp).use { it.write(rawBytes) }
        if (outFile.exists()) outFile.delete()
        tmp.renameTo(outFile)
        return rawBytes.size.toLong()
    }

    private fun assembleTrack(dir: File, track: ParsedMediaTrack, outFile: File) {
        if (outFile.exists()) outFile.delete()
        FileOutputStream(outFile).use { fos ->
            val initFile = File(dir, "init.bin")
            if (initFile.exists() && initFile.length() > 0L) initFile.inputStream().use { it.copyTo(fos) }
            for (idx in track.segments.indices) {
                val sf = File(dir, "seg_%06d.bin".format(Locale.US, idx))
                if (!sf.exists() || sf.length() == 0L) throw Exception("Missing segment $idx")
                sf.inputStream().use { it.copyTo(fos) }
            }
        }
    }
}
