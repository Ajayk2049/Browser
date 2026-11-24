package com.dab.browser

import android.app.AlertDialog
import android.content.Context
import android.content.SharedPreferences
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mozilla.geckoview.*

/// Manages WebExtensions via GeckoRuntime's WebExtensionController.
class ExtensionManager(
    private val context: Context,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val SNIFFER_ID = "media-sniffer@dab.browser"
        private const val SNIFFER_APP = "dab.sniffer"

        @Volatile
        private var shared: ExtensionManager? = null

        /// Forwards a sniffed stream URL reported by a browser session to Dart.
        @JvmStatic
        fun reportSniffedMedia(url: String, pageUrl: String, itag: String, mime: String) {
            shared?.forwardSniffed(url, pageUrl, itag, mime)
        }

        /// Registers the media-sniffer message delegate on [session] so its
        /// content script can reach the app.
        @JvmStatic
        fun attachSession(session: GeckoSession) {
            shared?.attachSnifferSession(session)
        }
    }

    private val channel = MethodChannel(messenger, "com.dab/extensions")
    private val runtime: GeckoRuntime get() = GeckoRuntimeProvider.get(context)
    private val controller: WebExtensionController get() = runtime.webExtensionController
    private val prefs: SharedPreferences = context.getSharedPreferences("ext_prefs", Context.MODE_PRIVATE)

    @Volatile
    private var snifferExt: WebExtension? = null
    private val pendingSessions = mutableListOf<GeckoSession>()

    init {
        shared = this
        channel.setMethodCallHandler(this)
        setupPromptDelegate()

        Handler(Looper.getMainLooper()).postDelayed({
            ensureGoogleSearchFixer()
            ensureMediaSniffer()
        }, 1500)
    }

    private fun runOnUiThread(block: () -> Unit) = Handler(Looper.getMainLooper()).post(block)

    private fun notifyExtensionsChanged() {
        runOnUiThread {
            Log.d("ExtDebug", "Notifying Dart of extensions change")
            channel.invokeMethod("onExtensionsChanged", null)
        }
    }

    private fun dispatchResult(method: String, action: () -> Unit) {
        Log.d("ExtDebug", "Dispatching result for method=$method on thread=${Thread.currentThread().name}")
        runOnUiThread {
            Log.d("ExtDebug", "Result delivered on thread=${Thread.currentThread().name} (isMain=${Looper.myLooper() == Looper.getMainLooper()})")
            action()
        }
    }

    private fun ensureGoogleSearchFixer(onComplete: (() -> Unit)? = null) {
        val gsfId = "{58c32ac4-0d6c-4d6f-ae2c-96aaf8ffcb66}"
        runtime.webExtensionController.ensureBuiltIn("resource://android/assets/extensions/google_search_fixer/", gsfId).accept({ ext ->
            notifyExtensionsChanged(); onComplete?.invoke()
        }, { onComplete?.invoke() })
    }

    /// Bundled extension that observes the page's own googlevideo traffic and
    /// forwards the (attested, session-bound) stream URLs to Dart. These are
    /// the only URLs YouTube reliably serves to non-player clients nowadays.
    private fun ensureMediaSniffer(attempt: Int = 0) {
        runtime.webExtensionController.ensureBuiltIn("resource://android/assets/extensions/media_sniffer/", SNIFFER_ID).accept({ ext ->
            if (ext == null) {
                Log.w("ExtDebug", "MediaSniffer ensureBuiltIn returned null (attempt $attempt)")
                return@accept
            }
            Log.i("ExtDebug", "MediaSniffer installed id=${ext.id} enabled=${ext.metaData.enabled}")
            snifferExt = ext
            runOnUiThread {
                try {
                    ext.setMessageDelegate(snifferDelegate, SNIFFER_APP)
                    Log.i("ExtDebug", "MediaSniffer message delegate registered")
                } catch (e: Exception) {
                    Log.w("ExtDebug", "MediaSniffer delegate registration failed", e)
                }
                for (s in pendingSessions.toList()) bindSniffer(ext, s)
                pendingSessions.clear()
            }
        }, { err ->
            Log.w("ExtDebug", "MediaSniffer ensureBuiltIn failed (attempt $attempt): ${err?.message}")
            // Gecko may not be listening yet on a cold start; retry briefly.
            if (attempt < 10) {
                Handler(Looper.getMainLooper()).postDelayed({ ensureMediaSniffer(attempt + 1) }, 1500)
            }
        })
    }

    /// Content scripts talk to the app through their *session*, so every
    /// GeckoSession needs its own delegate for the same native app name.
    fun attachSnifferSession(session: GeckoSession) {
        runOnUiThread {
            val ext = snifferExt
            if (ext != null) bindSniffer(ext, session) else pendingSessions.add(session)
        }
    }

    private fun bindSniffer(ext: WebExtension, session: GeckoSession) {
        try {
            session.webExtensionController.setMessageDelegate(ext, snifferDelegate, SNIFFER_APP)
            Log.i("ExtDebug", "MediaSniffer session delegate bound to ${System.identityHashCode(session)}")
        } catch (e: Exception) {
            Log.w("ExtDebug", "MediaSniffer session delegate failed", e)
        }
    }

    private val snifferDelegate = object : WebExtension.MessageDelegate {
        override fun onMessage(
            nativeApp: String,
            message: Any,
            sender: WebExtension.MessageSender
        ): GeckoResult<Any>? {
            try {
                fun str(key: String): String = when (message) {
                    is org.json.JSONObject -> message.optString(key, "")
                    is Map<*, *> -> message[key] as? String ?: ""
                    else -> ""
                }
                fun bool(key: String): Boolean = when (message) {
                    is org.json.JSONObject -> message.optBoolean(key, false)
                    is Map<*, *> -> message[key] as? Boolean ?: false
                    else -> false
                }
                if (message !is org.json.JSONObject && message !is Map<*, *>) return null
                val type = str("type").ifEmpty { "media" }
                if (type == "hello") {
                    Log.i("ExtDebug", "MediaSniffer hello from=${str("from").ifEmpty { "background" }} webRequest=${bool("hasWebRequest")} listener=${bool("hasOnBeforeRequest")}")
                    return null
                }
                if (type == "error") {
                    Log.w("ExtDebug", "MediaSniffer script error: ${str("message")}")
                    return null
                }
                val url = str("url")
                val pageUrl = str("pageUrl")
                val itag = str("itag")
                val mime = str("mime")
                if (url.isNotEmpty()) {
                    Log.d("ExtDebug", "Sniffed itag=$itag url=${url.take(400)}")
                    forwardSniffed(url, pageUrl, itag, mime)
                }
            } catch (e: Exception) {
                Log.w("ExtDebug", "MediaSniffer message parse failed", e)
            }
            return null
        }
    }

    private fun forwardSniffed(url: String, pageUrl: String, itag: String, mime: String) {
        runOnUiThread {
            channel.invokeMethod("onSniffedMedia", mapOf(
                "url" to url, "pageUrl" to pageUrl, "itag" to itag, "mime" to mime
            ))
        }
    }

    private fun logExtensionState(trigger: String) {
        runtime.webExtensionController.list().accept({ list ->
            Log.i("ExtDebug", "Extensions ($trigger): ${list?.map { it.id }}")
        }, {})
    }

    private fun setupPromptDelegate() {
        controller.promptDelegate = object : WebExtensionController.PromptDelegate {
            override fun onInstallPromptRequest(
                ext: WebExtension, perms: Array<out String>, origins: Array<out String>, data: Array<out String>
            ): GeckoResult<WebExtension.PermissionPromptResponse>? {
                Log.i("ExtDebug", "Prompt requested: id=${ext.id}, perms=${perms.toList()}, origins=${origins.toList()}")
                if (ext.location.startsWith("resource://") || ext.location.contains(context.cacheDir.name) ||
                    ext.id.contains("uBlock", ignoreCase = true) || ext.location.contains("ublock", ignoreCase = true)) {
                    Log.i("ExtDebug", "Auto-approving install permissions for ${ext.id}")
                    return GeckoResult.fromValue(WebExtension.PermissionPromptResponse(true, true, true))
                }
                val result = GeckoResult<WebExtension.PermissionPromptResponse>()
                dispatchResult("onInstallPrompt") {
                    val name = ext.metaData.name ?: "Unknown Extension"
                    val allPerms = (perms.toList() + origins.toList()).filter { it.isNotEmpty() }
                    val msg = if (allPerms.isNotEmpty()) "Permissions:\nâ€¢ " + allPerms.joinToString("\nâ€¢ ") else "No special permissions."
                    AlertDialog.Builder(context).setTitle("Add $name?").setMessage(msg)
                        .setPositiveButton("Add") { _, _ -> result.complete(WebExtension.PermissionPromptResponse(true, true, true)) }
                        .setNegativeButton("Cancel") { _, _ -> result.complete(WebExtension.PermissionPromptResponse(false, false, false)) }
                        .setOnCancelListener { result.complete(WebExtension.PermissionPromptResponse(false, false, false)) }.show()
                }
                return result
            }

            override fun onUpdatePrompt(
                ext: WebExtension, perms: Array<out String>, origins: Array<out String>, data: Array<out String>
            ): GeckoResult<AllowOrDeny>? {
                val result = GeckoResult<AllowOrDeny>()
                dispatchResult("onUpdatePrompt") {
                    val name = ext.metaData.name ?: "Extension"
                    val all = (perms.toList() + origins.toList()).filter { it.isNotEmpty() }
                    val msg = if (all.isNotEmpty()) "Update requires:\nâ€¢ " + all.joinToString("\nâ€¢ ") else "Update $name?"
                    AlertDialog.Builder(context).setTitle("Update $name?").setMessage(msg)
                        .setPositiveButton("Update") { _, _ -> result.complete(AllowOrDeny.ALLOW) }
                        .setNegativeButton("Skip") { _, _ -> result.complete(AllowOrDeny.DENY) }
                        .setOnCancelListener { result.complete(AllowOrDeny.DENY) }.show()
                }
                return result
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "install" -> {
                val url = call.argument<String>("url") ?: ""
                if (url.isEmpty()) return dispatchResult(call.method) { result.error("INVALID_URL", "URL empty", null) }
                controller.install(url).accept({ ext ->
                    logExtensionState("method:install")
                    notifyExtensionsChanged()
                    dispatchResult(call.method) { if (ext != null) result.success(extensionToMap(ext)) else result.error("INSTALL_ERROR", "Null ext", null) }
                }, { err -> dispatchResult(call.method) { result.error("INSTALL_ERROR", err?.message, null) } })
            }
            "list" -> {
                controller.list().accept({ list ->
                    Log.i("ExtDebug", "controller.list returned ${list?.size} extensions: ${list?.map { it.id }}")
                    val mapped = list?.map { extensionToMap(it) } ?: emptyList<Map<String, Any?>>()
                    dispatchResult(call.method) { result.success(mapped) }
                }, { err -> dispatchResult(call.method) { result.error("LIST_ERROR", err?.message, null) } })
            }
            "update" -> {
                val id = call.argument<String>("id") ?: ""
                findExtension(id) { ext ->
                    if (ext != null) controller.update(ext).accept({ up ->
                        logExtensionState("method:update")
                        notifyExtensionsChanged()
                        dispatchResult(call.method) { result.success(up?.let { extensionToMap(it) } ?: emptyMap<String, Any?>()) }
                    }, { err -> dispatchResult(call.method) { result.error("UPDATE_ERROR", err?.message, null) } })
                    else dispatchResult(call.method) { result.error("NOT_FOUND", "Extension $id not found", null) }
                }
            }
            "enable" -> {
                val id = call.argument<String>("id") ?: ""
                findExtension(id) { ext ->
                    if (ext != null) controller.enable(ext, WebExtensionController.EnableSource.USER).accept({
                        logExtensionState("method:enable")
                        notifyExtensionsChanged()
                        dispatchResult(call.method) { result.success(true) }
                    }, { err -> dispatchResult(call.method) { result.error("ENABLE_ERROR", err?.message, null) } })
                    else dispatchResult(call.method) { result.error("NOT_FOUND", "Extension $id not found", null) }
                }
            }
            "disable" -> {
                val id = call.argument<String>("id") ?: ""
                findExtension(id) { ext ->
                    if (ext != null) controller.disable(ext, WebExtensionController.EnableSource.USER).accept({
                        logExtensionState("method:disable")
                        notifyExtensionsChanged()
                        dispatchResult(call.method) { result.success(true) }
                    }, { err -> dispatchResult(call.method) { result.error("DISABLE_ERROR", err?.message, null) } })
                    else dispatchResult(call.method) { result.error("NOT_FOUND", "Extension $id not found", null) }
                }
            }
            "uninstall" -> {
                val id = call.argument<String>("id") ?: ""
                findExtension(id) { ext ->
                    if (ext != null) {
                        prefs.edit().putBoolean("uninstalled_$id", true).apply()
                        if (id.contains("uBlock", ignoreCase = true)) prefs.edit().putBoolean("ublock_amo_install_attempted", true).apply()
                        controller.uninstall(ext).accept({
                            logExtensionState("method:uninstall")
                            notifyExtensionsChanged()
                            dispatchResult(call.method) { result.success(true) }
                        }, { err -> dispatchResult(call.method) { result.error("UNINSTALL_ERROR", err?.message, null) } })
                    } else dispatchResult(call.method) { result.error("NOT_FOUND", "Extension $id not found", null) }
                }
            }
            else -> dispatchResult(call.method) { result.notImplemented() }
        }
    }

    private fun findExtension(id: String, onFound: (WebExtension?) -> Unit) {
        controller.list().accept({ list ->
            val match = list?.firstOrNull { it.id == id || (id.contains("uBlock", ignoreCase = true) && it.id.contains("uBlock", ignoreCase = true)) }
            onFound(match)
        }, { onFound(null) })
    }

    private fun extensionToMap(ext: WebExtension): Map<String, Any?> {
        val meta = ext.metaData
        var displayName = meta.name
        if (displayName.isNullOrEmpty() || displayName == "__MSG_addonName__") {
            displayName = if (ext.location.contains("google_search_fixer") || ext.id.contains("searchfixer") || ext.id == "{58c32ac4-0d6c-4d6f-ae2c-96aaf8ffcb66}") "Google Search Fixer" else ext.id
        }
        var desc = meta.description ?: ""
        if (desc.startsWith("__MSG_") || desc.isEmpty()) {
            desc = if (ext.id.contains("uBlock", ignoreCase = true) || ext.location.contains("ublock")) "Finally, an efficient wide-spectrum content blocker. Easy on CPU and memory."
            else if (ext.location.contains("google_search_fixer") || ext.id == "{58c32ac4-0d6c-4d6f-ae2c-96aaf8ffcb66}") "Fixes Google Search mobile experience on GeckoView." else desc
        }
        return mapOf(
            "id" to ext.id,
            "name" to displayName,
            "version" to meta.version,
            "description" to desc,
            "creatorName" to (meta.creatorName ?: ""),
            "creatorUrl" to (meta.creatorUrl ?: ""),
            "homepageUrl" to (meta.homepageUrl ?: ""),
            "optionsPageUrl" to (meta.optionsPageUrl ?: ""),
            "isEnabled" to meta.enabled
        )
    }
}
