import 'package:flutter/foundation.dart';

/// Location permission levels.
enum LocationPermissionLevel {
  denied,
  whileInUse,
  always,
  restricted,
  permanentlyDenied,
}

/// Represents the current permission status of the device.
@immutable
class PermissionStatus {
  /// The granted location permission level.
  final LocationPermissionLevel location;
  
  /// Whether precise accuracy is granted.
  final bool preciseAccuracy;
  
  /// Whether notifications permission is granted.
  final bool notifications;
  
  /// Whether battery optimization is ignored (Android).
  final bool batteryOptimizationIgnored;
  
  /// Whether the system location service (GPS) is enabled.
  final bool locationServiceEnabled;

  /// Creates a new PermissionStatus.
  const PermissionStatus({
    required this.location,
    required this.preciseAccuracy,
    required this.notifications,
    required this.batteryOptimizationIgnored,
    required this.locationServiceEnabled,
  });

  /// True if background tracking can run reliably.
  bool get isReadyForBackground => 
      location == LocationPermissionLevel.always && 
      locationServiceEnabled;

  /// Creates a PermissionStatus from a map.
  factory PermissionStatus.fromMap(Map<dynamic, dynamic> map) {
    return PermissionStatus(
      location: LocationPermissionLevel.values.firstWhere(
        (e) => e.name == map['location'],
        orElse: () => LocationPermissionLevel.denied,
      ),
      preciseAccuracy: map['preciseAccuracy'] as bool? ?? false,
      notifications: map['notifications'] as bool? ?? false,
      batteryOptimizationIgnored: map['batteryOptimizationIgnored'] as bool? ?? false,
      locationServiceEnabled: map['locationServiceEnabled'] as bool? ?? false,
    );
  }

  @override
  String toString() {
    return 'PermissionStatus(location: $location, precise: $preciseAccuracy, locationService: $locationServiceEnabled, notifications: $notifications, batteryOptimized: ${!batteryOptimizationIgnored})';
  }
}
