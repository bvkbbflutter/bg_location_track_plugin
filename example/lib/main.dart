import 'dart:async';
import 'dart:convert';

import 'package:bg_location_tracker/bg_location_tracker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'location_map_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _appState.init();
  runApp(const MyApp());
}

/// Reads a point's time from a server record.
///
/// The native uploader sends:
///   timestamp        -> epoch milliseconds (int)
///   timestampString  -> UTC ISO-8601
///   timestampLocal   -> device-local ISO-8601 with offset
DateTime? parseLocationTime(Map<String, dynamic> loc) {
  DateTime? fromValue(dynamic value) {
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is double) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  return fromValue(loc['timestamp']) ?? fromValue(loc['timestampString']);
}

/// Upload settings shared by every login scenario.
///
/// Native sends up to [batchSize] points per request as
/// `{ "userId": ..., "locations": [ ... ] }` to `/locations/bulk`,
/// flushing what has queued up every [syncIntervalSeconds].
const Map<String, dynamic> _bulkUploadConfig = {
  'headers': {'Authorization': 'Bearer fake_token_123'},
  'batchSize': 20,
  'syncIntervalSeconds': 120,
};

class AppState extends ChangeNotifier {
  bool isLoggedIn = false;
  String loginMode = '';
  String loginJsonConfig = '';
  TrackingState trackingState =
      const TrackingState(status: TrackingStatus.idle);
  PermissionStatus? permissions;
  List<LocationPoint> currentLocations = [];
  List<Map<String, dynamic>> serverLocations = [];

  String serverIp = 'https://bg-location-track-render.onrender.com';
  String currentUserId = 'user123';
  String get baseUrl {
    if (serverIp.startsWith('http://') || serverIp.startsWith('https://')) {
      return serverIp;
    }
    return 'http://$serverIp:3000';
  }

  late SharedPreferences _prefs;

  String selectedDateFilter = 'Today'; // Today, Week, Month, All
  String selectedUserFilter = 'All Users';

  StreamSubscription<LocationPoint>? _locationSub;
  StreamSubscription<TrackingState>? _stateSub;
  Timer? _refreshTimer;
  int _lastPending = 0;

  AppState();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    serverIp = _prefs.getString('serverIp') ?? serverIp;
    currentUserId = _prefs.getString('currentUserId') ?? 'user123';
    isLoggedIn = _prefs.getBool('isLoggedInBg') ?? false;
    loginMode = _prefs.getString('loginMode') ?? '';
    loginJsonConfig = _prefs.getString('loginJsonConfig') ?? '';

    // 1. Initialize the native plugin (global notification settings, logs).
    await BackgroundLocationTracker.instance.initialize(
      const TrackerOptions(
        notification: NotificationOptions(
          title: 'Field Tracking',
          text: 'Recording location securely',
          showStopAction: true,
        ),
        debugLogs: true,
      ),
    );

    permissions = await BackgroundLocationTracker.instance.checkPermissions();
    trackingState = await BackgroundLocationTracker.instance.getTrackingState();
    _lastPending = trackingState.pendingUpload;

    // If the native side is already tracking, make sure the UI reflects it.
    if (trackingState.status != TrackingStatus.idle) {
      isLoggedIn = true;
    }

    if (isLoggedIn) {
      _listenToStreams();
      await fetchServerData();
    }

