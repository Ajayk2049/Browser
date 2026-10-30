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
        val activeTorrentEngines = ConcurrentHashMap<String, TorrentEngine>()
        val taskQueue = ConcurrentLinkedQueue<String>()
        val lastEmitTimes = ConcurrentHashMap<String, Long>()
        const val THROTTLE_INTERVAL_MS = 250L // 4 Hz
        var onProgressCallback: ((DownloadTask) -> Unit)? = null
        @Volatile var maxConcurrentDownloads = 3
        @Volatile var globalSpeedLimitBytesPerSec = 0L

        fun dispatchProgress(task: DownloadTask, isStateChange: Boolean = false, onUpdateNotification: ((DownloadTask) -> Unit)? = null) {
            val now = System.currentTimeMillis()
            val lastTime = lastEmitTimes[task.id] ?: 0L
            val isCritical = isStateChange || task.status in listOf(
                DownloadStatus.COMPLETED, DownloadStatus.FAILED, DownloadStatus.PAUSED, DownloadStatus.CANCELED, DownloadStatus.QUEUED
            )
            if (isCritical || (now - lastTime) >= THROTTLE_INTERVAL_MS) {
                lastEmitTimes[task.id] = now
                onUpdateNotification?.invoke(task)
                onProgressCallback?.invoke(task)
            }
        }
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

    // Android 15/16 dataSync Foreground Service Timeout Handler
    override fun onTimeout(startId: Int, fgsType: Int) {
        pauseAll()
        allTasks.values.forEach { db.upsertTask(it) }
        val note = buildNotification("Downloads Paused", "System time limit reached. Tap in app to resume.", 0, 0)
        notificationManager.notify(NOTIFICATION_ID, note)
        stopForeground(STOP_FOREGROUND_DETACH)
        stopSelf(startId)
    }

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
        val isTor = TorrentEngine.isMagnetOrTorrent(url)
        val task = allTasks.getOrPut(taskId) {
            DownloadTask(taskId, url, destinationPath, segmentsCount, speedLimitBytesPerSec = globalSpeedLimitBytesPerSec, isTorrent = isTor)
        }
        db.upsertTask(task)
        enqueueTask(task)
    }

    @Synchronized
    private fun enqueueTask(task: DownloadTask) {
        val running = activeEngines.values.count { it.task.status in listOf(DownloadStatus.DOWNLOADING, DownloadStatus.CONNECTING) } +
                activeTorrentEngines.values.count { it.task.status in listOf(DownloadStatus.DOWNLOADING, DownloadStatus.CONNECTING) }
        if (running < maxConcurrentDownloads) {
            launchEngine(task)
        } else {
            task.status = DownloadStatus.QUEUED
            task.speedBytesPerSec = 0L
            if (!taskQueue.contains(task.id)) taskQueue.add(task.id)
            db.upsertTask(task)
            dispatchProgress(task, isStateChange = true)
        }
    }

    private fun launchEngine(task: DownloadTask) {
        taskQueue.remove(task.id)
        if (task.isTorrent) {
            val tEngine = activeTorrentEngines.getOrPut(task.id) {
                TorrentEngine(task) { updated ->
                    db.upsertTask(updated)
                    dispatchProgress(updated) { updateNotification(it) }
                    if (updated.status in listOf(DownloadStatus.COMPLETED, DownloadStatus.FAILED, DownloadStatus.CANCELED, DownloadStatus.PAUSED)) {
                        processQueue(); checkAutoStop()
                    }
                }
            }
            tEngine.start()
            return
        }
        val engine = activeEngines.getOrPut(task.id) {
            DownloadEngine(task, onSaveSegments = { segs -> db.saveSegments(task.id, segs) }) { updated ->
                db.upsertTask(updated)
                dispatchProgress(updated) { updateNotification(it) }
                if (updated.status in listOf(DownloadStatus.COMPLETED, DownloadStatus.FAILED, DownloadStatus.CANCELED, DownloadStatus.PAUSED)) {
                    db.saveSegments(updated.id, updated.segments)
                    processQueue(); checkAutoStop()
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
        val running = activeEngines.values.count { it.task.status in listOf(DownloadStatus.DOWNLOADING, DownloadStatus.CONNECTING) }
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
        activeTorrentEngines[taskId]?.pause()
        allTasks[taskId]?.let {
            if (it.status == DownloadStatus.QUEUED) {
                it.status = DownloadStatus.PAUSED
                db.upsertTask(it); dispatchProgress(it, isStateChange = true)
            }
        }
        processQueue()
    }

    fun resumeDownload(taskId: String) = allTasks[taskId]?.let { enqueueTask(it) }

    fun cancelDownload(taskId: String) {
        taskQueue.remove(taskId)
        val task = allTasks.remove(taskId)
        activeEngines.remove(taskId)?.cancel()
        activeTorrentEngines.remove(taskId)?.cancel()
        task?.let { it.status = DownloadStatus.CANCELED; dispatchProgress(it, isStateChange = true) }
        db.deleteTask(taskId); processQueue()
    }

    fun pauseAll() {
        taskQueue.clear()
        allTasks.values.forEach { task ->
            if (task.status == DownloadStatus.QUEUED) {
                task.status = DownloadStatus.PAUSED; db.upsertTask(task); dispatchProgress(task, isStateChange = true)
            }
        }
        activeEngines.values.forEach { it.pause() }
        activeTorrentEngines.values.forEach { it.pause() }
    }

    fun resumeAll() = allTasks.values.filter { it.status == DownloadStatus.PAUSED }.forEach { enqueueTask(it) }

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
        val hasActive = activeEngines.values.any { it.task.status in listOf(DownloadStatus.DOWNLOADING, DownloadStatus.CONNECTING) } ||
                activeTorrentEngines.values.any { it.task.status in listOf(DownloadStatus.DOWNLOADING, DownloadStatus.CONNECTING) }
        if (!hasActive && taskQueue.isEmpty()) stopForeground(STOP_FOREGROUND_DETACH)
    }

    private fun startAsForeground(title: String, text: String) {
        val n = buildNotification(title, text, 0, 0)
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC else 0
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) startForeground(NOTIFICATION_ID, n, type) else startForeground(NOTIFICATION_ID, n)
    }

    private fun updateNotification(task: DownloadTask) {
        val name = File(task.destinationPath).name
        val pct = (task.progress * 100).toInt()
        val mb = String.format("%.2f", task.speedBytesPerSec / (1024.0 * 1024.0))
        val statusText = when (task.status) {
            DownloadStatus.DOWNLOADING -> "$pct% • $mb MB/s"
            DownloadStatus.QUEUED -> "Queued"
            DownloadStatus.PAUSED -> "Paused • $pct%"
            DownloadStatus.COMPLETED -> "Completed"
            DownloadStatus.FAILED -> "Failed: ${task.errorMessage ?: "Error"}"
            else -> task.status.name
        }
        notificationManager.notify(NOTIFICATION_ID, buildNotification(name, statusText, 100, pct))
    }

    private fun buildNotification(title: String, text: String, max: Int, progress: Int): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title).setContentText(text)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setOngoing(max > 0 && progress < max).setProgress(max, progress, max == 0)
            .setOnlyAlertOnce(true).setPriority(NotificationCompat.PRIORITY_LOW).build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val c = NotificationChannel(CHANNEL_ID, "File Downloads", NotificationManager.IMPORTANCE_LOW)
            notificationManager.createNotificationChannel(c)
        }
    }
}
