# Testing Matrix

Follow this manual testing matrix to verify reliability on real devices.

## Setup
1. Run `mock_server` on your machine (`dart run bin/server.dart`).
2. Install the Example app on Android and iOS devices.
3. Configure `baseUrl` in `main.dart` to point to your machine's IP.

## 1. App State Testing (For each Tracking Mode)
Configure "Distance Filter (200m)". Walk with the device.

- [ ] **Foreground**: App is open. Map updates in real-time.
- [ ] **Background**: Press Home button. Walk 500m. Re-open app. Points should exist.
- [ ] **Screen Locked**: Lock screen. Walk 500m. Unlock. Points should exist.
- [ ] **Terminated (Swiped away)**: Swipe app from recents. Walk 500m. Open app. Points should exist, and upload should have occurred.
- [ ] **OS Kill**: Run `adb shell am kill com.example.bg_location_tracker_example`. Wait 5 mins. The watchdog should restart the service. Walk 500m.
- [ ] **Reboot**: Restart the phone. Do not open the app. Walk 500m. Open app. Points should exist.

## 2. Edge Cases
- [ ] **Force Stop**: Settings -> Apps -> Force Stop. Verify tracking stops permanently until app is opened again.
- [ ] **Permissions Revoked**: Revoke location permission from settings while tracking. Verify `TrackingEventLog` logs a `permission_revoked` event.
- [ ] **GPS Toggled**: Turn off location from quick settings. Verify `TrackingEventLog` logs a `gps_off` event.
- [ ] **Airplane Mode**: Turn on airplane mode. Walk 500m. Verify points are collected. Turn off airplane mode. Verify the queued points are bulk-uploaded successfully.
- [ ] **Doze Mode**: Run `adb shell dumpsys deviceidle force-idle`. Verify tracking window alarms still fire (using `setExactAndAllowWhileIdle`).
