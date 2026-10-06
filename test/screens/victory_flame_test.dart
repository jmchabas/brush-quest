import 'dart:async';

import 'package:brush_quest/screens/victory_screen.dart';
import 'package:brush_quest/services/audio_service.dart';
import 'package:brush_quest/services/flame_tier.dart';
import 'package:brush_quest/widgets/flame_view.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/fake_audio_service.dart';

/// What the chest looks like per streak step (spec §7.1): body gradient,
/// body edge and band colour.
typedef _Look = ({Color top, Color bottom, Color edge, Color band});

const _Look _wooden = (
  top: Color(0xFF8D5A33),
  bottom: Color(0xFF5D3420),
  edge: Color(0xFF4E2A17),
  band: Color(0xFFFFC107), // the original band fill: wooden must not change
);
const _Look _silver = (
  top: Color(0xFFCFD8DC),
  bottom: Color(0xFF90A4AE),
  edge: Color(0xFF607D8B),
  band: Color(0xFFECEFF1),
);
const _Look _gold = (
  top: Color(0xFFFFE082),
  bottom: Color(0xFFFFB300),
  edge: Color(0xFFE65100),
  band: Color(0xFFFFF8E1),
);

// The original chest's lid and lock, which only the wooden chest keeps.
const _woodenLid = [Color(0xFFB77845), Color(0xFF7A4A2D)];
const _woodenLidEdge = Color(0xFF5F371F);
const _woodenLock = [Color(0xFFFFF176), Color(0xFFFFC107)];
const _woodenLockEdge = Color(0xFFFFA000);
const _woodenLockIcon = Color(0xFF6D4C41);

/// Every colour only the wooden chest uses (body, edge, lid, lock, bands).
final _woodenOnly = <Color>{
  _wooden.top,
  _wooden.bottom,
  _wooden.edge,
  _wooden.band,
  ..._woodenLid,
  _woodenLidEdge,
  ..._woodenLock,
  _woodenLockEdge,
  _woodenLockIcon,
};

bool _isArcBeat2(String file) =>
    RegExp(r'^voice_victory_arc\d+_beat2\.mp3$').hasMatch(file);

/// A fake whose arc-beat-2 voice stays "playing" until the test ends it by
/// hand, like a real clip that takes a while. Muted, it returns at once, as
/// the real service does.
class _HeldArcAudio extends FakeAudioService {
  final Completer<void> arcBeat2 = Completer<void>();

