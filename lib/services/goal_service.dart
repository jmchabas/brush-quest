// lib/services/goal_service.dart
import 'dart:math';

import 'hero_service.dart';
import 'streak_service.dart';
import 'weapon_service.dart';
import 'world_service.dart';

enum GoalCategory { hero, weapon, world }

/// The closest next unlock in one category (spec §5). A null goal means
/// the category is complete.
class Goal {
  final GoalCategory category;

  /// Hero id ('frost'), evolution id ('blaze_stage2'), weapon id, or — for
  /// worlds — the planet that unlocks next.
  final String itemId;

  /// Set for an evolution goal: the hero it upgrades.
  final String? evolutionHeroId;

  /// Evolution stage (2 or 3) for an evolution goal; 1 otherwise.
  final int stage;

  /// Stars (heroes, evolutions, weapons) or missions (worlds).
  final int cost;

  /// Wallet stars, or missions done in the frontier world.
  final int have;

  const Goal({
    required this.category,
    required this.itemId,
    this.evolutionHeroId,
    this.stage = 1,
    required this.cost,
    required this.have,
  });

  bool get isEvolution => evolutionHeroId != null;

  int get left => max(0, cost - have);

  /// Heroes, evolutions and weapons can be bought once the wallet covers
  /// them. Worlds unlock by brushing and are never bought.
  bool get affordable => category != GoalCategory.world && have >= cost;

  /// Hero to draw for a hero or evolution goal.
  String get heroId => evolutionHeroId ?? itemId;
}

/// Pure goal rules (no I/O).
class GoalRules {
  GoalRules._();

  /// Cheaper of: the next upgrade of the selected hero, the cheapest locked
  /// hero. A tie goes to the upgrade.
  static Goal? heroGoal({
    required List<String> unlockedHeroIds,
    required String selectedHeroId,
    required List<String> unlockedEvolutionIds,
    required int wallet,
  }) {
    // Walk the selected hero's own ladder: it holds exactly the stages that
    // exist, so an id that doesn't (such as '<hero>_stage4' once a hero is
    // maxed, or an unknown id in a saved game) is simply never matched.
    final ladder = HeroService.evolutionsForHero(selectedHeroId);
    var topStage = 1;
    for (final evo in ladder) {
      if (unlockedEvolutionIds.contains(evo.id) && evo.stage > topStage) {
        topStage = evo.stage;
      }
    }
    Goal? upgrade;
    final nextEvo = ladder.where((e) => e.stage == topStage + 1).firstOrNull;
    if (nextEvo != null) {
      upgrade = Goal(
        category: GoalCategory.hero,
        itemId: nextEvo.id,
        evolutionHeroId: selectedHeroId,
        stage: nextEvo.stage,
        cost: nextEvo.price,
        have: wallet,
      );
    }

    Goal? newHero;
    for (final hero in HeroService.allHeroes) {
      if (unlockedHeroIds.contains(hero.id)) continue;
      if (newHero == null || hero.price < newHero.cost) {
        newHero = Goal(
          category: GoalCategory.hero,
          itemId: hero.id,
          cost: hero.price,
          have: wallet,
        );
      }
    }

    if (upgrade == null) return newHero;
    if (newHero == null) return upgrade;
    return newHero.cost < upgrade.cost ? newHero : upgrade;
  }

  static Goal? weaponGoal({
    required List<String> unlockedWeaponIds,
    required int wallet,
  }) {
    Goal? best;
    for (final weapon in WeaponService.allWeapons) {
      if (unlockedWeaponIds.contains(weapon.id)) continue;
      if (best == null || weapon.price < best.cost) {
        best = Goal(
          category: GoalCategory.weapon,
          itemId: weapon.id,
          cost: weapon.price,
          have: wallet,
        );
      }
    }
    return best;
  }

  /// Frontier = first unfinished world. The goal item is the planet that
  /// unlocks when the frontier is done (or the frontier itself if last).
  static Goal? worldGoal({required Map<String, int> progress}) {
    const worlds = WorldService.allWorlds;
    for (var i = 0; i < worlds.length; i++) {
      final w = worlds[i];
      final done = progress[w.id] ?? 0;
      if (done < w.missionsRequired) {
        final next = i + 1 < worlds.length ? worlds[i + 1] : w;
        return Goal(
          category: GoalCategory.world,
          itemId: next.id,
          cost: w.missionsRequired,
          have: done,
        );
      }
    }
    return null;
  }

  /// For the victory screen: fewest stars left; a tie goes to the hero.
  static Goal? overallGoal(Goal? hero, Goal? weapon) {
    if (hero == null) return weapon;
    if (weapon == null) return hero;
    return weapon.left < hero.left ? weapon : hero;
  }
}

/// Reads the current state and applies [GoalRules].
class GoalService {
  final HeroService _heroes;
  final WeaponService _weapons;
  final WorldService _worlds;
  final StreakService _streak;

  GoalService({
    HeroService? heroes,
    WeaponService? weapons,
    WorldService? worlds,
    StreakService? streak,
  }) : _heroes = heroes ?? HeroService(),
       _weapons = weapons ?? WeaponService(),
       _worlds = worlds ?? WorldService(),
       _streak = streak ?? StreakService();

  Future<Goal?> heroGoal() async => GoalRules.heroGoal(
    unlockedHeroIds: await _heroes.getUnlockedHeroIds(),
    selectedHeroId: await _heroes.getSelectedHeroId(),
    unlockedEvolutionIds: await _heroes.getUnlockedEvolutionIds(),
    wallet: await _streak.getWallet(),
  );

  Future<Goal?> weaponGoal() async => GoalRules.weaponGoal(
    unlockedWeaponIds: await _weapons.getUnlockedWeaponIds(),
    wallet: await _streak.getWallet(),
  );

  Future<Goal?> worldGoal() async {
    final progress = <String, int>{};
    for (final w in WorldService.allWorlds) {
      progress[w.id] = await _worlds.getWorldProgress(w.id);
    }
    return GoalRules.worldGoal(progress: progress);
  }

  Future<Goal?> overallGoal() async =>
      GoalRules.overallGoal(await heroGoal(), await weaponGoal());
}
