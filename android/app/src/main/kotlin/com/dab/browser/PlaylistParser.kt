package com.dab.browser

import android.util.LruCache
import org.xmlpull.v1.XmlPullParser
import org.xmlpull.v1.XmlPullParserFactory
import java.io.StringReader
import java.net.URL
import java.util.Locale
import kotlin.math.ceil

object PlaylistKeyCache {
    private val cache = LruCache<String, Map<String, String>>(128)
    @Synchronized fun remember(url: String, headers: Map<String, String>) {
        if (url.isNotBlank() && headers.isNotEmpty()) cache.put(url, headers)
    }
    @Synchronized fun headersFor(url: String): Map<String, String> = cache.get(url) ?: emptyMap()
}

data class PlaylistVariant(
    val label: String,
    val url: String,
    val audioUrl: String? = null,
    val bandwidth: Long = 0L,
    val width: Int = 0,
    val height: Int = 0,
    val format: String = "MP4",
    val type: String = "video"
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "label" to label, "url" to url, "audioUrl" to audioUrl,
        "bandwidth" to bandwidth, "width" to width, "height" to height,
        "format" to format, "type" to type
    )
}

data class MediaSegment(
    val url: String,
    val rangeStart: Long = -1L,
    val rangeEnd: Long = -1L,
    val keyMethod: String? = null,
    val keyUrl: String? = null,
    val ivBytes: ByteArray? = null,
    val sequence: Long = 0L
)

data class ParsedMediaTrack(
    val initUrl: String? = null,
    val initStart: Long = -1L,
    val initEnd: Long = -1L,
    val segments: List<MediaSegment> = emptyList(),
    val drmError: String? = null
)

object PlaylistParser {
    private val attrRegex = Regex("""([A-Za-z0-9_-]+)=("([^"]*)"|[^,\s]+)""")

    fun resolveUrl(base: String, rel: String): String = try {
        val t = rel.trim()
        if (t.startsWith("http://", true) || t.startsWith("https://", true)) t
        else URL(URL(base), t).toString()
    } catch (_: Exception) { rel.trim() }

    fun parseAttrs(line: String): Map<String, String> {
        val raw = line.substringAfter(':', "")
        val out = LinkedHashMap<String, String>()
        for (m in attrRegex.findAll(raw)) {
            val k = m.groupValues[1].uppercase(Locale.ROOT)
            val v = if (m.groupValues[3].isNotEmpty() || m.groupValues[2].startsWith("\"")) m.groupValues[3] else m.groupValues[2]
            out[k] = v
        }
        return out
    }

    fun parseByteRange(spec: String?, prevEnd: Long): Pair<Long, Long> {
        if (spec.isNullOrBlank()) return -1L to -1L
        val parts = spec.trim().split("@")
        val len = parts[0].toLongOrNull() ?: return -1L to -1L
        val offset = parts.getOrNull(1)?.toLongOrNull() ?: if (prevEnd >= 0L) prevEnd + 1L else 0L
        return offset to (offset + len - 1L)
    }

    fun isHlsMaster(text: String): Boolean = text.contains("#EXT-X-STREAM-INF", ignoreCase = true)

