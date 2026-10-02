package com.example.bg_location_tracker.schedule

import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone

object ScheduleChecker {
    fun isWithinSchedule(scheduleJson: String?): Boolean {
        if (scheduleJson.isNullOrEmpty()) {
            return true // If no schedule is defined, assume active
        }

        try {
            val jsonArray = JSONArray(scheduleJson)
            if (jsonArray.length() == 0) return true // Empty schedule = active

            val cal = Calendar.getInstance(TimeZone.getDefault())
            val currentDayOfWeek = cal.get(Calendar.DAY_OF_WEEK)
            // Adjust to match Flutter's day mapping: 1=Mon, 2=Tue, ..., 7=Sun
            val flutterDayOfWeek = if (currentDayOfWeek == Calendar.SUNDAY) 7 else currentDayOfWeek - 1
            
            val currentHour = cal.get(Calendar.HOUR_OF_DAY)
            val currentMinute = cal.get(Calendar.MINUTE)
            val nowTime = currentHour * 60 + currentMinute
            
            val now = Date()
            val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US)
            dateFormat.timeZone = TimeZone.getTimeZone("UTC") // Assuming ISO8601 UTC strings
            
            for (i in 0 until jsonArray.length()) {
                val window = jsonArray.getJSONObject(i)
                
                // 1. Check Date Range
                if (window.has("fromDate") && !window.isNull("fromDate")) {
                    val fromDateStr = window.getString("fromDate")
                    try {
                        val fromDate = dateFormat.parse(fromDateStr)
                        if (fromDate != null && now.before(fromDate)) {
                            continue
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }
                
                if (window.has("toDate") && !window.isNull("toDate")) {
                    val toDateStr = window.getString("toDate")
                    try {
                        val toDate = dateFormat.parse(toDateStr)
                        if (toDate != null && now.after(toDate)) {
                            continue
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }
                
                // 2. Check Day of Week
                var dayMatch = false
                if (window.has("days")) {
                    val daysArr = window.getJSONArray("days")
                    for (j in 0 until daysArr.length()) {
                        if (daysArr.getInt(j) == flutterDayOfWeek) {
                            dayMatch = true
                            break
                        }
                    }
                } else {
                    dayMatch = true // If no days specified, assume everyday
                }
                
                if (!dayMatch) continue
                
                // 3. Check Time of Day
                var timeMatch = false
                if (window.has("start") && window.has("end")) {
                    val startObj = window.getJSONObject("start")
                    val endObj = window.getJSONObject("end")
                    val startHour = startObj.optInt("hour", 0)
                    val startMin = startObj.optInt("minute", 0)
                    val endHour = endObj.optInt("hour", 23)
                    val endMin = endObj.optInt("minute", 59)
                    
                    val startTime = startHour * 60 + startMin
                    val endTime = endHour * 60 + endMin
                    
                    if (nowTime in startTime..endTime) {
                        timeMatch = true
                    }
                } else {
                    timeMatch = true
                }
                
                if (timeMatch) {
                    return true // Matches at least one window
                }
            }
            
            return false // Checked all windows, none matched
        } catch (e: Exception) {
            e.printStackTrace()
            return true // Fallback to active on parse error
        }
    }
}
