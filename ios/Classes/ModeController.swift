import Foundation

class ModeController {
    static let shared = ModeController()
    
    enum TrackingMode {
        case active
        case passive
    }
    
    var currentMode: TrackingMode = .active
    
    func setMode(_ mode: TrackingMode) {
        currentMode = mode
    }
}