    notifyListeners();
  }

  List<String> get availableUsers {
    final users = serverLocations
        .map((loc) => loc['userId']?.toString() ?? 'Unknown')
        .toSet()
        .toList();
    return ['All Users', ...users];
  }

  void updateDateFilter(String filter) {
    selectedDateFilter = filter;
    notifyListeners();
  }

  void updateUserFilter(String user) {
    selectedUserFilter = user;
    notifyListeners();
  }

  /// Server records after applying the user + date filters,
  /// newest first. Computed on each call, so read it once per build.
  List<Map<String, dynamic>> get filteredLocations {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfToday.subtract(Duration(days: now.weekday - 1));
    final startOfMonth = DateTime(now.year, now.month, 1);

    final entries = <(Map<String, dynamic>, DateTime)>[];

    for (final loc in serverLocations) {
      if (selectedUserFilter != 'All Users') {
        final locUser = loc['userId']?.toString() ?? 'Unknown';
        if (locUser != selectedUserFilter) continue;
      }

      final dt = parseLocationTime(loc)?.toLocal();
      if (dt == null) continue;

      final keep = switch (selectedDateFilter) {
        'Today' =>
          dt.year == now.year && dt.month == now.month && dt.day == now.day,
        'Week' => !dt.isBefore(startOfWeek),
        'Month' => !dt.isBefore(startOfMonth),
        _ => true, // All
      };

      if (keep) entries.add((loc, dt));
    }

    entries.sort((a, b) => b.$2.compareTo(a.$2));

    return [for (final entry in entries) entry.$1];
  }

  // Future<void> loginWithJsonConfig(
  //   String modeTitle,
  //   Map<String, dynamic> jsonResponse,
  // ) async {
  //   try {
  //     // 1. Save IP & user id & mode.
  //     await _prefs.setString('serverIp', serverIp);
  //     await _prefs.setString('currentUserId', currentUserId);
  //     await _prefs.setString('loginMode', modeTitle);
  //     loginMode = modeTitle;

  //     // 2. Simulated login response. Your real backend returns the
  //     //    TrackingConfig + UploadConfig structure.
  //     final configMap = jsonResponse['tracking_config'] as Map<String, dynamic>;
  //     final uploadMap = jsonResponse['upload_config'] as Map<String, dynamic>;

  //     // 3. Request permissions explicitly during login.
  //     final locLevel = permissions?.location;
  //     if (locLevel != LocationPermissionLevel.always ||
  //         permissions?.isReadyForBackground == false ||
  //         permissions?.locationServiceEnabled == false ||
  //         permissions?.notifications == false) {
  //       permissions =
  //           await BackgroundLocationTracker.instance.requestPermissions();

  //       final newLocLevel = permissions?.location;
  //       if (newLocLevel != LocationPermissionLevel.always ||
  //           permissions?.isReadyForBackground == false ||
  //           permissions?.locationServiceEnabled == false ||
  //           permissions?.notifications == false) {
  //         debugPrint(
  //             'Required permissions not granted. Cannot login/start tracking.');
  //         return; // Abort login if permissions are denied.
  //       }
  //     }

  //     // 4. Record the login in the mock backend.
  //     final loginPayload = jsonEncode({
  //       'timestamp': DateTime.now().toIso8601String(),
  //       'mode': modeTitle,
  //       'userId': currentUserId,
  //     });
  //     final loginUrl = Uri.parse('$baseUrl/login_history');
  //     debugPrint('=== FLUTTER API REQUEST (login_history) ===');
  //     debugPrint('URL: $loginUrl');
  //     debugPrint('Payload: $loginPayload');

  //     final loginRes = await http.post(
  //       loginUrl,
  //       headers: {'Content-Type': 'application/json'},
  //       body: loginPayload,
  //     );

  //     debugPrint('=== FLUTTER API RESPONSE (login_history) ===');
  //     debugPrint('Status: ${loginRes.statusCode}');
  //     debugPrint('Body: ${loginRes.body}');

  //     // 5. Configure native uploads.
  //     //    Native stores every point in SQLite first, then sends them in
  //     //    bulk to /locations/bulk (up to batchSize per request) and keeps
  //     //    draining the queue until it is empty, even when the app is closed.
  //     await BackgroundLocationTracker.instance.configureUpload(
  //       UploadConfig(
  //         url: uploadMap['url'] ?? '$baseUrl/locations/bulk',
  //         method: uploadMap['method'] ?? 'POST',
  //         headers: {
  //           ...Map<String, String>.from(uploadMap['headers'] ?? {}),
  //           'userId': currentUserId, // Native puts this in the body.
  //         },
  //         batchSize: uploadMap['batchSize'] ?? 20,
  //         syncIntervalSeconds: uploadMap['syncIntervalSeconds'] ?? 120,
  //       ),
  //     );

  //     // 6. Start tracking natively from the JSON config.
  //     final trackingConfig = TrackingConfig.fromMap(configMap);
  //     try {
  //       await BackgroundLocationTracker.instance.start(trackingConfig);
  //     } catch (e) {
  //       debugPrint('Tracking could not be started automatically: $e');
  //       // The user remains logged in. The alert card on the home screen
  //       // will notify them to fix permissions and they can start manually.
  //     }

  //     trackingState =
  //         await BackgroundLocationTracker.instance.getTrackingState();
  //     _lastPending = trackingState.pendingUpload;

  //     isLoggedIn = true;
  //     await _prefs.setBool('isLoggedInBg', true);

  //     _listenToStreams();
  //     await fetchServerData();
  //   } catch (e) {
  //     debugPrint('Network/JSON error: $e');
  //   }
  // }
  Future<void> loginWithJsonConfig(
    BuildContext context,
    String modeTitle,
    Map<String, dynamic> jsonResponse,
  ) async {
    try {
      // 1. Save IP & user id & mode.
      await _prefs.setString('serverIp', serverIp);
      await _prefs.setString('currentUserId', currentUserId);
      await _prefs.setString('loginMode', modeTitle);
      await _prefs.setString('loginJsonConfig', jsonEncode(jsonResponse));
      loginMode = modeTitle;
      loginJsonConfig = jsonEncode(jsonResponse);

      // 2. Simulated login response.
      final configMap = jsonResponse['tracking_config'] as Map<String, dynamic>;
      final uploadMap = jsonResponse['upload_config'] as Map<String, dynamic>;

      // 3. Ask for permissions — shows the "Allow all the time" dialog and
      //    waits for Settings if needed, then continues automatically.
      final granted = await _ensureAlwaysLocationPermission(context);
      if (!granted) {
        debugPrint(
            'User cancelled or permission still not granted — aborting login.');
        return;
      }

      // 4. Record the login in the mock backend.
      final loginPayload = jsonEncode({
        'timestamp': DateTime.now().toIso8601String(),
        'mode': modeTitle,
        'userId': currentUserId,
      });
      final loginUrl = Uri.parse('$baseUrl/login_history');
      debugPrint('=== FLUTTER API REQUEST (login_history) ===');
      debugPrint('URL: $loginUrl');
      debugPrint('Payload: $loginPayload');

      final loginRes = await http.post(
        loginUrl,
        headers: {'Content-Type': 'application/json'},
        body: loginPayload,
      );

      debugPrint('=== FLUTTER API RESPONSE (login_history) ===');
      debugPrint('Status: ${loginRes.statusCode}');
      debugPrint('Body: ${loginRes.body}');

      // 5. Configure native uploads.
      await BackgroundLocationTracker.instance.configureUpload(
        UploadConfig(
          url: uploadMap['url'] ?? '$baseUrl/locations/bulk',
          method: uploadMap['method'] ?? 'POST',
          headers: {
            ...Map<String, String>.from(uploadMap['headers'] ?? {}),
            'userId': currentUserId,
          },
          batchSize: uploadMap['batchSize'] ?? 20,
          syncIntervalSeconds: uploadMap['syncIntervalSeconds'] ?? 120,
        ),
      );

      // 6. Start tracking natively from the JSON config.
      final trackingConfig = TrackingConfig.fromMap(configMap);
      try {
        await BackgroundLocationTracker.instance.start(trackingConfig);
      } catch (e) {
        debugPrint('Tracking could not be started automatically: $e');
        // The user remains logged in. The alert card on the home screen
        // will notify them to fix permissions and they can start manually.
      }

      trackingState =
          await BackgroundLocationTracker.instance.getTrackingState();
      _lastPending = trackingState.pendingUpload;

      isLoggedIn = true;
      await _prefs.setBool('isLoggedInBg', true);
      notifyListeners(); // navigate to Dashboard now, don't wait on the network

      _listenToStreams();
      await fetchServerData();
    } catch (e) {
      debugPrint('Network/JSON error: $e');
    }
  }
  // No permission_handler import needed — drop it entirely.

  bool _isFullyGranted() =>
      permissions?.location == LocationPermissionLevel.always &&
      permissions?.isReadyForBackground == true &&
      permissions?.locationServiceEnabled == true &&
      permissions?.notifications == true;

  Future<void> _waitForAppResume() {
    final completer = Completer<void>();
    late final AppLifecycleListener listener;
    listener = AppLifecycleListener(
      onResume: () {
        if (!completer.isCompleted) completer.complete();
        listener.dispose();
      },
    );
    return completer.future;
  }

  /// Returns true only once "Always" location (plus the other required
  /// permissions) are actually granted.
  Future<bool> _ensureAlwaysLocationPermission(BuildContext context) async {
    permissions = await BackgroundLocationTracker.instance.requestPermissions();
    if (_isFullyGranted()) return true;

    if (permissions?.location != LocationPermissionLevel.always) {
      if (!context.mounted) return false;

      final shouldOpenSettings = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Background location required'),
          content: const Text(
            'To keep tracking your location even when the app is closed, '
            'please set location permission to "Allow all the time" in '
            'Settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Grant'),
            ),
          ],
        ),
      );

      if (shouldOpenSettings != true) return false; // user cancelled login

      // Uses the plugin's own native settings launcher — no third-party dep.
      await BackgroundLocationTracker.instance.openAppSettings();
      await _waitForAppResume();

      // checkPermissions() is a plain status read — it won't trigger another
      // OS prompt, unlike calling requestPermissions() again.
      permissions = await BackgroundLocationTracker.instance.checkPermissions();
    }

    return _isFullyGranted();
  }

  Future<void> logout() async {
    if (trackingState.status != TrackingStatus.idle) {
      await BackgroundLocationTracker.instance.stop(flushUpload: true);
    }
    await BackgroundLocationTracker.instance.clearUploadConfig();
    // Prevent old locations from being uploaded on the next login
    await BackgroundLocationTracker.instance.clearAll();

    _stopListening();

    isLoggedIn = false;
    loginMode = '';
    loginJsonConfig = '';
    await _prefs.setBool('isLoggedInBg', false);
    await _prefs.remove('loginMode');
    await _prefs.remove('loginJsonConfig');

    currentLocations.clear();
    serverLocations = [];
    notifyListeners();
  }

  Future<void> fetchServerData() async {
    try {
      final userId = currentUserId;

      if (userId.isEmpty) {
        debugPrint('FLUTTER LOG: Cannot fetch locations. User ID is missing.');
        return;
      }

      final uri = Uri.parse('$baseUrl/locations').replace(
        queryParameters: {'userId': userId},
      );

      debugPrint('=== FLUTTER API REQUEST (locations) ===');
      debugPrint('URL: $uri');
      debugPrint('Method: GET');

      final locRes = await http.get(uri);

      debugPrint('=== FLUTTER API RESPONSE (locations) ===');
      debugPrint('Status: ${locRes.statusCode}');
      debugPrint('Body: ${locRes.body}');

      if (locRes.statusCode == 200) {
        final decoded = jsonDecode(locRes.body);

        if (decoded is List) {
          serverLocations = List<Map<String, dynamic>>.from(decoded);
          debugPrint(
            'FLUTTER LOG: Fetched ${serverLocations.length} '
            'locations for userId=$userId',
          );
        } else {
          debugPrint(
              'FLUTTER LOG: Unexpected API response format. Not a list.');
          serverLocations = [];
        }
      } else {
        debugPrint(
          'FLUTTER LOG: Failed to fetch locations. '
          'Status code: ${locRes.statusCode}',
        );
      }

      notifyListeners();
    } catch (e) {
      debugPrint('FLUTTER LOG: Failed to fetch from server: $e');
    }
  }

  Future<void> clearAllData() async {
    // Deletes the currently filtered records (one user, or everyone when
    // "All Users" is selected).
    final listToDelete = List<Map<String, dynamic>>.from(filteredLocations);

    // Optimistically update the UI.
    serverLocations.removeWhere((item) => listToDelete.contains(item));
    notifyListeners();

    for (final loc in listToDelete) {
      final id = loc['id'];
      if (id != null) {
        try {
          await http.delete(Uri.parse('$baseUrl/locations/$id'));
        } catch (_) {}
      }
    }
  }

  void _listenToStreams() {
    // Avoid duplicate subscriptions when this is called more than once.
    _stopListening();

    _locationSub = BackgroundLocationTracker.instance.locationStream.listen(
      (point) {
        debugPrint(
          'FLUTTER LOG: Location captured -> '
          'Lat: ${point.latitude}, Lng: ${point.longitude}',
        );
        currentLocations.add(point);
        notifyListeners();
      },
    );

    // Points reach the server in bulk after a sync, not at capture time.
    // So refresh the server list when the pending count drops...
    _stateSub = BackgroundLocationTracker.instance.stateStream.listen((state) {
      final uploadedSomething = state.pendingUpload < _lastPending;
      _lastPending = state.pendingUpload;
      trackingState = state;
      notifyListeners();

      if (uploadedSomething) {
        fetchServerData();
      }
    });

    // ...and also poll lightly as a fallback.
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => fetchServerData(),
    );
  }

  void _stopListening() {
    _locationSub?.cancel();
    _stateSub?.cancel();
    _refreshTimer?.cancel();
    _locationSub = null;
    _stateSub = null;
    _refreshTimer = null;
  }

  Future<void> openSettings() async {
    await BackgroundLocationTracker.instance.openAppSettings();
  }

  Future<void> recheckPermissions() async {
    permissions = await BackgroundLocationTracker.instance.checkPermissions();
    notifyListeners();
  }
}

