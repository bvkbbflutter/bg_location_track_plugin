# OEM Settings Guide

Aggressive Android manufacturers (Xiaomi, Oppo, Vivo, Huawei, etc.) often kill background services to save battery. The plugin provides `openOemAutoStartSettings()` to help guide users to the correct settings pages.

## Handling OEMs

You should instruct your users to:
1. **Enable Autostart**: So the app can restart tracking after a device reboot.
2. **Disable Battery Optimization**: Set to "No restrictions".

## Known Intents Handled by `openOemAutoStartSettings()`

- **Xiaomi/Redmi/Poco**: `com.miui.securitycenter/com.miui.permcenter.autostart.AutoStartManagementActivity`
- **Oppo/Realme**: `com.coloros.safecenter/com.coloros.safecenter.startupapp.StartupAppListActivity`
- **Vivo**: `com.iqoo.secure/com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity`
- **Huawei/Honor**: `com.huawei.systemmanager/com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity`
- **Samsung**: Uses `ACTION_APPLICATION_DETAILS_SETTINGS` to guide users to the battery menu.

Always provide fallback UI in your Flutter app if the OEM intent fails to resolve.
