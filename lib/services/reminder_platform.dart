// lib/services/reminder_platform.dart
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'reminder_plan.dart';

/// The phone's notification system, as the bedtime reminder uses it (spec
/// docs/superpowers/specs/2026-10-15-bedtime-reminder-design.md §5). The
/// real one is [PluginReminderPlatform]; tests use a fake. ReminderService
/// guards every call: none of them may break the app.
abstract interface class ReminderPlatform {
  /// Sets the plugin up, asking for no permission. [onTap] gets the slot name
  /// of a reminder tapped while the app runs.
  Future<void> init({required void Function(String? slot) onTap});

  /// The slot name of the reminder that started the app, or null.
  Future<String?> launchSlot();

  /// The OS prompt (Android 13+ POST_NOTIFICATIONS; iOS alert and sound, no
  /// badge, never provisional). True when notifications are allowed.
  Future<bool> requestPermission();

  /// Whether the OS lets Brush Quest show notifications now.
  Future<bool> notificationsAllowed();

  /// The ids of the notifications waiting to show.
  Future<List<int>> pendingIds();

  Future<void> schedule(PlannedReminder reminder);

  /// Cancels [id], whether it waits or shows.
  Future<void> cancel(int id);

  /// Cancels every notification, waiting or shown.
  Future<void> cancelAll();

  /// The phone's notification settings for Brush Quest.
  Future<void> openSettings();
}

/// [ReminderPlatform] on flutter_local_notifications.
class PluginReminderPlatform implements ReminderPlatform {
  PluginReminderPlatform([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// The Android channel a parent can switch off in the phone's settings.
  static const channelId = 'brush_reminders';
  static const channelName = 'Brushing reminders';
  static const channelDescription =
      'The brushing reminder you set in Brush Quest.';

  /// res/drawable/ic_stat_brush_reminder.xml (a monochrome tooth with a moon)
  /// and res/drawable-nodpi/ic_reminder_large.png (the app icon), kept from
  /// the resource shrinker by res/raw/keep.xml.
  static const smallIcon = 'ic_stat_brush_reminder';
  static const largeIcon = 'ic_reminder_large';

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      icon: smallIcon,
      largeIcon: DrawableResourceAndroidBitmap(largeIcon),
      color: Color(0xFF7C4DFF),
      category: AndroidNotificationCategory.reminder,
    ),
    // Nothing on screen while the app is open (spec §4), and no badge ever.
    // presentSound must stay true: the plugin gives the notification its
    // sound only then, and a silent bedtime reminder would be missed.
    iOS: DarwinNotificationDetails(
      presentAlert: false,
      presentBanner: false,
      presentList: false,
      presentBadge: false,
      presentSound: true,
    ),
  );

  @override
  Future<void> init({required void Function(String? slot) onTap}) async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(smallIcon),
        // The plugin's defaults would prompt here, unguarded, at the first
        // launch. The prompt belongs behind the parent gate.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          defaultPresentAlert: false,
          defaultPresentBanner: false,
          defaultPresentList: false,
          defaultPresentBadge: false,
          defaultPresentSound: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) => onTap(response.payload),
    );
  }

  @override
  Future<String?> launchSlot() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> requestPermission() async => switch (defaultTargetPlatform) {
    TargetPlatform.android =>
      await _android?.requestNotificationsPermission() ?? false,
    TargetPlatform.iOS =>
      await _ios?.requestPermissions(
            alert: true,
            sound: true,
            badge: false,
            provisional: false,
          ) ??
          false,
    _ => false,
  };

  @override
  Future<bool> notificationsAllowed() async => switch (defaultTargetPlatform) {
    TargetPlatform.android =>
      await _android?.areNotificationsEnabled() ?? false,
    TargetPlatform.iOS => (await _ios?.checkPermissions())?.isEnabled ?? false,
    _ => false,
  };

  @override
  Future<List<int>> pendingIds() async => [
    for (final request in await _plugin.pendingNotificationRequests())
      request.id,
  ];

  @override
  Future<void> schedule(PlannedReminder reminder) => _plugin.zonedSchedule(
    id: reminder.id,
    title: reminder.title,
    body: reminder.body,
    // An absolute instant: the plan built it in local time for its own date,
    // so no time-zone database is needed, and a trip abroad is put right the
    // next time the app opens.
    scheduledDate: tz.TZDateTime.from(reminder.at, tz.UTC),
    notificationDetails: _details,
    // Inexact: Play allows exact alarms only for alarm and calendar apps.
    // Android may deliver up to about an hour late (spec §5).
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    payload: reminder.slot.name,
  );

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  @override
  Future<void> openSettings() async {
    await _plugin.openAppNotificationSettings();
  }
}
