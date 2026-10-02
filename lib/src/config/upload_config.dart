import 'package:flutter/foundation.dart';

/// Exponential backoff policy for upload retries.
@immutable
class ExponentialBackoff {
  /// Initial delay before first retry.
  final Duration initial;
  
  /// Maximum delay between retries.
  final Duration max;

  const ExponentialBackoff({
    this.initial = const Duration(seconds: 15),
    this.max = const Duration(minutes: 15),
  });

  factory ExponentialBackoff.fromMap(Map<dynamic, dynamic> map) {
    return ExponentialBackoff(
      initial: Duration(milliseconds: map['initialMs'] as int? ?? 15000),
      max: Duration(milliseconds: map['maxMs'] as int? ?? 900000),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'initialMs': initial.inMilliseconds,
      'maxMs': max.inMilliseconds,
    };
  }
}

/// Configuration for the native-side upload manager.
@immutable
class UploadConfig {
  /// The target URL for HTTP POST.
  final String url;
  
  /// HTTP method (default 'POST').
  final String method;
  
  /// Custom HTTP headers to include with the request.
  final Map<String, String>? headers;
  
  /// Bearer auth token, added to 'Authorization: Bearer <token>'.
  final String? authToken;
  
  /// Maximum number of points per upload batch.
  final int batchSize;
  
  /// How often to sync to the server automatically.
  final int syncIntervalSeconds;
  
  /// If true, uploads will only occur over unmetered (Wi-Fi) connections.
  final bool wifiOnly;
  
  /// If true, compresses the request payload using GZIP.
  final bool gzip;
  
  /// Maximum number of retries per batch.
  final int maxRetries;
  
  /// Backoff strategy for failures.
  final ExponentialBackoff backoff;
  
  /// Wrapper key for the JSON body (e.g., 'locations' -> {"locations": [...]}).
  /// If null, a top-level array is sent instead.
  final String? bodyWrapperKey;
  
  /// Remaps standard field names to your custom names.
  /// Example: {'latitude': 'lat', 'timestamp': 'recorded_at'}
  final Map<String, String>? fieldMapping;
  
  /// Which fields to include in the payload. If null, all fields are included.
  final List<String>? includeFields;
  
  /// HTTP status codes considered a success.
  final Set<int> successStatusCodes;
  
  /// Optional device identifier injected into the request.
  final String? deviceId;
  
  /// Extra key/value pairs to include in the root of the JSON body.
  final Map<String, dynamic>? extraBody;

  const UploadConfig({
    required this.url,
    this.method = 'POST',
    this.headers,
    this.authToken,
    this.batchSize = 50,
    this.syncIntervalSeconds = 60,
    this.wifiOnly = false,
    this.gzip = true,
    this.maxRetries = 8,
    this.backoff = const ExponentialBackoff(),
    this.bodyWrapperKey = 'locations',
    this.fieldMapping,
    this.includeFields,
    this.successStatusCodes = const {200, 201, 202, 204},
    this.deviceId,
    this.extraBody,
  });

  factory UploadConfig.fromMap(Map<dynamic, dynamic> map) {
    return UploadConfig(
      url: map['url'] as String,
      method: map['method'] as String? ?? 'POST',
      headers: (map['headers'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())),
      authToken: map['authToken'] as String?,
      batchSize: map['batchSize'] as int? ?? 50,
      syncIntervalSeconds: map['syncIntervalSeconds'] as int? ?? 60,
      wifiOnly: map['wifiOnly'] as bool? ?? false,
      gzip: map['gzip'] as bool? ?? true,
      maxRetries: map['maxRetries'] as int? ?? 8,
      backoff: map['backoff'] != null 
          ? ExponentialBackoff.fromMap(map['backoff'] as Map) 
          : const ExponentialBackoff(),
      bodyWrapperKey: map['bodyWrapperKey'] as String?,
      fieldMapping: (map['fieldMapping'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())),
      includeFields: (map['includeFields'] as List?)?.map((e) => e.toString()).toList(),
      successStatusCodes: (map['successStatusCodes'] as List?)?.map((e) => e as int).toSet() ?? const {200, 201, 202, 204},
      deviceId: map['deviceId'] as String?,
      extraBody: map['extraBody'] != null ? Map<String, dynamic>.from(map['extraBody'] as Map) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'method': method,
      if (headers != null) 'headers': headers,
      if (authToken != null) 'authToken': authToken,
      'batchSize': batchSize,
      'syncIntervalSeconds': syncIntervalSeconds,
      'wifiOnly': wifiOnly,
      'gzip': gzip,
      'maxRetries': maxRetries,
      'backoff': backoff.toMap(),
      if (bodyWrapperKey != null) 'bodyWrapperKey': bodyWrapperKey,
      if (fieldMapping != null) 'fieldMapping': fieldMapping,
      if (includeFields != null) 'includeFields': includeFields,
      'successStatusCodes': successStatusCodes.toList(),
      if (deviceId != null) 'deviceId': deviceId,
      if (extraBody != null) 'extraBody': extraBody,
    };
  }
}
