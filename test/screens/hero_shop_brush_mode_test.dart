// test/screens/hero_shop_brush_mode_test.dart
//
// The Heroes & Weapons page in brush mode (spec 2026-10-13 §4, §5) and the
// pins that it is unchanged when opened from Home (R6).
import 'package:brush_quest/screens/brush_mode.dart';
import 'package:brush_quest/screens/hero_shop_screen.dart';
import 'package:brush_quest/services/analytics_service.dart';
import 'package:brush_quest/services/audio_service.dart';
import 'package:brush_quest/services/goal_service.dart';
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

/// Records events (AnalyticsService is a no-op on the test host).
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

/// The purchase dialog (unchanged, and shared with Home) has a button row
/// 1.1 px too wide for the test font at 430 px, and Flutter reports that
/// overflow as a test failure. The buy tests use this width instead; they
/// assert nothing about layout.
const _buyWidth = 440.0;

/// Stands in for the brush steps: owns what the page follows and records
/// what it reports.
class _Steps {
  final tab = ValueNotifier<int>(0);
  final highlight = ValueNotifier<String?>(null);
  final reveal = BrushPing();
  final tabsReported = <int>[];
  final changes = <BrushChange>[];
  int closes = 0;

  late final mode = BrushMode(
    onClose: () => closes++,
    tab: tab,
    onTabChanged: tabsReported.add,
    highlightId: highlight,
    reveal: reveal,
    onChanged: changes.add,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeAudioService fakeAudio;
  late _RecordingAnalytics recorder;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    for (final name in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), (call) async => 1);
    }
  });

  setUp(() async {
    fakeAudio = FakeAudioService();
    AudioService.testInstance = fakeAudio;
    recorder = _RecordingAnalytics();
    final analytics = AnalyticsService.forTesting(
      isAndroid: true,
      analytics: recorder,
    );
    await analytics.init();
    HeroShopScreen.debugAnalytics = analytics;
  });

  tearDown(() {
    AudioService.testInstance = null;
    HeroShopScreen.debugAnalytics = null;
    StreakService.isPurchasing = false;
  });

  Future<_Steps> pumpShop(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
    bool brush = true,
    String? highlight,
    int tab = 0,
    double width = 430,
  }) async {
    SharedPreferences.setMockInitialValues({
      'star_wallet': 3,
      'total_stars': 13,
      'unlocked_heroes': ['blaze'],
      'selected_hero': 'blaze',
      'unlocked_weapons': ['star_blaster'],
      'selected_weapon': 'star_blaster',
      'muted': false,
      'current_world': 'candy_crater',
      ...prefs,
    });
    await tester.binding.setSurfaceSize(Size(width, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final steps = _Steps()
      ..highlight.value = highlight
      ..tab.value = tab;
    await tester.pumpWidget(
      MaterialApp(
        home: brush
            ? HeroShopScreen(brushMode: steps.mode)
            : const HeroShopScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    return steps;
  }

  Finder glowIn(String key) => find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(GoalGlow),
  );

  ScrollableState heroList(WidgetTester tester) =>
      tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );

  Iterable<Map<String, Object?>> shopVisits() =>
      recorder.events.where((e) => e['name'] == 'shop_visit');

  Future<void> buy(WidgetTester tester, Finder item) async {
    await tester.tap(item);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('YES!'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('brush mode', () {
    testWidgets('an X instead of the back arrow; it asks the steps to close', (
      tester,
    ) async {
      final steps = await pumpShop(tester);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(find.byIcon(Icons.close), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('brush_close')));
      await tester.pump();
      expect(steps.closes, 1);
      // The steps stop the voice when they close, not the page.
      expect(fakeAudio.callsFor('stopVoice'), isEmpty);
    });

    testWidgets('no entry line, tab line, music or shop visit', (tester) async {
      await pumpShop(tester);
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('WEAPONS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(fakeAudio.playedVoiceLines, isEmpty);
      expect(fakeAudio.callsFor('playMusic'), isEmpty);
      expect(fakeAudio.callsFor('setMusicVolume'), isEmpty);
      expect(shopVisits(), isEmpty);
    });

    testWidgets('follows the steps to WEAPONS without reporting it back', (
      tester,
    ) async {
      final steps = await pumpShop(tester);
      steps.tab.value = 1;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 1);
      expect(
        find.byKey(const ValueKey('weapon_card_flame_sword')),
        findsOneWidget,
      );
      expect(steps.tabsReported, isEmpty);
    });

    testWidgets('reports a tab tap and a swipe to the steps', (tester) async {
      final steps = await pumpShop(tester);
      await tester.tap(find.text('WEAPONS'));
      await tester.pump();
      expect(steps.tabsReported, [1]);
      steps.tab.value = 1; // the steps take the weapon step
      await tester.pump(const Duration(milliseconds: 400));
      await tester.fling(find.byType(TabBarView), const Offset(300, 0), 1500);
      // A swipe reaches the tab controller only once the page has settled,
      // about 0.75 s after the fling.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(steps.tabsReported, [1, 0]);
      expect(fakeAudio.playedVoiceLines, isEmpty); // no tab lines
    });

    testWidgets('the highlighted hero cell glows, and only it', (tester) async {
      final steps = await pumpShop(tester, highlight: 'frost_stage1');
      expect(glowIn('evo_cell_frost_stage1'), findsOneWidget);
      expect(find.byType(GoalGlow), findsOneWidget);
      steps.highlight.value = 'blaze_stage2';
      await tester.pump();
      expect(glowIn('evo_cell_blaze_stage2'), findsOneWidget);
      expect(find.byType(GoalGlow), findsOneWidget);
      steps.highlight.value = null;
      await tester.pump();
      expect(find.byType(GoalGlow), findsNothing);
    });

    testWidgets('the highlighted weapon card glows', (tester) async {
      await pumpShop(tester, tab: 1, highlight: 'flame_sword');
      expect(glowIn('weapon_card_flame_sword'), findsOneWidget);
      expect(find.byType(GoalGlow), findsOneWidget);
    });

    testWidgets('a reveal scrolls a far-down glow above GO', (tester) async {
      final steps = await pumpShop(tester, highlight: 'nova_stage1');
      final list = tester.getRect(find.byType(ListView));
      // Built (the brush-mode cache extent) but scrolled away: the default
      // finder skips what is off screen, so it could not see the glow.
      final glowFinder = find.byType(GoalGlow, skipOffstage: false);
      expect(
        tester.getRect(glowFinder).bottom,
        greaterThan(list.bottom - kBrushGoClearance),
        reason: 'Nova is the last row: off screen at first',
      );
      steps.reveal.ping();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      final glow = tester.getRect(glowFinder);
      expect(glow.top, greaterThanOrEqualTo(list.top));
      expect(glow.bottom, lessThanOrEqualTo(list.bottom - kBrushGoClearance));
    });

    testWidgets('a reveal leaves a glow already on screen alone', (
      tester,
    ) async {
      final steps = await pumpShop(tester, highlight: 'frost_stage1');
      steps.reveal.ping();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(heroList(tester).position.pixels, 0);
    });

    testWidgets('the last row can scroll above GO', (tester) async {
      await pumpShop(tester);
      expect(
        tester.widget<ListView>(find.byType(ListView)).padding,
        const EdgeInsets.fromLTRB(12, 8, 12, 16 + kBrushGoClearance),
      );
      final position = heroList(tester).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      expect(
        tester
            .getRect(find.byKey(const ValueKey('evo_cell_nova_stage1')))
            .bottom,
        lessThanOrEqualTo(
          tester.getRect(find.byType(ListView)).bottom - kBrushGoClearance,
        ),
      );
    });

    testWidgets('buying a hero: the page celebrates, equips and reports it', (
      tester,
    ) async {
      final steps = await pumpShop(
        tester,
        prefs: {'star_wallet': 6},
        highlight: 'frost_stage1',
        width: _buyWidth,
      );
      await buy(tester, find.byKey(const ValueKey('evo_cell_frost_stage1')));
      expect(find.text('FROST UNLOCKED!'), findsOneWidget);
      expect(fakeAudio.playedVoiceLines.last, 'voice_intro_hero_frost.mp3');
      await tester.pump(const Duration(seconds: 7)); // it closes after 6 s
      await tester.pump(const Duration(milliseconds: 500)); // and fades out
      expect(find.text('FROST UNLOCKED!'), findsNothing);
      expect(steps.changes, [
        const BrushChange.unlocked(GoalCategory.hero, 'frost'),
      ]);
      final saved = await SharedPreferences.getInstance();
      expect(saved.getString('selected_hero'), 'frost');
      expect(saved.getInt('star_wallet'), 1);
    });

    testWidgets('equipping an owned upgrade reports a selection', (
      tester,
    ) async {
      final steps = await pumpShop(
        tester,
        prefs: {
          'unlocked_evolutions': ['blaze_stage2'],
        },
      );
      await tester.tap(find.byKey(const ValueKey('evo_cell_blaze_stage2')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(steps.changes, [const BrushChange.selected(GoalCategory.hero)]);
      expect(fakeAudio.playedVoiceLines, ['voice_picker_evo_blaze_stage2.mp3']);
      final saved = await SharedPreferences.getInstance();
      expect(saved.getInt('evolution_stage_blaze'), 2);
    });

    testWidgets('buying a weapon reports it', (tester) async {
      final steps = await pumpShop(
        tester,
        prefs: {'star_wallet': 6},
        tab: 1,
        highlight: 'flame_sword',
        width: _buyWidth,
      );
      await buy(tester, find.byKey(const ValueKey('weapon_card_flame_sword')));
      await tester.pump(const Duration(seconds: 7)); // it closes after 6 s
      expect(steps.changes, [
        const BrushChange.unlocked(GoalCategory.weapon, 'flame_sword'),
      ]);
      final saved = await SharedPreferences.getInstance();
      expect(saved.getString('selected_weapon'), 'flame_sword');
    });

    testWidgets('leaving the page leaves the voice to the steps', (
      tester,
    ) async {
      await pumpShop(tester);
      await tester.pumpWidget(const SizedBox());
      expect(fakeAudio.callsFor('stopVoice'), isEmpty);
    });
  });

  group('from Home (unchanged)', () {
    testWidgets('entry line, tab line, music and shop visit as before', (
      tester,
    ) async {
      await pumpShop(tester, brush: false);
      expect(fakeAudio.playedVoiceLines, ['voice_entry_hero_hq.mp3']);
      expect(
        fakeAudio.calls,
        contains(
          const AudioCall('playMusic', {
            'fileName': 'battle_music_loop.mp3',
            'isRetry': false,
          }),
        ),
      );
      expect(
        fakeAudio.calls,
        contains(const AudioCall('setMusicVolume', {'volume': 0.05})),
      );
      expect(shopVisits(), hasLength(1));
      await tester.tap(find.text('WEAPONS'));
      await tester.pump();
      expect(fakeAudio.playedVoiceLines.last, 'voice_tab_weapons.mp3');
    });

    testWidgets('a back arrow, its own padding, no X and no glow', (
      tester,
    ) async {
      await pumpShop(tester, brush: false);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.byType(GoalGlow), findsNothing);
      expect(
        tester.widget<ListView>(find.byType(ListView)).padding,
        const EdgeInsets.fromLTRB(12, 8, 12, 16),
      );
    });

    testWidgets('leaving the page stops the voice, as before', (tester) async {
      await pumpShop(tester, brush: false);
      await tester.pumpWidget(const SizedBox());
      expect(fakeAudio.callsFor('stopVoice'), isNotEmpty);
    });
  });
}
