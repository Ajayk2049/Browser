package com.dab.browser

import android.util.Log
import okhttp3.Dns
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import okhttp3.dnsoverhttps.DnsOverHttps
import java.io.IOException
import java.net.Inet4Address
import java.net.InetAddress
import java.util.concurrent.*

class DnsResolutionException(message: String, cause: Throwable? = null) : IOException(message, cause)

object DownloadDns : Dns {
    private const val TAG = "DownloadDns"
    private const val SUCCESS_TTL_MS = 10 * 60 * 1000L // 10 minutes
    private const val FAILURE_TTL_MS = 30 * 1000L      // 30 seconds
    private val executor = Executors.newCachedThreadPool()

    private data class CacheEntry(val addresses: List<InetAddress>?, val expiresAt: Long)
    private val cache = ConcurrentHashMap<String, CacheEntry>()

    private val bootstrapClient = OkHttpClient.Builder()
        .connectTimeout(5, TimeUnit.SECONDS)
        .readTimeout(5, TimeUnit.SECONDS)
        .build()

    private val cloudflareDoh by lazy {
        try {
            DnsOverHttps.Builder()
                .client(bootstrapClient)
                .url("https://cloudflare-dns.com/dns-query".toHttpUrl())
                .bootstrapDnsHosts(InetAddress.getByName("1.1.1.1"), InetAddress.getByName("1.0.0.1"))
                .includeIPv6(true)
                .build()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to initialize Cloudflare DoH: ${e.message}")
            null
        }
    }

    private val googleDoh by lazy {
        try {
            DnsOverHttps.Builder()
                .client(bootstrapClient)
                .url("https://dns.google/dns-query".toHttpUrl())
                .bootstrapDnsHosts(InetAddress.getByName("8.8.8.8"), InetAddress.getByName("8.8.4.4"))
                .includeIPv6(true)
                .build()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to initialize Google DoH: ${e.message}")
            null
        }
    }

    override fun lookup(hostname: String): List<InetAddress> {
        val now = System.currentTimeMillis()
        val cached = cache[hostname]
        if (cached != null) {
            if (now < cached.expiresAt) {
                if (cached.addresses != null) return cached.addresses
                throw DnsResolutionException("DNS resolution recently failed for $hostname (cached negative response)")
            }
            cache.remove(hostname)
        }

        // 1. Try Dns.SYSTEM with 5s timeout on worker thread
        var result: List<InetAddress>? = null
        var lastErr: Throwable? = null
        try {
            val future = executor.submit(Callable { Dns.SYSTEM.lookup(hostname) })
            result = future.get(5, TimeUnit.SECONDS)
            if (!result.isNullOrEmpty()) {
                Log.d(TAG, "Resolved $hostname via System DNS: ${result.map { it.hostAddress }}")
            }
        } catch (e: Exception) {
            lastErr = e
            Log.w(TAG, "System DNS lookup failed for $hostname: ${e.message}")
        }

        // 2. Fallback to Cloudflare DoH
        if (result.isNullOrEmpty() && cloudflareDoh != null) {
            try {
                result = cloudflareDoh!!.lookup(hostname)
                if (!result.isNullOrEmpty()) {
                    Log.i(TAG, "Resolved $hostname via Cloudflare DoH: ${result.map { it.hostAddress }}")
                }
            } catch (e: Exception) {
                lastErr = e
                Log.w(TAG, "Cloudflare DoH lookup failed for $hostname: ${e.message}")
            }
        }

        // 3. Fallback to Google DoH
        if (result.isNullOrEmpty() && googleDoh != null) {
            try {
                result = googleDoh!!.lookup(hostname)
                if (!result.isNullOrEmpty()) {
                    Log.i(TAG, "Resolved $hostname via Google DoH: ${result.map { it.hostAddress }}")
                }
            } catch (e: Exception) {
                lastErr = e
                Log.w(TAG, "Google DoH lookup failed for $hostname: ${e.message}")
            }
        }

        if (result.isNullOrEmpty()) {
            cache[hostname] = CacheEntry(null, now + FAILURE_TTL_MS)
            throw DnsResolutionException("DNS resolution failed for $hostname (system + DoH)", lastErr)
        }

        // 4. Sort preferring IPv4 first
        val sorted = result.sortedBy { it !is Inet4Address }
        cache[hostname] = CacheEntry(sorted, now + SUCCESS_TTL_MS)
        return sorted
    }
}
