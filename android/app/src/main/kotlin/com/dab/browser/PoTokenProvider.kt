package com.dab.browser

import android.annotation.SuppressLint
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Base64
import android.util.Log
import android.util.LruCache
import android.webkit.JavascriptInterface
import android.webkit.WebSettings
import android.webkit.WebView
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.CompletableFuture
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * Port of Snaptube's PoTokenWebView + BotGuardPoTokenProvider:
 * runs YouTube's JNN BotGuard challenge inside an isolated offscreen WebView
 * (network loads blocked) and caches the integrity session to mint per-ID pot tokens.
 */
object PoTokenProvider {
    private const val TAG = "PoTokenProvider"
    private const val JNN_CREATE_URL = "https://www.youtube.com/api/jnn/v1/Create"
    private const val JNN_GEN_IT_URL = "https://www.youtube.com/api/jnn/v1/GenerateIT"
    private const val JNN_API_KEY = "AIzaSyDyT5W0Jh49F30Pqqtyfdf7pDLFKLJoAnw"
    private const val JNN_SITE_KEY = "O43z0dpjhgX20SCx4KAo"
    private const val CHROME_UA =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.3"

    private const val BOTGUARD_HTML = """<!DOCTYPE html><html lang=en><head><title></title><script>
function loadBotGuard(a){this.vm=this[a.globalName];this.program=a.program;this.vmFunctions={};if(!this.vm||!this.vm.a){throw new Error("BotGuard VM missing");}const b=function(c,e,f,d){this.vmFunctions={asyncSnapshotFunction:c,shutdownFunction:e,passEventFunction:f,checkCameraFunction:d}};this.vm.a(this.program,b,true,this.userInteractionElement,function(){},[[],[]]);return new Promise(function(d,c){var i=0;var id=setInterval(function(){if(this.vmFunctions.asyncSnapshotFunction){clearInterval(id);d(this);}else if(++i>=10000){clearInterval(id);c("asyncSnapshot timeout");}},1);})}
function snapshot(a){return new Promise(function(c,b){if(!this.vmFunctions.asyncSnapshotFunction)return b(new Error("asyncSnapshot missing"));this.vmFunctions.asyncSnapshotFunction(function(d){c(d)},[a.contentBinding,a.signedTimestamp,a.webPoSignalOutput,a.skipPrivacyBuffer])})}
function runBotGuard(c){const b=c.interpreterJavascript.privateDoNotAccessOrElseSafeScriptWrappedValue;if(!b)throw new Error("Could not load VM");new Function(b)();const a=[];return loadBotGuard({globalName:c.globalName,globalObj:this,program:c.program}).then(function(d){return d.snapshot({webPoSignalOutput:a})}).then(function(d){return{webPoSignalOutput:a,botguardResponse:d}})}
function obtainPoToken(c,f,d){const b=c[0];if(!b)throw new Error("PMD:Undefined");const e=b(f);if(!(e instanceof Function))throw new Error("APF:Failed");const a=e(d);if(!a||!(a instanceof Uint8Array))throw new Error("ODM:Invalid");return a}
PoTokenWebView.downloadAndRunBotguard()</script></head><body></body></html>"""

    private val mainHandler = Handler(Looper.getMainLooper())
    private val ioPool = Executors.newSingleThreadExecutor()
    private val tokenCache = LruCache<String, String>(16)
    @Volatile private var session: BotGuardSession? = null
    private val sessionLock = Any()
    private val idleCloseRunnable = Runnable { resetSession() }
    private const val IDLE_CLOSE_MS = 45_000L

    fun mint(context: Context, identifier: String): String? {
        if (identifier.isBlank()) return null
        tokenCache.get(identifier)?.let { return it }
        mainHandler.removeCallbacks(idleCloseRunnable)
        return try {
            val active = getOrCreateSession(context.applicationContext)
            val token = active.mint(identifier)
            if (!token.isNullOrBlank()) tokenCache.put(identifier, token)
            mainHandler.postDelayed(idleCloseRunnable, IDLE_CLOSE_MS)
            token
        } catch (e: Exception) {
            Log.w(TAG, "PoToken mint failed for ${identifier.take(12)}: ${e.message}")
            resetSession()
            null
        }
    }

