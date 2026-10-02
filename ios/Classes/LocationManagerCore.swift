import CoreLocation
import UIKit

class LocationManagerCore: NSObject, CLLocationManagerDelegate {
    static let shared = LocationManagerCore()
    let manager = CLLocationManager()
    private let config = ConfigStore.shared
    
    override init() {
        super.init()
        manager.delegate = self
        manager.pausesLocationUpdatesAutomatically = false
        if #available(iOS 11.0, *) {
            manager.showsBackgroundLocationIndicator = true
        }
        manager.allowsBackgroundLocationUpdates = true
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .otherNavigation
    }
    
    func start() {
        if config.trackingDistanceMeters > 0 {
            manager.distanceFilter = CLLocationDistance(config.trackingDistanceMeters)
        } else {
            manager.distanceFilter = kCLDistanceFilterNone
        }
        
        manager.startUpdatingLocation()
        manager.startMonitoringSignificantLocationChanges()
        requestNow()
    }
    
    func stop() {
        manager.stopUpdatingLocation()
        manager.stopMonitoringSignificantLocationChanges()
    }
    
    func requestNow() {
        manager.requestLocation()
    }
    
    func handleSignificantChangeRelaunch() {
        if config.isTracking && config.activeUserId != nil {
            start()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if !ScheduleChecker.isWithinSchedule(scheduleJson: config.scheduleJson) {
            print("[BgLocationTracker] Location rejected: outside scheduled window")
            return
        }
        
        for location in locations {
            if LocationFilter.shared.accept(location) {
                let insertedId = LocationDatabase.shared.insert(location: location)
                
                DispatchQueue.main.async {
                    BgLocationTrackerPlugin.shared?.pointsCapturedCounter += 1
                    BgLocationTrackerPlugin.shared?.pendingUploadCounter += 1
                    
                    let timeMs = Int64(location.timestamp.timeIntervalSince1970 * 1000)
                    let locData: [String: Any] = [
                        "id": insertedId,
                        "uuid": UUID().uuidString,
                        "latitude": location.coordinate.latitude,
                        "longitude": location.coordinate.longitude,
                        "accuracy": location.horizontalAccuracy,
                        "altitude": location.altitude,
                        "speed": max(0.0, location.speed),
                        "heading": max(0.0, location.course),
                        "timestamp": timeMs,
                        "time": timeMs,
                        "rejected": false
                    ]
                    
                    BgLocationTrackerPlugin.shared?.emitLocation(locData)
                    BgLocationTrackerPlugin.shared?.emitState()
                }
                
                print("[BgLocationTracker] Location captured natively: lat=\(location.coordinate.latitude), lng=\(location.coordinate.longitude)")
                
                // Trigger instant sync on background queue
                DispatchQueue.global(qos: .utility).async {
                    _ = UploadManager.shared.sync()
                }
            } else {
                // Location rejected by filter (too soon or too small distance)
                // We do not emit this to Flutter to avoid flooding the logs.
                print("[BgLocationTracker] Location rejected by filter (interval/distance not reached): lat=\(location.coordinate.latitude)")
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[BgLocationTracker] Location update failed: \(error)")
    }
}
