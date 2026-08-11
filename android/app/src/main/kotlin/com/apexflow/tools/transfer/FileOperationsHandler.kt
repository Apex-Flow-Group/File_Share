package com.apexflow.tools.transfer

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
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
                "saveToDownloads" -> {
                    val fileName = call.argument<String>("fileName")
                    val sourcePath = call.argument<String>("sourcePath")
                    val subFolder = call.argument<String>("subFolder") ?: ""
                    if (fileName != null && sourcePath != null) {
                        Thread {
                            saveToDownloads(fileName, sourcePath, subFolder, result)
                        }.start()
                    } else {
                        result.error("INVALID_ARGUMENT", "fileName and sourcePath are required", null)
                    }
                }
                "getDownloadsPath" -> {
                    getDownloadsPath(result)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Returns the public Downloads/ApexShare path.
     * On Android 10+, files should be saved via MediaStore (saveToDownloads),
     * but we still return the path for reference and for pre-Android 10.
     */
    private fun getDownloadsPath(result: MethodChannel.Result) {
        val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        val apexDir = File(downloadsDir, "ApexShare")
        apexDir.mkdirs()
        result.success(apexDir.absolutePath)
    }

    /**
     * Save a file to public Downloads/ApexShare/<subFolder>/ using MediaStore API (Android 10+)
     * or direct file write (Android 9 and below).
     * This does NOT require MANAGE_EXTERNAL_STORAGE permission.
     */
    private fun saveToDownloads(
        fileName: String,
        sourcePath: String,
        subFolder: String,
        result: MethodChannel.Result
    ) {
        try {
            val sourceFile = File(sourcePath)
            if (!sourceFile.exists()) {
                runOnUiThread { result.error("FILE_NOT_FOUND", "Source file not found", null) }
                return
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // Android 10+ — use MediaStore
                val relativePath = if (subFolder.isNotEmpty()) {
                    "${Environment.DIRECTORY_DOWNLOADS}/ApexShare/$subFolder"
                } else {
                    "${Environment.DIRECTORY_DOWNLOADS}/ApexShare"
                }

                val ext = fileName.substringAfterLast('.', "")
                val mimeType = MimeTypeMap.getSingleton()
                    .getMimeTypeFromExtension(ext.lowercase()) ?: "application/octet-stream"

                val contentValues = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                    put(MediaStore.Downloads.MIME_TYPE, mimeType)
                    put(MediaStore.Downloads.RELATIVE_PATH, relativePath)
                    put(MediaStore.Downloads.IS_PENDING, 1)
                }

                val resolver = context.contentResolver
                val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
                    ?: throw Exception("MediaStore insert returned null")

                resolver.openOutputStream(uri)?.use { outputStream ->
                    sourceFile.inputStream().use { it.copyTo(outputStream) }
                } ?: throw Exception("Failed to open output stream")

                // Mark as complete
                contentValues.clear()
                contentValues.put(MediaStore.Downloads.IS_PENDING, 0)
                resolver.update(uri, contentValues, null, null)

                // Return the actual file path
                val finalPath = "${Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)}/ApexShare/$subFolder/$fileName"
                runOnUiThread { result.success(finalPath) }
            } else {
                // Android 9 and below — direct file write
                val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                val destDir = if (subFolder.isNotEmpty()) {
                    File(downloadsDir, "ApexShare/$subFolder")
                } else {
                    File(downloadsDir, "ApexShare")
                }
                destDir.mkdirs()

                val destFile = File(destDir, fileName)
                sourceFile.inputStream().use { input ->
                    destFile.outputStream().use { input.copyTo(it) }
                }
                runOnUiThread { result.success(destFile.absolutePath) }
            }
        } catch (e: Exception) {
            runOnUiThread { result.error("SAVE_FAILED", e.message, null) }
        }
    }

    private fun runOnUiThread(action: () -> Unit) {
        android.os.Handler(android.os.Looper.getMainLooper()).post(action)
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

            // Special handling for APK files — check install permission first
            if (ext == "apk" || mimeType == "application/vnd.android.package-archive") {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    if (!context.packageManager.canRequestPackageInstalls()) {
                        // Redirect user to enable "Install from unknown sources" for this app
                        val settingsIntent = Intent(
                            android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                            Uri.parse("package:${context.packageName}")
                        ).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        context.startActivity(settingsIntent)
                        result.success(true)
                        return
                    }
                }

                val installIntent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, "application/vnd.android.package-archive")
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(installIntent)
                result.success(true)
                return
            }

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
