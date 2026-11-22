package com.dab.browser

import android.util.Log
import okhttp3.Headers
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import java.io.IOException
import java.io.InputStream
import java.net.URL
import java.net.URLDecoder
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.concurrent.TimeUnit
import java.util.regex.Pattern

data class ProbeResult(
    val finalUrl: String,
    val contentLength: Long,
    val supportsRanges: Boolean,
    val contentType: String?,
    val suggestedFileName: String?,
    val errorMessage: String? = null
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "finalUrl" to finalUrl, "contentLength" to contentLength,
        "supportsRanges" to supportsRanges, "contentType" to contentType,
        "suggestedFileName" to suggestedFileName, "errorMessage" to errorMessage
    )
}

class StreamResponse(
    val code: Int,
    val headers: Headers,
    val byteStream: InputStream,
    val finalUrl: String,
    private val rawResponse: Response
) : AutoCloseable {
    fun header(name: String): String? = headers[name]
    override fun close() {
        try { byteStream.close() } catch (_: Exception) {}
        rawResponse.close()
    }
}

object DownloadHttpHelper {
    private const val TAG = "DownloadHttp"
    const val USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    val client: OkHttpClient by lazy {
        OkHttpClient.Builder()
            .dns(DownloadDns)
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .followRedirects(false)
            .followSslRedirects(false)
            .build()
    }

    fun openStream(
        urlStr: String,
        rangeHeader: String? = null,
        referer: String? = null,
        method: String = "GET"
    ): StreamResponse {
        var current = urlStr
        for (hop in 0 until 8) {
            val host = try { URL(current).host } catch (_: Exception) { "" }
            val isYt = host.contains("googlevideo.com")
            val ref = when {
                isYt || referer?.contains("googlevideo.com") == true -> null
                !referer.isNullOrBlank() -> referer
                host.isNotEmpty() -> "https://$host/"
                else -> null
            }

            val reqBuilder = Request.Builder()
                .url(current)
                .method(method, null)
                .header("User-Agent", USER_AGENT)
                .header("Accept", "*/*")
            if (ref != null) reqBuilder.header("Referer", ref)
            if (rangeHeader != null) reqBuilder.header("Range", rangeHeader)

            val response = client.newCall(reqBuilder.build()).execute()
            val code = response.code
            Log.d(TAG, "Hop $hop: $host -> HTTP $code (Range: $rangeHeader)")

            if (code in 300..399) {
                val loc = response.header("Location") ?: break
                current = if (loc.startsWith("http")) loc else URL(URL(current), loc).toString()
                response.close()
                continue
            }

            val body = response.body ?: throw IOException("HTTP $code with empty response body from $current")
            return StreamResponse(code, response.headers, body.byteStream(), current, response)
        }
        throw IOException("Too many redirects (>8) while connecting to $urlStr")
    }

    fun probeUrl(urlStr: String, referer: String? = null): ProbeResult = try {
        val stream = openStream(urlStr, rangeHeader = "bytes=0-0", referer = referer, method = "GET")
        stream.use { s ->
            val finalUrl = s.finalUrl
            val cType = s.header("Content-Type")?.lowercase(Locale.ROOT)
            val code = s.code
            val cr = s.header("Content-Range")
            val crTotal = cr?.substringAfterLast("/")?.trim()?.toLongOrNull()?.takeIf { it > 0 }
            val contentLen = s.header("Content-Length")?.toLongOrNull() ?: -1L
            val parsedLen = when {
                crTotal != null -> crTotal
                code == 206 -> if (contentLen > 1) contentLen else -1L
                code in 200..299 -> contentLen
                else -> -1L
            }

            val len = if (parsedLen <= 0 && code in 200..399) {
                try {
                    openStream(finalUrl, referer = referer, method = "HEAD").use { h ->
                        h.header("Content-Length")?.toLongOrNull() ?: parsedLen
                    }
                } catch (_: Exception) { parsedLen }
            } else parsedLen

            val supportsRanges = code == 206 || code == 416 || s.header("Accept-Ranges")?.contains("bytes", true) == true
            val cd = s.header("Content-Disposition")
            val fileName = parseContentDisposition(cd)
            ProbeResult(finalUrl, len, supportsRanges, cType, fileName, if (code >= 400) "HTTP $code" else null)
        }
    } catch (e: Exception) {
        Log.e(TAG, "probeUrl failed for $urlStr: ${e.message}", e)
        ProbeResult(urlStr, -1L, false, null, null, e.message ?: "Probe failed")
    }

    fun validateRangeResponse(resp: StreamResponse, expectedStart: Long, isRangedRequest: Boolean): Boolean {
        val code = resp.code
        if (!isRangedRequest) return code in 200..299
        if (code != 206) return false
        val cr = resp.header("Content-Range") ?: return true
        val matcher = Pattern.compile("bytes\\s+(\\d+)-(\\d+)/").matcher(cr)
        if (matcher.find()) {
            val start = matcher.group(1)?.toLongOrNull() ?: return true
            return start == expectedStart
        }
        return true
    }

    fun parseRetryAfter(header: String?): Long? {
        if (header.isNullOrBlank()) return null
        header.trim().toLongOrNull()?.let { return (it * 1000L).coerceIn(1000L, 120000L) }
        try {
            val format = SimpleDateFormat("EEE, dd MMM yyyy HH:mm:ss zzz", Locale.US)
            val date = format.parse(header.trim())
            if (date != null) return (date.time - System.currentTimeMillis()).coerceIn(1000L, 120000L)
        } catch (_: Exception) {}
        return null
    }

    private fun parseContentDisposition(header: String?): String? {
        if (header.isNullOrBlank()) return null
        val uMatcher = Pattern.compile("filename\\*\\s*=\\s*(?:UTF-8''|utf-8'')([^;]+)", Pattern.CASE_INSENSITIVE).matcher(header)
        if (uMatcher.find()) {
            val raw = uMatcher.group(1)?.trim()?.replace("\"", "") ?: ""
            return try { URLDecoder.decode(raw, "UTF-8") } catch (_: Exception) { raw }
        }
        val sMatcher = Pattern.compile("filename\\s*=\\s*\"([^\"]+)\"|filename\\s*=\\s*([^; ]+)", Pattern.CASE_INSENSITIVE).matcher(header)
        if (sMatcher.find()) {
            val raw = (sMatcher.group(1) ?: sMatcher.group(2) ?: "").trim().replace("\"", "")
            return try { URLDecoder.decode(raw, "UTF-8") } catch (_: Exception) { raw }
        }
        return null
    }
}
