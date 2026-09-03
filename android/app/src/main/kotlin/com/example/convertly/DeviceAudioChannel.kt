package com.example.convertly

import android.Manifest
import android.app.Activity
import android.content.ContentUris
import android.content.ContentValues
import android.content.pm.PackageManager
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Reads the device's music index.
 *
 * Written here rather than taken from a plugin: the maintained options all
 * compile against Android SDKs old enough that they no longer configure under
 * current Gradle, and a music list is too central to this app to rest on that.
 */
class DeviceAudioChannel(private val activity: Activity) :
    MethodChannel.MethodCallHandler,
    ActivityCompat.OnRequestPermissionsResultCallback {

    companion object {
        const val CHANNEL = "convertly/device_audio"
        private const val REQUEST_CODE = 4471

        /** Audio-only from Android 13; before that there was no such split. */
        private val PERMISSION =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                Manifest.permission.READ_MEDIA_AUDIO
            } else {
                Manifest.permission.READ_EXTERNAL_STORAGE
            }

        /** Shorter than this is a ringtone or a notification, not a song. */
        private const val MIN_DURATION_MS = 20_000L
    }

    private var pendingPermission: MethodChannel.Result? = null

    fun attach(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasPermission" -> result.success(hasPermission())
            "requestPermission" -> requestPermission(result)
            "saveToMusic" -> saveToMusic(call, result)
            "querySongs" ->
                if (hasPermission()) {
                    result.success(querySongs())
                } else {
                    // An empty list would read as "this phone has no music",
                    // which is a different thing and would hide the prompt.
                    result.error("denied", "Audio permission not granted", null)
                }
            else -> result.notImplemented()
        }
    }

    private fun hasPermission(): Boolean =
        ContextCompat.checkSelfPermission(activity, PERMISSION) ==
            PackageManager.PERMISSION_GRANTED

    private fun requestPermission(result: MethodChannel.Result) {
        if (hasPermission()) {
            result.success(true)
            return
        }
        // Only one dialog can be in flight; a second request while one is open
        // would leave the first caller waiting forever.
        if (pendingPermission != null) {
            result.success(false)
            return
        }
        pendingPermission = result
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(PERMISSION),
            REQUEST_CODE
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (requestCode != REQUEST_CODE) {
            return
        }
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingPermission?.success(granted)
        pendingPermission = null
    }

    /**
     * Copies a file the app produced into the phone's public Music folder.
     *
     * Written through MediaStore rather than to a path: that is what puts the
     * track in the index every other music app reads, and it needs no write
     * permission on any supported version.
     */
    private fun saveToMusic(call: MethodCall, result: MethodChannel.Result) {
        val sourcePath = call.argument<String>("path")
        val displayName = call.argument<String>("name")

        if (sourcePath == null || displayName == null) {
            result.error("bad_args", "path and name are required", null)
            return
        }

        val source = File(sourcePath)
        if (!source.exists()) {
            result.error("missing", "That file is no longer on the device", null)
            return
        }

        try {
            val values = ContentValues().apply {
                put(MediaStore.Audio.Media.DISPLAY_NAME, displayName)
                put(MediaStore.Audio.Media.MIME_TYPE, mimeTypeFor(displayName))
                put(MediaStore.Audio.Media.IS_MUSIC, 1)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(
                        MediaStore.Audio.Media.RELATIVE_PATH,
                        "${Environment.DIRECTORY_MUSIC}/AudioForge"
                    )
                    // Hidden from other apps until the copy finishes, so a
                    // half-written file is never picked up as a track.
                    put(MediaStore.Audio.Media.IS_PENDING, 1)
                }
            }

            val resolver = activity.contentResolver
            val target = resolver.insert(
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                values
            ) ?: run {
                result.error("failed", "Could not create the file", null)
                return
            }

            resolver.openOutputStream(target)?.use { output ->
                source.inputStream().use { input -> input.copyTo(output) }
            } ?: run {
                resolver.delete(target, null, null)
                result.error("failed", "Could not write the file", null)
                return
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                values.clear()
                values.put(MediaStore.Audio.Media.IS_PENDING, 0)
                resolver.update(target, values, null, null)
            }

            result.success(target.toString())
        } catch (error: Exception) {
            result.error("failed", error.message, null)
        }
    }

    private fun mimeTypeFor(name: String): String =
        when (name.substringAfterLast('.', "").lowercase()) {
            "mp3" -> "audio/mpeg"
            "m4a" -> "audio/mp4"
            "wav" -> "audio/x-wav"
            else -> "audio/*"
        }

    private fun querySongs(): List<Map<String, Any?>> {
        val columns = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.SIZE
        )

        val songs = mutableListOf<Map<String, Any?>>()

        activity.contentResolver.query(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            columns,
            "${MediaStore.Audio.Media.IS_MUSIC} != 0",
            null,
            "${MediaStore.Audio.Media.DATE_ADDED} DESC"
        )?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val titleColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
            val artistColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
            val durationColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
            val sizeColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.SIZE)

            while (cursor.moveToNext()) {
                val duration = if (cursor.isNull(durationColumn)) {
                    null
                } else {
                    cursor.getLong(durationColumn)
                }
                if (duration != null && duration < MIN_DURATION_MS) {
                    continue
                }

                val id = cursor.getLong(idColumn)
                songs.add(
                    mapOf(
                        "id" to id.toString(),
                        "title" to cursor.getString(titleColumn),
                        "artist" to cursor.getString(artistColumn),
                        "durationMs" to duration,
                        "sizeBytes" to
                            if (cursor.isNull(sizeColumn)) null
                            else cursor.getLong(sizeColumn),
                        // A content URI rather than a file path: paths are not
                        // reliably readable under scoped storage, and the
                        // player opens either.
                        "uri" to ContentUris.withAppendedId(
                            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                            id
                        ).toString()
                    )
                )
            }
        }

        return songs
    }
}
