package com.dab.browser

import org.libtorrent4j.SessionManager
import org.libtorrent4j.SessionParams

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
            val params = SessionParams()
            params.settings.enableDht(true)
            session.start(params)
            isStarted = true
        }
    }

    @Synchronized
    fun stop() {
        if (isStarted) {
            session.stop()
            isStarted = false
        }
    }
}
