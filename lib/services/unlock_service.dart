// lib/services/unlock_service.dart
import 'dart:async';

import 'analytics_service.dart';
import 'goal_service.dart';
import 'hero_service.dart';
import 'streak_service.dart';
import 'weapon_service.dart';

/// Buy an item and equip it — the steps the shop runs after its
/// confirmation dialog (hero_shop_screen.dart), shared with the victory
/// screen's one-tap unlock (spec §6 step 4). Purchases keep the existing
/// `StreakService.isPurchasing` guard, so a double tap spends once.
class UnlockService {
  final HeroService _heroes;
  final WeaponService _weapons;
  final StreakService _streak;
  final AnalyticsService? _analyticsOverride;

  UnlockService({
    HeroService? heroes,
    WeaponService? weapons,
    StreakService? streak,
    AnalyticsService? analytics,
  }) : _heroes = heroes ?? HeroService(),
       _weapons = weapons ?? WeaponService(),
       _streak = streak ?? StreakService(),
       _analyticsOverride = analytics;

  // Looked up per call, as the shop did, so the singleton (and on Android
  // FirebaseAnalytics) is only touched when an unlock is actually logged.
  AnalyticsService get _analytics => _analyticsOverride ?? AnalyticsService();

  Future<bool> unlockHero(String heroId) async {
    if (!await _heroes.purchaseHero(heroId)) return false;
    await _heroes.selectHero(heroId);
    final rank = await _streak.getRangerRank();
    unawaited(_analytics.logHeroUnlock(heroId: heroId, starsAtUnlock: rank));
    return true;
  }

  /// Equips the new stage only if that hero is the selected one — otherwise
  /// the child's hero would silently switch (same rule as the shop).
  Future<bool> unlockEvolution(String evolutionId) async {
    final evo = HeroService.getEvolutionById(evolutionId);
    if (evo == null) return false;
    if (!await _heroes.purchaseEvolution(evolutionId)) return false;
    // getSelectedHero(), not getSelectedHeroId(): that is what the shop
    // asked, and a saved id it doesn't know counts as Blaze (the hero Home
    // draws), so a bought Blaze stage is still equipped.
    if ((await _heroes.getSelectedHero()).id == evo.heroId) {
      await _heroes.setEvolutionStage(evo.heroId, evo.stage);
    }
    return true;
  }

  Future<bool> unlockWeapon(String weaponId) async {
    if (!await _weapons.purchaseWeapon(weaponId)) return false;
    await _weapons.selectWeapon(weaponId);
    final rank = await _streak.getRangerRank();
    unawaited(
      _analytics.logWeaponUnlock(weaponId: weaponId, starsAtUnlock: rank),
    );
    return true;
  }

  Future<bool> unlockGoal(Goal goal) {
    switch (goal.category) {
      case GoalCategory.hero:
        return goal.isEvolution
            ? unlockEvolution(goal.itemId)
            : unlockHero(goal.itemId);
      case GoalCategory.weapon:
        return unlockWeapon(goal.itemId);
      case GoalCategory.world:
        return Future.value(false);
    }
  }
}
