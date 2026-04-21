package com.neosapien.assignment.neo_sapien

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import androidx.activity.result.ActivityResult
import androidx.activity.result.ActivityResultLauncher
import java.io.File
import java.io.FileOutputStream
import java.util.UUID

// Android implementation of the Pigeon NativeFilePickerHostApi contract.
//
// Uses ACTION_OPEN_DOCUMENT directly (via platform channels) instead of the
// file_picker pub.dev package — Bonus D scope.
//
// Flow:
//   1. Dart calls pickFiles; we stash the pigeon callback and launch an
//      ACTION_OPEN_DOCUMENT intent via an ActivityResultLauncher that
//      MainActivity owns.
//   2. The user picks file(s). Android returns content:// URIs through the
//      launcher's callback, which MainActivity forwards to handleResult.
//   3. handleResult copies each URI's bytes into
//      filesDir/neosapien_picked/<uuid>_<name> so the dart side receives a
//      stable, in-sandbox file path — no long-lived content URI lifetime
//      to manage.
class NativeFilePickerImpl(
    private val context: Context,
    private val launcher: ActivityResultLauncher<Intent>
) : NativeFilePickerHostApi {

    private var pendingCallback: ((Result<PickFilesResult>) -> Unit)? = null

    override fun pickFiles(
        allowMultiple: Boolean,
        callback: (Result<PickFilesResult>) -> Unit
    ) {
        // If a previous pick is still open (shouldn't happen — UI blocks it),
        // fail it out cleanly before starting the new one.
        pendingCallback?.invoke(
            Result.success(
                PickFilesResult(
                    files = emptyList(),
                    cancelled = true,
                    message = "A new file picker was requested before the previous one finished."
                )
            )
        )
        pendingCallback = callback

        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, allowMultiple)
        }
        try {
            launcher.launch(intent)
        } catch (error: Throwable) {
            val cb = pendingCallback
            pendingCallback = null
            cb?.invoke(
                Result.success(
                    PickFilesResult(
                        files = emptyList(),
                        cancelled = false,
                        message = "Could not open document picker: ${error.message ?: error::class.java.simpleName}"
                    )
                )
            )
        }
    }

    fun handleResult(result: ActivityResult) {
        val cb = pendingCallback ?: return
        pendingCallback = null

        if (result.resultCode != Activity.RESULT_OK) {
            cb(
                Result.success(
                    PickFilesResult(files = emptyList(), cancelled = true, message = null)
                )
            )
            return
        }

        val data = result.data
        val uris = mutableListOf<Uri>()
        val clipData = data?.clipData
        if (clipData != null) {
            for (index in 0 until clipData.itemCount) {
                clipData.getItemAt(index)?.uri?.let { uris.add(it) }
            }
        } else {
            data?.data?.let { uris.add(it) }
        }

        if (uris.isEmpty()) {
            cb(
                Result.success(
                    PickFilesResult(files = emptyList(), cancelled = false, message = null)
                )
            )
            return
        }

        val files = mutableListOf<PickedFile>()
        for (uri in uris) {
            val picked = copyToCache(uri)
            if (picked != null) {
                files.add(picked)
            }
        }

        cb(
            Result.success(
                PickFilesResult(files = files, cancelled = false, message = null)
            )
        )
    }

    private fun copyToCache(uri: Uri): PickedFile? {
        return try {
            val resolver = context.contentResolver
            val displayName = queryDisplayName(uri) ?: "picked_${System.currentTimeMillis()}"
            val reportedSize = queryReportedSize(uri)
            val mime = resolver.type
                ?: MimeTypeMap.getSingleton()
                    .getMimeTypeFromExtension(MimeTypeMap.getFileExtensionFromUrl(displayName))
                ?: "application/octet-stream"

            val baseDir = File(context.filesDir, "neosapien_picked")
            if (!baseDir.exists()) {
                baseDir.mkdirs()
            }
            val target = File(baseDir, "${UUID.randomUUID()}_${sanitize(displayName)}")
            resolver.openInputStream(uri)?.use { input ->
                FileOutputStream(target).use { output ->
                    input.copyTo(output)
                }
            } ?: return null

            val actualSize = if (reportedSize > 0) reportedSize else target.length()

            PickedFile(
                id = UUID.randomUUID().toString(),
                name = displayName,
                localPath = target.absolutePath,
                mimeType = mime,
                byteCount = actualSize,
                sourceIdentifier = uri.toString()
            )
        } catch (error: Throwable) {
            null
        }
    }

    private fun queryDisplayName(uri: Uri): String? {
        return context.contentResolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME),
            null,
            null,
            null
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0 && !cursor.isNull(index)) cursor.getString(index) else null
            } else {
                null
            }
        }
    }

    private fun queryReportedSize(uri: Uri): Long {
        return context.contentResolver.query(
            uri,
            arrayOf(OpenableColumns.SIZE),
            null,
            null,
            null
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                val index = cursor.getColumnIndex(OpenableColumns.SIZE)
                if (index >= 0 && !cursor.isNull(index)) cursor.getLong(index) else 0L
            } else {
                0L
            }
        } ?: 0L
    }

    private fun sanitize(name: String): String {
        return name.replace(Regex("[\\\\/:*?\"<>|]"), "_")
    }
}
