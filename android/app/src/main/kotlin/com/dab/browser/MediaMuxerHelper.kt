package com.dab.browser

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.util.Log
import java.io.File
import java.nio.ByteBuffer

object MediaMuxerHelper {
    private const val TAG = "MediaMuxer"

    fun mux(videoFile: File, audioFile: File, outputFile: File): MuxResult {
        var videoExtractor: MediaExtractor? = null
        var audioExtractor: MediaExtractor? = null
        var muxer: MediaMuxer? = null
        val tempOutput = File("${outputFile.path}.mux.tmp")
        try {
            if (!videoFile.exists() || videoFile.length() == 0L) {
                return MuxResult(false, "Video file missing or empty (${videoFile.length()} bytes)")
            }
            if (!audioFile.exists() || audioFile.length() == 0L) {
                return MuxResult(false, "Audio file missing or empty (${audioFile.length()} bytes)")
            }

            videoExtractor = MediaExtractor().apply { setDataSource(videoFile.path) }
            audioExtractor = MediaExtractor().apply { setDataSource(audioFile.path) }

            var videoTrackIndex = -1
            var videoFormat: MediaFormat? = null
            for (i in 0 until videoExtractor.trackCount) {
                val format = videoExtractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: ""
                if (mime.startsWith("video/")) {
                    videoTrackIndex = i; videoFormat = format; break
                }
            }

            var audioTrackIndex = -1
            var audioFormat: MediaFormat? = null
            for (i in 0 until audioExtractor.trackCount) {
                val format = audioExtractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: ""
                if (mime.startsWith("audio/")) {
                    audioTrackIndex = i; audioFormat = format; break
                }
            }

            if (videoTrackIndex < 0 || videoFormat == null) {
                return MuxResult(false, "No video track found in ${videoFile.name}")
            }
            if (audioTrackIndex < 0 || audioFormat == null) {
                return MuxResult(false, "No audio track found in ${audioFile.name}")
            }
            if (tempOutput.exists()) tempOutput.delete()

            muxer = MediaMuxer(tempOutput.path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            videoExtractor.selectTrack(videoTrackIndex)
            val muxerVideo = muxer.addTrack(videoFormat)
            audioExtractor.selectTrack(audioTrackIndex)
            val muxerAudio = muxer.addTrack(audioFormat)
            muxer.start()

            val maxVideoSize = try { videoFormat.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE) } catch (_: Exception) { 1024 * 1024 }
            val bufferSize = maxOf(maxVideoSize, 4 * 1024 * 1024)
            val buffer = ByteBuffer.allocate(bufferSize)
            val info = MediaCodec.BufferInfo()

            var videoBasePts = -1L
            while (true) {
                info.offset = 0
                info.size = videoExtractor.readSampleData(buffer, 0)
                if (info.size < 0) break
                val sampleTime = videoExtractor.sampleTime
                if (videoBasePts < 0) videoBasePts = if (sampleTime > 1_000_000L) sampleTime else 0L
                info.presentationTimeUs = (sampleTime - videoBasePts).coerceAtLeast(0L)
                info.flags = videoExtractor.sampleFlags
                muxer.writeSampleData(muxerVideo, buffer, info)
                videoExtractor.advance()
            }

            var audioBasePts = -1L
            while (true) {
                info.offset = 0
                info.size = audioExtractor.readSampleData(buffer, 0)
                if (info.size < 0) break
                val sampleTime = audioExtractor.sampleTime
                if (audioBasePts < 0) audioBasePts = if (sampleTime > 1_000_000L) sampleTime else 0L
                info.presentationTimeUs = (sampleTime - audioBasePts).coerceAtLeast(0L)
                info.flags = audioExtractor.sampleFlags
                muxer.writeSampleData(muxerAudio, buffer, info)
                audioExtractor.advance()
            }

            muxer.stop(); muxer.release(); muxer = null
            videoExtractor.release(); videoExtractor = null
            audioExtractor.release(); audioExtractor = null

            val verify = verifyOutput(tempOutput, requireBothTracks = true)
            if (!verify.success) {
                if (tempOutput.exists()) tempOutput.delete()
                return verify
            }

            if (outputFile.exists()) outputFile.delete()
            if (!tempOutput.renameTo(outputFile)) {
                return MuxResult(false, "Failed to rename temp file to ${outputFile.name}")
            }
            Log.d(TAG, "Mux successful: ${outputFile.path} (${outputFile.length()} bytes)")
            return MuxResult(true, videoTracks = verify.videoTracks, audioTracks = verify.audioTracks)
        } catch (e: Exception) {
            Log.e(TAG, "Muxing error: $e", e)
            try { if (tempOutput.exists()) tempOutput.delete() } catch (_: Exception) {}
            return MuxResult(false, e.message ?: "Muxing failed")
        } finally {
            try { videoExtractor?.release() } catch (_: Exception) {}
            try { audioExtractor?.release() } catch (_: Exception) {}
            try { muxer?.release() } catch (_: Exception) {}
        }
    }

