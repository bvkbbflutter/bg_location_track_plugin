import 'dart:math' as math;
import '../models/location_point.dart';

/// Geo utility functions.
class GeoUtils {
  static const double _earthRadiusMeters = 6371000;

  /// Calculates the Haversine distance in meters between two coordinates.
  static double distanceBetween(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
        
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusMeters * c;
  }

  static double _toRadians(double degrees) {
    return degrees * math.pi / 180.0;
  }

  /// Simplifies a polyline using the Douglas-Peucker algorithm.
  /// [points] must be ordered by timestamp.
  /// [toleranceMeters] determines the simplification aggressiveness.
  static List<LocationPoint> simplifyPolyline(
    List<LocationPoint> points, {
    double toleranceMeters = 10.0,
  }) {
    if (points.length <= 2) return points;

    double maxDistance = 0.0;
    int index = 0;

    final end = points.length - 1;
    for (int i = 1; i < end; i++) {
      final d = _perpendicularDistance(points[i], points[0], points[end]);
      if (d > maxDistance) {
        index = i;
        maxDistance = d;
      }
    }

    if (maxDistance > toleranceMeters) {
      final left = simplifyPolyline(points.sublist(0, index + 1), toleranceMeters: toleranceMeters);
      final right = simplifyPolyline(points.sublist(index), toleranceMeters: toleranceMeters);
      return [...left.sublist(0, left.length - 1), ...right];
    } else {
      return [points[0], points[end]];
    }
  }

  static double _perpendicularDistance(LocationPoint p, LocationPoint a, LocationPoint b) {
    final area = ((a.latitude - p.latitude) * (b.longitude - p.longitude) -
                 (a.longitude - p.longitude) * (b.latitude - p.latitude)).abs();
    
    final base = math.sqrt(
      math.pow(a.latitude - b.latitude, 2) + 
      math.pow(a.longitude - b.longitude, 2)
    );
    
    // Approximate conversion back to meters for tolerance comparison
    // This is a rough estimation suitable for small distances
    final degreesDist = base == 0 ? 0.0 : area / base;
    return degreesDist * 111320.0; // Approx meters per degree at equator
  }
}
