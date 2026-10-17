// test/widgets/reminder_settings_card_test.dart
import 'package:brush_quest/services/reminder_service.dart';
import 'package:brush_quest/widgets/reminder_settings_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/reminder_fakes.dart';

/// A phone whose OS says yes to the permission prompt, but where
/// notifications are still not allowed afterwards: on Android, a parent who
/// earlier blocked only the "Brushing reminders" channel.
class _ChannelBlockedPlatform extends FakeReminderPlatform {
  @override
  Future<bool> requestPermission() async {
    final granted = await super.requestPermission();
    allowed = false;
    return granted;
  }
}

/// The Parent Zone's REMINDERS card (spec
/// docs/superpowers/specs/2026-10-15-bedtime-reminder-design.md §3.3). The
/// app is open while it shows, so today's reminder waits: the plans below
/// start tomorrow.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeReminderPlatform platform;
  late RecordingAnalytics recorder;
  late int touches;

  setUp(() {
    platform = FakeReminderPlatform();
    recorder = RecordingAnalytics();
    touches = 0;
  });

  tearDown(() {
    ReminderService.testInstance = null;
  });

  const eveningOn = <String, Object>{
    ReminderService.keyEveningEnabled: true,
    ReminderService.keyEveningTime: 19 * 60 + 30,
  };

  Finder key(String name) => find.byKey(ValueKey(name));
  bool switchOn(WidgetTester tester, String name) =>
      tester.widget<Switch>(key(name)).value;
  List<Object?> results() => [
    for (final e in recorder.named('reminder_offer_result')) e['result'],
  ];

  Future<void> pumpCard(
    WidgetTester tester, [
    Map<String, Object> saved = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(saved);
    await installReminderService(
      platform: platform,
      recorder: recorder,
      now: () => DateTime(2026, 10, 15, 9),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReminderSettingsCard(onInteraction: () => touches++),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('off: both switches off, no time, no note, the OS not asked', (
    tester,
  ) async {
    await pumpCard(tester);
    expect(find.text('Bedtime reminder'), findsOneWidget);
    expect(find.text('Morning reminder'), findsOneWidget);
    expect(
      find.text("Only if that brush hasn't happened yet. Stays on this phone."),
      findsOneWidget,
    );
    expect(switchOn(tester, 'reminder_evening_switch'), isFalse);
    expect(switchOn(tester, 'reminder_morning_switch'), isFalse);
    expect(key('reminder_evening_time'), findsNothing);
    expect(key('reminder_blocked'), findsNothing);
    expect(platform.calls, isNot(contains('notificationsAllowed')));
  });

  testWidgets('the bedtime switch on: the OS asked, then on, timed and '
      'planned', (tester) async {
    await pumpCard(tester);
    await tester.tap(key('reminder_evening_switch'));
    await tester.pumpAndSettle();
    expect(platform.permissionRequests, 1);
    expect(switchOn(tester, 'reminder_evening_switch'), isTrue);
    expect(find.text('7:30 PM'), findsOneWidget);
    expect(platform.pendingTimes.first, DateTime(2026, 10, 16, 19, 30));
    expect(recorder.named('reminder_offer_shown'), [
      {'name': 'reminder_offer_shown', 'offer': 'parent_zone'},
    ]);
    expect(results(), ['enabled']);
    expect(touches, 1);
  });

  testWidgets('the OS refuses: still off, the note, and Open phone settings '
      'opens them', (tester) async {
    platform.grant = false;
    await pumpCard(tester);
    await tester.tap(key('reminder_evening_switch'));
    await tester.pumpAndSettle();
    expect(switchOn(tester, 'reminder_evening_switch'), isFalse);
    expect(
      find.text(
        'Notifications for Brush Quest are off in your phone settings.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Open phone settings'));
    await tester.pump();
    expect(platform.openSettingsCalls, 1);
    final saved = await SharedPreferences.getInstance();
    expect(saved.getBool(ReminderService.keyEveningEnabled), isNot(isTrue));
    expect(results(), ['os_denied']);
  });

  testWidgets('turned on while only the reminders channel is blocked: the '
      'note shows at once', (tester) async {
    platform = _ChannelBlockedPlatform();
    await pumpCard(tester);
    expect(key('reminder_blocked'), findsNothing);
    await tester.tap(key('reminder_evening_switch'));
    await tester.pumpAndSettle();
    // The OS said yes, so the reminder is on and planned...
    expect(platform.permissionRequests, 1);
    expect(switchOn(tester, 'reminder_evening_switch'), isTrue);
    expect(results(), ['enabled']);
    // ...but notifications are still off for it, and the parent is told now,
    // not at the next time the card opens.
    expect(key('reminder_blocked'), findsOneWidget);
    expect(
      find.text(
        'Notifications for Brush Quest are off in your phone settings.',
      ),
      findsOneWidget,
    );
    expect(find.text('Open phone settings'), findsOneWidget);
  });

  testWidgets('on, but off in the phone: the card says so as it opens', (
    tester,
  ) async {
    await pumpCard(tester, eveningOn);
    expect(switchOn(tester, 'reminder_evening_switch'), isTrue);
    expect(key('reminder_blocked'), findsOneWidget);
  });

  testWidgets("back from the phone's settings with notifications allowed: "
      'the note goes', (tester) async {
    await pumpCard(tester, eveningOn);
    expect(key('reminder_blocked'), findsOneWidget);
    await tester.tap(key('reminder_open_settings'));
    await tester.pump();
    platform.allowed = true; // the parent allowed them there
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();
    expect(key('reminder_blocked'), findsNothing);
  });

  testWidgets('turning it off cancels the waiting reminders and asks nothing', (
    tester,
  ) async {
    platform.allowed = true;
    await pumpCard(tester, eveningOn);
    expect(platform.pending, isNotEmpty);
    await tester.tap(key('reminder_evening_switch'));
    await tester.pumpAndSettle();
    expect(switchOn(tester, 'reminder_evening_switch'), isFalse);
    expect(platform.pending, isEmpty);
    expect(platform.permissionRequests, 0);
  });

  testWidgets('a new time is saved and planned', (tester) async {
    platform.allowed = true;
    await pumpCard(tester, eveningOn);
    // Which times an open menu shows depends on where the card sits on the
    // screen; the menu itself is ReminderTimeDropdown's own test. Pick as the
    // menu does.
    final list = tester.widget<DropdownButton<int>>(
      find.descendant(
        of: key('reminder_evening_time'),
        matching: find.byType(DropdownButton<int>),
      ),
    );
    list.onChanged!(19 * 60);
    await tester.pumpAndSettle();
    final saved = await SharedPreferences.getInstance();
    expect(saved.getInt(ReminderService.keyEveningTime), 19 * 60);
    expect(platform.pendingTimes.first, DateTime(2026, 10, 16, 19));
    expect(touches, 1);
  });

  testWidgets('a saved time that is not on the list still shows', (
    tester,
  ) async {
    platform.allowed = true;
    await pumpCard(tester, {
      ReminderService.keyEveningEnabled: true,
      ReminderService.keyEveningTime: 18 * 60 + 10,
    });
    expect(find.text('6:10 PM'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the morning reminder: its own switch, at 7:00 AM', (
    tester,
  ) async {
    await pumpCard(tester);
    await tester.tap(key('reminder_morning_switch'));
    await tester.pumpAndSettle();
    expect(switchOn(tester, 'reminder_morning_switch'), isTrue);
    expect(switchOn(tester, 'reminder_evening_switch'), isFalse);
    expect(find.text('7:00 AM'), findsOneWidget);
    expect(platform.pendingTimes.first, DateTime(2026, 10, 16, 7));
  });

  testWidgets('360 px wide, the largest text: nothing overflows', (
    tester,
  ) async {
    platform.allowed = true;
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({
      ...eveningOn,
      ReminderService.keyMorningEnabled: true,
      ReminderService.keyMorningTime: 7 * 60,
    });
    await installReminderService(platform: platform, recorder: recorder);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: ReminderSettingsCard(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
