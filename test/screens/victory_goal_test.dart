// test/screens/victory_goal_test.dart
import 'package:brush_quest/screens/victory_screen.dart';
import 'package:brush_quest/services/analytics_service.dart';
import 'package:brush_quest/services/audio_service.dart';
import 'package:brush_quest/services/streak_service.dart';
import 'package:brush_quest/services/world_service.dart';
import 'package:brush_quest/widgets/flame_view.dart';
import 'package:brush_quest/widgets/goal_art.dart';
import 'package:brush_quest/widgets/goal_meter.dart';
import 'package:brush_quest/widgets/item_silhouette.dart';
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

/// Records the events the victory screen sends. AnalyticsService only reaches
/// FirebaseAnalytics on Android (it is a no-op on the test host), so the
/// tests inject an Android-mode service around this fake.
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

typedef _Phone = ({Size size, double top, double bottom});

/// Two phones with the status and navigation bars real devices have (the
/// pre-brush tests use the same numbers).
const _small = (size: Size(360, 640), top: 24.0, bottom: 48.0);
const _big = (size: Size(430, 932), top: 59.0, bottom: 34.0);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String c(int hour, int streak, {required bool both}) =>
      VictoryScreen.closingVoiceFor(
        hour: hour,
        yesterdayBoth: both,
        newStreak: streak,
      );

  group('closingVoiceFor (spec 7.3)', () {
    test(
      'twice-a-day child brushing in the morning hears "see you tonight"',
      () {
        expect(c(8, 5, both: true), 'voice_forward_tonight.mp3');
      },
    );
    test('otherwise the flame closing line', () {
      expect(
        c(8, 2, both: false),
        'voice_flame_see_you_next.mp3',
      ); // 1 day to big
      expect(
        c(20, 4, both: true),
        'voice_flame_see_you_keep.mp3',
      ); // 3 days to hot
      expect(c(20, 6, both: false), 'voice_flame_see_you_next.mp3');
      expect(c(20, 30, both: false), 'voice_flame_see_you_keep.mp3'); // golden
    });
    test('morning ends at noon', () {
      expect(c(11, 5, both: true), 'voice_forward_tonight.mp3');
      expect(c(12, 5, both: true), 'voice_flame_see_you_keep.mp3');
    });
    test('both slots yesterday, not just one', () {
      // The caller passes morning && evening, so false covers "only one".
      expect(c(8, 5, both: false), 'voice_flame_see_you_keep.mp3');
    });
    test('one day to the next flame, at every step', () {
      expect(c(20, 2, both: false), 'voice_flame_see_you_next.mp3'); // big at 3
      expect(c(20, 6, both: false), 'voice_flame_see_you_next.mp3'); // hot at 7
      expect(
        c(20, 13, both: false),
        'voice_flame_see_you_next.mp3',
      ); // golden at 14
      expect(c(20, 14, both: false), 'voice_flame_see_you_keep.mp3'); // no next
    });
  });

  group('goal beat, world rockets and closing strip (widget)', () {
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
      VictoryScreen.debugAnalytics = analytics;
    });
    tearDown(() {
      AudioService.testInstance = null;
      VictoryScreen.debugAnalytics = null;
      StreakService.isPurchasing = false;
    });

    String day(int offset) {
      final d = DateTime.now().add(Duration(days: offset));
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    /// A child who brushed earlier today (a second brush: the streak stays 2,
    /// no flame line), owning only Blaze and the Star Blaster. His cheapest
    /// next unlocks are Frost and the Flame Sword, both 5 stars.
    Map<String, Object> base() => {
      'total_stars': 5,
      'current_streak': 2,
      'best_streak': 3,
      'last_brush_date': day(0),
      'today_brush_count': 1,
      'today_date': day(0),
      'total_brushes': 5,
      'selected_hero': 'blaze',
      'selected_weapon': 'star_blaster',
      'unlocked_heroes': ['blaze'],
      'unlocked_weapons': ['star_blaster'],
      'current_world': 'candy_crater',
      'collected_cards': <String>[],
      'muted': false,
    };

    /// Everything the Hero and Weapon shops sell is owned.
    Map<String, Object> allOwned() => {
      ...base(),
      'unlocked_heroes': ['blaze', 'frost', 'bolt', 'shadow', 'leaf', 'nova'],
      'selected_hero': 'nova',
      'unlocked_evolutions': [
        for (final hero in [
          'blaze',
          'frost',
          'bolt',
          'shadow',
          'leaf',
          'nova',
        ]) ...['${hero}_stage2', '${hero}_stage3'],
      ],
      'unlocked_weapons': [
        'star_blaster',
        'flame_sword',
        'ice_hammer',
        'lightning_wand',
        'vine_whip',
        'cosmic_burst',
      ],
    };

    /// Only the Flame Sword (5 stars) is left to unlock.
    Map<String, Object> weaponGoalOnly() => {
      ...allOwned(),
      'unlocked_weapons': ['star_blaster'],
    };

    final chestKey = find.byKey(const ValueKey('victory_chest'));
    final goalKey = find.byKey(const ValueKey('victory_goal'));
    final silhouette = find.descendant(
      of: goalKey,
      matching: find.byType(ItemSilhouette),
    );
    final goalSlots = find.descendant(
      of: goalKey,
      matching: find.byKey(const ValueKey('meter_filled')),
    );
    final goalEmptySlots = find.descendant(
      of: goalKey,
      matching: find.byKey(const ValueKey('meter_empty')),
    );

    Future<void> usePhone(WidgetTester tester, _Phone phone) async {
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
    }

    Future<void> pumpVictory(
      WidgetTester tester, {
      _Phone? phone,
      Size? size,
      String? trophy,
    }) async {
      if (phone != null) {
        await usePhone(tester, phone);
      } else {
        await tester.binding.setSurfaceSize(size ?? const Size(430, 932));
        addTearDown(() => tester.binding.setSurfaceSize(null));
      }
      await tester.pumpWidget(
        MaterialApp(
          home: VictoryScreen(
            totalHits: 10,
            monstersDefeated: 4,
            trophyTargetId: trophy,
          ),
        ),
      );
      await tester.pump();
    }

    /// The flame beat is done and the chest has dropped. A single long pump
    /// renders one frame at its end, so settle the chest's scale-in before
    /// tapping it.
    Future<void> pumpToChest(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 1));
    }

    /// An animation started inside one long pump gets its first frame at the
    /// pump's end, with no time elapsed. Pump [total] as 50 ms frames to let
    /// it run (scrolling into view, the monster card flying in).
    Future<void> frames(WidgetTester tester, Duration total) async {
      const frame = Duration(milliseconds: 50);
      for (var t = Duration.zero; t < total; t += frame) {
        await tester.pump(frame);
      }
    }

    /// Open the chest and run to just after the goal appears (0.5 s later),
    /// with its scroll into view finished. Its 1.2 s beat is not over yet.
    Future<void> pumpToGoal(WidgetTester tester) async {
      await pumpToChest(tester);
      await tester.tap(chestKey);
      await tester.pump(const Duration(milliseconds: 100));
      expect(chestKey, findsNothing);
      await tester.pump(const Duration(milliseconds: 500));
      await frames(tester, const Duration(milliseconds: 500));
    }

    /// Run the rest of the sequence out and let the achievement popups'
    /// auto-dismiss timers expire, then drop the screen.
    Future<void> drain(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 70));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }

    Future<SharedPreferences> prefsOf() => SharedPreferences.getInstance();

    List<String> voices() => fakeAudio.playedVoiceLines;

    AudioCall voiceCall(String file) => fakeAudio
        .callsFor('playVoice')
        .firstWhere((call) => call.args['fileName'] == file);

    List<Map<String, Object?>> eventsNamed(String name) =>
        recorder.events.where((e) => e['name'] == name).toList();

    group('the goal', () {
      testWidgets('affordable: one tap unlocks it once and selects it', (
        tester,
      ) async {
        // 3 + this brush's 2 + the chest's 1 to 5 stars: always 6 or more.
        SharedPreferences.setMockInitialValues({...base(), 'star_wallet': 3});
        await pumpVictory(tester);
        await pumpToGoal(tester);
        expect(goalKey, findsOneWidget);
        expect(silhouette, findsOneWidget); // still a silhouette
        final prefs = await prefsOf();
        final before = prefs.getInt('star_wallet')!;
        expect(before, greaterThanOrEqualTo(5));
        // Two quick taps: one spend, one voice line, one analytics event.
        await tester.tap(goalKey);
        await tester.tap(goalKey, warnIfMissed: false);
        await tester.pump(const Duration(seconds: 1));
        expect(prefs.getString('selected_hero'), 'frost');
        expect(prefs.getStringList('unlocked_heroes'), contains('frost'));
        expect(prefs.getInt('star_wallet'), before - 5);
        expect(voices().where((v) => v == 'voice_unlocked_yours.mp3'), [
          'voice_unlocked_yours.mp3',
        ]);
        expect(eventsNamed('goal_unlocked'), [
          {
            'name': 'goal_unlocked',
            'category': 'hero',
            'item': 'frost',
            'source': 'victory',
          },
        ]);
        expect(eventsNamed('hero_unlock'), hasLength(1));
        expect(silhouette, findsNothing); // the colours are on now
        // A later tap, long after, still does nothing more.
        await tester.tap(goalKey, warnIfMissed: false);
        await tester.pump(const Duration(seconds: 1));
        expect(prefs.getInt('star_wallet'), before - 5);
        expect(
          voices().where((v) => v == 'voice_unlocked_yours.mp3'),
          hasLength(1),
        );
        expect(eventsNamed('goal_unlocked'), hasLength(1));
        await drain(tester);
      });

      testWidgets(
        'a weapon goal: dimmed with a lock, then unlocked and equipped',
        (tester) async {
          SharedPreferences.setMockInitialValues({
            ...weaponGoalOnly(),
            'star_wallet': 3,
          });
          await pumpVictory(tester);
          await pumpToGoal(tester);
          // Opaque weapon art: dimmed, not a black box; clipped like the shop's.
          expect(tester.widget<ItemSilhouette>(silhouette).opaqueArt, isTrue);
          expect(
            find.descendant(of: silhouette, matching: find.byType(ClipRRect)),
            findsOneWidget,
          );
          final prefs = await prefsOf();
          final before = prefs.getInt('star_wallet')!;
          await tester.tap(goalKey);
          await tester.pump(const Duration(seconds: 1));
          expect(prefs.getString('selected_weapon'), 'flame_sword');
          expect(
            prefs.getStringList('unlocked_weapons'),
            contains('flame_sword'),
          );
          expect(prefs.getInt('star_wallet'), before - 5);
          expect(eventsNamed('weapon_unlock'), hasLength(1));
          expect(eventsNamed('goal_unlocked').single['category'], 'weapon');
          expect(silhouette, findsNothing);
          expect(
            find.descendant(of: goalKey, matching: find.byType(ClipRRect)),
            findsOneWidget, // the colour art, same clip
          );
          await drain(tester);
        },
      );

      testWidgets('a hero goal is a black silhouette, not a dimmed square', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({...base(), 'star_wallet': 3});
        await pumpVictory(tester);
        await pumpToGoal(tester);
        expect(tester.widget<ItemSilhouette>(silhouette).opaqueArt, isFalse);
        expect(
          find.descendant(of: silhouette, matching: find.byType(ClipRRect)),
          findsNothing,
        );
        await drain(tester);
      });

      testWidgets('an evolution goal unlocks the next stage of the hero', (
        tester,
      ) async {
        // Blaze's upgrade (10) is cheaper than Shadow (12); Ice Hammer is 14.
        SharedPreferences.setMockInitialValues({
          ...base(),
          'unlocked_heroes': ['blaze', 'frost', 'bolt'],
          'unlocked_weapons': ['star_blaster', 'flame_sword'],
          'star_wallet': 8, // 8 + 2 + the chest's 1 to 5 stars: 11 or more
        });
        await pumpVictory(tester);
        await pumpToGoal(tester);
        expect(goalSlots, findsNWidgets(10)); // full: 10 of 10
        final prefs = await prefsOf();
        final before = prefs.getInt('star_wallet')!;
        await tester.tap(goalKey);
        await tester.pump(const Duration(seconds: 1));
        expect(prefs.getStringList('unlocked_evolutions'), ['blaze_stage2']);
        expect(prefs.getInt('evolution_stage_blaze'), 2);
        expect(prefs.getInt('star_wallet'), before - 10);
        expect(eventsNamed('goal_unlocked').single['item'], 'blaze_stage2');
        await drain(tester);
      });

      testWidgets(
        'not affordable: the stars-left line, and a tap does nothing',
        (tester) async {
          // Next goals: blaze_stage2 10 (hero), ice_hammer 14 (weapon).
          // Wallet after this brush: 0 + 2 + 1..5 (chest) + 0..1 (modifier).
          SharedPreferences.setMockInitialValues({
            ...base(),
            'star_wallet': 0,
            'unlocked_heroes': ['blaze', 'frost', 'bolt'],
            'unlocked_weapons': ['star_blaster', 'flame_sword'],
          });
          await pumpVictory(tester);
          await pumpToGoal(tester);
          final prefs = await prefsOf();
          final wallet = prefs.getInt('star_wallet')!;
          expect(wallet, lessThan(10));
          expect(voices(), contains('voice_stars_left_${10 - wallet}.mp3'));
          expect(voices(), isNot(contains('voice_tap_to_unlock.mp3')));
          expect(goalSlots, findsNWidgets(wallet)); // the meter fills to it
          expect(goalEmptySlots, findsNWidgets(10 - wallet));
          await tester.tap(goalKey);
          await tester.pump(const Duration(seconds: 1));
          expect(prefs.getStringList('unlocked_evolutions'), isNull);
          expect(prefs.getInt('star_wallet'), wallet);
          expect(voices(), isNot(contains('voice_unlocked_yours.mp3')));
          expect(eventsNamed('goal_unlocked'), isEmpty);
          expect(silhouette, findsOneWidget);
          await drain(tester);
        },
      );

      testWidgets('the meter fills with this brush\'s stars', (tester) async {
        SharedPreferences.setMockInitialValues({
          ...base(),
          'star_wallet': 0,
          'unlocked_heroes': ['blaze', 'frost', 'bolt'],
          'unlocked_weapons': ['star_blaster', 'flame_sword'],
        });
        await pumpVictory(tester);
        await pumpToChest(tester);
        await tester.tap(chestKey);
        await tester.pump(const Duration(milliseconds: 700)); // goal appears
        // The stars the child had before this brush are in already; the new
        // ones come in after, so the meter is not at its end yet.
        final prefs = await prefsOf();
        final wallet = prefs.getInt('star_wallet')!;
        expect(goalSlots.evaluate().length, lessThan(wallet));
        await tester.pump(const Duration(milliseconds: 1500));
        expect(goalSlots, findsNWidgets(wallet));
        await drain(tester);
      });

      testWidgets('no goal beat when everything is owned', (tester) async {
        SharedPreferences.setMockInitialValues(allOwned());
        await pumpVictory(tester);
        await pumpToGoal(tester);
        expect(goalKey, findsNothing);
        expect(voices(), isNot(contains('voice_tap_to_unlock.mp3')));
        expect(
          voices().where((v) => v.startsWith('voice_stars_left_')),
          isEmpty,
        );
        await drain(tester);
      });

      testWidgets(
        'a refused purchase does not lock the goal: he can tap again',
        (tester) async {
          SharedPreferences.setMockInitialValues({...base(), 'star_wallet': 3});
          await pumpVictory(tester);
          await pumpToGoal(tester);
          final prefs = await prefsOf();
          final before = prefs.getInt('star_wallet')!;
          // Another purchase is in flight: the unlock is refused.
          StreakService.isPurchasing = true;
          await tester.tap(goalKey);
          await tester.pump(const Duration(milliseconds: 200));
          expect(prefs.getInt('star_wallet'), before);
          expect(voices(), isNot(contains('voice_unlocked_yours.mp3')));
          expect(eventsNamed('goal_unlocked'), isEmpty);
          expect(silhouette, findsOneWidget);
          StreakService.isPurchasing = false;
          await tester.tap(goalKey);
          await tester.pump(const Duration(seconds: 1));
          expect(prefs.getString('selected_hero'), 'frost');
          expect(prefs.getInt('star_wallet'), before - 5);
          expect(
            voices().where((v) => v == 'voice_unlocked_yours.mp3'),
            hasLength(1),
          );
          await drain(tester);
        },
      );

      testWidgets(
        'an unlock that fails with an error does not lock it either',
        (tester) async {
          SharedPreferences.setMockInitialValues({...base(), 'star_wallet': 3});
          await pumpVictory(tester);
          await pumpToGoal(tester);
          final prefs = await prefsOf();
          final before = prefs.getInt('star_wallet')!;
          // A wallet saved as the wrong type makes the purchase throw.
          await prefs.setString('star_wallet', 'oops');
          final printed = <String?>[];
          final original = debugPrint;
          debugPrint = (message, {wrapWidth}) => printed.add(message);
          try {
            await tester.tap(goalKey);
            await tester.pump(const Duration(milliseconds: 200));
          } finally {
            debugPrint = original;
          }
          expect(tester.takeException(), isNull);
          expect(printed.join(), contains('Goal unlock failed'));
          expect(voices(), isNot(contains('voice_unlocked_yours.mp3')));
          await prefs.setInt('star_wallet', before);
          await tester.tap(goalKey);
          await tester.pump(const Duration(seconds: 1));
          expect(prefs.getString('selected_hero'), 'frost');
          await drain(tester);
        },
      );

      testWidgets('a goal that cannot be worked out skips the beat only', (
        tester,
      ) async {
        // Wrong type for the owned weapons: the goal rules throw.
        SharedPreferences.setMockInitialValues({...base(), 'star_wallet': 3});
        await pumpVictory(tester);
        await pumpToChest(tester);
        final prefs = await prefsOf();
        await prefs.setString('unlocked_weapons', 'oops');
        final printed = <String?>[];
        final original = debugPrint;
        debugPrint = (message, {wrapWidth}) => printed.add(message);
        try {
          await tester.tap(chestKey);
          await tester.pump(const Duration(seconds: 3));
        } finally {
          debugPrint = original;
        }
        expect(goalKey, findsNothing);
        expect(printed.join(), contains('Goal beat skipped'));
        // The rest of the sequence still runs: the closing strip and DONE.
        await tester.pump(const Duration(seconds: 10));
        expect(find.byType(FlameStrip), findsOneWidget);
        expect(find.text('DONE'), findsOneWidget);
        await drain(tester);
      });

      testWidgets('leaving during the goal beat is safe', (tester) async {
        SharedPreferences.setMockInitialValues({...base(), 'star_wallet': 3});
        await pumpVictory(tester);
        await pumpToChest(tester);
        await tester.tap(chestKey);
        await tester.pump(const Duration(milliseconds: 700)); // beat is on
        expect(goalKey, findsOneWidget);
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        await tester.pump(const Duration(seconds: 5)); // its pause ends
        expect(tester.takeException(), isNull);
      });

      testWidgets('leaving right after the tap is safe', (tester) async {
        SharedPreferences.setMockInitialValues({...base(), 'star_wallet': 3});
        await pumpVictory(tester);
        await pumpToGoal(tester);
        await tester.tap(goalKey);
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        await tester.pump(const Duration(seconds: 5));
        expect(tester.takeException(), isNull);
      });
    });

    group('the voice around the goal', () {
      testWidgets(
        '"Tap to unlock it!" comes after the chest line and cuts nothing',
        (tester) async {
          SharedPreferences.setMockInitialValues({...base(), 'star_wallet': 3});
          await pumpVictory(tester);
          await pumpToGoal(tester);
          final spoken = voices();
          final chestLine = spoken.lastIndexWhere(
            (v) => v.startsWith('voice_chest_'),
          );
          expect(chestLine, isNonNegative);
          expect(
            spoken.indexOf('voice_tap_to_unlock.mp3'),
            greaterThan(chestLine),
          );
          final call = voiceCall('voice_tap_to_unlock.mp3');
          expect(call.args['interrupt'], isFalse);
          expect(call.args['clearQueue'], isFalse);
          await drain(tester);
        },
      );

      testWidgets('the stars-left line cuts nothing either', (tester) async {
        SharedPreferences.setMockInitialValues({
          ...base(),
          'star_wallet': 0,
          'unlocked_heroes': ['blaze', 'frost', 'bolt'],
          'unlocked_weapons': ['star_blaster', 'flame_sword'],
        });
        await pumpVictory(tester);
        await pumpToGoal(tester);
        final line = voices().firstWhere(
          (v) => v.startsWith('voice_stars_left_'),
        );
        expect(voiceCall(line).args['interrupt'], isFalse);
        expect(voiceCall(line).args['clearQueue'], isFalse);
        await drain(tester);
      });

      testWidgets('"It\'s yours!" answers the tap: it interrupts', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({...base(), 'star_wallet': 3});
        await pumpVictory(tester);
        await pumpToGoal(tester);
        await tester.tap(goalKey);
        await tester.pump(const Duration(milliseconds: 200));
        expect(voiceCall('voice_unlocked_yours.mp3').args['interrupt'], isTrue);
        await drain(tester);
      });

      testWidgets('after the comeback line, which is not cut', (tester) async {
        // The streak lapsed: a comeback brush (+3) before the goal beat.
        SharedPreferences.setMockInitialValues({
          ...base(),
          'last_brush_date': day(-5),
          'today_brush_count': 0,
          'current_streak': 9,
          'best_streak': 9,
          'star_wallet': 3,
        });
        await pumpVictory(tester);
        await pumpToChest(tester);
        await tester.tap(chestKey);
        await tester.pump(const Duration(seconds: 3));
        final spoken = voices();
        final comeback = spoken.indexOf('voice_first_comeback.mp3');
        expect(comeback, isNonNegative);
        expect(
          spoken.indexOf('voice_tap_to_unlock.mp3'),
          greaterThan(comeback),
        );
        expect(voiceCall('voice_tap_to_unlock.mp3').args['interrupt'], isFalse);
        await drain(tester);
      });

      testWidgets('muted: the goal still shows and nothing waits for a voice', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({...base(), 'star_wallet': 3});
        await fakeAudio.toggleMute();
        await pumpVictory(tester);
        await pumpToGoal(tester);
        expect(goalKey, findsOneWidget);
        expect(voices(), isEmpty);
        await tester.pump(const Duration(seconds: 15));
        expect(find.text('DONE'), findsOneWidget);
        await drain(tester);
      });
    });

    group('voice budget, timing and the full goal (review fixes)', () {
      /// This brush catches the last Candy Crater monster: the world is
      /// complete.
      Map<String, Object> lastCandyMonster() => {
        'trophy_captured': ['cc_t1', 'cc_t2', 'cc_t3', 'cc_t4'],
        'trophy_defeats_cc_t5': 2, // needs 3
      };

      testWidgets('a goal on a capture brush leaves the world-complete line '
          'its slot', (tester) async {
        SharedPreferences.setMockInitialValues({
          ...base(),
          'star_wallet': 3,
          ...lastCandyMonster(),
        });
        await pumpVictory(tester, trophy: 'cc_t5');
        await pumpToGoal(tester);
        expect(goalKey, findsOneWidget);
        await tester.pump(const Duration(seconds: 20));
        expect(voices(), contains('voice_card_new.mp3'));
        expect(voices(), contains('voice_world_complete.mp3'));
        await drain(tester);
      });

      testWidgets('a goal on a capture brush leaves the star milestone its '
          'slot', (tester) async {
        SharedPreferences.setMockInitialValues({
          ...base(),
          'total_stars': 68, // this brush passes 70
          'star_wallet': 3,
        });
        await pumpVictory(tester, trophy: 'cc_t1');
        await pumpToGoal(tester);
        expect(goalKey, findsOneWidget);
        await tester.pump(const Duration(seconds: 20));
        expect(voices(), contains('voice_milestone_70.mp3'));
        await drain(tester);
      });

      /// Lengths of the lines these tests turn on (afinfo); other lines take
      /// the fake's default 2 s.
      const realLengths = {
        'voice_card_new.mp3': Duration(milliseconds: 2664),
        'voice_card_cc_01.mp3': Duration(milliseconds: 4441),
        'voice_unlocked_yours.mp3': Duration(milliseconds: 1463),
        'voice_tap_to_unlock.mp3': Duration(milliseconds: 888),
        'voice_flame_see_you_next.mp3': Duration(milliseconds: 2769),
        'voice_flame_see_you_keep.mp3': Duration(milliseconds: 2273),
        'voice_forward_tonight.mp3': Duration(milliseconds: 3605),
        'voice_world_complete.mp3': Duration(milliseconds: 4624),
        'voice_milestone_70.mp3': Duration(milliseconds: 3553),
      };

      /// Installs a voice channel that takes time, with its clock on the
      /// test's fake time.
      TimedFakeAudioService useTimedVoices(
        WidgetTester tester, {
        Map<String, Duration> lengths = realLengths,
      }) {
        final timed = TimedFakeAudioService(lengths: lengths);
        final start = tester.binding.clock.now();
        timed.clock = () => tester.binding.clock.now().difference(start);
        AudioService.testInstance = timed;
        return timed;
      }

      /// With voices that take time the chest drops later: wait for it,
      /// let it scale in, open it.
      Future<void> openChestWhenItComes(WidgetTester tester) async {
        for (var i = 0; i < 200 && chestKey.evaluate().isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(chestKey, findsOneWidget);
        await frames(tester, const Duration(seconds: 1));
        await tester.tap(chestKey);
      }

      bool isClosing(TimedVoice v) =>
          v.file.startsWith('voice_flame_see_you_') ||
          v.file == 'voice_forward_tonight.mp3';

      testWidgets('the strip comes with its line, and DONE only after the '
          'line has played', (tester) async {
        final timed = useTimedVoices(tester);
        SharedPreferences.setMockInitialValues({...base(), 'star_wallet': 3});
        await pumpVictory(tester, trophy: 'cc_t1');
        await openChestWhenItComes(tester);
        Duration? stripAt;
        Duration? doneAt;
        for (var i = 0; i < 600 && doneAt == null; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          if (stripAt == null &&
              find.byType(FlameStrip).evaluate().isNotEmpty) {
            stripAt = timed.clock();
          }
          if (find.text('DONE').evaluate().isNotEmpty) doneAt = timed.clock();
        }
        final closing = timed.voices.lastWhere(isClosing);
        expect(doneAt, isNotNull);
        expect(closing.cut || closing.dropped, isFalse, reason: '$closing');
        // The card's lines were queued before it: the strip waits for them.
        expect(
          closing.startedAt! - stripAt!,
          lessThan(const Duration(milliseconds: 200)),
          reason: 'strip at $stripAt, ${timed.voices}',
        );
        expect(
          doneAt,
          greaterThanOrEqualTo(closing.endedAt!),
          reason: 'DONE at $doneAt, ${timed.voices}',
        );
        await drain(tester);
      });

      testWidgets('"It\'s yours!" answers the tap at once; the monster\'s name '
          'still plays in full after it', (tester) async {
        final timed = useTimedVoices(tester);
        SharedPreferences.setMockInitialValues({...base(), 'star_wallet': 3});
        await pumpVictory(tester, trophy: 'cc_t1');
        await openChestWhenItComes(tester);
        // Until the monster card's first line has been playing a moment.
        for (var i = 0; i < 300; i++) {
          final cardNew = timed.voiceNamed('voice_card_new.mp3');
          final playingFor = cardNew?.startedAt == null
              ? Duration.zero
              : timed.clock() - cardNew!.startedAt!;
          if (playingFor >= const Duration(milliseconds: 800)) break;
          await tester.pump(const Duration(milliseconds: 50));
        }
        final tapAt = timed.clock();
        await tester.tap(goalKey);
        await frames(tester, const Duration(seconds: 1));
        final yours = timed.voiceNamed('voice_unlocked_yours.mp3')!;
        expect(
          yours.startedAt! - tapAt,
          lessThan(const Duration(milliseconds: 200)),
          reason: 'tap at $tapAt, ${timed.voices}',
        );
        await tester.pump(const Duration(seconds: 10));
        final name = timed.voices.lastWhere(
          (v) => v.file == 'voice_card_cc_01.mp3',
        );
        expect(name.startedAt, isNotNull, reason: '${timed.voices}');
        expect(name.startedAt! >= yours.endedAt!, isTrue);
        expect(name.cut || name.dropped, isFalse, reason: '${timed.voices}');
        await drain(tester);
      });

      /// Pumps until [voice] has been playing for [into], then taps the goal.
      /// Returns the time of the tap.
      Future<Duration> tapGoalInto(
        WidgetTester tester,
        TimedFakeAudioService timed,
        String voice,
        Duration into,
      ) async {
        for (var i = 0; i < 400; i++) {
          final v = timed.voiceNamed(voice);
          if (v?.startedAt != null && timed.clock() - v!.startedAt! >= into) {
            break;
          }
          await tester.pump(const Duration(milliseconds: 50));
        }
        final tapAt = timed.clock();
        await tester.tap(goalKey);
        return tapAt;
      }

      testWidgets('a tap during the monster card still lets "world complete" '
          'play in full', (tester) async {
        final timed = useTimedVoices(tester);
        SharedPreferences.setMockInitialValues({
          ...base(),
          'star_wallet': 3,
          ...lastCandyMonster(),
        });
        await pumpVictory(tester, trophy: 'cc_t5');
        await openChestWhenItComes(tester);
        await tapGoalInto(
          tester,
          timed,
          'voice_card_new.mp3',
          const Duration(milliseconds: 800),
        );
        await tester.pump(const Duration(seconds: 25));
        final complete = timed.voices.where(
          (v) => v.file == 'voice_world_complete.mp3',
        );
        expect(
          complete.any((v) => v.endedAt != null && !v.cut && !v.dropped),
          isTrue,
          reason: '${timed.voices}',
        );
        await drain(tester);
      });

      testWidgets('a tap late in the monster\'s name: the strip still comes '
          'with its line, and DONE after it', (tester) async {
        final timed = useTimedVoices(tester);
        SharedPreferences.setMockInitialValues({...base(), 'star_wallet': 3});
        await pumpVictory(tester, trophy: 'cc_t1');
        await openChestWhenItComes(tester);
        await tapGoalInto(
          tester,
          timed,
          'voice_card_cc_01.mp3',
          const Duration(seconds: 4),
        );
        Duration? stripAt;
        Duration? doneAt;
        for (var i = 0; i < 600 && doneAt == null; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          if (stripAt == null &&
              find.byType(FlameStrip).evaluate().isNotEmpty) {
            stripAt = timed.clock();
          }
          if (find.text('DONE').evaluate().isNotEmpty) doneAt = timed.clock();
        }
        final closing = timed.voices.lastWhere(isClosing);
        expect(closing.cut || closing.dropped, isFalse, reason: '$closing');
        expect(
          closing.startedAt! - stripAt!,
          lessThan(const Duration(milliseconds: 200)),
          reason: 'strip at $stripAt, ${timed.voices}',
        );
        expect(
          doneAt,
          greaterThanOrEqualTo(closing.endedAt!),
          reason: 'DONE at $doneAt, ${timed.voices}',
        );
        await drain(tester);
      });

      testWidgets('DONE from the safety timer leaves within seconds, with the '
          'closing line once', (tester) async {
        // A world-complete line that never ends holds the sequence, so only
        // the 60 s safety timer brings DONE.
        final timed = useTimedVoices(
          tester,
          lengths: {
            ...realLengths,
            'voice_world_complete.mp3': const Duration(minutes: 5),
          },
        );
        SharedPreferences.setMockInitialValues({
          ...allOwned(),
          'star_wallet': 3,
          ...lastCandyMonster(),
        });
        final pushes = _PushLog(timed);
        await tester.binding.setSurfaceSize(const Size(430, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [pushes],
            home: const VictoryScreen(
              totalHits: 10,
              monstersDefeated: 4,
              trophyTargetId: 'cc_t5',
            ),
          ),
        );
        await tester.pump();
        await openChestWhenItComes(tester);
        final done = find.text('DONE');
        for (var i = 0; i < 800 && done.evaluate().isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(done, findsOneWidget);
        await frames(tester, const Duration(milliseconds: 500));
        final tapAt = timed.clock();
        pushes.at.clear();
        await tester.tap(done, warnIfMissed: false);
        for (var i = 0; i < 100 && pushes.at.isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(pushes.at, isNotEmpty, reason: 'it never went home');
        expect(
          pushes.at.first - tapAt,
          lessThan(const Duration(seconds: 6)),
          reason: '${timed.voices}',
        );
        final closingLines = timed.voices.where(isClosing).toList();
        expect(closingLines, hasLength(1), reason: '${timed.voices}');
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      });

      Finder goalFigure() =>
          find.descendant(of: goalKey, matching: find.byType(GoalArt));

      testWidgets('a full goal bounces until he taps it; unlocked, it rests at '
          'full size', (tester) async {
        SharedPreferences.setMockInitialValues({...base(), 'star_wallet': 3});
        await pumpVictory(tester);
        await pumpToGoal(tester);
        final tops = <double>{};
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          tops.add(tester.getRect(goalFigure()).top);
        }
        expect(tops.length, greaterThan(1), reason: 'it should bounce: $tops');
        // A bounce, not a size change.
        expect(tester.getRect(goalFigure()).width, closeTo(96, 0.5));
        await tester.tap(goalKey);
        await frames(tester, const Duration(seconds: 1));
        final settled = <double>{};
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          settled.add(tester.getRect(goalFigure()).top);
        }
        expect(settled, hasLength(1), reason: 'it should rest: $settled');
        expect(tester.getRect(goalFigure()).width, closeTo(96, 0.5));
        await drain(tester);
      });

      testWidgets('a goal that is not full stays still', (tester) async {
        SharedPreferences.setMockInitialValues({
          ...base(),
          'star_wallet': 0,
          'unlocked_heroes': ['blaze', 'frost', 'bolt'],
          'unlocked_weapons': ['star_blaster', 'flame_sword'],
        });
        await pumpVictory(tester);
        await pumpToGoal(tester);
        final tops = <double>{};
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          tops.add(tester.getRect(goalFigure()).top);
        }
        expect(tops, hasLength(1));
        await drain(tester);
      });
    });

    group('the goal stays on screen', () {
      /// The part of the screen the scroll view shows, below the top bar.
      Rect shown(_Phone phone) => Rect.fromLTRB(
        0,
        phone.top + 56, // the pills row: 8 px down, 48 px high at most
        phone.size.width,
        phone.size.height - phone.bottom,
      );

      for (final phone in const [_small, _big]) {
        final name = '${phone.size.width.toInt()}x${phone.size.height.toInt()}';

        testWidgets('$name: fully on screen when the beat starts, and still '
            'after the monster card comes in', (tester) async {
          SharedPreferences.setMockInitialValues({...base(), 'star_wallet': 3});
          await pumpVictory(tester, phone: phone, trophy: 'cc_t1');
          await pumpToGoal(tester);
          final area = shown(phone);
          Rect goalRect() => tester.getRect(goalKey);
          expect(
            area.contains(goalRect().topLeft),
            isTrue,
            reason: '${goalRect()} vs $area',
          );
          expect(
            area.contains(goalRect().bottomRight),
            isTrue,
            reason: '${goalRect()} vs $area',
          );
          // The sequence goes on: the monster card comes in below the goal.
          // Check as soon as it is in (and scrolled to), before the closing
          // beat brings the flame strip into view at the bottom.
          final badge = find.textContaining(RegExp('CAUGHT!|HIT!'));
          for (var i = 0; i < 200 && badge.evaluate().isEmpty; i++) {
            await tester.pump(const Duration(milliseconds: 50));
          }
          await frames(tester, const Duration(milliseconds: 450));
          expect(badge, findsOneWidget);
          expect(
            area.contains(goalRect().topLeft),
            isTrue,
            reason: '${goalRect()} vs $area',
          );
          expect(
            area.contains(goalRect().bottomRight),
            isTrue,
            reason: '${goalRect()} vs $area',
          );
          // The card is on screen too: the goal does not push it out of sight.
          final card = tester.getRect(
            find.textContaining(RegExp('CAUGHT!|HIT!')),
          );
          expect(area.contains(card.topLeft), isTrue, reason: '$card vs $area');
          expect(
            area.contains(card.bottomRight),
            isTrue,
            reason: '$card vs $area',
          );
          // And it can still be tapped there.
          final before = (await prefsOf()).getInt('star_wallet')!;
          await tester.tap(goalKey);
          await tester.pump(const Duration(seconds: 1));
          expect((await prefsOf()).getInt('star_wallet'), before - 5);
          await drain(tester);
        });
      }

      testWidgets('a tall phone shows it without scrolling anything', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({...base(), 'star_wallet': 3});
        await pumpVictory(tester, size: const Size(430, 1200));
        await pumpToGoal(tester);
        final scroll = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        expect(scroll.position.pixels, 0);
        expect(tester.getRect(goalKey).bottom, lessThan(1200));
        await drain(tester);
      });
      for (final phone in const [_small, _big]) {
        final name = '${phone.size.width.toInt()}x${phone.size.height.toInt()}';

        testWidgets('$name: the flame strip is on screen when its line starts, '
            'and DONE when it appears', (tester) async {
          SharedPreferences.setMockInitialValues({...base(), 'star_wallet': 3});
          await pumpVictory(tester, phone: phone, trophy: 'cc_t1');
          await pumpToChest(tester);
          await tester.tap(chestKey);
          final area = shown(phone);
          final strip = find.byType(FlameStrip);
          for (var i = 0; i < 400 && strip.evaluate().isEmpty; i++) {
            await tester.pump(const Duration(milliseconds: 50));
          }
          expect(strip, findsOneWidget);
          expect(voices().last, startsWith('voice_flame_see_you_'));
          await frames(tester, const Duration(milliseconds: 450)); // its scroll
          final stripRect = tester.getRect(strip);
          expect(
            area.contains(stripRect.topLeft),
            isTrue,
            reason: '$stripRect',
          );
          expect(
            area.contains(stripRect.bottomRight),
            isTrue,
            reason: '$stripRect vs $area',
          );
          final done = find.text('DONE');
          for (var i = 0; i < 300 && done.evaluate().isEmpty; i++) {
            await tester.pump(const Duration(milliseconds: 50));
          }
          await frames(tester, const Duration(milliseconds: 450));
          final doneRect = tester.getRect(done);
          expect(
            area.contains(doneRect.bottomRight),
            isTrue,
            reason: '$doneRect vs $area',
          );
          await drain(tester);
        });
      }
    });

    group('the world rockets', () {
      Finder rocketMeter() => find.byWidgetPredicate(
        (w) => w is GoalMeter && w.style == GoalMeterStyle.rockets,
      );

      testWidgets('sit under the world text and fill toward the next planet', (
        tester,
      ) async {
        // Candy Crater needs 5 missions; this brush makes the third.
        SharedPreferences.setMockInitialValues({
          ...base(),
          'star_wallet': 3,
          'world_progress_candy_crater': 2,
        });
        await pumpVictory(tester, trophy: 'cc_t1');
        await pumpToChest(tester);
        await tester.tap(chestKey);
        await tester.pump(const Duration(seconds: 5));
        await frames(tester, const Duration(seconds: 1)); // the card flies in
        final meter = tester.widget<GoalMeter>(rocketMeter());
        expect(meter.cost, 5);
        expect(meter.have, 3);
        expect(meter.unit, 18);
        expect(
          find.descendant(
            of: rocketMeter(),
            matching: find.byKey(const ValueKey('meter_filled')),
          ),
          findsNWidgets(3),
        );
        expect(
          find.descendant(
            of: rocketMeter(),
            matching: find.byKey(const ValueKey('meter_empty')),
          ),
          findsNWidgets(2),
        );
        // Directly under the world text, 6 px below it.
        final text = tester.getRect(
          find.text(
            '${WorldService.getWorldById('candy_crater').name} trophies collected!',
          ),
        );
        final rockets = tester.getRect(rocketMeter());
        expect(rockets.top, closeTo(text.bottom + 6, 0.5));
        expect(rockets.center.dx, closeTo(text.center.dx, 0.5));
        await drain(tester);
      });

      testWidgets('are not there without the world text', (tester) async {
        SharedPreferences.setMockInitialValues({...base(), 'star_wallet': 3});
        await pumpVictory(tester); // no trophy fight this brush
        await pumpToChest(tester);
        await tester.tap(chestKey);
        await tester.pump(const Duration(seconds: 6));
        expect(rocketMeter(), findsNothing);
        await drain(tester);
      });

      testWidgets('are not there once every planet is finished', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({
          ...base(),
          'star_wallet': 3,
          for (final world in WorldService.allWorlds)
            'world_progress_${world.id}': world.missionsRequired,
        });
        await pumpVictory(tester, trophy: 'cc_t1');
        await pumpToChest(tester);
        await tester.tap(chestKey);
        await tester.pump(const Duration(seconds: 6));
        expect(
          find.textContaining('trophies collected!'),
          findsOneWidget,
        ); // the world text is there
        expect(rocketMeter(), findsNothing);
        await drain(tester);
      });

      testWidgets('a brush on a finished planet: the showcase card shows the '
          'rockets to the next one', (tester) async {
        // Candy Crater is done and its monsters caught: no fight there, a
        // showcase card instead. The brush counts toward Slime Swamp.
        SharedPreferences.setMockInitialValues({
          ...base(),
          'star_wallet': 3,
          'world_progress_candy_crater': 5,
          'trophy_captured': ['cc_t1', 'cc_t2', 'cc_t3', 'cc_t4', 'cc_t5'],
        });
        await pumpVictory(tester);
        await pumpToChest(tester);
        await tester.tap(chestKey);
        await tester.pump(const Duration(seconds: 5));
        await frames(tester, const Duration(seconds: 1));
        final meter = tester.widget<GoalMeter>(rocketMeter());
        expect(
          meter.cost,
          WorldService.getWorldById('slime_swamp').missionsRequired,
        );
        expect(meter.have, 1);
        expect(find.textContaining('trophies collected!'), findsNothing);
        await drain(tester);
      });
    });

    group('the closing strip and line', () {
      testWidgets('the closing line plays and the flame strip shows', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues(base());
        await pumpVictory(tester);
        await pumpToChest(tester);
        await tester.tap(chestKey);
        await tester.pump(const Duration(seconds: 15));
        final last = voices().last;
        expect(
          last.startsWith('voice_flame_see_you_') ||
              last == 'voice_forward_tonight.mp3',
          isTrue,
          reason: 'last voice was $last',
        );
        expect(find.byType(FlameStrip), findsOneWidget);
        expect(tester.widget<FlameStrip>(find.byType(FlameStrip)).streak, 2);
        await drain(tester);
      });

      testWidgets('the flame line, by days to the next flame', (tester) async {
        // Streak 2 -> 1 day to the big flame, whatever the hour.
        SharedPreferences.setMockInitialValues(base());
        await pumpVictory(tester);
        await pumpToChest(tester);
        await tester.tap(chestKey);
        await tester.pump(const Duration(seconds: 15));
        expect(voices().last, 'voice_flame_see_you_next.mp3');
        await drain(tester);
      });

      testWidgets('"see you tonight" only after a morning, for a child who '
          'brushed both times yesterday', (tester) async {
        String record(String time) =>
            '{"date":"${day(-1)}","time":"$time","heroId":"blaze","worldId":"candy_crater"}';
        SharedPreferences.setMockInitialValues({
          ...base(),
          'brush_history': [record('08:00'), record('19:30')],
        });
        final morning = DateTime.now().hour < 12;
        await pumpVictory(tester);
        await pumpToChest(tester);
        await tester.tap(chestKey);
        await tester.pump(const Duration(seconds: 15));
        expect(
          voices().last,
          morning
              ? 'voice_forward_tonight.mp3'
              : 'voice_flame_see_you_next.mp3',
        );
        await drain(tester);
      });

      testWidgets('one slot yesterday is not both', (tester) async {
        SharedPreferences.setMockInitialValues({
          ...base(),
          'brush_history': [
            '{"date":"${day(-1)}","time":"19:30","heroId":"blaze","worldId":"candy_crater"}',
          ],
        });
        await pumpVictory(tester);
        await pumpToChest(tester);
        await tester.tap(chestKey);
        await tester.pump(const Duration(seconds: 15));
        expect(voices().last, 'voice_flame_see_you_next.mp3');
        await drain(tester);
      });

      testWidgets('the old forward hooks are gone', (tester) async {
        SharedPreferences.setMockInitialValues(base());
        await pumpVictory(tester);
        await pumpToChest(tester);
        await tester.tap(chestKey);
        await tester.pump(const Duration(seconds: 15));
        expect(voices(), isNot(contains('voice_full_power.mp3')));
        expect(voices(), isNot(contains('voice_forward_morning.mp3')));
        await drain(tester);
      });

      testWidgets('a history record that cannot be read does not stop DONE', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({
          ...base(),
          // No "time": reading yesterday's slots throws a TypeError.
          'brush_history': ['{"date":"${day(-1)}"}'],
        });
        final printed = <String?>[];
        final original = debugPrint;
        debugPrint = (message, {wrapWidth}) => printed.add(message);
        try {
          await pumpVictory(tester);
          await pumpToChest(tester);
          await tester.tap(chestKey);
          await tester.pump(const Duration(seconds: 15));
        } finally {
          debugPrint = original;
        }
        expect(find.text('DONE'), findsOneWidget);
        expect(find.byType(FlameStrip), findsOneWidget);
        expect(voices().last, 'voice_flame_see_you_next.mp3');
        expect(printed.join(), contains('Yesterday\'s slots unavailable'));
        await drain(tester);
      });

      testWidgets('a sequence that fails before the closing beat: DONE still '
          'plays the closing line once, then goes home', (tester) async {
        SharedPreferences.setMockInitialValues({...base(), 'star_wallet': 3});
        final pushes = _PushLog();
        await tester.binding.setSurfaceSize(const Size(430, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [pushes],
            home: const VictoryScreen(
              totalHits: 10,
              monstersDefeated: 4,
              trophyTargetId: 'cc_t1',
            ),
          ),
        );
        await tester.pump();
        await pumpToChest(tester);
        // A malformed save makes the trophy beat throw a TypeError.
        final prefs = await prefsOf();
        await prefs.setString('trophy_captured', 'oops');
        final printed = <String?>[];
        final original = debugPrint;
        debugPrint = (message, {wrapWidth}) => printed.add(message);
        try {
          await tester.tap(chestKey);
          await tester.pump(const Duration(seconds: 3));
        } finally {
          debugPrint = original;
        }
        expect(printed.join(), contains('Victory chest sequence error'));
        expect(find.text('DONE'), findsOneWidget);
        expect(find.byType(FlameStrip), findsNothing); // never reached
        await prefs.setStringList('trophy_captured', []); // for Home
        await frames(tester, const Duration(milliseconds: 500));
        await tester.tap(find.text('DONE'), warnIfMissed: false);
        for (var i = 0; i < 100 && pushes.at.isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(pushes.at, isNotEmpty, reason: 'it never went home');
        expect(
          voices().where((v) => v.startsWith('voice_flame_see_you_')),
          hasLength(1),
          reason: '${voices()}',
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      });

      testWidgets('DONE appears when muted', (tester) async {
        SharedPreferences.setMockInitialValues(base());
        await fakeAudio.toggleMute();
        await pumpVictory(tester);
        await pumpToChest(tester);
        await tester.tap(chestKey);
        await tester.pump(const Duration(seconds: 15));
        expect(find.text('DONE'), findsOneWidget);
        expect(find.byType(FlameStrip), findsOneWidget);
        await drain(tester);
      });

      testWidgets('the strip sits above DONE and below the goal', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({...base(), 'star_wallet': 3});
        await pumpVictory(tester, size: const Size(430, 1600));
        await pumpToChest(tester);
        await tester.tap(chestKey);
        await tester.pump(const Duration(seconds: 15));
        final strip = tester.getRect(find.byType(FlameStrip));
        expect(strip.bottom, lessThan(tester.getRect(find.text('DONE')).top));
        expect(strip.top, greaterThan(tester.getRect(goalKey).bottom));
        await drain(tester);
      });

      for (final width in [320.0, 280.0]) {
        testWidgets('the strip cannot overflow at ${width.toInt()} dp, even on '
            'day 7 (the longest)', (tester) async {
          // Streak 6 -> 7: the hot flame with 7 days to go, 282 px wide.
          SharedPreferences.setMockInitialValues({
            ...base(),
            'current_streak': 6,
            'last_brush_date': day(-1),
            'today_brush_count': 0,
            'today_date': day(-1),
            'star_wallet': 3,
          });
          await pumpVictory(tester, size: Size(width, 700));
          await pumpToChest(tester);
          await tester.tap(chestKey);
          await tester.pump(const Duration(seconds: 15));
          final strip = find.byType(FlameStrip);
          expect(strip, findsOneWidget);
          expect(tester.widget<FlameStrip>(strip).streak, 7);
          expect(tester.takeException(), isNull);
          final rect = tester.getRect(strip);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(width));
          await drain(tester);
        });
      }
    });
  });
}

/// Records when routes are pushed (the victory screen going home).
class _PushLog extends NavigatorObserver {
  _PushLog([this.timed]);

  final TimedFakeAudioService? timed;
  final List<Duration> at = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) at.add(timed?.clock() ?? Duration.zero);
  }
}
