import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WorldData {
  final String id;
  final String name;
  final String description;
  final int missionsRequired;
  final Color themeColor;
  final String imagePath;
  final List<int> monsterIndices;
  final List<Color> gradientColors;
  final String particleType; // 'sparkle', 'bubble', 'ember', 'twinkle', 'crack'

  const WorldData({
    required this.id,
    required this.name,
    required this.description,
    required this.missionsRequired,
    required this.themeColor,
    required this.imagePath,
    required this.monsterIndices,
    required this.gradientColors,
    required this.particleType,
  });
}

class WorldService {
  static const _progressPrefix = 'world_progress_';
  static const _currentWorldKey = 'current_world';

  static const List<WorldData> allWorlds = [
    WorldData(
      id: 'candy_crater',
      name: 'Candy Crater',
      description: 'A sweet planet covered in candy and sugar crystals!',
      missionsRequired: 5,
      themeColor: Color(0xFFFF80AB),
      imagePath: 'assets/images/planet_candy.png',
      monsterIndices: [0, 1],
      gradientColors: [Color(0xFFFF80AB), Color(0xFFC2185B), Color(0xFF1A0A2E)],
      particleType: 'sparkle',
    ),
    WorldData(
      id: 'slime_swamp',
      name: 'Slime Swamp',
      description: 'A gooey green planet full of slimy monsters!',
      missionsRequired: 5,
      themeColor: Color(0xFF69F0AE),
      imagePath: 'assets/images/planet_slime.png',
      monsterIndices: [1, 2],
      gradientColors: [Color(0xFF69F0AE), Color(0xFF00897B), Color(0xFF0D1B2A)],
      particleType: 'bubble',
    ),
    WorldData(
      id: 'sugar_volcano',
      name: 'Sugar Volcano',
      description: 'A fiery planet with erupting sugar volcanoes!',
      missionsRequired: 6,
      themeColor: Color(0xFFFF6E40),
      imagePath: 'assets/images/planet_volcano.png',
      monsterIndices: [2, 3],
      gradientColors: [Color(0xFFFF6E40), Color(0xFFD32F2F), Color(0xFF1A0A0A)],
      particleType: 'ember',
    ),
    WorldData(
      id: 'shadow_nebula',
      name: 'Shadow Nebula',
      description: 'A mysterious dark planet full of spooky surprises!',
      missionsRequired: 6,
      themeColor: Color(0xFFB388FF),
      imagePath: 'assets/images/planet_shadow.png',
      monsterIndices: [0, 3],
      gradientColors: [Color(0xFFB388FF), Color(0xFF4A148C), Color(0xFF050510)],
      particleType: 'twinkle',
    ),
    WorldData(
      id: 'cavity_fortress',
      name: 'Cavity Fortress',
      description: 'The Cavity King\'s stronghold! The final challenge!',
      missionsRequired: 7,
      themeColor: Color(0xFFFF5252),
      imagePath: 'assets/images/planet_fortress.png',
      monsterIndices: [0, 1, 2, 3],
      gradientColors: [Color(0xFFFF5252), Color(0xFFB71C1C), Color(0xFF050000)],
      particleType: 'crack',
    ),
  ];

  Future<String> getCurrentWorldId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentWorldKey) ?? 'candy_crater';
  }

  Future<WorldData> getCurrentWorld() async {
    final id = await getCurrentWorldId();
    return getWorldById(id);
  }

  Future<int> getWorldProgress(String worldId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_progressPrefix$worldId') ?? 0;
  }

  Future<void> recordMission() async {
    final prefs = await SharedPreferences.getInstance();
    final worldId = await getCurrentWorldId();
    final current = prefs.getInt('$_progressPrefix$worldId') ?? 0;
    await prefs.setInt('$_progressPrefix$worldId', current + 1);

    final world = getWorldById(worldId);
    if (current + 1 >= world.missionsRequired) {
      final worldIndex = allWorlds.indexWhere((w) => w.id == worldId);
      if (worldIndex < allWorlds.length - 1) {
        await prefs.setString(_currentWorldKey, allWorlds[worldIndex + 1].id);
      }
    }
  }

  Future<bool> isWorldUnlocked(String worldId) async {
    final worldIndex = allWorlds.indexWhere((w) => w.id == worldId);
    if (worldIndex <= 0) return true;

    final prevWorld = allWorlds[worldIndex - 1];
    final progress = await getWorldProgress(prevWorld.id);
    return progress >= prevWorld.missionsRequired;
  }

  Future<bool> isWorldCompleted(String worldId) async {
    final world = getWorldById(worldId);
    final progress = await getWorldProgress(worldId);
    return progress >= world.missionsRequired;
  }

  Future<bool> isAllWorldsCompleted() async {
    for (final world in allWorlds) {
      if (!await isWorldCompleted(world.id)) return false;
    }
    return true;
  }

  static WorldData getWorldById(String id) {
    return allWorlds.firstWhere((w) => w.id == id, orElse: () => allWorlds[0]);
  }
}
