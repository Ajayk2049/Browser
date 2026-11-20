# Proguard / R8 rules for Dab Browser

# Suppress missing java.beans referenced by SnakeYAML / GeckoView dependencies
-dontwarn java.beans.**
-dontwarn javax.annotation.**

# GeckoView keep rules
-keep class org.mozilla.geckoview.** { *; }
-keep interface org.mozilla.geckoview.** { *; }

# WorkManager keep rules
-keep class androidx.work.** { *; }

# libtorrent4j keep rules
-dontwarn org.libtorrent4j.**
-keep class org.libtorrent4j.** { *; }
-keep interface org.libtorrent4j.** { *; }
-keep class org.libtorrent4j.swig.** { *; }


