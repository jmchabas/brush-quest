// test/audio/brush_flow_timeline_test.dart
//
// The app has one voice channel with a queue (real and fake), so two voices
// can't overlap by construction. What can go wrong is the order, stale lines
// and duplicates: these tests pin the victory screen's voice order for the
// v1.1 brush flow (spec 2026-10-05 §6, §7.3). The pre-brush order is pinned
// exactly by the first pre-brush screen test; the Home welcome and tier-up
// lines by the Home flame tests.
import 'package:brush_quest/screens/victory_screen.dart';
import 'package:brush_quest/services/audio_service.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// Runs a victory from its first frame through the whole chest sequence,
  /// then drops the screen once the achievement popups' timers have expired.
  Future<List<String>> runVictory(
    WidgetTester tester,
    Map<String, Object> prefs,
  ) async {
    SharedPreferences.setMockInitialValues(prefs);
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: VictoryScreen(totalHits: 10, monstersDefeated: 4),
      ),
    );
    await tester.pump();
    // The flame beat, then the chest. A single long pump renders one frame
    // at its end, so a second one lets the chest's scale-in run before the
    // tap (as the victory screen tests do).
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('victory_chest')));
    await tester.pump(const Duration(seconds: 20));
    final spoken = List<String>.of(fakeAudio.playedVoiceLines);
    await tester.pump(const Duration(seconds: 70));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    return spoken;
  }

  /// A child on a 3-day streak who brushed yesterday: this brush makes day
  /// 4, so the big flame pays one bonus star (spec §7.1).
  Map<String, Object> dayFour() => {
    'total_stars': 5,
    'star_wallet': 0,
    'current_streak': 3,
    'best_streak': 3,
    'last_brush_date': day(-1),
    'total_brushes': 9,
    'selected_hero': 'blaze',
    'selected_weapon': 'star_blaster',
    'unlocked_heroes': ['blaze'],
    'unlocked_weapons': ['star_blaster'],
    'current_world': 'candy_crater',
    'collected_cards': <String>[],
    'muted': false,
  };

  testWidgets('victory voice order: flame, chest, goal, closing', (
    tester,
  ) async {
    final v = await runVictory(tester, dayFour());
    final flame = v.indexWhere((x) => x.startsWith('voice_flame_bonus_'));
    final chest = v.indexWhere((x) => x.startsWith('voice_chest_'));
    final goal = v.indexWhere(
      (x) =>
          x.startsWith('voice_stars_left_') || x == 'voice_tap_to_unlock.mp3',
    );
    final closing = v.lastIndexWhere(
      (x) =>
          x.startsWith('voice_flame_see_you_') ||
          x == 'voice_forward_tonight.mp3',
    );
    expect(flame, isNonNegative, reason: '$v');
    expect(chest, greaterThan(flame), reason: '$v');
    expect(goal, greaterThan(chest), reason: '$v');
    expect(closing, greaterThan(goal), reason: '$v');
    expect(v.where((x) => x == v[closing]), hasLength(1), reason: '$v');
  });

  testWidgets('exactly two flame lines per victory, none of them repeated', (
    tester,
  ) async {
    final v = await runVictory(tester, dayFour());
    // Spec §7.3: the beat's line and the closing line. "Tonight" stands in
    // for the closing flame line for a twice-a-day child in the morning.
    final flameLines = v
        .where(
          (x) =>
              x.startsWith('voice_flame_') || x == 'voice_forward_tonight.mp3',
        )
        .toList();
    expect(flameLines, hasLength(2), reason: '$v');
    expect(flameLines.toSet(), hasLength(2), reason: '$v');
  });

  testWidgets('the replaced streak lines never play', (tester) async {
    final v = await runVictory(tester, dayFour());
    // Spec §7.3: the flame lines replace these.
    for (final old in [
      'voice_first_streak_3.mp3',
      'voice_first_streak_7.mp3',
      'voice_chest_streak_bonus.mp3',
      'voice_chest_mega_streak.mp3',
      'voice_full_power.mp3',
      'voice_forward_morning.mp3',
    ]) {
      expect(v, isNot(contains(old)), reason: '$v');
    }
  });
}
