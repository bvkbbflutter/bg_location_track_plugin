import 'package:flutter/foundation.dart';

/// Configuration for the Android Foreground Service notification.
@immutable
class NotificationOptions {
  /// Android notification channel ID.
  final String channelId;
  
  /// Android notification channel name (user visible).
  final String channelName;
  
  /// Notification title.
  final String title;
  
  /// Notification body text.
  final String text;
  
  /// Drawable resource name for the small icon (e.g. 'ic_stat_location').
  final String smallIconResName;
  
  /// Whether to show a 'Stop' button action in the notification.
  final bool showStopAction;
  
  /// Whether tapping the notification should open the app.
  final bool tapOpensApp;

  /// Creates a NotificationOptions instance.
  const NotificationOptions({
    this.channelId = 'tracking_channel',
    this.channelName = 'Location Tracking',
    this.title = 'Tracking Active',
    this.text = 'Your location is being recorded in the background.',
    this.smallIconResName = 'ic_notification',
    this.showStopAction = false,
    this.tapOpensApp = true,
  });

  /// Creates from map.
  factory NotificationOptions.fromMap(Map<dynamic, dynamic> map) {
    return NotificationOptions(
      channelId: map['channelId'] as String? ?? 'tracking_channel',
      channelName: map['channelName'] as String? ?? 'Location Tracking',
      title: map['title'] as String? ?? 'Tracking Active',
      text: map['text'] as String? ?? 'Your location is being recorded in the background.',
      smallIconResName: map['smallIconResName'] as String? ?? 'ic_notification',
      showStopAction: map['showStopAction'] as bool? ?? false,
      tapOpensApp: map['tapOpensApp'] as bool? ?? true,
    );
  }

  /// Converts to map.
  Map<String, dynamic> toMap() {
    return {
      'channelId': channelId,
      'channelName': channelName,
      'title': title,
      'text': text,
      'smallIconResName': smallIconResName,
      'showStopAction': showStopAction,
      'tapOpensApp': tapOpensApp,
    };
  }
}
