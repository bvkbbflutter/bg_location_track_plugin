import 'dart:async';
import 'package:flutter/services.dart';

import '../bg_location_tracker.dart';
import 'channel/channel_names.dart';
import 'channel/method_names.dart';
import 'channel/event_types.dart';

/// Callback for handling permission rationale UI.
typedef PermissionRationaleCallback = Future<void> Function(String rationale);

/// The main entry point for the Background Location Tracker.
class BackgroundLocationTracker {
  BackgroundLocationTracker._();

  /// Singleton instance.
  static final BackgroundLocationTracker instance =
      BackgroundLocationTracker._();

  final MethodChannel _methodChannel =
      const MethodChannel(ChannelNames.methodChannel);
  final EventChannel _eventChannel =
      const EventChannel(ChannelNames.eventChannel);

  Stream<dynamic>? _eventStream;

  Stream<dynamic> get _events {
    _eventStream ??= _eventChannel.receiveBroadcastStream();
    return _eventStream!;
  }

  /// Initializes the tracker plugin and restores any persisted state.
  Future<bool> initialize(
      [TrackerOptions options = const TrackerOptions()]) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        MethodNames.initialize,
        options.toMap(),
      );
      return result ?? false;
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  // --- Permissions and Device Readiness ---

  /// Checks the current permission status.
  Future<PermissionStatus> checkPermissions() async {
    try {
      final map = await _methodChannel
          .invokeMapMethod<String, dynamic>(MethodNames.checkPermissions);
      return PermissionStatus.fromMap(map!);
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  /// Opens the OS Application Settings screen so the user can manually
  /// grant "Allow all the time" or disable Battery Saver.
  Future<bool> openAppSettings() async {
    return await _methodChannel.invokeMethod<bool>('openAppSettings') ?? false;
  }

  Future<PermissionStatus> requestPermissions({
    bool includeBackground = true,
    bool includeNotifications = true,
    PermissionRationaleCallback? onRationaleRequested,
  }) async {
    try {
      // Note: A complex plugin might invoke native to check rationale, call the callback, then continue.
      // For this API, we let native handle the OS-level rationale, but could expand.
      final map = await _methodChannel.invokeMapMethod<String, dynamic>(
        MethodNames.requestPermissions,
        {
          'includeBackground': includeBackground,
          'includeNotifications': includeNotifications,
        },
      );
      return PermissionStatus.fromMap(map!);
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  // Future<bool> openAppSettings() async {
  //   return await _methodChannel
  //           .invokeMethod<bool>(MethodNames.openAppSettings) ??
  //       false;
  // }

  Future<bool> openLocationSettings() async {
    return await _methodChannel
            .invokeMethod<bool>(MethodNames.openLocationSettings) ??
        false;
  }

  Future<bool> requestIgnoreBatteryOptimizations() async {
    return await _methodChannel.invokeMethod<bool>(
            MethodNames.requestIgnoreBatteryOptimizations) ??
        false;
  }

  Future<bool> openOemAutoStartSettings() async {
    return await _methodChannel
            .invokeMethod<bool>(MethodNames.openOemAutoStartSettings) ??
        false;
  }

  Future<Map<String, dynamic>> getDeviceInfoForTracking() async {
    final map = await _methodChannel
        .invokeMapMethod<String, dynamic>(MethodNames.getDeviceInfoForTracking);
    return map ?? {};
  }

  // --- Session Control ---

  /// Starts tracking with the provided configuration.
  Future<bool> start(TrackingConfig config) async {
    final status = await checkPermissions();
    if (status.location != LocationPermissionLevel.always) {
      throw TrackerException(
          code: 'PERMISSION_DENIED', 
          message: 'Background tracking requires "Allow all the time" location permission.');
    }
    if (!status.isReadyForBackground) {
      throw TrackerException(code: 'BACKGROUND_PERMISSION_DENIED', message: 'Background location permission is required for tracking.');
    }
    if (!status.notifications) {
      throw TrackerException(
          code: 'NOTIFICATION_PERMISSION_DENIED', 
          message: 'Notification permission is required for foreground service.');
    }

    try {
      return await _methodChannel.invokeMethod<bool>(
            MethodNames.start,
            config.toMap(),
          ) ??
          false;
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  /// Stops the current tracking session.
  Future<bool> stop({bool flushUpload = true}) async {
    try {
      return await _methodChannel.invokeMethod<bool>(
            MethodNames.stop,
            {'flushUpload': flushUpload},
          ) ??
          false;
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  Future<bool> pause() async {
    return await _methodChannel.invokeMethod<bool>(MethodNames.pause) ?? false;
  }

  Future<bool> resume() async {
    return await _methodChannel.invokeMethod<bool>(MethodNames.resume) ?? false;
  }

  Future<bool> isTracking() async {
    return await _methodChannel.invokeMethod<bool>(MethodNames.isTracking) ??
        false;
  }

  Future<TrackingState> getTrackingState() async {
    try {
      final map = await _methodChannel
          .invokeMapMethod<String, dynamic>(MethodNames.getTrackingState);
      return TrackingState.fromMap(map!);
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  Future<bool> updateConfig(TrackingConfig config) async {
    return await _methodChannel.invokeMethod<bool>(
            MethodNames.updateConfig, config.toMap()) ??
        false;
  }

  Future<bool> updateNotification(NotificationOptions options) async {
    return await _methodChannel.invokeMethod<bool>(
            MethodNames.updateNotification, options.toMap()) ??
        false;
  }

  Future<bool> updateExtras(Map<String, String> extras) async {
    return await _methodChannel.invokeMethod<bool>(
            MethodNames.updateExtras, extras) ??
        false;
  }

  // --- Convenience Tracking Modes ---

  Future<bool> startContinuous({
    int intervalSeconds = 10,
    int fastestIntervalSeconds = 5,
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) {
    return start(TrackingConfig(
      mode: TrackingMode.continuous,
      intervalSeconds: intervalSeconds,
      fastestIntervalSeconds: fastestIntervalSeconds,
      accuracy: accuracy,
    ));
  }

  Future<bool> startDistanceFilter({
    int minDistanceMeters = 200,
    int? heartbeatMinutes,
  }) {
    return start(TrackingConfig(
      mode: TrackingMode.distanceFilter,
      minDistanceMeters: minDistanceMeters,
      heartbeatMinutes: heartbeatMinutes,
    ));
  }

  Future<bool> startPeriodic({
    int intervalMinutes = 5,
    int fixTimeoutSeconds = 30,
  }) {
    return start(TrackingConfig(
      mode: TrackingMode.periodic,
      intervalSeconds: intervalMinutes * 60,
      fixTimeoutSeconds: fixTimeoutSeconds,
    ));
  }

  Future<bool> startScheduled(List<TrackingWindow> schedule) {
    return start(TrackingConfig(
      mode: TrackingMode.scheduled,
      schedule: schedule,
    ));
  }

  // --- Shifts ---

  Future<bool> startShift(Shift shift) async {
    return await scheduleShifts([shift]);
  }

  Future<bool> scheduleShifts(List<Shift> shifts) async {
    final list = shifts.map((e) => e.toMap()).toList();
    return await _methodChannel.invokeMethod<bool>(
            MethodNames.scheduleShifts, list) ??
        false;
  }

  Future<bool> cancelShift(String shiftId) async {
    return await _methodChannel.invokeMethod<bool>(
            MethodNames.cancelShift, {'shiftId': shiftId}) ??
        false;
  }

  Future<bool> endShift(String shiftId) async {
    return await cancelShift(shiftId);
  }

  Future<Shift?> getActiveShift() async {
    final map = await _methodChannel
        .invokeMapMethod<String, dynamic>(MethodNames.getActiveShift);
    if (map == null) return null;
    return Shift.fromMap(map);
  }

  Future<List<Shift>> listShifts() async {
    final list = await _methodChannel
        .invokeListMethod<Map<dynamic, dynamic>>(MethodNames.listShifts);
    return list?.map((e) => Shift.fromMap(e)).toList() ?? [];
  }

  // --- One-Shot / Force Capture ---

  Future<LocationPoint> getCurrentLocation({
    int timeoutSeconds = 15,
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    try {
      final map = await _methodChannel.invokeMapMethod<String, dynamic>(
        MethodNames.getCurrentLocation,
        {'timeoutSeconds': timeoutSeconds, 'accuracy': accuracy.name},
      );
      return LocationPoint.fromMap(map!);
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  Future<bool> captureNow({String? tag}) async {
    return await _methodChannel
            .invokeMethod<bool>(MethodNames.captureNow, {'tag': tag}) ??
        false;
  }

  // --- Data Access ---

  Future<List<LocationPoint>> getLocations({
    DateTime? from,
    DateTime? to,
    String? sessionId,
    String? shiftId,
    String? userId,
    bool? synced,
    int limit = 1000,
    int offset = 0,
    bool ascending = true,
  }) async {
    final args = {
      if (from != null) 'from': from.millisecondsSinceEpoch,
      if (to != null) 'to': to.millisecondsSinceEpoch,
      if (sessionId != null) 'sessionId': sessionId,
      if (shiftId != null) 'shiftId': shiftId,
      if (userId != null) 'userId': userId,
      if (synced != null) 'synced': synced,
      'limit': limit,
      'offset': offset,
      'ascending': ascending,
    };
    final list = await _methodChannel.invokeListMethod<Map<dynamic, dynamic>>(
        MethodNames.getLocations, args);
    return list?.map((e) => LocationPoint.fromMap(e)).toList() ?? [];
  }

  Future<LocationPoint?> getLastLocation() async {
    final map = await _methodChannel
        .invokeMapMethod<String, dynamic>(MethodNames.getLastLocation);
    if (map == null) return null;
    return LocationPoint.fromMap(map);
  }

  Future<int> getCount({
    DateTime? from,
    DateTime? to,
    String? sessionId,
    bool? synced,
  }) async {
    final args = {
      if (from != null) 'from': from.millisecondsSinceEpoch,
      if (to != null) 'to': to.millisecondsSinceEpoch,
      if (sessionId != null) 'sessionId': sessionId,
      if (synced != null) 'synced': synced,
    };
    return await _methodChannel.invokeMethod<int>(MethodNames.getCount, args) ??
        0;
  }

  Future<int> getPendingCount() async {
    return await _methodChannel
            .invokeMethod<int>(MethodNames.getPendingCount) ??
        0;
  }

  Future<int> deleteLocations({
    List<int>? ids,
    DateTime? before,
    String? sessionId,
  }) async {
    final args = {
      if (ids != null) 'ids': ids,
      if (before != null) 'before': before.millisecondsSinceEpoch,
      if (sessionId != null) 'sessionId': sessionId,
    };
    return await _methodChannel.invokeMethod<int>(
            MethodNames.deleteLocations, args) ??
        0;
  }

  Future<bool> clearAll() async {
    return await _methodChannel.invokeMethod<bool>(MethodNames.clearAll) ??
        false;
  }

  Future<List<TrackingSession>> getSessions() async {
    final list = await _methodChannel
        .invokeListMethod<Map<dynamic, dynamic>>(MethodNames.getSessions);
    return list?.map((e) => TrackingSession.fromMap(e)).toList() ?? [];
  }

  Future<List<TrackingEventLog>> getTrackingEventLog({int limit = 100}) async {
    final list = await _methodChannel.invokeListMethod<Map<dynamic, dynamic>>(
      MethodNames.getTrackingEventLog,
      {'limit': limit},
    );
    return list?.map((e) => TrackingEventLog.fromMap(e)).toList() ?? [];
  }

  Future<String> exportCsv(String sessionId) async {
    return await _methodChannel.invokeMethod<String>(
            MethodNames.exportCsv, {'sessionId': sessionId}) ??
        '';
  }

  Future<String> exportJson(String sessionId) async {
    return await _methodChannel.invokeMethod<String>(
            MethodNames.exportJson, {'sessionId': sessionId}) ??
        '';
  }

  // --- Sync / Upload ---

  Future<bool> configureUpload(UploadConfig config) async {
    try {
      return await _methodChannel.invokeMethod<bool>(
              MethodNames.configureUpload, config.toMap()) ??
          false;
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  Future<SyncResult> syncNow() async {
    try {
      final map = await _methodChannel
          .invokeMapMethod<String, dynamic>(MethodNames.syncNow);
      return SyncResult.fromMap(map!);
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  Future<bool> updateAuthToken(String token) async {
    return await _methodChannel.invokeMethod<bool>(
            MethodNames.updateAuthToken, {'token': token}) ??
        false;
  }

  Future<bool> clearUploadConfig() async {
    return await _methodChannel
            .invokeMethod<bool>(MethodNames.clearUploadConfig) ??
        false;
  }

  Future<SyncStatus> getSyncStatus() async {
    try {
      final map = await _methodChannel
          .invokeMapMethod<String, dynamic>(MethodNames.getSyncStatus);
      return SyncStatus.fromMap(map!);
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  Future<bool> pauseSync() async {
    return await _methodChannel.invokeMethod<bool>(MethodNames.pauseSync) ??
        false;
  }

  Future<bool> resumeSync() async {
    return await _methodChannel.invokeMethod<bool>(MethodNames.resumeSync) ??
        false;
  }

  // --- Diagnostics ---

  Future<Diagnostics> getDiagnostics() async {
    try {
      final map = await _methodChannel
          .invokeMapMethod<String, dynamic>(MethodNames.getDiagnostics);
      return Diagnostics.fromMap(map!);
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  // --- Streams ---

  Stream<LocationPoint> get locationStream {
    return _events
        .where((e) => e['type'] == EventTypes.location)
        .map((e) => LocationPoint.fromMap(e['data'] as Map));
  }

  Stream<TrackingState> get stateStream {
    return _events
        .where((e) => e['type'] == EventTypes.state)
        .map((e) => TrackingState.fromMap(e['data'] as Map));
  }

  Stream<PermissionStatus> get permissionStream {
    return _events
        .where((e) => e['type'] == EventTypes.permission)
        .map((e) => PermissionStatus.fromMap(e['data'] as Map));
  }

  Stream<Map<String, dynamic>> get providerStatusStream {
    return _events
        .where((e) => e['type'] == EventTypes.provider)
        .map((e) => Map<String, dynamic>.from(e['data'] as Map));
  }

  Stream<SyncStatus> get syncStream {
    return _events
        .where((e) => e['type'] == EventTypes.sync)
        .map((e) => SyncStatus.fromMap(e['data'] as Map));
  }

  Stream<Map<String, dynamic>> get geofenceStream {
    return _events
        .where((e) => e['type'] == EventTypes.geofence)
        .map((e) => Map<String, dynamic>.from(e['data'] as Map));
  }

  Stream<Shift> get shiftStream {
    return _events
        .where((e) => e['type'] == EventTypes.shift)
        .map((e) => Shift.fromMap(e['data'] as Map));
  }

  Stream<TrackingEventLog> get logStream {
    return _events
        .where((e) => e['type'] == EventTypes.log)
        .map((e) => TrackingEventLog.fromMap(e['data'] as Map));
  }

  Stream<TrackerException> get errorStream {
    return _events
        .where((e) => e['type'] == EventTypes.error)
        .map((e) => TrackerException(
              code: (e['data'] as Map)['code'] as String,
              message: (e['data'] as Map)['message'] as String,
              details: (e['data'] as Map)['details'],
            ));
  }

  // --- Internal ---

  TrackerException _handlePlatformException(PlatformException e) {
    return TrackerException(
      code: e.code,
      message: e.message ?? 'Unknown error',
      details: e.details,
    );
  }
}
