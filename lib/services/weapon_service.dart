import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'streak_service.dart';

enum AttackEffectType {
  defaultBeam,
  flameSword,
  iceHammer,
  lightningWand,
  vineWhip,
  cosmicBurst,
}

class WeaponItem {
  final String id;
  final String name;
  final String description;
  final int price;
  final AttackEffectType effectType;
  final Color primaryColor;
  final Color secondaryColor;
  final IconData icon;
  final String imagePath;

  const WeaponItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.effectType,
    required this.primaryColor,
    required this.secondaryColor,
    required this.icon,
    required this.imagePath,
  });
}

class WeaponService {
  static const _unlockedKey = 'unlocked_weapons';
  static const _selectedKey = 'selected_weapon';

  // Star prices — deducted from wallet on purchase.
  static const List<WeaponItem> allWeapons = [
    WeaponItem(
      id: 'star_blaster',
      name: 'STAR BLASTER',
      description: 'The classic beam weapon. Reliable and strong!',
      price: 0,
      effectType: AttackEffectType.defaultBeam,
      primaryColor: Color(0xFF7C4DFF),
      secondaryColor: Color(0xFFB388FF),
      icon: Icons.flash_on,
      imagePath: 'assets/images/weapon_star_blaster.png',
    ),
    WeaponItem(
      id: 'flame_sword',
      name: 'FLAME SWORD',
      description: 'Fiery slashes that burn through cavity monsters!',
      price: 5,
      effectType: AttackEffectType.flameSword,
      primaryColor: Color(0xFFFF6D00),
      secondaryColor: Color(0xFFFFAB40),
      icon: Icons.local_fire_department,
      imagePath: 'assets/images/weapon_flame_sword.png',
    ),
    WeaponItem(
      id: 'ice_hammer',
      name: 'ICE HAMMER',
      description: 'Freezing shockwaves that shatter monsters!',
      price: 14,
      effectType: AttackEffectType.iceHammer,
      primaryColor: Color(0xFF40C4FF),
      secondaryColor: Color(0xFF80D8FF),
      icon: Icons.ac_unit,
      imagePath: 'assets/images/weapon_ice_hammer.png',
    ),
    WeaponItem(
      id: 'lightning_wand',
      name: 'LIGHTNING WAND',
      description: 'Electric bolts that zap monsters from afar!',
      price: 18,
      effectType: AttackEffectType.lightningWand,
      primaryColor: Color(0xFFFFD600),
      secondaryColor: Color(0xFFFFFF00),
      icon: Icons.bolt,
      imagePath: 'assets/images/weapon_lightning_wand.png',
    ),
    WeaponItem(
      id: 'vine_whip',
      name: 'VINE WHIP',
      description: 'Nature strikes that tangle and crush!',
      price: 22,
      effectType: AttackEffectType.vineWhip,
      primaryColor: Color(0xFF00E676),
      secondaryColor: Color(0xFF69F0AE),
      icon: Icons.eco,
      imagePath: 'assets/images/weapon_vine_whip.png',
    ),
    WeaponItem(
      id: 'cosmic_burst',
      name: 'COSMIC BURST',
      description: 'The ultimate weapon! Rainbow star explosions!',
      price: 25,
      effectType: AttackEffectType.cosmicBurst,
      primaryColor: Color(0xFFFF4081),
      secondaryColor: Color(0xFFFFD54F),
      icon: Icons.auto_awesome,
      imagePath: 'assets/images/weapon_cosmic_burst.png',
    ),
  ];

  Future<List<String>> getUnlockedWeaponIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_unlockedKey) ?? ['star_blaster'];
  }

  Future<String> getSelectedWeaponId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedKey) ?? 'star_blaster';
  }

  Future<WeaponItem> getSelectedWeapon() async {
    final id = await getSelectedWeaponId();
    return getWeaponById(id);
  }

  Future<void> selectWeapon(String weaponId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedKey, weaponId);
  }

  /// Purchase a weapon by spending stars from the wallet.
  /// Returns true if purchase succeeds or weapon already owned.
  /// Returns false if insufficient stars or invalid weapon ID.
  ///
  /// Writes the unlock list first (idempotent), then deducts the wallet.
  /// A crash between the two writes grants the weapon without spending stars
  /// (recoverable), rather than spending stars without granting (lost).
  Future<bool> purchaseWeapon(String weaponId) async {
    if (StreakService.isPurchasing) return false;
    StreakService.isPurchasing = true;
    try {
      final weapon = getWeaponById(weaponId);
      if (weapon.id != weaponId) return false; // Invalid ID
      final prefs = await SharedPreferences.getInstance();

      final unlocked = prefs.getStringList(_unlockedKey) ?? ['star_blaster'];
      if (unlocked.contains(weaponId)) return true; // Already owned

      if (weapon.price == 0) {
        unlocked.add(weaponId);
        await prefs.setStringList(_unlockedKey, unlocked);
        return true;
      }

      final wallet = prefs.getInt('star_wallet') ?? 0;
      if (wallet < weapon.price) return false;

      // Write unlock first (idempotent), then deduct wallet.
      // A crash after unlock but before deduction is safe (item granted,
      // stars not spent). The reverse would lose stars without granting.
      await prefs.setStringList(_unlockedKey, [...unlocked, weaponId]);
      await prefs.setInt('star_wallet', wallet - weapon.price);
      return true;
    } finally {
      StreakService.isPurchasing = false;
    }
  }

  @Deprecated('Use purchaseWeapon instead')
  Future<bool> unlockWeapon(String weaponId) => purchaseWeapon(weaponId);

  Future<bool> isWeaponUnlocked(String weaponId) async {
    final unlocked = await getUnlockedWeaponIds();
    return unlocked.contains(weaponId);
  }

  Future<WeaponItem?> getNextLockedWeapon() async {
    final unlocked = await getUnlockedWeaponIds();
    for (final weapon in allWeapons) {
      if (!unlocked.contains(weapon.id)) return weapon;
    }
    return null;
  }

  static WeaponItem getWeaponById(String id) {
    return allWeapons.firstWhere(
      (w) => w.id == id,
      orElse: () => allWeapons[0],
    );
  }
}
