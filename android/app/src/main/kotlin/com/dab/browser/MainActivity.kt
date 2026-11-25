package com.dab.browser

import android.Manifest
import android.util.Log
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.*
import android.content.pm.PackageManager
import android.os.*
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.*
import kotlinx.coroutines.*
import org.mozilla.geckoview.StorageController
import java.io.File

class MainActivity : FlutterActivity() {
    private val methodChannelName = "com.dab/downloader"
    private val eventChannelName = "com.dab/downloads/updates"
    private var downloadService: DownloadService? = null
    private var isBound = false
    private var eventSink: EventChannel.EventSink? = null
    private var downloaderChannel: MethodChannel? = null
    private var extensionManager: ExtensionManager? = null

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            downloadService = (service as DownloadService.LocalBinder).getService()
            isBound = true
        }
        override fun onServiceDisconnected(name: ComponentName?) {
            downloadService = null; isBound = false
        }
    }

    private fun ensureDownloadServiceBound() {
        if (!isBound) {
            val intent = Intent(this, DownloadService::class.java)
            startService(intent); bindService(intent, connection, Context.BIND_AUTO_CREATE)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.platformViewsController.registry.registerViewFactory("com.dab/geckoview", GeckoViewFactory(flutterEngine.dartExecutor.binaryMessenger))
        extensionManager = ExtensionManager(this, flutterEngine.dartExecutor.binaryMessenger)

        downloaderChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
        downloaderChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "warmupGecko" -> {
                    ensureDownloadServiceBound()
                    CoroutineScope(Dispatchers.Default).launch {
                        try { GeckoRuntimeProvider.get(applicationContext) } catch (_: Exception) {}
                    }
                    result.success(true)
                }
                "startDownload" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                        ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 101)
                    }
                    ensureDownloadServiceBound()
                    val id = call.argument<String>("taskId") ?: ""
                    val url = call.argument<String>("url") ?: ""
                    val dest = call.argument<String>("destinationPath") ?: ""
                    val segs = call.argument<Int>("segmentsCount") ?: 8
                    val startNow = call.argument<Boolean>("startNow") ?: true
                    val ref = call.argument<String>("referer")
                    val audioUrl = call.argument<String>("audioUrl")
                    val audioBytes = (call.argument<Number>("audioBytes"))?.toLong() ?: 0L
                    val totalBytes = (call.argument<Number>("totalBytes"))?.toLong() ?: -1L
                    if (id.isNotEmpty() && url.isNotEmpty() && dest.isNotEmpty()) {
                        if (downloadService != null) {
                            downloadService?.startDownload(id, url, dest, segs, startNow, ref, totalBytes, audioUrl, audioBytes)
                        } else {
                            CoroutineScope(Dispatchers.Main).launch {
                                for (i in 0 until 30) {
                                    if (downloadService != null) break
                                    delay(100)
                                }
                                downloadService?.startDownload(id, url, dest, segs, startNow, ref, totalBytes, audioUrl, audioBytes)
                            }
                        }
                        result.success(true)
                    } else result.error("INVALID_ARGS", "Missing args", null)
                }
                "getPublicDownloadDirectory" -> {
                    val publicDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                    val dabFolder = File(publicDir, "Dab Browser")
                    if (!dabFolder.exists()) dabFolder.mkdirs()
                    result.success(dabFolder.absolutePath)
                }
                "requestStoragePermission" -> {
                    if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.S_V2) {
                        val hasRead = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
                        val hasWrite = ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
                        if (!hasRead || !hasWrite) {
                            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE, Manifest.permission.WRITE_EXTERNAL_STORAGE), 102)
                        }
                    }
                    result.success(true)
                }
                "probeUrl" -> {
                    val url = call.argument<String>("url") ?: ""
                    val ref = call.argument<String>("referer")
                    if (url.isNotEmpty()) {
                        CoroutineScope(Dispatchers.IO).launch {
                            val probe = DownloadHttpHelper.probeUrl(url, ref)
                            runOnUiThread { result.success(probe.toMap()) }
                        }
                    } else result.error("INVALID_ARGS", "Missing url", null)
                }
                "getDiskSpace" -> {
                    val path = call.argument<String>("path") ?: getExternalFilesDir(null)?.path ?: filesDir.path
                    try {
                        val stat = StatFs(path)
                        result.success(mapOf("available" to stat.availableBytes, "total" to stat.totalBytes))
                    } catch (_: Exception) { result.success(mapOf("available" to 0L, "total" to 0L)) }
                }
                "pauseDownload" -> { downloadService?.pauseDownload(call.argument<String>("taskId") ?: ""); result.success(true) }
                "resumeDownload" -> { downloadService?.resumeDownload(call.argument<String>("taskId") ?: ""); result.success(true) }
                "cancelDownload" -> { downloadService?.cancelDownload(call.argument<String>("taskId") ?: ""); result.success(true) }
                "deleteDownload" -> { downloadService?.deleteDownload(call.argument<String>("taskId") ?: "", call.argument<Boolean>("deleteFile") ?: false); result.success(true) }
                "pauseAll" -> { downloadService?.pauseAll(); result.success(true) }
                "resumeAll" -> { downloadService?.resumeAll(); result.success(true) }
                "scheduleSeeding" -> { TorrentSeedingWorker.schedule(applicationContext, call.argument<String>("taskId") ?: "", call.argument<Boolean>("wifiOnly") ?: true, call.argument<Boolean>("requiresCharging") ?: true); result.success(true) }
                "stopSeeding" -> { TorrentSeedingWorker.stop(applicationContext, call.argument<String>("taskId") ?: ""); result.success(true) }
                "setMaxConcurrent" -> { downloadService?.setMaxConcurrent(call.argument<Int>("limit") ?: 3); result.success(true) }
                "setSpeedLimit" -> { downloadService?.setSpeedLimit(call.argument<String?>("taskId"), (call.argument<Number>("bytesPerSec") ?: 0L).toLong()); result.success(true) }
                "muxMedia" -> {
                    val v = call.argument<String>("videoPath") ?: ""; val a = call.argument<String>("audioPath") ?: ""; val o = call.argument<String>("outputPath") ?: ""
                    CoroutineScope(Dispatchers.IO).launch { val res = MediaMuxerHelper.mux(File(v), File(a), File(o)); withContext(Dispatchers.Main) { result.success(res.success) } }
                }
                "updateDownloadNotification" -> {
                    val t = call.argument<String>("title") ?: "Downloading"; val tx = call.argument<String>("text") ?: ""
                    downloadService?.showCustomNotification(t, tx, call.argument<Int>("max") ?: 100, call.argument<Int>("progress") ?: 0)
                    result.success(true)
                }
                "startForegroundDownload" -> { ensureDownloadServiceBound(); downloadService?.showCustomNotification("Downloading", "Starting download...", 100, 0); result.success(true) }
                "stopForegroundDownload" -> { downloadService?.stopForegroundCustom(); result.success(true) }
                "updateTaskUrls" -> {
                    val id = call.argument<String>("taskId") ?: ""; val newUrl = call.argument<String>("newUrl") ?: ""; val newAudio = call.argument<String>("newAudioUrl")
                    val ds = downloadService
                    if (id.isEmpty() || newUrl.isEmpty()) result.error("INVALID_ARGS", "Missing args", null)
                    else if (ds == null) { Log.e("DLREFRESH", "updateTaskUrls: downloadService null"); result.error("SERVICE_UNAVAILABLE", "DownloadService not bound", null) }
                    else {
                        CoroutineScope(Dispatchers.IO).launch {
                            val ok = ds.updateTaskUrls(id, newUrl, newAudio)
                            Log.d("DLREFRESH", "MainActivity updateTaskUrls id=$id res=$ok")
                            withContext(Dispatchers.Main) { result.success(ok) }
                        }
                    }
                }
                "deleteFileIfExists" -> {
                    val path = call.argument<String>("path") ?: ""
                    result.success(
                        if (path.isEmpty()) true
                        else runCatching {
                            val f = java.io.File(path)
                            !f.exists() || f.delete()
                        }.getOrDefault(false)
                    )
                }
                "mintPoToken" -> {
                    val identifier = call.argument<String>("identifier") ?: ""
                    if (identifier.isEmpty()) {
                        result.success(null)
                    } else {
                        CoroutineScope(Dispatchers.IO).launch {
                            val pot = PoTokenProvider.mint(applicationContext, identifier)
                            withContext(Dispatchers.Main) { result.success(pot) }
                        }
                    }
                }
                "failDownload" -> {                    val id = call.argument<String>("taskId") ?: ""; val reason = call.argument<String>("reason") ?: "Download failed"
                    DownloadService.allTasks[id]?.let { it.status = DownloadStatus.FAILED; it.errorMessage = reason; downloadService?.db?.upsertTask(it); DownloadService.dispatchProgress(it, isStateChange = true) }
                    result.success(true)
                }
                "getTasks" -> result.success(DownloadService.allTasks.values.map { it.toMap() })
                "shareUrl" -> {
                    val url = call.argument<String>("url") ?: ""
                    if (url.isNotEmpty()) {
                        val send = Intent(Intent.ACTION_SEND).apply { type = "text/plain"; putExtra(Intent.EXTRA_TEXT, url) }
                        startActivity(Intent.createChooser(send, "Share via").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)); result.success(true)
                    } else result.error("INVALID_URL", "URL is empty", null)
                }
                "getCacheSize" -> {
                    val cSize = getFolderSize(cacheDir) + getFolderSize(externalCacheDir)
                    result.success(cSize)
                }
                "clearBrowsingData" -> {
                    val cookies = call.argument<Boolean>("clearCookies") ?: false
                    val cache = call.argument<Boolean>("clearCache") ?: false
                    var flags = 0L
                    if (cookies) flags = flags or StorageController.ClearFlags.COOKIES or StorageController.ClearFlags.DOM_STORAGES
                    if (cache) flags = flags or StorageController.ClearFlags.NETWORK_CACHE or StorageController.ClearFlags.IMAGE_CACHE
                    if (flags != 0L) {
                        try { GeckoRuntimeProvider.get(this).storageController.clearData(flags) } catch (_: Exception) {}
                    }
                    if (cache) {
                        try {
                            cacheDir.deleteRecursively(); cacheDir.mkdirs()
                            externalCacheDir?.deleteRecursively(); externalCacheDir?.mkdirs()
                        } catch (_: Exception) {}
                    }
                    result.success(true)
                }
                "updatePrivateNotification" -> {
                    updatePrivateNotification(call.argument<Int>("count") ?: 0)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    DownloadService.onProgressCallback = { task -> runOnUiThread { eventSink?.success(task.toMap()) } }
                }
                override fun onCancel(arguments: Any?) { eventSink = null; DownloadService.onProgressCallback = null }
            }
        )
    }

    override fun onDestroy() {
        if (isBound) { unbindService(connection); isBound = false }
        downloaderChannel = null
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        nm?.cancel(9002)
        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.action == "com.dab.browser.CLOSE_PRIVATE_TABS") {
            downloaderChannel?.invokeMethod("closeAllPrivateTabs", null)
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            nm?.cancel(9002)
        }
    }

    private fun updatePrivateNotification(count: Int) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) nm.createNotificationChannel(NotificationChannel("dab_private", "Private Browsing", NotificationManager.IMPORTANCE_LOW))
        if (count > 0) {
            val pi = PendingIntent.getActivity(this, 9002, Intent(this, MainActivity::class.java).apply { action = "com.dab.browser.CLOSE_PRIVATE_TABS"; flags = Intent.FLAG_ACTIVITY_SINGLE_TOP }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val notif = NotificationCompat.Builder(this, "dab_private")
                .setSmallIcon(android.R.drawable.ic_menu_close_clear_cancel).setContentTitle("Close all private tabs")
                .setContentText("$count open • Touch to close and erase data").setOngoing(true).setContentIntent(pi).build()
            nm.notify(9002, notif)
        } else nm.cancel(9002)
    }

    private fun getFolderSize(d: File?): Long = if (d == null || !d.exists()) 0L else (d.listFiles()?.sumOf { if (it.isDirectory) getFolderSize(it) else it.length() } ?: 0L)
}
