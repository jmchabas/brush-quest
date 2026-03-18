import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HeroCharacter {
  final String id;
  final String name;
  final String title;
  final String description;
  final int unlockAt;
  final String imagePath;
  final Color primaryColor;
  final Color attackColor;

  const HeroCharacter({
    required this.id,
    required this.name,
    required this.title,
    required this.description,
    required this.unlockAt,
    required this.imagePath,
    required this.primaryColor,
    required this.attackColor,
  });
}

class HeroService {
  static const _unlockedKey = 'unlocked_heroes';
  static const _selectedKey = 'selected_hero';
  static bool _purchasing = false;

  // Cumulative star thresholds — the star counter never drops.
  // Interleaved with weapons for a new unlock every 3-5 days at 2x/day.
  static const List<HeroCharacter> allHeroes = [
    HeroCharacter(
      id: 'blaze',
      name: 'BLAZE',
      title: 'Fire Dragon',
      description: 'A fierce little dragon who burns cavity monsters with blazing fire breath!',
      unlockAt: 0,
      imagePath: 'assets/images/hero_blaze.png',
      primaryColor: Color(0xFFFF6D00),
      attackColor: Color(0xFFFF9100),
    ),
    HeroCharacter(
      id: 'frost',
      name: 'FROST',
      title: 'Ice Wolf',
      description: 'A brave wolf knight who freezes monsters solid with icy howls!',
      unlockAt: 14,
      imagePath: 'assets/images/hero_frost.png',
      primaryColor: Color(0xFF40C4FF),
      attackColor: Color(0xFF80D8FF),
    ),
    HeroCharacter(
      id: 'bolt',
      name: 'BOLT',
      title: 'Lightning Robot',
      description: 'A super-charged robot who zaps monsters with electric bolts!',
      unlockAt: 30,
      imagePath: 'assets/images/hero_bolt.png',
      primaryColor: Color(0xFFFFD600),
      attackColor: Color(0xFFFFFF00),
    ),
    HeroCharacter(
      id: 'shadow',
      name: 'SHADOW',
      title: 'Ninja Cat',
      description: 'A sneaky ninja cat who strikes from the shadows with dark energy!',
      unlockAt: 50,
      imagePath: 'assets/images/hero_shadow.png',
      primaryColor: Color(0xFFAA00FF),
      attackColor: Color(0xFFD500F9),
    ),
    HeroCharacter(
      id: 'leaf',
      name: 'LEAF',
      title: 'Nature Guardian',
      description: 'A mighty tree guardian who smashes monsters with vine whip attacks!',
      unlockAt: 74,
      imagePath: 'assets/images/hero_leaf.png',
      primaryColor: Color(0xFF00E676),
      attackColor: Color(0xFF69F0AE),
    ),
    HeroCharacter(
      id: 'nova',
      name: 'NOVA',
      title: 'Cosmic Phoenix',
      description: 'The legendary phoenix who unleashes cosmic star bursts of pure light!',
      unlockAt: 98,
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

  Future<bool> unlockHero(String heroId) async {
    if (_purchasing) return false;
    _purchasing = true;
    try {
      final hero = getHeroById(heroId);
      if (hero.id != heroId) return false; // Invalid ID
      final prefs = await SharedPreferences.getInstance();

      final unlocked = prefs.getStringList(_unlockedKey) ?? ['blaze'];
      if (unlocked.contains(heroId)) return true;

      final stars = prefs.getInt('total_stars') ?? 0;
      if (stars < hero.unlockAt) return false;

      // Cumulative economy: stars are never deducted.
      unlocked.add(heroId);
      await prefs.setStringList(_unlockedKey, unlocked);
      return true;
    } finally {
      _purchasing = false;
    }
  }

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
}
