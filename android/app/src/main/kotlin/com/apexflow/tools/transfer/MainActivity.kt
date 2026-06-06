package com.apexflow.tools.transfer

import android.content.pm.ApplicationInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "MainActivity"
        private const val APPS_CHANNEL = "com.apex.core/apps"
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        FileOperationsHandler(this).setupChannel(flutterEngine)

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

            // Skip system packages
            if (isSystem && (pkg.startsWith("android.") ||
                    pkg.startsWith("com.android.") ||
                    pkg.startsWith("com.google.android."))) return@mapNotNull null

            val apkPath = appInfo.sourceDir ?: return@mapNotNull null

            try {
                val icon = pm.getApplicationIcon(appInfo)
                mapOf(
                    "name" to pm.getApplicationLabel(appInfo).toString(),
                    "path" to apkPath,
                    "package" to pkg,
                    "icon" to drawableToByteArray(icon)
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
