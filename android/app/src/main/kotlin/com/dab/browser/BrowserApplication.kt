package com.dab.browser

import android.app.Application

/**
 * Custom Application class for Dab Browser.
 * Unblocks startup path: GeckoRuntime warm-up is deferred to post-first-frame.
 */
class BrowserApplication : Application() {
    override fun onCreate() {
        super.onCreate()
    }
}
