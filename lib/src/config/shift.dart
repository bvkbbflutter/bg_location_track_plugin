import 'package:flutter/foundation.dart';
import 'tracking_config.dart';

/// Represents a specific, non-recurring time period for tracking (e.g. a worker's shift).
@immutable
class Shift {
  /// Unique identifier for this shift.
  final String id;
  
  /// Human-readable name.
  final String? name;
  
  /// When the shift starts (UTC).
  final DateTime startAt;
  
  /// When the shift ends (UTC).
  final DateTime endAt;
  
  /// Tracking configuration applied during this shift.
  final TrackingConfig config;
  
  /// Whether tracking should start automatically at [startAt].
  final bool autoStart;
  
  /// Whether tracking should end automatically at [endAt].
  final bool autoEnd;
  
  /// Grace period in minutes after [endAt] before forcing stop.
  final int graceMinutes;
  
  /// Additional metadata.
  final Map<String, String>? metadata;

  /// Creates a new Shift.
  const Shift({
    required this.id,
    this.name,
    required this.startAt,
    required this.endAt,
    required this.config,
    this.autoStart = true,
    this.autoEnd = true,
    this.graceMinutes = 0,
    this.metadata,
  });

  /// Creates a Shift from a map.
  factory Shift.fromMap(Map<dynamic, dynamic> map) {
    return Shift(
      id: map['id'] as String,
      name: map['name'] as String?,
      startAt: DateTime.fromMillisecondsSinceEpoch(map['startAt'] as int, isUtc: true),
      endAt: DateTime.fromMillisecondsSinceEpoch(map['endAt'] as int, isUtc: true),
      config: TrackingConfig.fromMap(map['config'] as Map),
      autoStart: map['autoStart'] as bool? ?? true,
      autoEnd: map['autoEnd'] as bool? ?? true,
      graceMinutes: map['graceMinutes'] as int? ?? 0,
      metadata: (map['metadata'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())),
    );
  }

  /// Converts to map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      if (name != null) 'name': name,
      'startAt': startAt.millisecondsSinceEpoch,
      'endAt': endAt.millisecondsSinceEpoch,
      'config': config.toMap(),
      'autoStart': autoStart,
      'autoEnd': autoEnd,
      'graceMinutes': graceMinutes,
      if (metadata != null) 'metadata': metadata,
    };
  }
}