    private fun getOrCreateSession(appContext: Context): BotGuardSession {
        synchronized(sessionLock) {
            val cur = session
            if (cur != null && !cur.isExpired()) return cur
            cur?.close()
            val created = BotGuardSession(appContext)
            created.awaitReady()
            session = created
            return created
        }
    }

    private fun resetSession() {
        synchronized(sessionLock) {
            session?.close()
            session = null
        }
    }

    @SuppressLint("SetJavaScriptEnabled", "JavascriptInterface")
    private class BotGuardSession(context: Context) {
        private val readyFuture = CompletableFuture<Unit>()
        private val pendingMints = ConcurrentHashMap<String, CompletableFuture<String>>()
        private var webView: WebView? = null
        @Volatile private var expiresAtMs = -1L
        @Volatile private var closed = false

        init {
            mainHandler.post {
                if (closed) return@post
                try {
                    val wv = WebView(context)
                    wv.settings.apply {
                        javaScriptEnabled = true
                        blockNetworkLoads = true
                        userAgentString = CHROME_UA
                    }
                    wv.addJavascriptInterface(this, "PoTokenWebView")
                    webView = wv
                    wv.loadDataWithBaseURL("https://www.youtube.com", BOTGUARD_HTML, "text/html", "utf-8", null)
                } catch (t: Throwable) {
                    readyFuture.completeExceptionally(t)
                }
            }
        }

        fun isExpired(): Boolean = closed || SystemClock.elapsedRealtime() > expiresAtMs

        fun awaitReady() {
            readyFuture.get(12, TimeUnit.SECONDS)
        }

        fun mint(identifier: String): String? {
            if (isExpired()) throw IllegalStateException("BotGuard session expired")
            val f = CompletableFuture<String>()
            pendingMints[identifier] = f
            val bytesLiteral = toJsUint8Array(identifier.toByteArray(Charsets.UTF_8))
            val safeId = JSONObject.quote(identifier)
            val js = """try{const p=obtainPoToken(webPoSignalOutput,integrityToken,$bytesLiteral);var s="";for(var i=0;i<p.length;i++){if(i)s+=",";s+=p[i]}PoTokenWebView.onObtainPoTokenResult($safeId,s)}catch(e){PoTokenWebView.onObtainPoTokenError($safeId,String(e))}"""
            mainHandler.post {
                val wv = webView
                if (closed || wv == null) f.completeExceptionally(IllegalStateException("WebView closed"))
                else wv.evaluateJavascript(js, null)
            }
            return f.get(6, TimeUnit.SECONDS)
        }

        @JavascriptInterface
        fun downloadAndRunBotguard() {
            ioPool.execute {
                try {
                    val raw = postJnn(JNN_CREATE_URL, JSONArray().put(JNN_SITE_KEY).toString())
                    val dataJson = parseCreatePayload(raw)
                    val js = "try{runBotGuard($dataJson).then(function(r){this.webPoSignalOutput=r.webPoSignalOutput;PoTokenWebView.onRunBotguardResult(r.botguardResponse)},function(e){PoTokenWebView.onJsInitializationError(String(e))})}catch(e){PoTokenWebView.onJsInitializationError(String(e))}"
                    mainHandler.post { webView?.evaluateJavascript(js, null) }
                } catch (t: Throwable) {
                    readyFuture.completeExceptionally(t)
                }
            }
        }

        @JavascriptInterface
        fun onRunBotguardResult(botguardResponse: String) {
            ioPool.execute {
                try {
                    val body = JSONArray().put(JNN_SITE_KEY).put(botguardResponse).toString()
                    val raw = postJnn(JNN_GEN_IT_URL, body)
                    val arr = JSONArray(raw)
                    val tokenBytes = decodeUrlBase64(arr.getString(0))
                    val ttlSec = arr.getLong(1)
                    expiresAtMs = SystemClock.elapsedRealtime() + ((ttlSec - 600L).coerceAtLeast(60L) * 1000L)
                    val js = "this.integrityToken = ${toJsUint8Array(tokenBytes)};"
                    mainHandler.post {
                        webView?.evaluateJavascript(js) { readyFuture.complete(Unit) }
                            ?: readyFuture.completeExceptionally(IllegalStateException("WebView null"))
                    }
                } catch (t: Throwable) {
                    readyFuture.completeExceptionally(t)
                }
            }
        }

