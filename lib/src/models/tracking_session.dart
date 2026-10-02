import 'package:flutter/foundation.dart';

/// Represents a tracking session in the database.
@immutable
class TrackingSession {
  /// Session ID (UUID).
  final String id;
  
  /// User ID associated with this session.
  final String? userId;
  
  /// Start time of the session (UTC).
  final DateTime startedAt;
  
  /// End time of the session (UTC), null if still active.
  final DateTime? endedAt;
  
  /// Total points captured in this session.
  final int pointsCount;

  /// Creates a new TrackingSession.
  const TrackingSession({
    required this.id,
    this.userId,
    required this.startedAt,
    this.endedAt,
    this.pointsCount = 0,
  });

  /// Creates a TrackingSession from a map.
  factory TrackingSession.fromMap(Map<dynamic, dynamic> map) {
    return TrackingSession(
      id: map['id'] as String,
      userId: map['userId'] as String?,
      startedAt: DateTime.fromMillisecondsSinceEpoch(map['startedAt'] as int, isUtc: true),
      endedAt: map['endedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['endedAt'] as int, isUtc: true)
          : null,
      pointsCount: map['pointsCount'] as int? ?? 0,
    );
  }

  /// Converts the TrackingSession to a map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      if (userId != null) 'userId': userId,
      'startedAt': startedAt.millisecondsSinceEpoch,
      if (endedAt != null) 'endedAt': endedAt!.millisecondsSinceEpoch,
      'pointsCount': pointsCount,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackingSession && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'TrackingSession(id: $id, points: $pointsCount, active: ${endedAt == null})';
  }
}
