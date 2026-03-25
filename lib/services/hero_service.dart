import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'streak_service.dart';

class HeroCharacter {
  final String id;
  final String name;
  final String title;
  final String description;
  final int price;
  final String imagePath;
  final Color primaryColor;
  final Color attackColor;

  const HeroCharacter({
    required this.id,
    required this.name,
    required this.title,
    required this.description,
    required this.price,
    required this.imagePath,
    required this.primaryColor,
    required this.attackColor,
  });
}

class HeroSkin {
  final String id;
  final String heroId;
  final String name;
  final String description;
  final int price;
  final Color primaryColor;
  final Color attackColor;
  final Color tintColor;
  final double tintStrength;

  const HeroSkin({
    required this.id,
    required this.heroId,
    required this.name,
    required this.description,
    required this.price,
    required this.primaryColor,
    required this.attackColor,
    required this.tintColor,
    required this.tintStrength,
  });
}

class HeroService {
  static const _unlockedKey = 'unlocked_heroes';
  static const _selectedKey = 'selected_hero';
  static const _unlockedSkinsKey = 'unlocked_skins';
  static const _equippedSkinPrefix = 'equipped_skin_';
  static bool _purchasing = false;

  // Star prices — deducted from wallet on purchase.
  // Interleaved with weapons for a new unlock every 3-5 days at 2x/day.
  static const List<HeroCharacter> allHeroes = [
    HeroCharacter(
      id: 'blaze',
      name: 'BLAZE',
      title: 'Fire Dragon',
      description: 'A fierce little dragon who burns cavity monsters with blazing fire breath!',
      price: 0,
      imagePath: 'assets/images/hero_blaze.png',
      primaryColor: Color(0xFFFF6D00),
      attackColor: Color(0xFFFF9100),
    ),
    HeroCharacter(
      id: 'frost',
      name: 'FROST',
      title: 'Ice Wolf',
      description: 'A brave wolf knight who freezes monsters solid with icy howls!',
      price: 15,
      imagePath: 'assets/images/hero_frost.png',
      primaryColor: Color(0xFF40C4FF),
      attackColor: Color(0xFF80D8FF),
    ),
    HeroCharacter(
      id: 'bolt',
      name: 'BOLT',
      title: 'Lightning Robot',
      description: 'A super-charged robot who zaps monsters with electric bolts!',
      price: 20,
      imagePath: 'assets/images/hero_bolt.png',
      primaryColor: Color(0xFFFFD600),
      attackColor: Color(0xFFFFFF00),
    ),
    HeroCharacter(
      id: 'shadow',
      name: 'SHADOW',
      title: 'Ninja Cat',
      description: 'A sneaky ninja cat who strikes from the shadows with dark energy!',
      price: 30,
      imagePath: 'assets/images/hero_shadow.png',
      primaryColor: Color(0xFFAA00FF),
      attackColor: Color(0xFFD500F9),
    ),
    HeroCharacter(
      id: 'leaf',
      name: 'LEAF',
      title: 'Nature Guardian',
      description: 'A mighty tree guardian who smashes monsters with vine whip attacks!',
      price: 35,
      imagePath: 'assets/images/hero_leaf.png',
      primaryColor: Color(0xFF00E676),
      attackColor: Color(0xFF69F0AE),
    ),
    HeroCharacter(
      id: 'nova',
      name: 'NOVA',
      title: 'Cosmic Phoenix',
      description: 'The legendary phoenix who unleashes cosmic star bursts of pure light!',
      price: 40,
      imagePath: 'assets/images/hero_nova.png',
      primaryColor: Color(0xFFFFD54F),
      attackColor: Color(0xFFFFE082),
    ),
  ];

