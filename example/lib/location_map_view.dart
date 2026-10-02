import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' as ll;

class LocationMapScreen extends StatefulWidget {
  /// Filtered server records from AppState.filteredLocations.
  /// (Sorted newest-first — this screen re-sorts chronologically.)
  final List<Map<String, dynamic>> locations;

  const LocationMapScreen({super.key, required this.locations});

  @override
  State<LocationMapScreen> createState() => _LocationMapScreenState();
}

class _LocationMapScreenState extends State<LocationMapScreen> {
  final MapController _mapController = MapController();

  late List<Map<String, dynamic>> _chronological;
  late TrackStats _stats;
  bool _showStats = false;

  /// Centre + zoom used for the initial camera.
  ll.LatLng _initialCenter = const ll.LatLng(0, 0);
  double _initialZoom = 2;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  // -------- parse helpers --------------------------------------------------

  DateTime? _parseTime(Map<String, dynamic> loc) {
    dynamic v = loc['timestamp'];
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is double) return DateTime.fromMillisecondsSinceEpoch(v.toInt());

    v = loc['timestampString'];
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  double? _num(dynamic v) => v == null ? null : double.tryParse(v.toString());

  String _formatTime(Map<String, dynamic> loc) {
    final dt = _parseTime(loc)?.toLocal();
    if (dt == null) return 'Unknown time';
    return DateFormat('MMM dd, yyyy - hh:mm:ss a').format(dt);
  }

  // -------- preparation ----------------------------------------------------