    /** Remuxes a single multi-track/single-track container (e.g. .ts or concatenated fMP4) into MP4. */
    fun remuxToMp4(inputFile: File, outputFile: File): MuxResult {
        var extractor: MediaExtractor? = null
        var muxer: MediaMuxer? = null
        val tempOutput = File("${outputFile.path}.remux.tmp")
        try {
            if (!inputFile.exists() || inputFile.length() == 0L) return MuxResult(false, "Input file missing or empty")
            extractor = MediaExtractor().apply { setDataSource(inputFile.path) }
            val trackMap = HashMap<Int, Int>()
            val basePts = HashMap<Int, Long>()
            val lastPts = HashMap<Int, Long>()
            var maxBuf = 4 * 1024 * 1024
            if (tempOutput.exists()) tempOutput.delete()
            muxer = MediaMuxer(tempOutput.path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

            for (i in 0 until extractor.trackCount) {
                val fmt = extractor.getTrackFormat(i)
                val mime = fmt.getString(MediaFormat.KEY_MIME) ?: ""
                if (mime.startsWith("video/") || mime.startsWith("audio/")) {
                    extractor.selectTrack(i)
                    trackMap[i] = muxer.addTrack(fmt)
                    try { maxBuf = maxOf(maxBuf, fmt.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE)) } catch (_: Exception) {}
                }
            }
            if (trackMap.isEmpty()) return MuxResult(false, "No playable video/audio tracks found in ${inputFile.name}")
            muxer.start()

            val buffer = ByteBuffer.allocate(maxBuf)
            val info = MediaCodec.BufferInfo()
            while (true) {
                val srcTrack = extractor.sampleTrackIndex
                if (srcTrack < 0) break
                val dstTrack = trackMap[srcTrack]
                if (dstTrack == null) { extractor.advance(); continue }
                info.offset = 0
                info.size = extractor.readSampleData(buffer, 0)
                if (info.size < 0) break
                val rawTime = extractor.sampleTime.coerceAtLeast(0L)
                val base = basePts.getOrPut(srcTrack) { if (rawTime > 1_000_000L) rawTime else 0L }
                var pts = (rawTime - base).coerceAtLeast(0L)
                val prev = lastPts[srcTrack] ?: -1L
                if (pts < prev) pts = prev
                lastPts[srcTrack] = pts
                info.presentationTimeUs = pts
                info.flags = extractor.sampleFlags
                muxer.writeSampleData(dstTrack, buffer, info)
                extractor.advance()
            }

            muxer.stop(); muxer.release(); muxer = null
            extractor.release(); extractor = null

            val verify = verifyOutput(tempOutput, requireBothTracks = false)
            if (!verify.success) { if (tempOutput.exists()) tempOutput.delete(); return verify }
            if (outputFile.exists()) outputFile.delete()
            if (!tempOutput.renameTo(outputFile)) return MuxResult(false, "Failed to rename remuxed file")
            return MuxResult(true, videoTracks = verify.videoTracks, audioTracks = verify.audioTracks)
        } catch (e: Exception) {
            Log.e(TAG, "Remux error: $e", e)
            try { if (tempOutput.exists()) tempOutput.delete() } catch (_: Exception) {}
            return MuxResult(false, e.message ?: "Remux failed")
        } finally {
            try { extractor?.release() } catch (_: Exception) {}
            try { muxer?.release() } catch (_: Exception) {}
        }
    }

    private fun verifyOutput(file: File, requireBothTracks: Boolean = true): MuxResult {
        if (!file.exists() || file.length() == 0L) return MuxResult(false, "Output file empty or missing")
        var extractor: MediaExtractor? = null
        try {
            extractor = MediaExtractor().apply { setDataSource(file.path) }
            var vCount = 0; var aCount = 0
            for (i in 0 until extractor.trackCount) {
                val mime = extractor.getTrackFormat(i).getString(MediaFormat.KEY_MIME) ?: ""
                if (mime.startsWith("video/")) vCount++
                if (mime.startsWith("audio/")) aCount++
            }
            if (requireBothTracks && (vCount == 0 || aCount == 0)) {
                return MuxResult(false, "Missing tracks in output: v=$vCount, a=$aCount", vCount, aCount)
            }
            if (!requireBothTracks && vCount == 0 && aCount == 0) {
                return MuxResult(false, "No tracks in remuxed output", 0, 0)
            }
            return MuxResult(true, videoTracks = vCount, audioTracks = aCount)
        } catch (e: Exception) {
            return MuxResult(false, "Output verification failed: ${e.message}")
        } finally {
            try { extractor?.release() } catch (_: Exception) {}
        }
    }
}
