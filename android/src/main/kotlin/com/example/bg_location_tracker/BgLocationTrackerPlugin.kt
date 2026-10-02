package com.example.bg_location_tracker

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import com.example.bg_location_tracker.service.LocationForegroundService

class BgLocationTrackerPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, EventChannel.StreamHandler, PluginRegistry.RequestPermissionsResultListener {
  private lateinit var methodChannel : MethodChannel
  private lateinit var eventChannel : EventChannel
  private var context: Context? = null
  private var activity: Activity? = null
  private var eventSink: EventChannel.EventSink? = null
  private var activityBinding: ActivityPluginBinding? = null

  private var pendingPermissionResult: Result? = null

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    context = flutterPluginBinding.applicationContext
    methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.example.bg_location_tracker/methods")
    methodChannel.setMethodCallHandler(this)
    
    eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "com.example.bg_location_tracker/events")
    eventChannel.setStreamHandler(this)

    // Restore tracking on app restart if it was active
    val ctx = context
    if (ctx != null) {
        val config = com.example.bg_location_tracker.store.ConfigStore(ctx)
        if (config.isTracking && config.activeUserId != null) {
            val modeController = com.example.bg_location_tracker.engine.ModeController(ctx, config)
            modeController.start { } // Pass empty listener, the service or PendingIntent will handle real locations
            
            // Re-schedule the alarm if periodic tracking is active
            if (config.trackingIntervalMs > 0 && config.trackingDistanceMeters <= 0) {
                com.example.bg_location_tracker.schedule.AlarmScheduler(ctx).scheduleWatchdog(config.trackingIntervalMs)
            }
        }
    }
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "initialize" -> {
        result.success(true)
      }
      "checkPermissions" -> {
        result.success(buildPermissionStatus())
      }
      "requestPermissions" -> {
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("NO_ACTIVITY", "Activity is null", null)
            return
        }

        val needed = mutableListOf<String>()
        val hasFine = ContextCompat.checkSelfPermission(currentActivity, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        
        if (!hasFine) {
            needed.add(Manifest.permission.ACCESS_FINE_LOCATION)
            needed.add(Manifest.permission.ACCESS_COARSE_LOCATION)
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && 
            ContextCompat.checkSelfPermission(currentActivity, Manifest.permission.ACCESS_BACKGROUND_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            // On Android 11+, you cannot request background and foreground location at the same time.
            // We only request background location if foreground is already granted.
            needed.add(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && 
            ContextCompat.checkSelfPermission(currentActivity, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            needed.add(Manifest.permission.POST_NOTIFICATIONS)
        }

        if (needed.isEmpty()) {
            result.success(buildPermissionStatus())
        } else {
            pendingPermissionResult = result
            ActivityCompat.requestPermissions(currentActivity, needed.toTypedArray(), 1001)
        }
      }
      "openAppSettings" -> {
        val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
        intent.data = android.net.Uri.parse("package:${context?.packageName}")
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context?.startActivity(intent)
        result.success(true)
      }
      "getTrackingState" -> {
        val status = if (com.example.bg_location_tracker.service.LocationForegroundService.isRunning) "tracking" else "idle"
        
        if (status == "tracking") {
            val intent = Intent(context, com.example.bg_location_tracker.service.LocationForegroundService::class.java)
            intent.action = "FORCE_UPDATE"
            context?.startService(intent)
        }

        result.success(mapOf(
          "status" to status,
          "pointsCaptured" to pointsCapturedCounter,
          "pendingUpload" to pendingUploadCounter
        ))
      }
      "start" -> {
        try {
            val ctx = context ?: throw Exception("Context is null")
            val store = com.example.bg_location_tracker.store.ConfigStore(ctx)
            
            // 1. Stop any existing tracking first
            store.isTracking = false
            store.activeUserId = null
            store.activeSessionId = null
            val modeController = com.example.bg_location_tracker.engine.ModeController(ctx, store)
            modeController.stop()
            com.example.bg_location_tracker.schedule.AlarmScheduler(ctx).cancelWatchdog()
            val stopIntent = Intent(ctx, LocationForegroundService::class.java)
            ctx.stopService(stopIntent)

            // 2. Parse new arguments
            val arg = call.arguments as? Map<*, *>
            if (arg != null) {
                val interval = (arg["intervalSeconds"] as? Number)?.toInt()
                if (interval != null) {
                    store.trackingIntervalMs = interval * 1000L
                } else {
                    store.trackingIntervalMs = 60000L // default 1 min
                }
                val distance = (arg["minDistanceMeters"] as? Number)?.toInt()
                if (distance != null) {
                    store.trackingDistanceMeters = distance.toFloat()
                } else {
                    store.trackingDistanceMeters = 0f
                }
                
                val minAcc = (arg["minAccuracyMeters"] as? Number)?.toFloat()
                if (minAcc != null) {
                    store.minAccuracyMeters = minAcc
                }
                
                store.notificationTimeoutSeconds = (arg["notificationTimeout"] as? Number)?.toInt() ?: 5
                store.activeUserId = arg["userId"] as? String
                store.activeSessionId = arg["sessionId"] as? String
                
                val scheduleList = arg["schedule"] as? List<*>
                if (scheduleList != null) {
                    try {
                        val jsonArray = org.json.JSONArray()
                        for (item in scheduleList) {
                            if (item is Map<*, *>) {
                                val jsonObj = org.json.JSONObject(item)
                                jsonArray.put(jsonObj)
                            }
                        }
                        store.scheduleJson = jsonArray.toString()
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                } else {
                    store.scheduleJson = null
                }
                
                store.isTracking = true
            }

            // 3. Start engine (registers PendingIntent for distance)
            modeController.start { } 
            
            // 4. If purely periodic, schedule the alarm
            if (store.trackingIntervalMs > 0 && store.trackingDistanceMeters <= 0) {
                com.example.bg_location_tracker.schedule.AlarmScheduler(ctx).scheduleWatchdog(store.trackingIntervalMs)
            }

            // 5. Trigger immediate first capture
            val startIntent = Intent(ctx, LocationForegroundService::class.java)
            startIntent.action = "FORCE_UPDATE"
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ctx.startForegroundService(startIntent)
            } else {
                ctx.startService(startIntent)
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("START_FAILED", e.message, null)
        }
      }
      "stop" -> {
        val ctx = context
        if (ctx != null) {
            val store = com.example.bg_location_tracker.store.ConfigStore(ctx)
            store.isTracking = false
            store.activeUserId = null
            store.activeSessionId = null
            val modeController = com.example.bg_location_tracker.engine.ModeController(ctx, store)
            modeController.stop()
            com.example.bg_location_tracker.schedule.AlarmScheduler(ctx).cancelWatchdog()
            
            val intent = Intent(ctx, LocationForegroundService::class.java)
            ctx.stopService(intent)
        }
        result.success(true)
      }
      "clearUploadConfig" -> {
        val store = com.example.bg_location_tracker.store.ConfigStore(context!!)
        store.syncUrl = null
        store.syncHeaders = null
        result.success(true)
      }
      "clearAll" -> {
        val ctx = context
        if (ctx != null) {
            val store = com.example.bg_location_tracker.store.ConfigStore(ctx)
            
            // Stop tracking
            store.isTracking = false
            store.activeUserId = null
            store.activeSessionId = null
            val modeController = com.example.bg_location_tracker.engine.ModeController(ctx, store)
            modeController.stop()
            com.example.bg_location_tracker.schedule.AlarmScheduler(ctx).cancelWatchdog()
            
            val intent = Intent(ctx, LocationForegroundService::class.java)
            ctx.stopService(intent)
            
            // Clear database
            com.example.bg_location_tracker.store.LocationDatabase.getInstance(ctx).clearAll()
            
            // Clear settings
            store.clear()
        }
        result.success(true)
      }
      "configureUpload" -> {
        val arg = call.arguments as? Map<*, *>
        if (arg != null) {
            val store = com.example.bg_location_tracker.store.ConfigStore(context!!)
            store.syncUrl = arg["url"] as? String
            store.batchSize = (arg["batchSize"] as? Int) ?: 1
            val headers = arg["headers"] as? Map<*, *>
            if (headers != null) {
                store.syncHeaders = org.json.JSONObject(headers).toString()
            }
        }
        result.success(true)
      }
      "getLocations" -> {
        result.success(emptyList<Map<String, Any>>())
      }
      "getDiagnostics" -> {
        result.success(mapOf(
          "serviceRunning" to false,
          "permissions" to buildPermissionStatus(),
          "batteryOptimizationIgnored" to true,
          "backgroundRestricted" to false,
          "powerSaveMode" to false,
          "dozeMode" to false,
          "playServicesAvailable" to true,
          "storedPoints" to pointsCapturedCounter,
          "pendingUpload" to pendingUploadCounter,
          "oemAutoStartLikelyRequired" to false,
          "warnings" to emptyList<String>()
        ))
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  private fun buildPermissionStatus(): Map<String, Any> {
      val ctx = context ?: return emptyMap()
      val hasFine = ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
      val hasBg = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
          ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_BACKGROUND_LOCATION) == PackageManager.PERMISSION_GRANTED
      } else true

      val locStr = if (hasBg) "always" else if (hasFine) "whileInUse" else "denied"
      
      val powerManager = ctx.getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
      val batteryIgnored = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
          powerManager.isIgnoringBatteryOptimizations(ctx.packageName)
      } else true

      return mapOf(
          "location" to locStr,
          "preciseAccuracy" to hasFine,
          "notifications" to true,
          "batteryOptimizationIgnored" to batteryIgnored,
          "locationServiceEnabled" to true
      )
  }

  override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {
      if (requestCode == 1001) {
          pendingPermissionResult?.success(buildPermissionStatus())
          pendingPermissionResult = null
          return true
      }
      return false
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    methodChannel.setMethodCallHandler(null)
    eventChannel.setStreamHandler(null)
    if (broadcastReceiver != null) {
        context?.unregisterReceiver(broadcastReceiver)
        broadcastReceiver = null
    }
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    eventSink = events
  }

  override fun onCancel(arguments: Any?) {
    eventSink = null
  }

  private var broadcastReceiver: android.content.BroadcastReceiver? = null
  private var pointsCapturedCounter = 0
  private var pendingUploadCounter = 0

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activityBinding = binding
    activity = binding.activity
    binding.addRequestPermissionsResultListener(this)
    
    if (broadcastReceiver == null) {
        broadcastReceiver = object : android.content.BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == "com.example.bg_location_tracker.LOCATION_UPDATE") {
                    val lat = intent.getDoubleExtra("lat", 0.0)
                    val lng = intent.getDoubleExtra("lng", 0.0)
                    val isSynced = intent.getBooleanExtra("isSynced", false)
                    val rejected = intent.getBooleanExtra("rejected", false)
                    
                    if (!rejected) {
                        pointsCapturedCounter++
                        if (!isSynced) {
                            pendingUploadCounter++
                        } else {
                            pendingUploadCounter = 0
                        }
                    }
                    
                    eventSink?.success(mapOf(
                        "type" to "location",
                        "data" to mapOf(
                            "uuid" to java.util.UUID.randomUUID().toString(),
                            "latitude" to lat,
                            "longitude" to lng,
                            "accuracy" to 10.0,
                            "timestamp" to System.currentTimeMillis(),
                            "rejected" to rejected
                        )
                    ))
                    
                    eventSink?.success(mapOf(
                        "type" to "state",
                        "data" to mapOf(
                            "status" to "tracking",
                            "pointsCaptured" to pointsCapturedCounter,
                            "pendingUpload" to pendingUploadCounter
                        )
                    ))
                }
            }
        }
        val filter = android.content.IntentFilter("com.example.bg_location_tracker.LOCATION_UPDATE")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context?.registerReceiver(broadcastReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context?.registerReceiver(broadcastReceiver, filter)
        }
    }
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activityBinding?.removeRequestPermissionsResultListener(this)
    activityBinding = null
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activityBinding = binding
    activity = binding.activity
    binding.addRequestPermissionsResultListener(this)
  }

  override fun onDetachedFromActivity() {
    activityBinding?.removeRequestPermissionsResultListener(this)
    activityBinding = null
    activity = null
  }
}
