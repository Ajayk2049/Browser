package com.yourdomain.browser

import android.Manifest
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.os.Build
import android.os.IBinder
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val methodChannelName = "com.yourdomain/downloader"
    private val eventChannelName = "com.yourdomain/downloads/updates"

    private var downloadService: DownloadService? = null
    private var isBound = false
    private var eventSink: EventChannel.EventSink? = null

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            val binder = service as DownloadService.LocalBinder
            downloadService = binder.getService()
            isBound = true
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            downloadService = null
            isBound = false
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Request POST_NOTIFICATIONS on Android 13+ (API 33+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 101)
            }
        }

        // Ensure DownloadService is started and bound
        val intent = Intent(this, DownloadService::class.java)
        startService(intent)
        bindService(intent, connection, Context.BIND_AUTO_CREATE)

        // 1. MethodChannel for download control
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "startDownload" -> {
                    val taskId = call.argument<String>("taskId") ?: ""
                    val url = call.argument<String>("url") ?: ""
                    val destinationPath = call.argument<String>("destinationPath") ?: ""
                    val segmentsCount = call.argument<Int>("segmentsCount") ?: 8

                    if (taskId.isNotEmpty() && url.isNotEmpty() && destinationPath.isNotEmpty()) {
                        downloadService?.startDownload(taskId, url, destinationPath, segmentsCount)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "Missing required download arguments", null)
                    }
                }
                "pauseDownload" -> {
                    val taskId = call.argument<String>("taskId") ?: ""
                    downloadService?.pauseDownload(taskId)
                    result.success(true)
                }
                "resumeDownload" -> {
                    val taskId = call.argument<String>("taskId") ?: ""
                    downloadService?.resumeDownload(taskId)
                    result.success(true)
                }
                "cancelDownload" -> {
                    val taskId = call.argument<String>("taskId") ?: ""
                    downloadService?.cancelDownload(taskId)
                    result.success(true)
                }
                "pauseAll" -> {
                    downloadService?.pauseAll()
                    result.success(true)
                }
                "resumeAll" -> {
                    downloadService?.resumeAll()
                    result.success(true)
                }
                "setMaxConcurrent" -> {
                    val limit = call.argument<Int>("limit") ?: 3
                    downloadService?.setMaxConcurrent(limit)
                    result.success(true)
                }
                "setSpeedLimit" -> {
                    val taskId = call.argument<String?>("taskId")
                    val bytesPerSec = (call.argument<Number>("bytesPerSec") ?: 0L).toLong()
                    downloadService?.setSpeedLimit(taskId, bytesPerSec)
                    result.success(true)
                }
                "getTasks" -> {
                    val tasks = DownloadService.allTasks.values.map { it.toMap() }
                    result.success(tasks)
                }
                else -> result.notImplemented()
            }
        }

        // 2. EventChannel for progress stream
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    DownloadService.onProgressCallback = { task ->
                        runOnUiThread {
                            eventSink?.success(task.toMap())
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    DownloadService.onProgressCallback = null
                }
            }
        )
    }

    override fun onDestroy() {
        if (isBound) {
            unbindService(connection)
            isBound = false
        }
        super.onDestroy()
    }
}
