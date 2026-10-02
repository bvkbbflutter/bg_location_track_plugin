package com.example.bg_location_tracker.store

import android.content.Context
import android.content.SharedPreferences

class ConfigStore(context: Context) {
    private val prefs: SharedPreferences = context.getSharedPreferences("bg_location_prefs", Context.MODE_PRIVATE)

    var syncUrl: String?
        get() = prefs.getString("sync_url", null)
        set(value) = prefs.edit().putString("sync_url", value).apply()

    var syncHeaders: String?
        get() = prefs.getString("sync_headers", null)
        set(value) = prefs.edit().putString("sync_headers", value).apply()

    var batchSize: Int
        get() = prefs.getInt("batch_size", 50)
        set(value) = prefs.edit().putInt("batch_size", value).apply()

    var trackingIntervalMs: Long
        get() = prefs.getLong("tracking_interval_ms", 15 * 60 * 1000L)
        set(value) = prefs.edit().putLong("tracking_interval_ms", value).apply()

    var trackingDistanceMeters: Float
        get() = prefs.getFloat("tracking_distance_meters", 0f)
        set(value) = prefs.edit().putFloat("tracking_distance_meters", value).apply()

    var minAccuracyMeters: Float
        get() = prefs.getFloat("min_accuracy_meters", 100f)
        set(value) = prefs.edit().putFloat("min_accuracy_meters", value).apply()

    var isTracking: Boolean
        get() = prefs.getBoolean("is_tracking", false)
        set(value) = prefs.edit().putBoolean("is_tracking", value).apply()

    var lastLocationLat: Double
        get() = Double.fromBits(prefs.getLong("last_loc_lat", Double.NaN.toBits()))
        set(value) = prefs.edit().putLong("last_loc_lat", value.toBits()).apply()

    var lastLocationLng: Double
        get() = Double.fromBits(prefs.getLong("last_loc_lng", Double.NaN.toBits()))
        set(value) = prefs.edit().putLong("last_loc_lng", value.toBits()).apply()

    var lastLocationTime: Long
        get() = prefs.getLong("last_loc_time", 0L)
        set(value) = prefs.edit().putLong("last_loc_time", value).apply()

    var notificationTimeoutSeconds: Int
        get() = prefs.getInt("notification_timeout_sec", 5)
        set(value) = prefs.edit().putInt("notification_timeout_sec", value).apply()

    var activeUserId: String?
        get() = prefs.getString("active_user_id", null)
        set(value) = prefs.edit().putString("active_user_id", value).apply()

    var activeSessionId: String?
        get() = prefs.getString("active_session_id", null)
        set(value) = prefs.edit().putString("active_session_id", value).apply()

    var scheduleJson: String?
        get() = prefs.getString("schedule_json", null)
        set(value) = prefs.edit().putString("schedule_json", value).apply()

    fun clear() {
        prefs.edit().clear().apply()
    }
}
