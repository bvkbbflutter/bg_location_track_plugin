import CoreMotion

class MotionDetector {
    static let shared = MotionDetector()
    private let activityManager = CMMotionActivityManager()
    
    func startMonitoring() {
        guard CMMotionActivityManager.isActivityAvailable() else { return }
        
        activityManager.startActivityUpdates(to: OperationQueue.main) { activity in
            guard let act = activity else { return }
            if act.walking || act.running || act.automotive || act.cycling {
                ModeController.shared.setMode(.active)
            } else if act.stationary {
                ModeController.shared.setMode(.passive)
            }
        }
    }
    
    func stopMonitoring() {
        activityManager.stopActivityUpdates()
    }
}
