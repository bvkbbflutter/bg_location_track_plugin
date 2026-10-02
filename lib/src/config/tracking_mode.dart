/// Predefined tracking modes.
enum TrackingMode {
  continuous,
  distanceFilter,
  periodic,
  scheduled,
  shift,
  hybrid,
  adaptive,
  geofenceTriggered,
  significantChanges,
  batterySaver,
}

/// Accuracy options for location updates.
enum LocationAccuracy {
  /// Highest possible accuracy (GPS).
  high,
  /// Balanced power and accuracy (Network/Wi-Fi).
  balanced,
  /// Low power (City level).
  low,
  /// Passive (only listen to updates requested by other apps).
  passive,
}
