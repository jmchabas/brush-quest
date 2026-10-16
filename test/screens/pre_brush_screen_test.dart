// test/screens/pre_brush_screen_test.dart
//
// The brush steps on the real pages (spec
// docs/superpowers/specs/2026-10-13-brush-steps-on-real-pages-design.md,
// amended by 2026-10-15-sticker-card-design.md §3): HEROES tab → WEAPONS
// tab → Map under one header, the instruction lines, GO and the idle count,
// dialogs, the background, X, the back gesture, "Let's fight!" and the
// voice timelines.
import 'dart:async';

import 'package:brush_quest/screens/brush_mode.dart';
import 'package:brush_quest/screens/brushing_screen.dart';
import 'package:brush_quest/screens/hero_shop_screen.dart';
import 'package:brush_quest/screens/pre_brush_screen.dart';
import 'package:brush_quest/screens/world_map_screen.dart';
import 'package:brush_quest/services/analytics_service.dart';
import 'package:brush_quest/services/audio_service.dart';
import 'package:brush_quest/services/streak_service.dart';
import 'package:brush_quest/widgets/goal_glow.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/fake_audio_service.dart';
import '../audio/timed_fake_audio_service.dart';

/// Records the events the steps send (AnalyticsService is a no-op on the
/// test host, so the tests inject an Android-mode one around this fake).
class _RecordingAnalytics extends Fake implements FirebaseAnalytics {
  final List<Map<String, Object?>> events = [];

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
}

/// Records route replacements (brushing replaces the pre-brush screen).
class _ReplaceLog extends NavigatorObserver {
  final replaced = <Route<dynamic>?>[];

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    replaced.add(newRoute);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeAudioService audio;
  late _RecordingAnalytics recorder;
  bool? launchedWithIntro;

