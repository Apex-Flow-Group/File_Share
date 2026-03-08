package com.apexflow.tools.transfer

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.wifi.p2p.WifiP2pManager
import android.util.Log

/**
 * Wi-Fi Direct Debug Receiver
 * Logs all Wi-Fi P2P state changes for debugging
 */
class WifiDirectDebugReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "P2P_DEBUG"
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            WifiP2pManager.WIFI_P2P_STATE_CHANGED_ACTION -> {
                val state = intent.getIntExtra(WifiP2pManager.EXTRA_WIFI_STATE, -1)
                when (state) {
                    WifiP2pManager.WIFI_P2P_STATE_ENABLED -> {
                        Log.d(TAG, "✅ Wi-Fi P2P is ENABLED")
                    }
                    WifiP2pManager.WIFI_P2P_STATE_DISABLED -> {
                        Log.e(TAG, "❌ Wi-Fi P2P is DISABLED - User needs to enable WiFi")
                    }
                    else -> {
                        Log.w(TAG, "⚠️ Wi-Fi P2P state UNKNOWN: $state")
                    }
                }
            }

            WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION -> {
                Log.d(TAG, "🔍 PEERS CHANGED - New devices available")
                // Request peer list here if you have WifiP2pManager instance
            }

            WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION -> {
                Log.d(TAG, "🔗 CONNECTION CHANGED")
                val networkInfo = intent.getParcelableExtra<android.net.NetworkInfo>(
                    WifiP2pManager.EXTRA_NETWORK_INFO
                )
                if (networkInfo?.isConnected == true) {
                    Log.d(TAG, "✅ Connected to P2P network")
                } else {
                    Log.d(TAG, "❌ Disconnected from P2P network")
                }
            }

            WifiP2pManager.WIFI_P2P_THIS_DEVICE_CHANGED_ACTION -> {
                Log.d(TAG, "📱 THIS DEVICE CHANGED")
                val device = intent.getParcelableExtra<android.net.wifi.p2p.WifiP2pDevice>(
                    WifiP2pManager.EXTRA_WIFI_P2P_DEVICE
                )
                Log.d(TAG, "Device Name: ${device?.deviceName}")
                Log.d(TAG, "Device Address: ${device?.deviceAddress}")
                Log.d(TAG, "Device Status: ${getDeviceStatus(device?.status ?: -1)}")
            }

            else -> {
                Log.d(TAG, "Unknown action: ${intent.action}")
            }
        }
    }

    private fun getDeviceStatus(status: Int): String {
        return when (status) {
            0 -> "CONNECTED"
            1 -> "INVITED"
            2 -> "FAILED"
            3 -> "AVAILABLE"
            4 -> "UNAVAILABLE"
            else -> "UNKNOWN ($status)"
        }
    }
}
