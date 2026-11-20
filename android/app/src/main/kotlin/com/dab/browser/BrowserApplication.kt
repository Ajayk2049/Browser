package com.dab.browser

import android.app.Application
import android.os.Build
import android.os.Handler
import android.os.Looper

class BrowserApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        if (isMainProcess()) {
            android.util.Log.i("GeckoPerf", "Main process detected ($packageName): deferring GeckoRuntime warm-up to unblock cold start")
            Handler(Looper.getMainLooper()).postDelayed({
                try {
                    GeckoRuntimeProvider.get(this)
                } catch (e: Exception) {
                    android.util.Log.e("GeckoPerf", "Deferred GeckoRuntime init error", e)
                }
            }, 300)
        } else {
            android.util.Log.i("GeckoPerf", "Child process detected ($packageName): skipping GeckoRuntime init")
        }
    }

    private fun isMainProcess(): Boolean {
        val processName = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            getProcessName()
        } else {
            try {
                val clazz = Class.forName("android.app.ActivityThread")
                val method = clazz.getDeclaredMethod("currentProcessName")
                method.invoke(null) as? String
            } catch (_: Exception) {
                null
            }
        }
        return processName == null || processName == packageName
    }
}
