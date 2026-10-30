package com.yourdomain.browser

import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.regex.Pattern

data class ProbeResult(
    val finalUrl: String,
    val contentLength: Long,
    val supportsRanges: Boolean,
    val contentType: String?,
    val suggestedFileName: String?
)

object DownloadHttpHelper {
    const val USER_AGENT = "Mozilla/5.0 (Android; Mobile; rv:144.0) Gecko/144.0 Firefox/144.0"

    fun openConnection(
        urlStr: String,
        rangeHeader: String? = null,
        referer: String? = null,
        method: String = "GET"
    ): HttpURLConnection {
        var current = urlStr
        for (i in 0 until 8) {
            val conn = (URL(current).openConnection() as HttpURLConnection).apply {
                requestMethod = method
                connectTimeout = 15000
                readTimeout = 30000
                instanceFollowRedirects = false
                setRequestProperty("User-Agent", USER_AGENT)
                setRequestProperty("Accept", "*/*")
                val ref = referer?.takeIf { it.isNotBlank() } ?: URL(current).host.let { if (it.isNotEmpty()) "https://$it/" else null }
                if (ref != null) setRequestProperty("Referer", ref)
                if (rangeHeader != null) setRequestProperty("Range", rangeHeader)
            }
            conn.connect()
            val code = conn.responseCode
            if (code in 300..399) {
                val loc = conn.getHeaderField("Location") ?: break
                current = if (loc.startsWith("http")) loc else URL(URL(current), loc).toString()
                conn.disconnect()
                continue
            }
            return conn
        }
        return (URL(current).openConnection() as HttpURLConnection).apply {
            requestMethod = method
            setRequestProperty("User-Agent", USER_AGENT)
            if (rangeHeader != null) setRequestProperty("Range", rangeHeader)
        }
    }

    fun probeUrl(urlStr: String, referer: String? = null): ProbeResult = try {
        // Single pre-flight request with Range: bytes=0-0 to get all metadata without triggering HEAD 405/429
        val conn = openConnection(urlStr, rangeHeader = "bytes=0-0", referer = referer, method = "GET")
        val finalUrl = conn.url.toString()
        val cType = conn.contentType?.lowercase(Locale.ROOT)
        val cr = conn.getHeaderField("Content-Range")
        val parsedLen = if (cr != null && cr.contains("/")) {
            val total = cr.substringAfterLast("/").trim().toLongOrNull()
            if (total != null && total > 0) total else (if (conn.responseCode != 206) conn.contentLengthLong else -1L)
        } else {
            if (conn.responseCode != 206) conn.contentLengthLong else -1L
        }
        val len = if (parsedLen <= 0 && conn.responseCode in 200..399) {
            try {
                val headConn = openConnection(finalUrl, referer = referer, method = "HEAD")
                val hl = headConn.contentLengthLong
                headConn.disconnect()
                if (hl > 0) hl else parsedLen
            } catch (_: Exception) { parsedLen }
        } else parsedLen

        val supportsRanges = conn.responseCode == 206 || conn.responseCode == 416 || conn.getHeaderField("Accept-Ranges")?.contains("bytes", true) == true
        val cd = conn.getHeaderField("Content-Disposition")
        val fileName = parseContentDisposition(cd)
        try {
            if (conn.responseCode in 200..299) conn.inputStream.close() else conn.errorStream?.close()
        } catch (_: Exception) {}
        conn.disconnect()
        ProbeResult(finalUrl, len, supportsRanges, cType, fileName)
    } catch (_: Exception) {
        ProbeResult(urlStr, -1L, false, null, null)
    }

    fun parseRetryAfter(header: String?): Long? {
        if (header.isNullOrBlank()) return null
        header.trim().toLongOrNull()?.let { return (it * 1000L).coerceIn(1000L, 120000L) }
        try {
            val format = SimpleDateFormat("EEE, dd MMM yyyy HH:mm:ss zzz", Locale.US)
            val date = format.parse(header.trim())
            if (date != null) {
                val diff = date.time - System.currentTimeMillis()
                return diff.coerceIn(1000L, 120000L)
            }
        } catch (_: Exception) {}
        return null
    }

    fun validateRangeResponse(conn: HttpURLConnection, expectedStart: Long, isRangedRequest: Boolean): Boolean {
        val code = conn.responseCode
        if (!isRangedRequest) return code in 200..299
        if (code != 206) return false
        val cr = conn.getHeaderField("Content-Range") ?: return true
        val matcher = Pattern.compile("bytes\\s+(\\d+)-(\\d+)/").matcher(cr)
        if (matcher.find()) {
            val start = matcher.group(1)?.toLongOrNull() ?: return true
            return start == expectedStart
        }
        return true
    }

    private fun parseContentDisposition(header: String?): String? {
        if (header.isNullOrBlank()) return null
        val utf8Matcher = Pattern.compile("filename\\*\\s*=\\s*(?:UTF-8''|utf-8'')([^;]+)", Pattern.CASE_INSENSITIVE).matcher(header)
        if (utf8Matcher.find()) {
            val raw = utf8Matcher.group(1)?.trim()?.replace("\"", "") ?: ""
            return try { java.net.URLDecoder.decode(raw, "UTF-8") } catch (_: Exception) { raw }
        }
        val stdMatcher = Pattern.compile("filename\\s*=\\s*\"([^\"]+)\"|filename\\s*=\\s*([^; ]+)", Pattern.CASE_INSENSITIVE).matcher(header)
        if (stdMatcher.find()) {
            val raw = (stdMatcher.group(1) ?: stdMatcher.group(2) ?: "").trim().replace("\"", "")
            return try { java.net.URLDecoder.decode(raw, "UTF-8") } catch (_: Exception) { raw }
        }
        return null
    }
}

