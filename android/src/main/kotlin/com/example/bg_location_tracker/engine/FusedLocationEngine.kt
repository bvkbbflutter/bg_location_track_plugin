package com.example.bg_location_tracker.engine

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.location.Location
import android.os.Build
import com.example.bg_location_tracker.receiver.WatchdogReceiver
import com.google.android.gms.location.*

class FusedLocationEngine(private val context: Context) : LocationEngine {
    private val client = LocationServices.getFusedLocationProviderClient(context)
    private var listener: ((Location) -> Unit)? = null
    
    private val pendingIntent: PendingIntent by lazy {
        val intent = Intent(context, WatchdogReceiver::class.java)
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        PendingIntent.getBroadcast(context, 1002, intent, flags)
    }

    override fun setListener(listener: (Location) -> Unit) {
        this.listener = listener
    }

    @SuppressLint("MissingPermission")
    override fun start(intervalMs: Long, distanceMeters: Float) {
        val request = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, intervalMs)
            .setMinUpdateDistanceMeters(distanceMeters)
            .setMinUpdateIntervalMillis(intervalMs / 2)
            .build()
        client.requestLocationUpdates(request, pendingIntent)
    }

    override fun stop() {
        client.removeLocationUpdates(pendingIntent)
    }

    @SuppressLint("MissingPermission")
    override fun requestSingleUpdate() {
        client.getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, null)
            .addOnSuccessListener { loc ->
                if (loc != null) {
                    listener?.invoke(loc)
                } else {
                    // Fallback to last location if current location is unavailable
                    client.lastLocation.addOnSuccessListener { lastLoc ->
                        if (lastLoc != null) {
                            listener?.invoke(lastLoc)
                        } else {
                            android.util.Log.e("BgLocationTracker", "Both current and last location are null.")
                            // Can't invoke listener because it requires a non-null Location.
                            // The Foreground service will eventually stop via its failsafe timeout.
                        }
                    }
                }
            }
            .addOnFailureListener { e ->
                android.util.Log.e("BgLocationTracker", "Failed to get current location: ${e.message}")
            }
    }
}
