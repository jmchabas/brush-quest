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

    test('first_brush unlocks at 1 brush', () async {
      final result = await service.checkAndUnlock(
        streak: 0,
        totalStars: 1,
        totalBrushes: 1,
      );
      final ids = result.map((a) => a.id).toList();
      expect(ids, contains('first_brush'));
    });

    test('first_brush does not unlock at 0 brushes', () async {
      final result = await service.checkAndUnlock(
        streak: 0,
        totalStars: 0,
        totalBrushes: 0,
      );
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

    test('streak_14 unlocks at streak 14', () async {
      final result = await service.checkAndUnlock(streak: 14, totalStars: 14);
      final ids = result.map((a) => a.id).toList();
      expect(ids, contains('streak_14'));
    });

    test('streak_14 does not unlock at streak 13', () async {
      final result = await service.checkAndUnlock(streak: 13, totalStars: 13);
      final ids = result.map((a) => a.id).toList();
      expect(ids, isNot(contains('streak_14')));
    });

    test('streak_30 unlocks at streak 30', () async {
      final result = await service.checkAndUnlock(streak: 30, totalStars: 30);
      final ids = result.map((a) => a.id).toList();
      expect(ids, contains('streak_30'));
    });

    // ── brush milestones ──

    test('brushes_10 unlocks at 10 brushes', () async {
      final result = await service.checkAndUnlock(
        streak: 0,
        totalStars: 0,
        totalBrushes: 10,
      );
      final ids = result.map((a) => a.id).toList();
      expect(ids, contains('brushes_10'));
    });

    test('brushes_10 does not unlock at 9 brushes', () async {
      final result = await service.checkAndUnlock(
        streak: 0,
        totalStars: 0,
        totalBrushes: 9,
      );
      final ids = result.map((a) => a.id).toList();
      expect(ids, isNot(contains('brushes_10')));
    });

    test('brushes_25 unlocks at 25 brushes', () async {
      final result = await service.checkAndUnlock(
        streak: 0,
        totalStars: 0,
        totalBrushes: 25,
      );
      final ids = result.map((a) => a.id).toList();
      expect(ids, contains('brushes_25'));
    });

    test('brushes_50 unlocks at 50 brushes', () async {
      final result = await service.checkAndUnlock(
        streak: 0,
        totalStars: 0,
        totalBrushes: 50,
      );
      final ids = result.map((a) => a.id).toList();
      expect(ids, contains('brushes_50'));
    });

    test('brushes_100 unlocks at 100 brushes', () async {
      final result = await service.checkAndUnlock(
        streak: 0,
        totalStars: 0,
        totalBrushes: 100,
      );
      final ids = result.map((a) => a.id).toList();
      expect(ids, contains('brushes_100'));
    });

    test('brushes_100 does not unlock at 99 brushes', () async {
      final result = await service.checkAndUnlock(
        streak: 0,
        totalStars: 0,
        totalBrushes: 99,
      );
      final ids = result.map((a) => a.id).toList();
      expect(ids, isNot(contains('brushes_100')));
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

    // ── Bonus stars ──

    test('streak_3 gives 1 bonus star', () async {
      final result = await service.checkAndUnlock(streak: 3, totalStars: 3);
      final streak3 = result.firstWhere((a) => a.id == 'streak_3');
      expect(streak3.bonusStars, 1);
    });

    test('streak_7 gives 2 bonus stars', () async {
      final result = await service.checkAndUnlock(streak: 7, totalStars: 7);
      final streak7 = result.firstWhere((a) => a.id == 'streak_7');
      expect(streak7.bonusStars, 2);
    });

    test('brushes_100 gives 5 bonus stars', () async {
      final result = await service.checkAndUnlock(
        streak: 0,
        totalStars: 0,
        totalBrushes: 100,
      );
      final b100 = result.firstWhere((a) => a.id == 'brushes_100');
      expect(b100.bonusStars, 5);
    });

    test('first_brush gives 0 bonus stars', () async {
      final result = await service.checkAndUnlock(
        streak: 0,
        totalStars: 1,
        totalBrushes: 1,
      );
      final first = result.firstWhere((a) => a.id == 'first_brush');
      expect(first.bonusStars, 0);
    });

    test('star milestones give 0 bonus stars', () async {
      final result = await service.checkAndUnlock(streak: 0, totalStars: 100);
      final starAchievements = result.where((a) => a.id.startsWith('stars_'));
      for (final a in starAchievements) {
        expect(a.bonusStars, 0);
      }
    });

    // ── Multiple achievements in one call ──

    test(
      'multiple achievements unlock together when conditions are met',
      () async {
        final result = await service.checkAndUnlock(
          streak: 7,
          totalStars: 25,
          totalBrushes: 25,
        );
        final ids = result.map((a) => a.id).toSet();
        expect(
          ids,
          containsAll([
            'first_brush',
            'streak_3',
            'streak_7',
            'stars_10',
            'stars_25',
          ]),
        );
      },
    );

    test('all 13 achievements unlock together at max stats', () async {
      final result = await service.checkAndUnlock(
        streak: 30,
        totalStars: 100,
        totalBrushes: 100,
      );
      expect(result.length, 13);
    });

    // ── Already-unlocked achievements don't re-trigger ──

    test('already unlocked achievements are not returned again', () async {
      final first = await service.checkAndUnlock(
        streak: 0,
        totalStars: 1,
        totalBrushes: 1,
      );
      expect(first.map((a) => a.id), contains('first_brush'));

      final second = await service.checkAndUnlock(
        streak: 0,
        totalStars: 1,
        totalBrushes: 1,
      );
      expect(second, isEmpty);
    });

    test(
      'only newly earned achievements are returned on progressive unlock',
      () async {
        await service.checkAndUnlock(streak: 0, totalStars: 1, totalBrushes: 1);

        final result = await service.checkAndUnlock(
          streak: 3,
          totalStars: 3,
          totalBrushes: 3,
        );
        final ids = result.map((a) => a.id).toList();
        expect(ids, contains('streak_3'));
        expect(ids, isNot(contains('first_brush')));
      },
    );

    test('pre-saved achievement in prefs is not re-triggered', () async {
      SharedPreferences.setMockInitialValues({'achievement_first_brush': true});
      final svc = AchievementService();
      final result = await svc.checkAndUnlock(
        streak: 0,
        totalStars: 5,
        totalBrushes: 5,
      );
      final ids = result.map((a) => a.id).toList();
      expect(ids, isNot(contains('first_brush')));
    });

    // ── Achievement data integrity ──

    test(
      'every achievement has a non-empty id, title, description, and emoji',
      () async {
        final result = await service.checkAndUnlock(
          streak: 30,
          totalStars: 100,
          totalBrushes: 100,
        );
        expect(result.length, 13);
        for (final achievement in result) {
          expect(achievement.id, isNotEmpty);
          expect(achievement.title, isNotEmpty);
          expect(achievement.description, isNotEmpty);
          expect(achievement.emoji, isNotEmpty);
        }
      },
    );

    test('all achievement ids are unique', () async {
      final result = await service.checkAndUnlock(
        streak: 30,
        totalStars: 100,
        totalBrushes: 100,
      );
      final ids = result.map((a) => a.id).toSet();
      expect(ids.length, result.length);
    });

    // ── Persists to SharedPreferences ──

    test('unlocked achievements are persisted in SharedPreferences', () async {
      await service.checkAndUnlock(streak: 0, totalStars: 1, totalBrushes: 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('achievement_first_brush'), true);
    });

    test('non-unlocked achievements are not persisted', () async {
      await service.checkAndUnlock(streak: 0, totalStars: 1, totalBrushes: 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('achievement_streak_3'), isNull);
    });

    // ── totalBrushes defaults to 0 (backwards compatible) ──

    test(
      'totalBrushes defaults to 0 so brush milestones do not unlock without it',
      () async {
        final result = await service.checkAndUnlock(streak: 0, totalStars: 0);
        final ids = result.map((a) => a.id).toSet();
        expect(ids, isNot(contains('brushes_10')));
      },
    );
  });
}
