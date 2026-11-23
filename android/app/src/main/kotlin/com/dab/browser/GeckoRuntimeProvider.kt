package com.dab.browser

import android.content.Context
import org.mozilla.geckoview.ContentBlocking
import org.mozilla.geckoview.GeckoRuntime
import org.mozilla.geckoview.GeckoRuntimeSettings

object GeckoRuntimeProvider {
    @Volatile
    private var instance: GeckoRuntime? = null

    /** Gecko default (or overridden) user agent, for download requests that must
     *  impersonate the browser session (e.g. page-sniffed googlevideo URLs). */
    @Volatile
    var defaultUserAgent: String? = null
        private set

    fun get(context: Context): GeckoRuntime {
        return instance ?: synchronized(this) {
            instance ?: createRuntime(context.applicationContext).also { instance = it }
        }
    }

    private fun createRuntime(context: Context): GeckoRuntime {
        // Fix 7 & What-Not-To-Do: Use DEFAULT anti-tracking to prevent duplicate rule evaluation with uBlock Origin
        val cbSettings = ContentBlocking.Settings.Builder()
            .antiTracking(ContentBlocking.AntiTracking.DEFAULT)
            .enhancedTrackingProtectionLevel(ContentBlocking.EtpLevel.DEFAULT)
            .safeBrowsing(ContentBlocking.SafeBrowsing.DEFAULT)
            .cookieBehavior(ContentBlocking.CookieBehavior.ACCEPT_NON_TRACKERS)
            .build()

        val settings = GeckoRuntimeSettings.Builder()
            .contentBlocking(cbSettings)
            .extensionsProcessEnabled(true)
            .build()

        android.util.Log.i("GeckoPerf", "GeckoRuntime initialized at startup")

        val runtime = GeckoRuntime.create(context, settings)
        // Gecko's default mobile UA (no override is configured in this app).
        defaultUserAgent = "Mozilla/5.0 (Android ${android.os.Build.VERSION.RELEASE}; Mobile; rv:144.0) Gecko/144.0 Firefox/144.0"
        DownloadHttpHelper.browserUserAgent = defaultUserAgent
        return runtime
    }
}
