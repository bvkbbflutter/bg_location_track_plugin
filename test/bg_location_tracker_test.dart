import 'package:flutter_test/flutter_test.dart';
import 'package:bg_location_tracker/bg_location_tracker.dart';

void main() {
  group('Model Serialization', () {
    test('LocationPoint serialization round-trip', () {
      final point = LocationPoint(
        id: 1,
        uuid: 'test-uuid',
        latitude: 37.7749,
        longitude: -122.4194,
        accuracy: 10.5,
        speed: 1.2,
        timestamp: DateTime.utc(2023, 10, 1),
        isMock: true,
      );

      final map = point.toMap();
      final restored = LocationPoint.fromMap(map);

      expect(restored.uuid, point.uuid);
      expect(restored.latitude, point.latitude);
      expect(restored.longitude, point.longitude);
      expect(restored.accuracy, point.accuracy);
      expect(restored.speed, point.speed);
      expect(restored.timestamp, point.timestamp);
      expect(restored.isMock, point.isMock);
    });

    test('TrackingConfig serialization round-trip', () {
      const config = TrackingConfig(
        mode: TrackingMode.distanceFilter,
        accuracy: LocationAccuracy.high,
        minDistanceMeters: 50,
        heartbeatMinutes: 10,
        detectStops: true,
        stopRadiusMeters: 100,
        stopMinDurationSeconds: 300,
      );

      final map = config.toMap();
      final restored = TrackingConfig.fromMap(map);

      expect(restored.mode, config.mode);
      expect(restored.accuracy, config.accuracy);
      expect(restored.minDistanceMeters, config.minDistanceMeters);
      expect(restored.heartbeatMinutes, config.heartbeatMinutes);
      expect(restored.detectStops, config.detectStops);
      expect(restored.stopRadiusMeters, config.stopRadiusMeters);
      expect(restored.stopMinDurationSeconds, config.stopMinDurationSeconds);
    });
  });

  group('GeoUtils', () {
    test('distanceBetween calculates correctly', () {
      // SF to LA
      final dist =
          GeoUtils.distanceBetween(37.7749, -122.4194, 34.0522, -118.2437);
      // Roughly 559 km
      expect(dist, closeTo(559000, 2000));
    });
  });
}