    fun parseHlsMaster(text: String, baseUrl: String): List<PlaylistVariant> {
        val audioGroups = HashMap<String, String>()
        val lines = text.lines().map { it.trim() }
        for (line in lines) {
            if (!line.startsWith("#EXT-X-MEDIA:", ignoreCase = true)) continue
            val a = parseAttrs(line)
            if (a["TYPE"]?.equals("AUDIO", true) == true && !a["URI"].isNullOrBlank()) {
                val g = a["GROUP-ID"] ?: ""
                if (!audioGroups.containsKey(g) || a["DEFAULT"]?.equals("YES", true) == true) {
                    audioGroups[g] = resolveUrl(baseUrl, a["URI"]!!)
                }
            }
        }
        val variants = mutableListOf<PlaylistVariant>()
        var i = 0
        while (i < lines.size) {
            val line = lines[i]
            if (line.startsWith("#EXT-X-STREAM-INF:", ignoreCase = true)) {
                val a = parseAttrs(line)
                var j = i + 1
                while (j < lines.size && (lines[j].isEmpty() || lines[j].startsWith("#"))) j++
                if (j < lines.size) {
                    val vUrl = resolveUrl(baseUrl, lines[j])
                    val bw = a["BANDWIDTH"]?.toLongOrNull() ?: a["AVERAGE-BANDWIDTH"]?.toLongOrNull() ?: 0L
                    val res = a["RESOLUTION"]?.lowercase(Locale.ROOT) ?: ""
                    val w = res.substringBefore('x').toIntOrNull() ?: 0
                    val h = res.substringAfter('x', "").toIntOrNull() ?: 0
                    val audioUrl = a["AUDIO"]?.let { audioGroups[it] }
                    val label = when {
                        h > 0 -> "${h}p"
                        bw > 0 -> "${(bw / 1000)} kbps"
                        else -> "Stream ${variants.size + 1}"
                    }
                    variants.add(PlaylistVariant(label, vUrl, audioUrl, bw, w, h, "MP4", "video"))
                    i = j
                }
            }
            i++
        }
        if (audioGroups.isNotEmpty()) {
            val bestAudio = audioGroups.values.first()
            variants.add(PlaylistVariant("Audio Only", bestAudio, null, 0L, 0, 0, "M4A", "audio"))
        }
        return variants.sortedWith(compareByDescending<PlaylistVariant> { it.type == "video" }.thenByDescending { it.height }.thenByDescending { it.bandwidth })
    }

    fun parseHlsMedia(text: String, baseUrl: String): ParsedMediaTrack {
        val lines = text.lines().map { it.trim() }
        var seq = 0L
        var keyMethod: String? = null
        var keyUrl: String? = null
        var keyIv: ByteArray? = null
        var initUrl: String? = null
        var initStart = -1L; var initEnd = -1L
        var nextByteRange: Pair<Long, Long>? = null
        var prevSegEnd = -1L
        val segs = mutableListOf<MediaSegment>()

        for (line in lines) {
            if (line.isEmpty()) continue
            when {
                line.startsWith("#EXT-X-MEDIA-SEQUENCE:", true) -> seq = line.substringAfter(':').trim().toLongOrNull() ?: seq
                line.startsWith("#EXT-X-MAP:", true) -> {
                    val a = parseAttrs(line)
                    a["URI"]?.let { initUrl = resolveUrl(baseUrl, it) }
                    a["BYTERANGE"]?.let { val r = parseByteRange(it, -1L); initStart = r.first; initEnd = r.second }
                }
                line.startsWith("#EXT-X-KEY:", true) -> {
                    val a = parseAttrs(line)
                    val m = a["METHOD"]?.uppercase(Locale.ROOT) ?: "NONE"
                    when (m) {
                        "NONE" -> { keyMethod = null; keyUrl = null; keyIv = null }
                        "AES-128" -> {
                            keyMethod = m
                            keyUrl = a["URI"]?.let { resolveUrl(baseUrl, it) }
                            keyIv = parseHexIv(a["IV"])
                        }
                        else -> return ParsedMediaTrack(drmError = "DRM-protected stream ($m) is not supported")
                    }
                }
                line.startsWith("#EXT-X-BYTERANGE:", true) -> {
                    val r = parseByteRange(line.substringAfter(':'), prevSegEnd)
                    if (r.first >= 0) { nextByteRange = r; prevSegEnd = r.second }
                }
                !line.startsWith("#") -> {
                    val segUrl = resolveUrl(baseUrl, line)
                    val iv = keyIv ?: seqToIv(seq)
                    segs.add(MediaSegment(segUrl, nextByteRange?.first ?: -1L, nextByteRange?.second ?: -1L, keyMethod, keyUrl, iv, seq))
                    nextByteRange = null
                    seq++
                }
            }
        }
        return ParsedMediaTrack(initUrl, initStart, initEnd, segs)
    }

