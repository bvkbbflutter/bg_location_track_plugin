import CoreLocation
import Foundation
import UserNotifications

class PermissionHelper: NSObject, CLLocationManagerDelegate {
    static let shared = PermissionHelper()
    private let manager = CLLocationManager()
    private var pendingCompletion: (([String: Any]) -> Void)?
    
    override init() {
        super.init()
        manager.delegate = self
    }
    
    func checkPermissions(completion: @escaping ([String: Any]) -> Void) {
        buildPermissionStatus(completion: completion)
    }
    
    func requestPermissions(completion: @escaping ([String: Any]) -> Void) {
        // Request notifications first or concurrently
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in
            DispatchQueue.main.async {
                let status: CLAuthorizationStatus
                if #available(iOS 14.0, *) {
                    status = self.manager.authorizationStatus
                } else {
                    status = CLLocationManager.authorizationStatus()
                }
                
                if status == .notDetermined {
                    self.pendingCompletion = completion
                    self.manager.requestAlwaysAuthorization()
                } else if status == .authorizedWhenInUse {
                    self.pendingCompletion = completion
                    self.manager.requestAlwaysAuthorization()
                    // Fallback timer in case the OS does not immediately re-prompt
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if let comp = self.pendingCompletion {
                            self.pendingCompletion = nil
                            self.buildPermissionStatus(completion: comp)
                        }
                    }
                } else {
                    self.buildPermissionStatus(completion: completion)
                }
            }
        }
    }
    
    func buildPermissionStatus(completion: @escaping ([String: Any]) -> Void) {
        let locationServicesEnabled = CLLocationManager.locationServicesEnabled()
        let authStatus: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            authStatus = manager.authorizationStatus
        } else {
            authStatus = CLLocationManager.authorizationStatus()
        }
        
        let locStr: String
        switch authStatus {
        case .authorizedAlways:
            locStr = "always"
        case .authorizedWhenInUse:
            locStr = "whileInUse"
        case .restricted:
            locStr = "restricted"
        case .denied, .notDetermined:
            fallthrough
        @unknown default:
            locStr = "denied"
        }
        
        var precise = true
        if #available(iOS 14.0, *) {
            precise = (manager.accuracyAuthorization == .fullAccuracy)
        }
        
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let notifGranted: Bool
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                notifGranted = true
            case .ephemeral:
                if #available(iOS 14.0, *) {
                    notifGranted = true
                } else {
                    notifGranted = false
                }
            case .denied, .notDetermined:
                fallthrough
            @unknown default:
                notifGranted = false
            }
            
            let result: [String: Any] = [
                "location": locStr,
                "preciseAccuracy": precise,
                "notifications": notifGranted,
                "batteryOptimizationIgnored": true,
                "locationServiceEnabled": locationServicesEnabled
            ]
            
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        handleAuthChanged(status)
    }
    
    @available(iOS 14.0, *)
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        handleAuthChanged(manager.authorizationStatus)
    }
    
    private func handleAuthChanged(_ status: CLAuthorizationStatus) {
        if status != .notDetermined {
            if let completion = pendingCompletion {
                pendingCompletion = nil
                buildPermissionStatus(completion: completion)
            }
        }
    }
}
