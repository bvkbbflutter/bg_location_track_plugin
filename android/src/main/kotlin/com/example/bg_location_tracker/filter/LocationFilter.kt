package com.example.bg_location_tracker.filter

import android.location.Location
import com.example.bg_location_tracker.store.ConfigStore
import kotlin.math.*

class LocationFilter(private val minAccuracy: Float, private val config: ConfigStore) {
    fun accept(location: Location): Boolean {
        if (location.accuracy > minAccuracy) return false
        
        val lastLat = config.lastLocationLat
        val lastLng = config.lastLocationLng
        val lastTime = config.lastLocationTime

        if (!lastLat.isNaN() && !lastLng.isNaN() && lastTime > 0) {
            val timeDiff = (location.time - lastTime) / 1000f
            
            if (timeDiff <= 0f) return false // Exact same timestamp (duplicate OS callback)

            val distance = haversine(lastLat, lastLng, location.latitude, location.longitude)
            if (timeDiff > 0) {
                val speed = distance / timeDiff
                if (speed > 100) return false // unrealistic speed (GPS jump)
            }

            // For distance filter mode
            if (config.trackingDistanceMeters > 0) {
                if (distance < config.trackingDistanceMeters) {
                    return false // distance threshold not reached
                }
            }
        }
        
        config.lastLocationLat = location.latitude
        config.lastLocationLng = location.longitude
        config.lastLocationTime = location.time
        return true
    }

    fun haversine(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val r = 6371000.0
        val dLat = Math.toRadians(lat2 - lat1)
        val dLon = Math.toRadians(lon2 - lon1)
        val a = sin(dLat / 2) * sin(dLat / 2) +
                cos(Math.toRadians(lat1)) * cos(Math.toRadians(lat2)) *
                sin(dLon / 2) * sin(dLon / 2)
        val c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return r * c
    }
}
