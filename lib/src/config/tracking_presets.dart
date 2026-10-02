import 'tracking_config.dart';
import 'tracking_mode.dart';
import 'battery_policy.dart';

/// Pre-configured TrackingConfigs for common use cases.
class TrackingPresets {
  /// High accuracy continuous tracking (e.g., Turn-by-turn navigation).
  /// Captures a point every 5-10 seconds. Highly battery intensive.
  static TrackingConfig get highAccuracy => const TrackingConfig(
        mode: TrackingMode.continuous,
        accuracy: LocationAccuracy.high,
        intervalSeconds: 10,
        fastestIntervalSeconds: 5,
        minAccuracyMeters: 50,
        detectStops: true,
      );

  /// Standard walking configuration.
  /// Distance-based, updates every 25 meters, balanced accuracy.
  static TrackingConfig get walking => const TrackingConfig(
        mode: TrackingMode.distanceFilter,
        accuracy: LocationAccuracy.high,
        minDistanceMeters: 25,
        heartbeatMinutes: 5,
        minAccuracyMeters: 100,
      );

  /// Cycling configuration.
  /// Distance-based, updates every 50 meters.
  static TrackingConfig get cycling => const TrackingConfig(
        mode: TrackingMode.distanceFilter,
        accuracy: LocationAccuracy.high,
        minDistanceMeters: 50,
        heartbeatMinutes: 10,
        minAccuracyMeters: 100,
      );

  /// Driving configuration.
  /// Distance-based, updates every 200 meters.
  static TrackingConfig get driving => const TrackingConfig(
        mode: TrackingMode.distanceFilter,
        accuracy: LocationAccuracy.balanced,
        minDistanceMeters: 200,
        heartbeatMinutes: 15,
        minAccuracyMeters: 200,
      );

  /// Delivery / Field Sales configuration.
  /// Adaptive motion-aware, scales interval with speed.
  static TrackingConfig get fieldSales => const TrackingConfig(
        mode: TrackingMode.adaptive,
        accuracy: LocationAccuracy.balanced,
        detectStops: true,
        stopRadiusMeters: 100,
        stopMinDurationSeconds: 300, // 5 minutes
      );

  /// Extreme battery saver.
  /// Significant changes only, network-based, lowest impact.
  static TrackingConfig get batterySaver => const TrackingConfig(
        mode: TrackingMode.significantChanges,
        accuracy: LocationAccuracy.low,
        minAccuracyMeters: 1000,
        batteryPolicy: BatteryPolicy(
          onLow: LowBatteryAction.pause,
          onCritical: LowBatteryAction.pause,
        ),
      );
}
