import Foundation

class ConfigStore {
    static let shared = ConfigStore()
    private let defaults = UserDefaults.standard
    
    var syncUrl: String? {
        get { defaults.string(forKey: "sync_url") }
        set { defaults.set(newValue, forKey: "sync_url") }
    }
    
    var syncHeaders: String? {
        get { defaults.string(forKey: "sync_headers") }
        set { defaults.set(newValue, forKey: "sync_headers") }
    }
    
    var batchSize: Int {
        get {
            let val = defaults.integer(forKey: "batch_size")
            return val > 0 ? val : 50
        }
        set { defaults.set(newValue, forKey: "batch_size") }
    }
    
    var trackingIntervalMs: Int64 {
        get {
            let val = defaults.object(forKey: "tracking_interval_ms") as? Int64
            return val ?? (15 * 60 * 1000)
        }
        set { defaults.set(newValue, forKey: "tracking_interval_ms") }
    }
    
    var trackingDistanceMeters: Double {
        get { defaults.double(forKey: "tracking_distance_meters") }
        set { defaults.set(newValue, forKey: "tracking_distance_meters") }
    }
    
    var minAccuracyMeters: Double {
        get {
            if defaults.object(forKey: "min_accuracy_meters") == nil {
                return 100.0
            }
            return defaults.double(forKey: "min_accuracy_meters")
        }
        set { defaults.set(newValue, forKey: "min_accuracy_meters") }
    }
    
    var isTracking: Bool {
        get { defaults.bool(forKey: "is_tracking") }
        set { defaults.set(newValue, forKey: "is_tracking") }
    }
    
    var lastLocationLat: Double {
        get {
            if defaults.object(forKey: "last_loc_lat") == nil {
                return Double.nan
            }
            return defaults.double(forKey: "last_loc_lat")
        }
        set { defaults.set(newValue, forKey: "last_loc_lat") }
    }
    
    var lastLocationLng: Double {
        get {
            if defaults.object(forKey: "last_loc_lng") == nil {
                return Double.nan
            }
            return defaults.double(forKey: "last_loc_lng")
        }
        set { defaults.set(newValue, forKey: "last_loc_lng") }
    }
    
    var lastLocationTime: Int64 {
        get {
            let val = defaults.object(forKey: "last_loc_time") as? Int64
            return val ?? 0
        }
        set { defaults.set(newValue, forKey: "last_loc_time") }
    }
    
    var notificationTimeoutSeconds: Int {
        get {
            let val = defaults.integer(forKey: "notification_timeout_sec")
            return val > 0 ? val : 5
        }
        set { defaults.set(newValue, forKey: "notification_timeout_sec") }
    }
    
    var activeUserId: String? {
        get { defaults.string(forKey: "active_user_id") }
        set { defaults.set(newValue, forKey: "active_user_id") }
    }
    
    var activeSessionId: String? {
        get { defaults.string(forKey: "active_session_id") }
        set { defaults.set(newValue, forKey: "active_session_id") }
    }
    
    var scheduleJson: String? {
        get { defaults.string(forKey: "schedule_json") }
        set { defaults.set(newValue, forKey: "schedule_json") }
    }
    
    func clear() {
        let keys = [
            "sync_url", "sync_headers", "batch_size", "tracking_interval_ms",
            "tracking_distance_meters", "min_accuracy_meters", "is_tracking",
            "last_loc_lat", "last_loc_lng", "last_loc_time",
            "notification_timeout_sec", "active_user_id", "active_session_id",
            "schedule_json"
        ]
        for key in keys {
            defaults.removeObject(forKey: key)
        }
        defaults.synchronize()
    }
}
