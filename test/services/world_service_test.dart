import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:brush_quest/services/world_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorldService daily modifier', () {
    test('returns deterministic modifier for same date', () {
      final service = WorldService();
      final date = DateTime(2026, 2, 25);
      final a = service.getDailyModifier(date);
      final b = service.getDailyModifier(date);
      expect(a.type, b.type);
      expect(a.title, b.title);
    });

    test('modifier values stay within safe bounds', () {
      final service = WorldService();
      for (int i = 0; i < 30; i++) {
        final m = service.getDailyModifier(DateTime(2026, 1, 1 + i));
        expect(m.damageMultiplier >= 1.0, true);
        expect(m.bossChanceMultiplier >= 1.0, true);
        expect(m.chestBonusStars >= 0, true);
      }
    });

    test('modifier cycles through all 5 types over 5 days', () {
      final service = WorldService();
      final types = <DailyModifierType>{};
      // Jan 1 2026 is day 0 of year -> idx 0, Jan 2 -> idx 1, etc.
      for (int i = 0; i < 5; i++) {
        final m = service.getDailyModifier(DateTime(2026, 1, 1 + i));
        types.add(m.type);
      }
      expect(types.length, 5);
    });

    test('getDailyModifier defaults to now when no date is passed', () {
      final service = WorldService();
      final m = service.getDailyModifier();
      expect(m.title, isNotEmpty);
      // Just verify it doesn't crash and returns something valid
      expect(m.damageMultiplier >= 1.0, true);
    });
  });

  group('WorldService world roster', () {
    test('allWorlds contains exactly 10 worlds', () {
      expect(WorldService.allWorlds.length, 10);
    });

    test('all world IDs are unique', () {
      final ids = WorldService.allWorlds.map((w) => w.id).toSet();
      expect(ids.length, WorldService.allWorlds.length);
    });

    test('world IDs in expected order', () {
      final ids = WorldService.allWorlds.map((w) => w.id).toList();
      expect(ids, [
        'candy_crater',
        'slime_swamp',
        'sugar_volcano',
        'shadow_nebula',
        'cavity_fortress',
        'frozen_tundra',
        'toxic_jungle',
        'crystal_cave',
        'storm_citadel',
        'dark_dimension',
      ]);
    });

    test('all worlds have positive missionsRequired', () {
      for (final world in WorldService.allWorlds) {
        expect(world.missionsRequired > 0, true,
            reason: '${world.id} should require at least 1 mission');
      }
    });

    test('world mission thresholds are [5, 5, 6, 6, 7, 7, 7, 8, 8, 10]', () {
      final expected = [5, 5, 6, 6, 7, 7, 7, 8, 8, 10];
      for (int i = 0; i < WorldService.allWorlds.length; i++) {
        expect(WorldService.allWorlds[i].missionsRequired, expected[i],
            reason: '${WorldService.allWorlds[i].id} should require ${expected[i]} missions');
      }
    });
  });

  group('WorldService getWorldById', () {
    test('returns correct world by id', () {
      final world = WorldService.getWorldById('slime_swamp');
      expect(world.name, 'Slime Swamp');
    });

    test('returns candy_crater for unknown id', () {
      final world = WorldService.getWorldById('nonexistent');
      expect(world.id, 'candy_crater');
    });
  });

  group('WorldService progression', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('default current world is candy_crater', () async {
      final service = WorldService();
      final worldId = await service.getCurrentWorldId();
      expect(worldId, 'candy_crater');
    });

    test('getCurrentWorld returns WorldData object', () async {
      final service = WorldService();
      final world = await service.getCurrentWorld();
      expect(world.id, 'candy_crater');
      expect(world.name, 'Candy Crater');
    });

    test('getWorldProgress returns 0 for fresh world', () async {
      final service = WorldService();
      final progress = await service.getWorldProgress('candy_crater');
      expect(progress, 0);
    });

    test('recordMission increments progress by 1', () async {
      final service = WorldService();
      await service.recordMission();
      final progress = await service.getWorldProgress('candy_crater');
      expect(progress, 1);
    });

    test('multiple recordMission calls accumulate progress', () async {
      final service = WorldService();
      await service.recordMission();
      await service.recordMission();
      await service.recordMission();
      final progress = await service.getWorldProgress('candy_crater');
      expect(progress, 3);
    });

    test('completing enough missions advances to next world', () async {
      final service = WorldService();
      // candy_crater requires 5 missions
      for (int i = 0; i < 5; i++) {
        await service.recordMission();
      }
      final worldId = await service.getCurrentWorldId();
      expect(worldId, 'slime_swamp');
    });

    test('progress for previous world is preserved after advancing', () async {
      final service = WorldService();
      for (int i = 0; i < 5; i++) {
        await service.recordMission();
      }
      final progress = await service.getWorldProgress('candy_crater');
      expect(progress, 5);
    });

    test('setCurrentWorld changes current world', () async {
      final service = WorldService();
      await service.setCurrentWorld('sugar_volcano');
      final worldId = await service.getCurrentWorldId();
      expect(worldId, 'sugar_volcano');
    });

    test('does not advance past the last world', () async {
      // Start at the last world
      SharedPreferences.setMockInitialValues({
        'current_world': 'dark_dimension',
      });
      final service = WorldService();
      // dark_dimension requires 10 missions
      for (int i = 0; i < 10; i++) {
        await service.recordMission();
      }
      // Should still be dark_dimension (no world after it)
      final worldId = await service.getCurrentWorldId();
      expect(worldId, 'dark_dimension');
    });

    test('advancing through two worlds in sequence', () async {
      final service = WorldService();
      // Complete candy_crater (5 missions)
      for (int i = 0; i < 5; i++) {
        await service.recordMission();
      }
      expect(await service.getCurrentWorldId(), 'slime_swamp');

      // Complete slime_swamp (5 missions)
      for (int i = 0; i < 5; i++) {
        await service.recordMission();
      }
      expect(await service.getCurrentWorldId(), 'sugar_volcano');
    });
  });

  group('WorldService world unlock checks', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('first world is always unlocked', () async {
      final service = WorldService();
      final unlocked = await service.isWorldUnlocked('candy_crater');
      expect(unlocked, true);
    });

    test('second world is locked when first has no progress', () async {
      final service = WorldService();
      final unlocked = await service.isWorldUnlocked('slime_swamp');
      expect(unlocked, false);
    });

    test('second world unlocks after first world is completed', () async {
      SharedPreferences.setMockInitialValues({
        'world_progress_candy_crater': 5,
      });
      final service = WorldService();
      final unlocked = await service.isWorldUnlocked('slime_swamp');
      expect(unlocked, true);
    });

    test('second world unlocks when first world has more than required missions', () async {
      SharedPreferences.setMockInitialValues({
        'world_progress_candy_crater': 8, // more than 5 required
      });
      final service = WorldService();
      final unlocked = await service.isWorldUnlocked('slime_swamp');
      expect(unlocked, true);
    });

    test('third world is locked when second is incomplete', () async {
      SharedPreferences.setMockInitialValues({
        'world_progress_candy_crater': 5,
        'world_progress_slime_swamp': 3, // needs 5
      });
      final service = WorldService();
      final unlocked = await service.isWorldUnlocked('sugar_volcano');
      expect(unlocked, false);
    });
  });

  group('WorldService completion checks', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('isWorldCompleted returns false when progress < required', () async {
      SharedPreferences.setMockInitialValues({
        'world_progress_candy_crater': 3,
      });
      final service = WorldService();
      final completed = await service.isWorldCompleted('candy_crater');
      expect(completed, false);
    });

    test('isWorldCompleted returns true when progress >= required', () async {
      SharedPreferences.setMockInitialValues({
        'world_progress_candy_crater': 5,
      });
      final service = WorldService();
      final completed = await service.isWorldCompleted('candy_crater');
      expect(completed, true);
    });

    test('isAllWorldsCompleted returns false when any world is incomplete', () async {
      final service = WorldService();
      final allDone = await service.isAllWorldsCompleted();
      expect(allDone, false);
    });

    test('isAllWorldsCompleted returns true when all worlds are done', () async {
      final values = <String, Object>{};
      for (final world in WorldService.allWorlds) {
        values['world_progress_${world.id}'] = world.missionsRequired;
      }
      SharedPreferences.setMockInitialValues(values);
      final service = WorldService();
      final allDone = await service.isAllWorldsCompleted();
      expect(allDone, true);
    });
  });
}
