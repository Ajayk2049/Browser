package com.dab.browser

import android.Manifest
import android.content.*
import android.content.pm.PackageManager
import android.os.*
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.*
import kotlinx.coroutines.*
import java.io.File

class MainActivity : FlutterActivity() {
    private val methodChannelName = "com.dab/downloader"
    private val eventChannelName = "com.dab/downloads/updates"
    private var downloadService: DownloadService? = null
    private var isBound = false
    private var eventSink: EventChannel.EventSink? = null

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            downloadService = (service as DownloadService.LocalBinder).getService()
            isBound = true
        }
        override fun onServiceDisconnected(name: ComponentName?) {
            downloadService = null; isBound = false
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 101)
        }

        flutterEngine.platformViewsController.registry.registerViewFactory("com.dab/geckoview", GeckoViewFactory(flutterEngine.dartExecutor.binaryMessenger))
        val intent = Intent(this, DownloadService::class.java)
        startService(intent); bindService(intent, connection, Context.BIND_AUTO_CREATE)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "startDownload" -> {
                    val id = call.argument<String>("taskId") ?: ""
                    val url = call.argument<String>("url") ?: ""
                    val dest = call.argument<String>("destinationPath") ?: ""
                    val segs = call.argument<Int>("segmentsCount") ?: 8
                    val startNow = call.argument<Boolean>("startNow") ?: true
                    val ref = call.argument<String>("referer")
                    if (id.isNotEmpty() && url.isNotEmpty() && dest.isNotEmpty()) {
                        downloadService?.startDownload(id, url, dest, segs, startNow, ref); result.success(true)
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
                "pauseAll" -> { downloadService?.pauseAll(); result.success(true) }
                "resumeAll" -> { downloadService?.resumeAll(); result.success(true) }
                "scheduleSeeding" -> {
                    TorrentSeedingWorker.schedule(applicationContext, call.argument<String>("taskId") ?: "", call.argument<Boolean>("wifiOnly") ?: true, call.argument<Boolean>("requiresCharging") ?: true)
                    result.success(true)
                }
                "stopSeeding" -> { TorrentSeedingWorker.stop(applicationContext, call.argument<String>("taskId") ?: ""); result.success(true) }
                "setMaxConcurrent" -> { downloadService?.setMaxConcurrent(call.argument<Int>("limit") ?: 3); result.success(true) }
                "setSpeedLimit" -> {
                    downloadService?.setSpeedLimit(call.argument<String?>("taskId"), (call.argument<Number>("bytesPerSec") ?: 0L).toLong())
                    result.success(true)
                }
                "getTasks" -> result.success(DownloadService.allTasks.values.map { it.toMap() })
                "shareUrl" -> {
                    val url = call.argument<String>("url") ?: ""
                    val title = call.argument<String>("title") ?: ""
                    if (url.isNotEmpty()) {
                        val sendIntent = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"; putExtra(Intent.EXTRA_TEXT, url)
                            if (title.isNotEmpty()) putExtra(Intent.EXTRA_SUBJECT, title)
                        }
                        val shareIntent = Intent.createChooser(sendIntent, "Share via").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(shareIntent); result.success(true)
                    } else result.error("INVALID_URL", "URL is empty", null)
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
        super.onDestroy()
    }
}
