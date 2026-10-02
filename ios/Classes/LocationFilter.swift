import Foundation
import CoreLocation

class LocationFilter {
    static let shared = LocationFilter()
    private let config = ConfigStore.shared
    
    func accept(_ location: CLLocation) -> Bool {
        let accuracy = location.horizontalAccuracy
        if accuracy < 0 || accuracy > config.minAccuracyMeters {
            return false
        }
        
        let locTimeMs = Int64(location.timestamp.timeIntervalSince1970 * 1000)
        let lastLat = config.lastLocationLat
        let lastLng = config.lastLocationLng
        let lastTime = config.lastLocationTime
        
        if !lastLat.isNaN && !lastLng.isNaN && lastTime > 0 {
            let timeDiff = Double(locTimeMs - lastTime)
            
            // 1. Time interval check (if set)
            if config.trackingIntervalMs > 0 && timeDiff < Double(config.trackingIntervalMs) {
                return false // Too soon based on interval setting
            }
            
            if timeDiff <= 0 {
                return false // Exact same or older timestamp (duplicate OS callback)
            }
            
            let timeDiffSeconds = timeDiff / 1000.0
            let distance = haversine(lat1: lastLat, lon1: lastLng, lat2: location.coordinate.latitude, lon2: location.coordinate.longitude)
            let speed = distance / timeDiffSeconds
            if speed > 100.0 {
                return false // Unrealistic speed (GPS jump)
            }
            
            if config.trackingDistanceMeters > 0 {
                if distance < config.trackingDistanceMeters {
                    return false // Distance threshold not reached
                }
            }
        }
        
        config.lastLocationLat = location.coordinate.latitude
        config.lastLocationLng = location.coordinate.longitude
        config.lastLocationTime = locTimeMs
        return true
    }
    
    func haversine(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let r = 6371000.0 // meters
        let dLat = (lat2 - lat1) * .pi / 180.0
        let dLon = (lon2 - lon1) * .pi / 180.0
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * .pi / 180.0) * cos(lat2 * .pi / 180.0) *
                sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return r * c
    }
}
