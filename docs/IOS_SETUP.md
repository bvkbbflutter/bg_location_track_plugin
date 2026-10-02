# iOS Setup

## 1. Minimal Version Requirements

Ensure your `ios/Podfile` specifies:
```ruby
platform :ios, '13.0'
```

## 2. Info.plist Setup

Add the following to your `ios/Runner/Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
    <string>fetch</string>
    <string>processing</string>
</array>

<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to track your route while the app is open.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>We need background location to continue tracking your shift even if you close the app.</string>

<key>NSLocationAlwaysUsageDescription</key>
<string>We need background location to continue tracking your shift.</string>

<key>NSMotionUsageDescription</key>
<string>We use motion data to save battery when you are stationary.</string>
```

## 3. AppDelegate Integration

The plugin registers automatically.

## 4. Background Task Scheduler

If using Scheduled Windows or Shifts, ensure you register the permitted task identifiers in your Info.plist:
```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.example.bg_location_tracker.sync</string>
    <string>com.example.bg_location_tracker.schedule</string>
</array>
```
