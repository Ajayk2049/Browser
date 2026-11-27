package com.dab.browser

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
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

    private val geckoContext: Context = context
    private val geckoView = GeckoView(context)
    private val session = GeckoSession(
        GeckoSessionSettings.Builder()
            .usePrivateMode(creationParams?.get("isPrivate") as? Boolean ?: false)
            .useTrackingProtection(true)
            .suspendMediaWhenInactive(true)
            .build()
    )
    private val channel = MethodChannel(messenger, "com.dab/geckoview_$id")
    private var runtime: GeckoRuntime? = null
    private var currentTitle: String = ""
    private var currentPageUrl: String = ""
    private var isSessionActive: Boolean = creationParams?.get("isActive") as? Boolean ?: true

    init {
        channel.setMethodCallHandler(this)
        runtime = GeckoRuntimeProvider.get(context)
        session.open(runtime!!)
        geckoView.setSession(session)
        ExtensionManager.attachSession(session)
        android.util.Log.d("NavPerf", "Session opened, active=$isSessionActive")
        session.setActive(isSessionActive)
        session.setPriorityHint(if (isSessionActive) GeckoSession.PRIORITY_HIGH else GeckoSession.PRIORITY_DEFAULT)

        geckoView.isFocusable = true
        geckoView.isFocusableInTouchMode = true
        geckoView.descendantFocusability = ViewGroup.FOCUS_AFTER_DESCENDANTS
        geckoView.setOnTouchListener { v, event ->
            if (event.action == MotionEvent.ACTION_DOWN && !v.hasFocus()) {
                v.requestFocus()
            }
            false
        }

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

    private fun isSearchOrUiMedia(url: String, pageUrl: String): Boolean {
        val u = url.lowercase()
        val p = pageUrl.lowercase()
        if (u.contains("gstatic.com/") || u.contains("translate.google.") || u.contains("google.com/speech-api")) {
            return true
        }
        return p.contains("google.") && p.contains("/search") ||
            p.contains("bing.com/search") ||
            p.contains("duckduckgo.com/") ||
            p.contains("search.brave.com/") ||
            p.contains("startpage.com/")
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

    private tailrec fun Context.findActivity(): Activity? = when (this) {
        is Activity -> this
        is ContextWrapper -> baseContext.findActivity()
        else -> null
    }

    private fun setupDelegates() {
        geckoContext.findActivity()?.let { activity ->
            session.selectionActionDelegate = BrowserSelectionActionDelegate(activity) { text ->
                invokeFlutter("onSearchSelectedText", mapOf("text" to text))
            }
        }
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
                currentPageUrl = url ?: ""
                invokeFlutter("onLocationChange", mapOf("url" to currentPageUrl))
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
                if (lower.startsWith("blob:") || lower.startsWith("data:")) {
                    return GeckoResult.fromValue(AllowOrDeny.ALLOW)
                }
                if (lower.startsWith("magnet:") || isDownloadable(lower)) {
                    invokeFlutter("onDownloadPrompt", mapOf("url" to uri))
                    return GeckoResult.fromValue(AllowOrDeny.DENY)
                }
                if (isMediaStream(lower) && !isSearchOrUiMedia(uri, currentPageUrl)) {
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
                if (isMediaStream(lower) && !isSearchOrUiMedia(uri, currentPageUrl)) {
                    invokeFlutter("onMediaDetected", mapOf("url" to uri, "title" to currentTitle.ifEmpty { "Media Stream" }, "type" to getMediaType(lower)))
                }
                session.loadUri(uri)
                return null
            }

            override fun onLoadError(s: GeckoSession, uri: String?, error: WebRequestError): GeckoResult<String>? {
                val errorKey = when (error.code) {
                    WebRequestError.ERROR_OFFLINE -> "OFFLINE"
                    WebRequestError.ERROR_UNKNOWN_HOST -> "UNKNOWN_HOST"
                    WebRequestError.ERROR_NET_TIMEOUT -> "NET_TIMEOUT"
                    WebRequestError.ERROR_CONNECTION_REFUSED -> "CONNECTION_REFUSED"
                    WebRequestError.ERROR_NET_RESET -> "NET_RESET"
                    WebRequestError.ERROR_NET_INTERRUPT -> "NET_INTERRUPT"
                    WebRequestError.ERROR_MALFORMED_URI -> "MALFORMED_URI"
                    WebRequestError.ERROR_UNKNOWN_PROTOCOL -> "UNSUPPORTED_PROTOCOL"
                    WebRequestError.ERROR_HTTPS_ONLY -> "HTTPS_ONLY"
                    WebRequestError.ERROR_BAD_HSTS_CERT -> "BAD_HSTS_CERT"
                    WebRequestError.ERROR_SECURITY_SSL -> "SECURITY_SSL"
                    WebRequestError.ERROR_SECURITY_BAD_CERT -> "SECURITY_BAD_CERT"
                    WebRequestError.ERROR_REDIRECT_LOOP -> "REDIRECT_LOOP"
                    WebRequestError.ERROR_UNKNOWN_PROXY_HOST -> "UNKNOWN_PROXY_HOST"
                    WebRequestError.ERROR_PROXY_CONNECTION_REFUSED -> "PROXY_CONNECTION_REFUSED"
                    WebRequestError.ERROR_CONTENT_CRASHED -> "CONTENT_CRASHED"
                    WebRequestError.ERROR_SAFEBROWSING_MALWARE_URI,
                    WebRequestError.ERROR_SAFEBROWSING_PHISHING_URI,
                    WebRequestError.ERROR_SAFEBROWSING_UNWANTED_URI,
                    WebRequestError.ERROR_SAFEBROWSING_HARMFUL_URI -> "SAFEBROWSING"
                    else -> "UNKNOWN"
                }
                val categoryName = when (error.category) {
                    WebRequestError.ERROR_CATEGORY_SECURITY -> "SECURITY"
                    WebRequestError.ERROR_CATEGORY_NETWORK -> "NETWORK"
                    WebRequestError.ERROR_CATEGORY_CONTENT -> "CONTENT"
                    WebRequestError.ERROR_CATEGORY_URI -> "URI"
                    WebRequestError.ERROR_CATEGORY_PROXY -> "PROXY"
                    WebRequestError.ERROR_CATEGORY_SAFEBROWSING -> "SAFEBROWSING"
                    else -> "UNKNOWN"
                }
                invokeFlutter(
                    "onWebResourceError",
                    mapOf(
                        "uri" to (uri ?: ""),
                        "code" to error.code,
                        "errorKey" to errorKey,
                        "categoryName" to categoryName
                    )
                )
                return null
            }
        }

        session.progressDelegate = object : GeckoSession.ProgressDelegate {
            override fun onPageStart(s: GeckoSession, url: String) {
                currentPageUrl = url
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

            override fun onContextMenu(
                s: GeckoSession,
                screenX: Int,
                screenY: Int,
                element: GeckoSession.ContentDelegate.ContextElement
            ) {
                val hasLink = !element.linkUri.isNullOrEmpty()
                val hasSrc = !element.srcUri.isNullOrEmpty()
                if (!hasLink && !hasSrc) return
                val mediaType = when (element.type) {
                    GeckoSession.ContentDelegate.ContextElement.TYPE_IMAGE -> "image"
                    GeckoSession.ContentDelegate.ContextElement.TYPE_VIDEO -> "video"
                    GeckoSession.ContentDelegate.ContextElement.TYPE_AUDIO -> "audio"
                    else -> "none"
                }
                geckoView.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
                invokeFlutter(
                    "onContextMenu",
                    mapOf(
                        "baseUri" to (element.baseUri ?: ""),
                        "linkUri" to (element.linkUri ?: ""),
                        "srcUri" to (element.srcUri ?: ""),
                        "title" to (element.title ?: ""),
                        "altText" to (element.altText ?: ""),
                        "textContent" to (element.textContent ?: ""),
                        "type" to mediaType
                    )
                )
            }

            override fun onExternalResponse(s: GeckoSession, response: WebResponse) {
                val url = response.uri
                if (response.body != null && WebResponseDownloader.shouldStreamDirectly(url)) {
                    WebResponseDownloader.streamToDownloads(geckoContext, response)
                    return
                }
                var contentType = ""
                var contentDisposition = ""
                for ((k, v) in response.headers) {
                    if (k.equals("content-type", ignoreCase = true)) contentType = v.lowercase()
                    else if (k.equals("content-disposition", ignoreCase = true)) contentDisposition = v.lowercase()
                }
                try { response.body?.close() } catch (_: Exception) {}
                val lower = url.lowercase()
                val isAttachment = contentDisposition.contains("attachment")
                val isInlineMedia = isMediaStream(lower) || contentType.startsWith("audio/") || contentType.startsWith("video/")
                if (isAttachment) {
                    invokeFlutter("onDownloadPrompt", mapOf("url" to url))
                } else if (isInlineMedia) {
                    if (!isSearchOrUiMedia(url, currentPageUrl)) {
                        val type = if (contentType.startsWith("audio/")) "audio" else getMediaType(lower)
                        invokeFlutter("onMediaDetected", mapOf("url" to url, "title" to currentTitle.ifEmpty { "Media Stream" }, "type" to type))
                    }
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
                val priorityHigh = call.argument<Boolean>("priorityHigh") ?: active
                isSessionActive = active
                session.setActive(active)
                session.setPriorityHint(if (priorityHigh) GeckoSession.PRIORITY_HIGH else GeckoSession.PRIORITY_DEFAULT)
                result.success(true)
            }
            "onResume" -> {
                session.setActive(isSessionActive)
                session.setPriorityHint(if (isSessionActive) GeckoSession.PRIORITY_HIGH else GeckoSession.PRIORITY_DEFAULT)
                if (geckoView.session == null) {
                    geckoView.setSession(session)
                }
                if (isSessionActive) {
                    geckoView.invalidate()
                    geckoView.requestLayout()
                }
                result.success(true)
            }
            "loadUrl" -> {
                val url = call.argument<String>("url") ?: ""
                isSessionActive = true
                session.setActive(true)
                session.setPriorityHint(GeckoSession.PRIORITY_HIGH)
                session.loadUri(url)
                result.success(true)
            }
            "proceedInsecure" -> {
                val url = call.argument<String>("url") ?: ""
                runtime?.settings?.allowInsecureConnections = GeckoRuntimeSettings.ALLOW_ALL
                session.setActive(true)
                if (url.isNotEmpty()) {
                    session.loadUri(url)
                } else {
                    session.reload()
                }
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
