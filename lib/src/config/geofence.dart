import 'package:flutter/foundation.dart';

/// Represents a circular geofence.
@immutable
class Geofence {
  /// Unique identifier for this geofence.
  final String id;
  
  /// Latitude in degrees.
  final double latitude;
  
  /// Longitude in degrees.
  final double longitude;
  
  /// Radius in meters.
  final double radiusMeters;
  
  /// Dwell time in seconds before triggering 'enter' event (Android only).
  final int dwellTimeSeconds;

  /// Creates a new Geofence.
  const Geofence({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.dwellTimeSeconds = 0,
  });

  /// Creates a Geofence from a map.
  factory Geofence.fromMap(Map<dynamic, dynamic> map) {
    return Geofence(
      id: map['id'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      radiusMeters: (map['radiusMeters'] as num).toDouble(),
      dwellTimeSeconds: map['dwellTimeSeconds'] as int? ?? 0,
    );
  }

  /// Converts to map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'radiusMeters': radiusMeters,
      'dwellTimeSeconds': dwellTimeSeconds,
    };
  }
}
