# Proguard / R8 rules for Dab Browser

# Suppress missing java.beans referenced by SnakeYAML / GeckoView dependencies
-dontwarn java.beans.**
-dontwarn javax.annotation.**

# GeckoView keep rules
-keep class org.mozilla.geckoview.** { *; }
-keep interface org.mozilla.geckoview.** { *; }

# WorkManager keep rules
-keep class androidx.work.** { *; }

