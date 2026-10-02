import 'package:flutter/foundation.dart';
import 'notification_options.dart';

/// Storage options for the native SQLite database.
@immutable
class StorageOptions {
  /// Maximum number of points to store (oldest are deleted first).
  final int maxStoredPoints;
  
  /// Days to retain unsynced points before force deleting.
  final int retentionDays;
  
  /// Days to retain synced points before deleting.
  final int deleteSyncedAfterDays;

  const StorageOptions({
    this.maxStoredPoints = 50000,
    this.retentionDays = 30,
    this.deleteSyncedAfterDays = 7,
  });

  factory StorageOptions.fromMap(Map<dynamic, dynamic> map) {
    return StorageOptions(
      maxStoredPoints: map['maxStoredPoints'] as int? ?? 50000,
      retentionDays: map['retentionDays'] as int? ?? 30,
      deleteSyncedAfterDays: map['deleteSyncedAfterDays'] as int? ?? 7,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'maxStoredPoints': maxStoredPoints,
      'retentionDays': retentionDays,
      'deleteSyncedAfterDays': deleteSyncedAfterDays,
    };
  }
}

/// Global initialization options for the plugin.
@immutable
class TrackerOptions {
  /// Android Foreground Service notification options.
  final NotificationOptions notification;
  
  /// SQLite storage options.
  final StorageOptions storage;
  
  /// Whether to output debug logs in native code.
  final bool debugLogs;
  
  /// Whether tracking should automatically resume after a device reboot.
  final bool restartAfterBoot;
  
  /// Whether tracking should completely stop when the app is swiped from recents.
  /// If false (default), the service will attempt to continue running.
  final bool stopOnTerminate;

  const TrackerOptions({
    this.notification = const NotificationOptions(),
    this.storage = const StorageOptions(),
    this.debugLogs = false,
    this.restartAfterBoot = true,
    this.stopOnTerminate = false,
  });

  factory TrackerOptions.fromMap(Map<dynamic, dynamic> map) {
    return TrackerOptions(
      notification: map['notification'] != null 
          ? NotificationOptions.fromMap(map['notification'] as Map) 
          : const NotificationOptions(),
      storage: map['storage'] != null 
          ? StorageOptions.fromMap(map['storage'] as Map) 
          : const StorageOptions(),
      debugLogs: map['debugLogs'] as bool? ?? false,
      restartAfterBoot: map['restartAfterBoot'] as bool? ?? true,
      stopOnTerminate: map['stopOnTerminate'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notification': notification.toMap(),
      'storage': storage.toMap(),
      'debugLogs': debugLogs,
      'restartAfterBoot': restartAfterBoot,
      'stopOnTerminate': stopOnTerminate,
    };
  }
}