final AppState _appState = AppState();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _appState,
      builder: (context, _) {
        return MaterialApp(
          title: 'Tracking App',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
            useMaterial3: true,
          ),
          home: _appState.isLoggedIn
              ? const DashboardScreen()
              : const LoginScreen(),
        );
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late TextEditingController _ipController;
  late TextEditingController _userController;

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController(text: _appState.serverIp);
    _userController = TextEditingController(text: _appState.currentUserId);
  }

  @override
  void dispose() {
    _ipController.dispose();
    _userController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login & Setup Tracker')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _ipController,
                    decoration: const InputDecoration(
                      labelText: 'JSON Server IP',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.wifi),
                    ),
                    onChanged: (val) => _appState.serverIp = val,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _userController,
                    decoration: const InputDecoration(
                      labelText: 'User ID',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    onChanged: (val) => _appState.currentUserId = val,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              children: [
                _buildJsonScenarioCard(
                  context,
                  title: 'A. Every Minute (Periodic)',
                  desc: 'Captures location strictly every 60 seconds.',
                  icon: Icons.timer,
                  jsonPayload: {
                    'tracking_config': {
                      'mode': 'periodic',
                      'intervalSeconds': 60,
                      'accuracy': 'high',
                      'notificationTimeout': 5,
                      'userId': _appState.currentUserId,
                    },
                    'upload_config': _bulkUploadConfig,
                  },
                ),
                _buildJsonScenarioCard(
                  context,
                  title: 'B. Every 200 Meters (Distance)',
                  desc: 'Updates only when user moves 200m. Saves battery.',
                  icon: Icons.social_distance,
                  jsonPayload: {
                    'tracking_config': {
                      'mode': 'distanceFilter',
                      'minDistanceMeters': 200,
                      'accuracy': 'balanced',
                      'notificationTimeout': 8,
                      'userId': _appState.currentUserId,
                    },
                    'upload_config': _bulkUploadConfig,
                  },
                ),
                _buildJsonScenarioCard(
                  context,
                  title: 'C. Shift Timings (Mon-Fri 9-5)',
                  desc: 'Tracks based on schedule even if app is closed.',
                  icon: Icons.work,
                  jsonPayload: {
                    'tracking_config': {
                      'mode': 'scheduled',
                      'accuracy': 'high',
                      'notificationTimeout': 10,
                      'userId': _appState.currentUserId,
                      'schedule': [
                        {
                          'days': [1, 2, 3, 4, 5], // Mon to Fri
                          'start': {'hour': 9, 'minute': 0},
                          'end': {'hour': 17, 'minute': 0},
                          'fromDate': DateTime.now()
                              .subtract(const Duration(days: 1))
                              .toIso8601String(),
                          'toDate': DateTime.now()
                              .add(const Duration(days: 30))
                              .toIso8601String(),
                          'innerConfig': {
                            'mode': 'periodic',
                            'intervalSeconds': 60
                          }
                        }
                      ],
                    },
                    'upload_config': _bulkUploadConfig,
                  },
                ),
                _buildJsonScenarioCard(
                  context,
                  title: 'E. Shift Timings + 2-Min Periodic',
                  desc:
                      'Captures location every 2 minute strictly during the scheduled shift.',
                  icon: Icons.work_history,
                  jsonPayload: {
                    'tracking_config': {
                      'mode': 'scheduled',
                      'accuracy': 'high',
                      'intervalSeconds':
                          120, // Root level parameter for native engines
                      'notificationTimeout': 10,
                      'userId': _appState.currentUserId,
                      'schedule': [
                        {
                          'days': [1, 2, 3, 4, 5],
                          'start': {'hour': 9, 'minute': 0},
                          'end': {'hour': 20, 'minute': 0},
                          'fromDate': DateTime.now()
                              .subtract(const Duration(days: 1))
                              .toIso8601String(),
                          'toDate': DateTime.now()
                              .add(const Duration(days: 30))
                              .toIso8601String(),
                          'innerConfig': {
                            'mode': 'periodic',
                            'intervalSeconds': 120
                          }
                        }
                      ],
                    },
                    'upload_config': _bulkUploadConfig,
                  },
                ),
                _buildJsonScenarioCard(
                  context,
                  title: 'F. Shift Timings + Distance Filter',
                  desc:
                      'Captures location only when moved 200m, strictly during the scheduled shift.',
                  icon: Icons.transfer_within_a_station,
                  jsonPayload: {
                    'tracking_config': {
                      'mode': 'scheduled',
                      'accuracy': 'balanced',
                      'minDistanceMeters':
                          200, // Root level parameter for native engines
                      'notificationTimeout': 10,
                      'userId': _appState.currentUserId,
                      'schedule': [
                        {
                          'days': [1, 2, 3, 4, 5],
                          'start': {'hour': 9, 'minute': 0},
                          'end': {'hour': 20, 'minute': 0},
                          'fromDate': DateTime.now()
                              .subtract(const Duration(days: 1))
                              .toIso8601String(),
                          'toDate': DateTime.now()
                              .add(const Duration(days: 30))
                              .toIso8601String(),
                          'innerConfig': {
                            'mode': 'distanceFilter',
                            'minDistanceMeters': 200
                          }
                        }
                      ],
                    },
                    'upload_config': _bulkUploadConfig,
                  },
                ),
                _buildJsonScenarioCard(
                  context,
                  title: 'G. Walking vs Driving (Adaptive)',
                  desc:
                      'Motion-based. Fast when driving, slow when walking/stopped.',
                  icon: Icons.directions_car,
                  jsonPayload: {
                    'tracking_config': {
                      'mode': 'adaptive',
                      'detectStops': true,
                      'stopRadiusMeters': 50,
                      'stopMinDurationSeconds': 180,
                      'notificationTimeout': 5,
                      'userId': _appState.currentUserId,
                    },
                    'upload_config': _bulkUploadConfig,
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJsonScenarioCard(
    BuildContext context, {
    required String title,
    required String desc,
    required IconData icon,
    required Map<String, dynamic> jsonPayload,
  }) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 30, color: Theme.of(context).primaryColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(desc, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                const JsonEncoder.withIndent('  ').convert(jsonPayload),
                style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () =>
                    _appState.loginWithJsonConfig(context, title, jsonPayload),
                icon: const Icon(Icons.login),
                label: const Text('Login via JSON Response'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  String _formatTimestamp(Map<String, dynamic> loc) {
    final dateTime = parseLocationTime(loc);

    if (dateTime == null) {
      return 'Unknown';
    }

    return DateFormat('MMM dd, yyyy - hh:mm:ss a').format(dateTime.toLocal());
  }

  String _formatNumber(dynamic value, int decimals) {
    if (value == null) return 'Unknown';

    final number = double.tryParse(value.toString());

    if (number == null) return 'Unknown';

    return number.toStringAsFixed(decimals);
  }

  void _showDetailsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        String formattedJson = 'No JSON Config Available';
        if (_appState.loginJsonConfig.isNotEmpty) {
          try {
            final map = jsonDecode(_appState.loginJsonConfig);
            formattedJson = const JsonEncoder.withIndent('  ').convert(map);
          } catch (_) {
            formattedJson = _appState.loginJsonConfig;
          }
        }
        return AlertDialog(
          title: Text('Details: ${_appState.loginMode}'),
          content: SingleChildScrollView(
            child: Text(
              formattedJson,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _appState,
      builder: (context, _) {
        final state = _appState.trackingState;

        final hasPending = state.pendingUpload > 0;

        final hasAlways =
            _appState.permissions?.location == LocationPermissionLevel.always;

        final hasBatteryOptDisabled =
            _appState.permissions?.batteryOptimizationIgnored == true;

        // Filter + sort once per build, not once per list item.
        final locations = _appState.filteredLocations;

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Dashboard - ${_appState.currentUserId}',
                  style: const TextStyle(fontSize: 16),
                ),
                if (_appState.loginMode.isNotEmpty)
                  Text(
                    'Mode: ${_appState.loginMode}',
                    style: const TextStyle(fontSize: 12),
                  ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _appState.fetchServerData,
                tooltip: 'Refresh Server Data',
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'details':
                      _showDetailsDialog(context);
                      break;
                    case 'map':
                      if (locations.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LocationMapScreen(
                              locations: locations,
                            ),
                          ),
                        );
                      }
                      break;
                    case 'clear':
                      _appState.clearAllData();
                      break;
                    case 'logout':
                      _appState.logout();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'details',
                    child: ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('Details'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'map',
                    enabled: locations.isNotEmpty,
                    child: const ListTile(
                      leading: Icon(Icons.map_outlined),
                      title: Text('View on Map'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'clear',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline, color: Colors.red),
                      title: Text('Clear Filtered Data'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: ListTile(
                      leading: Icon(Icons.logout),
                      title: Text('Logout'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // -------------------------------------------------------
                // PERMISSION WARNINGS
                // -------------------------------------------------------
                if (!hasAlways || !hasBatteryOptDisabled)
                  Card(
                    color: Colors.red.shade50,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ExpansionTile(
                      initiallyExpanded: false,
                      title: const Text(
                        '⚠️ Background Restrictions Found',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!hasAlways)
                                const Text(
                                  '• Location must be set to "Allow all the time" '
                                  'in App Info > Permissions.',
                                ),
                              if (!hasBatteryOptDisabled)
                                const Text(
                                  '• Battery Saver / Optimization must be '
                                  'disabled for this app.',
                                ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  ElevatedButton(
                                    onPressed: () => _appState.openSettings(),
                                    child: const Text('Open App Settings'),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () =>
                                        _appState.recheckPermissions(),
                                    child: const Text('Re-check'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // -------------------------------------------------------
                // OFFLINE / ONLINE
                // -------------------------------------------------------
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: hasPending
                        ? Colors.orange.shade100
                        : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        hasPending ? Icons.cloud_off : Icons.cloud_done,
                        color: hasPending ? Colors.orange : Colors.green,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          hasPending
                              ? '${state.pendingUpload} points queued in the '
                                  'native DB. They upload in bulk on the next '
                                  'sync.'
                              : 'All points synced!',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // -------------------------------------------------------
                // STATS
                // -------------------------------------------------------
                Row(
                  children: [
                    Expanded(
                      child: _StatCard('Captured', '${state.pointsCaptured}'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        'Synced',
                        '${state.pointsCaptured - state.pendingUpload}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard('Pending', '${state.pendingUpload}'),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // -------------------------------------------------------
                // FILTERS
                // -------------------------------------------------------
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Data (${locations.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Row(
                      children: [
                        DropdownButton<String>(
                          value: _appState.availableUsers
                                  .contains(_appState.selectedUserFilter)
                              ? _appState.selectedUserFilter
                              : 'All Users',
                          items: _appState.availableUsers
                              .map(
                                (value) => DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              _appState.updateUserFilter(val);
                            }
                          },
                        ),
                        const SizedBox(width: 16),
                        DropdownButton<String>(
                          value: _appState.selectedDateFilter,
                          items: const ['Today', 'Week', 'Month', 'All']
                              .map(
                                (value) => DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              _appState.updateDateFilter(val);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // -------------------------------------------------------
                // SERVER DATA
                // -------------------------------------------------------
                Expanded(
                  child: Card(
                    child: ListView.builder(
                      itemCount: locations.length,
                      itemBuilder: (context, index) {
                        final loc = locations[index];

                        final userId = loc['userId']?.toString() ?? 'Unknown';
                        final accuracy = loc['accuracy'];

                        final userInitial = userId.isNotEmpty
                            ? userId.substring(0, 1).toUpperCase()
                            : '?';

                        return ListTile(
                          leading: CircleAvatar(child: Text(userInitial)),
                          title: Text(
                            '[$userId] '
                            'Lat: ${_formatNumber(loc['latitude'], 5)}, '
                            'Lng: ${_formatNumber(loc['longitude'], 5)}',
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_formatTimestamp(loc)),
                              if (accuracy != null)
                                Text(
                                  'Accuracy: ${_formatNumber(accuracy, 1)} m',
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
