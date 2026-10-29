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
    private lateinit var db: DownloadDatabase

    inner class LocalBinder : Binder() {
        fun getService(): DownloadService = this@DownloadService
    }

    override fun onBind(intent: Intent?): IBinder = binder

    override fun onCreate() {
        super.onCreate()
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        db = DownloadDatabase(applicationContext)
        loadSavedTasks()
        createNotificationChannel()
        startAsForeground("Download Service", "Download engine running")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_NOT_STICKY

    private fun loadSavedTasks() {
        for (t in db.loadAllTasks()) {
            if (t.status in listOf(DownloadStatus.DOWNLOADING, DownloadStatus.CONNECTING, DownloadStatus.QUEUED)) {
                t.status = DownloadStatus.PAUSED
                db.upsertTask(t)
            }
            allTasks[t.id] = t
        }
    }

    fun startDownload(taskId: String, url: String, destinationPath: String, segmentsCount: Int = 8) {
        val task = allTasks.getOrPut(taskId) {
            DownloadTask(taskId, url, destinationPath, segmentsCount, speedLimitBytesPerSec = globalSpeedLimitBytesPerSec)
        }
        db.upsertTask(task)
        enqueueTask(task)
    }

    @Synchronized
    private fun enqueueTask(task: DownloadTask) {
        val running = activeEngines.values.count {
            it.task.status == DownloadStatus.DOWNLOADING || it.task.status == DownloadStatus.CONNECTING
        }
        if (running < maxConcurrentDownloads) {
            launchEngine(task)
        } else {
            task.status = DownloadStatus.QUEUED
            task.speedBytesPerSec = 0L
            if (!taskQueue.contains(task.id)) taskQueue.add(task.id)
            db.upsertTask(task)
            onProgressCallback?.invoke(task)
        }
    }

    private fun launchEngine(task: DownloadTask) {
        taskQueue.remove(task.id)
        val engine = activeEngines.getOrPut(task.id) {
            DownloadEngine(task, onSaveSegments = { segs -> db.saveSegments(task.id, segs) }) { updated ->
                db.upsertTask(updated)
                updateNotification(updated)
                onProgressCallback?.invoke(updated)
                if (updated.status in listOf(DownloadStatus.COMPLETED, DownloadStatus.FAILED, DownloadStatus.CANCELED, DownloadStatus.PAUSED)) {
                    db.saveSegments(updated.id, updated.segments)
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
        val running = activeEngines.values.count {
            it.task.status == DownloadStatus.DOWNLOADING || it.task.status == DownloadStatus.CONNECTING
        }
        var slots = maxConcurrentDownloads - running
        while (slots > 0 && taskQueue.isNotEmpty()) {
            val nextId = taskQueue.poll() ?: break
            val next = allTasks[nextId]
            if (next != null && next.status == DownloadStatus.QUEUED) {
                launchEngine(next)
                slots--
            }
        }
    }

    fun pauseDownload(taskId: String) {
        taskQueue.remove(taskId)
        activeEngines[taskId]?.pause()
        allTasks[taskId]?.let {
            if (it.status == DownloadStatus.QUEUED) {
                it.status = DownloadStatus.PAUSED
                db.upsertTask(it)
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
        db.deleteTask(taskId)
        processQueue()
    }

    fun pauseAll() {
        taskQueue.clear()
        allTasks.values.forEach { task ->
            if (task.status == DownloadStatus.QUEUED) {
                task.status = DownloadStatus.PAUSED
                db.upsertTask(task)
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
            allTasks[taskId]?.let { it.speedLimitBytesPerSec = limit; db.upsertTask(it) }
        } else {
            globalSpeedLimitBytesPerSec = limit
            activeEngines.values.forEach { it.setSpeedLimit(limit) }
            allTasks.values.forEach { it.speedLimitBytesPerSec = limit; db.upsertTask(it) }
        }
    }

    private fun checkAutoStop() {
        val hasActive = activeEngines.values.any {
            it.task.status == DownloadStatus.DOWNLOADING || it.task.status == DownloadStatus.CONNECTING
        }
        if (!hasActive && taskQueue.isEmpty()) stopForeground(STOP_FOREGROUND_DETACH)
    }

    private fun startAsForeground(title: String, text: String) {
        val n = buildNotification(title, text, 0, 0)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else startForeground(NOTIFICATION_ID, n)
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
            DownloadStatus.FAILED -> "Failed: ${task.errorMessage ?: "Error"}"
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
            val c = NotificationChannel(CHANNEL_ID, "File Downloads", NotificationManager.IMPORTANCE_LOW).apply {
                description = "Shows progress of active multi-threaded downloads"
            }
            notificationManager.createNotificationChannel(c)
        }
    }
}
