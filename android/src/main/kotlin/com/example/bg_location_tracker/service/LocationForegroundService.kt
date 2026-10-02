package com.example.bg_location_tracker.service

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.location.Location
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.example.bg_location_tracker.engine.ModeController
import com.example.bg_location_tracker.filter.LocationFilter
import com.example.bg_location_tracker.models.LocationData
import com.example.bg_location_tracker.store.ConfigStore
import com.example.bg_location_tracker.store.LocationDatabase
import java.util.concurrent.Executors
import android.os.Handler
import android.os.Looper

class LocationForegroundService : Service() {
    private lateinit var modeController: ModeController
    private lateinit var locationFilter: LocationFilter
    private lateinit var db: LocationDatabase
    private lateinit var config: ConfigStore
    private val executor = Executors.newSingleThreadExecutor()

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        config = ConfigStore(this)
        db = LocationDatabase.getInstance(this)
        modeController = ModeController(this, config)
        locationFilter = LocationFilter(config.minAccuracyMeters, config)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!config.isTracking || config.activeUserId == null) {
            stopForeground(true)
            stopSelf(startId)
            return START_NOT_STICKY
        }

        createNotificationChannel()
        val notification = NotificationCompat.Builder(this, "bg_location_channel")
            .setContentTitle("Location Tracker")
            .setContentText("Capturing and syncing location...")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
        
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(1, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
            } else {
                startForeground(1, notification)
            }
        } catch (e: Exception) {
            android.util.Log.e("BgLocationTracker", "Failed to start foreground service: ${e.message}")
        }
        
        // Failsafe: Guarantee the service stops and removes the notification even if location fails or sync hangs
        val failsafeTimeoutMs = (config.notificationTimeoutSeconds * 1000L) + 20000L
        Handler(Looper.getMainLooper()).postDelayed({
            stopSelf(startId)
            // Note: stopSelf(startId) only stops the service if startId is the LATEST one.
            // If a newer request came in, this will gracefully do nothing.
            // But if we are stuck, this will kill the service and clear the notification!
        }, failsafeTimeoutMs)
        
        if (intent?.action == "PROCESS_LOCATION") {
            val loc = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra("location_extra", Location::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra("location_extra") as? Location
            }

            if (loc != null) {
                processLocation(loc, startId)
            } else {
                // Trigger a single update request if no location in intent
                modeController.setListener { l -> processLocation(l, startId) }
                modeController.requestNow()
            }
        } else if (intent?.action == "FORCE_UPDATE") {
            modeController.setListener { l -> processLocation(l, startId) }
            modeController.requestNow()
        } else {
            // Unrecognized, stop service.
            stopForeground(true)
            stopSelf(startId)
        }

        return START_NOT_STICKY
    }

    private fun processLocation(location: Location, startId: Int) {
        if (!config.isTracking || config.activeUserId == null) {
            finishWork(startId, immediate = true)
            return
        }

        if (!com.example.bg_location_tracker.schedule.ScheduleChecker.isWithinSchedule(config.scheduleJson)) {
            android.util.Log.d("BgLocationTracker", "Location rejected: outside scheduled window")
            val intent2 = Intent("com.example.bg_location_tracker.LOCATION_UPDATE")
            intent2.putExtra("lat", location.latitude)
            intent2.putExtra("lng", location.longitude)
            intent2.putExtra("isSynced", false)
            intent2.putExtra("rejected", true)
            sendBroadcast(intent2)
            finishWork(startId, immediate = false)
            return
        }

        if (locationFilter.accept(location)) {
            executor.submit {
                val locData = LocationData(
                    latitude = location.latitude,
                    longitude = location.longitude,
                    accuracy = location.accuracy,
                    altitude = location.altitude,
                    speed = location.speed,
                    bearing = location.bearing,
                    time = location.time,
                    isMock = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) location.isMock else location.isFromMockProvider
                )
                db.insert(locData)
                android.util.Log.d("BgLocationTracker", "Location captured natively: lat=${locData.latitude}, lng=${locData.longitude}")
                
                // Trigger instant sync
                val isSynced = com.example.bg_location_tracker.sync.UploadManager(this@LocationForegroundService).sync()
                
                // Broadcast to Flutter UI
                val intent2 = Intent("com.example.bg_location_tracker.LOCATION_UPDATE")
                intent2.putExtra("lat", locData.latitude)
                intent2.putExtra("lng", locData.longitude)
                intent2.putExtra("isSynced", isSynced)
                intent2.putExtra("rejected", false)
                sendBroadcast(intent2)
                
                // Done capturing and uploading, delay remove notification and stop service
                finishWork(startId, immediate = false)
            }
        } else {
            // Ignored by filter, still respect notification timeout
            android.util.Log.d("BgLocationTracker", "Location rejected by filter: lat=${location.latitude}, lng=${location.longitude}, acc=${location.accuracy}")
            
            // Broadcast rejection to Flutter UI so developer knows it is working
            val intent2 = Intent("com.example.bg_location_tracker.LOCATION_UPDATE")
            intent2.putExtra("lat", location.latitude)
            intent2.putExtra("lng", location.longitude)
            intent2.putExtra("isSynced", false)
            intent2.putExtra("rejected", true)
            sendBroadcast(intent2)

            finishWork(startId, immediate = false)
        }
    }

    private fun finishWork(startId: Int, immediate: Boolean = false) {
        if (immediate) {
            executeFinish(startId)
        } else {
            val timeoutMs = config.notificationTimeoutSeconds * 1000L
            Handler(Looper.getMainLooper()).postDelayed({
                executeFinish(startId)
            }, timeoutMs)
        }
    }

    private fun executeFinish(startId: Int) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf(startId)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "bg_location_channel",
                "Background Location",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    companion object {
        var isRunning = false
    }
}