  void _prepare() {
    final valid = widget.locations.where((loc) {
      return _num(loc['latitude']) != null && _num(loc['longitude']) != null;
    }).toList();

    if (valid.isEmpty) return;

    valid.sort((a, b) {
      final ta = _parseTime(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = _parseTime(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return ta.compareTo(tb);
    });

    _chronological = valid;
    _stats = _computeStats(valid);

    final start = valid.first;
    _initialCenter = ll.LatLng(
      _num(start['latitude'])!,
      _num(start['longitude'])!,
    );
    _initialZoom = 15;
  }

  // Convenience — the polyline/marker LatLng list.
  List<ll.LatLng> get _latLngs => _chronological
      .map((loc) => ll.LatLng(_num(loc['latitude'])!, _num(loc['longitude'])!))
      .toList();

  // -------- stats ----------------------------------------------------------

  TrackStats _computeStats(List<Map<String, dynamic>> pts) {
    double totalMeters = 0;
    double maxSpeedMps = 0;
    double speedSumMps = 0;
    int speedSamples = 0;
    double accSum = 0;
    int accSamples = 0;
    double bestAcc = double.infinity;

    for (int i = 0; i < pts.length; i++) {
      final acc = _num(pts[i]['accuracy']);
      if (acc != null && acc > 0) {
        accSum += acc;
        accSamples++;
        if (acc < bestAcc) bestAcc = acc;
      }

      if (i == 0) continue;

      final a = pts[i - 1];
      final b = pts[i];

      final lat1 = _num(a['latitude'])!;
      final lng1 = _num(a['longitude'])!;
      final lat2 = _num(b['latitude'])!;
      final lng2 = _num(b['longitude'])!;

      final dist = _haversineMeters(lat1, lng1, lat2, lng2);
      totalMeters += dist;

      final t1 = _parseTime(a);
      final t2 = _parseTime(b);
      if (t1 != null && t2 != null) {
        final dtSec = t2.difference(t1).inMilliseconds / 1000.0;
        if (dtSec > 0.5) {
          final speed = dist / dtSec; // m/s
          speedSumMps += speed;
          speedSamples++;
          if (speed > maxSpeedMps) maxSpeedMps = speed;
        }
      }
    }

    final startTime = _parseTime(pts.first);
    final endTime = _parseTime(pts.last);
    final duration = (startTime != null && endTime != null)
        ? endTime.difference(startTime)
        : Duration.zero;

    final avgSpeedMps = speedSamples > 0 ? speedSumMps / speedSamples : 0.0;
    final avgAcc = accSamples > 0 ? accSum / accSamples : 0.0;

    return TrackStats(
      pointCount: pts.length,
      distanceMeters: totalMeters,
      duration: duration,
      startTime: startTime?.toLocal(),
      endTime: endTime?.toLocal(),
      avgSpeedMps: avgSpeedMps,
      maxSpeedMps: maxSpeedMps,
      avgAccuracyMeters: avgAcc,
      bestAccuracyMeters: bestAcc == double.infinity ? 0 : bestAcc,
    );
  }

  /// Great-circle distance between two lat/lng in metres.
  double _haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371000.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _deg2rad(double d) => d * math.pi / 180.0;

  // -------- camera ---------------------------------------------------------

  void _fitBounds() {
    if (_chronological.isEmpty) return;

    if (_chronological.length == 1) {
      _mapController.move(_latLngs.first, 16);
      return;
    }

    final latLngs = _latLngs;

    double minLat = latLngs.first.latitude;
    double maxLat = minLat;
    double minLng = latLngs.first.longitude;
    double maxLng = minLng;

    for (final p in latLngs) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }

    final bounds = LatLngBounds(
      ll.LatLng(minLat, minLng), // south-west
      ll.LatLng(maxLat, maxLng), // north-east
    );

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(64),
      ),
    );
  }

  // -------- build ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_chronological.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Locations Map')),
        body: const Center(child: Text('No valid locations to show.')),
      );
    }

    final start = _chronological.first;
    final end = _chronological.last;

    return Scaffold(
      appBar: AppBar(
        title: Text('Map (${_chronological.length} pts)'),
        actions: [
          IconButton(
            icon: Icon(_showStats ? Icons.map : Icons.info_outline),
            tooltip: _showStats ? 'Show Map' : 'Show Details',
            onPressed: () => setState(() => _showStats = !_showStats),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: _initialZoom,
              minZoom: 2,
              maxZoom: 19,
              onMapReady: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _fitBounds();
                });
              },
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              // ---- OpenStreetMap tile layer ----
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.bg_location_tracker_example',
                maxNativeZoom: 19,
              ),

              // ---- Track polyline (double layer for nicer look) ----
              if (_latLngs.length > 1) ...[
                // Subtle darker border under the main line
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _latLngs,
                      color: Colors.blue.shade900.withOpacity(0.35),
                      strokeWidth: 8,
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                  ],
                ),
                // Main bright polyline
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _latLngs,
                      color: Colors.blueAccent,
                      strokeWidth: 5.5,
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                  ],
                ),
              ],

              // ---- Start + End markers ----
              MarkerLayer(
                markers: [
                  // START – rich green
                  Marker(
                    point: ll.LatLng(
                      _num(start['latitude'])!,
                      _num(start['longitude'])!,
                    ),
                    width: 44,
                    height: 52,
                    alignment: Alignment.topCenter,
                    child: const _BeautifulPin(
                      color: Color(0xFF2E7D32),
                      letter: 'S',
                      tooltip: 'START',
                    ),
                  ),

                  // END – rich red (only when > 1 point)
                  if (_chronological.length > 1)
                    Marker(
                      point: ll.LatLng(
                        _num(end['latitude'])!,
                        _num(end['longitude'])!,
                      ),
                      width: 44,
                      height: 52,
                      alignment: Alignment.topCenter,
                      child: const _BeautifulPin(
                        color: Color(0xFFC62828),
                        letter: 'E',
                        tooltip: 'END',
                      ),
                    ),
                ],
              ),

              // ---- Attribution (required by OSM) ----
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                  ),
                ],
              ),
            ],
          ),

          // Fit-to-track button
          Positioned(
            top: 12,
            right: 12,
            child: FloatingActionButton.small(
              heroTag: 'fit',
              onPressed: _fitBounds,
              child: const Icon(Icons.center_focus_strong),
            ),
          ),

          // Stats overlay
          if (_showStats)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _StatsPanel(stats: _stats),
            ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Beautiful custom Start / End marker
// ===========================================================================

class _BeautifulPin extends StatelessWidget {
  final Color color;
  final String letter; // "S" or "E"
  final String tooltip;

  const _BeautifulPin({
    required this.color,
    required this.letter,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main circular badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.45),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
                const BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
              border: Border.all(color: Colors.white, width: 2.5),
            ),
            child: Center(
              child: Text(
                letter,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  height: 1.1,
                ),
              ),
            ),
          ),
          // Small triangle pointer under the circle
          CustomPaint(
            size: const Size(14, 8),
            painter: _TrianglePainter(color: color),
          ),
        ],
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ===========================================================================
// TrackStats + StatsPanel
// ===========================================================================

