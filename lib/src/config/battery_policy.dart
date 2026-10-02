import 'package:flutter/foundation.dart';

/// Actions to take when battery level drops.
enum LowBatteryAction {
  /// Degrade accuracy and interval to save battery.
  degrade,
  /// Pause tracking entirely until battery recovers.
  pause,
  /// Ignore battery constraints and continue tracking.
  continueTracking,
}

/// Defines how tracking behaves under different battery conditions.
@immutable
class BatteryPolicy {
  /// Battery percentage threshold to consider "low" (e.g. 15.0).
  final double lowBatteryPercent;
  
  /// Battery percentage threshold to consider "critical" (e.g. 5.0).
  final double criticalBatteryPercent;
  
  /// Action to take when battery drops below [lowBatteryPercent].
  final LowBatteryAction onLow;
  
  /// Action to take when battery drops below [criticalBatteryPercent].
  final LowBatteryAction onCritical;
  
  /// Whether to respect the system's battery saver mode.
  final bool respectBatterySaver;
  
  /// Whether to automatically resume tracking when connected to power.
  final bool resumeWhenCharging;

  /// Creates a new BatteryPolicy.
  const BatteryPolicy({
    this.lowBatteryPercent = 15.0,
    this.criticalBatteryPercent = 5.0,
    this.onLow = LowBatteryAction.degrade,
    this.onCritical = LowBatteryAction.pause,
    this.respectBatterySaver = true,
    this.resumeWhenCharging = true,
  });

  /// Creates a BatteryPolicy from a map.
  factory BatteryPolicy.fromMap(Map<dynamic, dynamic> map) {
    return BatteryPolicy(
      lowBatteryPercent: (map['lowBatteryPercent'] as num?)?.toDouble() ?? 15.0,
      criticalBatteryPercent: (map['criticalBatteryPercent'] as num?)?.toDouble() ?? 5.0,
      onLow: LowBatteryAction.values.firstWhere(
        (e) => e.name == map['onLow'],
        orElse: () => LowBatteryAction.degrade,
      ),
      onCritical: LowBatteryAction.values.firstWhere(
        (e) => e.name == map['onCritical'],
        orElse: () => LowBatteryAction.pause,
      ),
      respectBatterySaver: map['respectBatterySaver'] as bool? ?? true,
      resumeWhenCharging: map['resumeWhenCharging'] as bool? ?? true,
    );
  }

  /// Converts to map.
  Map<String, dynamic> toMap() {
    return {
      'lowBatteryPercent': lowBatteryPercent,
      'criticalBatteryPercent': criticalBatteryPercent,
      'onLow': onLow.name,
      'onCritical': onCritical.name,
      'respectBatterySaver': respectBatterySaver,
      'resumeWhenCharging': resumeWhenCharging,
    };
  }
}