  Future<List<String>> getUnlockedHeroIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_unlockedKey) ?? ['blaze'];
  }

  Future<String> getSelectedHeroId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedKey) ?? 'blaze';
  }

  Future<HeroCharacter> getSelectedHero() async {
    final id = await getSelectedHeroId();
    return getHeroById(id);
  }

  Future<void> selectHero(String heroId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedKey, heroId);
  }

  /// Purchase a hero by spending stars from the wallet.
  /// Returns true if purchase succeeds or hero already owned.
  /// Returns false if insufficient stars or invalid hero ID.
  Future<bool> purchaseHero(String heroId) async {
    if (_purchasing) return false;
    _purchasing = true;
    try {
      final hero = getHeroById(heroId);
      if (hero.id != heroId) return false;
      final prefs = await SharedPreferences.getInstance();

      final unlocked = prefs.getStringList(_unlockedKey) ?? ['blaze'];
      if (unlocked.contains(heroId)) return true; // Already owned

      if (hero.price == 0) {
        unlocked.add(heroId);
        await prefs.setStringList(_unlockedKey, unlocked);
        return true;
      }

      // Deduct from wallet
      final success = await StreakService().spendStars(hero.price);
      if (!success) return false;

      unlocked.add(heroId);
      await prefs.setStringList(_unlockedKey, unlocked);
      return true;
    } finally {
      _purchasing = false;
    }
  }

  @Deprecated('Use purchaseHero instead')
  Future<bool> unlockHero(String heroId) => purchaseHero(heroId);

  Future<bool> isHeroUnlocked(String heroId) async {
    final unlocked = await getUnlockedHeroIds();
    return unlocked.contains(heroId);
  }

  static HeroCharacter getHeroById(String id) {
    return allHeroes.firstWhere((h) => h.id == id, orElse: () => allHeroes[0]);
  }

  Future<HeroCharacter?> getNextLockedHero() async {
    final unlocked = await getUnlockedHeroIds();
    for (final hero in allHeroes) {
      if (!unlocked.contains(hero.id)) {
        return hero;
      }
    }
    return null; // All heroes unlocked
  }

  // ---------------------------------------------------------------------------
  // Hero Skins
  // ---------------------------------------------------------------------------

  static const List<HeroSkin> allSkins = [
    // Blaze skins (base: orange)
    HeroSkin(id: 'blaze_ice', heroId: 'blaze', name: 'Ice Blaze',
      description: 'Freezes monsters in their tracks!',
      price: 25,
      primaryColor: Color(0xFF40C4FF), attackColor: Color(0xFF80D8FF),
      tintColor: Color(0xFF40C4FF), tintStrength: 0.45),
    HeroSkin(id: 'blaze_gold', heroId: 'blaze', name: 'Golden Blaze',
      description: 'Legendary golden armor — monsters flee in fear!',
      price: 35,
      primaryColor: Color(0xFFFFD700), attackColor: Color(0xFFFFE082),
      tintColor: Color(0xFFFFD700), tintStrength: 0.4),
    HeroSkin(id: 'blaze_shadow', heroId: 'blaze', name: 'Dark Blaze',
      description: 'Shadow stealth mode — sneak attack bonus!',
      price: 45,
      primaryColor: Color(0xFF7C4DFF), attackColor: Color(0xFFB388FF),
      tintColor: Color(0xFF4A148C), tintStrength: 0.5),

    // Frost skins (base: blue)
    HeroSkin(id: 'frost_fire', heroId: 'frost', name: 'Fire Frost',
      description: 'Blazing hot and ice cold at the same time!',
      price: 25,
      primaryColor: Color(0xFFFF6D00), attackColor: Color(0xFFFF9100),
      tintColor: Color(0xFFFF6D00), tintStrength: 0.45),
    HeroSkin(id: 'frost_crystal', heroId: 'frost', name: 'Crystal Frost',
      description: 'Crystal armor reflects monster attacks right back!',
      price: 35,
      primaryColor: Color(0xFF00E5FF), attackColor: Color(0xFFE0F7FA),
      tintColor: Color(0xFF00BCD4), tintStrength: 0.35),
    HeroSkin(id: 'frost_emerald', heroId: 'frost', name: 'Emerald Frost',
      description: 'Ancient emerald power — nature and ice combined!',
      price: 45,
      primaryColor: Color(0xFF00E676), attackColor: Color(0xFF69F0AE),
      tintColor: Color(0xFF2E7D32), tintStrength: 0.45),

    // Bolt skins (base: yellow)
    HeroSkin(id: 'bolt_plasma', heroId: 'bolt', name: 'Plasma Bolt',
      description: 'Supercharged plasma — double the zap power!',
      price: 25,
      primaryColor: Color(0xFFFF4081), attackColor: Color(0xFFFF80AB),
      tintColor: Color(0xFFE91E63), tintStrength: 0.45),
    HeroSkin(id: 'bolt_copper', heroId: 'bolt', name: 'Copper Bolt',
      description: 'Ancient copper circuits never miss a shot!',
      price: 35,
      primaryColor: Color(0xFFBF8040), attackColor: Color(0xFFD4A574),
      tintColor: Color(0xFF8D6E63), tintStrength: 0.45),
    HeroSkin(id: 'bolt_neon', heroId: 'bolt', name: 'Neon Bolt',
      description: 'Glowing neon blasts blind monsters on impact!',
      price: 45,
      primaryColor: Color(0xFF76FF03), attackColor: Color(0xFFB2FF59),
      tintColor: Color(0xFF64DD17), tintStrength: 0.45),

    // Shadow skins (base: purple)
    HeroSkin(id: 'shadow_crimson', heroId: 'shadow', name: 'Crimson Shadow',
      description: 'Crimson fury — strikes twice as fast!',
      price: 30,
      primaryColor: Color(0xFFFF1744), attackColor: Color(0xFFFF5252),
      tintColor: Color(0xFFD50000), tintStrength: 0.45),
    HeroSkin(id: 'shadow_phantom', heroId: 'shadow', name: 'Phantom Shadow',
      description: 'Ghost form — monsters can\'t even see the attacks coming!',
      price: 40,
      primaryColor: Color(0xFFBDBDBD), attackColor: Color(0xFFE0E0E0),
      tintColor: Color(0xFF9E9E9E), tintStrength: 0.4),
    HeroSkin(id: 'shadow_void', heroId: 'shadow', name: 'Void Shadow',
      description: 'Void energy — the most powerful darkness in the galaxy!',
      price: 50,
      primaryColor: Color(0xFF1A237E), attackColor: Color(0xFF3949AB),
      tintColor: Color(0xFF0D1B3E), tintStrength: 0.5),

    // Leaf skins (base: green)
    HeroSkin(id: 'leaf_autumn', heroId: 'leaf', name: 'Autumn Leaf',
      description: 'Autumn storm — rains leaves on every monster!',
      price: 30,
      primaryColor: Color(0xFFFF8F00), attackColor: Color(0xFFFFB74D),
      tintColor: Color(0xFFE65100), tintStrength: 0.45),
    HeroSkin(id: 'leaf_blossom', heroId: 'leaf', name: 'Blossom Leaf',
      description: 'Cherry blossom power — beautiful and unstoppable!',
      price: 40,
      primaryColor: Color(0xFFFF80AB), attackColor: Color(0xFFF48FB1),
      tintColor: Color(0xFFEC407A), tintStrength: 0.4),
    HeroSkin(id: 'leaf_frost', heroId: 'leaf', name: 'Frosted Leaf',
      description: 'Winter guardian — freezing vines trap every enemy!',
      price: 50,
      primaryColor: Color(0xFF81D4FA), attackColor: Color(0xFFB3E5FC),
      tintColor: Color(0xFF4FC3F7), tintStrength: 0.45),

    // Nova skins (base: gold)
    HeroSkin(id: 'nova_nebula', heroId: 'nova', name: 'Nebula Nova',
      description: 'Born from a nebula — cosmic energy at maximum!',
      price: 30,
      primaryColor: Color(0xFF7B1FA2), attackColor: Color(0xFFCE93D8),
      tintColor: Color(0xFF6A1B9A), tintStrength: 0.45),
    HeroSkin(id: 'nova_solar', heroId: 'nova', name: 'Solar Nova',
      description: 'Powered by a star — unleashes solar flares on monsters!',
      price: 40,
      primaryColor: Color(0xFFFF3D00), attackColor: Color(0xFFFF6E40),
      tintColor: Color(0xFFDD2C00), tintStrength: 0.4),
    HeroSkin(id: 'nova_prism', heroId: 'nova', name: 'Prism Nova',
      description: 'Rainbow prism — splits light into unstoppable laser beams!',
      price: 50,
      primaryColor: Color(0xFF00BFA5), attackColor: Color(0xFF64FFDA),
      tintColor: Color(0xFF00897B), tintStrength: 0.4),
  ];

  static List<HeroSkin> skinsForHero(String heroId) {
    return allSkins.where((s) => s.heroId == heroId).toList();
  }

  static HeroSkin? getSkinById(String? id) {
    if (id == null) return null;
    try {
      return allSkins.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> getUnlockedSkinIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_unlockedSkinsKey) ?? [];
  }

  Future<bool> isSkinUnlocked(String skinId) async {
    final unlocked = await getUnlockedSkinIds();
    return unlocked.contains(skinId);
  }

  Future<bool> purchaseSkin(String skinId) async {
    if (_purchasing) return false;
    _purchasing = true;
    try {
      final skin = getSkinById(skinId);
      if (skin == null) return false;

      final prefs = await SharedPreferences.getInstance();
      final unlocked = prefs.getStringList(_unlockedSkinsKey) ?? [];
      if (unlocked.contains(skinId)) return true;

      final success = await StreakService().spendStars(skin.price);
      if (!success) return false;

      unlocked.add(skinId);
      await prefs.setStringList(_unlockedSkinsKey, unlocked);
      return true;
    } finally {
      _purchasing = false;
    }
  }

  Future<String?> getEquippedSkinId(String heroId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_equippedSkinPrefix$heroId');
  }

  Future<void> equipSkin(String heroId, String? skinId) async {
    final prefs = await SharedPreferences.getInstance();
    if (skinId == null) {
      await prefs.remove('$_equippedSkinPrefix$heroId');
    } else {
      await prefs.setString('$_equippedSkinPrefix$heroId', skinId);
    }
  }

  /// Build a hero image widget with optional skin tint overlay.
  static Widget buildHeroImage(String heroId, {String? skinId, double size = 120}) {
    final hero = getHeroById(heroId);
    final skin = getSkinById(skinId);

    Widget image = Image.asset(hero.imagePath, width: size, height: size, fit: BoxFit.contain);

    if (skin != null) {
      image = ColorFiltered(
        colorFilter: ColorFilter.mode(
          skin.tintColor.withValues(alpha: skin.tintStrength),
          BlendMode.color,
        ),
        child: image,
      );
    }

    return image;
  }
}
