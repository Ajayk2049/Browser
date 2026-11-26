package com.dab.browser

import android.content.Context
import android.os.Environment
import android.webkit.MimeTypeMap
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.mozilla.geckoview.WebResponse
import java.io.File
import java.io.FileOutputStream
import java.net.URLDecoder
import java.util.UUID

/**
 * Streams GeckoView WebResponse bodies (blob:, data:, Mega.nz ServiceWorker)
 * directly into the public Downloads/Dab Browser directory and reports live
 * progress to DownloadService/DownloadDatabase.
 */
object WebResponseDownloader {

    fun shouldStreamDirectly(url: String): Boolean {
        val lower = url.lowercase()
        return lower.startsWith("blob:") ||
            lower.startsWith("data:") ||
            lower.contains("mega.nz") ||
            lower.contains("mega.co.nz")
    }

    fun streamToDownloads(context: Context, response: WebResponse) {
        val body = response.body ?: return
        val appContext = context.applicationContext
        val uri = response.uri
        val headers = response.headers
        val fileName = parseFileName(uri, headers)
        val totalBytes = headers.entries
            .firstOrNull { it.key.equals("content-length", ignoreCase = true) }
            ?.value?.trim()?.toLongOrNull() ?: -1L

        val publicDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        val dabFolder = File(publicDir, "Dab Browser").apply { if (!exists()) mkdirs() }
        val destFile = uniqueFile(dabFolder, fileName)

        val taskId = UUID.randomUUID().toString()
        val task = DownloadTask(
            id = taskId,
            url = uri,
            destinationPath = destFile.absolutePath,
            segmentsCount = 1,
            totalBytes = totalBytes,
            status = DownloadStatus.DOWNLOADING
        )

        val db = DownloadDatabase(appContext)
        DownloadService.allTasks[taskId] = task
        DownloadService.dispatchProgress(task, isStateChange = true, db = db)

        CoroutineScope(Dispatchers.IO).launch {
            val buffer = ByteArray(64 * 1024)
            var downloaded = 0L
            var lastSpeedTime = System.currentTimeMillis()
            var bytesSinceLastSpeed = 0L

            try {
                FileOutputStream(destFile).use { out ->
                    while (true) {
                        val read = body.read(buffer)
                        if (read == -1) break
                        out.write(buffer, 0, read)
                        downloaded += read
                        bytesSinceLastSpeed += read

                        val now = System.currentTimeMillis()
                        val elapsed = now - lastSpeedTime
                        if (elapsed >= 500L) {
                            task.speedBytesPerSec = (bytesSinceLastSpeed * 1000L) / elapsed
                            lastSpeedTime = now
                            bytesSinceLastSpeed = 0L
                        }
                        task.downloadedBytes = downloaded
                        DownloadService.dispatchProgress(task, db = db)
                    }
                    out.flush()
                }
                task.downloadedBytes = downloaded
                if (task.totalBytes <= 0) task.totalBytes = downloaded
                task.speedBytesPerSec = 0L
                task.status = DownloadStatus.COMPLETED
                DownloadService.dispatchProgress(task, isStateChange = true, db = db)
            } catch (e: Exception) {
                task.speedBytesPerSec = 0L
                task.status = DownloadStatus.FAILED
                task.errorMessage = e.message ?: "Stream download failed"
                DownloadService.dispatchProgress(task, isStateChange = true, db = db)
            } finally {
                try { body.close() } catch (_: Exception) {}
            }
        }
    }

    private fun parseFileName(uri: String, headers: Map<String, String>): String {
        val disp = headers.entries
            .firstOrNull { it.key.equals("content-disposition", ignoreCase = true) }
            ?.value
        if (!disp.isNullOrBlank()) {
            val utf8Match = Regex("filename\\*\\s*=\\s*(?:UTF-8''|utf-8'')([^;]+)", RegexOption.IGNORE_CASE).find(disp)
            if (utf8Match != null) {
                val decoded = runCatching { URLDecoder.decode(utf8Match.groupValues[1].trim().trim('"'), "UTF-8") }.getOrNull()
                if (!decoded.isNullOrBlank()) return sanitize(decoded)
            }
            val stdMatch = Regex("filename\\s*=\\s*\"([^\"]+)\"|filename\\s*=\\s*([^; ]+)", RegexOption.IGNORE_CASE).find(disp)
            if (stdMatch != null) {
                val raw = (stdMatch.groupValues[1].ifEmpty { stdMatch.groupValues[2] }).trim().trim('"')
                val decoded = runCatching { URLDecoder.decode(raw, "UTF-8") }.getOrNull() ?: raw
                if (decoded.isNotBlank()) return sanitize(decoded)
            }
        }

        val mime = headers.entries
            .firstOrNull { it.key.equals("content-type", ignoreCase = true) }
            ?.value?.substringBefore(';')?.trim()
        val ext = if (!mime.isNullOrBlank()) MimeTypeMap.getSingleton().getExtensionFromMimeType(mime) else null
        val pathSeg = uri.substringBefore('?').substringBefore('#').substringAfterLast('/')
        val base = if (pathSeg.isNotBlank() && pathSeg.contains('.')) sanitize(pathSeg) else "download_${System.currentTimeMillis()}"
        return if (!base.contains('.') && !ext.isNullOrBlank()) "$base.$ext" else base
    }

    private fun sanitize(name: String): String =
        name.replace(Regex("[\\\\/:*?\"<>|]"), "_").trim().ifEmpty { "download_${System.currentTimeMillis()}" }

    private fun uniqueFile(dir: File, name: String): File {
        var candidate = File(dir, name)
        if (!candidate.exists()) return candidate
        val dot = name.lastIndexOf('.')
        val stem = if (dot > 0) name.substring(0, dot) else name
        val ext = if (dot > 0) name.substring(dot) else ""
        var i = 1
        while (candidate.exists()) {
            candidate = File(dir, "$stem ($i)$ext")
            i++
        }
        return candidate
    }
}
