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

    test('hero costs match expected progression (0/4/7/10/14/18)', () {
      final expectedCosts = [0, 4, 7, 10, 14, 18];
      for (int i = 0; i < HeroService.allHeroes.length; i++) {
        expect(HeroService.allHeroes[i].cost, expectedCosts[i],
            reason: 'Hero ${HeroService.allHeroes[i].id} should cost ${expectedCosts[i]}');
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

    test('default hero is blaze (cost 0)', () async {
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
      expect(hero.cost, 4);
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

    // ── Unlock logic ──────────────────────────────────────────────

    test('unlock succeeds when enough stars are available', () async {
      SharedPreferences.setMockInitialValues({'total_stars': 10});
      final service = HeroService();
      final result = await service.unlockHero('frost'); // costs 4
      expect(result, true);

      final unlocked = await service.getUnlockedHeroIds();
      expect(unlocked, contains('frost'));

      // Stars should be deducted
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('total_stars'), 6);
    });

    test('unlock fails when not enough stars', () async {
      SharedPreferences.setMockInitialValues({'total_stars': 3});
      final service = HeroService();
      final result = await service.unlockHero('frost'); // costs 4
      expect(result, false);

      final unlocked = await service.getUnlockedHeroIds();
      expect(unlocked, isNot(contains('frost')));

      // Stars should not be deducted
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('total_stars'), 3);
    });

    test('unlock with exact star balance succeeds', () async {
      SharedPreferences.setMockInitialValues({'total_stars': 4});
      final service = HeroService();
      final result = await service.unlockHero('frost'); // costs 4
      expect(result, true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('total_stars'), 0);
    });

    test('unlocking already-unlocked hero returns true and does not deduct stars', () async {
      SharedPreferences.setMockInitialValues({
        'total_stars': 10,
        'unlocked_heroes': ['blaze', 'frost'],
      });
      final service = HeroService();
      final result = await service.unlockHero('frost');
      expect(result, true);

      // Stars not deducted
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('total_stars'), 10);
    });

    test('unlock deducts correct amount for each hero', () async {
      // Unlock bolt (cost 7)
      SharedPreferences.setMockInitialValues({'total_stars': 50});
      final service = HeroService();
      await service.unlockHero('bolt');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('total_stars'), 43);
    });

    test('unlocking with invalid heroId returns blaze fallback (no deduction)', () async {
      // getHeroById('fake') returns blaze (id='blaze'), but hero.id != 'fake'
      // so the method returns false
      SharedPreferences.setMockInitialValues({'total_stars': 50});
      final service = HeroService();
      final result = await service.unlockHero('fake_hero_id');
      expect(result, false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('total_stars'), 50);
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

    test('isHeroUnlocked returns true after unlocking', () async {
      SharedPreferences.setMockInitialValues({'total_stars': 20});
      final service = HeroService();
      await service.unlockHero('frost');
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
  });
}
