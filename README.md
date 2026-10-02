# Background Location Tracker

A production-grade, highly reliable Flutter plugin for background location tracking, designed to capture device location in *every* app state.

## Features

- **True Background Execution**: Survives app termination (swipe from recents), Doze mode, and device reboots.
- **Native-first Architecture**: Storage, filtering, and network sync happen entirely in native code (Kotlin/Swift). The Flutter engine is *not* required to be running.
- **Offline Reliability**: Points are safely stored in a local SQLite WAL-mode database. If network fails, points are queued and uploaded with exponential backoff.
- **Multiple Tracking Modes**: Continuous, Distance-based, Periodic, Schedule Windows, Shift-based, Adaptive/Motion-aware, and Geofence-triggered.
- **Smart Battery Policies**: Automatically degrade tracking frequency or pause tracking when the battery is low.
- **Stop Detection**: Avoid storing thousands of duplicate points when the user is stationary.

## Setup

See the platform-specific guides:
- [Android Setup](docs/ANDROID_SETUP.md)
- [iOS Setup](docs/IOS_SETUP.md)

## Limitations & Reliability Checklist

Tracking behavior when the app state changes:

| State | Android | iOS |
|---|---|---|
| Foreground / Background / Locked | Foreground service (`location`) + Notification | `allowsBackgroundLocationUpdates`, `UIBackgroundModes: location` |
| Swiped from recents ("Terminated") | Service keeps running (watchdog re-arms it) | Relaunches via significant-change/region monitoring |
| Killed by OS | Watchdog alarm + boot receiver restores state | Significant-change relaunch |
| Device reboot | `BOOT_COMPLETED` receiver restarts | Significant-change relaunch after first event |
| **Force-Stop in Settings** | **Impossible for any plugin** (OS blocks components) | Continues via significant-change relaunch only |
| Aggressive OEMs | Provide helpers to open autostart screens | n/a |

**End User Reliability Checklist:**
1. "Allow all the time" permission granted.
2. Battery Optimization set to "Unrestricted".
3. OEM-specific "Autostart" enabled (Xiaomi, Oppo, Vivo, etc. - see [OEM Guide](docs/OEM_GUIDE.md)).

## Quick Start

```dart
import 'package:bg_location_tracker/bg_location_tracker.dart';

void main() async {
  // 1. Initialize the tracker
  await BackgroundLocationTracker.instance.initialize(
    TrackerOptions(
      notification: NotificationOptions(
        title: 'App Tracking',
        text: 'Recording your route...',
      ),
    )
  );

  // 2. Request permissions
  await BackgroundLocationTracker.instance.requestPermissions();

  // 3. Configure Upload Sync
  await BackgroundLocationTracker.instance.configureUpload(
    UploadConfig(
      url: 'https://api.example.com/v1/locations/batch',
      authToken: 'your_jwt_token',
      batchSize: 50,
      syncIntervalSeconds: 60,
    )
  );

  // 4. Start Tracking (e.g., Distance-filtered walking)
  await BackgroundLocationTracker.instance.startDistanceFilter(
    minDistanceMeters: 50,
    heartbeatMinutes: 5,
  );
}
```

## API Reference

See the full [Channel Contract](docs/CHANNEL_CONTRACT.md).

## Play Store & App Store Declarations

**Google Play**: You must declare `ACCESS_BACKGROUND_LOCATION` usage. Use a prominent disclosure:
> "[App Name] collects location data to enable [feature] even when the app is closed or not in use."

**App Store**: Justify `Always` location in `Info.plist` thoroughly.