// test/services/reminder_plan_test.dart
import 'package:brush_quest/services/reminder_plan.dart';
import 'package:flutter_test/flutter_test.dart';

/// The bedtime reminder's rules (spec
/// docs/superpowers/specs/2026-10-15-bedtime-reminder-design.md §2–§5).
/// Run this file under TZ=America/Los_Angeles and TZ=Europe/Paris as well:
/// the daylight-saving tests need a zone whose clocks change.
void main() {
  const evenings = ReminderSettings(eveningOn: true);
  const both = ReminderSettings(eveningOn: true, morningOn: true);
  // A Thursday, 9 am: this morning's 7:00 is gone, tonight's 7:30 is ahead.
  final thursday = DateTime(2026, 10, 15, 9);

  List<DateTime> times(Iterable<PlannedReminder> plan) => [
    for (final r in plan) r.at,
  ];
  List<PlannedReminder> only(List<PlannedReminder> plan, ReminderSlot slot) => [
    for (final r in plan)
      if (r.slot == slot) r,
  ];

  group('planReminders', () {
    test('nothing on: nothing planned', () {
      expect(
        planReminders(now: thursday, settings: const ReminderSettings()),
        isEmpty,
      );
    });

    test('a week of evenings at 7:30 pm, soonest first', () {
      final plan = planReminders(now: thursday, settings: evenings);
      expect(times(plan), [
        for (var d = 0; d < 7; d++) DateTime(2026, 10, 15 + d, 19, 30),
      ]);
      expect(plan.every((r) => r.slot == ReminderSlot.evening), isTrue);
    });

    test('mornings too, in time order with the evenings', () {
      final plan = planReminders(
        now: DateTime(2026, 10, 15, 6),
        settings: both,
      );
      expect(times(plan.take(4)), [
        DateTime(2026, 10, 15, 7),
        DateTime(2026, 10, 15, 19, 30),
        DateTime(2026, 10, 16, 7),
        DateTime(2026, 10, 16, 19, 30),
      ]);
      expect(plan, hasLength(14));
    });

    test('one id per night and per morning, each once a week', () {
      final plan = planReminders(
        now: DateTime(2026, 10, 15, 6),
        settings: both,
      );
      expect(
        {for (final r in only(plan, ReminderSlot.evening)) r.id},
        {100, 101, 102, 103, 104, 105, 106},
      );
      expect(
        {for (final r in only(plan, ReminderSlot.morning)) r.id},
        {200, 201, 202, 203, 204, 205, 206},
      );
      expect(allReminderIds(), [
        100,
        101,
        102,
        103,
        104,
        105,
        106,
        200,
        201,
        202,
        203,
        204,
        205,
        206,
      ]);
      expect(isReminderId(100), isTrue);
      expect(isReminderId(206), isTrue);
      expect(isReminderId(107), isFalse);
      expect(isReminderId(42), isFalse);
    });

    test('a night keeps its id, whenever the week is planned', () {
      final night = DateTime(2026, 10, 19, 19, 30);
      int idOn(DateTime now) => planReminders(
        now: now,
        settings: evenings,
      ).firstWhere((r) => r.at == night).id;
      expect(idOn(DateTime(2026, 10, 18, 9)), idOn(thursday));
      expect(
        reminderIdFor(ReminderSlot.evening, DateTime(2026, 10, 22)),
        reminderIdFor(ReminderSlot.evening, DateTime(2026, 10, 15)),
      );
      expect(
        reminderIdFor(ReminderSlot.evening, DateTime(2026, 10, 16)),
        isNot(reminderIdFor(ReminderSlot.evening, DateTime(2026, 10, 15))),
      );
    });

    test('nothing a week or more ahead', () {
      final plan = planReminders(now: thursday, settings: both);
      expect(plan.every((r) => r.at.isBefore(DateTime(2026, 10, 22))), isTrue);
    });

    test('a time already gone today waits for tomorrow', () {
      final plan = planReminders(
        now: DateTime(2026, 10, 15, 19, 30),
        settings: evenings,
      );
      expect(plan.first.at, DateTime(2026, 10, 16, 19, 30));
      expect(plan, hasLength(6));
    });

    test('an evening brush today drops tonight only', () {
      final plan = planReminders(
        now: DateTime(2026, 10, 15, 18),
        settings: both,
        eveningDoneToday: true,
      );
      expect(times(only(plan, ReminderSlot.evening)), [
        for (var d = 1; d < 7; d++) DateTime(2026, 10, 15 + d, 19, 30),
      ]);
      expect(times(only(plan, ReminderSlot.morning)), [
        for (var d = 1; d < 7; d++) DateTime(2026, 10, 15 + d, 7),
      ]);
    });

    test('a morning brush drops this morning only', () {
      final plan = planReminders(
        now: DateTime(2026, 10, 15, 6),
        settings: both,
        morningDoneToday: true,
      );
      expect(
        only(plan, ReminderSlot.morning).first.at,
        DateTime(2026, 10, 16, 7),
      );
      expect(
        only(plan, ReminderSlot.evening).first.at,
        DateTime(2026, 10, 15, 19, 30),
      );
    });

    test('the parent Pause: nothing before the day it ends', () {
      final plan = planReminders(
        now: thursday,
        settings: evenings,
        pauseUntil: DateTime(2026, 10, 18),
      );
      // The week starts on the day the Pause ends: the four nights the old
      // window held (18 to 21), then the three after them.
      expect(times(plan), [
        for (var d = 18; d <= 24; d++) DateTime(2026, 10, d, 19, 30),
      ]);
    });

    test('a Pause that has ended changes nothing', () {
      final plan = planReminders(
        now: thursday,
        settings: evenings,
        pauseUntil: DateTime(2026, 10, 1),
      );
      expect(plan, hasLength(7));
    });

    test("while the app is open, today's reminders wait; the rest stay", () {
      final plan = planReminders(
        now: DateTime(2026, 10, 15, 6),
        settings: both,
        appInForeground: true,
      );
      expect(plan.where((r) => r.at.day == 15), isEmpty);
      expect(plan, hasLength(12));
    });

    test('across the end of the year', () {
      final plan = planReminders(
        now: DateTime(2026, 12, 29, 9),
        settings: evenings,
      );
      expect(plan.last.at, DateTime(2027, 1, 4, 19, 30));
    });
  });

  group('the week after a Pause', () {
    // The Pause picker sets the end to the start of a date, up to 14 days
    // ahead. The week of reminders starts on the day the Pause ends, so a
    // family back from a trip is reminded without opening the app first.
    DateTime endIn(int days) => DateTime(2026, 10, 15 + days);

    test('a 10-day Pause plans exactly the 7 evenings from the day it ends '
        '(dates, ids, times)', () {
      final plan = planReminders(
        now: thursday,
        settings: evenings,
        pauseUntil: endIn(10),
      );
      expect(times(plan), [
        for (var d = 25; d <= 31; d++) DateTime(2026, 10, d, 19, 30),
      ]);
      // Ids follow the date (day number % 7), and 7 in a row never repeat.
      expect([for (final r in plan) r.id], [103, 104, 105, 106, 100, 101, 102]);
      expect(plan.every((r) => r.slot == ReminderSlot.evening), isTrue);
    });

    test('a 14-day Pause: the same, from its own end, over a month end', () {
      final plan = planReminders(
        now: thursday,
        settings: evenings,
        pauseUntil: endIn(14),
      );
      expect(times(plan), [
        for (var i = 0; i < 7; i++) DateTime(2026, 10, 29 + i, 19, 30),
      ]);
      expect(times(plan).last, DateTime(2026, 11, 4, 19, 30));
      expect([for (final r in plan) r.id], [100, 101, 102, 103, 104, 105, 106]);
    });

    for (final days in [3, 6, 7, 10, 14]) {
      test('a $days-day Pause: the plan is the one made on the morning it '
          'ends', () {
        final end = endIn(days);
        final plan = planReminders(
          now: thursday,
          settings: both,
          pauseUntil: end,
        );
        expect(plan, hasLength(14));
        expect(
          plan,
          planReminders(
            now: DateTime(end.year, end.month, end.day, 6),
            settings: both,
          ),
        );
      });
    }

    test("a Pause ending today is no Pause for today's later slots", () {
      final morning = DateTime(2026, 10, 15, 6);
      final end = DateTime(2026, 10, 15);
      expect(
        times(
          planReminders(now: morning, settings: both, pauseUntil: end),
        ).take(3),
        [
          DateTime(2026, 10, 15, 7),
          DateTime(2026, 10, 15, 19, 30),
          DateTime(2026, 10, 16, 7),
        ],
      );
      // The rules about today still apply: today is in the week.
      for (final (foreground, morningDone, eveningDone) in [
        (false, false, false),
        (true, false, false),
        (false, true, false),
        (false, false, true),
      ]) {
        expect(
          planReminders(
            now: morning,
            settings: both,
            pauseUntil: end,
            appInForeground: foreground,
            morningDoneToday: morningDone,
            eveningDoneToday: eveningDone,
          ),
          planReminders(
            now: morning,
            settings: both,
            appInForeground: foreground,
            morningDoneToday: morningDone,
            eveningDoneToday: eveningDone,
          ),
          reason:
              'foreground $foreground, morning done $morningDone, '
              'evening done $eveningDone',
        );
      }
    });

    test('the rules about today leave a week that starts later alone', () {
      final end = endIn(3);
      final plain = planReminders(
        now: thursday,
        settings: both,
        pauseUntil: end,
      );
      expect(plain, hasLength(14));
      expect(
        planReminders(
          now: thursday,
          settings: both,
          pauseUntil: end,
          appInForeground: true,
          morningDoneToday: true,
          eveningDoneToday: true,
        ),
        plain,
      );
    });

    test('a reminder at the very moment the Pause ends is kept, one before '
        'it is not', () {
      final atTheMoment = planReminders(
        now: thursday,
        settings: evenings,
        pauseUntil: DateTime(2026, 10, 18, 19, 30),
      );
      expect(times(atTheMoment), [
        for (var d = 18; d <= 24; d++) DateTime(2026, 10, d, 19, 30),
      ]);
      final aMinuteLater = planReminders(
        now: thursday,
        settings: evenings,
        pauseUntil: DateTime(2026, 10, 18, 19, 31),
      );
      expect(times(aMinuteLater), [
        for (var d = 19; d <= 24; d++) DateTime(2026, 10, d, 19, 30),
      ]);
    });

    test('with a gift coming, every night of a week that starts later is a '
        'gift night; tonight stays the exception', () {
      final later = planReminders(
        now: thursday,
        settings: evenings,
        pauseUntil: endIn(3),
        morningDoneToday: true, // today's sticker is placed
        nextStickerOpensGift: true,
      );
      expect(later, hasLength(7));
      expect({for (final r in later) r.body}, {kEveningCopyGift.body});
      final today = planReminders(
        now: thursday,
        settings: evenings,
        pauseUntil: endIn(0),
        morningDoneToday: true,
        nextStickerOpensGift: true,
      );
      expect(today.first.at, DateTime(2026, 10, 15, 19, 30));
      expect(today.first.body, isNot(kEveningCopyGift.body));
      expect({for (final r in today.skip(1)) r.body}, {kEveningCopyGift.body});
    });
  });

  group('daylight saving', () {
    // US clocks go back on Sun 1 Nov 2026 and forward on Sun 14 Mar 2027;
    // EU clocks on Sun 25 Oct 2026 and Sun 28 Mar 2027.
    for (final start in [
      DateTime(2026, 10, 22, 9),
      DateTime(2026, 10, 29, 9),
      DateTime(2027, 3, 10, 9),
      DateTime(2027, 3, 25, 9),
    ]) {
      test('from ${start.month}/${start.day}: every reminder at its own '
          "date's 7:30 pm and 7:00 am", () {
        final plan = planReminders(now: start, settings: both);
        final nights = only(plan, ReminderSlot.evening);
        expect(nights, hasLength(7));
        for (var i = 0; i < nights.length; i++) {
          final at = nights[i].at;
          expect(at, DateTime(start.year, start.month, start.day + i, 19, 30));
          expect((at.hour, at.minute), (19, 30));
          if (i > 0) {
            final before = nights[i - 1].at;
            // One day on the wall clock: 24 h, plus the hour the clocks went
            // back (or minus the hour they went forward) in between.
            expect(
              at.difference(before),
              const Duration(hours: 24) +
                  (before.timeZoneOffset - at.timeZoneOffset),
            );
          }
        }
        expect(
          {
            for (final r in only(plan, ReminderSlot.morning))
              (r.at.hour, r.at.minute),
          },
          {(7, 0)},
        );
      });

      // A Pause of 3 days puts the week on 25 Oct, 1 Nov, 13 Mar and 28 Mar:
      // the first day or the day before a clock change in some zone.
      test(
        'from ${start.month}/${start.day} with a 3-day Pause: the week '
        "from the day it ends, each at its own date's 7:30 pm and 7:00 am",
        () {
          final end = DateTime(start.year, start.month, start.day + 3);
          final plan = planReminders(
            now: start,
            settings: both,
            pauseUntil: end,
          );
          final nights = only(plan, ReminderSlot.evening);
          expect(nights, hasLength(7));
          for (var i = 0; i < nights.length; i++) {
            expect(
              nights[i].at,
              DateTime(end.year, end.month, end.day + i, 19, 30),
            );
          }
          expect(
            {
              for (final r in only(plan, ReminderSlot.morning))
                (r.at.hour, r.at.minute),
            },
            {(7, 0)},
          );
          expect({for (final r in plan) r.id}.length, 14);
        },
      );
    }

    final usChange =
        DateTime(2026, 10, 31, 19, 30).timeZoneOffset !=
        DateTime(2026, 11, 1, 19, 30).timeZoneOffset;
    final euChange =
        DateTime(2026, 10, 24, 19, 30).timeZoneOffset !=
        DateTime(2026, 10, 25, 19, 30).timeZoneOffset;
    test(
      'the night the clocks go back comes 25 hours after the one before',
      () {
        final night = usChange
            ? DateTime(2026, 11, 1, 19, 30)
            : DateTime(2026, 10, 25, 19, 30);
        final plan = planReminders(
          now: DateTime(night.year, night.month, night.day - 3, 9),
          settings: evenings,
        );
        final i = plan.indexWhere((r) => r.at == night);
        expect(i, greaterThan(0));
        expect(
          plan[i].at.difference(plan[i - 1].at),
          const Duration(hours: 25),
        );
      },
      skip: usChange || euChange
          ? false
          : 'no clock change in this zone: run with '
                'TZ=America/Los_Angeles or TZ=Europe/Paris',
    );
  });

  group('the copy', () {
    test('evenings alternate between the two approved lines', () {
      final plan = planReminders(now: thursday, settings: evenings);
      expect(
        {for (final r in plan) (r.title, r.body)},
        {
          (kEveningCopyMonsters.title, kEveningCopyMonsters.body),
          (kEveningCopyBattle.title, kEveningCopyBattle.body),
        },
      );
      for (var i = 1; i < plan.length; i++) {
        expect(plan[i].body, isNot(plan[i - 1].body));
      }
    });

    test('a night keeps its line, whenever the week is planned', () {
      final night = DateTime(2026, 10, 19, 19, 30);
      String bodyOn(DateTime now) => planReminders(
        now: now,
        settings: evenings,
      ).firstWhere((r) => r.at == night).body;
      expect(bodyOn(DateTime(2026, 10, 18, 9)), bodyOn(thursday));
    });

    test('mornings say the morning line', () {
      final plan = planReminders(
        now: DateTime(2026, 10, 15, 6),
        settings: both,
      );
      expect(
        {for (final r in only(plan, ReminderSlot.morning)) r.title},
        {kMorningCopy.title},
      );
      expect(
        {for (final r in only(plan, ReminderSlot.morning)) r.body},
        {kMorningCopy.body},
      );
    });

    test('the approved words, for the parent only', () {
      expect(kEveningCopyMonsters, (
        title: 'Brushing time!',
        body: "Tonight's cavity monsters are waiting.",
      ));
      expect(kEveningCopyBattle, (
        title: 'Bedtime brush',
        body: '2 minutes, one monster battle.',
      ));
      expect(kEveningCopyGift, (
        title: 'Brushing time!',
        body: "Tonight's brush opens a gift on the sticker card.",
      ));
      expect(kMorningCopy, (
        title: 'Morning brush',
        body: '2 minutes before the day starts.',
      ));
      for (final copy in [
        kEveningCopyMonsters,
        kEveningCopyBattle,
        kEveningCopyGift,
        kMorningCopy,
      ]) {
        final words = '${copy.title} ${copy.body}'.toLowerCase();
        for (final never in [
          'streak',
          'ranger',
          'miss',
          'lose',
          'lost',
          "don't",
          'hero',
        ]) {
          expect(words, isNot(contains(never)), reason: never);
        }
      }
    });
  });

  group('gift nights (the sticker card, Part B)', () {
    test('no gift coming: never the gift line', () {
      final plan = planReminders(now: thursday, settings: evenings);
      expect(plan.map((r) => r.body), isNot(contains(kEveningCopyGift.body)));
    });

    test('a gift next and nothing brushed today: tonight and every later '
        'night', () {
      final plan = planReminders(
        now: thursday,
        settings: evenings,
        nextStickerOpensGift: true,
      );
      expect({for (final r in plan) r.body}, {kEveningCopyGift.body});
    });

    test("brushed this morning: today's sticker is placed, so the gift is "
        'tomorrow night', () {
      final plan = planReminders(
        now: thursday,
        settings: evenings,
        morningDoneToday: true,
        nextStickerOpensGift: true,
      );
      expect(plan.first.at, DateTime(2026, 10, 15, 19, 30));
      expect(plan.first.body, isNot(kEveningCopyGift.body));
      expect({for (final r in plan.skip(1)) r.body}, {kEveningCopyGift.body});
    });

    test('mornings never carry it', () {
      final plan = planReminders(
        now: DateTime(2026, 10, 15, 6),
        settings: both,
        nextStickerOpensGift: true,
      );
      expect(
        {for (final r in only(plan, ReminderSlot.morning)) r.body},
        {kMorningCopy.body},
      );
    });
  });

  group('defaultEveningTime (the personalised default)', () {
    test('7:30 pm with no first brush, or an unreadable one', () {
      expect(defaultEveningTime(null), kDefaultEveningTime);
      expect(defaultEveningTime('oops'), kDefaultEveningTime);
      expect(defaultEveningTime('25:00'), kDefaultEveningTime);
      expect(defaultEveningTime('19:75'), kDefaultEveningTime);
    });

    test('a first brush outside 5:30 to 9:30 pm keeps 7:30 pm', () {
      expect(defaultEveningTime('07:10'), kDefaultEveningTime);
      expect(defaultEveningTime('17:29'), kDefaultEveningTime);
      expect(defaultEveningTime('21:31'), kDefaultEveningTime);
    });

    test('30 minutes before, on the nearest quarter hour', () {
      expect(defaultEveningTime('20:15'), (hour: 19, minute: 45)); // spec
      expect(defaultEveningTime('20:07'), (hour: 19, minute: 30));
      expect(defaultEveningTime('20:08'), (hour: 19, minute: 45));
      expect(defaultEveningTime('19:52'), (hour: 19, minute: 15));
    });

    test('kept between 6:30 and 9:00 pm', () {
      expect(defaultEveningTime('17:30'), (hour: 18, minute: 30));
      expect(defaultEveningTime('18:40'), (hour: 18, minute: 30));
      expect(defaultEveningTime('21:30'), (hour: 21, minute: 0));
    });
  });

  group('reminderOfferDue (spec §2)', () {
    ReminderOffer? due({
      int shown = 0,
      String? last,
      bool decided = false,
      bool on = false,
      int brushes = 1,
    }) => reminderOfferDue(
      offersShown: shown,
      lastOfferDate: last,
      decided: decided,
      remindersOn: on,
      totalBrushes: brushes,
      today: '2026-10-15',
    );

    test('offer 1 after the first finished brush', () {
      expect(due(), ReminderOffer.first);
    });

    test('offer 1 for a player from before this version (R-1)', () {
      expect(due(brushes: 40), ReminderOffer.first);
    });

    test('not before any brush', () {
      expect(due(brushes: 0), isNull);
    });

    test('offer 2: from the 3rd brush, on a later day', () {
      expect(
        due(shown: 1, last: '2026-10-14', brushes: 3),
        ReminderOffer.second,
      );
      expect(due(shown: 1, last: '2026-10-14', brushes: 2), isNull);
      expect(due(shown: 1, last: '2026-10-15', brushes: 9), isNull);
    });

    test(
      'never after a decision, while a reminder is on, or after offer 2',
      () {
        expect(due(decided: true), isNull);
        expect(
          due(shown: 1, last: '2026-10-01', brushes: 9, decided: true),
          isNull,
        );
        expect(due(on: true), isNull);
        expect(due(shown: 2, last: '2026-10-01', brushes: 9), isNull);
      },
    );

    test('the numbers and the analytics names', () {
      expect(ReminderOffer.first.number, 1);
      expect(ReminderOffer.second.number, 2);
      expect(
        [for (final r in ReminderOfferResult.values) r.analyticsName],
        [
          'gate_opened',
          'skipped',
          'timeout',
          'not_now',
          'os_denied',
          'enabled',
        ],
      );
    });
  });

  group('times and settings', () {
    test('formatReminderTime', () {
      expect(formatReminderTime((hour: 19, minute: 45)), '7:45 PM');
      expect(formatReminderTime((hour: 7, minute: 0)), '7:00 AM');
      expect(formatReminderTime((hour: 12, minute: 5)), '12:05 PM');
      expect(formatReminderTime((hour: 0, minute: 30)), '12:30 AM');
    });

    test('saved as minutes after midnight, kept inside the day', () {
      expect(reminderMinutes((hour: 19, minute: 30)), 1170);
      expect(reminderTimeFromMinutes(1170), (hour: 19, minute: 30));
      expect(reminderTimeFromMinutes(-5), (hour: 0, minute: 0));
      expect(reminderTimeFromMinutes(99999), (hour: 23, minute: 59));
    });

    test('the choices: quarter hours, 5 to 10 pm and 5:30 to 10 am', () {
      expect(eveningReminderChoices.first, (hour: 17, minute: 0));
      expect(eveningReminderChoices.last, (hour: 22, minute: 0));
      expect(eveningReminderChoices, hasLength(21));
      expect(morningReminderChoices.first, (hour: 5, minute: 30));
      expect(morningReminderChoices.last, (hour: 10, minute: 0));
      expect(morningReminderChoices, hasLength(19));
      expect(eveningReminderChoices, contains(kDefaultEveningTime));
      expect(morningReminderChoices, contains(kDefaultMorningTime));
      for (final firstBrush in ['17:30', '18:00', '19:00', '20:15', '21:30']) {
        expect(
          eveningReminderChoices,
          contains(defaultEveningTime(firstBrush)),
        );
      }
    });

    test('reminderConfirmation (spec §3.2)', () {
      const evening = (hour: 19, minute: 45);
      expect(
        reminderConfirmation(
          const ReminderSettings(eveningOn: true, evening: evening),
        ),
        'Reminder set for 7:45 PM',
      );
      expect(
        reminderConfirmation(
          const ReminderSettings(
            eveningOn: true,
            evening: evening,
            morningOn: true,
          ),
        ),
        'Reminders set for 7:45 PM and 7:00 AM',
      );
    });

    test('ReminderSettings: defaults, anyOn, copyWith, equality', () {
      const off = ReminderSettings();
      expect(off.anyOn, isFalse);
      expect(off.evening, kDefaultEveningTime);
      expect(off.morning, kDefaultMorningTime);
      expect(off.copyWith(morningOn: true).anyOn, isTrue);
      expect(
        off.copyWith(evening: (hour: 20, minute: 0)),
        const ReminderSettings(evening: (hour: 20, minute: 0)),
      );
      expect(off, isNot(off.copyWith(eveningOn: true)));
    });
  });
}
