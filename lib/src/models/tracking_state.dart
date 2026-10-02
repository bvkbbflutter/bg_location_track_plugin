import 'package:flutter/foundation.dart';
import 'location_point.dart';

/// Status of the tracking session.
enum TrackingStatus {
  idle,
  running,
  paused,
  waitingForSchedule,
  permissionLost,
  gpsOff,
}

/// Represents the current tracking state.
@immutable
class TrackingState {
  /// Current tracking status.
  final TrackingStatus status;
  
  /// Active tracking mode name.
  final String? activeMode;
  
  /// Current session ID.
  final String? sessionId;
  
  /// Current shift ID.
  final String? shiftId;
  
  /// Timestamp when tracking started.
  final DateTime? startedAt;
  
  /// Last recorded location.
  final LocationPoint? lastLocation;
  
  /// Total points captured in current session.
  final int pointsCaptured;
  
  /// Total points pending upload across all sessions.
  final int pendingUpload;

  /// Creates a new TrackingState.
  const TrackingState({
    required this.status,
    this.activeMode,
    this.sessionId,
    this.shiftId,
    this.startedAt,
    this.lastLocation,
    this.pointsCaptured = 0,
    this.pendingUpload = 0,
  });

  /// Creates a TrackingState from a map.
  factory TrackingState.fromMap(Map<dynamic, dynamic> map) {
    return TrackingState(
      status: TrackingStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => TrackingStatus.idle,
      ),
      activeMode: map['activeMode'] as String?,
      sessionId: map['sessionId'] as String?,
      shiftId: map['shiftId'] as String?,
      startedAt: map['startedAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['startedAt'] as int, isUtc: true) 
          : null,
      lastLocation: map['lastLocation'] != null
          ? LocationPoint.fromMap(map['lastLocation'] as Map)
          : null,
      pointsCaptured: map['pointsCaptured'] as int? ?? 0,
      pendingUpload: map['pendingUpload'] as int? ?? 0,
    );
  }

  /// Converts the TrackingState to a map.
  Map<String, dynamic> toMap() {
    return {
      'status': status.name,
      if (activeMode != null) 'activeMode': activeMode,
      if (sessionId != null) 'sessionId': sessionId,
      if (shiftId != null) 'shiftId': shiftId,
      if (startedAt != null) 'startedAt': startedAt!.millisecondsSinceEpoch,
      if (lastLocation != null) 'lastLocation': lastLocation!.toMap(),
      'pointsCaptured': pointsCaptured,
      'pendingUpload': pendingUpload,
    };
  }

  /// Creates a copy of this TrackingState with the given fields replaced.
  TrackingState copyWith({
    TrackingStatus? status,
    String? activeMode,
    String? sessionId,
    String? shiftId,
    DateTime? startedAt,
    LocationPoint? lastLocation,
    int? pointsCaptured,
    int? pendingUpload,
  }) {
    return TrackingState(
      status: status ?? this.status,
      activeMode: activeMode ?? this.activeMode,
      sessionId: sessionId ?? this.sessionId,
      shiftId: shiftId ?? this.shiftId,
      startedAt: startedAt ?? this.startedAt,
      lastLocation: lastLocation ?? this.lastLocation,
      pointsCaptured: pointsCaptured ?? this.pointsCaptured,
      pendingUpload: pendingUpload ?? this.pendingUpload,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackingState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          activeMode == other.activeMode &&
          sessionId == other.sessionId &&
          shiftId == other.shiftId &&
          startedAt == other.startedAt &&
          lastLocation == other.lastLocation &&
          pointsCaptured == other.pointsCaptured &&
          pendingUpload == other.pendingUpload;

  @override
  int get hashCode =>
      status.hashCode ^
      activeMode.hashCode ^
      sessionId.hashCode ^
      shiftId.hashCode ^
      startedAt.hashCode ^
      lastLocation.hashCode ^
      pointsCaptured.hashCode ^
      pendingUpload.hashCode;

  @override
  String toString() {
    return 'TrackingState(status: $status, session: $sessionId, mode: $activeMode, points: $pointsCaptured, pending: $pendingUpload)';
  }
}
