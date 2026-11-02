package com.dab.browser

import android.app.AlertDialog
import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mozilla.geckoview.AllowOrDeny
import org.mozilla.geckoview.GeckoResult
import org.mozilla.geckoview.GeckoRuntime
import org.mozilla.geckoview.WebExtension
import org.mozilla.geckoview.WebExtensionController
import java.io.File
import java.io.FileOutputStream

/// Manages WebExtensions via GeckoRuntime's WebExtensionController.
/// Handles pre-installed built-in extensions, install from remote URL (AMO),
/// list, enable, disable, update, and uninstall.
class ExtensionManager(
    private val context: Context,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "com.dab/extensions")
    private val runtime: GeckoRuntime = GeckoRuntime.getDefault(context)
    private val controller: WebExtensionController get() = runtime.webExtensionController
    private val prefs: SharedPreferences = context.getSharedPreferences("extension_prefs", Context.MODE_PRIVATE)

    init {
        channel.setMethodCallHandler(this)
        setupPromptDelegate()
        ensurePreinstalledExtensions()
    }

    private fun ensurePreinstalledExtensions() {
        controller.list().accept(
            { list ->
                val installedIds = list?.map { it.id }?.toSet() ?: emptySet()

                // 1. uBlock Origin
                val ublockId = "uBlock0@raymondhill.net"
                val ublockUninstalled = prefs.getBoolean("uninstalled_$ublockId", false)
                if (!ublockUninstalled && !installedIds.contains(ublockId)) {
                    installAssetXpi("extensions/ublock_origin.xpi") { ext ->
                        Log.d("ExtensionManager", "uBlock Origin installed: ${ext?.id}")
                    }
                }

                // 2. Google Search Fixer
                val gsfId = "{58c32ac4-0d6c-4d6f-ae2c-96aaf8ffcb66}"
                val gsfUninstalled = prefs.getBoolean("uninstalled_$gsfId", false)
                val hasGsf = list?.any {
                    it.id == gsfId || it.metaData.name?.contains("Google Search", ignoreCase = true) == true
                } == true
                if (!gsfUninstalled && !hasGsf) {
                    installAssetXpi("extensions/google_search_fixer.xpi") { ext ->
                        Log.d("ExtensionManager", "Google Search Fixer installed: ${ext?.id}")
                    }
                }
            },
            { Log.e("ExtensionManager", "Failed to check installed extensions for pre-installation", it) }
        )
    }

    private fun installAssetXpi(assetPath: String, onDone: (WebExtension?) -> Unit) {
        try {
            val fileName = File(assetPath).name
            val destFile = File(context.cacheDir, fileName)
            context.assets.open(assetPath).use { input ->
                FileOutputStream(destFile).use { output ->
                    input.copyTo(output)
                }
            }
            val fileUri = destFile.toURI().toString()
            controller.install(fileUri).accept(
                { ext -> onDone(ext) },
                { err ->
                    Log.e("ExtensionManager", "Failed to install $assetPath via $fileUri", err)
                    onDone(null)
                }
            )
        } catch (e: Exception) {
            Log.e("ExtensionManager", "Error extracting asset $assetPath to cache", e)
            onDone(null)
        }
    }

    private fun setupPromptDelegate() {
        controller.promptDelegate = object : WebExtensionController.PromptDelegate {
            override fun onInstallPrompt(extension: WebExtension): GeckoResult<AllowOrDeny>? {
                // If it's a bundled asset installed from local storage or resource://, auto-allow
                val loc = extension.location
                if (loc.startsWith("resource://") || loc.contains(context.cacheDir.name) ||
                    loc.contains("ublock_origin") || loc.contains("google_search_fixer")) {
                    return GeckoResult.fromValue(AllowOrDeny.ALLOW)
                }

                val result = GeckoResult<AllowOrDeny>()
                (context as? android.app.Activity)?.runOnUiThread {
                    val name = extension.metaData.name ?: "Unknown Extension"
                    val permissions = extension.metaData.permissions?.toList() ?: emptyList()
                    val origins = extension.metaData.origins?.toList() ?: emptyList()
                    val allPerms = (permissions + origins).filter { it.isNotEmpty() }
                    
                    val msg = if (allPerms.isNotEmpty()) {
                        "It will have access to:\n• " + allPerms.joinToString("\n• ")
                    } else {
                        "This extension requests no special permissions."
                    }

                    AlertDialog.Builder(context)
                        .setTitle("Add $name?")
                        .setMessage(msg)
                        .setPositiveButton("Add") { _, _ -> result.complete(AllowOrDeny.ALLOW) }
                        .setNegativeButton("Cancel") { _, _ -> result.complete(AllowOrDeny.DENY) }
                        .setOnCancelListener { result.complete(AllowOrDeny.DENY) }
                        .show()
                } ?: run {
                    result.complete(AllowOrDeny.ALLOW)
                }

                return result
            }

            override fun onUpdatePrompt(
                current: WebExtension,
                updated: WebExtension,
                newPermissions: Array<out String>,
                newOrigins: Array<out String>
            ): GeckoResult<AllowOrDeny>? {
                val result = GeckoResult<AllowOrDeny>()
                (context as? android.app.Activity)?.runOnUiThread {
                    val name = updated.metaData.name ?: current.metaData.name ?: "Extension"
                    val perms = (newPermissions.toList() + newOrigins.toList()).filter { it.isNotEmpty() }
                    val msg = if (perms.isNotEmpty()) {
                        "An update for $name requires new permissions:\n• " + perms.joinToString("\n• ")
                    } else {
                        "Update $name to the latest version?"
                    }

                    AlertDialog.Builder(context)
                        .setTitle("Update $name?")
                        .setMessage(msg)
                        .setPositiveButton("Update") { _, _ -> result.complete(AllowOrDeny.ALLOW) }
                        .setNegativeButton("Skip") { _, _ -> result.complete(AllowOrDeny.DENY) }
                        .setOnCancelListener { result.complete(AllowOrDeny.DENY) }
                        .show()
                } ?: run {
                    result.complete(AllowOrDeny.ALLOW)
                }
                return result
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "install" -> {
                val url = call.argument<String>("url") ?: ""
                if (url.isEmpty()) {
                    result.error("INVALID_URL", "Extension URL cannot be empty", null)
                    return
                }
                controller.install(url).accept(
                    { ext ->
                        if (ext != null) result.success(extensionToMap(ext))
                        else result.error("INSTALL_ERROR", "Extension install returned null", null)
                    },
                    { throwable ->
                        result.error("INSTALL_ERROR", throwable?.message ?: "Failed to install extension", null)
                    }
                )
            }
            "list" -> {
                controller.list().accept(
                    { list ->
                        val mapped = list?.map { extensionToMap(it) } ?: emptyList<Map<String, Any?>>()
                        result.success(mapped)
                    },
                    { throwable ->
                        result.error("LIST_ERROR", throwable?.message ?: "Failed to list extensions", null)
                    }
                )
            }
            "update" -> {
                val id = call.argument<String>("id") ?: ""
                findExtension(id) { ext ->
                    val extension = ext
                    if (extension != null) {
                        controller.update(extension).accept(
                            { updated -> result.success(updated?.let { extensionToMap(it) } ?: emptyMap<String, Any?>()) },
                            { throwable -> result.error("UPDATE_ERROR", throwable?.message, null) }
                        )
                    } else {
                        result.error("NOT_FOUND", "Extension $id not found", null)
                    }
                }
            }
            "enable" -> {
                val id = call.argument<String>("id") ?: ""
                findExtension(id) { ext ->
                    if (ext != null) {
                        controller.enable(ext, WebExtensionController.EnableSource.USER).accept(
                            { _ -> result.success(true) },
                            { throwable -> result.error("ENABLE_ERROR", throwable?.message, null) }
                        )
                    } else {
                        result.error("NOT_FOUND", "Extension $id not found", null)
                    }
                }
            }
            "disable" -> {
                val id = call.argument<String>("id") ?: ""
                findExtension(id) { ext ->
                    if (ext != null) {
                        controller.disable(ext, WebExtensionController.EnableSource.USER).accept(
                            { _ -> result.success(true) },
                            { throwable -> result.error("DISABLE_ERROR", throwable?.message, null) }
                        )
                    } else {
                        result.error("NOT_FOUND", "Extension $id not found", null)
                    }
                }
            }
            "uninstall" -> {
                val id = call.argument<String>("id") ?: ""
                findExtension(id) { ext ->
                    if (ext != null) {
                        prefs.edit().putBoolean("uninstalled_$id", true).apply()
                        controller.uninstall(ext).accept(
                            { _ -> result.success(true) },
                            { throwable -> result.error("UNINSTALL_ERROR", throwable?.message, null) }
                        )
                    } else {
                        result.error("NOT_FOUND", "Extension $id not found", null)
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun findExtension(id: String, onFound: (WebExtension?) -> Unit) {
        controller.list().accept(
            { list ->
                val match = list?.firstOrNull { it.id == id }
                onFound(match)
            },
            { onFound(null) }
        )
    }

    private fun extensionToMap(ext: WebExtension): Map<String, Any?> {
        val meta = ext.metaData
        var displayName = meta.name
        if (displayName.isNullOrEmpty() || displayName == "__MSG_addonName__") {
            if (ext.location.contains("google_search_fixer") || ext.id.contains("searchfixer")) {
                displayName = "Google Search Fixer"
            } else {
                displayName = ext.id
            }
        }
        return mapOf(
            "id" to ext.id,
            "name" to displayName,
            "version" to (meta.version ?: "1.0.0"),
            "description" to (meta.description ?: ""),
            "creatorName" to (meta.creatorName ?: ""),
            "creatorUrl" to (meta.creatorUrl ?: ""),
            "homepageUrl" to (meta.homepageUrl ?: ""),
            "isEnabled" to meta.enabled
        )
    }
}
