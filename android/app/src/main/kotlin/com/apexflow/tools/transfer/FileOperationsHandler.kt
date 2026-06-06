package com.apexflow.tools.transfer

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class FileOperationsHandler(private val context: Context) {
    companion object {
        private const val CHANNEL = "com.apex.core/file_ops"
    }

    fun setupChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openFile" -> {
                    val path = call.argument<String>("path")
                    if (path != null) openFile(path, result)
                    else result.error("INVALID_ARGUMENT", "Path is required", null)
                }
                "openFileLocation" -> {
                    val path = call.argument<String>("path")
                    if (path != null) openFileLocation(path, result)
                    else result.error("INVALID_ARGUMENT", "Path is required", null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun openFile(path: String, result: MethodChannel.Result) {
        try {
            val file = File(path)
            if (!file.exists()) {
                result.error("FILE_NOT_FOUND", "File does not exist", null)
                return
            }

            val uri = FileProvider.getUriForFile(
                context, "${context.packageName}.fileprovider", file
            )

            // Let Android resolve the MIME type - falls back to "*/*" for unknown types
            val ext = file.extension.lowercase()
            val mimeType = MimeTypeMap.getSingleton()
                .getMimeTypeFromExtension(ext) ?: "*/*"

            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mimeType)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            context.startActivity(Intent.createChooser(intent, null))
            result.success(true)
        } catch (e: Exception) {
            result.error("OPEN_FAILED", e.message, null)
        }
    }

    private fun openFileLocation(path: String, result: MethodChannel.Result) {
        try {
            val file = File(path)
            val directory = file.parentFile ?: run {
                result.error("INVALID_PATH", "Cannot get parent directory", null)
                return
            }

            // Try multiple approaches to open folder
            val opened = tryOpenFolder(directory)
            if (opened) {
                result.success(true)
            } else {
                // Last resort: open the file itself
                openFile(path, result)
            }
        } catch (e: Exception) {
            result.error("OPEN_FAILED", e.message, null)
        }
    }

    private fun tryOpenFolder(directory: File): Boolean {
        // Approach 1: Android Files app via content URI
        try {
            val relativePath = directory.absolutePath
                .removePrefix("/storage/emulated/0/")
            val uri = Uri.parse(
                "content://com.android.externalstorage.documents/document/primary:$relativePath"
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "vnd.android.document/directory")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            if (intent.resolveActivity(context.packageManager) != null) {
                context.startActivity(intent)
                return true
            }
        } catch (_: Exception) {}

        // Approach 2: Files app via EXTRA_INITIAL_URI
        try {
            val relativePath = directory.absolutePath
                .removePrefix("/storage/emulated/0/")
            val uri = Uri.parse(
                "content://com.android.externalstorage.documents/document/primary:$relativePath"
            )
            val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "*/*"
                putExtra("android.provider.extra.INITIAL_URI", uri)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            if (intent.resolveActivity(context.packageManager) != null) {
                context.startActivity(intent)
                return true
            }
        } catch (_: Exception) {}

        // Approach 3: Generic file manager via file:// URI
        try {
            val uri = Uri.fromFile(directory)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "resource/folder")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            if (intent.resolveActivity(context.packageManager) != null) {
                context.startActivity(intent)
                return true
            }
        } catch (_: Exception) {}

        return false
    }
}
