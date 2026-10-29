package com.yourdomain.browser

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Binder
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import java.io.File
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ConcurrentLinkedQueue

class DownloadService : Service() {

    companion object {
        const val CHANNEL_ID = "downloads_channel"
        const val NOTIFICATION_ID = 1001

        val allTasks = ConcurrentHashMap<String, DownloadTask>()
        val activeEngines = ConcurrentHashMap<String, DownloadEngine>()
        val taskQueue = ConcurrentLinkedQueue<String>()
        var onProgressCallback: ((DownloadTask) -> Unit)? = null
        @Volatile var maxConcurrentDownloads = 3
        @Volatile var globalSpeedLimitBytesPerSec = 0L
    }

    private val binder = LocalBinder()
    private lateinit var notificationManager: NotificationManager

    inner class LocalBinder : Binder() {
        fun getService(): DownloadService = this@DownloadService
    }

    override fun onBind(intent: Intent?): IBinder = binder

    override fun onCreate() {
        super.onCreate()
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createNotificationChannel()
        startAsForeground("Download Service", "Download engine running")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_NOT_STICKY

    fun startDownload(taskId: String, url: String, destinationPath: String, segmentsCount: Int = 8) {
        val task = allTasks.getOrPut(taskId) {
            DownloadTask(taskId, url, destinationPath, segmentsCount, speedLimitBytesPerSec = globalSpeedLimitBytesPerSec)
        }
        enqueueTask(task)
    }

    @Synchronized
    private fun enqueueTask(task: DownloadTask) {
        val runningCount = activeEngines.values.count {
            it.task.status == DownloadStatus.DOWNLOADING || it.task.status == DownloadStatus.CONNECTING
        }
        if (runningCount < maxConcurrentDownloads) {
            launchEngine(task)
        } else {
            task.status = DownloadStatus.QUEUED
            task.speedBytesPerSec = 0L
            if (!taskQueue.contains(task.id)) taskQueue.add(task.id)
            onProgressCallback?.invoke(task)
        }
    }

    private fun launchEngine(task: DownloadTask) {
        taskQueue.remove(task.id)
        val engine = activeEngines.getOrPut(task.id) {
            DownloadEngine(task) { updatedTask ->
                updateNotification(updatedTask)
                onProgressCallback?.invoke(updatedTask)
                if (updatedTask.status in listOf(DownloadStatus.COMPLETED, DownloadStatus.FAILED, DownloadStatus.CANCELED, DownloadStatus.PAUSED)) {
                    processQueue()
                    checkAutoStop()
                }
            }
        }
        if (globalSpeedLimitBytesPerSec > 0 && engine.speedLimitBytesPerSec == 0L) {
            engine.setSpeedLimit(globalSpeedLimitBytesPerSec)
        }
        engine.start()
    }

    @Synchronized
    private fun processQueue() {
        val runningCount = activeEngines.values.count {
            it.task.status == DownloadStatus.DOWNLOADING || it.task.status == DownloadStatus.CONNECTING
        }
        var slotsAvailable = maxConcurrentDownloads - runningCount
        while (slotsAvailable > 0 && taskQueue.isNotEmpty()) {
            val nextId = taskQueue.poll() ?: break
            val nextTask = allTasks[nextId]
            if (nextTask != null && nextTask.status == DownloadStatus.QUEUED) {
                launchEngine(nextTask)
                slotsAvailable--
            }
        }
    }

    fun pauseDownload(taskId: String) {
        taskQueue.remove(taskId)
        activeEngines[taskId]?.pause()
        allTasks[taskId]?.let {
            if (it.status == DownloadStatus.QUEUED) {
                it.status = DownloadStatus.PAUSED
                onProgressCallback?.invoke(it)
            }
        }
        processQueue()
    }

    fun resumeDownload(taskId: String) {
        allTasks[taskId]?.let { enqueueTask(it) }
    }

    fun cancelDownload(taskId: String) {
        taskQueue.remove(taskId)
        activeEngines.remove(taskId)?.cancel()
        allTasks.remove(taskId)
        processQueue()
    }

    fun pauseAll() {
        taskQueue.clear()
        allTasks.values.forEach { task ->
            if (task.status == DownloadStatus.QUEUED) {
                task.status = DownloadStatus.PAUSED
                onProgressCallback?.invoke(task)
            }
        }
        activeEngines.values.forEach { it.pause() }
    }

    fun resumeAll() {
        allTasks.values.filter { it.status == DownloadStatus.PAUSED }.forEach { enqueueTask(it) }
    }

    fun setMaxConcurrent(limit: Int) {
        maxConcurrentDownloads = limit.coerceAtLeast(1)
        processQueue()
    }

    fun setSpeedLimit(taskId: String?, bytesPerSec: Long) {
        val limit = bytesPerSec.coerceAtLeast(0L)
        if (taskId != null) {
            activeEngines[taskId]?.setSpeedLimit(limit)
            allTasks[taskId]?.speedLimitBytesPerSec = limit
        } else {
            globalSpeedLimitBytesPerSec = limit
            activeEngines.values.forEach { it.setSpeedLimit(limit) }
            allTasks.values.forEach { it.speedLimitBytesPerSec = limit }
        }
    }

    private fun checkAutoStop() {
        val hasActive = activeEngines.values.any {
            it.task.status == DownloadStatus.DOWNLOADING || it.task.status == DownloadStatus.CONNECTING
        }
        if (!hasActive && taskQueue.isEmpty()) {
            stopForeground(STOP_FOREGROUND_DETACH)
        }
    }

    private fun startAsForeground(title: String, text: String) {
        val notification = buildNotification(title, text, 0, 0)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun updateNotification(task: DownloadTask) {
        val fileName = File(task.destinationPath).name
        val percent = (task.progress * 100).toInt()
        val speedMb = String.format("%.2f", task.speedBytesPerSec / (1024.0 * 1024.0))
        val statusText = when (task.status) {
            DownloadStatus.DOWNLOADING -> "$percent% • $speedMb MB/s"
            DownloadStatus.QUEUED -> "Queued"
            DownloadStatus.PAUSED -> "Paused • $percent%"
            DownloadStatus.COMPLETED -> "Completed"
            DownloadStatus.FAILED -> "Failed: ${task.errorMessage ?: "Unknown error"}"
            else -> task.status.name
        }
        notificationManager.notify(NOTIFICATION_ID, buildNotification(fileName, statusText, 100, percent))
    }

    private fun buildNotification(title: String, text: String, max: Int, progress: Int): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setOngoing(max > 0 && progress < max)
            .setProgress(max, progress, max == 0)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "File Downloads", NotificationManager.IMPORTANCE_LOW
            ).apply { description = "Shows progress of active multi-threaded downloads" }
            notificationManager.createNotificationChannel(channel)
        }
    }
}
