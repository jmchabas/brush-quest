// test/services/reminder_fakes.dart
import 'dart:async';

import 'package:brush_quest/services/analytics_service.dart';
import 'package:brush_quest/services/reminder_plan.dart';
import 'package:brush_quest/services/reminder_platform.dart';
import 'package:brush_quest/services/reminder_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

/// The phone's notification system, in memory. [pending] is what waits to
/// show; [calls] lists every call by name.
class FakeReminderPlatform implements ReminderPlatform {
  /// What the OS answers when asked.
  bool grant = true;

  /// Whether notifications are allowed now (an answered request sets it).
  bool allowed = false;

  /// The slot of the reminder that "started the app".
  String? launchSlotValue;

  /// Ids whose scheduling throws, as the plugin does for a past date.
  Set<int> failScheduleFor = {};

  /// When set, [pendingIds] throws it (the plugin can't list what waits);
  /// every other call still works.
  Error? pendingIdsError;

  /// When set, the next [schedule] call waits for it (overlap tests).
  Completer<void>? holdSchedule;

  final Map<int, PlannedReminder> pending = {};
  final List<String> calls = [];
  final List<int> cancelled = [];
  int permissionRequests = 0;
  int cancelAllCalls = 0;
  int openSettingsCalls = 0;
  void Function(String? slot)? onTap;

  Exception? _exception;
  Error? _error;

  /// From now on every call throws this (null: no more).
  Object? get failure => _exception ?? _error;
  set failure(Object? value) {
    _exception = value is Exception ? value : null;
    _error = value is Error ? value : null;
  }

  /// When the waiting reminders show, soonest first.
  List<DateTime> get pendingTimes =>
      [for (final r in pending.values) r.at]..sort();

  void _enter(String name) {
    calls.add(name);
    final exception = _exception;
    if (exception != null) throw exception;
    final error = _error;
    if (error != null) throw error;
  }

  @override
  Future<void> init({required void Function(String? slot) onTap}) async {
    _enter('init');
    this.onTap = onTap;
  }

  @override
  Future<String?> launchSlot() async {
    _enter('launchSlot');
    return launchSlotValue;
  }

  @override
  Future<bool> requestPermission() async {
    _enter('requestPermission');
    permissionRequests++;
    allowed = grant;
    return grant;
  }

  @override
  Future<bool> notificationsAllowed() async {
    _enter('notificationsAllowed');
    return allowed;
  }

  @override
  Future<List<int>> pendingIds() async {
    _enter('pendingIds');
    final error = pendingIdsError;
    if (error != null) throw error;
    return pending.keys.toList();
  }

  @override
  Future<void> schedule(PlannedReminder reminder) async {
    _enter('schedule');
    final hold = holdSchedule;
    if (hold != null) {
      holdSchedule = null;
      await hold.future;
    }
    if (failScheduleFor.contains(reminder.id)) {
      throw ArgumentError.value(
        reminder.at,
        'scheduledDate',
        'Must be a date in the future',
      );
    }
    pending[reminder.id] = reminder;
  }

  @override
  Future<void> cancel(int id) async {
    _enter('cancel');
    cancelled.add(id);
    pending.remove(id);
  }

  @override
  Future<void> cancelAll() async {
    _enter('cancelAll');
    cancelAllCalls++;
    pending.clear();
  }

  @override
  Future<void> openSettings() async {
    _enter('openSettings');
    openSettingsCalls++;
  }
}

/// FirebaseAnalytics that records, for an Android-mode AnalyticsService (on
/// the test host AnalyticsService is otherwise a no-op).
class RecordingAnalytics extends Fake implements FirebaseAnalytics {
  final List<Map<String, Object?>> events = [];
  final Map<String, String?> properties = {};

  /// The events called [name], with their parameters.
  Iterable<Map<String, Object?>> named(String name) =>
      events.where((e) => e['name'] == name);

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {}

  @override
  Future<void> setConsent({
    bool? adStorageConsentGranted,
    bool? analyticsStorageConsentGranted,
    bool? adPersonalizationSignalsConsentGranted,
    bool? adUserDataConsentGranted,
    bool? functionalityStorageConsentGranted,
    bool? personalizationStorageConsentGranted,
    bool? securityStorageConsentGranted,
  }) async {}

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {
    events.add({'name': name, ...?parameters});
  }

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
    AnalyticsCallOptions? callOptions,
  }) async {
    properties[name] = value;
  }
}

/// A ReminderService on [platform], recording analytics in [recorder], with
/// its clock at [now]. It is installed as the app's ReminderService (reset
/// `ReminderService.testInstance = null` in tearDown). [initialise] runs
/// `init()`, as app start does.
Future<ReminderService> installReminderService({
  required FakeReminderPlatform platform,
  required RecordingAnalytics recorder,
  DateTime Function()? now,
  GiftNightCheck nextStickerOpensGift = noStickerGifts,
  bool initialise = true,
}) async {
  final analytics = AnalyticsService.forTesting(
    isAndroid: true,
    analytics: recorder,
  );
  await analytics.init();
  final service = ReminderService.forTesting(
    platform: platform,
    analytics: analytics,
    now: now,
    nextStickerOpensGift: nextStickerOpensGift,
  );
  ReminderService.testInstance = service;
  if (initialise) await service.init();
  return service;
}
