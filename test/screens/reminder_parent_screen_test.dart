// test/screens/reminder_parent_screen_test.dart
import 'package:brush_quest/screens/after_brush_home.dart';
import 'package:brush_quest/screens/reminder_parent_screen.dart';
import 'package:brush_quest/services/reminder_service.dart';
import 'package:brush_quest/widgets/space_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/reminder_fakes.dart';

/// Screen B of the bedtime reminder (spec
/// docs/superpowers/specs/2026-10-15-bedtime-reminder-design.md §3.2), behind
/// the GROWN-UP CHECK: the explanation first, the OS prompt only from TURN
/// ON, and the reminder saved only if the OS allows it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeReminderPlatform platform;
  late RecordingAnalytics recorder;

  setUpAll(() async {
    // The app's own font: the small-phone test measures real text.
    final fredoka = FontLoader('Fredoka')
      ..addFont(
        rootBundle.load(
          'assets/fonts/Fredoka/Fredoka-VariableFont_wdth_wght.ttf',
        ),
      );
    await fredoka.load();
  });

  setUp(() {
    platform = FakeReminderPlatform();
    recorder = RecordingAnalytics();
    AfterBrushHome.debugBuilder = (_) => const Scaffold(body: Text('HOME'));
  });

  tearDown(() {
    ReminderService.testInstance = null;
    AfterBrushHome.debugBuilder = null;
  });

  Finder key(String name) => find.byKey(ValueKey(name));
  List<Object?> results() => [
    for (final e in recorder.named('reminder_offer_result')) e['result'],
  ];
  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

  Future<void> pumpScreen(
    WidgetTester tester, {
    Map<String, Object> saved = const {},
    Size size = const Size(430, 932),
    double textScale = 1,
  }) async {
    SharedPreferences.setMockInitialValues(saved);
    await installReminderService(
      platform: platform,
      recorder: recorder,
      now: () => DateTime(2026, 10, 15, 9),
    );
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Fredoka'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const ReminderParentScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Opens the [list] of times and picks [time]. The open list shows the
  /// times up to the current one, so tests pick an earlier time.
  Future<void> pick(WidgetTester tester, String list, String time) async {
    await tester.tap(key(list));
    await tester.pumpAndSettle();
    await tester.tap(find.text(time).last);
    await tester.pumpAndSettle();
  }

  /// TURN ON, and the frame after the OS has answered.
  Future<void> turnOn(WidgetTester tester) async {
    await tester.tap(key('parent_turn_on'));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('says what the reminder is, before any OS prompt', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(find.text('FOR GROWN-UPS'), findsOneWidget);
    expect(find.text('Want a bedtime brushing reminder?'), findsOneWidget);
    expect(
      find.text(
        "One reminder on this phone each evening, only if brushing hasn't "
        'happened yet. Your reminder times stay on this phone.',
      ),
      findsOneWidget,
    );
    expect(find.text('Remind me at'), findsOneWidget);
    expect(find.text('7:30 PM'), findsOneWidget);
    expect(find.text('Morning reminder too'), findsOneWidget);
    expect(tester.widget<Checkbox>(key('parent_morning_check')).value, isFalse);
    expect(find.text('7:00 AM'), findsOneWidget);
    expect(find.text('TURN ON'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    expect(
      find.text('Change or turn off anytime: Parents > Settings > Reminders'),
      findsOneWidget,
    );
    expect(platform.permissionRequests, 0);
  });

  testWidgets('the evening time starts 30 minutes before the first brush', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      saved: {
        'brush_history': [
          '{"date":"2026-10-14","time":"20:15","heroId":"blaze","worldId":"candy_crater"}',
        ],
      },
    );
    expect(find.text('7:45 PM'), findsOneWidget);
  });

  testWidgets('TURN ON, allowed: saved, "Reminder set for 7:30 PM", then '
      'Home', (tester) async {
    await pumpScreen(tester);
    await turnOn(tester);
    expect(platform.permissionRequests, 1);
    expect(find.text('Reminder set for 7:30 PM'), findsOneWidget);
    expect(key('parent_confirmation'), findsOneWidget);
    expect(key('parent_turn_on'), findsNothing);
    final saved = await prefs();
    expect(saved.getBool(ReminderService.keyEveningEnabled), isTrue);
    expect(saved.getInt(ReminderService.keyEveningTime), 19 * 60 + 30);
    expect(saved.getBool(ReminderService.keyMorningEnabled), isFalse);
    expect(results(), ['enabled']);
    await tester.pump(const Duration(milliseconds: 2400));
    expect(find.text('HOME'), findsNothing);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('new times and the morning ticked: both saved, both confirmed', (
    tester,
  ) async {
    await pumpScreen(tester);
    await pick(tester, 'parent_evening_time', '7:00 PM');
    await tester.tap(key('parent_morning_check'));
    await tester.pump();
    await pick(tester, 'parent_morning_time', '6:45 AM');
    await turnOn(tester);
    expect(find.text('Reminders set for 7:00 PM and 6:45 AM'), findsOneWidget);
    final saved = await prefs();
    expect(saved.getInt(ReminderService.keyEveningTime), 19 * 60);
    expect(saved.getBool(ReminderService.keyMorningEnabled), isTrue);
    expect(saved.getInt(ReminderService.keyMorningTime), 6 * 60 + 45);
    expect(recorder.named('reminder_enabled'), [
      {'name': 'reminder_enabled', 'morning': 1},
    ]);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('the morning time waits for the box to be ticked', (
    tester,
  ) async {
    await pumpScreen(tester);
    final morning = tester.widget<DropdownButton<int>>(
      find.descendant(
        of: key('parent_morning_time'),
        matching: find.byType(DropdownButton<int>),
      ),
    );
    expect(morning.onChanged, isNull);
  });

  testWidgets('the OS says no: nothing on, no more offers, straight Home', (
    tester,
  ) async {
    platform.grant = false;
    await pumpScreen(tester);
    await turnOn(tester);
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    final saved = await prefs();
    expect(saved.containsKey(ReminderService.keyEveningEnabled), isFalse);
    expect(saved.getBool(ReminderService.keyDecided), isTrue);
    expect(results(), ['os_denied']);
    expect(platform.pending, isEmpty);
  });

  testWidgets('Not now: Home, no OS prompt, no more offers', (tester) async {
    await pumpScreen(tester);
    await tester.tap(key('parent_not_now'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    expect(platform.permissionRequests, 0);
    expect((await prefs()).getBool(ReminderService.keyDecided), isTrue);
    expect(results(), ['not_now']);
  });

  testWidgets('a double tap on TURN ON asks the OS once', (tester) async {
    await pumpScreen(tester);
    await tester.tap(key('parent_turn_on'));
    await tester.tap(key('parent_turn_on'), warnIfMissed: false);
    await tester.pump();
    await tester.pump();
    expect(platform.permissionRequests, 1);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('leaving while "Reminder set" shows leaves no timer behind', (
    tester,
  ) async {
    await pumpScreen(tester);
    await turnOn(tester);
    expect(key('parent_confirmation'), findsOneWidget);
    // A pending Timer at the end of a test fails it: dispose must cancel.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the toothbrush shows as its own picture, not a tinted square', (
    tester,
  ) async {
    await pumpScreen(tester);
    // The art is an opaque tile: tinting it (ImageIcon with a colour) would
    // paint a solid square.
    expect(find.byType(ImageIcon), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.color == null &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName ==
                'assets/images/icon_toothbrush.png',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the space background fills a tall phone, not just the text', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(tester.getSize(find.byType(SpaceBackground)), const Size(430, 932));
  });

  testWidgets('360x640 at the largest text size: nothing overflows', (
    tester,
  ) async {
    await pumpScreen(tester, size: const Size(360, 640), textScale: 1.3);
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -800),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Change or turn off anytime: Parents > Settings > Reminders'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
