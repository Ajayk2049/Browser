package com.dab.browser

import android.app.*
import android.util.Log
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Binder
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*
import java.io.File
import java.util.Locale
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ConcurrentLinkedQueue

class DownloadService : Service() {

    companion object {
        const val CHANNEL_ID = "downloads_channel"; const val NOTIFICATION_ID = 1001
        val allTasks = ConcurrentHashMap<String, DownloadTask>(); val activeEngines = ConcurrentHashMap<String, DownloadEngine>()
        val activeTorrentEngines = ConcurrentHashMap<String, TorrentEngine>(); val taskQueue = ConcurrentLinkedQueue<String>()
        val lastEmitTimes = ConcurrentHashMap<String, Long>(); val lastDbSaveTimes = ConcurrentHashMap<String, Long>()
        const val THROTTLE_INTERVAL_MS = 250L; const val DB_SAVE_INTERVAL_MS = 5000L
        var onProgressCallback: ((DownloadTask) -> Unit)? = null
        @Volatile var maxConcurrentDownloads = 3; @Volatile var globalSpeedLimitBytesPerSec = 0L

        fun dispatchProgress(task: DownloadTask, isStateChange: Boolean = false, db: DownloadDatabase? = null, onUpdateNotification: ((DownloadTask) -> Unit)? = null) {
            val now = System.currentTimeMillis(); val lastTime = lastEmitTimes[task.id] ?: 0L
            val isCritical = isStateChange || task.status in listOf(DownloadStatus.COMPLETED, DownloadStatus.FAILED, DownloadStatus.PAUSED, DownloadStatus.CANCELED, DownloadStatus.QUEUED, DownloadStatus.LINK_EXPIRED, DownloadStatus.CONNECTING)
            if (isCritical || (now - lastTime) >= THROTTLE_INTERVAL_MS) {
                lastEmitTimes[task.id] = now; onUpdateNotification?.invoke(task); onProgressCallback?.invoke(task)
            }
            if (db != null) {
                val lastDb = lastDbSaveTimes[task.id] ?: 0L
                if (isCritical || (now - lastDb) >= DB_SAVE_INTERVAL_MS) {
                    lastDbSaveTimes[task.id] = now
                    db.upsertTask(task)
                }
            }
        }
    }

    private val binder = LocalBinder()
    private lateinit var notificationManager: NotificationManager
    @Volatile private var _db: DownloadDatabase? = null
    val db: DownloadDatabase get() = _db ?: synchronized(this) { _db ?: DownloadDatabase(applicationContext).also { _db = it } }

    inner class LocalBinder : Binder() { fun getService(): DownloadService = this@DownloadService }
    override fun onBind(intent: Intent?): IBinder = binder

