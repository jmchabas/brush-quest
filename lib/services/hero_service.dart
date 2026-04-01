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

class HeroEvolution {
  final String id;          // e.g., 'blaze_stage2'
  final String heroId;      // 'blaze'
  final int stage;          // 1, 2, or 3
  final String name;        // 'FLAME KNIGHT'
  final String description; // flavor text
  final int price;          // 0 (base comes free), 15-18 (stage 2), 25 (stage 3)
  final Color primaryColor;
  final Color attackColor;

  const HeroEvolution({
    required this.id,
    required this.heroId,
    required this.stage,
    required this.name,
    required this.description,
    required this.price,
    required this.primaryColor,
    required this.attackColor,
  });
}

class HeroService {
  static const _unlockedKey = 'unlocked_heroes';
  static const _selectedKey = 'selected_hero';
  static const _unlockedEvolutionsKey = 'unlocked_evolutions';
  static const _evolutionStagePrefix = 'evolution_stage_';
  static bool _purchasing = false;

  // Star prices — deducted from wallet on purchase.
  // Dense price ladder: a new unlock every 1-3 days at 2x/day.
  // Prevents "poverty trap" where cheap items are exhausted and only
  // expensive ones remain, leaving the child with nothing achievable.
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
      price: 8,
      imagePath: 'assets/images/hero_frost.png',
      primaryColor: Color(0xFF40C4FF),
      attackColor: Color(0xFF80D8FF),
    ),
    HeroCharacter(
      id: 'bolt',
      name: 'BOLT',
      title: 'Lightning Robot',
      description: 'A super-charged robot who zaps monsters with electric bolts!',
      price: 18,
      imagePath: 'assets/images/hero_bolt.png',
      primaryColor: Color(0xFFFFD600),
      attackColor: Color(0xFFFFFF00),
    ),
    HeroCharacter(
      id: 'shadow',
      name: 'SHADOW',
      title: 'Ninja Cat',
      description: 'A sneaky ninja cat who strikes from the shadows with dark energy!',
      price: 25,
      imagePath: 'assets/images/hero_shadow.png',
      primaryColor: Color(0xFFAA00FF),
      attackColor: Color(0xFFD500F9),
    ),
    HeroCharacter(
      id: 'leaf',
      name: 'LEAF',
      title: 'Nature Guardian',
      description: 'A mighty tree guardian who smashes monsters with vine whip attacks!',
      price: 33,
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
  // Hero Evolutions (replaces old tint-based skins)
  // ---------------------------------------------------------------------------

  static const List<HeroEvolution> allEvolutions = [
    // Blaze evolutions (base: orange)
    HeroEvolution(id: 'blaze_stage1', heroId: 'blaze', stage: 1,
      name: 'BLAZE',
      description: 'A fierce little dragon who burns cavity monsters!',
      price: 0,
      primaryColor: Color(0xFFFF6D00), attackColor: Color(0xFFFF9100)),
    HeroEvolution(id: 'blaze_stage2', heroId: 'blaze', stage: 2,
      name: 'FLAME KNIGHT',
      description: 'Upgraded fire armor with glowing flame patterns!',
      price: 15,
      primaryColor: Color(0xFFFF6D00), attackColor: Color(0xFFFF9100)),
    HeroEvolution(id: 'blaze_stage3', heroId: 'blaze', stage: 3,
      name: 'INFERNO LORD',
      description: 'Legendary fire armor — monsters flee in terror!',
      price: 25,
      primaryColor: Color(0xFFFF6D00), attackColor: Color(0xFFFF9100)),

    // Frost evolutions (base: blue)
    HeroEvolution(id: 'frost_stage1', heroId: 'frost', stage: 1,
      name: 'FROST',
      description: 'A brave wolf knight who freezes monsters solid with icy howls!',
      price: 0,
      primaryColor: Color(0xFF40C4FF), attackColor: Color(0xFF80D8FF)),
    HeroEvolution(id: 'frost_stage2', heroId: 'frost', stage: 2,
      name: 'CRYSTAL KNIGHT',
      description: 'Crystalline armor with frost breath power!',
      price: 15,
      primaryColor: Color(0xFF40C4FF), attackColor: Color(0xFF80D8FF)),
    HeroEvolution(id: 'frost_stage3', heroId: 'frost', stage: 3,
      name: 'BLIZZARD LORD',
      description: 'Ultimate ice armor — freezes everything!',
      price: 25,
      primaryColor: Color(0xFF40C4FF), attackColor: Color(0xFF80D8FF)),

    // Bolt evolutions (base: yellow)
    HeroEvolution(id: 'bolt_stage1', heroId: 'bolt', stage: 1,
      name: 'BOLT',
      description: 'A super-charged robot who zaps monsters with electric bolts!',
      price: 0,
      primaryColor: Color(0xFFFFD600), attackColor: Color(0xFFFFFF00)),
    HeroEvolution(id: 'bolt_stage2', heroId: 'bolt', stage: 2,
      name: 'THUNDER KNIGHT',
      description: 'Electric coils and crackling lightning power!',
      price: 15,
      primaryColor: Color(0xFFFFD600), attackColor: Color(0xFFFFFF00)),
    HeroEvolution(id: 'bolt_stage3', heroId: 'bolt', stage: 3,
      name: 'STORM LORD',
      description: 'Tesla-powered armor — lightning strikes all!',
      price: 25,
      primaryColor: Color(0xFFFFD600), attackColor: Color(0xFFFFFF00)),

    // Shadow evolutions (base: purple)
    HeroEvolution(id: 'shadow_stage1', heroId: 'shadow', stage: 1,
      name: 'SHADOW',
      description: 'A sneaky ninja cat who strikes from the shadows with dark energy!',
      price: 0,
      primaryColor: Color(0xFFAA00FF), attackColor: Color(0xFFD500F9)),
    HeroEvolution(id: 'shadow_stage2', heroId: 'shadow', stage: 2,
      name: 'PHANTOM KNIGHT',
      description: 'Sleek dark armor with shadow energy!',
      price: 18,
      primaryColor: Color(0xFFAA00FF), attackColor: Color(0xFFD500F9)),
    HeroEvolution(id: 'shadow_stage3', heroId: 'shadow', stage: 3,
      name: 'VOID LORD',
      description: 'Legendary void armor — invisible and deadly!',
      price: 25,
      primaryColor: Color(0xFFAA00FF), attackColor: Color(0xFFD500F9)),

    // Leaf evolutions (base: green)
    HeroEvolution(id: 'leaf_stage1', heroId: 'leaf', stage: 1,
      name: 'LEAF',
      description: 'A mighty tree guardian who smashes monsters with vine whip attacks!',
      price: 0,
      primaryColor: Color(0xFF00E676), attackColor: Color(0xFF69F0AE)),
    HeroEvolution(id: 'leaf_stage2', heroId: 'leaf', stage: 2,
      name: 'FOREST KNIGHT',
      description: 'Living vine armor with nature magic!',
      price: 18,
      primaryColor: Color(0xFF00E676), attackColor: Color(0xFF69F0AE)),
    HeroEvolution(id: 'leaf_stage3', heroId: 'leaf', stage: 3,
      name: 'ANCIENT GUARDIAN',
      description: 'Legendary tree armor — unstoppable!',
      price: 25,
      primaryColor: Color(0xFF00E676), attackColor: Color(0xFF69F0AE)),

    // Nova evolutions (base: gold)
    HeroEvolution(id: 'nova_stage1', heroId: 'nova', stage: 1,
      name: 'NOVA',
      description: 'The legendary phoenix who unleashes cosmic star bursts of pure light!',
      price: 0,
      primaryColor: Color(0xFFFFD54F), attackColor: Color(0xFFFFE082)),
    HeroEvolution(id: 'nova_stage2', heroId: 'nova', stage: 2,
      name: 'STAR KNIGHT',
      description: 'Golden armor with cosmic star energy!',
      price: 18,
      primaryColor: Color(0xFFFFD54F), attackColor: Color(0xFFFFE082)),
    HeroEvolution(id: 'nova_stage3', heroId: 'nova', stage: 3,
      name: 'CELESTIAL LORD',
      description: 'Legendary cosmic armor — pure starlight!',
      price: 25,
      primaryColor: Color(0xFFFFD54F), attackColor: Color(0xFFFFE082)),
  ];

  static List<HeroEvolution> evolutionsForHero(String heroId) {
    return allEvolutions.where((e) => e.heroId == heroId).toList();
  }

  static HeroEvolution? getEvolutionById(String? id) {
    if (id == null) return null;
    try {
      return allEvolutions.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  static HeroEvolution getEvolutionForHero(String heroId, int stage) {
    return allEvolutions.firstWhere(
      (e) => e.heroId == heroId && e.stage == stage,
      orElse: () => allEvolutions.firstWhere((e) => e.heroId == heroId && e.stage == 1),
    );
  }

  Future<List<String>> getUnlockedEvolutionIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_unlockedEvolutionsKey) ?? [];
  }

  Future<bool> isEvolutionUnlocked(String evolutionId) async {
    final unlocked = await getUnlockedEvolutionIds();
    return unlocked.contains(evolutionId);
  }

  Future<bool> purchaseEvolution(String evolutionId) async {
    if (_purchasing) return false;
    _purchasing = true;
    try {
      final evo = getEvolutionById(evolutionId);
      if (evo == null) return false;

      // Stage 1 is always free — no purchase needed
      if (evo.price == 0) return true;

      final prefs = await SharedPreferences.getInstance();
      final unlocked = prefs.getStringList(_unlockedEvolutionsKey) ?? [];
      if (unlocked.contains(evolutionId)) return true;

      // Sequential gating: stage 3 requires stage 2 to be owned
      if (evo.stage >= 3) {
        final prevId = '${evo.heroId}_stage${evo.stage - 1}';
        if (!unlocked.contains(prevId)) return false;
      }

      final success = await StreakService().spendStars(evo.price);
      if (!success) return false;

      unlocked.add(evolutionId);
      await prefs.setStringList(_unlockedEvolutionsKey, unlocked);
      return true;
    } finally {
      _purchasing = false;
    }
  }

  Future<int> getEvolutionStage(String heroId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_evolutionStagePrefix$heroId') ?? 1;
  }

  Future<void> setEvolutionStage(String heroId, int stage) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_evolutionStagePrefix$heroId', stage);
  }

  /// Build a hero image widget using the composite hero+weapon image.
  /// Falls back to the base hero image if the composite doesn't exist.
  static Widget buildHeroImage(String heroId, {int stage = 1, String? weaponId, double size = 120}) {
    weaponId ??= 'star_blaster';
    final path = 'assets/images/heroes/hero_${heroId}_stage${stage}_$weaponId.png';
    return Image.asset(
      path,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // Fallback to base hero image if composite doesn't exist
        return Image.asset(
          'assets/images/hero_$heroId.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
        );
      },
    );
  }
}
