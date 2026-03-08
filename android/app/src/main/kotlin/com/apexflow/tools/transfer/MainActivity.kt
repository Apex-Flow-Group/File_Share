package com.apexflow.tools.transfer

import android.Manifest
import android.content.Context
import android.content.IntentFilter
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.wifi.p2p.WifiP2pManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    
    companion object {
        private const val TAG = "MainActivity_P2P"
        private const val PERMISSION_REQUEST_CODE = 1001
    }
    
    private var wifiP2pManager: WifiP2pManager? = null
    private var channel: WifiP2pManager.Channel? = null
    private var receiver: WifiDirectDebugReceiver? = null
    private val intentFilter = IntentFilter()
    private val APPS_CHANNEL = "com.apex.core/apps"
    
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Setup file operations handler
        FileOperationsHandler(this).setupChannel(flutterEngine)
        
        // Setup apps channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APPS_CHANNEL).setMethodCallHandler { call, result ->
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
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        Log.d(TAG, "========================================")
        Log.d(TAG, "🚀 MainActivity Started")
        Log.d(TAG, "========================================")
        
        // Check Android version
        Log.d(TAG, "📱 Android Version: ${Build.VERSION.SDK_INT}")
        Log.d(TAG, "📱 Device Model: ${Build.MODEL}")
        Log.d(TAG, "📱 Manufacturer: ${Build.MANUFACTURER}")
        
        // Check Google Play Services
        checkGooglePlayServices()
        
        // Check permissions
        checkPermissions()
        
        // Initialize Wi-Fi P2P (for debugging)
        initializeWifiP2P()
        
        // Register broadcast receiver
        registerP2PReceiver()
    }
    
    private fun checkGooglePlayServices() {
        val apiAvailability = GoogleApiAvailability.getInstance()
        val resultCode = apiAvailability.isGooglePlayServicesAvailable(this)
        
        when (resultCode) {
            ConnectionResult.SUCCESS -> {
                Log.d(TAG, "✅ Google Play Services: AVAILABLE")
            }
            ConnectionResult.SERVICE_MISSING -> {
                Log.e(TAG, "❌ Google Play Services: MISSING")
            }
            ConnectionResult.SERVICE_VERSION_UPDATE_REQUIRED -> {
                Log.e(TAG, "⚠️ Google Play Services: UPDATE REQUIRED")
            }
            ConnectionResult.SERVICE_DISABLED -> {
                Log.e(TAG, "❌ Google Play Services: DISABLED")
            }
            else -> {
                Log.e(TAG, "❌ Google Play Services: ERROR ($resultCode)")
            }
        }
    }
    
    private fun checkPermissions() {
        Log.d(TAG, "\n🔐 Checking Permissions:")
        
        val permissions = mutableListOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION,
            Manifest.permission.CHANGE_WIFI_STATE,
            Manifest.permission.ACCESS_WIFI_STATE
        )
        
        // Android 12+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            permissions.add(Manifest.permission.BLUETOOTH_SCAN)
            permissions.add(Manifest.permission.BLUETOOTH_ADVERTISE)
            permissions.add(Manifest.permission.BLUETOOTH_CONNECT)
        }
        
        // Android 13+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissions.add(Manifest.permission.NEARBY_WIFI_DEVICES)
        }
        
        val missingPermissions = mutableListOf<String>()
        
        for (permission in permissions) {
            val status = ContextCompat.checkSelfPermission(this, permission)
            val permissionName = permission.split(".").last()
            
            if (status == PackageManager.PERMISSION_GRANTED) {
                Log.d(TAG, "  ✅ $permissionName: GRANTED")
            } else {
                Log.e(TAG, "  ❌ $permissionName: DENIED")
                missingPermissions.add(permission)
            }
        }
        
        if (missingPermissions.isNotEmpty()) {
            Log.e(TAG, "\n⚠️ Missing ${missingPermissions.size} permissions!")
            Log.e(TAG, "Requesting permissions...")
            ActivityCompat.requestPermissions(
                this,
                missingPermissions.toTypedArray(),
                PERMISSION_REQUEST_CODE
            )
        } else {
            Log.d(TAG, "\n✅ All permissions granted!")
        }
    }
    
    private fun initializeWifiP2P() {
        Log.d(TAG, "\n📡 Initializing Wi-Fi P2P Manager...")
        
        try {
            wifiP2pManager = getSystemService(Context.WIFI_P2P_SERVICE) as? WifiP2pManager
            
            if (wifiP2pManager != null) {
                channel = wifiP2pManager?.initialize(this, mainLooper, null)
                Log.d(TAG, "✅ WifiP2pManager initialized successfully")
                Log.d(TAG, "✅ Channel created: ${channel != null}")
            } else {
                Log.e(TAG, "❌ WifiP2pManager is NULL - Device may not support Wi-Fi Direct")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to initialize WifiP2pManager: ${e.message}")
            e.printStackTrace()
        }
    }
    
    private fun registerP2PReceiver() {
        Log.d(TAG, "\n📻 Registering P2P Broadcast Receiver...")
        
        // Setup intent filter
        intentFilter.addAction(WifiP2pManager.WIFI_P2P_STATE_CHANGED_ACTION)
        intentFilter.addAction(WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION)
        intentFilter.addAction(WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION)
        intentFilter.addAction(WifiP2pManager.WIFI_P2P_THIS_DEVICE_CHANGED_ACTION)
        
        receiver = WifiDirectDebugReceiver()
        registerReceiver(receiver, intentFilter)
        
        Log.d(TAG, "✅ Broadcast Receiver registered")
        Log.d(TAG, "========================================\n")
    }
    
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        
        if (requestCode == PERMISSION_REQUEST_CODE) {
            Log.d(TAG, "\n📋 Permission Results:")
            permissions.forEachIndexed { index, permission ->
                val permissionName = permission.split(".").last()
                val granted = grantResults[index] == PackageManager.PERMISSION_GRANTED
                
                if (granted) {
                    Log.d(TAG, "  ✅ $permissionName: GRANTED")
                } else {
                    Log.e(TAG, "  ❌ $permissionName: DENIED")
                }
            }
        }
    }
    
    override fun onResume() {
        super.onResume()
        receiver?.let {
            registerReceiver(it, intentFilter)
        }
    }
    
    override fun onPause() {
        super.onPause()
        receiver?.let {
            try {
                unregisterReceiver(it)
            } catch (e: Exception) {
                Log.e(TAG, "Error unregistering receiver: ${e.message}")
            }
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "🛑 MainActivity destroyed")
    }
    
    private fun getInstalledApps(): List<Map<String, Any>> {
        val appsList = mutableListOf<Map<String, Any>>()
        val pm = packageManager
        val packages = pm.getInstalledPackages(0)

        Log.d(TAG, "🔍 Getting installed apps... Total packages: ${packages.size}")

        for (packageInfo in packages) {
            val appInfo = packageInfo.applicationInfo ?: continue

            // Log app details for debugging
            val appName = pm.getApplicationLabel(appInfo).toString()
            val isSystemApp = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            val apkPath = appInfo.sourceDir
            val packageName = packageInfo.packageName

            Log.d(TAG, "📱 App: $appName, Package: $packageName, System: $isSystemApp, APK: $apkPath")

            // Include all apps except core system apps (be less restrictive)
            if (isSystemApp && packageName.startsWith("android.") ||
                packageName.startsWith("com.android.") ||
                packageName.startsWith("com.google.android.")) {
                Log.d(TAG, "  ⏭️ Skipping core system app: $packageName")
                continue
            }

            if (apkPath == null) {
                Log.d(TAG, "  ⏭️ Skipping app with no APK path: $packageName")
                continue
            }

            try {
                val icon = pm.getApplicationIcon(appInfo)
                val iconBytes = drawableToByteArray(icon)

                appsList.add(mapOf(
                    "name" to appName,
                    "path" to apkPath,
                    "package" to packageName,
                    "icon" to iconBytes
                ))

                Log.d(TAG, "  ✅ Added app: $appName")
            } catch (e: Exception) {
                Log.e(TAG, "  ❌ Error processing app $packageName: ${e.message}")
            }
        }

        Log.d(TAG, "📋 Final apps list size: ${appsList.size}")
        return appsList
    }

    private fun drawableToByteArray(drawable: Drawable): ByteArray {
        val bitmap = if (drawable is BitmapDrawable) {
            drawable.bitmap
        } else {
            val bmp = Bitmap.createBitmap(drawable.intrinsicWidth, drawable.intrinsicHeight, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            bmp
        }
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
        return stream.toByteArray()
    }
}
