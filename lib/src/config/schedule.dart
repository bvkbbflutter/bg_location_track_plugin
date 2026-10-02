import 'package:flutter/foundation.dart';
import 'tracking_config.dart';

/// Lightweight time of day representation.
@immutable
class TimeOfDayLite {
  final int hour;
  final int minute;

  const TimeOfDayLite({required this.hour, required this.minute})
      : assert(hour >= 0 && hour < 24),
        assert(minute >= 0 && minute < 60);

  factory TimeOfDayLite.fromMap(Map<dynamic, dynamic> map) {
    return TimeOfDayLite(
      hour: map['hour'] as int,
      minute: map['minute'] as int,
    );
  }

  Map<String, dynamic> toMap() => {'hour': hour, 'minute': minute};
}

/// A recurring window during which tracking should be active.
@immutable
class TrackingWindow {
  /// Days of the week (1=Monday, 7=Sunday) this window applies to.
  final Set<int> days;
  
  /// Start time.
  final TimeOfDayLite start;
  
  /// End time.
  final TimeOfDayLite end;
  
  /// Configuration to apply during this window.
  final TrackingConfig innerConfig;

  /// Optional start date for this window to be active.
  final DateTime? fromDate;

  /// Optional end date for this window to be active.
  final DateTime? toDate;

  /// Creates a new TrackingWindow.
  const TrackingWindow({
    required this.days,
    required this.start,
    required this.end,
    required this.innerConfig,
    this.fromDate,
    this.toDate,
  });

  /// Creates a TrackingWindow from a map.
  factory TrackingWindow.fromMap(Map<dynamic, dynamic> map) {
    return TrackingWindow(
      days: (map['days'] as List).map((e) => e as int).toSet(),
      start: TimeOfDayLite.fromMap(map['start'] as Map),
      end: TimeOfDayLite.fromMap(map['end'] as Map),
      innerConfig: TrackingConfig.fromMap(map['innerConfig'] as Map),
      fromDate: map['fromDate'] != null ? DateTime.tryParse(map['fromDate'] as String) : null,
      toDate: map['toDate'] != null ? DateTime.tryParse(map['toDate'] as String) : null,
    );
  }

  /// Converts to map.
  Map<String, dynamic> toMap() {
    return {
      'days': days.toList(),
      'start': start.toMap(),
      'end': end.toMap(),
      'innerConfig': innerConfig.toMap(),
      if (fromDate != null) 'fromDate': fromDate!.toIso8601String(),
      if (toDate != null) 'toDate': toDate!.toIso8601String(),
    };
  }
}