  @override
  Future<void> playVoice(
    String fileName, {
    bool clearQueue = false,
    bool interrupt = false,
  }) async {
    await super.playVoice(
      fileName,
      clearQueue: clearQueue,
      interrupt: interrupt,
    );
    if (isMuted || !_isArcBeat2(fileName)) return;
    await arcBeat2.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String? v(int prev, int next, {int mult = 0, int comeback = 0}) =>
      VictoryScreen.flameBeatVoiceFor(
        previousStreak: prev,
        newStreak: next,
        streakMultiplierBonus: mult,
        comebackBonus: comeback,
      );

  test('tier-up lines win', () {
    expect(v(2, 3, mult: 1), 'voice_flame_tier_3.mp3');
    expect(v(6, 7, mult: 2), 'voice_flame_tier_7.mp3');
    expect(v(13, 14, mult: 2), 'voice_flame_tier_14.mp3');
  });
  test('bonus lines when the flame pays out', () {
    expect(v(3, 4, mult: 1), 'voice_flame_bonus_1.mp3');
    expect(v(8, 9, mult: 2), 'voice_flame_bonus_2.mp3');
    expect(v(4, 4, mult: 1), 'voice_flame_bonus_1.mp3'); // second brush today
  });
  test('new flame after a break or on the very first day', () {
    expect(v(9, 1, comeback: 3), 'voice_flame_new.mp3');
    expect(v(0, 1), 'voice_flame_new.mp3');
  });
  test('grow on days 1-2, nothing on a second brush the same day', () {
    expect(v(1, 2), 'voice_flame_grow.mp3');
    expect(v(2, 2), isNull);
  });

  group('flame beat in the victory sequence', () {
    late FakeAudioService fakeAudio;

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
    setUp(() {
      fakeAudio = FakeAudioService();
      AudioService.testInstance = fakeAudio;
    });
    tearDown(() => AudioService.testInstance = null);

    String day(int offset) {
      final d = DateTime.now().add(Duration(days: offset));
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    final chestKey = find.byKey(const ValueKey('victory_chest'));

    /// A kid whose last brush was [lastBrushDaysAgo] days ago, with a
    /// [streak]-day streak. Yesterday continues the streak (this brush makes it
    /// [streak] + 1), today is a second brush, and 3+ days ago breaks it.
    void seedPrefs({
      required int streak,
      int lastBrushDaysAgo = 1,
      Map<String, Object> extra = const {},
    }) {
      SharedPreferences.setMockInitialValues({
        'total_stars': 5,
        'star_wallet': 0,
        'current_streak': streak,
        'best_streak': streak,
        'last_brush_date': day(-lastBrushDaysAgo),
        'total_brushes': 5,
        'selected_hero': 'blaze',
        'selected_weapon': 'star_blaster',
        'unlocked_heroes': ['blaze'],
        'unlocked_weapons': ['star_blaster'],
        'current_world': 'candy_crater',
        'collected_cards': <String>[],
        'muted': false,
        ...extra,
      });
    }

    Future<void> pumpVictory(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(
          home: VictoryScreen(totalHits: 10, monstersDefeated: 4),
        ),
      );
      await tester.pump();
    }

    /// Flame beat done and the chest dropped. A single long pump renders one
    /// frame at its end, so the chest's elastic scale-in has not started yet:
    /// settle it before tapping.
    Future<void> pumpToChest(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 1));
    }

    /// Run the rest of the sequence out, then let the achievement popups'
    /// 3 s auto-dismiss timers (started by the last frame) expire.
    Future<void> drain(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 70));
      await tester.pump(const Duration(seconds: 5));
    }

    /// Tap the chest and prove it opened (the closed chest has the key).
    Future<void> openChest(WidgetTester tester) async {
      await tester.tap(chestKey);
      await tester.pump(const Duration(milliseconds: 100));
      expect(chestKey, findsNothing);
    }

    /// A box with this two-colour vertical gradient and this border colour
    /// (the chest body, lid or lock).
    Finder gradientBox(List<Color> colors, Color edge) =>
        find.byWidgetPredicate((w) {
          if (w is! DecoratedBox) return false;
          final decoration = w.decoration;
          if (decoration is! BoxDecoration) return false;
          final gradient = decoration.gradient;
          final border = decoration.border;
          return gradient is LinearGradient &&
              listEquals(gradient.colors, colors) &&
              border is Border &&
              border.top.color == edge;
        });

    /// The straps: flat-coloured rounded boxes with a border (of colour
    /// [edge], when given).
    Finder bandBox(Color band, {Color? edge}) => find.byWidgetPredicate((w) {
      if (w is! DecoratedBox) return false;
      final decoration = w.decoration;
      if (decoration is! BoxDecoration || decoration.color != band) {
        return false;
      }
      final border = decoration.border;
      return border is Border && (edge == null || border.top.color == edge);
    });

    /// The bonus stars of the flame beat (22 px amber stars), one per star.
    final bonusStars = find.byWidgetPredicate(
      (w) =>
          w is Icon &&
          w.icon == Icons.star &&
          w.color == Colors.amberAccent &&
          w.size == 22,
    );

    /// Total area (px squared) where the bonus stars overlap the flame.
    double starsOverFlame(WidgetTester tester) {
      final flame = tester.getRect(find.byType(FlameIcon));
      var area = 0.0;
      for (var i = 0; i < bonusStars.evaluate().length; i++) {
        final overlap = flame.intersect(tester.getRect(bonusStars.at(i)));
        if (overlap.width > 0 && overlap.height > 0) {
          area += overlap.width * overlap.height;
        }
      }
      return area;
    }

    /// The chest's own widgets: the closed chest carries the key, the opened
    /// chest is the 260x280 box. Scoping keeps the rest of the screen out.
    Finder chestRoot({required bool opened}) => opened
        ? find.byWidgetPredicate(
            (w) => w is SizedBox && w.width == 260 && w.height == 280,
          )
        : chestKey;

    /// Chest pieces still drawn in a colour only the wooden chest uses.
    Finder woodenRemnants({required bool opened}) => find.descendant(
      of: chestRoot(opened: opened),
      matching: find.byWidgetPredicate((w) {
        if (w is Icon) return _woodenOnly.contains(w.color);
        if (w is! DecoratedBox) return false;
        final decoration = w.decoration;
        if (decoration is! BoxDecoration) return false;
        final border = decoration.border;
        return [
          decoration.color,
          ...?decoration.gradient?.colors,
          if (border is Border) border.top.color,
        ].any(_woodenOnly.contains);
      }),
    );

    FlameTier shownFlame(WidgetTester tester) =>
        tester.widget<FlameIcon>(find.byType(FlameIcon)).tier;

    testWidgets('reaching 3 days: tier line before the chest, old lines gone', (
      tester,
    ) async {
      seedPrefs(streak: 2); // this brush makes the streak 3
      await pumpVictory(tester);
      await pumpToChest(tester); // flame beat, chest drops
      final voices = fakeAudio.playedVoiceLines;
      expect(voices, contains('voice_flame_tier_3.mp3'));
      expect(bonusStars, findsOneWidget); // the big flame pays +1 star
      expect(chestKey, findsOneWidget);
      final before = voices.length;
      await openChest(tester);
      await tester.pump(const Duration(seconds: 2));
      // Chest voices come after the flame line.
      expect(voices.length, greaterThan(before));
      expect(voices.indexOf('voice_flame_tier_3.mp3'), lessThan(before));
      expect(voices, isNot(contains('voice_first_streak_3.mp3')));
      expect(voices, isNot(contains('voice_chest_streak_bonus.mp3')));
      await drain(tester);
    });

    testWidgets('reaching 7 days: week line, none of the old streak lines', (
      tester,
    ) async {
      seedPrefs(streak: 6); // this brush makes the streak 7
      await pumpVictory(tester);
      await pumpToChest(tester);
      expect(bonusStars, findsNWidgets(2)); // the hot flame pays +2 stars
      await openChest(tester);
      await tester.pump(const Duration(seconds: 2));
      final voices = fakeAudio.playedVoiceLines;
      expect(voices, contains('voice_flame_tier_7.mp3'));
      expect(voices, isNot(contains('voice_first_streak_7.mp3')));
      expect(voices, isNot(contains('voice_chest_mega_streak.mp3')));
      await drain(tester);
    });

    testWidgets('the flame shows before the chest, and stays on screen', (
      tester,
    ) async {
      seedPrefs(streak: 2); // streak 3 -> the big flame
      await pumpVictory(tester);
      expect(find.byType(FlameIcon), findsNothing);
      await tester.pump(const Duration(milliseconds: 2000)); // mid flame beat
      expect(find.byType(FlameIcon), findsOneWidget);
      expect(shownFlame(tester), FlameTier.big);
      expect(chestKey, findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(chestKey, findsOneWidget);
      expect(shownFlame(tester), FlameTier.big);
      await drain(tester);
    });

    testWidgets('a second brush today shows the flame and says nothing', (
      tester,
    ) async {
      seedPrefs(streak: 2, lastBrushDaysAgo: 0); // streak stays 2
      await pumpVictory(tester);
      await pumpToChest(tester);
      expect(shownFlame(tester), FlameTier.small);
      expect(bonusStars, findsNothing);
      expect(chestKey, findsOneWidget);
      expect(
        fakeAudio.playedVoiceLines.where((l) => l.startsWith('voice_flame_')),
        isEmpty,
      );
      await drain(tester);
    });

    group('comeback day: the +3 works as today, apart from the flame', () {
      testWidgets('first time: no flame stars, the welcome-back line comes '
          'after the chest opens', (tester) async {
        seedPrefs(streak: 9, lastBrushDaysAgo: 5); // streak lapsed, restarts
        await pumpVictory(tester);
        await pumpToChest(tester);
        expect(shownFlame(tester), FlameTier.small);
        // A small flame pays nothing; the 3 comeback stars are not its.
        expect(bonusStars, findsNothing);
        final voices = fakeAudio.playedVoiceLines;
        expect(voices, contains('voice_flame_new.mp3'));
        expect(voices, isNot(contains('voice_first_comeback.mp3')));
        final before = voices.length;
        await openChest(tester);
        await tester.pump(const Duration(seconds: 3));
        final afterOpen = voices.sublist(before);
        expect(afterOpen.first, startsWith('voice_chest_')); // the chest line
        expect(afterOpen.skip(1), contains('voice_first_comeback.mp3'));
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('has_seen_first_comeback'), isTrue);
        await drain(tester);
      });

      testWidgets('after the first time: the short comeback line', (
        tester,
      ) async {
        seedPrefs(
          streak: 9,
          lastBrushDaysAgo: 5,
          extra: {'has_seen_first_comeback': true},
        );
        await pumpVictory(tester);
        await pumpToChest(tester);
        expect(bonusStars, findsNothing);
        final voices = fakeAudio.playedVoiceLines;
        final before = voices.length;
        await openChest(tester);
        await tester.pump(const Duration(seconds: 3));
        final afterOpen = voices.sublist(before);
        expect(afterOpen, contains('voice_chest_comeback.mp3'));
        expect(afterOpen, isNot(contains('voice_first_comeback.mp3')));
        await drain(tester);
      });

      testWidgets('an ordinary day has no comeback line', (tester) async {
        seedPrefs(streak: 2);
        await pumpVictory(tester);
        await pumpToChest(tester);
        await openChest(tester);
        await tester.pump(const Duration(seconds: 3));
        final voices = fakeAudio.playedVoiceLines;
        expect(voices, isNot(contains('voice_first_comeback.mp3')));
        expect(voices, isNot(contains('voice_chest_comeback.mp3')));
        await drain(tester);
      });
    });

    testWidgets('leaving during the flame beat is safe', (tester) async {
      seedPrefs(streak: 2);
      await pumpVictory(tester);
      await tester.pump(const Duration(milliseconds: 2000)); // mid flame beat
      expect(find.byType(FlameIcon), findsOneWidget);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump(const Duration(seconds: 5)); // the beat's pause ends
      expect(tester.takeException(), isNull);
    });

    group('the beat follows the voice (capped)', () {
      /// Built inside the test body: its Completer must live in the
      /// fake-async zone, or completing it would never be flushed by pump.
      _HeldArcAudio useHeldAudio() {
        final held = _HeldArcAudio();
        AudioService.testInstance = held;
        return held;
      }

      testWidgets('waits for arc beat 2 to end, then flame, line, chest', (
        tester,
      ) async {
        final held = useHeldAudio();
        seedPrefs(streak: 2); // streak 3: the flame line is the tier-up one
        await pumpVictory(tester);
        await tester.pump(const Duration(milliseconds: 1400));
        // Arc beat 2 starts at 1.5 s, as before.
        expect(held.playedVoiceLines.where(_isArcBeat2), isEmpty);
        await tester.pump(const Duration(milliseconds: 600)); // 2.0 s
        expect(held.playedVoiceLines.where(_isArcBeat2), hasLength(1));
        // It is still playing: no flame yet, no flame line asked for.
        expect(find.byType(FlameIcon), findsNothing);
        expect(
          held.playedVoiceLines,
          isNot(contains('voice_flame_tier_3.mp3')),
        );
        held.arcBeat2.complete();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(FlameIcon), findsOneWidget);
        expect(held.playedVoiceLines, contains('voice_flame_tier_3.mp3'));
        // The chest still follows 1.6 s after the beat starts.
        await tester.pump(const Duration(milliseconds: 1400));
        expect(chestKey, findsNothing);
        await tester.pump(const Duration(milliseconds: 400));
        expect(chestKey, findsOneWidget);
        await drain(tester);
      });

      testWidgets(
        'a beat 2 that never ends cannot hold the beat past the cap',
        (tester) async {
          final held = useHeldAudio();
          seedPrefs(streak: 2);
          await pumpVictory(tester);
          // The cap is 2.5 s after beat 2 was asked for (1.5 s): 4.0 s.
          await tester.pump(const Duration(milliseconds: 3900));
          expect(find.byType(FlameIcon), findsNothing);
          expect(
            held.playedVoiceLines,
            isNot(contains('voice_flame_tier_3.mp3')),
          );
          await tester.pump(const Duration(milliseconds: 200));
          expect(find.byType(FlameIcon), findsOneWidget);
          expect(held.playedVoiceLines, contains('voice_flame_tier_3.mp3'));
          await tester.pump(const Duration(milliseconds: 1300));
          expect(chestKey, findsNothing);
          await tester.pump(const Duration(milliseconds: 500));
          expect(chestKey, findsOneWidget);
          await drain(tester);
        },
      );

      testWidgets('muted: the voice never plays, the beat starts at once', (
        tester,
      ) async {
        final held = useHeldAudio();
        await held.toggleMute();
        seedPrefs(streak: 2);
        await pumpVictory(tester);
        await tester.pump(const Duration(milliseconds: 1600));
        expect(find.byType(FlameIcon), findsOneWidget);
        expect(held.playedVoiceLines, isEmpty);
        await drain(tester);
      });

      testWidgets('leaving while the beat waits for the voice is safe', (
        tester,
      ) async {
        final held = useHeldAudio();
        seedPrefs(streak: 2);
        await pumpVictory(tester);
        await tester.pump(const Duration(milliseconds: 2000));
        expect(find.byType(FlameIcon), findsNothing);
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        held.arcBeat2.complete();
        await tester.pump(const Duration(seconds: 5));
        expect(tester.takeException(), isNull);
      });
    });

    group('the beat animates', () {
      testWidgets('the flame grows in', (tester) async {
        seedPrefs(streak: 2); // the big flame, 30 px
        await pumpVictory(tester);
        await tester.pump(const Duration(milliseconds: 1500)); // beat is built
        final start = tester.getRect(find.byType(FlameIcon)).width;
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 800));
        final end = tester.getRect(find.byType(FlameIcon)).width;
        expect(end, closeTo(FlameIcon.sizeFor(FlameTier.big), 0.01));
        expect(start, lessThan(end * 0.7));
        await drain(tester);
      });

      testWidgets('the stars slide out of the flame and end clear of it', (
        tester,
      ) async {
        seedPrefs(streak: 6); // the hot flame pays 2 stars
        await pumpVictory(tester);
        await tester.pump(const Duration(milliseconds: 1500)); // beat is built
        await tester.pump(const Duration(milliseconds: 16)); // animations start
        await tester.pump(const Duration(milliseconds: 300)); // half way
        expect(bonusStars, findsNWidgets(2));
        expect(starsOverFlame(tester), greaterThan(1)); // still over the flame
        await tester.pump(const Duration(milliseconds: 700)); // slide done
        expect(starsOverFlame(tester), lessThan(0.5)); // clear of it
        await drain(tester);
      });

      testWidgets('the hero and the title do not jump when the beat appears', (
        tester,
      ) async {
        seedPrefs(streak: 2);
        await pumpVictory(tester);
        await tester.pump(const Duration(milliseconds: 1000)); // data loaded
        expect(find.byType(FlameIcon), findsNothing);
        final title = tester.getRect(find.text('GREAT JOB!'));
        await tester.pump(const Duration(milliseconds: 1000)); // beat is shown
        expect(find.byType(FlameIcon), findsOneWidget);
        expect(chestKey, findsNothing); // the chest's own jump comes later
        final after = tester.getRect(find.text('GREAT JOB!'));
        expect(after.top, closeTo(title.top, 0.01));
        expect(after.left, closeTo(title.left, 0.01));
        await drain(tester);
      });
    });

    group('chest look follows the streak', () {
      void expectChest(
        WidgetTester tester,
        _Look look, {
        required bool opened,
      }) {
        expect(chestRoot(opened: opened), findsOneWidget);
        expect(gradientBox([look.top, look.bottom], look.edge), findsOneWidget);
        expect(bandBox(look.band), findsNWidgets(2));
        final wooden = look == _wooden;
        // The lid, lock and band edge are the original chest's own only when
        // wooden.
        final original = wooden ? findsOneWidget : findsNothing;
        expect(gradientBox(_woodenLid, _woodenLidEdge), original);
        expect(
          bandBox(_wooden.band, edge: _woodenLockEdge),
          wooden ? findsNWidgets(2) : findsNothing,
        );
        if (!opened) {
          expect(gradientBox(_woodenLock, _woodenLockEdge), original);
          final lockIcon = tester.widget<Icon>(find.byIcon(Icons.lock));
          expect(lockIcon.color == _woodenLockIcon, wooden);
        }
        // No half-recoloured silver or gold chest.
        if (!wooden) expect(woodenRemnants(opened: opened), findsNothing);
      }

      Future<void> expectTier(
        WidgetTester tester, {
        required int streakBefore,
        required _Look look,
      }) async {
        seedPrefs(streak: streakBefore);
        await pumpVictory(tester);
        await pumpToChest(tester);
        expectChest(tester, look, opened: false);
        // The opened chest keeps the same look.
        await openChest(tester);
        expectChest(tester, look, opened: true);
        await drain(tester);
      }

      testWidgets('2 days: wooden, exactly as before', (tester) async {
        await expectTier(tester, streakBefore: 1, look: _wooden);
      });
      testWidgets('3 days: silver', (tester) async {
        await expectTier(tester, streakBefore: 2, look: _silver);
      });
      testWidgets('7 days: gold', (tester) async {
        await expectTier(tester, streakBefore: 6, look: _gold);
      });
    });
  });
}
