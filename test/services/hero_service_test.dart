import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:brush_quest/services/hero_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HeroService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    // ── Hero roster ───────────────────────────────────────────────

    test('allHeroes contains exactly 6 heroes', () {
      expect(HeroService.allHeroes.length, 6);
    });

    test('hero prices match expected values (0/8/18/25/33/40)', () {
      final expectedPrices = [0, 8, 18, 25, 33, 40];
      for (int i = 0; i < HeroService.allHeroes.length; i++) {
        expect(HeroService.allHeroes[i].price, expectedPrices[i],
            reason: 'Hero ${HeroService.allHeroes[i].id} should cost ${expectedPrices[i]}');
      }
    });

    test('all hero IDs are unique', () {
      final ids = HeroService.allHeroes.map((h) => h.id).toSet();
      expect(ids.length, HeroService.allHeroes.length);
    });

    test('hero IDs are blaze, frost, bolt, shadow, leaf, nova', () {
      final ids = HeroService.allHeroes.map((h) => h.id).toList();
      expect(ids, ['blaze', 'frost', 'bolt', 'shadow', 'leaf', 'nova']);
    });

    // ── Default state ─────────────────────────────────────────────

    test('default hero is blaze (price 0)', () async {
      final service = HeroService();
      final selected = await service.getSelectedHeroId();
      expect(selected, 'blaze');
    });

    test('blaze is unlocked by default', () async {
      final service = HeroService();
      final unlocked = await service.getUnlockedHeroIds();
      expect(unlocked, contains('blaze'));
    });

    test('only blaze is unlocked initially', () async {
      final service = HeroService();
      final unlocked = await service.getUnlockedHeroIds();
      expect(unlocked.length, 1);
      expect(unlocked[0], 'blaze');
    });

    // ── getHeroById ───────────────────────────────────────────────

    test('getHeroById returns correct hero', () {
      final hero = HeroService.getHeroById('frost');
      expect(hero.name, 'FROST');
      expect(hero.price, 8);
    });

    test('getHeroById returns blaze for unknown id', () {
      final hero = HeroService.getHeroById('nonexistent');
      expect(hero.id, 'blaze');
    });

    // ── getSelectedHero ───────────────────────────────────────────

    test('getSelectedHero returns HeroCharacter object', () async {
      final service = HeroService();
      final hero = await service.getSelectedHero();
      expect(hero.id, 'blaze');
      expect(hero.name, 'BLAZE');
    });

    // ── Hero selection ────────────────────────────────────────────

    test('selectHero changes selected hero', () async {
      final service = HeroService();
      await service.selectHero('frost');
      final selected = await service.getSelectedHeroId();
      expect(selected, 'frost');
    });

    test('selected hero persists across service instances', () async {
      final service1 = HeroService();
      await service1.selectHero('bolt');
      final service2 = HeroService();
      final selected = await service2.getSelectedHeroId();
      expect(selected, 'bolt');
    });

    // ── Purchase logic ──────────────────────────────────────────

    test('purchaseHero succeeds when wallet has enough stars', () async {
      SharedPreferences.setMockInitialValues({
        'star_wallet': 20,
        'total_stars': 20,
      });
      final service = HeroService();
      final result = await service.purchaseHero('frost'); // price 8
      expect(result, true);

      final unlocked = await service.getUnlockedHeroIds();
      expect(unlocked, contains('frost'));

      // Stars deducted from wallet
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('star_wallet'), 12); // 20 - 8
      expect(prefs.getInt('total_stars'), 20); // Rank unchanged
    });

    test('purchaseHero fails when wallet has insufficient stars', () async {
      SharedPreferences.setMockInitialValues({
        'star_wallet': 10,
        'total_stars': 50,
      });
      final service = HeroService();
      final result = await service.purchaseHero('bolt'); // price 18
      expect(result, false);

      final unlocked = await service.getUnlockedHeroIds();
      expect(unlocked, isNot(contains('bolt')));

      // Wallet unchanged
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('star_wallet'), 10);
    });

    test('purchaseHero succeeds without deducting if already owned', () async {
      SharedPreferences.setMockInitialValues({
        'star_wallet': 50,
        'total_stars': 50,
        'unlocked_heroes': ['blaze', 'frost'],
      });
      final service = HeroService();
      final result = await service.purchaseHero('frost');
      expect(result, true);

      // Wallet not deducted
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('star_wallet'), 50);
    });

    test('purchaseHero fails for invalid hero id', () async {
      SharedPreferences.setMockInitialValues({'star_wallet': 100});
      final service = HeroService();
      final result = await service.purchaseHero('nonexistent');
      expect(result, false);
    });

    // ignore: deprecated_member_use_from_same_package
    test('deprecated unlockHero delegates to purchaseHero', () async {
      SharedPreferences.setMockInitialValues({
        'star_wallet': 20,
        'total_stars': 20,
      });
      final service = HeroService();
      // ignore: deprecated_member_use_from_same_package
      final result = await service.unlockHero('frost');
      expect(result, true);

      final unlocked = await service.getUnlockedHeroIds();
      expect(unlocked, contains('frost'));
    });

    // ── isHeroUnlocked ────────────────────────────────────────────

    test('isHeroUnlocked returns true for default hero', () async {
      final service = HeroService();
      final unlocked = await service.isHeroUnlocked('blaze');
      expect(unlocked, true);
    });

    test('isHeroUnlocked returns false for locked hero', () async {
      final service = HeroService();
      final unlocked = await service.isHeroUnlocked('nova');
      expect(unlocked, false);
    });

    test('isHeroUnlocked returns true after purchasing', () async {
      SharedPreferences.setMockInitialValues({
        'star_wallet': 20,
        'total_stars': 20,
      });
      final service = HeroService();
      await service.purchaseHero('frost');
      final unlocked = await service.isHeroUnlocked('frost');
      expect(unlocked, true);
    });

    // ── getNextLockedHero ─────────────────────────────────────────

    test('getNextLockedHero returns frost when only blaze is unlocked', () async {
      final service = HeroService();
      final next = await service.getNextLockedHero();
      expect(next, isNotNull);
      expect(next!.id, 'frost');
    });

    test('getNextLockedHero returns null when all heroes are unlocked', () async {
      final allIds = HeroService.allHeroes.map((h) => h.id).toList();
      SharedPreferences.setMockInitialValues({
        'unlocked_heroes': allIds,
      });
      final service = HeroService();
      final next = await service.getNextLockedHero();
      expect(next, isNull);
    });

    test('getNextLockedHero skips already-unlocked heroes', () async {
      SharedPreferences.setMockInitialValues({
        'unlocked_heroes': ['blaze', 'frost', 'bolt'],
      });
      final service = HeroService();
      final next = await service.getNextLockedHero();
      expect(next, isNotNull);
      expect(next!.id, 'shadow');
    });

    // ── Evolution gating ──────────────────────────────────────────

    group('evolution gating', () {
      test('cannot purchase stage 3 without owning stage 2', () async {
        SharedPreferences.setMockInitialValues({
          'unlocked_heroes': ['blaze'],
          'star_wallet': 100,
          'total_stars': 100,
        });
        final service = HeroService();
        final result = await service.purchaseEvolution('blaze_stage3');
        expect(result, false);
      });

      test('can purchase stage 3 after owning stage 2', () async {
        SharedPreferences.setMockInitialValues({
          'unlocked_heroes': ['blaze'],
          'unlocked_evolutions': ['blaze_stage2'],
          'star_wallet': 100,
          'total_stars': 100,
        });
        final service = HeroService();
        final result = await service.purchaseEvolution('blaze_stage3');
        expect(result, true);
      });

      test('stage 2 can be purchased without gating', () async {
        SharedPreferences.setMockInitialValues({
          'unlocked_heroes': ['blaze'],
          'star_wallet': 100,
          'total_stars': 100,
        });
        final service = HeroService();
        final result = await service.purchaseEvolution('blaze_stage2');
        expect(result, true);
      });
    });
  });
}
