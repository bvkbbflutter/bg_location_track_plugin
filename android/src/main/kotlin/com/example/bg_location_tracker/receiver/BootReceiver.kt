package com.example.bg_location_tracker.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat
import com.example.bg_location_tracker.service.LocationForegroundService
import com.example.bg_location_tracker.store.ConfigStore

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            val config = ConfigStore(context)
            if (config.isTracking) {
                val serviceIntent = Intent(context, LocationForegroundService::class.java)
                ContextCompat.startForegroundService(context, serviceIntent)
            }
        }
    }
}
