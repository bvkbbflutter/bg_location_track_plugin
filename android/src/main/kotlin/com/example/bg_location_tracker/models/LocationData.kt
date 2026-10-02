package com.example.bg_location_tracker.models

data class LocationData(
    val id: Long = 0,
    val latitude: Double,
    val longitude: Double,
    val accuracy: Float,
    val altitude: Double,
    val speed: Float,
    val bearing: Float,
    val time: Long,
    val isMock: Boolean
)
