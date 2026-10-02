package com.example.bg_location_tracker.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat
import com.example.bg_location_tracker.schedule.AlarmScheduler
import com.example.bg_location_tracker.service.LocationForegroundService
import com.example.bg_location_tracker.store.ConfigStore
import com.google.android.gms.location.LocationResult

class WatchdogReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val config = ConfigStore(context)
        if (config.isTracking && config.activeUserId != null) {
            val serviceIntent = Intent(context, LocationForegroundService::class.java)
            serviceIntent.action = "PROCESS_LOCATION"
            
            if (LocationResult.hasResult(intent)) {
                val result = LocationResult.extractResult(intent)
                result?.lastLocation?.let { loc ->
                    serviceIntent.putExtra("location_extra", loc)
                }
            }

            ContextCompat.startForegroundService(context, serviceIntent)
            
            // Only reschedule periodic watchdog if we are not purely in distance-filter mode
            if (config.trackingIntervalMs > 0 && config.trackingDistanceMeters <= 0) {
                AlarmScheduler(context).scheduleWatchdog(config.trackingIntervalMs)
            }
        }
    }
}
