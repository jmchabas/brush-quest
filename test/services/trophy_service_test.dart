import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:brush_quest/services/trophy_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TrophyService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('has 5 monsters per world, 5 worlds = 25 total', () {
      expect(TrophyService.allTrophies.length, 25);
      expect(TrophyService.worldIds.length, 5);
      for (final worldId in TrophyService.worldIds) {
        final worldTrophies = TrophyService.trophiesForWorld(worldId);
        expect(worldTrophies.length, 5, reason: 'World $worldId should have 5 trophies');
      }
    });

    test('every trophy has a valid baseImageIndex (0-3)', () {
      for (final t in TrophyService.allTrophies) {
        expect(t.baseImageIndex, inInclusiveRange(0, 3), reason: '${t.id} baseImageIndex out of range');
      }
    });

    test('every trophy has defeatsRequired between 1 and 3', () {
      for (final t in TrophyService.allTrophies) {
        expect(t.defeatsRequired, inInclusiveRange(1, 3), reason: '${t.id} defeatsRequired out of range');
      }
    });

    test('each world has exactly one boss (defeatsRequired=3)', () {
      for (final worldId in TrophyService.worldIds) {
        final bosses = TrophyService.trophiesForWorld(worldId)
            .where((t) => t.defeatsRequired == 3).toList();
        expect(bosses.length, 1, reason: 'World $worldId should have exactly 1 boss');
      }
    });

    test('recordCapture marks monster as captured', () async {
      final service = TrophyService();
      await service.recordCapture('cc_t1');

      final captured = await service.getCapturedIds();
      expect(captured, contains('cc_t1'));
    });

    test('recordCapture is idempotent', () async {
      final service = TrophyService();
      await service.recordCapture('cc_t1');
      await service.recordCapture('cc_t1');

      final captured = await service.getCapturedIds();
      expect(captured.where((id) => id == 'cc_t1').length, 1);
    });

    test('isCaptured returns correct status', () async {
      final service = TrophyService();
      expect(await service.isCaptured('cc_t1'), false);
      await service.recordCapture('cc_t1');
      expect(await service.isCaptured('cc_t1'), true);
    });

    test('recordDefeat tracks defeats and auto-captures at threshold', () async {
      final service = TrophyService();
      // cc_t4 requires 2 defeats
      final result1 = await service.recordDefeat('cc_t4');
      expect(result1.captured, false);
      expect(result1.currentDefeats, 1);
      expect(result1.required, 2);

      final result2 = await service.recordDefeat('cc_t4');
      expect(result2.captured, true);
      expect(result2.currentDefeats, 2);
      expect(await service.isCaptured('cc_t4'), true);
    });

    test('recordDefeat auto-captures 1-defeat monsters immediately', () async {
      final service = TrophyService();
      final result = await service.recordDefeat('cc_t1'); // defeatsRequired=1
      expect(result.captured, true);
      expect(result.currentDefeats, 1);
    });

    test('recordDefeat on already-captured is a no-op', () async {
      final service = TrophyService();
      await service.recordCapture('cc_t1');

      final result = await service.recordDefeat('cc_t1');
      expect(result.captured, true);
      expect(result.currentDefeats, 1); // defeatsRequired, not incremented
    });

    test('getNextUncaptured returns first uncaptured in world order', () async {
      final service = TrophyService();
      final next = await service.getNextUncaptured('candy_crater');
      expect(next, isNotNull);
      expect(next!.id, 'cc_t1'); // First in order

      await service.recordCapture('cc_t1');
      final next2 = await service.getNextUncaptured('candy_crater');
      expect(next2!.id, 'cc_t2');
    });

    test('getNextUncaptured returns null when all captured', () async {
      final service = TrophyService();
      for (final t in TrophyService.trophiesForWorld('candy_crater')) {
        await service.recordCapture(t.id);
      }
      expect(await service.getNextUncaptured('candy_crater'), isNull);
    });

    test('getWallProgress returns correct counts', () async {
      final service = TrophyService();
      await service.recordCapture('cc_t1');
      await service.recordCapture('cc_t3');

      final progress = await service.getWallProgress('candy_crater');
      expect(progress.captured, 2);
      expect(progress.total, 5);
    });

    test('isWorldComplete returns true when all 5 captured', () async {
      final service = TrophyService();
      expect(await service.isWorldComplete('candy_crater'), false);

      for (final t in TrophyService.trophiesForWorld('candy_crater')) {
        await service.recordCapture(t.id);
      }
      expect(await service.isWorldComplete('candy_crater'), true);
    });

    test('getTotalCaptured returns count across all worlds', () async {
      final service = TrophyService();
      await service.recordCapture('cc_t1');
      await service.recordCapture('ss_t1');
      await service.recordCapture('sv_t1');

      expect(await service.getTotalCaptured(), 3);
    });

    test('getDefeatCount returns defeat count', () async {
      final service = TrophyService();
      expect(await service.getDefeatCount('cc_t5'), 0);

      await service.recordDefeat('cc_t5'); // Boss, needs 3
      expect(await service.getDefeatCount('cc_t5'), 1);

      await service.recordDefeat('cc_t5');
      expect(await service.getDefeatCount('cc_t5'), 2);
    });
  });
}