    private fun parseHexIv(hex: String?): ByteArray? {
        if (hex.isNullOrBlank()) return null
        val clean = hex.removePrefix("0x").removePrefix("0X").padStart(32, '0')
        if (clean.length != 32) return null
        return ByteArray(16) { i -> clean.substring(i * 2, i * 2 + 2).toInt(16).toByte() }
    }

    private fun seqToIv(seq: Long): ByteArray {
        val out = ByteArray(16)
        for (i in 0..7) out[15 - i] = ((seq ushr (i * 8)) and 0xFFL).toByte()
        return out
    }

    // --- DASH MPD Parser (XmlPullParser) ---
    data class DashRep(
        val id: String, val type: String, val mime: String, val codecs: String,
        val bandwidth: Long, val width: Int, val height: Int, val track: ParsedMediaTrack
    )

    fun parseMpdDurationSeconds(raw: String?): Double {
        if (raw.isNullOrBlank()) return 0.0
        val m = Regex("""PT(?:(\d+)H)?(?:(\d+)M)?(?:([\d.]+)S)?""", RegexOption.IGNORE_CASE).find(raw) ?: return 0.0
        val h = m.groupValues[1].toDoubleOrNull() ?: 0.0
        val min = m.groupValues[2].toDoubleOrNull() ?: 0.0
        val s = m.groupValues[3].toDoubleOrNull() ?: 0.0
        return h * 3600.0 + min * 60.0 + s
    }

    private class DashTpl(
        var init: String = "", var media: String = "",
        var start: Long = 1L, var scale: Long = 1L, var dur: Long = 0L,
        val timeline: MutableList<Long> = mutableListOf()
    )

