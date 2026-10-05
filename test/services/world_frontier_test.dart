// test/services/world_frontier_test.dart
import 'package:brush_quest/services/world_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = WorldService();

  Future<int> progress(String id) => service.getWorldProgress(id);

  test('frontier is the first unfinished world', () async {
    SharedPreferences.setMockInitialValues({'world_progress_candy_crater': 5});
    expect((await service.getFrontierWorld())!.id, 'slime_swamp');
  });

  test(
    'a brush in a revisited finished world counts toward the frontier',
    () async {
      SharedPreferences.setMockInitialValues({
        'world_progress_candy_crater': 5,
        'world_progress_slime_swamp': 2,
        'current_world': 'candy_crater', // the child picked the old world
      });
      await service.recordMission();
      expect(await progress('candy_crater'), 5); // unchanged
      expect(await progress('slime_swamp'), 3);
      expect(await service.getCurrentWorldId(), 'candy_crater'); // scenery kept
    },
  );

  test(
    'finishing the frontier moves the current world to the next one',
    () async {
      SharedPreferences.setMockInitialValues({
        'world_progress_candy_crater': 5,
        'world_progress_slime_swamp': 4,
        'current_world': 'candy_crater',
      });
      await service.recordMission();
      expect(await progress('slime_swamp'), 5);
      expect(await service.getCurrentWorldId(), 'sugar_volcano');
    },
  );

  test('finishing the last world keeps it current', () async {
    final values = <String, Object>{'current_world': 'dark_dimension'};
    for (final w in WorldService.allWorlds) {
      values['world_progress_${w.id}'] = w.id == 'dark_dimension'
          ? w.missionsRequired - 1
          : w.missionsRequired;
    }
    SharedPreferences.setMockInitialValues(values);
    await service.recordMission();
    expect(await service.isAllWorldsCompleted(), isTrue);
    expect(await service.getCurrentWorldId(), 'dark_dimension');
  });

  test('when every world is finished, recordMission changes nothing', () async {
    final values = <String, Object>{'current_world': 'storm_citadel'};
    for (final w in WorldService.allWorlds) {
      values['world_progress_${w.id}'] = w.missionsRequired;
    }
    SharedPreferences.setMockInitialValues(values);
    expect(await service.getFrontierWorld(), isNull);
    await service.recordMission();
    expect(await progress('storm_citadel'), 8);
    expect(await progress('dark_dimension'), 10);
    expect(await service.getCurrentWorldId(), 'storm_citadel');
  });

  test('unlock rule is unchanged (no world re-locks)', () async {
    SharedPreferences.setMockInitialValues({'world_progress_candy_crater': 5});
    expect(await service.isWorldUnlocked('slime_swamp'), isTrue);
    expect(await service.isWorldUnlocked('sugar_volcano'), isFalse);
  });
}
