package com.example.bg_location_tracker.engine

import android.content.Context
import android.location.Location
import com.example.bg_location_tracker.store.ConfigStore
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability

class ModeController(private val context: Context, private val config: ConfigStore) {
    private var engine: LocationEngine? = null

    init {
        val googleAvail = GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(context)
        engine = if (googleAvail == ConnectionResult.SUCCESS) {
            FusedLocationEngine(context)
        } else {
            PlatformLocationEngine(context)
        }
    }

    fun start(listener: (Location) -> Unit) {
        engine?.setListener(listener)
        engine?.start(config.trackingIntervalMs, config.trackingDistanceMeters)
    }

    fun stop() {
        engine?.stop()
    }
    
    fun setListener(listener: (Location) -> Unit) {
        engine?.setListener(listener)
    }
    
    fun requestNow() {
        engine?.requestSingleUpdate()
    }
}
