# Room, and WorkManager which is built on it.
#
# The Google Mobile Ads SDK starts WorkManager at launch, and WorkManager
# loads its Room database through a generated class it looks up by name. R8
# cannot see that reference, so without these rules it removes the class and
# the app dies on startup with "Failed to create an instance of WorkDatabase".
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.** { *; }
-dontwarn androidx.room.paging.**

# The ads SDK reaches its mediation adapters by name too.
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**
