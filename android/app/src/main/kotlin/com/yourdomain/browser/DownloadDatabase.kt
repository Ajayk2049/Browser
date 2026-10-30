package com.yourdomain.browser

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

class DownloadDatabase(context: Context) : SQLiteOpenHelper(context, "downloads.db", null, 2) {

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("""
            CREATE TABLE tasks (
                id TEXT PRIMARY KEY,
                url TEXT NOT NULL,
                destination_path TEXT NOT NULL,
                segments_count INTEGER NOT NULL,
                total_bytes INTEGER NOT NULL,
                downloaded_bytes INTEGER NOT NULL,
                speed_limit INTEGER NOT NULL,
                status TEXT NOT NULL,
                error_message TEXT,
                final_url TEXT,
                content_type TEXT,
                referer TEXT
            )
        """.trimIndent())

        db.execSQL("""
            CREATE TABLE segments (
                task_id TEXT NOT NULL,
                segment_index INTEGER NOT NULL,
                start_byte INTEGER NOT NULL,
                end_byte INTEGER NOT NULL,
                downloaded_bytes INTEGER NOT NULL,
                PRIMARY KEY (task_id, segment_index)
            )
        """.trimIndent())
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        if (oldVersion < 2) {
            try { db.execSQL("ALTER TABLE tasks ADD COLUMN final_url TEXT") } catch (_: Exception) {}
            try { db.execSQL("ALTER TABLE tasks ADD COLUMN content_type TEXT") } catch (_: Exception) {}
            try { db.execSQL("ALTER TABLE tasks ADD COLUMN referer TEXT") } catch (_: Exception) {}
        }
    }

    @Synchronized
    fun upsertTask(task: DownloadTask) {
        val db = writableDatabase
        val cv = ContentValues().apply {
            put("id", task.id)
            put("url", task.url)
            put("destination_path", task.destinationPath)
            put("segments_count", task.segmentsCount)
            put("total_bytes", task.totalBytes)
            put("downloaded_bytes", task.downloadedBytes)
            put("speed_limit", task.speedLimitBytesPerSec)
            put("status", task.status.name)
            put("error_message", task.errorMessage)
            put("final_url", task.finalUrl)
            put("content_type", task.resolvedContentType)
            put("referer", task.referer)
        }
        db.insertWithOnConflict("tasks", null, cv, SQLiteDatabase.CONFLICT_REPLACE)
    }

    @Synchronized
    fun saveSegments(taskId: String, segments: List<DownloadSegment>) {
        val db = writableDatabase
        db.beginTransaction()
        try {
            for (seg in segments) {
                val cv = ContentValues().apply {
                    put("task_id", taskId)
                    put("segment_index", seg.index)
                    put("start_byte", seg.startByte)
                    put("end_byte", seg.endByte)
                    put("downloaded_bytes", seg.downloadedBytes)
                }
                db.insertWithOnConflict("segments", null, cv, SQLiteDatabase.CONFLICT_REPLACE)
            }
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    @Synchronized
    fun loadAllTasks(): List<DownloadTask> {
        val tasks = mutableListOf<DownloadTask>()
        val db = readableDatabase
        val cursor = db.query("tasks", null, null, null, null, null, null)
        cursor.use { c ->
            while (c.moveToNext()) {
                val id = c.getString(c.getColumnIndexOrThrow("id"))
                val url = c.getString(c.getColumnIndexOrThrow("url"))
                val dest = c.getString(c.getColumnIndexOrThrow("destination_path"))
                val segCount = c.getInt(c.getColumnIndexOrThrow("segments_count"))
                val totalBytes = c.getLong(c.getColumnIndexOrThrow("total_bytes"))
                val downloadedBytes = c.getLong(c.getColumnIndexOrThrow("downloaded_bytes"))
                val speedLimit = c.getLong(c.getColumnIndexOrThrow("speed_limit"))
                val statusStr = c.getString(c.getColumnIndexOrThrow("status"))
                val errorMsg = c.getString(c.getColumnIndexOrThrow("error_message"))
                val finalUrl = c.getColumnIndex("final_url").takeIf { it >= 0 }?.let { c.getString(it) }
                val contentType = c.getColumnIndex("content_type").takeIf { it >= 0 }?.let { c.getString(it) }
                val referer = c.getColumnIndex("referer").takeIf { it >= 0 }?.let { c.getString(it) }

                val status = try {
                    DownloadStatus.valueOf(statusStr)
                } catch (_: Exception) {
                    DownloadStatus.PENDING
                }

                val task = DownloadTask(
                    id = id,
                    url = url,
                    destinationPath = dest,
                    segmentsCount = segCount,
                    totalBytes = totalBytes,
                    downloadedBytes = downloadedBytes,
                    speedLimitBytesPerSec = speedLimit,
                    status = status,
                    errorMessage = errorMsg,
                    finalUrl = finalUrl,
                    resolvedContentType = contentType,
                    referer = referer
                )

                // Load segments for this task
                loadSegments(id).forEach { seg -> task.segments.add(seg) }
                tasks.add(task)
            }
        }
        return tasks
    }

    @Synchronized
    fun loadSegments(taskId: String): List<DownloadSegment> {
        val segments = mutableListOf<DownloadSegment>()
        val db = readableDatabase
        val cursor = db.query(
            "segments", null, "task_id = ?", arrayOf(taskId),
            null, null, "segment_index ASC"
        )
        cursor.use { c ->
            while (c.moveToNext()) {
                val index = c.getInt(c.getColumnIndexOrThrow("segment_index"))
                val start = c.getLong(c.getColumnIndexOrThrow("start_byte"))
                val end = c.getLong(c.getColumnIndexOrThrow("end_byte"))
                val downloaded = c.getLong(c.getColumnIndexOrThrow("downloaded_bytes"))
                segments.add(DownloadSegment(index, start, end, downloaded))
            }
        }
        return segments
    }

    @Synchronized
    fun deleteTask(taskId: String) {
        val db = writableDatabase
        db.delete("segments", "task_id = ?", arrayOf(taskId))
        db.delete("tasks", "id = ?", arrayOf(taskId))
    }
}