    fun parseMpdReps(xml: String, baseUrl: String): Pair<List<DashRep>, String?> {
        val factory = XmlPullParserFactory.newInstance().apply { isNamespaceAware = false }
        val parser = factory.newPullParser().apply { setInput(StringReader(xml)) }
        var mpdDuration = 0.0
        var mpdBase = baseUrl; var periodBase = ""; var asBase = ""; var repBase = ""
        var inMpd = false; var inPeriod = false; var inAs = false; var inRep = false
        var asType = ""; var asMime = ""; var asCodecs = ""; var asDrm = false; var repDrm = false
        var repId = ""; var repMime = ""; var repCodecs = ""; var repBw = 0L; var repW = 0; var repH = 0

        var asTpl: DashTpl? = null; var repTpl: DashTpl? = null; var activeTpl: DashTpl? = null
        var timelineTime = 0L
        var listInit = ""; val listSegs = mutableListOf<String>()
        val reps = mutableListOf<DashRep>()
        var anyDrm = false

        var ev = parser.eventType
        while (ev != XmlPullParser.END_DOCUMENT) {
            when (ev) {
                XmlPullParser.START_TAG -> when (parser.name.lowercase(Locale.ROOT)) {
                    "mpd" -> {
                        inMpd = true
                        mpdDuration = parseMpdDurationSeconds(parser.getAttributeValue(null, "mediaPresentationDuration"))
                    }
                    "period" -> { inPeriod = true; periodBase = mpdBase; val pd = parseMpdDurationSeconds(parser.getAttributeValue(null, "duration")); if (pd > 0) mpdDuration = pd }
                    "adaptationset" -> {
                        inAs = true; asBase = periodBase; asDrm = false; asTpl = null
                        asMime = parser.getAttributeValue(null, "mimeType") ?: ""
                        asCodecs = parser.getAttributeValue(null, "codecs") ?: ""
                        val ct = parser.getAttributeValue(null, "contentType") ?: ""
                        asType = when {
                            ct.equals("audio", true) || asMime.startsWith("audio/", true) -> "audio"
                            ct.equals("video", true) || asMime.startsWith("video/", true) -> "video"
                            else -> ""
                        }
                    }
                    "representation" -> {
                        inRep = true; repBase = asBase; repDrm = false; repTpl = null; listInit = ""; listSegs.clear()
                        repId = parser.getAttributeValue(null, "id") ?: "${reps.size}"
                        repMime = parser.getAttributeValue(null, "mimeType") ?: asMime
                        repCodecs = parser.getAttributeValue(null, "codecs") ?: asCodecs
                        repBw = parser.getAttributeValue(null, "bandwidth")?.toLongOrNull() ?: 0L
                        repW = parser.getAttributeValue(null, "width")?.toIntOrNull() ?: 0
                        repH = parser.getAttributeValue(null, "height")?.toIntOrNull() ?: 0
                    }
                    "contentprotection" -> {
                        val scheme = parser.getAttributeValue(null, "schemeIdUri")?.lowercase(Locale.ROOT) ?: ""
                        if (!scheme.contains("mp4protection")) { if (inRep) repDrm = true else if (inAs) asDrm = true; anyDrm = true }
                    }
                    "baseurl" -> {
                        val txt = parser.nextText().trim()
                        if (txt.isNotEmpty()) {
                            val curBase = when { inRep -> repBase; inAs -> asBase; inPeriod -> periodBase; else -> mpdBase }
                            val resolved = resolveUrl(curBase, txt)
                            when { inRep -> repBase = resolved; inAs -> asBase = resolved; inPeriod -> periodBase = resolved; inMpd -> mpdBase = resolved }
                        }
                    }
                    "segmenttemplate" -> {
                        val t = DashTpl(
                            init = parser.getAttributeValue(null, "initialization") ?: "",
                            media = parser.getAttributeValue(null, "media") ?: "",
                            start = parser.getAttributeValue(null, "startNumber")?.toLongOrNull() ?: 1L,
                            scale = parser.getAttributeValue(null, "timescale")?.toLongOrNull() ?: 1L,
                            dur = parser.getAttributeValue(null, "duration")?.toLongOrNull() ?: 0L
                        )
                        if (inRep) repTpl = t else if (inAs) asTpl = t
                        activeTpl = t; timelineTime = 0L
                    }
                    "s" -> activeTpl?.let { tpl ->
                        val tAttr = parser.getAttributeValue(null, "t")?.toLongOrNull()
                        if (tAttr != null) timelineTime = tAttr
                        val d = parser.getAttributeValue(null, "d")?.toLongOrNull() ?: 0L
                        val r = parser.getAttributeValue(null, "r")?.toIntOrNull() ?: 0
                        if (d > 0 && r >= 0) {
                            for (k in 0..minOf(r, 10000)) { tpl.timeline.add(timelineTime); timelineTime += d }
                        }
                    }
                    "initialization" -> if (inRep) { listInit = parser.getAttributeValue(null, "sourceURL") ?: "" }
                    "segmenturl" -> if (inRep) { parser.getAttributeValue(null, "media")?.let { listSegs.add(it) } }
                }
                XmlPullParser.END_TAG -> when (parser.name.lowercase(Locale.ROOT)) {
                    "segmenttemplate" -> activeTpl = null
                    "representation" -> {
                        if (!asDrm && !repDrm) {
                            val t = when { repType(repMime, asType) == "audio" -> "audio"; repType(repMime, asType) == "video" -> "video"; else -> "" }
                            if (t.isNotEmpty()) {
                                val tpl = repTpl ?: asTpl
                                val track = when {
                                    tpl != null && tpl.media.isNotEmpty() -> buildDashTplTrack(repBase, repId, repBw, tpl, mpdDuration)
                                    listSegs.isNotEmpty() -> ParsedMediaTrack(
                                        initUrl = if (listInit.isNotEmpty()) resolveUrl(repBase, listInit) else null,
                                        segments = listSegs.mapIndexed { idx, u -> MediaSegment(resolveUrl(repBase, u), sequence = idx.toLong()) }
                                    )
                                    else -> ParsedMediaTrack(segments = listOf(MediaSegment(repBase)))
                                }
                                if (track.segments.isNotEmpty()) reps.add(DashRep(repId, t, repMime, repCodecs, repBw, repW, repH, track))
                            }
                        }
                        inRep = false
                    }
                    "adaptationset" -> inAs = false
                    "period" -> inPeriod = false
                    "mpd" -> inMpd = false
                }
            }
            ev = parser.next()
        }
        val err = if (reps.isEmpty() && anyDrm) "DRM-protected DASH stream is not supported" else null
        return reps to err
    }

