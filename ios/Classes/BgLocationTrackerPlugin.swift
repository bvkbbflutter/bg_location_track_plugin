import Flutter
import UIKit
import CoreLocation

public class BgLocationTrackerPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    public static var shared: BgLocationTrackerPlugin?
    
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?
    
    public var pointsCapturedCounter: Int = 0
    public var pendingUploadCounter: Int = 0
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = BgLocationTrackerPlugin()
        BgLocationTrackerPlugin.shared = instance
        
        let mChannel = FlutterMethodChannel(
            name: "com.example.bg_location_tracker/methods",
            binaryMessenger: registrar.messenger()
        )
        instance.methodChannel = mChannel
        registrar.addMethodCallDelegate(instance, channel: mChannel)
        
        let eChannel = FlutterEventChannel(
            name: "com.example.bg_location_tracker/events",
            binaryMessenger: registrar.messenger()
        )
        instance.eventChannel = eChannel
        eChannel.setStreamHandler(instance)
        
        registrar.addApplicationDelegate(instance)
        
        // Restore tracking if it was active
        let config = ConfigStore.shared
        if config.isTracking && config.activeUserId != nil {
            LocationManagerCore.shared.start()
        }
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            result(true)
            
        case "checkPermissions":
            PermissionHelper.shared.checkPermissions { permMap in
                result(permMap)
            }
            
        case "requestPermissions":
            PermissionHelper.shared.requestPermissions { permMap in
                result(permMap)
            }
            
        case "openAppSettings":
            if let url = URL(string: UIApplication.openSettingsURLString) {
                DispatchQueue.main.async {
                    UIApplication.shared.open(url, options: [:]) { success in
                        result(success)
                    }
                }
            } else {
                result(false)
            }
            
        case "getTrackingState":
            let status = ConfigStore.shared.isTracking ? "tracking" : "idle"
            if status == "tracking" {
                LocationManagerCore.shared.requestNow()
            }
            result([
                "status": status,
                "pointsCaptured": pointsCapturedCounter,
                "pendingUpload": pendingUploadCounter
            ])
            
        case "start":
            do {
                let store = ConfigStore.shared
                // 1. Stop existing tracking first
                store.isTracking = false
                store.activeUserId = nil
                store.activeSessionId = nil
                LocationManagerCore.shared.stop()
                
                // 2. Parse new arguments
                if let arg = call.arguments as? [AnyHashable: Any] {
                    if let interval = arg["intervalSeconds"] as? NSNumber {
                        store.trackingIntervalMs = interval.int64Value * 1000
                    } else {
                        store.trackingIntervalMs = 60000 // default 1 min
                    }
                    
                    if let distance = arg["minDistanceMeters"] as? NSNumber {
                        store.trackingDistanceMeters = distance.doubleValue
                    } else {
                        store.trackingDistanceMeters = 0.0
                    }
                    
                    if let minAcc = arg["minAccuracyMeters"] as? NSNumber {
                        store.minAccuracyMeters = minAcc.doubleValue
                    }
                    
                    if let timeout = arg["notificationTimeout"] as? NSNumber {
                        store.notificationTimeoutSeconds = timeout.intValue
                    } else {
                        store.notificationTimeoutSeconds = 5
                    }
                    
                    store.activeUserId = arg["userId"] as? String
                    store.activeSessionId = arg["sessionId"] as? String
                    
                    if let scheduleList = arg["schedule"] as? [[String: Any]],
                       let scheduleData = try? JSONSerialization.data(withJSONObject: scheduleList, options: []),
                       let scheduleJsonStr = String(data: scheduleData, encoding: .utf8) {
                        store.scheduleJson = scheduleJsonStr
                    } else {
                        store.scheduleJson = nil
                    }
                    
                    store.isTracking = true
                }
                
                // 3. Start engine
                LocationManagerCore.shared.start()
                result(true)
            }
            
        case "stop":
            let store = ConfigStore.shared
            store.isTracking = false
            store.activeUserId = nil
            store.activeSessionId = nil
            LocationManagerCore.shared.stop()
            result(true)
            
        case "clearUploadConfig":
            let store = ConfigStore.shared
            store.syncUrl = nil
            store.syncHeaders = nil
            result(true)
            
        case "clearAll":
            let store = ConfigStore.shared
            store.isTracking = false
            store.activeUserId = nil
            store.activeSessionId = nil
            LocationManagerCore.shared.stop()
            LocationDatabase.shared.clearAll()
            store.clear()
            pointsCapturedCounter = 0
            pendingUploadCounter = 0
            result(true)
            
        case "configureUpload":
            if let arg = call.arguments as? [AnyHashable: Any] {
                let store = ConfigStore.shared
                store.syncUrl = arg["url"] as? String
                store.batchSize = (arg["batchSize"] as? NSNumber)?.intValue ?? 1
                if let headers = arg["headers"] as? [AnyHashable: Any],
                   let jsonData = try? JSONSerialization.data(withJSONObject: headers, options: []),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    store.syncHeaders = jsonString
                }
            }
            result(true)
            
        case "getLocations":
            result(LocationDatabase.shared.getAllLocations())
            
        case "getDiagnostics":
            PermissionHelper.shared.checkPermissions { permMap in
                result([
                    "serviceRunning": ConfigStore.shared.isTracking,
                    "permissions": permMap,
                    "batteryOptimizationIgnored": true,
                    "backgroundRestricted": false,
                    "powerSaveMode": false,
                    "dozeMode": false,
                    "playServicesAvailable": true,
                    "storedPoints": self.pointsCapturedCounter,
                    "pendingUpload": self.pendingUploadCounter,
                    "oemAutoStartLikelyRequired": false,
                    "warnings": [String]()
                ])
            }
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [AnyHashable : Any] = [:]) -> Bool {
        if let options = launchOptions as? [UIApplication.LaunchOptionsKey: Any],
           options[.location] != nil {
            LocationManagerCore.shared.handleSignificantChangeRelaunch()
        }
        return true
    }
    
    // FlutterStreamHandler methods
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
    
    public func emitLocation(_ data: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?([
                "type": "location",
                "data": data
            ])
        }
    }
    
    public func emitState() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.eventSink?([
                "type": "state",
                "data": [
                    "status": ConfigStore.shared.isTracking ? "tracking" : "idle",
                    "pointsCaptured": self.pointsCapturedCounter,
                    "pendingUpload": self.pendingUploadCounter
                ]
            ])
        }
    }
}
