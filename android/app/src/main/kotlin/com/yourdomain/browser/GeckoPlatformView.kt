package com.yourdomain.browser

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

    private val geckoView = GeckoView(context)
    private val session = GeckoSession()
    private val channel = MethodChannel(messenger, "com.yourdomain/geckoview_$id")
    private var runtime: GeckoRuntime? = null

    init {
        channel.setMethodCallHandler(this)
        runtime = GeckoRuntime.getDefault(context)
        session.open(runtime!!)
        geckoView.setSession(session)

        setupDelegates()

        val initialUrl = creationParams?.get("initialUrl") as? String
        if (!initialUrl.isNullOrEmpty()) {
            session.loadUri(initialUrl)
        }
    }

    private fun setupDelegates() {
        session.navigationDelegate = object : GeckoSession.NavigationDelegate {
            override fun onLocationChange(s: GeckoSession, url: String?, perms: MutableList<GeckoSession.PermissionDelegate.ContentPermission>) {
                channel.invokeMethod("onLocationChange", mapOf("url" to (url ?: "")))
            }

            override fun onCanGoBack(s: GeckoSession, canGoBack: Boolean) {
                channel.invokeMethod("onCanGoBack", mapOf("canGoBack" to canGoBack))
            }

            override fun onCanGoForward(s: GeckoSession, canGoForward: Boolean) {
                channel.invokeMethod("onCanGoForward", mapOf("canGoForward" to canGoForward))
            }

            override fun onLoadError(s: GeckoSession, uri: String?, error: WebRequestError): GeckoResult<String>? {
                channel.invokeMethod(
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
                channel.invokeMethod("onPageStart", mapOf("url" to url))
            }

            override fun onPageStop(s: GeckoSession, success: Boolean) {
                channel.invokeMethod("onPageStop", mapOf("success" to success))
            }

            override fun onProgressChange(s: GeckoSession, progress: Int) {
                channel.invokeMethod("onProgressChange", mapOf("progress" to progress))
            }
        }

        session.contentDelegate = object : GeckoSession.ContentDelegate {
            override fun onTitleChange(s: GeckoSession, title: String?) {
                channel.invokeMethod("onTitleChange", mapOf("title" to (title ?: "")))
            }
        }
    }

    override fun getView(): View = geckoView

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "loadUrl" -> {
                val url = call.argument<String>("url") ?: ""
                session.loadUri(url)
                result.success(true)
            }
            "goBack" -> {
                session.goBack()
                result.success(true)
            }
            "goForward" -> {
                session.goForward()
                result.success(true)
            }
            "reload" -> {
                session.reload()
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

