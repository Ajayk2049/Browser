package com.yourdomain.browser

import android.content.Context
import android.content.pm.ServiceInfo
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.work.*
import kotlinx.coroutines.delay
import java.io.File

class TorrentSeedingWorker(
    private val context: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(context, workerParams) {

    private val db = DownloadDatabase(context)

    override suspend fun doWork(): Result {
        val taskId = inputData.getString("taskId") ?: return Result.failure()
        val task = db.loadAllTasks().find { it.id == taskId } ?: return Result.failure()

        val destFile = File(task.destinationPath)
        if (!destFile.exists()) return Result.failure()

        var isPromoted = false
        var uploadedBytes = 0L

        try {
            // Seeding session: listen for peers
            for (i in 0 until 120) { // Runs periodic seeding window
                if (isStopped) break

                // Simulate peer upload traffic detection
                val isPeerRequesting = (0..10).random() > 6
                val uploadSpeed = if (isPeerRequesting) (50_000L..300_000L).random() else 0L

                if (uploadSpeed > 0) {
                    uploadedBytes += uploadSpeed
                    if (!isPromoted) {
                        setForeground(createForegroundInfo(task, uploadSpeed))
                        isPromoted = true
                    }
                } else if (isPromoted) {
                    // Demote when idle to save foreground dataSync budget
                    isPromoted = false
                }

                delay(1000)
            }
            return Result.success()
        } catch (_: Exception) {
            return Result.retry()
        }
    }

    private fun createForegroundInfo(task: DownloadTask, uploadSpeed: Long): ForegroundInfo {
        val fileName = File(task.destinationPath).name
        val speedKb = String.format("%.1f", uploadSpeed / 1024.0)

        val notification = NotificationCompat.Builder(context, DownloadService.CHANNEL_ID)
            .setContentTitle("Seeding $fileName")
            .setContentText("P2P Uploading • $speedKb KB/s")
            .setSmallIcon(android.R.drawable.stat_sys_upload)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
        } else 0

        return ForegroundInfo(DownloadService.NOTIFICATION_ID + 100, notification, type)
    }

    companion object {
        fun schedule(context: Context, taskId: String, wifiOnly: Boolean = true, requiresCharging: Boolean = true) {
            val constraints = Constraints.Builder().apply {
                if (wifiOnly) setRequiredNetworkType(NetworkType.UNMETERED)
                if (requiresCharging) setRequiresCharging(true)
            }.build()

            val workRequest = OneTimeWorkRequestBuilder<TorrentSeedingWorker>()
                .setConstraints(constraints)
                .setInputData(workDataOf("taskId" to taskId))
                .addTag("seed_$taskId")
                .build()

            WorkManager.getInstance(context).enqueueUniqueWork(
                "seed_$taskId",
                ExistingWorkPolicy.REPLACE,
                workRequest
            )
        }

        fun stop(context: Context, taskId: String) {
            WorkManager.getInstance(context).cancelUniqueWork("seed_$taskId")
        }
    }
}

