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

# The bundled yt-dlp engine (extractor plugin) unpacks Python/ffmpeg archives
# with Apache Commons Compress. Its zip extra-field registry is built
# reflectively below a static initializer, and R8 full mode rewrites it into a
# non-instantiable class - the app then dies with
# "class AsiExtraField is not a concrete class" the first time yt-dlp runs.
-keep class org.apache.commons.compress.** { *; }
-dontwarn org.apache.commons.compress.**

# yt-dlp / youtubedl-android: JNI + reflection driven, must stay intact.
-keep class com.yausername.** { *; }
-keep interface com.yausername.** { *; }
-keep class com.ashishpipaliya.** { *; }
-dontwarn com.yausername.**
-dontwarn com.ashishpipaliya.**
-dontwarn org.slf4j.**
-dontwarn org.apache.commons.io.**


