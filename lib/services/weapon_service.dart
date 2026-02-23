import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final int cost;
  final AttackEffectType effectType;
  final Color primaryColor;
  final Color secondaryColor;
  final IconData icon;

  const WeaponItem({
    required this.id,
    required this.name,
    required this.description,
    required this.cost,
    required this.effectType,
    required this.primaryColor,
    required this.secondaryColor,
    required this.icon,
  });
}

class WeaponService {
  static const _unlockedKey = 'unlocked_weapons';
  static const _selectedKey = 'selected_weapon';

  static const List<WeaponItem> allWeapons = [
    WeaponItem(
      id: 'star_blaster',
      name: 'STAR BLASTER',
      description: 'The classic beam weapon. Reliable and strong!',
      cost: 0,
      effectType: AttackEffectType.defaultBeam,
      primaryColor: Color(0xFF7C4DFF),
      secondaryColor: Color(0xFFB388FF),
      icon: Icons.flash_on,
    ),
    WeaponItem(
      id: 'flame_sword',
      name: 'FLAME SWORD',
      description: 'Fiery slashes that burn through cavity monsters!',
      cost: 2,
      effectType: AttackEffectType.flameSword,
      primaryColor: Color(0xFFFF6D00),
      secondaryColor: Color(0xFFFFAB40),
      icon: Icons.local_fire_department,
    ),
    WeaponItem(
      id: 'ice_hammer',
      name: 'ICE HAMMER',
      description: 'Freezing shockwaves that shatter monsters!',
      cost: 5,
      effectType: AttackEffectType.iceHammer,
      primaryColor: Color(0xFF40C4FF),
      secondaryColor: Color(0xFF80D8FF),
      icon: Icons.ac_unit,
    ),
    WeaponItem(
      id: 'lightning_wand',
      name: 'LIGHTNING WAND',
      description: 'Electric bolts that zap monsters from afar!',
      cost: 8,
      effectType: AttackEffectType.lightningWand,
      primaryColor: Color(0xFFFFD600),
      secondaryColor: Color(0xFFFFFF00),
      icon: Icons.bolt,
    ),
    WeaponItem(
      id: 'vine_whip',
      name: 'VINE WHIP',
      description: 'Nature strikes that tangle and crush!',
      cost: 12,
      effectType: AttackEffectType.vineWhip,
      primaryColor: Color(0xFF00E676),
      secondaryColor: Color(0xFF69F0AE),
      icon: Icons.eco,
    ),
    WeaponItem(
      id: 'cosmic_burst',
      name: 'COSMIC BURST',
      description: 'The ultimate weapon! Rainbow star explosions!',
      cost: 16,
      effectType: AttackEffectType.cosmicBurst,
      primaryColor: Color(0xFFFF4081),
      secondaryColor: Color(0xFFFFD54F),
      icon: Icons.auto_awesome,
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

  Future<bool> unlockWeapon(String weaponId) async {
    final weapon = getWeaponById(weaponId);
    final prefs = await SharedPreferences.getInstance();

    final unlocked = prefs.getStringList(_unlockedKey) ?? ['star_blaster'];
    if (unlocked.contains(weaponId)) return true;

    final stars = prefs.getInt('total_stars') ?? 0;
    if (stars < weapon.cost) return false;

    await prefs.setInt('total_stars', stars - weapon.cost);
    unlocked.add(weaponId);
    await prefs.setStringList(_unlockedKey, unlocked);
    return true;
  }

  Future<bool> isWeaponUnlocked(String weaponId) async {
    final unlocked = await getUnlockedWeaponIds();
    return unlocked.contains(weaponId);
  }

  static WeaponItem getWeaponById(String id) {
    return allWeapons.firstWhere((w) => w.id == id, orElse: () => allWeapons[0]);
  }
}
