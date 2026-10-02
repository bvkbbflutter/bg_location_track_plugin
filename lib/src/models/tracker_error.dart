/// Represents an error from the background location tracker.
class TrackerException implements Exception {
  /// Stable error code.
  final String code;

  /// Human-readable error message.
  final String message;

  /// Additional error details.
  final dynamic details;

  /// Creates a new TrackerException.
  TrackerException({
    required this.code,
    required this.message,
    this.details,
  });

  @override
  String toString() => 'TrackerException($code): $message ${details != null ? "- $details" : ""}';
}
