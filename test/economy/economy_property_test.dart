import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, setUp, setUpAll, tearDown, tearDownAll, test;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:brush_quest/services/hero_service.dart';
import 'package:brush_quest/services/streak_service.dart';
import 'package:brush_quest/services/weapon_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── 1. Price ladder monotonicity ──────────────────────────────────────────

  group('Price ladder monotonicity', () {
    test('hero prices are non-decreasing in roster order', () {
      final prices = HeroService.allHeroes.map((h) => h.price).toList();
      for (var i = 1; i < prices.length; i++) {
        expect(
          prices[i] >= prices[i - 1],
          isTrue,
          reason: 'Hero at index $i (${prices[i]}) should be >= '
              'hero at index ${i - 1} (${prices[i - 1]})',
        );
      }
    });

    test('weapon prices are non-decreasing in roster order', () {
      final prices = WeaponService.allWeapons.map((w) => w.price).toList();
      for (var i = 1; i < prices.length; i++) {
        expect(
          prices[i] >= prices[i - 1],
          isTrue,
          reason: 'Weapon at index $i (${prices[i]}) should be >= '
              'weapon at index ${i - 1} (${prices[i - 1]})',
        );
      }
    });

    test('hero evolution prices are non-decreasing per hero', () {
      for (final hero in HeroService.allHeroes) {
        final evos = HeroService.evolutionsForHero(hero.id);
        for (var i = 1; i < evos.length; i++) {
          expect(
            evos[i].price >= evos[i - 1].price,
            isTrue,
            reason: '${hero.id} stage ${evos[i].stage} (${evos[i].price}) '
                'should be >= stage ${evos[i - 1].stage} '
                '(${evos[i - 1].price})',
          );
        }
      }
    });
  });

  // ── 2. Wallet never goes negative ────────────────────────────────────────

  group('Wallet never goes negative', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    Glados<int>(any.intInRange(0, 200)).test(
      'spendStars returns false when wallet has insufficient funds',
      (walletBalance) async {
        SharedPreferences.setMockInitialValues({
          'star_wallet': walletBalance,
        });
        final service = StreakService();
        final overSpend = walletBalance + 1;
        final result = await service.spendStars(overSpend);
        expect(result, isFalse);
        final remaining = await service.getWallet();
        expect(remaining, walletBalance);
      },
    );

    Glados<int>(any.intInRange(0, 200)).test(
      'wallet stays non-negative after any valid spend',
      (walletBalance) async {
        SharedPreferences.setMockInitialValues({
          'star_wallet': walletBalance,
        });
        final service = StreakService();

        // Try spending every possible amount from 1 to walletBalance
        // (capped to avoid huge loops)
        final cap = walletBalance > 20 ? 20 : walletBalance;
        for (var spend = 1; spend <= cap; spend++) {
          SharedPreferences.setMockInitialValues({
            'star_wallet': walletBalance,
          });
          await service.spendStars(spend);
          final remaining = await service.getWallet();
          expect(remaining, greaterThanOrEqualTo(0));
        }
      },
    );

    test('hero purchase fails when wallet is below hero price', () async {
      for (final hero in HeroService.allHeroes) {
        if (hero.price == 0) continue;
        SharedPreferences.setMockInitialValues({
          'star_wallet': hero.price - 1,
        });
        final service = HeroService();
        final result = await service.purchaseHero(hero.id);
        expect(result, isFalse, reason: '${hero.id} should not be '
            'purchasable with ${hero.price - 1} stars');
      }
    });

    test('weapon purchase fails when wallet is below weapon price', () async {
      for (final weapon in WeaponService.allWeapons) {
        if (weapon.price == 0) continue;
        SharedPreferences.setMockInitialValues({
          'star_wallet': weapon.price - 1,
        });
        final service = WeaponService();
        final result = await service.purchaseWeapon(weapon.id);
        expect(result, isFalse, reason: '${weapon.id} should not be '
            'purchasable with ${weapon.price - 1} stars');
      }
    });
  });

  // ── 3. Rank (total_stars) never decreases ────────────────────────────────

  group('Rank (total_stars) never decreases', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    Glados<int>(any.intInRange(10, 200)).test(
      'total_stars unchanged after hero purchase',
      (initialStars) async {
        // Pick a hero that costs <= initialStars
        final affordableHero = HeroService.allHeroes
            .where((h) => h.price > 0 && h.price <= initialStars)
            .toList();
        if (affordableHero.isEmpty) return; // Nothing affordable, skip

        final hero = affordableHero.last;
        SharedPreferences.setMockInitialValues({
          'total_stars': initialStars,
          'star_wallet': initialStars,
        });

        final service = HeroService();
        await service.purchaseHero(hero.id);

        final prefs = await SharedPreferences.getInstance();
        final totalAfter = prefs.getInt('total_stars') ?? 0;
        expect(totalAfter, initialStars,
            reason: 'Rank should not change after spending wallet stars');
      },
    );

    Glados<int>(any.intInRange(10, 200)).test(
      'total_stars unchanged after weapon purchase',
      (initialStars) async {
        final affordableWeapon = WeaponService.allWeapons
            .where((w) => w.price > 0 && w.price <= initialStars)
            .toList();
        if (affordableWeapon.isEmpty) return;

        final weapon = affordableWeapon.last;
        SharedPreferences.setMockInitialValues({
          'total_stars': initialStars,
          'star_wallet': initialStars,
        });

        final service = WeaponService();
        await service.purchaseWeapon(weapon.id);

        final prefs = await SharedPreferences.getInstance();
        final totalAfter = prefs.getInt('total_stars') ?? 0;
        expect(totalAfter, initialStars,
            reason: 'Rank should not change after spending wallet stars');
      },
    );

    Glados<int>(any.intInRange(10, 200)).test(
      'total_stars unchanged after evolution purchase',
      (initialStars) async {
        // Find an affordable evolution (stage 2, no prerequisite issue)
        final affordableEvo = HeroService.allEvolutions
            .where((e) => e.stage == 2 && e.price > 0 && e.price <= initialStars)
            .toList();
        if (affordableEvo.isEmpty) return;

        final evo = affordableEvo.last;
        SharedPreferences.setMockInitialValues({
          'total_stars': initialStars,
          'star_wallet': initialStars,
          'unlocked_heroes': ['blaze', 'frost', 'bolt', 'shadow', 'leaf', 'nova'],
        });

        final service = HeroService();
        await service.purchaseEvolution(evo.id);

        final prefs = await SharedPreferences.getInstance();
        final totalAfter = prefs.getInt('total_stars') ?? 0;
        expect(totalAfter, initialStars,
            reason: 'Rank should not change after purchasing an evolution');
      },
    );
  });

  // ── 4. Star earning is deterministic ─────────────────────────────────────

  group('Star earning is deterministic', () {
    Glados2<int, bool>(
      any.intInRange(0, 100),
      any.bool,
    ).test(
      'calculateStreakBonus is deterministic for same inputs',
      (streak, bothSlotsDone) {
        final service = StreakService();
        final first = service.calculateStreakBonus(
          streak: streak,
          bothSlotsDone: bothSlotsDone,
        );
        final second = service.calculateStreakBonus(
          streak: streak,
          bothSlotsDone: bothSlotsDone,
        );
        expect(first, second,
            reason: 'Same inputs should produce same bonus '
                '(streak=$streak, bothSlots=$bothSlotsDone)');
      },
    );

    test('base stars are always 2', () async {
      SharedPreferences.setMockInitialValues({});
      final service = StreakService();
      final outcome = await service.recordBrush();
      expect(outcome.baseStars, 2);
    });

    Glados2<int, bool>(
      any.intInRange(0, 100),
      any.bool,
    ).test(
      'detailed breakdown total matches simple bonus',
      (streak, bothSlotsDone) {
        final service = StreakService();
        final simple = service.calculateStreakBonus(
          streak: streak,
          bothSlotsDone: bothSlotsDone,
        );
        final detailed = service.calculateStreakBonusDetailed(
          streak: streak,
          bothSlotsDone: bothSlotsDone,
        );
        expect(detailed.total, simple,
            reason: 'Detailed breakdown total should equal simple bonus');
      },
    );
  });

  // ── 5. Streak bonus bounds ───────────────────────────────────────────────

  group('Streak bonus bounds', () {
    Glados2<int, bool>(
      any.intInRange(0, 1000),
      any.bool,
    ).test(
      'streak bonus is always 0-3',
      (streak, bothSlotsDone) {
        final service = StreakService();
        final bonus = service.calculateStreakBonus(
          streak: streak,
          bothSlotsDone: bothSlotsDone,
        );
        expect(bonus, inInclusiveRange(0, 3),
            reason: 'Bonus should be 0-3, got $bonus '
                '(streak=$streak, bothSlots=$bothSlotsDone)');
      },
    );

    Glados<int>(any.intInRange(0, 2)).test(
      'streak < 3: multiplier bonus is 0',
      (streak) {
        final service = StreakService();
        final breakdown = service.calculateStreakBonusDetailed(
          streak: streak,
          bothSlotsDone: false,
        );
        expect(breakdown.streakMultiplierBonus, 0,
            reason: 'Streak $streak (< 3) should give 0 multiplier bonus');
      },
    );

    Glados<int>(any.intInRange(3, 7)).test(
      'streak 3-6: multiplier bonus is 1',
      (streak) {
        final service = StreakService();
        final breakdown = service.calculateStreakBonusDetailed(
          streak: streak,
          bothSlotsDone: false,
        );
        expect(breakdown.streakMultiplierBonus, 1,
            reason: 'Streak $streak (3-6) should give 1 multiplier bonus');
      },
    );

    Glados<int>(any.intInRange(7, 500)).test(
      'streak >= 7: multiplier bonus is 2',
      (streak) {
        final service = StreakService();
        final breakdown = service.calculateStreakBonusDetailed(
          streak: streak,
          bothSlotsDone: false,
        );
        expect(breakdown.streakMultiplierBonus, 2,
            reason: 'Streak $streak (>= 7) should give 2 multiplier bonus');
      },
    );

    Glados<int>(any.intInRange(0, 500)).test(
      'daily pair bonus is exactly 1 when both slots done',
      (streak) {
        final service = StreakService();
        final breakdown = service.calculateStreakBonusDetailed(
          streak: streak,
          bothSlotsDone: true,
        );
        expect(breakdown.dailyBonus, 1);
      },
    );

    Glados<int>(any.intInRange(0, 500)).test(
      'daily pair bonus is exactly 0 when not both slots done',
      (streak) {
        final service = StreakService();
        final breakdown = service.calculateStreakBonusDetailed(
          streak: streak,
          bothSlotsDone: false,
        );
        expect(breakdown.dailyBonus, 0);
      },
    );
  });

  // ── 6. No dead zones in unlock ladder ────────────────────────────────────

  group('No dead zones in unlock ladder', () {
    test('no gap between consecutive unlock prices exceeds 6 stars', () {
      final allPrices = <int>[
        ...HeroService.allHeroes.map((h) => h.price),
        ...WeaponService.allWeapons.map((w) => w.price),
      ];
      // Remove free items (price 0) — they are always available
      allPrices.removeWhere((p) => p == 0);
      allPrices.sort();
      // Remove duplicates for gap analysis
      final uniquePrices = allPrices.toSet().toList()..sort();

      for (var i = 1; i < uniquePrices.length; i++) {
        final gap = uniquePrices[i] - uniquePrices[i - 1];
        expect(
          gap <= 6,
          isTrue,
          reason: 'Gap between prices ${uniquePrices[i - 1]} and '
              '${uniquePrices[i]} is $gap stars (> 6). '
              'Child would go ~${(gap / 2).ceil()} days without a new unlock.',
        );
      }
    });

    test('first paid item costs at most 6 stars', () {
      final allPrices = <int>[
        ...HeroService.allHeroes.map((h) => h.price),
        ...WeaponService.allWeapons.map((w) => w.price),
      ];
      allPrices.removeWhere((p) => p == 0);
      allPrices.sort();
      expect(
        allPrices.first,
        lessThanOrEqualTo(6),
        reason: 'First paid item should be achievable within 3 days '
            '(at 2 stars/brush, 2 brushes/day)',
      );
    });
  });

  // ── 7. Purchase atomicity ────────────────────────────────────────────────

  group('Purchase atomicity', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    Glados<int>(any.intInRange(0, 200)).test(
      'successful hero purchase decreases wallet by exactly the hero price',
      (extraStars) async {
        for (final hero in HeroService.allHeroes) {
          if (hero.price == 0) continue;
          final walletBefore = hero.price + extraStars;
          SharedPreferences.setMockInitialValues({
            'star_wallet': walletBefore,
          });

          final service = HeroService();
          final result = await service.purchaseHero(hero.id);

          if (result) {
            final prefs = await SharedPreferences.getInstance();
            final walletAfter = prefs.getInt('star_wallet') ?? 0;
            expect(
              walletAfter,
              walletBefore - hero.price,
              reason: 'After buying ${hero.id} (cost ${hero.price}) '
                  'with $walletBefore stars, wallet should be '
                  '${walletBefore - hero.price} but was $walletAfter',
            );
          }
        }
      },
    );

    Glados<int>(any.intInRange(0, 200)).test(
      'successful weapon purchase decreases wallet by exactly the weapon price',
      (extraStars) async {
        for (final weapon in WeaponService.allWeapons) {
          if (weapon.price == 0) continue;
          final walletBefore = weapon.price + extraStars;
          SharedPreferences.setMockInitialValues({
            'star_wallet': walletBefore,
          });

          final service = WeaponService();
          final result = await service.purchaseWeapon(weapon.id);

          if (result) {
            final prefs = await SharedPreferences.getInstance();
            final walletAfter = prefs.getInt('star_wallet') ?? 0;
            expect(
              walletAfter,
              walletBefore - weapon.price,
              reason: 'After buying ${weapon.id} (cost ${weapon.price}) '
                  'with $walletBefore stars, wallet should be '
                  '${walletBefore - weapon.price} but was $walletAfter',
            );
          }
        }
      },
    );

    test('failed purchase leaves wallet unchanged', () async {
      for (final hero in HeroService.allHeroes) {
        if (hero.price == 0) continue;
        final walletBefore = hero.price - 1;
        SharedPreferences.setMockInitialValues({
          'star_wallet': walletBefore,
        });

        final service = HeroService();
        await service.purchaseHero(hero.id);

        final prefs = await SharedPreferences.getInstance();
        final walletAfter = prefs.getInt('star_wallet') ?? 0;
        expect(walletAfter, walletBefore,
            reason: 'Failed purchase of ${hero.id} should leave wallet '
                'at $walletBefore but was $walletAfter');
      }
    });

    test('failed weapon purchase leaves wallet unchanged', () async {
      for (final weapon in WeaponService.allWeapons) {
        if (weapon.price == 0) continue;
        final walletBefore = weapon.price - 1;
        SharedPreferences.setMockInitialValues({
          'star_wallet': walletBefore,
        });

        final service = WeaponService();
        await service.purchaseWeapon(weapon.id);

        final prefs = await SharedPreferences.getInstance();
        final walletAfter = prefs.getInt('star_wallet') ?? 0;
        expect(walletAfter, walletBefore,
            reason: 'Failed purchase of ${weapon.id} should leave wallet '
                'at $walletBefore but was $walletAfter');
      }
    });
  });
}
