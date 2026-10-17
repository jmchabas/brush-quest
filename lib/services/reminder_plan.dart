// lib/services/reminder_plan.dart
//
// The parent bedtime reminder's rules (spec
// docs/superpowers/specs/2026-10-15-bedtime-reminder-design.md §2–§5), as
// plain functions and values: no plugin, no storage, no clock of their own.
// ReminderService feeds them; reminder_plan_test.dart pins them.
import 'package:flutter/foundation.dart';

/// A time of day, in the phone's local time.
typedef ReminderTime = ({int hour, int minute});

/// The evening reminder's time before the parent picks one (spec §3.2).
const ReminderTime kDefaultEveningTime = (hour: 19, minute: 30);

/// The morning reminder's time before the parent picks one (spec §3.2).
const ReminderTime kDefaultMorningTime = (hour: 7, minute: 0);

/// Days planned at a time, from today (or from the day a Pause ends, if that
/// is later): a week without opening the app means at most a week of
/// reminders, then silence (spec §4).
const kReminderHorizonDays = 7;

/// Minutes after midnight: how a time is saved.
int reminderMinutes(ReminderTime time) => time.hour * 60 + time.minute;

/// The time [minutes] after midnight, kept inside the day.
ReminderTime reminderTimeFromMinutes(int minutes) {
  final m = minutes.clamp(0, 24 * 60 - 1);
  return (hour: m ~/ 60, minute: m % 60);
}

/// "7:45 PM": how the parent screens write a time.
String formatReminderTime(ReminderTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${time.hour < 12 ? 'AM' : 'PM'}';
}

/// Every quarter hour from [first] to [last], both included.
List<ReminderTime> _quarterHours(ReminderTime first, ReminderTime last) => [
  for (var m = reminderMinutes(first); m <= reminderMinutes(last); m += 15)
    reminderTimeFromMinutes(m),
];

/// The evening times a parent can pick: 5:00 PM to 10:00 PM.
final List<ReminderTime> eveningReminderChoices = _quarterHours(
  (hour: 17, minute: 0),
  (hour: 22, minute: 0),
);

/// The morning times a parent can pick: 5:30 AM to 10:00 AM. Both lists keep
/// a reminder on its own side of noon, where the brushing slots split.
final List<ReminderTime> morningReminderChoices = _quarterHours(
  (hour: 5, minute: 30),
  (hour: 10, minute: 0),
);

/// The two reminders, and the first of each one's notification ids.
enum ReminderSlot {
  evening(100),
  morning(200);

  const ReminderSlot(this.idBase);

  final int idBase;
}

/// Days since 1 Jan 1970 for [day]'s date. UTC arithmetic, so a
/// daylight-saving change can't move it.
int _dayNumber(DateTime day) =>
    DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

/// The notification id of [slot]'s reminder on [day]'s date: evening 100–106,
/// morning 200–206 (spec §5), taken in turn by the days of a week. A date
/// keeps its id however often the week is planned, so planning again
/// replaces that night's reminder, and cancelling it also clears it if it is
/// still showing.
int reminderIdFor(ReminderSlot slot, DateTime day) =>
    slot.idBase + _dayNumber(day) % kReminderHorizonDays;

/// Every id the reminders use.
List<int> allReminderIds() => [
  for (final slot in ReminderSlot.values)
    for (var i = 0; i < kReminderHorizonDays; i++) slot.idBase + i,
];

/// Whether [id] is one of the reminders' ids.
bool isReminderId(int id) => ReminderSlot.values.any(
  (slot) => id >= slot.idBase && id < slot.idBase + kReminderHorizonDays,
);

/// What the parent chose: each reminder on or off, and its time.
@immutable
class ReminderSettings {
  const ReminderSettings({
    this.eveningOn = false,
    this.evening = kDefaultEveningTime,
    this.morningOn = false,
    this.morning = kDefaultMorningTime,
  });

  final bool eveningOn;
  final ReminderTime evening;
  final bool morningOn;
  final ReminderTime morning;

  bool get anyOn => eveningOn || morningOn;

  ReminderSettings copyWith({
    bool? eveningOn,
    ReminderTime? evening,
    bool? morningOn,
    ReminderTime? morning,
  }) => ReminderSettings(
    eveningOn: eveningOn ?? this.eveningOn,
    evening: evening ?? this.evening,
    morningOn: morningOn ?? this.morningOn,
    morning: morning ?? this.morning,
  );

