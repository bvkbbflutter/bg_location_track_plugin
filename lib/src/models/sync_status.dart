import 'package:flutter/foundation.dart';

/// Result of a manual sync operation.
@immutable
class SyncResult {
  /// Number of points successfully sent.
  final int sent;
  
  /// Number of points that failed to send.
  final int failed;
  
  /// Number of points still remaining to be uploaded.
  final int remaining;

  /// Creates a new SyncResult.
  const SyncResult({
    required this.sent,
    required this.failed,
    required this.remaining,
  });

  /// Creates a SyncResult from a map.
  factory SyncResult.fromMap(Map<dynamic, dynamic> map) {
    return SyncResult(
      sent: map['sent'] as int? ?? 0,
      failed: map['failed'] as int? ?? 0,
      remaining: map['remaining'] as int? ?? 0,
    );
  }
}

/// Status of the background sync manager.
@immutable
class SyncStatus {
  /// Whether the sync manager is paused.
  final bool isPaused;
  
  /// Number of points pending upload.
  final int pendingCount;
  
  /// Number of consecutive failed attempts.
  final int consecutiveFailures;
  
  /// Timestamp of the next scheduled retry, if backing off.
  final DateTime? nextRetryAt;
  
  /// Last HTTP error code received, if any.
  final int? lastError;

  /// Creates a new SyncStatus.
  const SyncStatus({
    required this.isPaused,
    required this.pendingCount,
    required this.consecutiveFailures,
    this.nextRetryAt,
    this.lastError,
  });

  /// Creates a SyncStatus from a map.
  factory SyncStatus.fromMap(Map<dynamic, dynamic> map) {
    return SyncStatus(
      isPaused: map['isPaused'] as bool? ?? false,
      pendingCount: map['pendingCount'] as int? ?? 0,
      consecutiveFailures: map['consecutiveFailures'] as int? ?? 0,
      nextRetryAt: map['nextRetryAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['nextRetryAt'] as int, isUtc: true)
          : null,
      lastError: map['lastError'] as int?,
    );
  }
}
