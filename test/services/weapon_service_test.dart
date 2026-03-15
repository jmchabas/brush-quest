import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:brush_quest/services/weapon_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WeaponService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    // ── Weapon roster ─────────────────────────────────────────────

    test('allWeapons contains exactly 6 weapons', () {
      expect(WeaponService.allWeapons.length, 6);
    });

    test('weapon costs match expected progression (0/2/5/8/12/16)', () {
      final expectedCosts = [0, 2, 5, 8, 12, 16];
      for (int i = 0; i < WeaponService.allWeapons.length; i++) {
        expect(WeaponService.allWeapons[i].cost, expectedCosts[i],
            reason: 'Weapon ${WeaponService.allWeapons[i].id} should cost ${expectedCosts[i]}');
      }
    });

    test('all weapon IDs are unique', () {
      final ids = WeaponService.allWeapons.map((w) => w.id).toSet();
      expect(ids.length, WeaponService.allWeapons.length);
    });

    test('weapon IDs are star_blaster, flame_sword, ice_hammer, lightning_wand, vine_whip, cosmic_burst', () {
      final ids = WeaponService.allWeapons.map((w) => w.id).toList();
      expect(ids, [
        'star_blaster',
        'flame_sword',
        'ice_hammer',
        'lightning_wand',
        'vine_whip',
        'cosmic_burst',
      ]);
    });

    // ── Default state ─────────────────────────────────────────────

    test('default weapon is star_blaster (cost 0)', () async {
      final service = WeaponService();
      final selected = await service.getSelectedWeaponId();
      expect(selected, 'star_blaster');
    });

    test('star_blaster is unlocked by default', () async {
      final service = WeaponService();
      final unlocked = await service.getUnlockedWeaponIds();
      expect(unlocked, contains('star_blaster'));
    });

    test('only star_blaster is unlocked initially', () async {
      final service = WeaponService();
      final unlocked = await service.getUnlockedWeaponIds();
      expect(unlocked.length, 1);
      expect(unlocked[0], 'star_blaster');
    });

    // ── getWeaponById ─────────────────────────────────────────────

    test('getWeaponById returns correct weapon', () {
      final weapon = WeaponService.getWeaponById('flame_sword');
      expect(weapon.name, 'FLAME SWORD');
      expect(weapon.cost, 2);
    });

    test('getWeaponById returns star_blaster for unknown id', () {
      final weapon = WeaponService.getWeaponById('nonexistent');
      expect(weapon.id, 'star_blaster');
    });

    // ── getSelectedWeapon ─────────────────────────────────────────

    test('getSelectedWeapon returns WeaponItem object', () async {
      final service = WeaponService();
      final weapon = await service.getSelectedWeapon();
      expect(weapon.id, 'star_blaster');
      expect(weapon.name, 'STAR BLASTER');
    });

    // ── Weapon selection ──────────────────────────────────────────

    test('selectWeapon changes selected weapon', () async {
      final service = WeaponService();
      await service.selectWeapon('ice_hammer');
      final selected = await service.getSelectedWeaponId();
      expect(selected, 'ice_hammer');
    });

    test('selected weapon persists across service instances', () async {
      final service1 = WeaponService();
      await service1.selectWeapon('vine_whip');
      final service2 = WeaponService();
      final selected = await service2.getSelectedWeaponId();
      expect(selected, 'vine_whip');
    });

    // ── Unlock logic ──────────────────────────────────────────────

    test('unlock succeeds when enough stars are available', () async {
      SharedPreferences.setMockInitialValues({'total_stars': 10});
      final service = WeaponService();
      final result = await service.unlockWeapon('flame_sword'); // costs 2
      expect(result, true);

      final unlocked = await service.getUnlockedWeaponIds();
      expect(unlocked, contains('flame_sword'));

      // Stars should be deducted
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('total_stars'), 8);
    });

    test('unlock fails when not enough stars', () async {
      SharedPreferences.setMockInitialValues({'total_stars': 1});
      final service = WeaponService();
      final result = await service.unlockWeapon('flame_sword'); // costs 2
      expect(result, false);

      final unlocked = await service.getUnlockedWeaponIds();
      expect(unlocked, isNot(contains('flame_sword')));

      // Stars should not be deducted
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('total_stars'), 1);
    });

    test('unlock with exact star balance succeeds', () async {
      SharedPreferences.setMockInitialValues({'total_stars': 5});
      final service = WeaponService();
      final result = await service.unlockWeapon('ice_hammer'); // costs 5
      expect(result, true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('total_stars'), 0);
    });

    test('unlocking already-unlocked weapon returns true and does not deduct stars', () async {
      SharedPreferences.setMockInitialValues({
        'total_stars': 10,
        'unlocked_weapons': ['star_blaster', 'flame_sword'],
      });
      final service = WeaponService();
      final result = await service.unlockWeapon('flame_sword');
      expect(result, true);

      // Stars not deducted
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('total_stars'), 10);
    });

    test('unlock deducts correct amount for expensive weapon', () async {
      SharedPreferences.setMockInitialValues({'total_stars': 50});
      final service = WeaponService();
      await service.unlockWeapon('cosmic_burst'); // costs 16
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('total_stars'), 34);
    });

    test('unlocking with invalid weaponId returns false (no deduction)', () async {
      SharedPreferences.setMockInitialValues({'total_stars': 50});
      final service = WeaponService();
      final result = await service.unlockWeapon('fake_weapon_id');
      expect(result, false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('total_stars'), 50);
    });

    // ── isWeaponUnlocked ──────────────────────────────────────────

    test('isWeaponUnlocked returns true for default weapon', () async {
      final service = WeaponService();
      final unlocked = await service.isWeaponUnlocked('star_blaster');
      expect(unlocked, true);
    });

    test('isWeaponUnlocked returns false for locked weapon', () async {
      final service = WeaponService();
      final unlocked = await service.isWeaponUnlocked('cosmic_burst');
      expect(unlocked, false);
    });

    test('isWeaponUnlocked returns true after unlocking', () async {
      SharedPreferences.setMockInitialValues({'total_stars': 20});
      final service = WeaponService();
      await service.unlockWeapon('flame_sword');
      final unlocked = await service.isWeaponUnlocked('flame_sword');
      expect(unlocked, true);
    });

    // ── Multiple unlocks ──────────────────────────────────────────

    test('unlocking multiple weapons deducts stars cumulatively', () async {
      SharedPreferences.setMockInitialValues({'total_stars': 50});
      final service = WeaponService();

      await service.unlockWeapon('flame_sword'); // -2 = 48
      await service.unlockWeapon('ice_hammer'); // -5 = 43
      await service.unlockWeapon('lightning_wand'); // -8 = 35

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('total_stars'), 35);

      final unlocked = await service.getUnlockedWeaponIds();
      expect(unlocked, containsAll(['star_blaster', 'flame_sword', 'ice_hammer', 'lightning_wand']));
    });

    // ── Each weapon has a unique effect type ──────────────────────

    test('each weapon has a unique effect type', () {
      final effects = WeaponService.allWeapons.map((w) => w.effectType).toSet();
      expect(effects.length, WeaponService.allWeapons.length);
    });
  });
}
