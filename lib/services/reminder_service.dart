// lib/services/reminder_service.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_service.dart';
import 'reminder_plan.dart';
import 'reminder_platform.dart';
import 'streak_service.dart';

/// Whether the next sticker the card places opens a gift: it is the 3rd or
/// the 7th (sticker-card spec §4.1). The card is Part B of the 2026-10-15
/// rework. Until it ships, [noStickerGifts] answers, and no reminder carries
/// the gift line.
typedef GiftNightCheck = Future<bool> Function();

/// Before the sticker card: no night is a gift night.
Future<bool> noStickerGifts() async => false;

/// The parent bedtime reminder (spec
/// docs/superpowers/specs/2026-10-15-bedtime-reminder-design.md): the
/// parent's settings, the hand-off offers, and a rolling week of one-shot
/// notifications ([planReminders]). Everything stays on this device; none of
/// its keys is synced. No call into the notification system may break the
/// app: each one is guarded, and nothing is scheduled before [init].
class ReminderService {
  factory ReminderService() => _testInstance ?? _instance;

  /// A service on [platform] (in tests, a fake), with its own [analytics],
  /// clock and gift check.
  @visibleForTesting
  ReminderService.forTesting({
    required ReminderPlatform platform,
    AnalyticsService? analytics,
    DateTime Function()? now,
    GiftNightCheck nextStickerOpensGift = noStickerGifts,
  }) : this._(platform, analytics, now ?? DateTime.now, nextStickerOpensGift);

  ReminderService._(
    this._platform,
    this._analyticsOverride,
    this._now,
    this._nextStickerOpensGift,
  );

  // Part B (the sticker card) replaces noStickerGifts here with the card's
  // own check: true when its count is 2 or 6 (the next sticker is the 3rd or
  // the 7th), false on a full card (the next one starts a new card).
  static final ReminderService _instance = ReminderService._(
    PluginReminderPlatform(),
    null,
    DateTime.now,
    noStickerGifts,
  );

  static ReminderService? _testInstance;

  /// The service a test installed, if any.
  @visibleForTesting
  static ReminderService? get testInstance => _testInstance;

  /// Tests install their service here; null brings the real one back.
  @visibleForTesting
  static set testInstance(ReminderService? service) => _testInstance = service;

  static const keyEveningEnabled = 'reminder_evening_enabled';
  static const keyEveningTime = 'reminder_evening_time';
  static const keyMorningEnabled = 'reminder_morning_enabled';
  static const keyMorningTime = 'reminder_morning_time';
  static const keyOfferCount = 'reminder_offer_count';
  static const keyOfferLastDate = 'reminder_offer_last_date';
  static const keyDecided = 'reminder_decided';

  /// Every reminder key. Per device (none is in SyncService's keys); "Start
  /// fresh" removes them all.
  static const allKeys = [
    keyEveningEnabled,
    keyEveningTime,
    keyMorningEnabled,
    keyMorningTime,
    keyOfferCount,
    keyOfferLastDate,
    keyDecided,
  ];

  final ReminderPlatform _platform;
  final AnalyticsService? _analyticsOverride;
  final DateTime Function() _now;
  final GiftNightCheck _nextStickerOpensGift;

  AnalyticsService get _analytics => _analyticsOverride ?? AnalyticsService();

  /// True once [init] has set the plugin up. Before that (and in tests that
  /// never call it) nothing is scheduled and the plugin is never touched.
  bool _ready = false;

  /// The app is open: no reminder shows today (spec §4). It starts open.
  bool _foreground = true;

  Future<void>? _rescheduling;
  bool _rescheduleAgain = false;

  /// App start (main.dart): sets the plugin up, asking for no permission;
  /// counts an app open from a reminder; plans the week.
  Future<void> init() async {
    if (_ready) return;
    try {
      await _platform.init(onTap: _onReminderTapped);
    } on Object catch (e) {
      debugPrint('Reminders unavailable: $e');
      return;
    }
    _ready = true;
    final slot = await _safe(_platform.launchSlot, null);
    if (slot != null) _onReminderTapped(slot);
    final prefs = await SharedPreferences.getInstance();
    unawaited(_analytics.setReminderOn(on: _readSettings(prefs).anyOn));
    await reschedule();
  }

  /// A tap on a reminder only opens the app, to Home and its usual greeting
  /// (spec §4: no deep link).
  void _onReminderTapped(String? slot) {
    unawaited(_analytics.logAppOpenFromReminder(slot: slot ?? 'unknown'));
  }

