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

    test('weapon prices match expected values (0/5/14/18/22/25)', () {
      final expectedPrices = [0, 5, 14, 18, 22, 25];
      for (int i = 0; i < WeaponService.allWeapons.length; i++) {
        expect(
          WeaponService.allWeapons[i].price,
          expectedPrices[i],
          reason:
              'Weapon ${WeaponService.allWeapons[i].id} should cost ${expectedPrices[i]}',
        );
      }
    });

    test('all weapon IDs are unique', () {
      final ids = WeaponService.allWeapons.map((w) => w.id).toSet();
      expect(ids.length, WeaponService.allWeapons.length);
    });

    test(
      'weapon IDs are star_blaster, flame_sword, ice_hammer, lightning_wand, vine_whip, cosmic_burst',
      () {
        final ids = WeaponService.allWeapons.map((w) => w.id).toList();
        expect(ids, [
          'star_blaster',
          'flame_sword',
          'ice_hammer',
          'lightning_wand',
          'vine_whip',
          'cosmic_burst',
        ]);
      },
    );

    // ── Default state ─────────────────────────────────────────────

    test('default weapon is star_blaster (price 0)', () async {
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
      expect(weapon.price, 5);
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

    // ── Purchase logic ──────────────────────────────────────────

    test('purchaseWeapon succeeds when wallet has enough stars', () async {
      SharedPreferences.setMockInitialValues({
        'star_wallet': 15,
        'total_stars': 15,
      });
      final service = WeaponService();
      final result = await service.purchaseWeapon('flame_sword'); // price 5
      expect(result, true);

      final unlocked = await service.getUnlockedWeaponIds();
      expect(unlocked, contains('flame_sword'));

      // Stars deducted from wallet
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('star_wallet'), 10); // 15 - 5
      expect(prefs.getInt('total_stars'), 15); // Rank unchanged
    });

    test('purchaseWeapon fails when wallet has insufficient stars', () async {
      SharedPreferences.setMockInitialValues({
        'star_wallet': 4,
        'total_stars': 50,
      });
      final service = WeaponService();
      final result = await service.purchaseWeapon('flame_sword'); // price 5
      expect(result, false);

      final unlocked = await service.getUnlockedWeaponIds();
      expect(unlocked, isNot(contains('flame_sword')));

      // Wallet unchanged
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('star_wallet'), 4);
    });

    test(
      'purchaseWeapon succeeds without deducting if already owned',
      () async {
        SharedPreferences.setMockInitialValues({
          'star_wallet': 50,
          'total_stars': 50,
          'unlocked_weapons': ['star_blaster', 'flame_sword'],
        });
        final service = WeaponService();
        final result = await service.purchaseWeapon('flame_sword');
        expect(result, true);

        // Wallet not deducted
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt('star_wallet'), 50);
      },
    );

    test('purchaseWeapon fails for invalid weapon id', () async {
      SharedPreferences.setMockInitialValues({'star_wallet': 100});
      final service = WeaponService();
      final result = await service.purchaseWeapon('fake_weapon_id');
      expect(result, false);
    });

    // ignore: deprecated_member_use_from_same_package
    test('deprecated unlockWeapon delegates to purchaseWeapon', () async {
      SharedPreferences.setMockInitialValues({
        'star_wallet': 15,
        'total_stars': 15,
      });
      final service = WeaponService();
      // ignore: deprecated_member_use_from_same_package
      final result = await service.unlockWeapon('flame_sword');
      expect(result, true);

      final unlocked = await service.getUnlockedWeaponIds();
      expect(unlocked, contains('flame_sword'));
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

    test('isWeaponUnlocked returns true after purchasing', () async {
      SharedPreferences.setMockInitialValues({
        'star_wallet': 15,
        'total_stars': 15,
      });
      final service = WeaponService();
      await service.purchaseWeapon('flame_sword');
      final unlocked = await service.isWeaponUnlocked('flame_sword');
      expect(unlocked, true);
    });

    // ── Multiple purchases ──────────────────────────────────────

    test('purchasing multiple weapons deducts stars correctly', () async {
      SharedPreferences.setMockInitialValues({
        'star_wallet': 50,
        'total_stars': 50,
      });
      final service = WeaponService();

      await service.purchaseWeapon('flame_sword'); // price 5
      await service.purchaseWeapon('ice_hammer'); // price 14
      await service.purchaseWeapon('lightning_wand'); // price 18

      // Wallet: 50 - 5 - 14 - 18 = 13
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('star_wallet'), 13);

      final unlocked = await service.getUnlockedWeaponIds();
      expect(
        unlocked,
        containsAll([
          'star_blaster',
          'flame_sword',
          'ice_hammer',
          'lightning_wand',
        ]),
      );
    });

    // ── getNextLockedWeapon ─────────────────────────────────────

    test(
      'getNextLockedWeapon returns flame_sword when only star_blaster is unlocked',
      () async {
        final service = WeaponService();
        final next = await service.getNextLockedWeapon();
        expect(next, isNotNull);
        expect(next!.id, 'flame_sword');
      },
    );

    test(
      'getNextLockedWeapon returns null when all weapons are unlocked',
      () async {
        final allIds = WeaponService.allWeapons.map((w) => w.id).toList();
        SharedPreferences.setMockInitialValues({'unlocked_weapons': allIds});
        final service = WeaponService();
        final next = await service.getNextLockedWeapon();
        expect(next, isNull);
      },
    );

    test('getNextLockedWeapon skips already-unlocked weapons', () async {
      SharedPreferences.setMockInitialValues({
        'unlocked_weapons': ['star_blaster', 'flame_sword', 'ice_hammer'],
      });
      final service = WeaponService();
      final next = await service.getNextLockedWeapon();
      expect(next, isNotNull);
      expect(next!.id, 'lightning_wand');
    });

    // ── Each weapon has a unique effect type ──────────────────────

    test('each weapon has a unique effect type', () {
      final effects = WeaponService.allWeapons.map((w) => w.effectType).toSet();
      expect(effects.length, WeaponService.allWeapons.length);
    });
  });
}
