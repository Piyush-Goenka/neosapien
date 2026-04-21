package com.neosapien.assignment.neo_sapien

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import java.io.File
import java.io.FileInputStream

/**
 * Android implementation of the Pigeon `NativeMediaSaverHostApi` contract.
 *
 * Saves received files into the platform's scoped-storage media roots:
 *   - `image/*` → `MediaStore.Images`      (Pictures/NeoSapien)
 *   - `video/*` → `MediaStore.Video`       (Movies/NeoSapien)
 *   - `audio/*` → `MediaStore.Audio`       (Music/NeoSapien)
 *   - other    → `MediaStore.Downloads`    (Download/NeoSapien)  [API 29+]
 *
 * No `WRITE_EXTERNAL_STORAGE` runtime permission is required on API 29+
 * because we only write through MediaStore inside the collection the app
 * itself owns. On API 28 and lower, `MediaStore.Downloads` does not exist
 * and we fall back to the app-scoped `Environment.DIRECTORY_DOWNLOADS`
 * path; the README documents that as the compatibility floor.
 */
class NativeMediaSaverImpl(private val context: Context) : NativeMediaSaverHostApi {

    override fun saveFileToGallery(
        request: SaveFileRequest,
        callback: (Result<SaveFileResult>) -> Unit
    ) {
        try {
            val source = File(request.localPath)
            if (!source.exists()) {
                callback(
                    Result.success(
                        SaveFileResult(
                            success = false,
                            savedUri = null,
                            message = "File not found at ${request.localPath}"
                        )
                    )
                )
                return
            }

            val mime = request.mimeType.lowercase()
            val displayName = sanitizeDisplayName(
                request.displayName.ifBlank { source.name },
                mime
            )

            val uri: Uri? = when {
                mime.startsWith("image/") -> insertImage(displayName, mime)
                mime.startsWith("video/") -> insertVideo(displayName, mime)
                mime.startsWith("audio/") -> insertAudio(displayName, mime)
                else -> insertDownload(displayName, mime)
            }

            if (uri == null) {
                callback(
                    Result.success(
                        SaveFileResult(
                            success = false,
                            savedUri = null,
                            message = "MediaStore insert returned no URI."
                        )
                    )
                )
                return
            }

            context.contentResolver.openOutputStream(uri)?.use { outputStream ->
                FileInputStream(source).use { input ->
                    input.copyTo(outputStream)
                }
            } ?: run {
                callback(
                    Result.success(
                        SaveFileResult(
                            success = false,
                            savedUri = uri.toString(),
                            message = "Could not open output stream for $uri."
                        )
                    )
                )
                return
            }

            markNotPending(uri)

            callback(
                Result.success(
                    SaveFileResult(
                        success = true,
                        savedUri = uri.toString(),
                        message = null
                    )
                )
            )
        } catch (error: Throwable) {
            callback(
                Result.success(
                    SaveFileResult(
                        success = false,
                        savedUri = null,
                        message = "Save failed: ${error.message ?: error::class.java.simpleName}"
                    )
                )
            )
        }
    }

    private fun insertImage(displayName: String, mime: String): Uri? {
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, displayName)
            put(MediaStore.Images.Media.MIME_TYPE, mime)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(
                    MediaStore.Images.Media.RELATIVE_PATH,
                    "${Environment.DIRECTORY_PICTURES}/NeoSapien"
                )
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
        }
        val collection =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            } else {
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI
            }
        return context.contentResolver.insert(collection, values)
    }

    private fun insertVideo(displayName: String, mime: String): Uri? {
        val values = ContentValues().apply {
            put(MediaStore.Video.Media.DISPLAY_NAME, displayName)
            put(MediaStore.Video.Media.MIME_TYPE, mime)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(
                    MediaStore.Video.Media.RELATIVE_PATH,
                    "${Environment.DIRECTORY_MOVIES}/NeoSapien"
                )
                put(MediaStore.Video.Media.IS_PENDING, 1)
            }
        }
        val collection =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            } else {
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI
            }
        return context.contentResolver.insert(collection, values)
    }

    private fun insertAudio(displayName: String, mime: String): Uri? {
        val values = ContentValues().apply {
            put(MediaStore.Audio.Media.DISPLAY_NAME, displayName)
            put(MediaStore.Audio.Media.MIME_TYPE, mime)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(
                    MediaStore.Audio.Media.RELATIVE_PATH,
                    "${Environment.DIRECTORY_MUSIC}/NeoSapien"
                )
                put(MediaStore.Audio.Media.IS_PENDING, 1)
            }
        }
        val collection =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            } else {
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
            }
        return context.contentResolver.insert(collection, values)
    }

    private fun insertDownload(displayName: String, mime: String): Uri? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            // MediaStore.Downloads was added in API 29; nothing we can legally
            // do on older Android without WRITE_EXTERNAL_STORAGE. Documented.
            return null
        }
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, displayName)
            put(MediaStore.Downloads.MIME_TYPE, mime)
            put(
                MediaStore.Downloads.RELATIVE_PATH,
                "${Environment.DIRECTORY_DOWNLOADS}/NeoSapien"
            )
            put(MediaStore.Downloads.IS_PENDING, 1)
        }
        return context.contentResolver.insert(
            MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY),
            values
        )
    }

    private fun markNotPending(uri: Uri) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return
        }
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.IS_PENDING, 0)
        }
        context.contentResolver.update(uri, values, null, null)
    }

    private fun sanitizeDisplayName(raw: String, mime: String): String {
        val cleaned = raw.replace(Regex("[\\\\/:*?\"<>|]"), "_").trim()
        if (cleaned.isEmpty()) {
            return "neosapien_${System.currentTimeMillis()}"
        }
        val ext = MimeTypeMap.getSingleton().getExtensionFromMimeType(mime)
        return if (ext != null && !cleaned.lowercase().endsWith(".${ext.lowercase()}")) {
            "$cleaned.$ext"
        } else {
            cleaned
        }
    }
}
