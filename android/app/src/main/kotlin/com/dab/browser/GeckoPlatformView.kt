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
            ".mp4", ".mkv", ".avi", ".mp3", ".pdf", ".dmg", ".exe", ".torrent"
        )
    }

    private val geckoView = GeckoView(context)
    private val session = GeckoSession(
        GeckoSessionSettings.Builder()
            .useTrackingProtection(true)
            .build()
    )
    private val channel = MethodChannel(messenger, "com.dab/geckoview_$id")
    private var runtime: GeckoRuntime? = null

    init {
        channel.setMethodCallHandler(this)
        runtime = GeckoRuntimeProvider.get(context)
        session.open(runtime!!)
        geckoView.setSession(session)

        geckoView.isFocusable = true
        geckoView.isFocusableInTouchMode = true
        geckoView.setOnTouchListener { v, _ ->
            if (!v.hasFocus()) {
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
                return GeckoResult.fromValue(AllowOrDeny.ALLOW)
            }

            override fun onNewSession(s: GeckoSession, uri: String): GeckoResult<GeckoSession>? {
                val lower = uri.lowercase()
                if (lower.startsWith("magnet:") || isDownloadable(lower)) {
                    invokeFlutter("onDownloadPrompt", mapOf("url" to uri))
                    return null
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
                invokeFlutter("onTitleChange", mapOf("title" to (title ?: "")))
            }

            override fun onExternalResponse(s: GeckoSession, response: WebResponse) {
                val url = response.uri
                try { response.body?.close() } catch (_: Exception) {}
                invokeFlutter("onDownloadPrompt", mapOf("url" to url))
            }
        }
    }

    override fun getView(): View = geckoView

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "loadUrl" -> { session.loadUri(call.argument<String>("url") ?: ""); result.success(true) }
            "goBack" -> { session.goBack(); result.success(true) }
            "goForward" -> { session.goForward(); result.success(true) }
            "reload" -> { session.reload(); result.success(true) }
            "setFontSizeFactor" -> {
                val factor = (call.argument<Number>("factor"))?.toFloat() ?: 1.0f
                runtime?.settings?.fontSizeFactor = factor
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    override fun dispose() {
        channel.setMethodCallHandler(null)
        session.close()
        geckoView.releaseSession()
    }
}