        @JavascriptInterface
        fun onJsInitializationError(error: String) {
            readyFuture.completeExceptionally(IllegalStateException("BotGuard JS error: $error"))
        }

        @JavascriptInterface
        fun onObtainPoTokenResult(identifier: String, poTokenCsv: String) {
            try {
                val bytes = poTokenCsv.split(",").map { it.trim().toInt().toByte() }.toByteArray()
                val encoded = Base64.encodeToString(bytes, Base64.NO_WRAP)
                    .replace('+', '-').replace('/', '_')
                pendingMints.remove(identifier)?.complete(encoded)
            } catch (t: Throwable) {
                pendingMints.remove(identifier)?.completeExceptionally(t)
            }
        }

        @JavascriptInterface
        fun onObtainPoTokenError(identifier: String, error: String) {
            pendingMints.remove(identifier)?.completeExceptionally(IllegalStateException(error))
        }

        fun close() {
            if (closed) return
            closed = true
            pendingMints.values.forEach { it.completeExceptionally(IllegalStateException("closed")) }
            pendingMints.clear()
            mainHandler.post {
                webView?.apply {
                    removeJavascriptInterface("PoTokenWebView")
                    loadUrl("about:blank")
                    onPause()
                    removeAllViews()
                    destroy()
                }
                webView = null
            }
        }
    }

    private fun postJnn(url: String, body: String): String {
        val req = Request.Builder()
            .url(url)
            .post(body.toRequestBody("application/json+protobuf".toMediaType()))
            .header("User-Agent", CHROME_UA)
            .header("Accept", "application/json")
            .header("x-goog-api-key", JNN_API_KEY)
            .header("x-user-agent", "grpc-web-javascript/0.1")
            .build()
        DownloadHttpHelper.client.newCall(req).execute().use { resp ->
            val str = resp.body?.string().orEmpty()
            if (resp.code != 200) throw IllegalStateException("JNN HTTP ${resp.code}")
            return str
        }
    }

    private fun parseCreatePayload(raw: String): String {
        val outer = JSONArray(raw)
        val inner = if (outer.length() > 1 && outer.opt(1) is String) {
            val bytes = decodeUrlBase64(outer.getString(1))
            val shifted = ByteArray(bytes.size) { i -> (bytes[i] + 97).toByte() }
            JSONArray(String(shifted, Charsets.UTF_8))
        } else {
            outer.getJSONArray(0)
        }
        val jsArr = inner.optJSONArray(1)
        val urlArr = inner.optJSONArray(2)
        val safeJs = (0 until (jsArr?.length() ?: 0)).firstNotNullOfOrNull { idx ->
            jsArr?.opt(idx) as? String
        }
        val safeUrl = (0 until (urlArr?.length() ?: 0)).firstNotNullOfOrNull { idx ->
            urlArr?.opt(idx) as? String
        }
        return JSONObject().apply {
            put("messageId", inner.optString(0))
            put("interpreterJavascript", JSONObject().apply {
                if (safeJs != null) put("privateDoNotAccessOrElseSafeScriptWrappedValue", safeJs)
                if (safeUrl != null) put("privateDoNotAccessOrElseTrustedResourceUrlWrappedValue", safeUrl)
            })
            put("interpreterHash", inner.optString(3))
            put("program", inner.optString(4))
            put("globalName", inner.optString(5))
            put("clientExperimentsStateBlob", inner.optString(7))
        }.toString()
    }

    private fun decodeUrlBase64(input: String): ByteArray {
        val normalized = input.replace('-', '+').replace('_', '/').replace('.', '=')
        return Base64.decode(normalized, Base64.DEFAULT)
    }

    private fun toJsUint8Array(bytes: ByteArray): String =
        bytes.joinToString(prefix = "new Uint8Array([", postfix = "])", separator = ",") {
            (it.toInt() and 0xFF).toString()
        }
}
