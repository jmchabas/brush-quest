import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:brush_quest/services/achievement_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AchievementService', () {
    late AchievementService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = AchievementService();
    });

    // ── No achievements initially ──

    test('no achievements unlocked with zero stats', () async {
      final result = await service.checkAndUnlock(streak: 0, totalStars: 0);
      expect(result, isEmpty);
    });

    // ── first_brush milestone ──

    test('first_brush unlocks at 1 star', () async {
      final result = await service.checkAndUnlock(streak: 0, totalStars: 1);
      final ids = result.map((a) => a.id).toList();
      expect(ids, contains('first_brush'));
    });

    test('first_brush does not unlock at 0 stars', () async {
      final result = await service.checkAndUnlock(streak: 0, totalStars: 0);
      final ids = result.map((a) => a.id).toList();
      expect(ids, isNot(contains('first_brush')));
    });

    // ── streak milestones ──

    test('streak_3 unlocks at streak 3', () async {
      final result = await service.checkAndUnlock(streak: 3, totalStars: 3);
      final ids = result.map((a) => a.id).toList();
      expect(ids, contains('streak_3'));
    });

    test('streak_3 does not unlock at streak 2', () async {
      final result = await service.checkAndUnlock(streak: 2, totalStars: 2);
      final ids = result.map((a) => a.id).toList();
      expect(ids, isNot(contains('streak_3')));
    });

    test('streak_7 unlocks at streak 7', () async {
      final result = await service.checkAndUnlock(streak: 7, totalStars: 7);
      final ids = result.map((a) => a.id).toList();
      expect(ids, contains('streak_7'));
    });

    test('streak_7 does not unlock at streak 6', () async {
      final result = await service.checkAndUnlock(streak: 6, totalStars: 6);
      final ids = result.map((a) => a.id).toList();
      expect(ids, isNot(contains('streak_7')));
    });

    // ── star milestones ──

    test('stars_10 unlocks at 10 stars', () async {
      final result = await service.checkAndUnlock(streak: 0, totalStars: 10);
      final ids = result.map((a) => a.id).toList();
      expect(ids, contains('stars_10'));
    });

    test('stars_10 does not unlock at 9 stars', () async {
      final result = await service.checkAndUnlock(streak: 0, totalStars: 9);
      final ids = result.map((a) => a.id).toList();
      expect(ids, isNot(contains('stars_10')));
    });

    test('stars_25 unlocks at 25 stars', () async {
      final result = await service.checkAndUnlock(streak: 0, totalStars: 25);
      final ids = result.map((a) => a.id).toList();
      expect(ids, contains('stars_25'));
    });

    test('stars_50 unlocks at 50 stars', () async {
      final result = await service.checkAndUnlock(streak: 0, totalStars: 50);
      final ids = result.map((a) => a.id).toList();
      expect(ids, contains('stars_50'));
    });

    test('stars_100 unlocks at 100 stars', () async {
      final result = await service.checkAndUnlock(streak: 0, totalStars: 100);
      final ids = result.map((a) => a.id).toList();
      expect(ids, contains('stars_100'));
    });

    test('stars_100 does not unlock at 99 stars', () async {
      final result = await service.checkAndUnlock(streak: 0, totalStars: 99);
      final ids = result.map((a) => a.id).toList();
      expect(ids, isNot(contains('stars_100')));
    });

    // ── Multiple achievements in one call ──

    test('multiple achievements unlock together when conditions are met', () async {
      final result = await service.checkAndUnlock(streak: 7, totalStars: 25);
      final ids = result.map((a) => a.id).toSet();
      // Should unlock: first_brush, streak_3, streak_7, stars_10, stars_25
      expect(ids, containsAll(['first_brush', 'streak_3', 'streak_7', 'stars_10', 'stars_25']));
      expect(ids.length, 5);
    });

    test('all 7 achievements unlock together at max stats', () async {
      final result = await service.checkAndUnlock(streak: 7, totalStars: 100);
      expect(result.length, 7);
    });

    // ── Already-unlocked achievements don't re-trigger ──

    test('already unlocked achievements are not returned again', () async {
      // First call unlocks first_brush
      final first = await service.checkAndUnlock(streak: 0, totalStars: 1);
      expect(first.map((a) => a.id), contains('first_brush'));

      // Second call with same stats should return nothing new
      final second = await service.checkAndUnlock(streak: 0, totalStars: 1);
      expect(second, isEmpty);
    });

    test('only newly earned achievements are returned on progressive unlock', () async {
      // First call: get first_brush
      await service.checkAndUnlock(streak: 0, totalStars: 1);

      // Second call at streak 3: should get streak_3 but NOT first_brush again
      final result = await service.checkAndUnlock(streak: 3, totalStars: 3);
      final ids = result.map((a) => a.id).toList();
      expect(ids, contains('streak_3'));
      expect(ids, isNot(contains('first_brush')));
    });

    test('pre-saved achievement in prefs is not re-triggered', () async {
      // Simulate a previously unlocked achievement
      SharedPreferences.setMockInitialValues({
        'achievement_first_brush': true,
      });
      final svc = AchievementService();
      final result = await svc.checkAndUnlock(streak: 0, totalStars: 5);
      final ids = result.map((a) => a.id).toList();
      expect(ids, isNot(contains('first_brush')));
    });

    // ── Achievement data integrity ──

    test('every achievement has a non-empty id, title, description, and emoji', () async {
      // Access milestones through a high-stats call that returns them all
      final result = await service.checkAndUnlock(streak: 7, totalStars: 100);
      expect(result.length, 7);
      for (final achievement in result) {
        expect(achievement.id, isNotEmpty);
        expect(achievement.title, isNotEmpty);
        expect(achievement.description, isNotEmpty);
        expect(achievement.emoji, isNotEmpty);
      }
    });

    test('all achievement ids are unique', () async {
      final result = await service.checkAndUnlock(streak: 7, totalStars: 100);
      final ids = result.map((a) => a.id).toSet();
      expect(ids.length, result.length);
    });

    // ── Persists to SharedPreferences ──

    test('unlocked achievements are persisted in SharedPreferences', () async {
      await service.checkAndUnlock(streak: 0, totalStars: 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('achievement_first_brush'), true);
    });

    test('non-unlocked achievements are not persisted', () async {
      await service.checkAndUnlock(streak: 0, totalStars: 1);
      final prefs = await SharedPreferences.getInstance();
      // streak_3 should NOT be in prefs since streak is 0
      expect(prefs.getBool('achievement_streak_3'), isNull);
    });
  });
}
