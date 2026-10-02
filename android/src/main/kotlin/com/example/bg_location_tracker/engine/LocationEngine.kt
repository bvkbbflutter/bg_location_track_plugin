package com.example.bg_location_tracker.engine

import android.location.Location

interface LocationEngine {
    fun start(intervalMs: Long, distanceMeters: Float)
    fun stop()
    fun requestSingleUpdate()
    fun setListener(listener: (Location) -> Unit)
}
