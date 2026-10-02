import 'package:flutter/foundation.dart';

/// Represents a tracking audit event log.
@immutable
class TrackingEventLog {
  /// Internal DB ID.
  final int? id;
  
  /// Timestamp of the event (UTC).
  final DateTime timestamp;
  
  /// Type of event (e.g. started, stopped, permission_revoked, gps_off, watchdog_restart).
  final String eventType;
  
  /// Optional details or context about the event.
  final String? details;

  /// Creates a new TrackingEventLog.
  const TrackingEventLog({
    this.id,
    required this.timestamp,
    required this.eventType,
    this.details,
  });

  /// Creates a TrackingEventLog from a map.
  factory TrackingEventLog.fromMap(Map<dynamic, dynamic> map) {
    return TrackingEventLog(
      id: map['id'] as int?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int, isUtc: true),
      eventType: map['eventType'] as String,
      details: map['details'] as String?,
    );
  }

  /// Converts to map.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'eventType': eventType,
      if (details != null) 'details': details,
    };
  }
}
