# === WorkManager / Room (required by Google Ads SDK under AGP 9 R8 full mode) ===
-keep class androidx.work.** { <init>(...); }
-keep class * extends androidx.work.ListenableWorker {
    <init>(android.content.Context, androidx.work.WorkerParameters);
}
-keep class * extends androidx.room.RoomDatabase { *; }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.sqlite.db.framework.FrameworkSQLiteOpenHelperFactory { *; }

# === App Startup (prevents InitializationProvider crash) ===
-keep class androidx.startup.** { *; }
-keep class * implements androidx.startup.Initializer { *; }

# === Google Play Services / AdMob ===
-keep public class com.google.android.gms.ads.** { public *; }

# === just_audio (Flutter audio player) ===
-keep class com.google.android.exoplayer2.** { *; }
-keep class com.google.android.exoplayer2.ext.** { *; }
-keep class io.flutter.plugins.gradle.** { *; }
-dontwarn com.google.android.exoplayer2.**

# === audio_service (background audio) ===
-keep class com.ryanheise.audioservice.** { *; }
-keep class android.support.v4.media.** { *; }
-keep class android.support.v4.media.session.** { *; }
-keep class androidx.media.** { *; }

# === Hive (local database) ===
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class org.aspectj.** { *; }

# === youtube_explode_dart (YouTube streaming) ===
-keep class com.google.gson.** { *; }
-keep class java.lang.reflect.Type { *; }
-dontwarn com.google.gson.**

# === Provider (state management) ===
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# === Flutter general ===
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# === Kotlin coroutines (used by audio plugins) ===
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembers class kotlinx.coroutines.** {
    volatile <fields>;
}
-dontwarn kotlinx.coroutines.**

# === Permission handler ===
-keep class com.baseflow.permissionhandler.** { *; }

# === path_provider ===
-keep class io.flutter.plugins.pathprovider.** { *; }
