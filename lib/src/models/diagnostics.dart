import 'package:flutter/foundation.dart';
import 'permission_status.dart';

/// Diagnostics information from the native layer.
@immutable
class Diagnostics {
  /// Whether the tracking service is currently running.
  final bool serviceRunning;
  
  /// Timestamp of the last location fix.
  final DateTime? lastLocationAt;
  
  /// Timestamp of the last watchdog check.
  final DateTime? lastWatchdogAt;
  
  /// Reason for the last restart (e.g. boot, watchdog, app_update).
  final String? lastRestartReason;
  
  /// Current permissions.
  final PermissionStatus permissions;
  
  /// True if battery optimization is ignored.
  final bool batteryOptimizationIgnored;
  
  /// True if background restrictions are applied (Android 9+).
  final bool backgroundRestricted;
  
  /// App standby bucket (Android).
  final String? standbyBucket;
  
  /// True if power save mode (battery saver) is enabled.
  final bool powerSaveMode;
  
  /// True if device is in doze mode (Android).
  final bool dozeMode;
  
  /// True if Google Play Services are available (Android).
  final bool playServicesAvailable;
  
  /// Which location engine is in use (fused or platform).
  final String? engineInUse;
  
  /// Total stored points in local DB.
  final int storedPoints;
  
  /// Points pending upload.
  final int pendingUpload;
  
  /// Device manufacturer OEM.
  final String? oem;
  
  /// True if OEM autostart settings might be required.
  final bool oemAutoStartLikelyRequired;
  
  /// List of potential issues or warnings.
  final List<String> warnings;

  /// Creates a new Diagnostics.
  const Diagnostics({
    required this.serviceRunning,
    this.lastLocationAt,
    this.lastWatchdogAt,
    this.lastRestartReason,
    required this.permissions,
    required this.batteryOptimizationIgnored,
    required this.backgroundRestricted,
    this.standbyBucket,
    required this.powerSaveMode,
    required this.dozeMode,
    required this.playServicesAvailable,
    this.engineInUse,
    required this.storedPoints,
    required this.pendingUpload,
    this.oem,
    required this.oemAutoStartLikelyRequired,
    required this.warnings,
  });

  /// Creates a Diagnostics from a map.
  factory Diagnostics.fromMap(Map<dynamic, dynamic> map) {
    return Diagnostics(
      serviceRunning: map['serviceRunning'] as bool? ?? false,
      lastLocationAt: map['lastLocationAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastLocationAt'] as int, isUtc: true)
          : null,
      lastWatchdogAt: map['lastWatchdogAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastWatchdogAt'] as int, isUtc: true)
          : null,
      lastRestartReason: map['lastRestartReason'] as String?,
      permissions: PermissionStatus.fromMap(map['permissions'] as Map),
      batteryOptimizationIgnored: map['batteryOptimizationIgnored'] as bool? ?? false,
      backgroundRestricted: map['backgroundRestricted'] as bool? ?? false,
      standbyBucket: map['standbyBucket'] as String?,
      powerSaveMode: map['powerSaveMode'] as bool? ?? false,
      dozeMode: map['dozeMode'] as bool? ?? false,
      playServicesAvailable: map['playServicesAvailable'] as bool? ?? true,
      engineInUse: map['engineInUse'] as String?,
      storedPoints: map['storedPoints'] as int? ?? 0,
      pendingUpload: map['pendingUpload'] as int? ?? 0,
      oem: map['oem'] as String?,
      oemAutoStartLikelyRequired: map['oemAutoStartLikelyRequired'] as bool? ?? false,
      warnings: (map['warnings'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  /// Generates a diagnostic report text suitable for support tickets.
  String getDiagnosticsReportText() {
    final buffer = StringBuffer();
    buffer.writeln('=== Tracking Diagnostics ===');
    buffer.writeln('Service Running: $serviceRunning');
    buffer.writeln('Engine in use: $engineInUse (Play Services: $playServicesAvailable)');
    buffer.writeln('Last Location: ${lastLocationAt?.toLocal() ?? "Never"}');
    buffer.writeln('Last Watchdog: ${lastWatchdogAt?.toLocal() ?? "Never"}');
    buffer.writeln('Last Restart: $lastRestartReason');
    buffer.writeln('Stored Points: $storedPoints ($pendingUpload pending)');
    buffer.writeln('Device OEM: $oem');
    buffer.writeln('Power Save Mode: $powerSaveMode');
    buffer.writeln('Doze Mode: $dozeMode');
    buffer.writeln('Battery Opt Ignored: $batteryOptimizationIgnored');
    buffer.writeln('Background Restricted: $backgroundRestricted');
    buffer.writeln('Standby Bucket: $standbyBucket');
    buffer.writeln('Permissions:');
    buffer.writeln('  Location: ${permissions.location.name}');
    buffer.writeln('  Precise: ${permissions.preciseAccuracy}');
    buffer.writeln('  Service Enabled: ${permissions.locationServiceEnabled}');
    buffer.writeln('Warnings:');
    if (warnings.isEmpty) {
      buffer.writeln('  None');
    } else {
      for (final w in warnings) {
        buffer.writeln('  - $w');
      }
    }
    return buffer.toString();
  }
}
