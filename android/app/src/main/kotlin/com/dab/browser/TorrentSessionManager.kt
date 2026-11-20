package com.dab.browser

import org.libtorrent4j.SessionManager

/**
 * Shared singleton manager for libtorrent4j session.
 * Manages DHT, peer connections, and tracker alerts.
 */
object TorrentSessionManager {
    val session = SessionManager()
    @Volatile private var isStarted = false

    @Synchronized
    fun ensureStarted() {
        if (!isStarted) {
            session.start()
            isStarted = true
        }
    }

    @Synchronized
    fun stop() {
        if (isStarted) {
            try { session.stop() } catch (_: Exception) {}
            isStarted = false
        }
    }
}
