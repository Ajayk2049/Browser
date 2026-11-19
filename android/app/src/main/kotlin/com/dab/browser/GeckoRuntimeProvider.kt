package com.dab.browser

import android.content.Context
import org.mozilla.geckoview.ContentBlocking
import org.mozilla.geckoview.GeckoRuntime
import org.mozilla.geckoview.GeckoRuntimeSettings

object GeckoRuntimeProvider {
    @Volatile
    private var instance: GeckoRuntime? = null

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

        return GeckoRuntime.create(context, settings)
    }
}
