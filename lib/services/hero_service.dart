import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HeroCharacter {
  final String id;
  final String name;
  final String title;
  final String description;
  final int cost;
  final String imagePath;
  final Color primaryColor;
  final Color attackColor;

  const HeroCharacter({
    required this.id,
    required this.name,
    required this.title,
    required this.description,
    required this.cost,
    required this.imagePath,
    required this.primaryColor,
    required this.attackColor,
  });
}

class HeroService {
  static const _unlockedKey = 'unlocked_heroes';
  static const _selectedKey = 'selected_hero';

  static const List<HeroCharacter> allHeroes = [
    HeroCharacter(
      id: 'blaze',
      name: 'BLAZE',
      title: 'Fire Ranger',
      description: 'Burns cavity monsters to ash with blazing fire attacks!',
      cost: 0,
      imagePath: 'assets/images/hero_blaze.png',
      primaryColor: Color(0xFFFF6D00),
      attackColor: Color(0xFFFF9100),
    ),
    HeroCharacter(
      id: 'frost',
      name: 'FROST',
      title: 'Ice Ranger',
      description: 'Freezes monsters solid with powerful ice beams!',
      cost: 8,
      imagePath: 'assets/images/hero_frost.png',
      primaryColor: Color(0xFF40C4FF),
      attackColor: Color(0xFF80D8FF),
    ),
    HeroCharacter(
      id: 'bolt',
      name: 'BOLT',
      title: 'Lightning Ranger',
      description: 'Zaps monsters with lightning-fast electric attacks!',
      cost: 12,
      imagePath: 'assets/images/hero_bolt.png',
      primaryColor: Color(0xFFFFD600),
      attackColor: Color(0xFFFFFF00),
    ),
    HeroCharacter(
      id: 'shadow',
      name: 'SHADOW',
      title: 'Dark Ranger',
      description: 'Strikes from the shadows with mysterious dark energy!',
      cost: 18,
      imagePath: 'assets/images/hero_shadow.png',
      primaryColor: Color(0xFFAA00FF),
      attackColor: Color(0xFFD500F9),
    ),
    HeroCharacter(
      id: 'leaf',
      name: 'LEAF',
      title: 'Nature Ranger',
      description: 'Commands the power of nature with vine whip attacks!',
      cost: 25,
      imagePath: 'assets/images/hero_leaf.png',
      primaryColor: Color(0xFF00E676),
      attackColor: Color(0xFF69F0AE),
    ),
    HeroCharacter(
      id: 'nova',
      name: 'NOVA',
      title: 'Cosmic Ranger',
      description: 'The ultimate ranger! Unleashes cosmic star bursts!',
      cost: 35,
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
    final hero = getHeroById(heroId);
    final prefs = await SharedPreferences.getInstance();

    final unlocked = prefs.getStringList(_unlockedKey) ?? ['blaze'];
    if (unlocked.contains(heroId)) return true;

    final stars = prefs.getInt('total_stars') ?? 0;
    if (stars < hero.cost) return false;

    await prefs.setInt('total_stars', stars - hero.cost);
    unlocked.add(heroId);
    await prefs.setStringList(_unlockedKey, unlocked);
    return true;
  }

  Future<bool> isHeroUnlocked(String heroId) async {
    final unlocked = await getUnlockedHeroIds();
    return unlocked.contains(heroId);
  }

  static HeroCharacter getHeroById(String id) {
    return allHeroes.firstWhere((h) => h.id == id, orElse: () => allHeroes[0]);
  }
}
