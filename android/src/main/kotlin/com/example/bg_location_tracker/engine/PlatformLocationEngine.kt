package com.example.bg_location_tracker.engine

import android.annotation.SuppressLint
import android.content.Context
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.Looper

class PlatformLocationEngine(private val context: Context) : LocationEngine {
    private val manager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
    private var listener: ((Location) -> Unit)? = null
    
    private val locationListener = object : LocationListener {
        override fun onLocationChanged(location: Location) {
            listener?.invoke(location)
        }
        override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
        override fun onProviderEnabled(provider: String) {}
        override fun onProviderDisabled(provider: String) {}
    }

    override fun setListener(listener: (Location) -> Unit) {
        this.listener = listener
    }

    @SuppressLint("MissingPermission")
    override fun start(intervalMs: Long, distanceMeters: Float) {
        val provider = if (manager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
            LocationManager.GPS_PROVIDER
        } else {
            LocationManager.NETWORK_PROVIDER
        }
        manager.requestLocationUpdates(provider, intervalMs, distanceMeters, locationListener, Looper.getMainLooper())
    }

    override fun stop() {
        manager.removeUpdates(locationListener)
    }

    @SuppressLint("MissingPermission")
    override fun requestSingleUpdate() {
        val provider = if (manager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
            LocationManager.GPS_PROVIDER
        } else {
            LocationManager.NETWORK_PROVIDER
        }
        if (android.os.Build.VERSION.SDK_INT >= 30) {
            manager.getCurrentLocation(provider, null, context.mainExecutor) { loc ->
                loc?.let { listener?.invoke(it) }
            }
        } else {
            manager.requestSingleUpdate(provider, locationListener, Looper.getMainLooper())
        }
    }
}