  /// The app is back on screen: today's reminders wait while it is open, and
  /// the week is planned again from now.
  Future<void> onAppResumed() {
    _foreground = true;
    return reschedule();
  }

  /// The app was left: today's reminders are planned again.
  Future<void> onAppPaused() {
    _foreground = false;
    return reschedule();
  }

  /// Plans the week again and replaces what waits (spec §5): at start, on
  /// resume and pause, after every brush, and when the Pause or a setting
  /// changes. A call that comes while one runs makes it run once more, after
  /// the last change. Never throws.
  Future<void> reschedule() {
    if (!_ready) return Future<void>.value();
    final running = _rescheduling;
    if (running != null) {
      _rescheduleAgain = true;
      return running;
    }
    return _rescheduling = _rescheduleLoop();
  }

  Future<void> _rescheduleLoop() async {
    try {
      do {
        _rescheduleAgain = false;
        await _rescheduleOnce();
      } while (_rescheduleAgain);
    } on Object catch (e) {
      debugPrint('Reminder planning failed: $e');
    } finally {
      _rescheduling = null;
    }
  }

  Future<void> _rescheduleOnce() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = _readSettings(prefs);
    final now = _now();
    final streak = StreakService();
    final today = await streak.getSlotsOn(now);
    final pauseUntil = await streak.getStreakPauseEnd();
    final gift =
        settings.eveningOn && await _safe(_nextStickerOpensGift, false);
    final plan = planReminders(
      now: now,
      settings: settings,
      morningDoneToday: today.morningDone,
      eveningDoneToday: today.eveningDone,
      pauseUntil: pauseUntil,
      nextStickerOpensGift: gift,
      appInForeground: _foreground,
    );
    if (settings.anyOn) {
      // Every reminder id, waiting or showing: a reminder the parent has seen
      // goes once the app is opened or a brush is recorded.
      for (final id in allReminderIds()) {
        await _try(() => _platform.cancel(id));
      }
    } else {
      for (final id in await _safe(_platform.pendingIds, const <int>[])) {
        if (isReminderId(id)) await _try(() => _platform.cancel(id));
      }
    }
    for (final reminder in plan) {
      await _try(() => _platform.schedule(reminder));
    }
  }

  /// The parent's settings. With no evening time saved yet, the evening time
  /// is the one suggested from the first brush (spec §3.2).
  Future<ReminderSettings> settings() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = _readSettings(prefs);
    if (prefs.get(keyEveningTime) is int) return saved;
    return saved.copyWith(evening: await suggestedEveningTime());
  }

  /// 30 minutes before the first brush, or 7:30 pm ([defaultEveningTime]).
  Future<ReminderTime> suggestedEveningTime() async {
    try {
      final history = await StreakService().getHistory(); // newest first
      return defaultEveningTime(history.isEmpty ? null : history.last.time);
    } on Object catch (e) {
      debugPrint('Brush history unreadable: $e');
      return kDefaultEveningTime;
    }
  }

  /// TURN ON (Screen B), or a Parent Zone switch turned on (spec §3.2): the
  /// OS prompt first, and the reminder is saved only if the OS allows it.
  /// Either answer is the parent's decision: no more hand-offs.
  Future<bool> turnOn(ReminderSettings wanted) async {
    final granted = await _safe(_platform.requestPermission, false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyDecided, true);
    final result = granted
        ? ReminderOfferResult.enabled
        : ReminderOfferResult.osDenied;
    unawaited(_analytics.logReminderOfferResult(result: result.analyticsName));
    if (!granted) return false;
    await _writeSettings(prefs, wanted);
    unawaited(
      _analytics.logReminderEnabled(
        eveningHour: wanted.evening.hour,
        morning: wanted.morningOn,
      ),
    );
    unawaited(_analytics.setReminderOn(on: wanted.anyOn));
    await reschedule();
    return true;
  }

  /// The Parent Zone's other changes: a switch turned off, a new time.
  /// Turning a reminder on goes through [turnOn] (the OS must allow it
  /// first), so here a reminder that is off stays off.
  Future<void> saveSettings(ReminderSettings changed) async {
    final prefs = await SharedPreferences.getInstance();
    final current = _readSettings(prefs);
    final allowed = changed.copyWith(
      eveningOn: changed.eveningOn && current.eveningOn,
      morningOn: changed.morningOn && current.morningOn,
    );
    await _writeSettings(prefs, allowed);
    unawaited(_analytics.setReminderOn(on: allowed.anyOn));
    await reschedule();
  }

  /// When DONE is tapped after a finished brush: the hand-off to show, or
  /// null (spec §2, [reminderOfferDue]). Saved state only; the OS is never
  /// asked. On Android 13+ it can't tell "never asked" from "refused", so a
  /// refusal in our own flow is saved as the parent's decision instead.
  Future<ReminderOffer?> offerDue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shown = prefs.get(keyOfferCount);
      final last = prefs.get(keyOfferLastDate);
      return reminderOfferDue(
        offersShown: shown is int ? shown : 0,
        lastOfferDate: last is String ? last : null,
        decided: prefs.get(keyDecided) == true,
        remindersOn: _readSettings(prefs).anyOn,
        totalBrushes: await StreakService().getTotalBrushes(),
        today: StreakService.dateKey(_now()),
      );
    } on Object catch (e) {
      debugPrint('Reminder offer skipped: $e');
      return null;
    }
  }

  /// The hand-off is on screen: [offer] has been made, today.
  Future<void> noteOfferShown(ReminderOffer offer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyOfferCount, offer.number);
    await prefs.setString(keyOfferLastDate, StreakService.dateKey(_now()));
    unawaited(_analytics.logReminderOfferShown(offer: '${offer.number}'));
  }

  /// A Parent Zone switch is being turned on: the Parent Zone's own offer
  /// (ruling R-6). [turnOn] sends its result.
  void noteParentZoneOffer() {
    unawaited(_analytics.logReminderOfferShown(offer: 'parent_zone'));
  }

  /// How the hand-off went: gate opened, skipped, timeout or "Not now"
  /// ([turnOn] sends the OS's answer itself). "Not now" is the parent's
  /// decision: no more hand-offs.
  Future<void> noteOfferResult(ReminderOfferResult result) async {
    if (result == ReminderOfferResult.notNow) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyDecided, true);
    }
    unawaited(_analytics.logReminderOfferResult(result: result.analyticsName));
  }

  /// Whether the OS lets Brush Quest show notifications (the Parent Zone).
  Future<bool> notificationsAllowed() =>
      _safe(_platform.notificationsAllowed, false);

  /// "Open phone settings": a link out, only ever offered behind the parent
  /// gate (the Parent Zone).
  Future<void> openPhoneSettings() => _try(_platform.openSettings);

  /// "Start fresh" (Settings): every reminder cancelled, shown ones too, and
  /// every reminder key removed (spec §4).
  Future<void> resetAll() async {
    if (_ready) await _try(_platform.cancelAll);
    final prefs = await SharedPreferences.getInstance();
    for (final key in allKeys) {
      await prefs.remove(key);
    }
    unawaited(_analytics.setReminderOn(on: false));
  }

  /// The saved settings. A value of the wrong type (an odd old save) reads
  /// as not saved.
  ReminderSettings _readSettings(SharedPreferences prefs) {
    ReminderTime time(String key, ReminderTime fallback) {
      final value = prefs.get(key);
      return value is int ? reminderTimeFromMinutes(value) : fallback;
    }

    return ReminderSettings(
      eveningOn: prefs.get(keyEveningEnabled) == true,
      evening: time(keyEveningTime, kDefaultEveningTime),
      morningOn: prefs.get(keyMorningEnabled) == true,
      morning: time(keyMorningTime, kDefaultMorningTime),
    );
  }

  Future<void> _writeSettings(
    SharedPreferences prefs,
    ReminderSettings settings,
  ) async {
    await prefs.setBool(keyEveningEnabled, settings.eveningOn);
    await prefs.setInt(keyEveningTime, reminderMinutes(settings.evening));
    await prefs.setBool(keyMorningEnabled, settings.morningOn);
    await prefs.setInt(keyMorningTime, reminderMinutes(settings.morning));
  }

  /// One call into the notification system. A reminder must never break the
  /// app: a failure (an Exception, or an Error such as the
  /// LateInitializationError of an unregistered plugin) is logged and
  /// [fallback] returned.
  Future<T> _safe<T>(Future<T> Function() call, T fallback) async {
    try {
      return await call();
    } on Object catch (e) {
      debugPrint('Reminder platform call failed: $e');
      return fallback;
    }
  }

  Future<void> _try(Future<void> Function() call) async {
    try {
      await call();
    } on Object catch (e) {
      debugPrint('Reminder platform call failed: $e');
    }
  }
}
