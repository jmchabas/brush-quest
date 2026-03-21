import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:brush_quest/services/greeting_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GreetingService', () {
    late GreetingService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = GreetingService();
    });

    // ── Returns null when no brushes ──

    test('returns null when totalBrushes is 0', () {
      final result = service.checkGreeting(
        totalBrushes: 0,
        brushStreak: 0,
        totalStars: 0,
        nextHeroName: null,
        nextHeroUnlockAt: null,
        nextWeaponName: null,
        nextWeaponUnlockAt: null,
        todayDate: '2026-03-16',
        lastGreetingDate: null,
      );
      expect(result, isNull);
    });

    // ── Returns null when already greeted today ──

    test('returns null when already greeted today', () {
      final result = service.checkGreeting(
        totalBrushes: 5,
        brushStreak: 3,
        totalStars: 5,
        nextHeroName: null,
        nextHeroUnlockAt: null,
        nextWeaponName: null,
        nextWeaponUnlockAt: null,
        todayDate: '2026-03-16',
        lastGreetingDate: '2026-03-16',
      );
      expect(result, isNull);
    });

    // ── justStarted state ──

    test('justStarted state for user with 1 brush and no streak', () {
      final result = service.checkGreeting(
        totalBrushes: 1,
        brushStreak: 0,
        totalStars: 1,
        nextHeroName: null,
        nextHeroUnlockAt: null,
        nextWeaponName: null,
        nextWeaponUnlockAt: null,
        todayDate: '2026-03-16',
        lastGreetingDate: null,
      );
      expect(result, isNotNull);
      expect(result!.state, GreetingState.justStarted);
      expect(result.voiceFile, startsWith('voice_greet_just_started_'));
    });

    test('justStarted state for user with 2 brushes and streak 1', () {
      final result = service.checkGreeting(
        totalBrushes: 2,
        brushStreak: 1,
        totalStars: 2,
        nextHeroName: null,
        nextHeroUnlockAt: null,
        nextWeaponName: null,
        nextWeaponUnlockAt: null,
        todayDate: '2026-03-16',
        lastGreetingDate: null,
      );
      expect(result, isNotNull);
      expect(result!.state, GreetingState.justStarted);
    });

    // ── returning state ──

    test('returning state for user with broken streak and >2 brushes', () {
      final result = service.checkGreeting(
        totalBrushes: 10,
        brushStreak: 0,
        totalStars: 10,
        nextHeroName: null,
        nextHeroUnlockAt: null,
        nextWeaponName: null,
        nextWeaponUnlockAt: null,
        todayDate: '2026-03-16',
        lastGreetingDate: null,
      );
      expect(result, isNotNull);
      expect(result!.state, GreetingState.returning);
      expect(result.voiceFile, startsWith('voice_greet_returning_'));
    });

    // ── streak states ──

    test('streak2to4 state at streak 2', () {
      final result = service.checkGreeting(
        totalBrushes: 5,
        brushStreak: 2,
        totalStars: 5,
        nextHeroName: null,
        nextHeroUnlockAt: null,
        nextWeaponName: null,
        nextWeaponUnlockAt: null,
        todayDate: '2026-03-16',
        lastGreetingDate: null,
      );
      expect(result!.state, GreetingState.streak2to4);
    });

    test('streak2to4 state at upper boundary streak 4', () {
      final result = service.checkGreeting(
        totalBrushes: 10,
        brushStreak: 4,
        totalStars: 10,
        nextHeroName: null,
        nextHeroUnlockAt: null,
        nextWeaponName: null,
        nextWeaponUnlockAt: null,
        todayDate: '2026-03-16',
        lastGreetingDate: null,
      );
      expect(result!.state, GreetingState.streak2to4);
    });

    test('streak5to9 state at streak 5', () {
      final result = service.checkGreeting(
        totalBrushes: 10,
        brushStreak: 5,
        totalStars: 10,
        nextHeroName: null,
        nextHeroUnlockAt: null,
        nextWeaponName: null,
        nextWeaponUnlockAt: null,
        todayDate: '2026-03-16',
        lastGreetingDate: null,
      );
      expect(result!.state, GreetingState.streak5to9);
    });

    test('streak5to9 state at upper boundary streak 9', () {
      final result = service.checkGreeting(
        totalBrushes: 20,
        brushStreak: 9,
        totalStars: 20,
        nextHeroName: null,
        nextHeroUnlockAt: null,
        nextWeaponName: null,
        nextWeaponUnlockAt: null,
        todayDate: '2026-03-16',
        lastGreetingDate: null,
      );
      expect(result!.state, GreetingState.streak5to9);
    });

    test('streak10to19 state at streak 10', () {
      final result = service.checkGreeting(
        totalBrushes: 20,
        brushStreak: 10,
        totalStars: 20,
        nextHeroName: null,
        nextHeroUnlockAt: null,
        nextWeaponName: null,
        nextWeaponUnlockAt: null,
        todayDate: '2026-03-16',
        lastGreetingDate: null,
      );
      expect(result!.state, GreetingState.streak10to19);
    });

    test('streak10to19 state at upper boundary streak 19', () {
      final result = service.checkGreeting(
        totalBrushes: 40,
        brushStreak: 19,
        totalStars: 40,
        nextHeroName: null,
        nextHeroUnlockAt: null,
        nextWeaponName: null,
        nextWeaponUnlockAt: null,
        todayDate: '2026-03-16',
        lastGreetingDate: null,
      );
      expect(result!.state, GreetingState.streak10to19);
    });

    test('streak20plus state at streak 20', () {
      final result = service.checkGreeting(
        totalBrushes: 40,
        brushStreak: 20,
        totalStars: 40,
        nextHeroName: null,
        nextHeroUnlockAt: null,
        nextWeaponName: null,
        nextWeaponUnlockAt: null,
        todayDate: '2026-03-16',
        lastGreetingDate: null,
      );
      expect(result!.state, GreetingState.streak20plus);
    });

    test('streak20plus state at high streak 100', () {
      final result = service.checkGreeting(
        totalBrushes: 200,
        brushStreak: 100,
        totalStars: 200,
        nextHeroName: null,
        nextHeroUnlockAt: null,
        nextWeaponName: null,
        nextWeaponUnlockAt: null,
        todayDate: '2026-03-16',
        lastGreetingDate: null,
      );
      expect(result!.state, GreetingState.streak20plus);
    });

    test('returning state when streak is 1 and totalBrushes > 2', () {
      final result = service.checkGreeting(
        totalBrushes: 5,
        brushStreak: 1,
        totalStars: 5,
        nextHeroName: null,
        nextHeroUnlockAt: null,
        nextWeaponName: null,
        nextWeaponUnlockAt: null,
        todayDate: '2026-03-16',
        lastGreetingDate: null,
      );
      expect(result!.state, GreetingState.returning);
    });

    // ── Voice pool selection per state ──

    test('voice file comes from streak2to4 pool', () {
      final result = service.checkGreeting(
        totalBrushes: 5,
        brushStreak: 3,
        totalStars: 5,
        nextHeroName: null,
        nextHeroUnlockAt: null,
        nextWeaponName: null,
        nextWeaponUnlockAt: null,
        todayDate: '2026-03-16',
        lastGreetingDate: null,
      );
      expect(result!.voiceFile, startsWith('voice_greet_streak_low_'));
    });

    test('voice file comes from streak5to9 pool', () {
      final result = service.checkGreeting(
        totalBrushes: 15,
        brushStreak: 7,
        totalStars: 15,
        nextHeroName: null,
        nextHeroUnlockAt: null,
        nextWeaponName: null,
        nextWeaponUnlockAt: null,
        todayDate: '2026-03-16',
        lastGreetingDate: null,
      );
      expect(result!.voiceFile, startsWith('voice_greet_streak_mid_'));
    });

    test('voice file comes from streak10to19 pool', () {
      final result = service.checkGreeting(
        totalBrushes: 30,
        brushStreak: 15,
        totalStars: 30,
        nextHeroName: null,
        nextHeroUnlockAt: null,
        nextWeaponName: null,
        nextWeaponUnlockAt: null,
        todayDate: '2026-03-16',
        lastGreetingDate: null,
      );
      expect(result!.voiceFile, startsWith('voice_greet_streak_high_'));
    });

    test('voice file comes from streak20plus pool', () {
      final result = service.checkGreeting(
        totalBrushes: 50,
        brushStreak: 25,
        totalStars: 50,
        nextHeroName: null,
        nextHeroUnlockAt: null,
        nextWeaponName: null,
        nextWeaponUnlockAt: null,
        todayDate: '2026-03-16',
        lastGreetingDate: null,
      );
      expect(result!.voiceFile, startsWith('voice_greet_streak_legend_'));
    });

    test('voice selection is deterministic based on totalBrushes modulo pool size', () {
      // justStarted pool has 3 files, totalBrushes=1 => index 1%3=1
      final result1 = service.checkGreeting(
        totalBrushes: 1,
        brushStreak: 0,
        totalStars: 1,
        nextHeroName: null,
        nextHeroUnlockAt: null,
        nextWeaponName: null,
        nextWeaponUnlockAt: null,
        todayDate: '2026-03-16',
        lastGreetingDate: null,
      );
      expect(result1!.voiceFile, 'voice_greet_just_started_2.mp3');

      // totalBrushes=2 => index 2%3=2
      final result2 = service.checkGreeting(
        totalBrushes: 2,
        brushStreak: 1,
        totalStars: 2,
        nextHeroName: null,
        nextHeroUnlockAt: null,
        nextWeaponName: null,
        nextWeaponUnlockAt: null,
        todayDate: '2026-03-16',
        lastGreetingDate: null,
      );
      expect(result2!.voiceFile, 'voice_greet_just_started_3.mp3');
    });

    // ── Tease logic ──

    test('tease shows weapon when weapon is closer', () {
      final result = service.checkGreeting(
        totalBrushes: 5,
        brushStreak: 2,
        totalStars: 1,
        nextHeroName: 'FROST',
        nextHeroUnlockAt: 4,
        nextWeaponName: 'FLAME SWORD',
        nextWeaponUnlockAt: 2,
        todayDate: '2026-03-16',
        lastGreetingDate: null,
      );
      expect(result!.teaseItemName, 'FLAME SWORD');
      expect(result.teaseStarsAway, 1);
    });

    test('tease shows hero when hero is closer', () {
      final result = service.checkGreeting(
        totalBrushes: 5,
        brushStreak: 2,
        totalStars: 3,
        nextHeroName: 'FROST',
        nextHeroUnlockAt: 4,
        nextWeaponName: 'ICE HAMMER',
        nextWeaponUnlockAt: 5,
        todayDate: '2026-03-16',
        lastGreetingDate: null,
      );
      expect(result!.teaseItemName, 'FROST');
      expect(result.teaseStarsAway, 1);
    });

    test('no tease when all items unlocked', () {
      final result = service.checkGreeting(
        totalBrushes: 50,
        brushStreak: 10,
        totalStars: 50,
        nextHeroName: null,
        nextHeroUnlockAt: null,
        nextWeaponName: null,
        nextWeaponUnlockAt: null,
        todayDate: '2026-03-16',
        lastGreetingDate: null,
      );
      expect(result!.teaseItemName, isNull);
      expect(result.teaseStarsAway, isNull);
    });

    test('tease shows weapon when distances are equal', () {
      // When distances are equal, weapon wins (weaponDistance <= heroDistance)
      final result = service.checkGreeting(
        totalBrushes: 5,
        brushStreak: 2,
        totalStars: 9,
        nextHeroName: 'FROST',
        nextHeroUnlockAt: 14, // 5 away
        nextWeaponName: 'FLAME SWORD',
        nextWeaponUnlockAt: 14, // 5 away (same)
        todayDate: '2026-03-16',
        lastGreetingDate: null,
      );
      expect(result!.teaseItemName, 'FLAME SWORD');
      expect(result.teaseStarsAway, 5);
    });

    test('tease shows hero when only hero unlock remains', () {
      final result = service.checkGreeting(
        totalBrushes: 50,
        brushStreak: 25,
        totalStars: 90,
        nextHeroName: 'NOVA',
        nextHeroUnlockAt: 98, // 8 away
        nextWeaponName: null,
        nextWeaponUnlockAt: null,
        todayDate: '2026-03-16',
        lastGreetingDate: null,
      );
      expect(result!.teaseItemName, 'NOVA');
      expect(result.teaseStarsAway, 8);
    });

    test('tease shows weapon when only weapon unlock remains', () {
      final result = service.checkGreeting(
        totalBrushes: 50,
        brushStreak: 25,
        totalStars: 80,
        nextHeroName: null,
        nextHeroUnlockAt: null,
        nextWeaponName: 'COSMIC BURST',
        nextWeaponUnlockAt: 88, // 8 away
        todayDate: '2026-03-16',
        lastGreetingDate: null,
      );
      expect(result!.teaseItemName, 'COSMIC BURST');
      expect(result.teaseStarsAway, 8);
    });

    test('no tease when already have enough stars for next item', () {
      final result = service.checkGreeting(
        totalBrushes: 5,
        brushStreak: 2,
        totalStars: 10,
        nextHeroName: 'FROST',
        nextHeroUnlockAt: 4,
        nextWeaponName: 'FLAME SWORD',
        nextWeaponUnlockAt: 2,
        todayDate: '2026-03-16',
        lastGreetingDate: null,
      );
      // Both distances are <= 0, so no tease
      expect(result!.teaseItemName, isNull);
    });

    // ── No material reward ──

    test('greeting result contains no material reward fields', () {
      final result = service.checkGreeting(
        totalBrushes: 5,
        brushStreak: 3,
        totalStars: 5,
        nextHeroName: null,
        nextHeroUnlockAt: null,
        nextWeaponName: null,
        nextWeaponUnlockAt: null,
        todayDate: '2026-03-16',
        lastGreetingDate: null,
      );
      expect(result, isNotNull);
      // GreetingResult has no 'reward' or 'bonusStar' or 'amount' fields
      // Just verify the result is a greeting, not a reward
      expect(result!.brushStreak, 3);
    });

    // ── Result carries brushStreak ──

    test('result carries the correct brushStreak value', () {
      final result = service.checkGreeting(
        totalBrushes: 10,
        brushStreak: 7,
        totalStars: 10,
        nextHeroName: null,
        nextHeroUnlockAt: null,
        nextWeaponName: null,
        nextWeaponUnlockAt: null,
        todayDate: '2026-03-16',
        lastGreetingDate: null,
      );
      expect(result, isNotNull);
      expect(result!.brushStreak, 7);
    });

    // ── Persistence ──

    test('markGreetingShown persists date', () async {
      await service.markGreetingShown('2026-03-16');
      final date = await service.getLastGreetingDate();
      expect(date, '2026-03-16');
    });

    test('getLastGreetingDate returns null when never greeted', () async {
      final date = await service.getLastGreetingDate();
      expect(date, isNull);
    });
  });
}
