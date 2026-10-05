import 'package:brush_quest/route_observer.dart';
import 'package:brush_quest/screens/home_screen.dart';
import 'package:brush_quest/screens/pre_brush_screen.dart';
import 'package:brush_quest/services/audio_service.dart';
import 'package:brush_quest/services/flame_tier.dart';
import 'package:brush_quest/widgets/flame_view.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/fake_audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAudioService fakeAudio;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();

    // Mock audioplayers platform channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers.global'),
          (call) async => 1,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers'),
          (call) async => 1,
        );
  });

  setUp(() {
    fakeAudio = FakeAudioService();
    AudioService.testInstance = fakeAudio;
  });

  tearDown(() {
    AudioService.testInstance = null;
  });

  test('welcome line matches the daily bonus', () {
    expect(HomeScreen.welcomeFlameVoiceFor(0), isNull);
    expect(HomeScreen.welcomeFlameVoiceFor(1), 'voice_flame_welcome_1.mp3');
    expect(HomeScreen.welcomeFlameVoiceFor(2), 'voice_flame_welcome_2.mp3');
  });

  String day(int offset) {
    final d = DateTime.now().add(Duration(days: offset));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> pumpHomeWith(
    WidgetTester tester,
    Map<String, Object> extra, {
    bool skipGreeting = true,
    double width = 430,
    double topInset = 0,
    List<NavigatorObserver> observers = const [],
    int settleSteps = 6,
  }) async {
    SharedPreferences.setMockInitialValues({
      'selected_hero': 'blaze',
      'selected_weapon': 'star_blaster',
      'total_brushes': 5,
      'camera_mode_configured': true,
      'muted': false,
      ...extra,
    });
    await tester.binding.setSurfaceSize(Size(width, 932));
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: observers,
        // A status-bar inset: Home's SafeArea shifts the stack down by it.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(padding: EdgeInsets.only(top: topInset)),
          child: child!,
        ),
        home: HomeScreen(skipGreeting: skipGreeting),
      ),
    );
    await tester.pump();
    for (var i = 0; i < settleSteps; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  Future<void> disposeAll(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    await tester.binding.setSurfaceSize(null);
  }

  int whooshes() => fakeAudio.playedSfx.where((s) => s == 'whoosh.mp3').length;

  Iterable<String> flameVoices() =>
      fakeAudio.playedVoiceLines.where((v) => v.startsWith('voice_flame_'));

  Future<int?> lastSeenTier() async =>
      (await SharedPreferences.getInstance()).getInt('last_seen_flame_tier');

  // The pill's own box: the nearest Container around the finder's widget.
  Offset pillCentre(WidgetTester tester, Finder inside) => tester.getCenter(
    find.ancestor(of: inside, matching: find.byType(Container)).first,
  );

  // The scale Home's pulse puts on the pill around [inside] (1.0 at rest).
  double pillScale(WidgetTester tester, Finder inside) => tester
      .widget<Transform>(
        find.ancestor(of: inside, matching: find.byType(Transform)).first,
      )
      .transform
      .getMaxScaleOnAxis();

  double streakPillScale(WidgetTester tester) =>
      pillScale(tester, find.byType(FlameIcon));

  group('streak pill', () {
    for (final (streak, tier) in [
      (1, FlameTier.small),
      (3, FlameTier.big),
      (7, FlameTier.hot),
      (14, FlameTier.golden),
    ]) {
      testWidgets('a $streak day streak shows the ${tier.name} flame', (
        tester,
      ) async {
        // 500 wide: the test font gives every digit 22 px (Fredoka's are about
        // 10), so a two-digit streak next to the golden flame would not fit
        // the pill at phone width here, whatever it does on a device.
        await pumpHomeWith(tester, {
          'current_streak': streak,
          'last_brush_date': day(0),
        }, width: 500);
        final tiers = tester
            .widgetList<FlameIcon>(find.byType(FlameIcon))
            .map((w) => w.tier);
        expect(tiers, [tier]);
        expect(find.text('$streak'), findsOneWidget);
        await disposeAll(tester);
      });
    }

    testWidgets('a child with no brush yet sees the dim empty flame', (
      tester,
    ) async {
      await pumpHomeWith(tester, {'total_brushes': 0, 'current_streak': 0});
      expect(
        tester.widgetList<FlameIcon>(find.byType(FlameIcon)).map((w) => w.tier),
        [FlameTier.none],
      );
      await disposeAll(tester);
    });

    testWidgets('a broken streak keeps the rocket, not a flame', (
      tester,
    ) async {
      await pumpHomeWith(tester, {
        'current_streak': 9,
        'last_brush_date': day(-5),
      });
      expect(find.byIcon(Icons.rocket_launch), findsOneWidget);
      expect(find.byType(FlameIcon), findsNothing);
      await disposeAll(tester);
    });
  });

  group('welcome-back payoff', () {
    testWidgets('daily bonus plays the welcome flame line once per day', (
      tester,
    ) async {
      await pumpHomeWith(tester, {
        'current_streak': 4,
        'last_brush_date': day(-1),
      });
      expect(fakeAudio.playedVoiceLines, contains('voice_flame_welcome_1.mp3'));
      expect(
        fakeAudio.playedVoiceLines.where(
          (v) => v.startsWith('voice_streak_teach'),
        ),
        isEmpty,
      );
      fakeAudio.resetTracking();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        const MaterialApp(home: HomeScreen(skipGreeting: true)),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(
        fakeAudio.playedVoiceLines,
        isNot(contains('voice_flame_welcome_1.mp3')),
      );
      await disposeAll(tester);
    });

    testWidgets('a 7 day streak gets the two-star welcome line', (
      tester,
    ) async {
      await pumpHomeWith(tester, {
        'current_streak': 7,
        'last_brush_date': day(-1),
      });
      expect(flameVoices(), ['voice_flame_welcome_2.mp3']);
      await disposeAll(tester);
    });

    testWidgets('a short streak has no bonus and no welcome line', (
      tester,
    ) async {
      await pumpHomeWith(tester, {
        'current_streak': 2,
        'last_brush_date': day(-1),
      });
      expect(flameVoices(), isEmpty);
      expect(fakeAudio.playedSfx, isNot(contains('star_chime.mp3')));
      expect(find.byKey(const ValueKey('bonus_flight_star')), findsNothing);
      await disposeAll(tester);
    });

    testWidgets('the greeting no longer teaches the streak, the flame does', (
      tester,
    ) async {
      // Cold open, first of the day: the greeting dialog shows, then the
      // bonus is claimed behind it.
      await pumpHomeWith(tester, {
        'current_streak': 4,
        'last_brush_date': day(-1),
      }, skipGreeting: false);
      final lines = fakeAudio.playedVoiceLines;
      expect(lines.where((v) => v.startsWith('voice_streak_teach')), isEmpty);
      expect(lines.first, startsWith('voice_greet_streak_low_'));
      expect(lines, contains('voice_flame_welcome_1.mp3'));
      expect(
        lines.indexOf('voice_flame_welcome_1.mp3'),
        greaterThan(0),
        reason: 'the welcome line queues behind the greeting line',
      );
      await disposeAll(tester);
    });

    testWidgets('stars fly from the flame to the star counter, then land', (
      tester,
    ) async {
      // A 47 px status bar: the flight must still start and end on the pills.
      await pumpHomeWith(
        tester,
        {
          'current_streak': 7,
          'last_brush_date': day(-1),
          'total_stars': 20,
          'star_wallet': 11,
        },
        topInset: 47,
        settleSteps: 0,
      );
      final stars = find.byKey(const ValueKey('bonus_flight_star'));
      for (var i = 0; i < 40 && stars.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      // +2 for a 7 day streak: two stars, the counter still shows the old 11.
      expect(stars, findsNWidgets(2));
      expect(find.text('11'), findsOneWidget);
      expect(fakeAudio.playedSfx, isNot(contains('star_chime.mp3')));

      final flame = pillCentre(tester, find.byType(FlameIcon));
      final counter = pillCentre(tester, find.text('11'));
      Offset starsCentre() =>
          (tester.getCenter(stars.at(0)) + tester.getCenter(stars.at(1))) / 2;
      expect((starsCentre() - flame).distance, lessThan(4));

      // A ticker's first frame is its t=0; halfway is 450 ms after that.
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 450));
      final mid = starsCentre();
      expect(mid.dx, greaterThan(flame.dx + 20));
      expect(mid.dx, lessThan(counter.dx - 20));

      await tester.pump(const Duration(milliseconds: 350));
      expect((starsCentre() - counter).distance, lessThan(10));

      // Landing: chime, stars gone, the counter takes the two stars.
      await tester.pump(const Duration(milliseconds: 200));
      expect(stars, findsNothing);
      expect(
        fakeAudio.playedSfx.where((s) => s == 'star_chime.mp3'),
        hasLength(1),
      );
      expect(find.text('13'), findsOneWidget);

      // The counter that took the stars pulses once; the flame pill does not.
      await tester.pump(const Duration(milliseconds: 16)); // ticker's t=0
      await tester.pump(const Duration(milliseconds: 150));
      expect(pillScale(tester, find.text('13')), greaterThan(1.0));
      expect(streakPillScale(tester), 1.0);
      await tester.pump(const Duration(seconds: 1));
      expect(pillScale(tester, find.text('13')), 1.0);
      await disposeAll(tester);
    });

    testWidgets('leaving Home mid-flight lands nothing and breaks nothing', (
      tester,
    ) async {
      await pumpHomeWith(tester, {
        'current_streak': 4,
        'last_brush_date': day(-1),
      }, settleSteps: 0);
      final stars = find.byKey(const ValueKey('bonus_flight_star'));
      for (var i = 0; i < 40 && stars.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(stars, findsOneWidget);
      // No time passes after the dispose, on purpose: a landing timer that
      // was not cancelled would still be pending when the test ends, and the
      // framework fails the test for it (project rule: Timer? field,
      // cancelled in dispose).
      await tester.pumpWidget(const SizedBox());
      expect(fakeAudio.playedSfx, isNot(contains('star_chime.mp3')));
      await tester.binding.setSurfaceSize(null);
    });
  });

  group('tier-up whoosh', () {
    testWidgets('tier-up after victory: whoosh, no repeated line (R6)', (
      tester,
    ) async {
      await pumpHomeWith(tester, {
        'current_streak': 3,
        'last_brush_date': day(0),
        'last_seen_flame_tier': FlameTier.small.index,
      });
      expect(fakeAudio.playedSfx, contains('whoosh.mp3'));
      expect(whooshes(), 1);
      expect(
        fakeAudio.playedVoiceLines,
        isNot(contains('voice_flame_got_bigger.mp3')),
      );
      expect(await lastSeenTier(), FlameTier.big.index);
      await disposeAll(tester);
    });

    testWidgets('the whoosh pulses the streak pill once', (tester) async {
      await pumpHomeWith(tester, {
        'current_streak': 3,
        'last_brush_date': day(0),
        'last_seen_flame_tier': FlameTier.small.index,
      }, settleSteps: 0);
      await tester.pump(const Duration(milliseconds: 16)); // ticker's t=0
      await tester.pump(const Duration(milliseconds: 150));
      expect(streakPillScale(tester), greaterThan(1.0));
      await tester.pump(const Duration(seconds: 1));
      expect(streakPillScale(tester), 1.0);
      await disposeAll(tester);
    });

    testWidgets('without a tier-up the pill does not pulse', (tester) async {
      await pumpHomeWith(tester, {
        'current_streak': 3,
        'last_brush_date': day(0),
        'last_seen_flame_tier': FlameTier.big.index,
      }, settleSteps: 0);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 150));
      expect(streakPillScale(tester), 1.0);
      await disposeAll(tester);
    });

    testWidgets('a cold open that finds a bigger flame says so (R6)', (
      tester,
    ) async {
      await pumpHomeWith(tester, {
        'current_streak': 7,
        'last_brush_date': day(0),
        'last_seen_flame_tier': FlameTier.big.index,
        'last_greeting_date': day(0),
        'last_daily_bonus_date': day(0),
      }, skipGreeting: false);
      expect(whooshes(), 1);
      expect(
        fakeAudio.playedVoiceLines.where(
          (v) => v == 'voice_flame_got_bigger.mp3',
        ),
        hasLength(1),
      );
      expect(await lastSeenTier(), FlameTier.hot.index);
      await disposeAll(tester);
    });

    testWidgets('the same step is not announced on the next open', (
      tester,
    ) async {
      await pumpHomeWith(tester, {
        'current_streak': 7,
        'last_brush_date': day(0),
        'last_seen_flame_tier': FlameTier.big.index,
        'last_greeting_date': day(0),
        'last_daily_bonus_date': day(0),
      }, skipGreeting: false);
      expect(whooshes(), 1);
      fakeAudio.resetTracking();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(whooshes(), 0);
      expect(
        fakeAudio.playedVoiceLines,
        isNot(contains('voice_flame_got_bigger.mp3')),
      );
      await disposeAll(tester);
    });

    testWidgets('Home refreshing after a sub-screen does not whoosh again', (
      tester,
    ) async {
      PreBrushScreen.minStep = const Duration(seconds: 30);
      PreBrushScreen.maxStep = const Duration(seconds: 30);
      addTearDown(() {
        PreBrushScreen.minStep = const Duration(seconds: 3);
        PreBrushScreen.maxStep = const Duration(seconds: 5);
      });
      await pumpHomeWith(
        tester,
        {
          'current_streak': 3,
          'last_brush_date': day(0),
          'last_seen_flame_tier': FlameTier.small.index,
          'last_daily_bonus_date': day(0),
        },
        observers: [routeObserver],
      );
      expect(whooshes(), 1);

      // Hero tap (its own whoosh) -> pre-brush screen -> back to Home, which
      // reloads its stats as it is shown again.
      await tester.tap(find.byKey(const ValueKey('home_hero_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(PreBrushScreen), findsOneWidget);
      final whooshesBeforeBack = whooshes();
      final musicStarts = fakeAudio.callsFor('playMusic').length;
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        fakeAudio.callsFor('playMusic').length,
        greaterThan(musicStarts),
        reason: 'Home must really have reloaded for this test to mean much',
      );
      expect(whooshes(), whooshesBeforeBack);
      expect(
        fakeAudio.playedVoiceLines,
        isNot(contains('voice_flame_got_bigger.mp3')),
      );
      await disposeAll(tester);
    });

    testWidgets('the first run after the update is silent but takes note', (
      tester,
    ) async {
      await pumpHomeWith(tester, {
        'current_streak': 7,
        'last_brush_date': day(0),
        'last_daily_bonus_date': day(0),
      });
      expect(whooshes(), 0);
      expect(flameVoices(), isEmpty);
      expect(await lastSeenTier(), FlameTier.hot.index);
      await disposeAll(tester);
    });

    testWidgets('a first flame is not a step-up', (tester) async {
      await pumpHomeWith(tester, {
        'current_streak': 1,
        'last_brush_date': day(0),
        'last_seen_flame_tier': FlameTier.none.index,
      });
      expect(whooshes(), 0);
      expect(flameVoices(), isEmpty);
      expect(await lastSeenTier(), FlameTier.small.index);
      await disposeAll(tester);
    });

    testWidgets('broken streak: no flame voice or whoosh', (tester) async {
      await pumpHomeWith(tester, {
        'current_streak': 1,
        'last_brush_date': day(0),
        'last_seen_flame_tier': FlameTier.hot.index,
      });
      expect(
        fakeAudio.playedVoiceLines.where((v) => v.startsWith('voice_flame_')),
        isEmpty,
      );
      expect(fakeAudio.playedSfx, isNot(contains('whoosh.mp3')));
      expect(await lastSeenTier(), FlameTier.small.index);
      await disposeAll(tester);
    });
  });
}
