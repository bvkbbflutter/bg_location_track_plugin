import Foundation

class UploadManager: NSObject {
    static let shared = UploadManager()
    
    private let config = ConfigStore.shared
    private let db = LocationDatabase.shared
    
    private static let connectTimeout: TimeInterval = 15.0
    private static let readTimeout: TimeInterval = 30.0
    private static let maxBatchesPerRun = 50
    
    private let syncLock = NSLock()
    
    private let utcFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        f.timeZone = TimeZone(abbreviation: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    
    private let localFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        f.timeZone = TimeZone.current
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    
    @discardableResult
    func sync() -> Bool {
        guard syncLock.try() else {
            print("[BgLocationTracker] Sync already in progress, skipping")
            return false
        }
        defer { syncLock.unlock() }
        
        guard let urlStr = config.syncUrl, !urlStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let url = URL(string: urlStr) else {
            print("[BgLocationTracker] Sync URL is not configured")
            return true
        }
        
        var headersDict: [String: Any]?
        if let headersStr = config.syncHeaders, !headersStr.isEmpty,
           let data = headersStr.data(using: .utf8) {
            headersDict = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any]
        }
        
        let userId = (headersDict?["userId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? (headersDict?["userId"] as? String)
            : config.activeUserId
        
        let batchSize = max(1, config.batchSize)
        var batchesSent = 0
        var pointsSent = 0
        
        while batchesSent < UploadManager.maxBatchesPerRun {
            let locations = db.getUnsynced(limit: batchSize)
            if locations.isEmpty {
                if batchesSent == 0 {
                    print("[BgLocationTracker] No unsynced locations")
                } else {
                    print("[BgLocationTracker] Backlog drained: \(pointsSent) location(s) in \(batchesSent) request(s)")
                }
                updatePendingCounter()
                return true
            }
            
            var locArray = [[String: Any]]()
            for loc in locations {
                let date = Date(timeIntervalSince1970: Double(loc.time) / 1000.0)
                var obj: [String: Any] = [
                    "id": loc.id,
                    "latitude": loc.latitude,
                    "longitude": loc.longitude,
                    "accuracy": loc.accuracy,
                    "timestamp": loc.time,
                    "timestampString": utcFormatter.string(from: date),
                    "timestampLocal": localFormatter.string(from: date),
                    "saved_from": "Native",
                    "platform": "iOS"
                ]
                if let uid = userId, !uid.isEmpty {
                    obj["userId"] = uid
                }
                locArray.append(obj)
            }
            
            var bodyObj: [String: Any] = ["locations": locArray]
            if let uid = userId, !uid.isEmpty {
                bodyObj["userId"] = uid
            }
            
            guard let jsonData = try? JSONSerialization.data(withJSONObject: bodyObj, options: [.prettyPrinted]) else {
                print("[BgLocationTracker] Failed to serialize locations payload")
                return false
            }
            
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("[BgLocationTracker] === API REQUEST ===\nURL: \(urlStr)\nMethod: POST\nPayload: \(jsonString)\n===================")
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = UploadManager.readTimeout
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            if let headers = headersDict {
                for (key, val) in headers {
                    if key.caseInsensitiveCompare("userId") == .orderedSame {
                        continue
                    }
                    request.setValue("\(val)", forHTTPHeaderField: key)
                }
            }
            
            request.httpBody = jsonData
            
            let semaphore = DispatchSemaphore(value: 0)
            var success = false
            
            let sessionConfig = URLSessionConfiguration.ephemeral
            sessionConfig.timeoutIntervalForRequest = UploadManager.connectTimeout
            sessionConfig.timeoutIntervalForResource = UploadManager.readTimeout
            let session = URLSession(configuration: sessionConfig)
            
            let task = session.dataTask(with: request) { data, response, error in
                defer { semaphore.signal() }
                
                if let error = error {
                    print("[BgLocationTracker] === API ERROR ===\nMessage: \(error.localizedDescription)")
                    return
                }
                
                let httpResponse = response as? HTTPURLResponse
                let statusCode = httpResponse?.statusCode ?? 0
                let responseBody = data != nil ? (String(data: data!, encoding: .utf8) ?? "") : ""
                
                print("[BgLocationTracker] === API RESPONSE ===\nStatus: \(statusCode)\nBody: \(responseBody)\n====================")
                
                if (200...299).contains(statusCode) {
                    success = true
                } else {
                    print("[BgLocationTracker] API call failed. HTTP \(statusCode)")
                }
            }
            task.resume()
            _ = semaphore.wait(timeout: .now() + UploadManager.readTimeout)
            
            if !success {
                updatePendingCounter()
                return false
            }
            
            let syncedIds = locations.map { $0.id }
            db.deleteSynced(ids: syncedIds)
            
            batchesSent += 1
            pointsSent += locations.sizeCount
            updatePendingCounter()
        }
        
        print("[BgLocationTracker] Reached max batches cap (\(batchesSent) batches, \(pointsSent) sent)")
        return true
    }
    
    private func updatePendingCounter() {
        let remaining = db.getUnsyncedCount()
        DispatchQueue.main.async {
            BgLocationTrackerPlugin.shared?.pendingUploadCounter = remaining
            BgLocationTrackerPlugin.shared?.emitState()
        }
    }
}

private extension Array {
    var sizeCount: Int { return count }
}
