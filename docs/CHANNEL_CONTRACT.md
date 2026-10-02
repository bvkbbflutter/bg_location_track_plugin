# Channel Contract

## Channels

- MethodChannel: `com.example.bg_location_tracker/methods`
- EventChannel: `com.example.bg_location_tracker/events`

## Methods

| Method | Arguments | Returns | Description |
|---|---|---|---|
| `initialize` | `Map<String, dynamic>` (options) | `bool` | Initializes the tracker, restores state. |
| `checkPermissions` | none | `Map<String, dynamic>` (PermissionStatus) | Gets current permission state. |
| `requestPermissions` | `Map<String, dynamic>` (includeBackground, includeNotifications) | `Map<String, dynamic>` (PermissionStatus) | Requests permissions. |
| `openAppSettings` | none | `bool` | Opens app settings. |
| `openLocationSettings` | none | `bool` | Opens device location settings. |
| `requestIgnoreBatteryOptimizations`| none | `bool` | Prompts to ignore battery optimizations. |
| `openOemAutoStartSettings` | none | `bool` | Opens OEM specific settings. |
| `getDeviceInfoForTracking` | none | `Map<String, dynamic>` | Device info (manufacturer, model, etc). |
| `start` | `Map<String, dynamic>` (TrackingConfig) | `bool` | Starts tracking. |
| `stop` | `Map<String, dynamic>` (flushUpload) | `bool` | Stops tracking. |
| `pause` | none | `bool` | Pauses tracking. |
| `resume` | none | `bool` | Resumes tracking. |
| `isTracking` | none | `bool` | Returns true if currently tracking. |
| `getTrackingState` | none | `Map<String, dynamic>` (TrackingState) | Gets current state. |
| `updateConfig` | `Map<String, dynamic>` (TrackingConfig) | `bool` | Updates config on the fly. |
| `updateNotification` | `Map<String, dynamic>` (NotificationOptions) | `bool` | Updates notification settings. |
| `updateExtras` | `Map<String, dynamic>` (extras) | `bool` | Updates extras. |
| `scheduleShifts` | `List<Map<String, dynamic>>` (shifts) | `bool` | Schedules shifts. |
| `cancelShift` | `Map<String, dynamic>` (shiftId) | `bool` | Cancels a shift. |
| `getActiveShift` | none | `Map<String, dynamic>?` (Shift) | Gets active shift. |
| `listShifts` | none | `List<Map<String, dynamic>>` | Lists all shifts. |
| `getCurrentLocation` | `Map<String, dynamic>` (timeoutSeconds, accuracy) | `Map<String, dynamic>` (LocationPoint) | One-shot fix. |
| `captureNow` | `Map<String, dynamic>` (tag) | `bool` | Force record. |
| `getLocations` | `Map<String, dynamic>` (query params) | `List<Map<String, dynamic>>` (LocationPoints) | Fetches locations. |
| `getLastLocation` | none | `Map<String, dynamic>?` (LocationPoint) | Gets last stored location. |
| `getCount` | `Map<String, dynamic>` (query params) | `int` | Counts locations. |
| `getPendingCount` | none | `int` | Counts unsynced locations. |
| `deleteLocations` | `Map<String, dynamic>` (ids, before, sessionId) | `int` | Deletes locations. |
| `clearAll` | none | `bool` | Clears all data. |
| `getSessions` | none | `List<Map<String, dynamic>>` (Sessions) | Gets tracking sessions. |
| `getTrackingEventLog` | `Map<String, dynamic>` (limit) | `List<Map<String, dynamic>>` (EventLogs) | Audit trail. |
| `exportCsv` | `Map<String, dynamic>` (sessionId) | `String` | Exports to CSV. |
| `exportJson` | `Map<String, dynamic>` (sessionId) | `String` | Exports to JSON. |
| `configureUpload` | `Map<String, dynamic>` (UploadConfig) | `bool` | Configures sync. |
| `syncNow` | none | `Map<String, dynamic>` (SyncResult) | Force sync. |
| `updateAuthToken` | `Map<String, dynamic>` (token) | `bool` | Updates token. |
| `clearUploadConfig` | none | `bool` | Clears upload config. |
| `getSyncStatus` | none | `Map<String, dynamic>` (SyncStatus) | Gets sync status. |
| `pauseSync` | none | `bool` | Pauses sync. |
| `resumeSync` | none | `bool` | Resumes sync. |
| `getDiagnostics` | none | `Map<String, dynamic>` (Diagnostics) | Diagnostics info. |

## Error Codes
- `PERMISSION_DENIED`
- `PERMISSION_PERMANENTLY_DENIED`
- `BACKGROUND_PERMISSION_REQUIRED`
- `LOCATION_SERVICE_DISABLED`
- `NOTIFICATION_PERMISSION_REQUIRED`
- `INVALID_CONFIG`
- `ALREADY_TRACKING`
- `NOT_TRACKING`
- `PLAY_SERVICES_UNAVAILABLE`
- `FOREGROUND_SERVICE_START_NOT_ALLOWED`
- `EXACT_ALARM_NOT_PERMITTED`
- `UPLOAD_NOT_CONFIGURED`
- `STORAGE_ERROR`
- `UNKNOWN`

## Event Types (EventChannel)
Envelope format: `{ "type": "...", "data": {...}, "ts": 123456789 }`
Types: `location`, `state`, `permission`, `provider`, `sync`, `geofence`, `error`, `shift`, `log`
