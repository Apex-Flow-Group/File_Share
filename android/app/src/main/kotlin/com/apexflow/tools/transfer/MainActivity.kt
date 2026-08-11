package com.apexflow.tools.transfer

import android.content.Intent
import android.content.pm.ApplicationInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "MainActivity"
        private const val APPS_CHANNEL = "com.apex.core/apps"
        private const val SINAN_CHANNEL = "com.apex.core/sinan"
        private const val NEARBY_CHANNEL = "com.apex.core/nearby"
        private const val SHARE_CHANNEL = "com.apex.core/share"
    }

    private var pendingSinanPath: String? = null
    private var pendingSharedPaths: List<String>? = null
    private var sinanChannel: MethodChannel? = null
    private var shareChannel: MethodChannel? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        FileOperationsHandler(this).setupChannel(flutterEngine)

        // Apps channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APPS_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getInstalledApps") {
                    Thread {
                        val apps = getInstalledApps()
                        runOnUiThread { result.success(apps) }
                    }.start()
                } else {
                    result.notImplemented()
                }
            }

        // Sinan file channel
        sinanChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SINAN_CHANNEL)
        sinanChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPendingSinanFile" -> {
                    result.success(pendingSinanPath)
                    pendingSinanPath = null
                }
                else -> result.notImplemented()
            }
        }

        // Share intent channel - يستقبل الملفات من قائمة المشاركة
        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL)
        shareChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPendingSharedFiles" -> {
                    result.success(pendingSharedPaths)
                    pendingSharedPaths = null
                }
                else -> result.notImplemented()
            }
        }

        // Nearby content URI resolver channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NEARBY_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "copyContentUri") {
                    val uriStr = call.argument<String>("uri")
                    val destPath = call.argument<String>("destPath")
                    if (uriStr == null || destPath == null) {
                        result.error("INVALID_ARGS", "uri and destPath required", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        try {
                            val uri = Uri.parse(uriStr)
                            val input = contentResolver.openInputStream(uri)
                                ?: throw Exception("openInputStream returned null")
                            val dest = File(destPath)
                            dest.parentFile?.mkdirs()
                            dest.outputStream().use { input.copyTo(it) }
                            runOnUiThread { result.success(destPath) }
                        } catch (e: Exception) {
                            Log.e(TAG, "copyContentUri failed: ${e.message}")
                            runOnUiThread { result.error("COPY_FAILED", e.message, null) }
                        }
                    }.start()
                } else {
                    result.notImplemented()
                }
            }

        // معالجة الـ intent عند بدء التطبيق
        handleIncomingIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIncomingIntent(intent)
    }

    // ─── Intent Handler ────────────────────────────────────────────────────

    private fun handleIncomingIntent(intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_VIEW -> handleSinanIntent(intent)
            Intent.ACTION_SEND -> handleSendIntent(intent)
            Intent.ACTION_SEND_MULTIPLE -> handleSendMultipleIntent(intent)
        }
    }

    // معالجة ملف .sinan
    private fun handleSinanIntent(intent: Intent?) {
        if (intent?.action != Intent.ACTION_VIEW) return
        val extraPath = intent.getStringExtra("sinan_file_path")
        if (extraPath != null && File(extraPath).exists()) {
            deliverOrStoreSinan(extraPath)
            return
        }
        val uri = intent.data ?: return
        try {
            val stream = contentResolver.openInputStream(uri) ?: return
            val tmpFile = File(cacheDir, "received.sinan")
            tmpFile.outputStream().use { stream.copyTo(it) }
            deliverOrStoreSinan(tmpFile.absolutePath)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to read .sinan from URI: ${e.message}")
        }
    }

    // معالجة ملف واحد مشارك
    private fun handleSendIntent(intent: Intent?) {
        val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent?.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent?.getParcelableExtra(Intent.EXTRA_STREAM)
        } ?: return

        Thread {
            val path = copyUriToCache(uri)
            if (path != null) {
                runOnUiThread { deliverOrStoreShared(listOf(path)) }
            }
        }.start()
    }

    // معالجة ملفات متعددة مشاركة
    private fun handleSendMultipleIntent(intent: Intent?) {
        val uris: List<Uri> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent?.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent?.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
        } ?: return

        Thread {
            val paths = uris.mapNotNull { copyUriToCache(it) }
            if (paths.isNotEmpty()) {
                runOnUiThread { deliverOrStoreShared(paths) }
            }
        }.start()
    }

    // نسخ content URI إلى مجلد مؤقت والحصول على المسار الحقيقي
    private fun copyUriToCache(uri: Uri): String? {
        return try {
            val fileName = getFileNameFromUri(uri) ?: "shared_file_${System.currentTimeMillis()}"
            val destDir = File(cacheDir, "shared_files")
            destDir.mkdirs()
            val destFile = File(destDir, fileName)
            contentResolver.openInputStream(uri)?.use { input ->
                destFile.outputStream().use { input.copyTo(it) }
            }
            destFile.absolutePath
        } catch (e: Exception) {
            Log.e(TAG, "copyUriToCache failed for $uri: ${e.message}")
            null
        }
    }

    // استخراج اسم الملف من content URI
    private fun getFileNameFromUri(uri: Uri): String? {
        if (uri.scheme == "content") {
            try {
                contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (idx >= 0) return cursor.getString(idx)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "getFileNameFromUri query failed: ${e.message}")
            }
        }
        return uri.lastPathSegment?.substringAfterLast('/')
    }

    private fun deliverOrStoreSinan(path: String) {
        val ch = sinanChannel
        if (ch != null) {
            runOnUiThread { ch.invokeMethod("onSinanFileReceived", path) }
        } else {
            pendingSinanPath = path
        }
    }

    private fun deliverOrStoreShared(paths: List<String>) {
        val ch = shareChannel
        if (ch != null) {
            ch.invokeMethod("onSharedFilesReceived", paths)
        } else {
            pendingSharedPaths = paths
        }
    }

    private fun getInstalledApps(): List<Map<String, Any>> {
        val pm = packageManager
        val packages = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.getInstalledPackages(android.content.pm.PackageManager.PackageInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            pm.getInstalledPackages(0)
        }

        return packages.mapNotNull { packageInfo ->
            val appInfo = packageInfo.applicationInfo ?: return@mapNotNull null
            val isSystem = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            val pkg = packageInfo.packageName

            // Skip core Android framework packages (not useful to share)
            if (pkg == "android" || pkg.startsWith("android.")) return@mapNotNull null

            val apkPath = appInfo.sourceDir ?: return@mapNotNull null

            try {
                val icon = pm.getApplicationIcon(appInfo)
                mapOf(
                    "name" to pm.getApplicationLabel(appInfo).toString(),
                    "path" to apkPath,
                    "package" to pkg,
                    "icon" to drawableToByteArray(icon),
                    "isSystem" to isSystem
                )
            } catch (e: Exception) {
                Log.e(TAG, "Error processing app $pkg: ${e.message}")
                null
            }
        }
    }

    private fun drawableToByteArray(drawable: Drawable): ByteArray {
        val bitmap = if (drawable is BitmapDrawable) {
            drawable.bitmap
        } else {
            Bitmap.createBitmap(
                drawable.intrinsicWidth, drawable.intrinsicHeight, Bitmap.Config.ARGB_8888
            ).also {
                val canvas = Canvas(it)
                drawable.setBounds(0, 0, canvas.width, canvas.height)
                drawable.draw(canvas)
            }
        }
        return ByteArrayOutputStream().also {
            bitmap.compress(Bitmap.CompressFormat.PNG, 85, it)
        }.toByteArray()
    }
}
