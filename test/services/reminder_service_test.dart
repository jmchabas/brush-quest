// test/services/reminder_service_test.dart
import 'dart:async';
import 'dart:io';

import 'package:brush_quest/services/reminder_plan.dart';
import 'package:brush_quest/services/reminder_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'reminder_fakes.dart';

/// ReminderService (spec
/// docs/superpowers/specs/2026-10-15-bedtime-reminder-design.md §2–§6): what
/// it plans and when, the offers, and that the notification system can never
/// break the app. The clock is a Thursday, 9 am, unless a test moves it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeReminderPlatform platform;
  late RecordingAnalytics recorder;
  late DateTime now;
  late DebugPrintCallback originalDebugPrint;

  setUp(() {
    platform = FakeReminderPlatform();
    recorder = RecordingAnalytics();
    now = DateTime(2026, 10, 15, 9);
    // The guards log the failures they absorb: not printed into the test run.
    originalDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {};
  });

  tearDown(() {
    debugPrint = originalDebugPrint;
    ReminderService.testInstance = null;
  });

  Future<ReminderService> service({
    Map<String, Object> prefs = const {},
    GiftNightCheck gift = noStickerGifts,
    bool initialise = true,
  }) {
    SharedPreferences.setMockInitialValues(prefs);
    return installReminderService(
      platform: platform,
      recorder: recorder,
      now: () => now,
      nextStickerOpensGift: gift,
      initialise: initialise,
    );
  }

  const eveningOn = <String, Object>{
    ReminderService.keyEveningEnabled: true,
    ReminderService.keyEveningTime: 19 * 60 + 30,
  };

  /// 7:30 pm on each date of October 2026 from [first] to [last].
  List<DateTime> nights(int first, int last) => [
    for (var d = first; d <= last; d++) DateTime(2026, 10, d, 19, 30),
  ];

  List<Object?> results() => [
    for (final e in recorder.named('reminder_offer_result')) e['result'],
  ];

  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

  group('start-up', () {
    test('sets the plugin up and asks for no permission', () async {
      await service();
      expect(platform.calls.first, 'init');
      expect(platform.permissionRequests, 0);
    });

    test('plans the week; the app being open holds tonight back', () async {
      await service(prefs: eveningOn);
      expect(platform.pendingTimes, nights(16, 21));
    });

    test('a reminder that started the app is counted', () async {
      platform.launchSlotValue = 'evening';
      await service();
      expect(recorder.named('app_open_from_reminder'), [
        {'name': 'app_open_from_reminder', 'slot': 'evening'},
      ]);
    });

    test('a tap while the app runs is counted', () async {
      await service();
      platform.onTap!('morning');
      await pumpEventQueue();
      expect(recorder.named('app_open_from_reminder'), [
        {'name': 'app_open_from_reminder', 'slot': 'morning'},
      ]);
    });

    test('the reminder_on user property follows the setting', () async {
      await service(prefs: eveningOn);
      expect(recorder.properties['reminder_on'], 'true');
    });

    test('nothing touches the plugin before init', () async {
      final s = await service(prefs: eveningOn, initialise: false);
      await s.reschedule();
      await s.onAppPaused();
      await s.resetAll();
      expect(platform.calls, isEmpty);
    });

    test('init with a failing plugin leaves reminders off, quietly', () async {
      platform.failure = StateError('no plugin');
      final s = await service(prefs: eveningOn);
      platform.failure = null;
      await s.onAppPaused();
      expect(platform.calls, ['init']);
      expect(platform.pending, isEmpty);
    });
  });

  group('the week', () {
    test(
      'leaving the app brings tonight back; coming back holds it again',
      () async {
        final s = await service(prefs: eveningOn);
        await s.onAppPaused();
        expect(platform.pendingTimes, nights(15, 21));
        await s.onAppResumed();
        expect(platform.pendingTimes, nights(16, 21));
      },
    );

    test(
      "a brush this evening drops tonight's reminder, not tomorrow's",
      () async {
        now = DateTime(2026, 10, 15, 18);
        final s = await service(
          prefs: {...eveningOn, 'evening_done_date': '2026-10-15'},
        );
        await s.onAppPaused();
        expect(platform.pendingTimes, nights(16, 21));
      },
    );

    test('a morning brush leaves tonight on', () async {
      final s = await service(
        prefs: {...eveningOn, 'morning_done_date': '2026-10-15'},
      );
      await s.onAppPaused();
      expect(platform.pendingTimes, nights(15, 21));
    });

    test('the parent Pause holds every reminder before its end', () async {
      final s = await service(
        prefs: {
          ...eveningOn,
          'streak_pause_until': DateTime(2026, 10, 18).toIso8601String(),
        },
      );
      await s.onAppPaused();
      // The week starts on the day the Pause ends.
      expect(platform.pendingTimes, nights(18, 24));
    });

    test('a Pause of a week or more still leaves the week after it planned, '
        'with nothing opened in between', () async {
      final s = await service(
        prefs: {
          ...eveningOn,
          'streak_pause_until': DateTime(2026, 10, 25).toIso8601String(),
        },
      );
      await s.onAppPaused();
      // Seven nights, seven ids: a repeated id would have replaced a night.
      expect(platform.pendingTimes, nights(25, 31));
    });

    test(
      'a Pause set while reminders wait cancels the nights it covers',
      () async {
        final s = await service(prefs: eveningOn);
        await s.onAppPaused();
        expect(platform.pendingTimes, nights(15, 21));
        final saved = await prefs();
        await saved.setString(
          'streak_pause_until',
          DateTime(2026, 10, 18).toIso8601String(),
        );
        await s.reschedule();
        expect(platform.pendingTimes, nights(18, 24));
      },
    );

    test('with a reminder on, every reminder id is cleared first, shown ones '
        'too', () async {
      final s = await service(prefs: eveningOn);
      platform.cancelled.clear();
      await s.onAppPaused();
      expect(platform.cancelled.toSet(), allReminderIds().toSet());
    });

    test(
      'turning everything off cancels what waits, and nothing else',
      () async {
        final s = await service(prefs: eveningOn);
        await s.onAppPaused();
        platform.pending[7] = PlannedReminder(
          id: 7,
          slot: ReminderSlot.evening,
          at: DateTime(2026, 10, 20),
          title: 'not ours',
          body: 'not ours',
        );
        await s.saveSettings(const ReminderSettings());
        expect(platform.pending.keys, [7]);
        expect(platform.cancelled, isNot(contains(7)));
      },
    );

    test('turning everything off still clears every reminder when the plugin '
        'cannot list what waits', () async {
      final s = await service(prefs: eveningOn);
      await s.onAppPaused();
      expect(platform.pendingTimes, nights(15, 21));
      platform
        ..pendingIdsError = StateError('cannot list')
        ..cancelled.clear();
      await s.saveSettings(const ReminderSettings());
      expect(platform.pending, isEmpty);
      expect(platform.cancelled.toSet(), allReminderIds().toSet());
    });

    test('one instant that fails to schedule does not stop the rest', () async {
      platform.failScheduleFor = {
        reminderIdFor(ReminderSlot.evening, DateTime(2026, 10, 17)),
      };
      final s = await service(prefs: eveningOn);
      await s.onAppPaused();
      expect(platform.pendingTimes, [...nights(15, 16), ...nights(18, 21)]);
    });

    test(
      'calls that overlap make one more plan, after the last change',
      () async {
        final s = await service(prefs: eveningOn);
        platform.calls.clear();
        final hold = Completer<void>();
        platform.holdSchedule = hold;
        final first = s.onAppPaused();
        final second = s.onAppResumed();
        final third = s.onAppPaused();
        await pumpEventQueue(); // the first plan now waits inside schedule()
        final saved = await prefs();
        await saved.setBool(ReminderService.keyEveningEnabled, false);
        hold.complete();
        await Future.wait([first, second, third]);
        // Two plans, not three: the first, then one more with the reminder off
        // (only a plan with nothing on asks what waits).
        expect(platform.calls.where((c) => c == 'pendingIds'), hasLength(1));
        expect(platform.pending, isEmpty);
      },
    );
  });

  group('failures', () {
    for (final failure in [
      (name: 'an Exception', value: Exception('MissingPluginException')),
      (name: 'an Error', value: StateError('LateInitializationError')),
    ]) {
      test('a failing plugin never throws (${failure.name})', () async {
        final s = await service(prefs: eveningOn);
        platform.failure = failure.value;
        await expectLater(s.onAppPaused(), completes);
        await expectLater(
          s.turnOn(const ReminderSettings(eveningOn: true)),
          completion(isFalse),
        );
        await expectLater(s.notificationsAllowed(), completion(isFalse));
        await expectLater(s.openPhoneSettings(), completes);
        await expectLater(s.resetAll(), completes);
        await expectLater(s.offerDue(), completes);
      });
    }

    test('a failing gift check means no gift line', () async {
      final s = await service(
        prefs: eveningOn,
        gift: () async => throw StateError('card'),
      );
      await s.onAppPaused();
      expect(platform.pending, hasLength(7));
      expect(
        platform.pending.values.map((r) => r.body),
        isNot(contains(kEveningCopyGift.body)),
      );
    });
  });

  group('turning it on', () {
    test('asks the OS, then saves and plans; no more hand-offs', () async {
      final s = await service();
      final on = await s.turnOn(
        const ReminderSettings(
          eveningOn: true,
          evening: (hour: 19, minute: 45),
        ),
      );
      expect(on, isTrue);
      expect(platform.permissionRequests, 1);
      final saved = await prefs();
      expect(saved.getBool(ReminderService.keyEveningEnabled), isTrue);
      expect(saved.getInt(ReminderService.keyEveningTime), 19 * 60 + 45);
      expect(saved.getBool(ReminderService.keyMorningEnabled), isFalse);
      expect(saved.getBool(ReminderService.keyDecided), isTrue);
      expect(results(), ['enabled']);
      expect(recorder.named('reminder_enabled'), [
        {'name': 'reminder_enabled', 'evening_hour': 19, 'morning': 0},
      ]);
      expect(recorder.properties['reminder_on'], 'true');
      // The app is open (Screen B): tonight waits for it to be left.
      expect(platform.pendingTimes.first, DateTime(2026, 10, 16, 19, 45));
    });

    test("the OS says no: nothing saved as on, and it was the parent's "
        'decision', () async {
      platform.grant = false;
      final s = await service();
      expect(await s.turnOn(const ReminderSettings(eveningOn: true)), isFalse);
      final saved = await prefs();
      expect(saved.containsKey(ReminderService.keyEveningEnabled), isFalse);
      expect(saved.getBool(ReminderService.keyDecided), isTrue);
      expect(platform.pending, isEmpty);
      expect(results(), ['os_denied']);
      expect(recorder.named('reminder_enabled'), isEmpty);
    });

    test('saveSettings never turns a reminder on: only turnOn can', () async {
      final s = await service();
      await s.saveSettings(
        const ReminderSettings(eveningOn: true, morningOn: true),
      );
      expect((await s.settings()).anyOn, isFalse);
      expect(platform.permissionRequests, 0);
      expect(platform.pending, isEmpty);
    });

    test('a new time while on is planned at once', () async {
      final s = await service(prefs: eveningOn);
      await s.onAppPaused();
      await s.saveSettings(
        const ReminderSettings(eveningOn: true, evening: (hour: 20, minute: 0)),
      );
      expect(platform.pendingTimes.first, DateTime(2026, 10, 15, 20));
      expect(platform.pendingTimes, hasLength(7));
    });
  });

  group('settings', () {
    test(
      'nothing saved: both off, the evening time from the first brush',
      () async {
        final s = await service(
          prefs: {
            'brush_history': [
              '{"date":"2026-10-12","time":"20:15","heroId":"blaze","worldId":"candy_crater"}',
              '{"date":"2026-10-14","time":"07:05","heroId":"blaze","worldId":"candy_crater"}',
            ],
          },
          initialise: false,
        );
        final settings = await s.settings();
        expect(settings.anyOn, isFalse);
        expect(settings.evening, (hour: 19, minute: 45));
        expect(settings.morning, kDefaultMorningTime);
      },
    );

    test('an unreadable history suggests 7:30 pm', () async {
      final s = await service(
        prefs: {
          'brush_history': ['{"date":"2026-10-14"}'],
        },
        initialise: false,
      );
      expect((await s.settings()).evening, kDefaultEveningTime);
    });

    test(
      'a saved time is kept; a saved value of the wrong type is ignored',
      () async {
        final s = await service(
          prefs: {
            ReminderService.keyEveningTime: 20 * 60,
            ReminderService.keyMorningTime: 'oops',
          },
          initialise: false,
        );
        final settings = await s.settings();
        expect(settings.evening, (hour: 20, minute: 0));
        expect(settings.morning, kDefaultMorningTime);
      },
    );
  });

  group('offers (spec §2)', () {
    test('the first brush: offer 1; showing it saves its number and the '
        'date', () async {
      final s = await service(prefs: {'total_brushes': 1}, initialise: false);
      expect(await s.offerDue(), ReminderOffer.first);
      await s.noteOfferShown(ReminderOffer.first);
      final saved = await prefs();
      expect(saved.getInt(ReminderService.keyOfferCount), 1);
      expect(saved.getString(ReminderService.keyOfferLastDate), '2026-10-15');
      expect(await s.offerDue(), isNull);
      expect(recorder.named('reminder_offer_shown'), [
        {'name': 'reminder_offer_shown', 'offer': '1'},
      ]);
    });

    test('skipped yesterday: offer 2 from the 3rd brush', () async {
      final s = await service(
        prefs: {
          'total_brushes': 3,
          ReminderService.keyOfferCount: 1,
          ReminderService.keyOfferLastDate: '2026-10-14',
        },
        initialise: false,
      );
      expect(await s.offerDue(), ReminderOffer.second);
    });

    test('offer 2 never comes the day offer 1 was made; the dates are the '
        "service clock's, zero-padded yyyy-mm-dd", () async {
      now = DateTime(2026, 3, 7, 20); // one-digit month and day
      final s = await service(prefs: {'total_brushes': 1}, initialise: false);
      await s.noteOfferShown(ReminderOffer.first);
      final saved = await prefs();
      expect(saved.getString(ReminderService.keyOfferLastDate), '2026-03-07');
      await saved.setInt('total_brushes', 3);
      expect(await s.offerDue(), isNull); // the same day
      now = DateTime(2026, 3, 8, 20);
      expect(await s.offerDue(), ReminderOffer.second); // a later day
    });

    test('skip, timeout and the gate leave offer 2 open; "Not now" ends the '
        'offers', () async {
      final s = await service(
        prefs: {
          'total_brushes': 3,
          ReminderService.keyOfferCount: 1,
          ReminderService.keyOfferLastDate: '2026-10-14',
        },
        initialise: false,
      );
      await s.noteOfferResult(ReminderOfferResult.skipped);
      await s.noteOfferResult(ReminderOfferResult.timeout);
      await s.noteOfferResult(ReminderOfferResult.gateOpened);
      expect(await s.offerDue(), ReminderOffer.second);
      await s.noteOfferResult(ReminderOfferResult.notNow);
      expect(await s.offerDue(), isNull);
      expect(results(), ['skipped', 'timeout', 'gate_opened', 'not_now']);
    });

    test('no offer while a reminder is on', () async {
      final s = await service(
        prefs: {...eveningOn, 'total_brushes': 1},
        initialise: false,
      );
      expect(await s.offerDue(), isNull);
    });

    test('the Parent Zone counts as an offer of its own', () async {
      final s = await service(initialise: false);
      s.noteParentZoneOffer();
      await pumpEventQueue();
      expect(recorder.named('reminder_offer_shown'), [
        {'name': 'reminder_offer_shown', 'offer': 'parent_zone'},
      ]);
    });

    test('offers read saved state only: they never touch the plugin', () async {
      final s = await service(prefs: {'total_brushes': 1});
      platform.calls.clear();
      await s.offerDue();
      await s.noteOfferShown(ReminderOffer.first);
      await s.noteOfferResult(ReminderOfferResult.skipped);
      expect(platform.calls, isEmpty);
    });
  });

  group('gift nights (Part B wires the check)', () {
    test(
      'until the sticker card ships, no reminder carries the gift line',
      () async {
        final s = await service(prefs: eveningOn);
        await s.onAppPaused();
        expect(
          platform.pending.values.map((r) => r.body),
          isNot(contains(kEveningCopyGift.body)),
        );
      },
    );

    test(
      'a gift next and nothing brushed today: every night says it',
      () async {
        final s = await service(prefs: eveningOn, gift: () async => true);
        await s.onAppPaused();
        expect(
          {for (final r in platform.pending.values) r.body},
          {kEveningCopyGift.body},
        );
      },
    );

    test('the card is asked only when the evening reminder is on', () async {
      var asked = 0;
      Future<bool> gift() async {
        asked++;
        return true;
      }

      final s = await service(
        prefs: {
          ReminderService.keyMorningEnabled: true,
          ReminderService.keyMorningTime: 7 * 60,
        },
        gift: gift,
      );
      await s.onAppPaused();
      expect(asked, 0);
      expect(platform.pending, isNotEmpty);
    });
  });

  test(
    'Start fresh: everything cancelled, every reminder key forgotten',
    () async {
      final s = await service(
        prefs: {
          ...eveningOn,
          ReminderService.keyMorningEnabled: true,
          ReminderService.keyMorningTime: 7 * 60,
          ReminderService.keyDecided: true,
          ReminderService.keyOfferCount: 2,
          ReminderService.keyOfferLastDate: '2026-10-01',
        },
      );
      await s.resetAll();
      expect(platform.cancelAllCalls, 1);
      expect(platform.pending, isEmpty);
      final saved = await prefs();
      for (final key in ReminderService.allKeys) {
        expect(saved.containsKey(key), isFalse, reason: key);
      }
      expect(recorder.properties['reminder_on'], 'false');
    },
  );

  test('the keys stay on this device: none is synced', () {
    final sync = File('lib/services/sync_service.dart').readAsStringSync();
    expect(sync, isNot(contains("'reminder_")));
    for (final key in ReminderService.allKeys) {
      expect(key, startsWith('reminder_'));
    }
  });
}