    private fun repType(mime: String, fallback: String): String = when {
        mime.startsWith("audio/", true) -> "audio"
        mime.startsWith("video/", true) -> "video"
        else -> fallback
    }

    private fun substDash(tplStr: String, repId: String, num: Long, bw: Long, time: Long): String {
        var s = tplStr.replace("\$RepresentationID\$", repId).replace("\$Bandwidth\$", bw.toString()).replace("\$Time\$", time.toString())
        s = s.replace("\$Number\$", num.toString())
        s = Regex("\\\$Number%0(\\d+)d\\\$").replace(s) { m -> num.toString().padStart(m.groupValues[1].toIntOrNull() ?: 1, '0') }
        return s
    }

    private fun buildDashTplTrack(base: String, repId: String, bw: Long, tpl: DashTpl, mpdDuration: Double): ParsedMediaTrack =
        buildDashTplTrackInternal(base, repId, bw, tpl.init, tpl.media, tpl.start, tpl.scale, tpl.dur, tpl.timeline, mpdDuration)

    // Overload taking raw fields cleanly
    private fun buildDashTplTrackInternal(
        base: String, repId: String, bw: Long, initTpl: String, mediaTpl: String,
        startNum: Long, scale: Long, dur: Long, timeline: List<Long>, mpdDuration: Double
    ): ParsedMediaTrack {
        val initUrl = if (initTpl.isNotEmpty()) resolveUrl(base, substDash(initTpl, repId, startNum, bw, 0L)) else null
        val segs = if (timeline.isNotEmpty()) {
            timeline.mapIndexed { idx, tVal ->
                MediaSegment(resolveUrl(base, substDash(mediaTpl, repId, startNum + idx, bw, tVal)), sequence = startNum + idx)
            }
        } else if (dur > 0 && mpdDuration > 0) {
            val count = ceil((mpdDuration * scale) / dur.toDouble()).toInt().coerceIn(1, 20000)
            (0 until count).map { idx ->
                MediaSegment(resolveUrl(base, substDash(mediaTpl, repId, startNum + idx, bw, idx * dur)), sequence = startNum + idx)
            }
        } else emptyList()
        return ParsedMediaTrack(initUrl = initUrl, segments = segs)
    }

    fun inspectMpdVariants(xml: String, baseUrl: String): List<PlaylistVariant> {
        val (reps, _) = parseMpdReps(xml, baseUrl)
        val audios = reps.filter { it.type == "audio" }.sortedByDescending { it.bandwidth }
        val bestAudioUrl = audios.firstOrNull()?.let { "$baseUrl#dashRep=${it.id}" }
        val out = mutableListOf<PlaylistVariant>()
        for (v in reps.filter { it.type == "video" }.sortedWith(compareByDescending<DashRep> { it.height }.thenByDescending { it.bandwidth })) {
            val label = if (v.height > 0) "${v.height}p" else "${v.bandwidth / 1000} kbps"
            out.add(PlaylistVariant(label, "$baseUrl#dashRep=${v.id}", bestAudioUrl, v.bandwidth, v.width, v.height, "MP4", "video"))
        }
        audios.firstOrNull()?.let { a ->
            out.add(PlaylistVariant("Audio Only (${a.bandwidth / 1000} kbps)", "$baseUrl#dashRep=${a.id}", null, a.bandwidth, 0, 0, "M4A", "audio"))
        }
        return out
    }
}