  @override
  bool operator ==(Object other) =>
      other is ReminderSettings &&
      other.eveningOn == eveningOn &&
      other.evening == evening &&
      other.morningOn == morningOn &&
      other.morning == morning;

  @override
  int get hashCode => Object.hash(eveningOn, evening, morningOn, morning);

  @override
  String toString() =>
      'ReminderSettings(evening: $eveningOn ${formatReminderTime(evening)}, '
      'morning: $morningOn ${formatReminderTime(morning)})';
}

/// One notification's words.
typedef ReminderCopy = ({String title, String body});

// The approved copy (spec §4; sticker-card spec §4.7), each line split at its
// natural break into the notification's title and text. Written to the
// parent: no streaks, no "we miss you", nothing addressed to the child.
const ReminderCopy kEveningCopyMonsters = (
  title: 'Brushing time!',
  body: "Tonight's cavity monsters are waiting.",
);
const ReminderCopy kEveningCopyBattle = (
  title: 'Bedtime brush',
  body: '2 minutes, one monster battle.',
);
const ReminderCopy kEveningCopyGift = (
  title: 'Brushing time!',
  body: "Tonight's brush opens a gift on the sticker card.",
);
const ReminderCopy kMorningCopy = (
  title: 'Morning brush',
  body: '2 minutes before the day starts.',
);

/// One reminder to schedule.
@immutable
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.slot,
    required this.at,
    required this.title,
    required this.body,
  });

  final int id;
  final ReminderSlot slot;

  /// When it should show, in local time.
  final DateTime at;
  final String title;
  final String body;

  @override
  bool operator ==(Object other) =>
      other is PlannedReminder &&
      other.id == id &&
      other.slot == slot &&
      other.at == at &&
      other.title == title &&
      other.body == body;

  @override
  int get hashCode => Object.hash(id, slot, at, title, body);

  @override
  String toString() => 'PlannedReminder($id ${slot.name} $at "$title")';
}

/// The first date to plan reminders for: today, or the date the Pause ends if
/// that is later. A week that always began today would leave a Pause of a
/// week or more with nothing planned after it, until the app is opened again.
DateTime _firstPlannedDay(DateTime now, DateTime? pauseUntil) {
  final pauseEnds = pauseUntil?.toLocal();
  return pauseEnds != null && _dayNumber(pauseEnds) > _dayNumber(now)
      ? pauseEnds
      : now;
}

/// The reminders for [kReminderHorizonDays] days, soonest first (spec
/// §4–§5): the next week, or the week from the day the Pause ends if that is
/// later. Rolling one-shots, so a brushed day can be skipped:
///
/// * each instant is built in local time for its own date, so a
///   daylight-saving change needs nothing special;
/// * the week starts today, or on the date [pauseUntil] falls on if that is
///   later: a Pause of any length is followed by a full week, planned
///   without the app being opened first;
/// * nothing before [pauseUntil] (the parent Pause);
/// * the rules about today apply only when today is in the week: nothing for
///   a time that has passed, nor for a slot already brushed today
///   ([morningDoneToday], [eveningDoneToday]; morning is before noon, as in
///   the streak service), nor while [appInForeground] (a reminder never shows
///   while the app is open, and leaving the app plans the week again);
/// * the evening line alternates by date; on a gift night it is the gift
///   line. [nextStickerOpensGift] says the next sticker the card places is
///   the 3rd or the 7th. The first finished brush of a day places that day's
///   sticker, so tonight is a gift night only if nothing was brushed yet
///   today, and every later night is one (a brush first plans it all again).
///   A week that starts after today has no "tonight": all its nights are.
List<PlannedReminder> planReminders({
  required DateTime now,
  required ReminderSettings settings,
  bool morningDoneToday = false,
  bool eveningDoneToday = false,
  DateTime? pauseUntil,
  bool nextStickerOpensGift = false,
  bool appInForeground = false,
}) {
  final brushedToday = morningDoneToday || eveningDoneToday;
  final today = _dayNumber(now);
  final first = _firstPlannedDay(now, pauseUntil);
  final plan = <PlannedReminder>[];
  for (var dayIndex = 0; dayIndex < kReminderHorizonDays; dayIndex++) {
    // DateTime turns Oct 32 into Nov 1.
    final day = DateTime(first.year, first.month, first.day + dayIndex);
    final isToday = _dayNumber(day) == today;
    for (final slot in ReminderSlot.values) {
      final evening = slot == ReminderSlot.evening;
      if (!(evening ? settings.eveningOn : settings.morningOn)) continue;
      final time = evening ? settings.evening : settings.morning;
      final at = DateTime(day.year, day.month, day.day, time.hour, time.minute);
      if (!at.isAfter(now)) continue;
      final brushedThisSlot = evening ? eveningDoneToday : morningDoneToday;
      if (isToday && (appInForeground || brushedThisSlot)) continue;
      if (pauseUntil != null && at.isBefore(pauseUntil)) continue;
      final copy = _copyFor(
        slot,
        day,
        giftNight: nextStickerOpensGift && (!isToday || !brushedToday),
      );
      plan.add(
        PlannedReminder(
          id: reminderIdFor(slot, day),
          slot: slot,
          at: at,
          title: copy.title,
          body: copy.body,
        ),
      );
    }
  }
  plan.sort((a, b) => a.at.compareTo(b.at));
  return plan;
}