  setUpAll(() async {
    // The hand-off group builds the real BrushingScreen (Firebase, audio
    // players, wakelock), and tearDown's `testInstance = null` builds a real
    // AudioService, whose players talk to the audioplayers channels.
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers.global'),
        (call) async => 1,
      )
      ..setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers'),
        (call) async => 1,
      )
      ..setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/wakelock_plus'),
        (call) async => true,
      );
    // The app's own font, for the phone tests. The test font is about twice
    // as wide: in it the page's tab labels and the Map's title overflow at
    // 360 px, opened from Home too.
    final fredoka = FontLoader('Fredoka')
      ..addFont(
        rootBundle.load(
          'assets/fonts/Fredoka/Fredoka-VariableFont_wdth_wght.ttf',
        ),
      );
    await fredoka.load();
  });

  setUp(() async {
    audio = FakeAudioService();
    AudioService.testInstance = audio;
    recorder = _RecordingAnalytics();
    final analytics = AnalyticsService.forTesting(
      isAndroid: true,
      analytics: recorder,
    );
    await analytics.init();
    PreBrushScreen.debugAnalytics = analytics;
    HeroShopScreen.debugAnalytics = analytics;
    launchedWithIntro = null;
    PreBrushScreen.idleAdvance = const Duration(seconds: 1);
    PreBrushScreen.launchDelay = const Duration(milliseconds: 50);
    PreBrushScreen.debugBrushingBuilder = ({required showWorldIntro}) {
      launchedWithIntro = showWorldIntro;
      return const Scaffold(body: Text('BRUSHING'));
    };
  });

  tearDown(() {
    AudioService.testInstance = null;
    PreBrushScreen.debugBrushingBuilder = null;
    PreBrushScreen.debugAnalytics = null;
    HeroShopScreen.debugAnalytics = null;
    PreBrushScreen.idleAdvance = const Duration(seconds: 8);
    PreBrushScreen.maxVoiceWait = const Duration(seconds: 12);
    PreBrushScreen.launchDelay = const Duration(milliseconds: 400);
    PreBrushScreen.maxLaunchWait = const Duration(seconds: 3);
    StreakService.isPurchasing = false;
  });

  // A child on his fifth brush: 3 stars, Blaze and the Star Blaster, 2 of
  // Candy Crater's 5 missions. Goals: Frost (5), Flame Sword (5), and Slime
  // Swamp, which opens after 3 more brushes.
  final returningKid = <String, Object>{
    'total_brushes': 4,
    'star_wallet': 3,
    'unlocked_heroes': ['blaze'],
    'selected_hero': 'blaze',
    'unlocked_weapons': ['star_blaster'],
    'selected_weapon': 'star_blaster',
    'current_world': 'candy_crater',
    'world_progress_candy_crater': 2,
    'muted': false,
  };

  Map<String, Object> kid(Map<String, Object> changes) => {
    ...returningKid,
    ...changes,
  };

  // Every hero but Nova, and Blaze maxed: the hero goal is Nova (20), the
  // last row of the list.
  final farGoal = kid({
    'unlocked_heroes': ['blaze', 'frost', 'bolt', 'shadow', 'leaf'],
    'unlocked_evolutions': ['blaze_stage2', 'blaze_stage3'],
    'evolution_stage_blaze': 3,
  });

  final go = find.byKey(const ValueKey('prebrush_go'));
  Finder stepIs(PreBrushStep step) =>
      find.byKey(ValueKey('prebrush_step_${step.name}'));
  List<String> voices() => audio.playedVoiceLines;
  Finder glowOn(String key, {bool skipOffstage = true}) => find.descendant(
    of: find.byKey(ValueKey(key), skipOffstage: skipOffstage),
    matching: find.byType(GoalGlow, skipOffstage: skipOffstage),
  );

  /// The shop's tab (its own tab bar is hidden in brush mode).
  int tabIndex(WidgetTester tester) =>
      tester.widget<TabBarView>(find.byType(TabBarView)).controller!.index;
  final header = find.byKey(const ValueKey('prebrush_header'));
  Finder headerTab(PreBrushStep step) =>
      find.byKey(ValueKey('step_tab_${step.index}'));
  Color labelColor(WidgetTester tester, String label) =>
      tester.widget<Text>(find.text(label)).style!.color!;
  ScrollableState heroList(WidgetTester tester) =>
      tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
  Iterable<Map<String, Object?>> eventsNamed(String name) =>
      recorder.events.where((e) => e['name'] == name);

  Future<void> useSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(440, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    Map<String, Object> prefs,
  ) async {
    SharedPreferences.setMockInitialValues(prefs);
    await useSurface(tester);
    await tester.pumpWidget(const MaterialApp(home: PreBrushScreen()));
    await tester.pump(); // load
    await tester.pump(); // the first page
  }

  /// Pumps [total] in 50 ms frames, so frame-driven animations (the tab
  /// slide, the page slide, the reveal scroll) run as on a device.
  Future<void> pumpFor(WidgetTester tester, Duration total) async {
    const frame = Duration(milliseconds: 50);
    var left = total;
    while (left > Duration.zero) {
      final next = left < frame ? left : frame;
      await tester.pump(next);
      left -= next;
    }
  }

  /// Pumps 50 ms frames until [done]; returns how long that took.
  Future<Duration> pumpUntil(
    WidgetTester tester,
    bool Function() done, {
    Duration max = const Duration(seconds: 20),
  }) async {
    var waited = Duration.zero;
    while (!done()) {
      if (waited >= max) fail('not done after $max');
      await tester.pump(const Duration(milliseconds: 50));
      waited += const Duration(milliseconds: 50);
    }
    return waited;
  }

  Future<Duration> pumpUntilFound(WidgetTester tester, Finder finder) =>
      pumpUntil(tester, () => finder.evaluate().isNotEmpty);

  Future<void> tapGo(WidgetTester tester) async {
    await tester.tap(go);
    await tester.pump();
  }

  /// GO ignores taps for 400 ms after a step change (a double tap moves one
  /// step), so presses in a row wait this long.
  const goSettled = Duration(milliseconds: 450);

  /// GO on each step, the Map's too: "Let's fight!".
  Future<void> goToTheFight(WidgetTester tester) async {
    await tapGo(tester);
    await pumpFor(tester, goSettled);
    await tapGo(tester);
    await pumpFor(tester, goSettled);
    await tapGo(tester);
  }

  /// Opens the screen from a stand-in Home, so X has somewhere to go back to.
  Future<void> openFromHome(WidgetTester tester) async {
    await useSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: IconButton(
                key: const ValueKey('open'),
                icon: const Icon(Icons.play_arrow),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PreBrushScreen(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // route transition
  }

  /// A system back (Android's back button or gesture): the message the
  /// engine sends, as Flutter's own navigator tests do.
  Future<void> systemBack(WidgetTester tester) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMessageCodec().encodeMessage(const {'method': 'popRoute'}),
      (_) {},
    );
    await tester.pump();
  }

  /// From a stand-in Home, GO twice: the Map, slid in.
  Future<void> openOnTheMap(WidgetTester tester) async {
    await openFromHome(tester);
    await tapGo(tester);
    await pumpFor(tester, goSettled);
    await tapGo(tester);
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(stepIs(PreBrushStep.world), findsOneWidget);
  }

  /// Installs a voice channel that takes time, with its clock on the test's
  /// fake time. Lines not in [lengths] take 2 s.
  TimedFakeAudioService useTimedVoices(
    WidgetTester tester, {
    Map<String, Duration> lengths = const {},
  }) {
    final timed = TimedFakeAudioService(lengths: lengths);
    final start = tester.binding.clock.now();
    timed.clock = () => tester.binding.clock.now().difference(start);
    AudioService.testInstance = timed;
    audio = timed;
    return timed;
  }

  /// Runs [body] with debugPrint collected, so expected error logs are
  /// checked rather than printed.
  Future<List<String?>> collectDebugPrint(Future<void> Function() body) async {
    final printed = <String?>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => printed.add(message);
    try {
      await body();
    } finally {
      debugPrint = original;
    }
    return printed;
  }

  /// Taps Frost's cell (5 stars) and waits for the purchase dialog.
  Future<void> openFrostPurchase(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('evo_cell_frost_stage1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Get FROST?'), findsOneWidget);
  }

  // ── The three pages ───────────────────────────────────────────

  testWidgets('opens on the HEROES tab with its instruction and the goal', (
    tester,
  ) async {
    await pumpScreen(tester, returningKid);
    expect(stepIs(PreBrushStep.hero), findsOneWidget);
    expect(find.byType(HeroShopScreen), findsOneWidget);
    expect(tabIndex(tester), 0);
    // "Pick the hero who'll brush with you!", then Frost (5) minus the
    // wallet (3). Not Blaze's own description: that plays when he taps him.
    expect(voices(), ['voice_step_pick_hero.mp3', 'voice_stars_left_2.mp3']);
    expect(glowOn('evo_cell_frost_stage1'), findsOneWidget);
    expect(find.byType(GoalGlow), findsOneWidget);
    expect(find.byKey(const ValueKey('brush_close')), findsOneWidget);
    expect(
      find.descendant(of: go, matching: find.byIcon(Icons.arrow_forward)),
      findsOneWidget,
    );
  });

  testWidgets('GO: WEAPONS on the same page, then the Map, then the fight', (
    tester,
  ) async {
    await pumpScreen(tester, returningKid);
    final shop = tester.state(find.byType(HeroShopScreen));

    await tapGo(tester);
    expect(stepIs(PreBrushStep.weapon), findsOneWidget);
    expect(audio.playedSfx, ['whoosh.mp3']);
    // "Now pick your weapon!", then the Flame Sword (5) minus 3.
    expect(voices().sublist(2), [
      'voice_step_pick_weapon.mp3',
      'voice_stars_left_2.mp3',
    ]);
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(tabIndex(tester), 1);
    expect(tester.state(find.byType(HeroShopScreen)), same(shop));
    expect(glowOn('weapon_card_flame_sword'), findsOneWidget);

    await tapGo(tester);
    expect(stepIs(PreBrushStep.world), findsOneWidget);
    // "Pick the world where you'll fight!", then 3 of Candy Crater's 5
    // missions to go.
    expect(voices().sublist(4), [
      'voice_step_pick_world.mp3',
      'voice_brushes_left_3.mp3',
    ]);
    await pumpFor(tester, const Duration(milliseconds: 500)); // the slide
    expect(find.byType(WorldMapScreen), findsOneWidget);
    expect(find.byType(HeroShopScreen), findsNothing);
    expect(glowOn('planet_slime_swamp'), findsOneWidget); // opens next
    expect(
      find.descendant(of: go, matching: find.byIcon(Icons.rocket_launch)),
      findsOneWidget,
    );

    await tapGo(tester);
    expect(voices().last, 'voice_lets_fight.mp3');
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.text('BRUSHING'), findsOneWidget);
    expect(launchedWithIntro, isFalse);
  });

  testWidgets('each step moves on by itself once quiet, then brushing', (
    tester,
  ) async {
    await pumpScreen(tester, returningKid);
    final toWeapon = await pumpUntilFound(tester, stepIs(PreBrushStep.weapon));
    expect(toWeapon, greaterThanOrEqualTo(PreBrushScreen.idleAdvance));
    expect(
      toWeapon,
      lessThan(PreBrushScreen.idleAdvance + const Duration(milliseconds: 200)),
    );
    // The tab slide (300 ms) holds the count, then the whole idle time.
    final toWorld = await pumpUntilFound(tester, stepIs(PreBrushStep.world));
    expect(
      toWorld,
      greaterThanOrEqualTo(
        PreBrushScreen.idleAdvance + const Duration(milliseconds: 250),
      ),
    );
    final toFight = await pumpUntil(
      tester,
      () => voices().last == 'voice_lets_fight.mp3',
    );
    expect(toFight, greaterThanOrEqualTo(PreBrushScreen.idleAdvance));
    await pumpUntilFound(tester, find.text('BRUSHING'));
    expect(launchedWithIntro, isFalse);
    expect(audio.playedSfx, isEmpty); // the whoosh is GO's
  });

  testWidgets('an affordable goal: "Tap to unlock it!", never "Brush to..."', (
    tester,
  ) async {
    await pumpScreen(tester, kid({'star_wallet': 6}));
    expect(voices().last, 'voice_tap_to_unlock.mp3'); // Frost costs 5
    await tapGo(tester);
    expect(voices().last, 'voice_tap_to_unlock.mp3'); // Flame Sword costs 5
    expect(voices(), isNot(contains('voice_ready_to_unlock.mp3')));
  });

  testWidgets('everything owned: "You have them all" and no glow', (
    tester,
  ) async {
    await pumpScreen(tester, {
      'total_brushes': 400,
      'star_wallet': 0,
      'unlocked_heroes': ['blaze', 'frost', 'bolt', 'shadow', 'leaf', 'nova'],
      'selected_hero': 'nova',
      'unlocked_evolutions': ['nova_stage2', 'nova_stage3'],
      'evolution_stage_nova': 3,
      'unlocked_weapons': [
        'star_blaster',
        'flame_sword',
        'ice_hammer',
        'lightning_wand',
        'vine_whip',
        'cosmic_burst',
      ],
      'selected_weapon': 'cosmic_burst',
      'current_world': 'dark_dimension',
      'world_progress_candy_crater': 5,
      'world_progress_slime_swamp': 5,
      'world_progress_sugar_volcano': 6,
      'world_progress_shadow_nebula': 6,
      'world_progress_cavity_fortress': 7,
      'world_progress_frozen_tundra': 7,
      'world_progress_toxic_jungle': 7,
      'world_progress_crystal_cave': 8,
      'world_progress_storm_citadel': 8,
      'world_progress_dark_dimension': 10,
      'muted': false,
    });
    expect(voices(), ['voice_step_pick_hero.mp3', 'voice_have_them_all.mp3']);
    expect(find.byType(GoalGlow), findsNothing);
    await tapGo(tester);
    expect(voices().last, 'voice_have_them_all.mp3');
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(find.byType(GoalGlow), findsNothing);
    await tapGo(tester);
    expect(voices().sublist(4), [
      'voice_step_pick_world.mp3',
      'voice_have_them_all.mp3',
    ]);
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.byType(GoalGlow), findsNothing);
  });

  // ── Tabs ──────────────────────────────────────────────────────

  testWidgets('one header on every step, the step he is on lit', (
    tester,
  ) async {
    await pumpScreen(tester, returningKid);
    expect(header, findsOneWidget);
    // The page's own HEROES/WEAPONS bar gives way to it.
    expect(find.byType(TabBar), findsNothing);
    expect(labelColor(tester, 'HEROES'), Colors.white);
    expect(labelColor(tester, 'WEAPONS'), Colors.white54);
    expect(labelColor(tester, 'WORLD'), Colors.white54);
    await tapGo(tester);
    await pumpFor(tester, goSettled);
    expect(header, findsOneWidget);
    expect(labelColor(tester, 'HEROES'), Colors.white54);
    expect(labelColor(tester, 'WEAPONS'), Colors.white);
    await tapGo(tester);
    await pumpFor(tester, const Duration(milliseconds: 500)); // the slide
    expect(find.byType(WorldMapScreen), findsOneWidget);
    expect(header, findsOneWidget);
    expect(labelColor(tester, 'WEAPONS'), Colors.white54);
    expect(labelColor(tester, 'WORLD'), Colors.white);
    expect(find.byType(TabBar), findsNothing);
  });

  testWidgets('a header tab goes to its step with its lines, the Map too', (
    tester,
  ) async {
    await pumpScreen(tester, returningKid);
    audio.resetTracking();
    await tester.tap(headerTab(PreBrushStep.world));
    await tester.pump();
    expect(stepIs(PreBrushStep.world), findsOneWidget);
    expect(voices(), ['voice_step_pick_world.mp3', 'voice_brushes_left_3.mp3']);
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.byType(WorldMapScreen), findsOneWidget);
    expect(find.byType(HeroShopScreen), findsNothing);
    expect(glowOn('planet_slime_swamp'), findsOneWidget);

    audio.resetTracking();
    await tester.tap(headerTab(PreBrushStep.weapon));
    await tester.pump();
    expect(stepIs(PreBrushStep.weapon), findsOneWidget);
    expect(voices(), ['voice_step_pick_weapon.mp3', 'voice_stars_left_2.mp3']);
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.byType(WorldMapScreen), findsNothing);
    expect(tabIndex(tester), 1); // the shop comes back on its WEAPONS tab
    expect(glowOn('weapon_card_flame_sword'), findsOneWidget);

    audio.resetTracking();
    await tester.tap(headerTab(PreBrushStep.hero));
    await tester.pump();
    expect(stepIs(PreBrushStep.hero), findsOneWidget);
    expect(voices(), ['voice_step_pick_hero.mp3', 'voice_stars_left_2.mp3']);
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(tabIndex(tester), 0);
    expect(glowOn('evo_cell_frost_stage1'), findsOneWidget);
    // The steps speak, never the page's tab lines.
    expect(
      audio
          .callsFor('playVoice')
          .where((c) => '${c.args['fileName']}'.startsWith('voice_tab_')),
      isEmpty,
    );
  });

  testWidgets('the lit tab does nothing', (tester) async {
    await pumpScreen(tester, returningKid);
    final heard = voices().length;
    await tester.tap(headerTab(PreBrushStep.hero));
    await tester.pump();
    expect(stepIs(PreBrushStep.hero), findsOneWidget);
    expect(voices(), hasLength(heard));
  });

  testWidgets('going back, the page comes in from the left', (tester) async {
    await pumpScreen(tester, returningKid);
    await tapGo(tester);
    await pumpFor(tester, goSettled);
    await tapGo(tester);
    await pumpFor(tester, const Duration(milliseconds: 200)); // mid-slide
    // On to the Map: it comes in from the right, the shop leaves left.
    expect(tester.getTopLeft(find.byType(WorldMapScreen)).dx, greaterThan(0));
    expect(tester.getTopLeft(find.byType(HeroShopScreen)).dx, lessThan(0));
    await pumpFor(tester, const Duration(milliseconds: 300));
    await tester.tap(headerTab(PreBrushStep.hero));
    await tester.pump();
    await pumpFor(tester, const Duration(milliseconds: 200)); // mid-slide
    // Back to the shop: it comes in from the left, the Map leaves right.
    expect(tester.getTopLeft(find.byType(HeroShopScreen)).dx, lessThan(0));
    expect(tester.getTopLeft(find.byType(WorldMapScreen)).dx, greaterThan(0));
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(tester.getTopLeft(find.byType(HeroShopScreen)).dx, 0);
  });

  testWidgets('a header tap as the Map slides in: HEROES, cleanly', (
    tester,
  ) async {
    await pumpScreen(tester, returningKid);
    await tapGo(tester);
    await pumpFor(tester, goSettled);
    await tapGo(tester); // the Map slides in
    await pumpFor(tester, const Duration(milliseconds: 150));
    // Two headers for now: the shop's, leaving (it takes no taps), and the
    // Map's, coming in.
    expect(header, findsNWidgets(2));
    await tester.tap(headerTab(PreBrushStep.hero).last);
    await tester.pump();
    expect(stepIs(PreBrushStep.hero), findsOneWidget);
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull); // no duplicate GlobalKey
    expect(find.byType(WorldMapScreen), findsNothing);
    expect(find.byType(HeroShopScreen), findsOneWidget);
    expect(header, findsOneWidget);
    expect(tabIndex(tester), 0);
    expect(glowOn('evo_cell_frost_stage1'), findsOneWidget);
    expect(voices().sublist(voices().length - 2), [
      'voice_step_pick_hero.mp3',
      'voice_stars_left_2.mp3',
    ]);
  });

  testWidgets('WEAPONS as the shop slides back in: the slide does not turn '
      'round', (tester) async {
    await pumpScreen(tester, returningKid);
    await tapGo(tester);
    await pumpFor(tester, goSettled);
    await tapGo(tester);
    await pumpFor(tester, const Duration(milliseconds: 500)); // on the Map
    await tester.tap(headerTab(PreBrushStep.hero));
    await tester.pump();
    await pumpFor(tester, const Duration(milliseconds: 100)); // mid-slide
    // The shop comes in from the left, the Map leaves to the right. WEAPONS
    // on the incoming header (the page leaving comes first) only moves the
    // shop's own tab: both pages keep sliding the way they were.
    expect(header, findsNWidgets(2));
    await tester.tap(headerTab(PreBrushStep.weapon).last);
    await tester.pump();
    expect(stepIs(PreBrushStep.weapon), findsOneWidget);
    expect(tester.getTopLeft(find.byType(HeroShopScreen)).dx, lessThan(0));
    expect(tester.getTopLeft(find.byType(WorldMapScreen)).dx, greaterThan(0));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.byType(WorldMapScreen), findsNothing);
    expect(tester.getTopLeft(find.byType(HeroShopScreen)).dx, 0);
    expect(tabIndex(tester), 1);
  });

  testWidgets('a swipe to the other tab is a step change too', (tester) async {
    await pumpScreen(tester, returningKid);
    await tester.fling(find.byType(TabBarView), const Offset(-300, 0), 1500);
    // The tab controller takes the new index when the page settles.
    await pumpFor(tester, const Duration(seconds: 1));
    expect(stepIs(PreBrushStep.weapon), findsOneWidget);
    expect(tabIndex(tester), 1);
    expect(voices().sublist(2), [
      'voice_step_pick_weapon.mp3',
      'voice_stars_left_2.mp3',
    ]);
  });

  testWidgets('a step change clears the page\'s snack bars', (tester) async {
    await pumpScreen(tester, returningKid);
    // Bolt (8) is out of reach with 3 stars: the page's "5 more" snack bar.
    await tester.tap(find.byKey(const ValueKey('evo_cell_bolt_stage1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('5 more'), findsOneWidget);
    await tapGo(tester);
    // Its exit animation (250 ms), long before its own 2 s are up.
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(find.text('5 more'), findsNothing);
  });

  // ── What holds the idle count ─────────────────────────────────

  testWidgets('a touch holds the count; lifting it starts again from zero', (
    tester,
  ) async {
    await pumpScreen(tester, returningKid);
    await pumpFor(tester, const Duration(milliseconds: 700));
    final finger = await tester.startGesture(
      tester.getCenter(find.text('HEROES & WEAPONS')),
    );
    await pumpFor(tester, const Duration(seconds: 2));
    expect(stepIs(PreBrushStep.hero), findsOneWidget);
    await finger.up();
    final waited = await pumpUntilFound(tester, stepIs(PreBrushStep.weapon));
    expect(waited, greaterThanOrEqualTo(PreBrushScreen.idleAdvance));
  });

  testWidgets('a cancelled touch lets the count run again', (tester) async {
    await pumpScreen(tester, returningKid);
    final finger = await tester.startGesture(
      tester.getCenter(find.text('HEROES & WEAPONS')),
    );
    await pumpFor(tester, const Duration(seconds: 2));
    expect(stepIs(PreBrushStep.hero), findsOneWidget);
    await finger.cancel();
    final waited = await pumpUntilFound(tester, stepIs(PreBrushStep.weapon));
    expect(waited, greaterThanOrEqualTo(PreBrushScreen.idleAdvance));
  });

  testWidgets('a finger on GO holds the count: one press, one step', (
    tester,
  ) async {
    await pumpScreen(tester, returningKid);
    await pumpFor(tester, const Duration(milliseconds: 900));
    // Pressed just before the idle count runs out, and held past it.
    final finger = await tester.startGesture(tester.getCenter(go));
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(stepIs(PreBrushStep.hero), findsOneWidget);
    await finger.up();
    await tester.pump();
    expect(stepIs(PreBrushStep.weapon), findsOneWidget);
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(stepIs(PreBrushStep.weapon), findsOneWidget); // not the Map
    expect(voices(), [
      'voice_step_pick_hero.mp3',
      'voice_stars_left_2.mp3',
      'voice_step_pick_weapon.mp3',
      'voice_stars_left_2.mp3',
    ]);
    expect(audio.playedSfx, ['whoosh.mp3']);
  });

  testWidgets('a double tap on GO on HEROES moves one step', (tester) async {
    await pumpScreen(tester, returningKid);
    await tapGo(tester);
    await tester.pump(const Duration(milliseconds: 150));
    await tapGo(tester); // as the tabs slide
    expect(stepIs(PreBrushStep.weapon), findsOneWidget);
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(stepIs(PreBrushStep.weapon), findsOneWidget); // not the Map
    expect(voices(), [
      'voice_step_pick_hero.mp3',
      'voice_stars_left_2.mp3',
      'voice_step_pick_weapon.mp3',
      'voice_stars_left_2.mp3',
    ]);
    expect(audio.playedSfx, ['whoosh.mp3']); // the second tap did nothing
  });

  testWidgets('a double tap on GO on WEAPONS: the Map, not the fight', (
    tester,
  ) async {
    await pumpScreen(tester, returningKid);
    await tapGo(tester);
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tapGo(tester);
    await tester.pump(const Duration(milliseconds: 150));
    await tapGo(tester); // as the Map slides in
    expect(stepIs(PreBrushStep.world), findsOneWidget);
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(stepIs(PreBrushStep.world), findsOneWidget);
    expect(voices(), isNot(contains('voice_lets_fight.mp3')));
    expect(audio.playedSfx, ['whoosh.mp3', 'whoosh.mp3']);
  });

  testWidgets('GO again once the next page is in: it moves on', (tester) async {
    await pumpScreen(tester, returningKid);
    await tapGo(tester);
    await pumpFor(tester, goSettled); // 450 ms: past the settle
    await tapGo(tester);
    expect(stepIs(PreBrushStep.world), findsOneWidget);
    expect(audio.playedSfx, ['whoosh.mp3', 'whoosh.mp3']);
  });

  testWidgets('a scroll holds the count until it ends', (tester) async {
    await pumpScreen(tester, returningKid);
    unawaited(
      heroList(tester).position.animateTo(
        300,
        duration: const Duration(seconds: 2),
        curve: Curves.linear,
      ),
    );
    await pumpFor(tester, const Duration(milliseconds: 1900));
    expect(stepIs(PreBrushStep.hero), findsOneWidget);
    final waited = await pumpUntilFound(tester, stepIs(PreBrushStep.weapon));
    // The last 100 ms of the scroll, then the whole idle time.
    expect(waited, greaterThanOrEqualTo(PreBrushScreen.idleAdvance));
  });

  testWidgets('a scroll that never sends its end does not hold the step', (
    tester,
  ) async {
    await pumpScreen(tester, returningKid);
    // As when a page goes away mid-fling: a start, and no end ever.
    final page = tester.element(find.text('HEROES & WEAPONS'));
    ScrollStartNotification(
      metrics: heroList(tester).position.copyWith(),
      context: page,
    ).dispatch(page);
    final waited = await pumpUntilFound(tester, stepIs(PreBrushStep.weapon));
    expect(waited, greaterThanOrEqualTo(PreBrushScreen.idleAdvance));
    expect(
      waited,
      lessThan(PreBrushScreen.idleAdvance + const Duration(milliseconds: 700)),
    );
  });

  testWidgets('a dialog holds the count; it starts again once it closes', (
    tester,
  ) async {
    await pumpScreen(tester, kid({'star_wallet': 6}));
    await openFrostPurchase(tester);
    await pumpFor(tester, const Duration(seconds: 3));
    expect(stepIs(PreBrushStep.hero), findsOneWidget);
    await tester.tap(find.text('Not yet'));
    await tester.pump();
    final waited = await pumpUntilFound(tester, stepIs(PreBrushStep.weapon));
    expect(waited, greaterThanOrEqualTo(PreBrushScreen.idleAdvance));
  });

  testWidgets('back from the background with a dialog still open: it waits', (
    tester,
  ) async {
    await pumpScreen(tester, kid({'star_wallet': 6}));
    await openFrostPurchase(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpFor(tester, const Duration(seconds: 3));
    expect(stepIs(PreBrushStep.hero), findsOneWidget);
    expect(find.text('Get FROST?'), findsOneWidget);
    await tester.tap(find.text('Not yet'));
    await tester.pump();
    await pumpUntilFound(tester, stepIs(PreBrushStep.weapon));
  });

  testWidgets('a voice that never ends cannot hold a step: past the cap', (
    tester,
  ) async {
    PreBrushScreen.maxVoiceWait = const Duration(seconds: 2);
    await pumpScreen(tester, returningKid);
    audio.voicePipelineActiveNotifier.value = true; // stuck
    await pumpFor(tester, const Duration(milliseconds: 2800));
    expect(stepIs(PreBrushStep.hero), findsOneWidget);
    final waited = await pumpUntilFound(tester, stepIs(PreBrushStep.weapon));
    expect(waited, lessThan(const Duration(milliseconds: 600)));
  });

  // ── On the page: unlocks, picks, the glow ─────────────────────

  testWidgets('an unlock: celebrated, equipped, the glow moves, pre_brush', (
    tester,
  ) async {
    PreBrushScreen.idleAdvance = const Duration(seconds: 30);
    await pumpScreen(tester, kid({'star_wallet': 6}));
    await openFrostPurchase(tester);
    await tester.tap(find.text('YES!'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('FROST UNLOCKED!'), findsOneWidget);
    expect(voices().last, 'voice_intro_hero_frost.mp3');
    final heard = voices().length;
    await pumpFor(tester, const Duration(seconds: 7)); // closes after 6 s
    expect(find.text('FROST UNLOCKED!'), findsNothing);
    final saved = await SharedPreferences.getInstance();
    expect(saved.getString('selected_hero'), 'frost');
    expect(saved.getInt('star_wallet'), 1);
    // Bolt (8) is now the closest: Frost's upgrade costs 12.
    expect(glowOn('evo_cell_bolt_stage1'), findsOneWidget);
    expect(find.byType(GoalGlow), findsOneWidget);
    expect(voices(), hasLength(heard)); // no extra line after an unlock
    expect(eventsNamed('goal_unlocked'), [
      {
        'name': 'goal_unlocked',
        'category': 'hero',
        'item': 'frost',
        'source': 'pre_brush',
      },
    ]);
    expect(eventsNamed('pre_brush_change'), [
      {'name': 'pre_brush_change', 'category': 'hero'},
    ]);
    expect(stepIs(PreBrushStep.hero), findsOneWidget);
  });

  testWidgets('a pick is a pre_brush_change; the steps are no shop visit', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      kid({
        'unlocked_weapons': ['star_blaster', 'flame_sword'],
      }),
    );
    await tapGo(tester);
    // The tab slide, then the goal (the Ice Hammer, behind GO) scrolls into
    // view (400 ms); a list ignores taps while it scrolls.
    await pumpFor(tester, const Duration(milliseconds: 1100));
    await tester.tap(find.byKey(const ValueKey('weapon_card_flame_sword')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(voices().last, 'voice_picker_weapon_flame_sword.mp3'); // the page's
    expect(eventsNamed('pre_brush_change'), [
      {'name': 'pre_brush_change', 'category': 'weapon'},
    ]);
    expect(eventsNamed('shop_visit'), isEmpty);
    final saved = await SharedPreferences.getInstance();
    expect(saved.getString('selected_weapon'), 'flame_sword');
  });

  testWidgets('the page sliding away takes no taps', (tester) async {
    final timed = useTimedVoices(tester); // each line 2 s
    await pumpScreen(
      tester,
      kid({
        'unlocked_weapons': ['star_blaster', 'flame_sword'],
      }),
    );
    await tapGo(tester);
    await pumpFor(tester, goSettled);
    final shop = tester.state(find.byType(HeroShopScreen));
    await tapGo(tester); // the Map slides in, the shop slides away
    await tester.pump(const Duration(milliseconds: 16));
    // The page on its way out is still the same page.
    expect(tester.state(find.byType(HeroShopScreen)), same(shop));
    final map = tester.state(find.byType(WorldMapScreen));
    // The Flame Sword is his: a tap on its card would equip it.
    await tester.tap(
      find.byKey(const ValueKey('weapon_card_flame_sword')),
      warnIfMissed: false, // ignored on purpose
    );
    await pumpFor(tester, const Duration(milliseconds: 500));
    // The Map stays the same page once the shop is gone.
    expect(find.byType(HeroShopScreen), findsNothing);
    expect(tester.state(find.byType(WorldMapScreen)), same(map));
    expect(timed.voiceNamed('voice_picker_weapon_flame_sword.mp3'), isNull);
    expect(eventsNamed('pre_brush_change'), isEmpty);
    final saved = await SharedPreferences.getInstance();
    expect(saved.getString('selected_weapon'), 'star_blaster');
    // The Map's lines play out.
    await pumpFor(tester, const Duration(seconds: 4));
    final world = timed.voiceNamed('voice_step_pick_world.mp3')!;
    final left = timed.voiceNamed('voice_brushes_left_3.mp3')!;
    expect(world.cut, isFalse, reason: '${timed.voices}');
    expect(left.cut || left.dropped, isFalse, reason: '${timed.voices}');
    expect(left.endedAt, isNotNull, reason: '${timed.voices}');
    // The idle count has begun: end any line, or its timer outlives the
    // test.
    await timed.stopVoice();
  });

  testWidgets('a goal far down the list scrolls into view after the lines', (
    tester,
  ) async {
    await pumpScreen(tester, farGoal);
    // Built (the page's cache extent) but still below the screen.
    expect(glowOn('evo_cell_nova_stage1', skipOffstage: false), findsOneWidget);
    await pumpFor(tester, const Duration(milliseconds: 800));
    expect(heroList(tester).position.pixels, greaterThan(0));
    final glow = tester.getRect(find.byType(GoalGlow));
    final list = tester.getRect(find.byType(ListView));
    expect(glow.top, greaterThanOrEqualTo(list.top));
    expect(glow.bottom, lessThanOrEqualTo(list.bottom - kBrushGoClearance));
  });

  testWidgets('a touch while the lines play: no scroll afterwards', (
    tester,
  ) async {
    final timed = useTimedVoices(tester); // each line 2 s
    await pumpScreen(tester, farGoal);
    final finger = await tester.startGesture(
      tester.getCenter(find.text('HEROES & WEAPONS')),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await finger.up();
    await pumpFor(tester, const Duration(milliseconds: 4500)); // lines over
    expect(timed.voices.every((v) => v.endedAt != null), isTrue);
    expect(heroList(tester).position.pixels, 0);
  });

  testWidgets('a saved hero or weapon the game does not know: the steps '
      'run as usual', (tester) async {
    await pumpScreen(
      tester,
      kid({'selected_hero': 'robo', 'selected_weapon': 'laser_sword'}),
    );
    expect(voices().first, 'voice_step_pick_hero.mp3');
    expect(tester.takeException(), isNull);
    await tapGo(tester);
    expect(voices()[2], 'voice_step_pick_weapon.mp3');
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.byType(HeroShopScreen), findsOneWidget);
  });

  testWidgets('the pages never stop the voice while the steps run', (
    tester,
  ) async {
    await pumpScreen(tester, returningKid);
    await tapGo(tester);
    await pumpFor(tester, const Duration(milliseconds: 400));
    await tapGo(tester);
    await pumpFor(tester, const Duration(milliseconds: 600)); // shop gone
    expect(find.byType(HeroShopScreen), findsNothing);
    expect(audio.callsFor('stopVoice'), isEmpty);
    await tapGo(tester);
    await pumpFor(tester, const Duration(seconds: 1)); // the Map gone too
    expect(find.byType(WorldMapScreen), findsNothing);
    expect(audio.callsFor('stopVoice'), isEmpty);
  });

  // ── The background ────────────────────────────────────────────

  testWidgets('a pause stops the count; back, it starts again from zero', (
    tester,
  ) async {
    await pumpScreen(tester, returningKid);
    await pumpFor(tester, const Duration(milliseconds: 700));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 3));
    expect(stepIs(PreBrushStep.hero), findsOneWidget);
    expect(audio.callsFor('stopVoice'), isNotEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final waited = await pumpUntilFound(tester, stepIs(PreBrushStep.weapon));
    expect(waited, greaterThanOrEqualTo(PreBrushScreen.idleAdvance));
  });

  testWidgets('a resume with no pause before it changes nothing', (
    tester,
  ) async {
    await pumpScreen(tester, returningKid);
    await pumpFor(tester, const Duration(milliseconds: 600));
    final heard = voices().length;
    // The notification shade or a system dialog: inactive, then resumed.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(voices(), hasLength(heard));
    // The first count ran on (about 400 ms left), no fresh start.
    final waited = await pumpUntilFound(tester, stepIs(PreBrushStep.weapon));
    expect(waited, lessThan(const Duration(milliseconds: 600)));
  });

  testWidgets('a pause after "Let\'s fight!" launches brushing on resume', (
    tester,
  ) async {
    // Frames stop while paused, so a route pushed in the background can't be
    // seen with a finder: watch the navigator instead.
    final routes = _ReplaceLog();
    SharedPreferences.setMockInitialValues(returningKid);
    await useSurface(tester);
    await tester.pumpWidget(
      MaterialApp(home: const PreBrushScreen(), navigatorObservers: [routes]),
    );
    await tester.pump();
    await tester.pump();
    await goToTheFight(tester);
    expect(voices().last, 'voice_lets_fight.mp3');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 5)); // past every launch timer
    expect(routes.replaced, isEmpty); // nothing launched in the background
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(routes.replaced, hasLength(1));
    expect(find.text('BRUSHING'), findsOneWidget);
    expect(launchedWithIntro, isFalse);
  });

  // ── X, back, "Let's fight!" and the launch ────────────────────

  testWidgets('X goes back to Home with his pick kept; then nothing plays', (
    tester,
  ) async {
    PreBrushScreen.idleAdvance = const Duration(seconds: 30);
    SharedPreferences.setMockInitialValues(
      kid({
        'unlocked_heroes': ['blaze', 'frost'],
      }),
    );
    await openFromHome(tester);
    // The goal (Bolt, behind GO) first scrolls into view (400 ms); a list
    // ignores taps while it scrolls.
    await pumpFor(tester, const Duration(milliseconds: 700));
    await tester.tap(find.byKey(const ValueKey('evo_cell_frost_stage1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(voices().last, 'voice_picker_hero_frost.mp3');
    final heard = voices().length;
    await tester.tap(find.byKey(const ValueKey('brush_close')));
    await tester.pumpAndSettle();
    expect(find.byType(PreBrushScreen), findsNothing);
    expect(find.byKey(const ValueKey('open')), findsOneWidget);
    expect(audio.callsFor('stopVoice'), isNotEmpty);
    final saved = await SharedPreferences.getInstance();
    expect(saved.getString('selected_hero'), 'frost');
    await tester.pump(const Duration(seconds: 35)); // past every step timer
    expect(voices(), hasLength(heard));
    expect(launchedWithIntro, isNull);
  });

  testWidgets('the back gesture: the Map, WEAPONS, HEROES, then Home', (
    tester,
  ) async {
    PreBrushScreen.idleAdvance = const Duration(seconds: 30);
    SharedPreferences.setMockInitialValues(returningKid);
    await openOnTheMap(tester);

    audio.resetTracking();
    await systemBack(tester);
    expect(stepIs(PreBrushStep.weapon), findsOneWidget);
    expect(voices(), ['voice_step_pick_weapon.mp3', 'voice_stars_left_2.mp3']);
    await pumpFor(tester, const Duration(milliseconds: 100));
    // The shop comes back from the left, on its WEAPONS tab, its glow on.
    expect(tester.getTopLeft(find.byType(HeroShopScreen)).dx, lessThan(0));
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(find.byType(WorldMapScreen), findsNothing);
    expect(tabIndex(tester), 1);
    expect(glowOn('weapon_card_flame_sword'), findsOneWidget);

    audio.resetTracking();
    await systemBack(tester);
    expect(stepIs(PreBrushStep.hero), findsOneWidget);
    expect(voices(), ['voice_step_pick_hero.mp3', 'voice_stars_left_2.mp3']);
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(tabIndex(tester), 0);
    expect(find.byType(PreBrushScreen), findsOneWidget);

    await systemBack(tester);
    await tester.pumpAndSettle();
    expect(find.byType(PreBrushScreen), findsNothing);
    expect(find.byKey(const ValueKey('open')), findsOneWidget);
    expect(audio.callsFor('stopVoice'), isNotEmpty);
    expect(launchedWithIntro, isNull);
  });

  testWidgets('X goes Home from the Map, not one step back', (tester) async {
    PreBrushScreen.idleAdvance = const Duration(seconds: 30);
    SharedPreferences.setMockInitialValues(returningKid);
    await openOnTheMap(tester);
    final heard = voices().length;
    await tester.tap(find.byKey(const ValueKey('brush_close')));
    await tester.pumpAndSettle();
    expect(find.byType(PreBrushScreen), findsNothing);
    expect(find.byKey(const ValueKey('open')), findsOneWidget);
    expect(voices(), hasLength(heard)); // no WEAPONS lines on the way out
    expect(launchedWithIntro, isNull);
  });

  testWidgets('the back gesture with a dialog open closes only the dialog', (
    tester,
  ) async {
    PreBrushScreen.idleAdvance = const Duration(seconds: 30);
    SharedPreferences.setMockInitialValues(kid({'star_wallet': 6}));
    await openFromHome(tester);
    await tapGo(tester);
    await pumpFor(tester, const Duration(milliseconds: 500));
    // The Flame Sword (5) is his to buy: its confirmation opens.
    await tester.tap(find.byKey(const ValueKey('weapon_card_flame_sword')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Get FLAME SWORD?'), findsOneWidget);
    final heard = voices().length;
    await systemBack(tester);
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(find.text('Get FLAME SWORD?'), findsNothing);
    expect(stepIs(PreBrushStep.weapon), findsOneWidget);
    expect(voices(), hasLength(heard));
    final saved = await SharedPreferences.getInstance();
    expect(saved.getInt('star_wallet'), 6); // nothing bought
  });

  testWidgets('two quick backs from the Map: HEROES; one more is Home', (
    tester,
  ) async {
    PreBrushScreen.idleAdvance = const Duration(seconds: 30);
    SharedPreferences.setMockInitialValues(returningKid);
    await openOnTheMap(tester);
    await systemBack(tester);
    await tester.pump(const Duration(milliseconds: 100)); // shop sliding in
    await systemBack(tester);
    expect(stepIs(PreBrushStep.hero), findsOneWidget);
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    expect(find.byType(WorldMapScreen), findsNothing);
    expect(tabIndex(tester), 0);
    expect(voices().sublist(voices().length - 2), [
      'voice_step_pick_hero.mp3',
      'voice_stars_left_2.mp3',
    ]);
    await systemBack(tester);
    await tester.pumpAndSettle();
    expect(find.byType(PreBrushScreen), findsNothing);
  });

  testWidgets('after a step back the count runs again, and GO works', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(returningKid);
    await openOnTheMap(tester);
    await systemBack(tester); // WEAPONS
    final waited = await pumpUntilFound(tester, stepIs(PreBrushStep.world));
    expect(waited, greaterThanOrEqualTo(PreBrushScreen.idleAdvance));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await systemBack(tester); // WEAPONS again
    await pumpFor(tester, goSettled);
    await tapGo(tester);
    expect(stepIs(PreBrushStep.world), findsOneWidget);
  });

  testWidgets('back after "Let\'s fight!" goes Home; brushing never starts', (
    tester,
  ) async {
    PreBrushScreen.launchDelay = const Duration(milliseconds: 400);
    SharedPreferences.setMockInitialValues(returningKid);
    await openFromHome(tester);
    await goToTheFight(tester);
    expect(voices().last, 'voice_lets_fight.mp3');
    await tester.pump(const Duration(milliseconds: 200)); // inside the delay
    await systemBack(tester); // Home, not the Map: ruling 2 stands
    await tester.pumpAndSettle();
    expect(find.text('BRUSHING'), findsNothing);
    expect(find.byKey(const ValueKey('open')), findsOneWidget);
    expect(
      tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
      isFalse,
    );
    expect(launchedWithIntro, isNull);
  });

  testWidgets('after "Let\'s fight!" a tap on the page changes nothing', (
    tester,
  ) async {
    // Slime Swamp is open too.
    await pumpScreen(tester, kid({'world_progress_candy_crater': 5}));
    await tapGo(tester);
    await pumpFor(tester, goSettled);
    await tapGo(tester);
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tapGo(tester);
    audio.voicePipelineActiveNotifier.value = true; // hold the launch
    final heard = voices().length;
    await tester.tap(
      find.byKey(const ValueKey('planet_slime_swamp')),
      warnIfMissed: false, // ignored on purpose
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(voices().sublist(heard), isEmpty);
    final saved = await SharedPreferences.getInstance();
    expect(saved.getString('current_world'), 'candy_crater');
    audio.voicePipelineActiveNotifier.value = false;
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.text('BRUSHING'), findsOneWidget);
  });

  testWidgets('after "Let\'s fight!" the header changes nothing', (
    tester,
  ) async {
    await pumpScreen(tester, returningKid);
    await goToTheFight(tester);
    audio.voicePipelineActiveNotifier.value = true; // hold the launch
    final heard = voices().length;
    await tester.tap(
      headerTab(PreBrushStep.hero),
      warnIfMissed: false, // ignored on purpose
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(stepIs(PreBrushStep.world), findsOneWidget);
    expect(voices().sublist(heard), isEmpty);
    audio.voicePipelineActiveNotifier.value = false;
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.text('BRUSHING'), findsOneWidget);
  });

  testWidgets('"Let\'s fight!" plays out before brushing starts', (
    tester,
  ) async {
    await pumpScreen(tester, returningKid);
    await goToTheFight(tester);
    audio.voicePipelineActiveNotifier.value = true; // "Let's fight!" playing
    await tester.pump(const Duration(milliseconds: 500)); // past the delay
    expect(find.text('BRUSHING'), findsNothing);
    expect(audio.callsFor('stopVoice'), isEmpty);
    audio.voicePipelineActiveNotifier.value = false; // the line ends
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.text('BRUSHING'), findsOneWidget);
  });

  testWidgets('a "Let\'s fight!" that never ends still launches at the cap', (
    tester,
  ) async {
    PreBrushScreen.maxLaunchWait = const Duration(milliseconds: 500);
    await pumpScreen(tester, returningKid);
    await goToTheFight(tester);
    audio.voicePipelineActiveNotifier.value = true; // stuck
    await tester.pump(const Duration(milliseconds: 400)); // delay + part of cap
    expect(find.text('BRUSHING'), findsNothing);
    await tester.pump(const Duration(milliseconds: 300)); // the cap
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('BRUSHING'), findsOneWidget);
  });

  testWidgets('a load error goes straight to brushing with its world intro', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'total_brushes': 3,
      // A string where a number belongs: getInt throws a TypeError.
      'world_progress_candy_crater': 'two',
    });
    final printed = await collectDebugPrint(() async {
      await tester.pumpWidget(const MaterialApp(home: PreBrushScreen()));
      await tester.pumpAndSettle();
    });
    expect(find.text('BRUSHING'), findsOneWidget);
    expect(launchedWithIntro, isTrue);
    expect(printed.single, startsWith('PreBrush load failed'));
    expect(eventsNamed('pre_brush_skipped'), [
      {'name': 'pre_brush_skipped', 'reason': 'error'},
    ]);
  });

  // ── Voice timelines (a voice channel that takes time) ─────────

  testWidgets('timeline: a step\'s lines in turn, and the count waits', (
    tester,
  ) async {
    // The clips' real lengths.
    final timed = useTimedVoices(
      tester,
      lengths: const {
        'voice_step_pick_hero.mp3': Duration(milliseconds: 1672),
        'voice_stars_left_2.mp3': Duration(milliseconds: 993),
      },
    );
    await pumpScreen(tester, returningKid);
    await pumpFor(tester, const Duration(milliseconds: 3500)); // lines: 2.7 s
    expect(stepIs(PreBrushStep.hero), findsOneWidget);
    await pumpUntilFound(tester, stepIs(PreBrushStep.weapon));
    final instruction = timed.voiceNamed('voice_step_pick_hero.mp3')!;
    final progress = timed.voiceNamed('voice_stars_left_2.mp3')!;
    expect(instruction.cut, isFalse);
    expect(progress.startedAt, greaterThanOrEqualTo(instruction.endedAt!));
    final quiet = timed.clock() - progress.endedAt!;
    expect(quiet, greaterThanOrEqualTo(PreBrushScreen.idleAdvance));
    expect(
      quiet,
      lessThan(PreBrushScreen.idleAdvance + const Duration(milliseconds: 100)),
    );
    // The WEAPONS lines have just begun: end them, or their timer outlives
    // the test.
    await timed.stopVoice();
  });

  testWidgets('timeline: a far goal scrolls into view once the lines end', (
    tester,
  ) async {
    final timed = useTimedVoices(tester); // each line 2 s
    await pumpScreen(tester, farGoal);
    await pumpFor(tester, const Duration(milliseconds: 3500));
    expect(timed.voices.last.endedAt, isNull); // the goal's line plays
    expect(heroList(tester).position.pixels, 0);
    // The lines end at 4 s; then the 400 ms scroll and a frame.
    await pumpFor(tester, const Duration(milliseconds: 950));
    expect(timed.voices.every((v) => v.endedAt != null), isTrue);
    expect(heroList(tester).position.pixels, greaterThan(0));
    final glow = tester.getRect(find.byType(GoalGlow));
    final list = tester.getRect(find.byType(ListView));
    expect(glow.top, greaterThanOrEqualTo(list.top));
    expect(glow.bottom, lessThanOrEqualTo(list.bottom - kBrushGoClearance));
    await timed.stopVoice();
  });

  testWidgets('timeline: the count waits for a description he taps', (
    tester,
  ) async {
    final timed = useTimedVoices(
      tester,
      lengths: const {
        'voice_picker_weapon_ice_hammer.mp3': Duration(seconds: 8),
        'voice_shop_nudge_default.mp3': Duration(seconds: 2),
      },
    );
    await pumpScreen(tester, returningKid);
    await tapGo(tester); // WEAPONS: two lines of 2 s
    await pumpFor(tester, const Duration(milliseconds: 4100));
    // Ice Hammer (14) is out of reach: its line, then the nudge.
    await tester.tap(find.byKey(const ValueKey('weapon_card_ice_hammer')));
    await tester.pump();
    final tapAt = timed.clock();
    await pumpFor(tester, const Duration(milliseconds: 10900));
    expect(stepIs(PreBrushStep.weapon), findsOneWidget);
    await pumpUntilFound(tester, stepIs(PreBrushStep.world));
    expect(
      timed.clock() - tapAt,
      greaterThanOrEqualTo(const Duration(seconds: 11)),
    );
    expect(
      timed.voiceNamed('voice_picker_weapon_ice_hammer.mp3')!.cut,
      isFalse,
    );
    // The Map's lines have just begun: end them, or their timer outlives the
    // test.
    await timed.stopVoice();
  });

  testWidgets('timeline: each tap re-arms the voice cap; the count waits '
      'for what he taps', (tester) async {
    // The real knobs. The step's lines and two descriptions he taps make
    // one unbroken run of voice of 18.5 s, longer than the 12 s cap.
    PreBrushScreen.idleAdvance = const Duration(seconds: 8);
    final timed = useTimedVoices(
      tester,
      lengths: const {
        'voice_step_pick_hero.mp3': Duration(milliseconds: 1672),
        'voice_stars_left_2.mp3': Duration(seconds: 1),
        'voice_picker_hero_bolt.mp3': Duration(seconds: 6),
        'voice_picker_hero_frost.mp3': Duration(seconds: 7),
        'voice_shop_nudge_default.mp3': Duration(seconds: 2),
      },
    );
    await pumpScreen(tester, returningKid);
    // Before the step's lines are over (2.7 s).
    await pumpFor(tester, const Duration(seconds: 2));
    // Bolt (8) and Frost (5) are out of reach: each tap plays the hero's
    // line, then the nudge.
    await tester.tap(find.byKey(const ValueKey('evo_cell_bolt_stage1')));
    final boltAt = timed.clock();
    await pumpFor(tester, const Duration(milliseconds: 7500));
    await tester.tap(find.byKey(const ValueKey('evo_cell_frost_stage1')));
    final frostAt = timed.clock();
    await pumpUntilFound(tester, stepIs(PreBrushStep.weapon));
    final lastLine = timed.voices.lastWhere(
      (v) => v.file == 'voice_shop_nudge_default.mp3',
    );
    final weapon = timed.voiceNamed('voice_step_pick_weapon.mp3')!;
    // His last line played out, and the whole idle time passed after it.
    expect(lastLine.cut, isFalse, reason: '${timed.voices}');
    expect(
      weapon.queuedAt - lastLine.endedAt!,
      greaterThanOrEqualTo(PreBrushScreen.idleAdvance),
      reason: '${timed.voices}',
    );
    // Only his own taps cut a line (the page's way), never a step change.
    for (final voice in timed.voices.where((v) => v.cut)) {
      expect(
        [boltAt, frostAt],
        contains(voice.endedAt),
        reason: '${timed.voices}',
      );
    }
    // The WEAPONS lines have just begun: end them, or their timer outlives
    // the test.
    await timed.stopVoice();
  });

  testWidgets('timeline: GO cuts the lines; the next ones never overlap', (
    tester,
  ) async {
    final timed = useTimedVoices(
      tester,
      lengths: const {'voice_step_pick_hero.mp3': Duration(milliseconds: 1672)},
    );
    await pumpScreen(tester, returningKid);
    await pumpFor(tester, const Duration(seconds: 1));
    await tapGo(tester); // inside "Pick the hero..."
    await pumpFor(tester, const Duration(seconds: 5));
    final hero = timed.voiceNamed('voice_step_pick_hero.mp3')!;
    final weapon = timed.voiceNamed('voice_step_pick_weapon.mp3')!;
    expect(hero.cut, isTrue);
    // The hero step's "two more stars" never played: dropped from the queue.
    expect(timed.voiceNamed('voice_stars_left_2.mp3')!.dropped, isTrue);
    expect(weapon.startedAt, greaterThanOrEqualTo(hero.endedAt!));
    final played = timed.voices.where((v) => v.startedAt != null).toList();
    for (var i = 1; i < played.length; i++) {
      expect(
        played[i].startedAt,
        greaterThanOrEqualTo(played[i - 1].endedAt!),
        reason: '$played',
      );
    }
    // A line may still be playing: end it, or its timer outlives the test.
    await timed.stopVoice();
  });

  testWidgets('timeline: a back inside a line cuts it; the step before speaks '
      'after the cut, never over it', (tester) async {
    PreBrushScreen.idleAdvance = const Duration(seconds: 30);
    // The clips' real lengths.
    final timed = useTimedVoices(
      tester,
      lengths: const {
        'voice_step_pick_hero.mp3': Duration(milliseconds: 1672),
        'voice_step_pick_weapon.mp3': Duration(milliseconds: 1071),
        'voice_stars_left_2.mp3': Duration(milliseconds: 993),
      },
    );
    SharedPreferences.setMockInitialValues(returningKid);
    await openFromHome(tester);
    await tapGo(tester); // WEAPONS: "Now pick your weapon!" (1.071 s) begins
    final weapon = timed.voiceNamed('voice_step_pick_weapon.mp3')!;
    expect(weapon.startedAt, isNotNull);
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(weapon.endedAt, isNull, reason: 'still inside the clip: $weapon');

    await systemBack(tester);
    expect(stepIs(PreBrushStep.hero), findsOneWidget);
    // The clip is cut where it was, 0.5 s in, and not left to run on.
    expect(weapon.cut, isTrue);
    expect(
      weapon.endedAt! - weapon.startedAt!,
      const Duration(milliseconds: 500),
    );
    await pumpFor(tester, const Duration(seconds: 4)); // the lines play out

    // The open's two lines (GO cut the first, dropped the second), WEAPONS'
    // two (the back cut the first, dropped the second), then HEROES' own.
    expect(timed.voices.map((v) => v.file), [
      'voice_step_pick_hero.mp3',
      'voice_stars_left_2.mp3',
      'voice_step_pick_weapon.mp3',
      'voice_stars_left_2.mp3',
      'voice_step_pick_hero.mp3',
      'voice_stars_left_2.mp3',
    ]);
    expect(timed.voices[3].dropped, isTrue, reason: 'WEAPONS\' progress line');
    final hero = timed.voices[4];
    final progress = timed.voices[5];
    expect(hero.cut || hero.dropped, isFalse, reason: '$hero');
    expect(progress.cut || progress.dropped, isFalse, reason: '$progress');
    expect(hero.startedAt, greaterThanOrEqualTo(weapon.endedAt!));
    expect(progress.startedAt, greaterThanOrEqualTo(hero.endedAt!));
    // Never two lines at once, anywhere in the run.
    final played = timed.voices.where((v) => v.startedAt != null).toList();
    for (var i = 1; i < played.length; i++) {
      expect(
        played[i].startedAt,
        greaterThanOrEqualTo(played[i - 1].endedAt!),
        reason: '$played',
      );
    }
    // A line may still be playing: end it, or its timer outlives the test.
    await timed.stopVoice();
  });

  // ── Phones ────────────────────────────────────────────────────

  for (final phone in const [
    (size: Size(360, 640), top: 24.0, bottom: 48.0),
    (size: Size(430, 932), top: 59.0, bottom: 34.0),
  ]) {
    final name = '${phone.size.width.toInt()}x${phone.size.height.toInt()}';
    testWidgets('fits a $name phone on every step, GO on screen', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(phone.size);
      final ratio = tester.view.devicePixelRatio;
      final insets = FakeViewPadding(
        top: phone.top * ratio,
        bottom: phone.bottom * ratio,
      );
      tester.view
        ..padding = insets
        ..viewPadding = insets;
      addTearDown(() async {
        tester.view
          ..resetPadding()
          ..resetViewPadding();
        await tester.binding.setSurfaceSize(null);
      });
      SharedPreferences.setMockInitialValues(
        kid({
          'unlocked_heroes': ['blaze', 'frost', 'bolt'],
          'unlocked_weapons': ['star_blaster', 'flame_sword'],
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          // The app's font (main.dart), so widths are a phone's.
          theme: ThemeData(
            textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Fredoka'),
          ),
          home: const PreBrushScreen(),
        ),
      );
      await tester.pump();
      await tester.pump();
      final screen = Offset.zero & phone.size;
      for (final step in PreBrushStep.values) {
        expect(stepIs(step), findsOneWidget);
        expect(tester.takeException(), isNull, reason: step.name);
        final headerRect = tester.getRect(header);
        expect(
          screen.intersect(headerRect),
          headerRect,
          reason: '${step.name}: $headerRect',
        );
        final goRect = tester.getRect(go);
        expect(
          screen.contains(goRect.topLeft) &&
              screen.contains(goRect.bottomRight),
          isTrue,
          reason: '${step.name}: $goRect',
        );
        if (step != PreBrushStep.world) {
          await tapGo(tester);
          await pumpFor(tester, const Duration(milliseconds: 500));
        }
      }
    });
  }

  group('brushing hand-off', () {
    Future<void> pumpBrushing(
      WidgetTester tester, {
      required bool showWorldIntro,
    }) async {
      SharedPreferences.setMockInitialValues({
        'phase_duration': 20,
        'camera_enabled': false,
        'selected_hero': 'blaze',
        'selected_weapon': 'star_blaster',
        'current_world': 'candy_crater',
        'total_brushes': 4,
        'muted': false,
      });
      await tester.binding.setSurfaceSize(const Size(430, 932));
      // The game screen's own layout is not under test here.
      final onError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        onError?.call(details);
      };
      addTearDown(() => FlutterError.onError = onError);
      await tester.pumpWidget(
        MaterialApp(home: BrushingScreen(showWorldIntro: showWorldIntro)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    Future<void> disposeBrushing(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2)); // initState's 1.5 s delay
      await tester.binding.setSurfaceSize(null);
    }

    testWidgets('after the pre-brush steps brushing starts at the countdown', (
      tester,
    ) async {
      await pumpBrushing(tester, showWorldIntro: false);
      expect(voices(), isNot(contains('voice_world_candy_crater.mp3')));
      expect(voices(), contains('voice_three.mp3'));
      expect(find.text('3'), findsWidgets);
      await disposeBrushing(tester);
    });

    testWidgets('by default brushing still opens with the world intro', (
      tester,
    ) async {
      await pumpBrushing(tester, showWorldIntro: true);
      expect(voices(), contains('voice_world_candy_crater.mp3'));
      expect(voices(), isNot(contains('voice_three.mp3')));
      await disposeBrushing(tester);
    });
  });
}
