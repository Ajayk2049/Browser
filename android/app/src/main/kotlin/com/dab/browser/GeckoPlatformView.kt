package com.dab.browser

import android.content.Context
import android.view.View
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import org.mozilla.geckoview.*

class GeckoPlatformView(
    context: Context,
    id: Int,
    creationParams: Map<String?, Any?>?,
    messenger: BinaryMessenger
) : PlatformView, MethodChannel.MethodCallHandler {

    companion object {
        private val downloadExtensions = listOf(
            ".apk", ".zip", ".rar", ".7z", ".tar", ".gz", ".bin", ".iso",
            ".pdf", ".dmg", ".exe", ".torrent"
        )
        private val mediaExtensions = listOf(
            ".mp4", ".mkv", ".webm", ".avi", ".mov", ".m4a", ".mp3", ".aac",
            ".wav", ".flac", ".ogg", ".opus", ".m3u8", ".ts"
        )
    }

    private val geckoView = GeckoView(context)
    private val session = GeckoSession(
        GeckoSessionSettings.Builder()
            .usePrivateMode(creationParams?.get("isPrivate") as? Boolean ?: false)
            .useTrackingProtection(true)
            .build()
    )
    private val channel = MethodChannel(messenger, "com.dab/geckoview_$id")
    private var runtime: GeckoRuntime? = null
    private var currentTitle: String = ""

    init {
        channel.setMethodCallHandler(this)
        runtime = GeckoRuntimeProvider.get(context)
        session.open(runtime!!)
        geckoView.setSession(session)
        ExtensionManager.attachSession(session)
        android.util.Log.d("NavPerf", "Session opened, activating")
        android.util.Log.d("NavPerf", "setActive(true) on session ${System.identityHashCode(session)}")
        session.setActive(true)

        geckoView.isFocusable = true; geckoView.isFocusableInTouchMode = true
        geckoView.setOnTouchListener { v, _ -> if (!v.hasFocus()) v.requestFocus(); false }

        setupDelegates()

        val fontFactor = (creationParams?.get("fontSizeFactor") as? Number)?.toFloat() ?: 1.0f
        runtime?.settings?.fontSizeFactor = fontFactor

        val initialUrl = creationParams?.get("initialUrl") as? String
        if (!initialUrl.isNullOrEmpty()) {
            session.loadUri(initialUrl)
        }
    }

    private fun isDownloadable(url: String): Boolean {
        val clean = url.substringBefore('?').substringBefore('#')
        return downloadExtensions.any { clean.endsWith(it) } || url.contains(".torrent")
    }

    private fun isMediaStream(url: String): Boolean {
        val clean = url.substringBefore('?').substringBefore('#')
        return mediaExtensions.any { clean.endsWith(it) } ||
                url.contains("googlevideo.com/videoplayback") ||
                url.contains("/hls/") || url.contains(".m3u8?")
    }

    private fun getMediaType(url: String): String {
        return if (url.contains("audio") || url.endsWith(".mp3") || url.endsWith(".m4a") || url.endsWith(".aac")) "audio"
        else if (url.contains(".m3u8") || url.contains("/hls/")) "stream"
        else "video"
    }

    private fun invokeFlutter(method: String, arguments: Any?) {
        if (android.os.Looper.myLooper() == android.os.Looper.getMainLooper()) {
            channel.invokeMethod(method, arguments)
        } else {
            geckoView.post { channel.invokeMethod(method, arguments) }
        }
    }

    private fun setupDelegates() {
        session.contentBlockingDelegate = object : ContentBlocking.Delegate {
            override fun onContentBlocked(s: GeckoSession, event: ContentBlocking.BlockEvent) {
                android.util.Log.d("ExtDebug", "Blocked content: uri=${event.uri}")
            }
        }
        session.navigationDelegate = object : GeckoSession.NavigationDelegate {
            override fun onLocationChange(
                s: GeckoSession,
                url: String?,
                perms: MutableList<GeckoSession.PermissionDelegate.ContentPermission>,
                hasUserGesture: Boolean
            ) {
                invokeFlutter("onLocationChange", mapOf("url" to (url ?: "")))
            }

            override fun onCanGoBack(s: GeckoSession, canGoBack: Boolean) {
                invokeFlutter("onCanGoBack", mapOf("canGoBack" to canGoBack))
            }

            override fun onCanGoForward(s: GeckoSession, canGoForward: Boolean) {
                invokeFlutter("onCanGoForward", mapOf("canGoForward" to canGoForward))
            }

            override fun onLoadRequest(
                s: GeckoSession,
                request: GeckoSession.NavigationDelegate.LoadRequest
            ): GeckoResult<AllowOrDeny>? {
                val uri = request.uri
                val lower = uri.lowercase()
                if (lower.startsWith("magnet:") || isDownloadable(lower)) {
                    invokeFlutter("onDownloadPrompt", mapOf("url" to uri))
                    return GeckoResult.fromValue(AllowOrDeny.DENY)
                }
                if (isMediaStream(lower)) {
                    invokeFlutter("onMediaDetected", mapOf("url" to uri, "title" to currentTitle.ifEmpty { "Media Stream" }, "type" to getMediaType(lower)))
                }
                return GeckoResult.fromValue(AllowOrDeny.ALLOW)
            }

            override fun onNewSession(s: GeckoSession, uri: String): GeckoResult<GeckoSession>? {
                val lower = uri.lowercase()
                if (lower.startsWith("magnet:") || isDownloadable(lower)) {
                    invokeFlutter("onDownloadPrompt", mapOf("url" to uri))
                    return null
                }
                if (isMediaStream(lower)) {
                    invokeFlutter("onMediaDetected", mapOf("url" to uri, "title" to currentTitle.ifEmpty { "Media Stream" }, "type" to getMediaType(lower)))
                }
                session.loadUri(uri)
                return null
            }

            override fun onLoadError(s: GeckoSession, uri: String?, error: WebRequestError): GeckoResult<String>? {
                invokeFlutter(
                    "onWebResourceError",
                    mapOf(
                        "uri" to (uri ?: ""),
                        "code" to error.code,
                        "category" to error.category,
                        "message" to "Error ${error.code} in category ${error.category}"
                    )
                )
                return null
            }
        }

        session.progressDelegate = object : GeckoSession.ProgressDelegate {
            override fun onPageStart(s: GeckoSession, url: String) {
                invokeFlutter("onPageStart", mapOf("url" to url))
            }

            override fun onPageStop(s: GeckoSession, success: Boolean) {
                invokeFlutter("onPageStop", mapOf("success" to success))
            }

            override fun onProgressChange(s: GeckoSession, progress: Int) {
                invokeFlutter("onProgressChange", mapOf("progress" to progress))
            }
        }

        session.contentDelegate = object : GeckoSession.ContentDelegate {
            override fun onTitleChange(s: GeckoSession, title: String?) {
                currentTitle = title ?: ""
                invokeFlutter("onTitleChange", mapOf("title" to currentTitle))
            }

            override fun onExternalResponse(s: GeckoSession, response: WebResponse) {
                val url = response.uri
                try { response.body?.close() } catch (_: Exception) {}
                if (isMediaStream(url.lowercase())) {
                    invokeFlutter("onMediaDetected", mapOf("url" to url, "title" to currentTitle.ifEmpty { "Media Stream" }, "type" to getMediaType(url.lowercase())))
                } else {
                    invokeFlutter("onDownloadPrompt", mapOf("url" to url))
                }
            }
        }
    }

    override fun getView(): View = geckoView

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setActive" -> {
                val active = call.argument<Boolean>("active") ?: true
                android.util.Log.d("NavPerf", "setActive($active) on session ${System.identityHashCode(session)}")
                session.setActive(active)
                result.success(true)
            }
            "loadUrl" -> {
                val url = call.argument<String>("url") ?: ""
                android.util.Log.d("NavPerf", "setActive(true) on session ${System.identityHashCode(session)}")
                session.setActive(true)
                session.loadUri(url)
                result.success(true)
            }
            "goBack" -> { session.goBack(); result.success(true) }
            "goForward" -> { session.goForward(); result.success(true) }
            "reload" -> { session.reload(); result.success(true) }
            "setFontSizeFactor" -> {
                val factor = (call.argument<Number>("factor"))?.toFloat() ?: 1.0f
                runtime?.settings?.fontSizeFactor = factor
                result.success(true)
            }
            "findInPage" -> {
                val text = call.argument<String>("text") ?: ""
                val forward = call.argument<Boolean>("forward") ?: true
                if (text.isNotEmpty()) {
                    val flags = if (forward) GeckoSession.FINDER_FIND_FORWARD else GeckoSession.FINDER_FIND_BACKWARDS
                    session.finder.find(text, flags).accept { res ->
                        invokeFlutter("onFinderResult", mapOf("current" to (res?.current ?: 0), "total" to (res?.total ?: 0), "searchString" to (res?.searchString ?: "")))
                    }
                } else {
                    session.finder.clear()
                    invokeFlutter("onFinderResult", mapOf("current" to 0, "total" to 0, "searchString" to ""))
                }
                result.success(true)
            }
            "clearFindInPage" -> { session.finder.clear(); result.success(true) }
            else -> result.notImplemented()
        }
    }

    override fun dispose() {
        channel.setMethodCallHandler(null)
        session.close()
        geckoView.releaseSession()
    }
}