ReminderCopy _copyFor(
  ReminderSlot slot,
  DateTime day, {
  required bool giftNight,
}) {
  if (slot == ReminderSlot.morning) return kMorningCopy;
  if (giftNight) return kEveningCopyGift;
  // By date, so a night keeps its line whenever the week is planned.
  return _dayNumber(day).isEven ? kEveningCopyMonsters : kEveningCopyBattle;
}

/// The hand-off's two chances (spec §2).
enum ReminderOffer {
  first,
  second;

  /// 1 or 2: the saved offer count, and the analytics `offer`.
  int get number => index + 1;
}

/// The hand-off to show after a finished brush, or null (spec §2):
///
/// * offer 1: the first finished brush with no offer made yet. That is a new
///   player's first brush, and a player's next brush after updating from a
///   version without reminders (ruling R-1);
/// * offer 2: after offer 1 ended without a decision (a skip, a timeout, a
///   cancelled gate), from the 3rd finished brush, on a later date;
/// * never once the parent decided ([decided]: TURN ON allowed or refused,
///   or "Not now"), while a reminder is on, or after offer 2.
///
/// [today] and [lastOfferDate] are 'yyyy-mm-dd'.
ReminderOffer? reminderOfferDue({
  required int offersShown,
  required String? lastOfferDate,
  required bool decided,
  required bool remindersOn,
  required int totalBrushes,
  required String today,
}) {
  if (decided || remindersOn || totalBrushes < 1) return null;
  if (offersShown <= 0) return ReminderOffer.first;
  final laterDay = lastOfferDate == null || today.compareTo(lastOfferDate) > 0;
  if (offersShown == 1 && totalBrushes >= 3 && laterDay) {
    return ReminderOffer.second;
  }
  return null;
}

/// How an offer ended, for `reminder_offer_result` (spec §6).
enum ReminderOfferResult {
  gateOpened('gate_opened'),
  skipped('skipped'),
  timeout('timeout'),
  notNow('not_now'),
  osDenied('os_denied'),
  enabled('enabled');

  const ReminderOfferResult(this.analyticsName);

  final String analyticsName;
}

/// Screen B's evening time before the parent picks one (spec §3.2): 30
/// minutes before the first brush if that was between 5:30 and 9:30 pm, on
/// the nearest quarter hour, kept between 6:30 and 9:00 pm; otherwise
/// 7:30 pm. [firstBrushTime] is the brush history's 'HH:mm', or null.
ReminderTime defaultEveningTime(String? firstBrushTime) {
  final parts = firstBrushTime?.split(':');
  if (parts == null || parts.length != 2) return kDefaultEveningTime;
  final hour = int.tryParse(parts.first);
  final minute = int.tryParse(parts.last);
  if (hour == null || minute == null) return kDefaultEveningTime;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return kDefaultEveningTime;
  }
  final brushed = hour * 60 + minute;
  if (brushed < 17 * 60 + 30 || brushed > 21 * 60 + 30) {
    return kDefaultEveningTime;
  }
  final quarter = ((brushed - 30 + 7) ~/ 15) * 15;
  return reminderTimeFromMinutes(quarter.clamp(18 * 60 + 30, 21 * 60));
}

/// Screen B's line once the reminder is on (spec §3.2).
String reminderConfirmation(ReminderSettings settings) => settings.morningOn
    ? 'Reminders set for ${formatReminderTime(settings.evening)} and '
          '${formatReminderTime(settings.morning)}'
    : 'Reminder set for ${formatReminderTime(settings.evening)}';
