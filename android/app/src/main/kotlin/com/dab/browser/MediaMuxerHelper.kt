package com.dab.browser

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import java.io.File
import java.nio.ByteBuffer

/// Native Android MediaMuxer helper that combines MP4 video and M4A/AAC audio
/// into a single final MP4 container without re-encoding.
/// Complies with rules.md §13, §29.2 (< 200 lines).
object MediaMuxerHelper {
    fun mux(videoFile: File, audioFile: File, outputFile: File): Boolean {
        var videoExtractor: MediaExtractor? = null
        var audioExtractor: MediaExtractor? = null
        var muxer: MediaMuxer? = null
        val tempOutput = File("${outputFile.path}.mux.tmp")
        try {
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

            if (videoTrackIndex < 0 || audioTrackIndex < 0 || videoFormat == null || audioFormat == null) return false
            if (tempOutput.exists()) tempOutput.delete()

            muxer = MediaMuxer(tempOutput.path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            videoExtractor.selectTrack(videoTrackIndex)
            val muxerVideo = muxer.addTrack(videoFormat)
            audioExtractor.selectTrack(audioTrackIndex)
            val muxerAudio = muxer.addTrack(audioFormat)
            muxer.start()

            val buffer = ByteBuffer.allocate(1024 * 1024)
            val info = MediaCodec.BufferInfo()

            while (true) {
                info.offset = 0
                info.size = videoExtractor.readSampleData(buffer, 0)
                if (info.size < 0) break
                info.presentationTimeUs = videoExtractor.sampleTime
                info.flags = videoExtractor.sampleFlags
                muxer.writeSampleData(muxerVideo, buffer, info)
                videoExtractor.advance()
            }

            while (true) {
                info.offset = 0
                info.size = audioExtractor.readSampleData(buffer, 0)
                if (info.size < 0) break
                info.presentationTimeUs = audioExtractor.sampleTime
                info.flags = audioExtractor.sampleFlags
                muxer.writeSampleData(muxerAudio, buffer, info)
                audioExtractor.advance()
            }

            muxer.stop(); muxer.release(); muxer = null
            videoExtractor.release(); videoExtractor = null
            audioExtractor.release(); audioExtractor = null

            if (outputFile.exists()) outputFile.delete()
            return tempOutput.renameTo(outputFile)
        } catch (e: Exception) {
            android.util.Log.e("MediaMuxerHelper", "Muxing error: $e")
            try { if (tempOutput.exists()) tempOutput.delete() } catch (_: Exception) {}
            return false
        } finally {
            try { videoExtractor?.release() } catch (_: Exception) {}
            try { audioExtractor?.release() } catch (_: Exception) {}
            try { muxer?.release() } catch (_: Exception) {}
        }
    }
}
