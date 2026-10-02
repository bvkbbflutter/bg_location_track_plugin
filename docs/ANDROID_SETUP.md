# Android Setup

## 1. Minimal Version Requirements

Ensure your `android/app/build.gradle` has at least:
```gradle
android {
    defaultConfig {
        minSdk 23 // Required by this plugin
        targetSdk 34
    }
}
```

## 2. Dependencies
No extra Gradle configurations are needed. The plugin bundles `play-services-location:21.2.0` automatically.

## 3. Permissions

The plugin automatically merges the required permissions. However, ensure you configure the Play Store Data Safety section to declare background location usage.

## 4. Customizing the Notification

Create a small white-with-transparent-background icon for your notification, and place it in `android/app/src/main/res/drawable/ic_stat_location.xml`.
Pass `smallIconResName: 'ic_stat_location'` in `NotificationOptions` during initialization.

## 5. Google Maps (Example App Only)

If using the example app, add your API key to the `AndroidManifest.xml` meta-data placeholder:
```xml
<meta-data android:name="com.google.android.geo.API_KEY" android:value="YOUR_KEY" />
```
