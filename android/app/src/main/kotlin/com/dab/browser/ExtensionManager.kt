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

    private val channel = MethodChannel(messenger, "com.dab/extensions")
    private val runtime: GeckoRuntime = GeckoRuntimeProvider.get(context)
    private val controller: WebExtensionController get() = runtime.webExtensionController
    private val prefs: SharedPreferences = context.getSharedPreferences("ext_prefs", Context.MODE_PRIVATE)

    init {
        channel.setMethodCallHandler(this)
        setupPromptDelegate()
        org.mozilla.geckoview.GeckoSession().open(runtime)

        ensureGoogleSearchFixer {
            installUBlockFromAmoIfNeeded()
            Log.i("ExtDebug", "post-AMO-install state check")
            runtime.webExtensionController.list().accept({ extensions ->
                extensions?.forEach { ext ->
                    Log.i("ExtDebug", "  ext: id=${ext.id}, name=${ext.metaData.name}, builtIn=${ext.isBuiltIn}, disabledFlags=${ext.metaData.disabledFlags}")
                }
            }, { error -> Log.e("ExtDebug", "post-install list failed", error) })
            logExtensionState("startup")
        }
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
            Log.i("ExtDebug", "Google Search Fixer ensured: id=${ext?.id}, builtIn=${ext?.isBuiltIn}, disabledFlags=${ext?.metaData?.disabledFlags}")
            notifyExtensionsChanged()
            onComplete?.invoke()
        }, { error ->
            Log.e("ExtDebug", "Google Search Fixer ensureBuiltIn FAILED", error)
            onComplete?.invoke()
        })
    }

    private fun installUBlockFromAmoIfNeeded() {
        if (prefs.getBoolean("ublock_amo_install_attempted", false)) {
            Log.d("ExtDebug", "uBlock AMO install already attempted; skipping")
            return
        }
        runtime.webExtensionController.list().accept({ extensions ->
            val ublock = extensions?.find { it.id.contains("uBlock", ignoreCase = true) }
            if (ublock != null) {
                Log.i("ExtDebug", "uBlock already installed: id=${ublock.id}, enabled=${ublock.metaData.disabledFlags == 0}")
                prefs.edit().putBoolean("ublock_amo_install_attempted", true).apply()
                return@accept
            }
            Log.i("ExtDebug", "uBlock not installed; installing from AMO")
            val amoUrl = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi"
            runtime.webExtensionController.install(amoUrl).accept({ ext ->
                Log.i("ExtDebug", "uBlock installed from AMO: id=${ext?.id}")
                prefs.edit().putBoolean("ublock_amo_install_attempted", true).apply()
                notifyExtensionsChanged()
            }, { error -> Log.e("ExtDebug", "uBlock AMO install failed", error) })
        }, { error -> Log.e("ExtDebug", "list() failed while checking for uBlock", error) })
    }

    private fun logExtensionState(trigger: String) {
        runtime.webExtensionController.list().accept({ extensions ->
            Log.i("ExtDebug", "=== Extension state dump (trigger=$trigger) ===")
            if (extensions.isNullOrEmpty()) Log.w("ExtDebug", "  (no extensions installed)")
            extensions?.forEach { ext ->
                Log.i("ExtDebug", "  id=${ext.id} name=${ext.metaData.name} version=${ext.metaData.version} builtIn=${ext.isBuiltIn} disabledFlags=${ext.metaData.disabledFlags}")
                if (ext.id.contains("uBlock", ignoreCase = true)) {
                    Log.i("ExtDebug", "uBlock optionsPageUrl=${ext.metaData.optionsPageUrl}")
                }
            }
            Log.i("ExtDebug", "=== End dump ===")
        }, { error -> Log.e("ExtDebug", "State dump failed (trigger=$trigger)", error) })
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
                    val msg = if (allPerms.isNotEmpty()) "Permissions:\n• " + allPerms.joinToString("\n• ") else "No special permissions."
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
                    val msg = if (all.isNotEmpty()) "Update requires:\n• " + all.joinToString("\n• ") else "Update $name?"
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