    override fun onCreate() {
        super.onCreate()
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createNotificationChannel(); CoroutineScope(Dispatchers.IO).launch { loadSavedTasks(db) }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_NOT_STICKY

    // Android 15/16 dataSync Foreground Service Timeout Handler
    override fun onTimeout(startId: Int, fgsType: Int) {
        pauseAll(); allTasks.values.forEach { db.upsertTask(it) }
        notificationManager.notify(NOTIFICATION_ID, buildNotification("Downloads Paused", "System time limit reached. Tap in app to resume.", 0, 0))
        stopForeground(STOP_FOREGROUND_DETACH); stopSelf(startId)
    }

    private fun loadSavedTasks(database: DownloadDatabase) {
        for (t in database.loadAllTasks()) {
            if (t.status in listOf(DownloadStatus.DOWNLOADING, DownloadStatus.CONNECTING, DownloadStatus.QUEUED)) { t.status = DownloadStatus.PAUSED; database.upsertTask(t) }
            allTasks[t.id] = t
        }
    }

    fun startDownload(taskId: String, url: String, destinationPath: String, segmentsCount: Int = 8, startNow: Boolean = true, referer: String? = null, totalBytes: Long = -1L, audioUrl: String? = null, audioBytes: Long = 0L) {
        val isTor = TorrentEngine.isMagnetOrTorrent(url); val isYt = url.contains("googlevideo.com") || audioUrl != null
        val finalSegs = if (isYt) 1 else segmentsCount
        val task = allTasks.getOrPut(taskId) { DownloadTask(taskId, url, destinationPath, finalSegs, speedLimitBytesPerSec = globalSpeedLimitBytesPerSec, isTorrent = isTor, referer = referer, totalBytes = totalBytes, audioUrl = audioUrl, audioBytes = audioBytes) }
        if (totalBytes > 0 && task.totalBytes <= 0) task.totalBytes = totalBytes
        if (referer != null) task.referer = referer; if (audioUrl != null) task.audioUrl = audioUrl
        if (audioBytes > 0 && task.audioBytes <= 0) task.audioBytes = audioBytes
        db.upsertTask(task)
        if (startNow) enqueueTask(task) else { task.status = DownloadStatus.PAUSED; dispatchProgress(task, isStateChange = true) }
    }

    private fun getHost(url: String): String = try { java.net.URL(url).host } catch (_: Exception) { "" }

    @Synchronized
    private fun enqueueTask(task: DownloadTask, forceRestart: Boolean = false) {
        val running = activeEngines.values.count { it.task.status in listOf(DownloadStatus.DOWNLOADING, DownloadStatus.CONNECTING) } + activeTorrentEngines.values.count { it.task.status in listOf(DownloadStatus.DOWNLOADING, DownloadStatus.CONNECTING) }
        val host = getHost(task.finalUrl ?: task.url)
        val hostRunning = if (host.isEmpty()) 0 else activeEngines.values.count { it.task.status in listOf(DownloadStatus.DOWNLOADING, DownloadStatus.CONNECTING) && getHost(it.task.finalUrl ?: it.task.url) == host }
        if (running < maxConcurrentDownloads && hostRunning < 2) {
            launchEngine(task, forceRestart = forceRestart)
        } else {
            task.status = DownloadStatus.QUEUED; task.speedBytesPerSec = 0L; if (!taskQueue.contains(task.id)) taskQueue.add(task.id); db.upsertTask(task); dispatchProgress(task, isStateChange = true)
        }
    }

    private var isForegroundActive = false

    private fun launchEngine(task: DownloadTask, forceRestart: Boolean = false) {
        taskQueue.remove(task.id); ensureForegroundStarted()
        if (task.isTorrent) {
            val tEngine = activeTorrentEngines.getOrPut(task.id) {
                TorrentEngine(task) { updated ->
                    dispatchProgress(updated, db = db) { updateNotification(it) }
                    if (updated.status in listOf(DownloadStatus.COMPLETED, DownloadStatus.FAILED, DownloadStatus.CANCELED, DownloadStatus.PAUSED)) { processQueue(); checkAutoStop() }
                }
            }
            if (globalSpeedLimitBytesPerSec > 0 && task.speedLimitBytesPerSec == 0L) tEngine.setSpeedLimit(globalSpeedLimitBytesPerSec)
            tEngine.start(); return
        }
        if (forceRestart) activeEngines.remove(task.id)?.shutdown()
        val engine = activeEngines.getOrPut(task.id) {
            DownloadEngine(task, onSaveSegments = { segs -> db.saveSegments(task.id, segs) }) { updated ->
                dispatchProgress(updated, db = db) { updateNotification(it) }
                if (updated.status in listOf(DownloadStatus.COMPLETED, DownloadStatus.FAILED, DownloadStatus.CANCELED, DownloadStatus.PAUSED, DownloadStatus.LINK_EXPIRED)) {
                    db.saveSegments(updated.id, updated.segments); activeEngines.remove(task.id); processQueue(); checkAutoStop()
                }
            }
        }
        if (globalSpeedLimitBytesPerSec > 0 && engine.speedLimitBytesPerSec == 0L) engine.setSpeedLimit(globalSpeedLimitBytesPerSec)
        engine.start(forceRestart = forceRestart)
    }

    suspend fun updateTaskUrls(taskId: String, newUrl: String, newAudioUrl: String?): Boolean = withContext(Dispatchers.IO) {
        val task = allTasks[taskId] ?: run { Log.e("DLREFRESH", "updateTaskUrls: task $taskId not found"); return@withContext false }
        Log.d("DLREFRESH", "updateTaskUrls: entered id=$taskId oldStatus=${task.status}")
        activeEngines.remove(taskId)?.shutdown()
        val isYt = newUrl.contains("googlevideo.com") || task.url.contains("googlevideo.com") || task.audioUrl != null
        if (!isYt) {
            val probe = DownloadHttpHelper.probeUrl(newUrl, task.referer)
            Log.d("DLREFRESH", "updateTaskUrls probe id=$taskId len=${probe.contentLength} ranges=${probe.supportsRanges} err=${probe.errorMessage}")
            val newStreamLen = probe.contentLength
            if (newStreamLen <= 0 || probe.errorMessage != null) { Log.e("DLREFRESH", "updateTaskUrls: probe rejected link for $taskId (len=$newStreamLen err=${probe.errorMessage})"); return@withContext false }
            val oldStreamLen = if (task.audioBytes > 0 && task.totalBytes > task.audioBytes) task.totalBytes - task.audioBytes else task.totalBytes
            if (oldStreamLen > 0 && newStreamLen != oldStreamLen) {
                Log.w("DLREFRESH", "updateTaskUrls: length mismatch ($oldStreamLen vs $newStreamLen), resetting part")
                try { File("${task.destinationPath}.part").delete(); File("${task.destinationPath}.audio.part").delete() } catch (_: Exception) {}
                task.downloadedBytes = 0L; task.totalBytes = newStreamLen + task.audioBytes; task.segments.clear()
                val cnt = if (newStreamLen < 5 * 1024 * 1024) 1 else task.segmentsCount.coerceIn(1, 6); val chunk = newStreamLen / cnt
                for (i in 0 until cnt) task.segments.add(DownloadSegment(i, i * chunk, if (i == cnt - 1) newStreamLen - 1 else (i + 1) * chunk - 1))
            }
        } else {
            task.segments.clear(); val streamLen = if (task.audioBytes > 0 && task.totalBytes > task.audioBytes) task.totalBytes - task.audioBytes else task.totalBytes
            task.segments.add(DownloadSegment(0, 0, if (streamLen > 0) streamLen - 1 else Long.MAX_VALUE))
        }
        task.url = newUrl; task.finalUrl = newUrl; if (newAudioUrl != null) task.audioUrl = newAudioUrl
        task.status = DownloadStatus.CONNECTING; db.upsertTask(task); dispatchProgress(task, isStateChange = true)
        enqueueTask(task, forceRestart = true); Log.d("DLREFRESH", "updateTaskUrls: finished id=$taskId"); true
    }

    @Synchronized
    private fun processQueue() {
        val running = activeEngines.values.count { it.task.status in listOf(DownloadStatus.DOWNLOADING, DownloadStatus.CONNECTING) }
        var slots = maxConcurrentDownloads - running
        val delayed = mutableListOf<String>()
        while (slots > 0 && taskQueue.isNotEmpty()) {
            val nextId = taskQueue.poll() ?: break
            val next = allTasks[nextId]
            if (next != null && next.status == DownloadStatus.QUEUED) {
                val host = getHost(next.finalUrl ?: next.url)
                val hostRunning = if (host.isEmpty()) 0 else activeEngines.values.count { it.task.status in listOf(DownloadStatus.DOWNLOADING, DownloadStatus.CONNECTING) && getHost(it.task.finalUrl ?: it.task.url) == host }
                if (hostRunning < 2) { launchEngine(next); slots-- } else delayed.add(nextId)
            }
        }
        taskQueue.addAll(delayed)
    }

    fun pauseDownload(taskId: String) {
        taskQueue.remove(taskId); activeEngines[taskId]?.pause(); activeTorrentEngines[taskId]?.pause()
        allTasks[taskId]?.let { if (it.status == DownloadStatus.QUEUED) { it.status = DownloadStatus.PAUSED; db.upsertTask(it); dispatchProgress(it, isStateChange = true) } }
        processQueue(); checkAutoStop()
    }

    fun resumeDownload(taskId: String) = allTasks[taskId]?.let { enqueueTask(it) }
    fun cancelDownload(taskId: String) = deleteDownload(taskId, deleteFile = false)
    fun deleteDownload(taskId: String, deleteFile: Boolean = false) {
        taskQueue.remove(taskId); lastEmitTimes.remove(taskId); lastDbSaveTimes.remove(taskId); val task = allTasks.remove(taskId)
        activeEngines.remove(taskId)?.cancel(); activeTorrentEngines.remove(taskId)?.cancel()
        task?.let {
            it.status = DownloadStatus.CANCELED; dispatchProgress(it, isStateChange = true)
            if (deleteFile && it.destinationPath.isNotEmpty()) {
                try { val f = File(it.destinationPath); if (f.exists()) f.deleteRecursively(); val p = File("${it.destinationPath}.part"); if (p.exists()) p.delete() } catch (_: Exception) {}
            }
        }
        db.deleteTask(taskId); processQueue(); checkAutoStop()
    }

    fun pauseAll() {
        taskQueue.clear()
        allTasks.values.forEach { if (it.status == DownloadStatus.QUEUED) { it.status = DownloadStatus.PAUSED; db.upsertTask(it); dispatchProgress(it, isStateChange = true) } }
        activeEngines.values.forEach { it.pause() }; activeTorrentEngines.values.forEach { it.pause() }
        checkAutoStop()
    }

    fun resumeAll() = allTasks.values.filter { it.status == DownloadStatus.PAUSED }.forEach { enqueueTask(it) }
    fun setMaxConcurrent(limit: Int) { maxConcurrentDownloads = limit.coerceAtLeast(1); processQueue() }
    fun setSpeedLimit(taskId: String?, bytesPerSec: Long) {
        val limit = bytesPerSec.coerceAtLeast(0L)
        if (taskId != null) { activeEngines[taskId]?.setSpeedLimit(limit); activeTorrentEngines[taskId]?.setSpeedLimit(limit); allTasks[taskId]?.let { it.speedLimitBytesPerSec = limit; db.upsertTask(it) } }
        else { globalSpeedLimitBytesPerSec = limit; activeEngines.values.forEach { it.setSpeedLimit(limit) }; activeTorrentEngines.values.forEach { it.setSpeedLimit(limit) }; allTasks.values.forEach { it.speedLimitBytesPerSec = limit; db.upsertTask(it) } }
    }

    private fun checkAutoStop() {
        val hasActive = activeEngines.values.any { it.task.status in listOf(DownloadStatus.DOWNLOADING, DownloadStatus.CONNECTING) } || activeTorrentEngines.values.any { it.task.status in listOf(DownloadStatus.DOWNLOADING, DownloadStatus.CONNECTING) }
        if (!hasActive && taskQueue.isEmpty() && isForegroundActive) {
            stopForeground(STOP_FOREGROUND_REMOVE); notificationManager.cancel(NOTIFICATION_ID); isForegroundActive = false
        }
    }

    fun showCustomNotification(title: String, text: String, max: Int, progress: Int) {
        try { ensureForegroundStarted(); notificationManager.notify(NOTIFICATION_ID, buildNotification(title, text, max, progress)) } catch (_: Exception) {}
    }
    fun stopForegroundCustom() {
        try { stopForeground(STOP_FOREGROUND_REMOVE); notificationManager.cancel(NOTIFICATION_ID); isForegroundActive = false } catch (_: Exception) {}
    }

    private fun ensureForegroundStarted() {
        if (!isForegroundActive) {
            try {
                createNotificationChannel(); val n = buildNotification("Downloading", "Preparing download...", 0, 0)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) startForeground(NOTIFICATION_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC) else startForeground(NOTIFICATION_ID, n)
                isForegroundActive = true
            } catch (_: Exception) {}
        }
    }

    private fun updateNotification(task: DownloadTask) {
        try {
            if (!isForegroundActive) ensureForegroundStarted()
            val pct = (task.progress * 100).toInt()
            val mb = String.format(Locale.US, "%.2f", task.speedBytesPerSec / 1048576.0)
            val statusText = if (task.status == DownloadStatus.DOWNLOADING) "$pct% • $mb MB/s" else task.status.name
            notificationManager.notify(NOTIFICATION_ID, buildNotification(File(task.destinationPath).name, statusText, 100, pct))
        } catch (_: Exception) {}
    }

    private fun buildNotification(title: String, text: String, max: Int, progress: Int): Notification =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title).setContentText(text).setSmallIcon(applicationInfo.icon.takeIf { it != 0 } ?: android.R.drawable.ic_menu_save)
            .setOngoing(max > 0 && progress < max).setProgress(max, progress, max == 0).setOnlyAlertOnce(true).setPriority(NotificationCompat.PRIORITY_LOW).build()

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) notificationManager.createNotificationChannel(NotificationChannel(CHANNEL_ID, "File Downloads", NotificationManager.IMPORTANCE_LOW))
    }
}