class TrackStats {
  final int pointCount;
  final double distanceMeters;
  final Duration duration;
  final DateTime? startTime;
  final DateTime? endTime;
  final double avgSpeedMps;
  final double maxSpeedMps;
  final double avgAccuracyMeters;
  final double bestAccuracyMeters;

  TrackStats({
    required this.pointCount,
    required this.distanceMeters,
    required this.duration,
    required this.startTime,
    required this.endTime,
    required this.avgSpeedMps,
    required this.maxSpeedMps,
    required this.avgAccuracyMeters,
    required this.bestAccuracyMeters,
  });

  String get distanceKm => (distanceMeters / 1000).toStringAsFixed(3);
  String get distanceMetersFormatted => distanceMeters.toStringAsFixed(0);

  String get avgSpeedKmh => (avgSpeedMps * 3.6).toStringAsFixed(1);
  String get maxSpeedKmh => (maxSpeedMps * 3.6).toStringAsFixed(1);

  String get durationFormatted {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    final s = duration.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

class _StatsPanel extends StatelessWidget {
  final TrackStats stats;
  const _StatsPanel({required this.stats});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM dd, HH:mm:ss');

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.route, color: Colors.blueAccent),
                const SizedBox(width: 8),
                Text('Track details',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            _row(Icons.straighten, 'Distance',
                '${stats.distanceKm} km (${stats.distanceMetersFormatted} m)'),
            _row(Icons.timer, 'Duration', stats.durationFormatted),
            _row(Icons.speed, 'Avg speed', '${stats.avgSpeedKmh} km/h'),
            _row(Icons.rocket_launch, 'Max speed', '${stats.maxSpeedKmh} km/h'),
            _row(Icons.pin_drop, 'Points', '${stats.pointCount}'),
            _row(Icons.gps_fixed, 'Best accuracy',
                '${stats.bestAccuracyMeters.toStringAsFixed(1)} m'),
            _row(Icons.gps_not_fixed, 'Avg accuracy',
                '${stats.avgAccuracyMeters.toStringAsFixed(1)} m'),
            const Divider(height: 20),
            _row(Icons.play_arrow_rounded, 'Start',
                stats.startTime == null ? '—' : fmt.format(stats.startTime!)),
            _row(Icons.stop_rounded, 'End',
                stats.endTime == null ? '—' : fmt.format(stats.endTime!)),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blueGrey),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(color: Colors.black54, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// import 'dart:math' as math;

// import 'package:flutter/material.dart';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:intl/intl.dart';
// import 'package:latlong2/latlong.dart' as ll;

// class LocationMapScreen extends StatefulWidget {
//   /// Filtered server records from AppState.filteredLocations.
//   /// (Sorted newest-first — this screen re-sorts chronologically.)
//   final List<Map<String, dynamic>> locations;

//   const LocationMapScreen({super.key, required this.locations});

//   @override
//   State<LocationMapScreen> createState() => _LocationMapScreenState();
// }

// class _LocationMapScreenState extends State<LocationMapScreen> {
//   final MapController _mapController = MapController();

//   late List<Map<String, dynamic>> _chronological;
//   late TrackStats _stats;
//   bool _showStats = false;

//   /// Centre + zoom used for the initial camera.  We update it after the
//   /// first layout pass via `_fitBounds()`.
//   ll.LatLng _initialCenter = const ll.LatLng(0, 0);
//   double _initialZoom = 2;

//   @override
//   void initState() {
//     super.initState();
//     _prepare();
//   }

//   @override
//   void dispose() {
//     _mapController.dispose();
//     super.dispose();
//   }

//   // -------- parse helpers --------------------------------------------------

//   DateTime? _parseTime(Map<String, dynamic> loc) {
//     dynamic v = loc['timestamp'];
//     if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
//     if (v is double) return DateTime.fromMillisecondsSinceEpoch(v.toInt());

//     v = loc['timestampString'];
//     if (v is String) return DateTime.tryParse(v);
//     return null;
//   }

//   double? _num(dynamic v) => v == null ? null : double.tryParse(v.toString());

//   String _formatTime(Map<String, dynamic> loc) {
//     final dt = _parseTime(loc)?.toLocal();
//     if (dt == null) return 'Unknown time';
//     return DateFormat('MMM dd, yyyy - hh:mm:ss a').format(dt);
//   }

//   // -------- preparation ----------------------------------------------------

//   void _prepare() {
//     final valid = widget.locations.where((loc) {
//       return _num(loc['latitude']) != null && _num(loc['longitude']) != null;
//     }).toList();

//     if (valid.isEmpty) return;

//     valid.sort((a, b) {
//       final ta = _parseTime(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
//       final tb = _parseTime(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
//       return ta.compareTo(tb);
//     });

//     _chronological = valid;
//     _stats = _computeStats(valid);

//     final start = valid.first;
//     _initialCenter = ll.LatLng(
//       _num(start['latitude'])!,
//       _num(start['longitude'])!,
//     );
//     _initialZoom = 15;
//   }

//   // Convenience — the polyline/marker LatLng list.
//   List<ll.LatLng> get _latLngs => _chronological
//       .map((loc) => ll.LatLng(_num(loc['latitude'])!, _num(loc['longitude'])!))
//       .toList();

//   // -------- stats ----------------------------------------------------------

//   TrackStats _computeStats(List<Map<String, dynamic>> pts) {
//     double totalMeters = 0;
//     double maxSpeedMps = 0;
//     double speedSumMps = 0;
//     int speedSamples = 0;
//     double accSum = 0;
//     int accSamples = 0;
//     double bestAcc = double.infinity;

//     for (int i = 0; i < pts.length; i++) {
//       final acc = _num(pts[i]['accuracy']);
//       if (acc != null && acc > 0) {
//         accSum += acc;
//         accSamples++;
//         if (acc < bestAcc) bestAcc = acc;
//       }

//       if (i == 0) continue;

//       final a = pts[i - 1];
//       final b = pts[i];

//       final lat1 = _num(a['latitude'])!;
//       final lng1 = _num(a['longitude'])!;
//       final lat2 = _num(b['latitude'])!;
//       final lng2 = _num(b['longitude'])!;

//       final dist = _haversineMeters(lat1, lng1, lat2, lng2);
//       totalMeters += dist;

//       final t1 = _parseTime(a);
//       final t2 = _parseTime(b);
//       if (t1 != null && t2 != null) {
//         final dtSec = t2.difference(t1).inMilliseconds / 1000.0;
//         if (dtSec > 0.5) {
//           final speed = dist / dtSec; // m/s
//           speedSumMps += speed;
//           speedSamples++;
//           if (speed > maxSpeedMps) maxSpeedMps = speed;
//         }
//       }
//     }

//     final startTime = _parseTime(pts.first);
//     final endTime = _parseTime(pts.last);
//     final duration = (startTime != null && endTime != null)
//         ? endTime.difference(startTime)
//         : Duration.zero;

//     final avgSpeedMps = speedSamples > 0 ? speedSumMps / speedSamples : 0.0;
//     final avgAcc = accSamples > 0 ? accSum / accSamples : 0.0;

//     return TrackStats(
//       pointCount: pts.length,
//       distanceMeters: totalMeters,
//       duration: duration,
//       startTime: startTime?.toLocal(),
//       endTime: endTime?.toLocal(),
//       avgSpeedMps: avgSpeedMps,
//       maxSpeedMps: maxSpeedMps,
//       avgAccuracyMeters: avgAcc,
//       bestAccuracyMeters: bestAcc == double.infinity ? 0 : bestAcc,
//     );
//   }

//   /// Great-circle distance between two lat/lng in metres.
//   double _haversineMeters(
//     double lat1,
//     double lon1,
//     double lat2,
//     double lon2,
//   ) {
//     const R = 6371000.0;
//     final dLat = _deg2rad(lat2 - lat1);
//     final dLon = _deg2rad(lon2 - lon1);
//     final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
//         math.cos(_deg2rad(lat1)) *
//             math.cos(_deg2rad(lat2)) *
//             math.sin(dLon / 2) *
//             math.sin(dLon / 2);
//     return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
//   }

//   double _deg2rad(double d) => d * math.pi / 180.0;

//   // -------- camera ---------------------------------------------------------

//   /// Fits the map to the whole track (mirrors the old `_fitBounds()`).
//   void _fitBounds() {
//     if (_chronological.isEmpty) return;

//     if (_chronological.length == 1) {
//       _mapController.move(_latLngs.first, 16);
//       return;
//     }

//     final latLngs = _latLngs;

//     double minLat = latLngs.first.latitude;
//     double maxLat = minLat;
//     double minLng = latLngs.first.longitude;
//     double maxLng = minLng;

//     for (final p in latLngs) {
//       minLat = math.min(minLat, p.latitude);
//       maxLat = math.max(maxLat, p.latitude);
//       minLng = math.min(minLng, p.longitude);
//       maxLng = math.max(maxLng, p.longitude);
//     }

//     final bounds = LatLngBounds(
//       ll.LatLng(minLat, minLng), // south-west
//       ll.LatLng(maxLat, maxLng), // north-east
//     );

//     _mapController.fitCamera(
//       CameraFit.bounds(
//         bounds: bounds,
//         padding: const EdgeInsets.all(64), // same 64px padding
//       ),
//     );
//   }

//   // -------- build ----------------------------------------------------------

//   @override
//   Widget build(BuildContext context) {
//     if (_chronological.isEmpty) {
//       return Scaffold(
//         appBar: AppBar(title: const Text('Locations Map')),
//         body: const Center(child: Text('No valid locations to show.')),
//       );
//     }

//     final start = _chronological.first;
//     final end = _chronological.last;

//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Map (${_chronological.length} pts)'),
//         actions: [
//           IconButton(
//             icon: Icon(_showStats ? Icons.map : Icons.info_outline),
//             tooltip: _showStats ? 'Show Map' : 'Show Details',
//             onPressed: () => setState(() => _showStats = !_showStats),
//           ),
//         ],
//       ),
//       body: Stack(
//         children: [
//           FlutterMap(
//             mapController: _mapController,
//             options: MapOptions(
//               initialCenter: _initialCenter,
//               initialZoom: _initialZoom,
//               minZoom: 2,
//               maxZoom: 19,
//               // After the first layout, fit the whole track.
//               onMapReady: () {
//                 WidgetsBinding.instance.addPostFrameCallback((_) {
//                   _fitBounds();
//                 });
//               },
//               interactionOptions: const InteractionOptions(
//                 flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
//               ),
//             ),
//             children: [
//               // ---- OpenStreetMap tile layer (free, no key) ----
//               TileLayer(
//                 urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
//                 userAgentPackageName: 'com.example.bg_location_tracker_example',
//                 maxNativeZoom: 19,
//               ),

//               // ---- Track polyline ----
//               if (_latLngs.length > 1)
//                 PolylineLayer(
//                   polylines: [
//                     Polyline(
//                       points: _latLngs,
//                       color: Colors.blueAccent,
//                       strokeWidth: 5,
//                       strokeCap: StrokeCap.round,
//                       strokeJoin: StrokeJoin.round,
//                     ),
//                   ],
//                 ),

//               // ---- Start + End markers ----
//               MarkerLayer(
//                 markers: [
//                   // START (green)
//                   Marker(
//                     point: ll.LatLng(
//                       _num(start['latitude'])!,
//                       _num(start['longitude'])!,
//                     ),
//                     width: 40,
//                     height: 40,
//                     alignment: Alignment.topCenter,
//                     child: const _Pin(
//                       color: Colors.green,
//                       label: 'START',
//                     ),
//                   ),
//                   // END (red) — only if more than one point
//                   if (_chronological.length > 1)
//                     Marker(
//                       point: ll.LatLng(
//                         _num(end['latitude'])!,
//                         _num(end['longitude'])!,
//                       ),
//                       width: 40,
//                       height: 40,
//                       alignment: Alignment.topCenter,
//                       child: const _Pin(
//                         color: Colors.red,
//                         label: 'END',
//                       ),
//                     ),
//                 ],
//               ),

//               // ---- Attribution (required by OSM) ----
//               const RichAttributionWidget(
//                 attributions: [
//                   TextSourceAttribution(
//                     'OpenStreetMap contributors',
//                   ),
//                 ],
//               ),
//             ],
//           ),

//           // Fit-to-track button
//           Positioned(
//             top: 12,
//             right: 12,
//             child: FloatingActionButton.small(
//               heroTag: 'fit',
//               onPressed: _fitBounds,
//               child: const Icon(Icons.center_focus_strong),
//             ),
//           ),

//           // Stats overlay
//           if (_showStats)
//             Positioned(
//               left: 0,
//               right: 0,
//               bottom: 0,
//               child: _StatsPanel(stats: _stats),
//             ),
//         ],
//       ),
//     );
//   }
// }

// // ===========================================================================
// // Custom marker pin (matches the Flutter look)
// // ===========================================================================

// class _Pin extends StatelessWidget {
//   final Color color;
//   final String label;
//   const _Pin({required this.color, required this.label});

//   @override
//   Widget build(BuildContext context) {
//     return Tooltip(
//       message: label,
//       child: Icon(
//         Icons.location_on,
//         color: color,
//         size: 40,
//         shadows: const [
//           Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
//         ],
//       ),
//     );
//   }
// }

// // ===========================================================================
// // TrackStats + StatsPanel  (unchanged from your original)
// // ===========================================================================

// class TrackStats {
//   final int pointCount;
//   final double distanceMeters;
//   final Duration duration;
//   final DateTime? startTime;
//   final DateTime? endTime;
//   final double avgSpeedMps;
//   final double maxSpeedMps;
//   final double avgAccuracyMeters;
//   final double bestAccuracyMeters;

//   TrackStats({
//     required this.pointCount,
//     required this.distanceMeters,
//     required this.duration,
//     required this.startTime,
//     required this.endTime,
//     required this.avgSpeedMps,
//     required this.maxSpeedMps,
//     required this.avgAccuracyMeters,
//     required this.bestAccuracyMeters,
//   });

//   String get distanceKm => (distanceMeters / 1000).toStringAsFixed(3);
//   String get distanceMetersFormatted => distanceMeters.toStringAsFixed(0);

//   String get avgSpeedKmh => (avgSpeedMps * 3.6).toStringAsFixed(1);
//   String get maxSpeedKmh => (maxSpeedMps * 3.6).toStringAsFixed(1);

//   String get durationFormatted {
//     final h = duration.inHours;
//     final m = duration.inMinutes.remainder(60);
//     final s = duration.inSeconds.remainder(60);
//     if (h > 0) return '${h}h ${m}m ${s}s';
//     if (m > 0) return '${m}m ${s}s';
//     return '${s}s';
//   }
// }

// class _StatsPanel extends StatelessWidget {
//   final TrackStats stats;
//   const _StatsPanel({required this.stats});

//   @override
//   Widget build(BuildContext context) {
//     final fmt = DateFormat('MMM dd, HH:mm:ss');

//     return SafeArea(
//       top: false,
//       child: Container(
//         margin: const EdgeInsets.all(12),
//         padding: const EdgeInsets.all(16),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(16),
//           boxShadow: const [
//             BoxShadow(
//               color: Colors.black26,
//               blurRadius: 12,
//               offset: Offset(0, 4),
//             ),
//           ],
//         ),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 const Icon(Icons.route, color: Colors.blueAccent),
//                 const SizedBox(width: 8),
//                 Text('Track details',
//                     style: Theme.of(context).textTheme.titleMedium),
//               ],
//             ),
//             const SizedBox(height: 12),
//             _row(Icons.straighten, 'Distance',
//                 '${stats.distanceKm} km (${stats.distanceMetersFormatted} m)'),
//             _row(Icons.timer, 'Duration', stats.durationFormatted),
//             _row(Icons.speed, 'Avg speed', '${stats.avgSpeedKmh} km/h'),
//             _row(Icons.rocket_launch, 'Max speed', '${stats.maxSpeedKmh} km/h'),
//             _row(Icons.pin_drop, 'Points', '${stats.pointCount}'),
//             _row(Icons.gps_fixed, 'Best accuracy',
//                 '${stats.bestAccuracyMeters.toStringAsFixed(1)} m'),
//             _row(Icons.gps_not_fixed, 'Avg accuracy',
//                 '${stats.avgAccuracyMeters.toStringAsFixed(1)} m'),
//             const Divider(height: 20),
//             _row(Icons.play_arrow_rounded, 'Start',
//                 stats.startTime == null ? '—' : fmt.format(stats.startTime!)),
//             _row(Icons.stop_rounded, 'End',
//                 stats.endTime == null ? '—' : fmt.format(stats.endTime!)),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _row(IconData icon, String label, String value) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 3),
//       child: Row(
//         children: [
//           Icon(icon, size: 18, color: Colors.blueGrey),
//           const SizedBox(width: 8),
//           SizedBox(
//             width: 110,
//             child: Text(label,
//                 style: const TextStyle(color: Colors.black54, fontSize: 13)),
//           ),
//           Expanded(
//             child: Text(
//               value,
//               style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
