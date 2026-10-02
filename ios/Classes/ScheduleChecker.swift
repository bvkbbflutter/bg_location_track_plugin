import Foundation

class ScheduleChecker {
    static func isWithinSchedule(scheduleJson: String?) -> Bool {
        guard let jsonStr = scheduleJson, !jsonStr.isEmpty else {
            return true // If no schedule is defined, assume active
        }
        
        guard let data = jsonStr.data(using: .utf8),
              let jsonArray = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] else {
            return true // Fallback to active on parse error
        }
        
        if jsonArray.isEmpty {
            return true
        }
        
        let now = Date()
        let calendar = Calendar.current
        
        // Adjust to match Flutter's day mapping: 1=Mon, 2=Tue, ..., 7=Sun
        // Swift calendar: 1=Sun, 2=Mon...
        let currentSwiftDay = calendar.component(.weekday, from: now)
        let flutterDayOfWeek = currentSwiftDay == 1 ? 7 : currentSwiftDay - 1
        
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let nowTime = currentHour * 60 + currentMinute
        
        let dateFormatter = ISO8601DateFormatter()
        // If we want fractions of seconds:
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let dateFormatterNoFrac = ISO8601DateFormatter()
        dateFormatterNoFrac.formatOptions = [.withInternetDateTime]
        
        for window in jsonArray {
            // 1. Check Date Range
            var dateMatch = true
            
            if let fromDateStr = window["fromDate"] as? String {
                if let fromDate = dateFormatter.date(from: fromDateStr) ?? dateFormatterNoFrac.date(from: fromDateStr) {
                    if now < fromDate {
                        dateMatch = false
                    }
                }
            }
            
            if let toDateStr = window["toDate"] as? String {
                if let toDate = dateFormatter.date(from: toDateStr) ?? dateFormatterNoFrac.date(from: toDateStr) {
                    if now > toDate {
                        dateMatch = false
                    }
                }
            }
            
            if !dateMatch { continue }
            
            // 2. Check Day of Week
            var dayMatch = false
            if let days = window["days"] as? [Int] {
                if days.contains(flutterDayOfWeek) {
                    dayMatch = true
                }
            } else {
                dayMatch = true // If no days specified, assume everyday
            }
            
            if !dayMatch { continue }
            
            // 3. Check Time of Day
            var timeMatch = false
            if let startObj = window["start"] as? [String: Any],
               let endObj = window["end"] as? [String: Any] {
                
                let startHour = startObj["hour"] as? Int ?? 0
                let startMin = startObj["minute"] as? Int ?? 0
                let endHour = endObj["hour"] as? Int ?? 23
                let endMin = endObj["minute"] as? Int ?? 59
                
                let startTime = startHour * 60 + startMin
                let endTime = endHour * 60 + endMin
                
                if nowTime >= startTime && nowTime <= endTime {
                    timeMatch = true
                }
            } else {
                timeMatch = true
            }
            
            if timeMatch {
                return true // Matches at least one window
            }
        }
        
        return false // Checked all windows, none matched
    }
}
