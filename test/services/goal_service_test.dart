// test/services/goal_service_test.dart
import 'package:brush_quest/services/goal_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GoalRules.heroGoal', () {
    test('picks the cheaper of next upgrade and next new hero', () {
      // Blaze stage 2 = 10, next new hero = frost 5 -> frost.
      final g = GoalRules.heroGoal(
        unlockedHeroIds: ['blaze'],
        selectedHeroId: 'blaze',
        unlockedEvolutionIds: [],
        wallet: 3,
      )!;
      expect(g.itemId, 'frost');
      expect(g.isEvolution, isFalse);
      expect(g.cost, 5);
      expect(g.left, 2);
      expect(g.affordable, isFalse);
    });

    test('upgrade wins when cheaper', () {
      // Owns blaze, frost, bolt, shadow; next new = leaf 15; blaze stage2 = 10.
      final g = GoalRules.heroGoal(
        unlockedHeroIds: ['blaze', 'frost', 'bolt', 'shadow'],
        selectedHeroId: 'blaze',
        unlockedEvolutionIds: [],
        wallet: 10,
      )!;
      expect(g.itemId, 'blaze_stage2');
      expect(g.isEvolution, isTrue);
      expect(g.heroId, 'blaze');
      expect(g.stage, 2);
      expect(g.affordable, isTrue);
    });

    test('on a tie the upgrade wins', () {
      // Selected frost: frost stage2 = 12; next new = shadow 12.
      final g = GoalRules.heroGoal(
        unlockedHeroIds: ['blaze', 'frost', 'bolt'],
        selectedHeroId: 'frost',
        unlockedEvolutionIds: [],
        wallet: 0,
      )!;
      expect(g.itemId, 'frost_stage2');
    });

    test('next upgrade follows the owned stages of the selected hero', () {
      final g = GoalRules.heroGoal(
        unlockedHeroIds: ['blaze', 'frost', 'bolt', 'shadow', 'leaf', 'nova'],
        selectedHeroId: 'blaze',
        unlockedEvolutionIds: ['blaze_stage2'],
        wallet: 0,
      )!;
      expect(g.itemId, 'blaze_stage3');
      expect(g.cost, 20);
    });

    test(
      'complete when every hero is owned and the selected hero is fully upgraded',
      () {
        final g = GoalRules.heroGoal(
          unlockedHeroIds: ['blaze', 'frost', 'bolt', 'shadow', 'leaf', 'nova'],
          selectedHeroId: 'nova',
          unlockedEvolutionIds: ['nova_stage2', 'nova_stage3'],
          wallet: 99,
        );
        expect(g, isNull);
      },
    );

    // Not in the brief: a stale or synced save can hold an evolution id that
    // doesn't exist; the goal ignores it rather than offering it.
    test('ignores evolution ids it does not know', () {
      final g = GoalRules.heroGoal(
        unlockedHeroIds: ['blaze'],
        selectedHeroId: 'blaze',
        unlockedEvolutionIds: ['mystery_stage9'],
        wallet: 0,
      )!;
      expect(g.itemId, 'frost');
    });
  });

  group('GoalRules.weaponGoal', () {
    test('cheapest locked weapon', () {
      final g = GoalRules.weaponGoal(
        unlockedWeaponIds: ['star_blaster', 'flame_sword'],
        wallet: 9,
      )!;
      expect(g.itemId, 'ice_hammer');
      expect(g.left, 5);
    });
    test('complete when all owned', () {
      expect(
        GoalRules.weaponGoal(
          unlockedWeaponIds: [
            'star_blaster',
            'flame_sword',
            'ice_hammer',
            'lightning_wand',
            'vine_whip',
            'cosmic_burst',
          ],
          wallet: 0,
        ),
        isNull,
      );
    });
  });

  group('GoalRules.worldGoal', () {
    test('counts the frontier missions; silhouette is the next planet', () {
      final g = GoalRules.worldGoal(
        progress: {'candy_crater': 5, 'slime_swamp': 2},
      )!;
      expect(g.category, GoalCategory.world);
      expect(g.itemId, 'sugar_volcano'); // unlocks when slime_swamp is done
      expect(g.cost, 5); // slime_swamp missionsRequired
      expect(g.have, 2);
      expect(g.left, 3);
      expect(g.affordable, isFalse); // worlds are never bought
    });
    test('last world: the goal is finishing it', () {
      final p = {
        'candy_crater': 5,
        'slime_swamp': 5,
        'sugar_volcano': 6,
        'shadow_nebula': 6,
        'cavity_fortress': 7,
        'frozen_tundra': 7,
        'toxic_jungle': 7,
        'crystal_cave': 8,
        'storm_citadel': 8,
        'dark_dimension': 4,
      };
      final g = GoalRules.worldGoal(progress: p)!;
      expect(g.itemId, 'dark_dimension');
      expect(g.left, 6);
    });
    test('complete when every world is finished', () {
      final p = {
        'candy_crater': 5,
        'slime_swamp': 5,
        'sugar_volcano': 6,
        'shadow_nebula': 6,
        'cavity_fortress': 7,
        'frozen_tundra': 7,
        'toxic_jungle': 7,
        'crystal_cave': 8,
        'storm_citadel': 8,
        'dark_dimension': 10,
      };
      expect(GoalRules.worldGoal(progress: p), isNull);
    });
  });

  group('GoalRules.overallGoal', () {
    const hero = Goal(
      category: GoalCategory.hero,
      itemId: 'frost',
      cost: 5,
      have: 3,
    );
    const weapon = Goal(
      category: GoalCategory.weapon,
      itemId: 'flame_sword',
      cost: 5,
      have: 3,
    );
    const farWeapon = Goal(
      category: GoalCategory.weapon,
      itemId: 'ice_hammer',
      cost: 14,
      have: 3,
    );
    test('fewest stars left wins; tie goes to the hero', () {
      expect(GoalRules.overallGoal(hero, farWeapon), hero);
      expect(GoalRules.overallGoal(hero, weapon), hero);
      expect(GoalRules.overallGoal(null, weapon), weapon);
      expect(GoalRules.overallGoal(null, null), isNull);
    });
  });

  test('GoalService reads the services', () async {
    SharedPreferences.setMockInitialValues({
      'star_wallet': 4,
      'unlocked_heroes': ['blaze'],
      'selected_hero': 'blaze',
      'unlocked_weapons': ['star_blaster'],
      'world_progress_candy_crater': 1,
    });
    final s = GoalService();
    expect((await s.heroGoal())!.itemId, 'frost');
    expect((await s.weaponGoal())!.itemId, 'flame_sword');
    // The meters count the wallet.
    expect((await s.heroGoal())!.have, 4);
    expect((await s.weaponGoal())!.have, 4);
    final w = (await s.worldGoal())!;
    expect(w.itemId, 'slime_swamp');
    expect(w.left, 4);
    expect((await s.overallGoal())!.itemId, 'frost');
  });
}
