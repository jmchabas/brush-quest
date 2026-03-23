import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TrophyMonster {
  final String id;
  final String name;
  final String title;
  final String worldId;
  final int baseImageIndex; // 0-3 → monster_purple/green/orange/red
  final Color tintColor;
  final int defeatsRequired; // 1-3 brushes to capture
  final String flavorText;

  const TrophyMonster({
    required this.id,
    required this.name,
    required this.title,
    required this.worldId,
    required this.baseImageIndex,
    required this.tintColor,
    required this.defeatsRequired,
    required this.flavorText,
  });

  String get imagePath => _monsterImages[baseImageIndex];

  static const _monsterImages = [
    'assets/images/monster_purple.png',
    'assets/images/monster_green.png',
    'assets/images/monster_orange.png',
    'assets/images/monster_red.png',
  ];
}

class DefeatResult {
  final bool captured;
  final int currentDefeats;
  final int required;

  const DefeatResult({
    required this.captured,
    required this.currentDefeats,
    required this.required,
  });
}

class WallProgress {
  final int captured;
  final int total;
  const WallProgress({required this.captured, required this.total});
}

class TrophyService {
  static const _capturedKey = 'trophy_captured';
  static const _defeatPrefix = 'trophy_defeats_';

  static const worldIds = [
    'candy_crater', 'slime_swamp', 'sugar_volcano',
    'shadow_nebula', 'cavity_fortress',
  ];

  // 25 trophies: 5 per world.
  // defeatsRequired: 1 for regular, 2 for tough, 3 for boss.
  static const List<TrophyMonster> allTrophies = [
    // -- Candy Crater --
    TrophyMonster(id: 'cc_t1', name: 'Gummy Grub', title: 'Sugar Slimer', worldId: 'candy_crater', baseImageIndex: 0, tintColor: Color(0xFFFF80AB), defeatsRequired: 1, flavorText: 'Leaves sticky gum trails everywhere!'),
    TrophyMonster(id: 'cc_t2', name: 'Lollipop Lurker', title: 'Sweet Stalker', worldId: 'candy_crater', baseImageIndex: 1, tintColor: Color(0xFFF48FB1), defeatsRequired: 1, flavorText: 'Hides inside giant lollipops!'),
    TrophyMonster(id: 'cc_t3', name: 'Taffy Twister', title: 'Stretchy Menace', worldId: 'candy_crater', baseImageIndex: 1, tintColor: Color(0xFFEF9A9A), defeatsRequired: 1, flavorText: 'Stretches like taffy to dodge attacks!'),
    TrophyMonster(id: 'cc_t4', name: 'Mint Marauder', title: 'Cool Criminal', worldId: 'candy_crater', baseImageIndex: 0, tintColor: Color(0xFF80CBC4), defeatsRequired: 2, flavorText: 'So minty your eyes water!'),
    TrophyMonster(id: 'cc_t5', name: 'Sugar King', title: 'Sweetness Supreme', worldId: 'candy_crater', baseImageIndex: 0, tintColor: Color(0xFFFF4081), defeatsRequired: 3, flavorText: 'The ultimate sugar monster!'),

    // -- Slime Swamp --
    TrophyMonster(id: 'ss_t1', name: 'Goo Goblin', title: 'Slime Spitter', worldId: 'slime_swamp', baseImageIndex: 1, tintColor: Color(0xFF69F0AE), defeatsRequired: 1, flavorText: 'Spits green goo at everything!'),
    TrophyMonster(id: 'ss_t2', name: 'Muck Monster', title: 'Mud Dweller', worldId: 'slime_swamp', baseImageIndex: 2, tintColor: Color(0xFF81C784), defeatsRequired: 1, flavorText: 'Lives deep in the muckiest mud!'),
    TrophyMonster(id: 'ss_t3', name: 'Bog Beast', title: 'Swamp Stomper', worldId: 'slime_swamp', baseImageIndex: 2, tintColor: Color(0xFF4DB6AC), defeatsRequired: 1, flavorText: 'Shakes the ground when it walks!'),
    TrophyMonster(id: 'ss_t4', name: 'Toxic Toad', title: 'Poison Hopper', worldId: 'slime_swamp', baseImageIndex: 1, tintColor: Color(0xFF00E676), defeatsRequired: 2, flavorText: 'Its tongue is super sticky!'),
    TrophyMonster(id: 'ss_t5', name: 'Swamp Lord', title: 'King of Ooze', worldId: 'slime_swamp', baseImageIndex: 1, tintColor: Color(0xFF00BFA5), defeatsRequired: 3, flavorText: 'Rules the entire swamp!'),

    // -- Sugar Volcano --
    TrophyMonster(id: 'sv_t1', name: 'Ember Imp', title: 'Fire Starter', worldId: 'sugar_volcano', baseImageIndex: 2, tintColor: Color(0xFFFF8A65), defeatsRequired: 1, flavorText: 'Sets everything on fire!'),
    TrophyMonster(id: 'sv_t2', name: 'Lava Larva', title: 'Hot Crawler', worldId: 'sugar_volcano', baseImageIndex: 3, tintColor: Color(0xFFFF7043), defeatsRequired: 1, flavorText: 'Born inside a volcano!'),
    TrophyMonster(id: 'sv_t3', name: 'Magma Mite', title: 'Molten Menace', worldId: 'sugar_volcano', baseImageIndex: 3, tintColor: Color(0xFFE64A19), defeatsRequired: 2, flavorText: 'Too hot to touch!'),
    TrophyMonster(id: 'sv_t4', name: 'Pyro Python', title: 'Fire Fang', worldId: 'sugar_volcano', baseImageIndex: 3, tintColor: Color(0xFFFF6E40), defeatsRequired: 2, flavorText: 'Breathes fireballs!'),
    TrophyMonster(id: 'sv_t5', name: 'Volcano King', title: 'Eruption Lord', worldId: 'sugar_volcano', baseImageIndex: 2, tintColor: Color(0xFFDD2C00), defeatsRequired: 3, flavorText: 'Makes volcanoes erupt on command!'),

    // -- Shadow Nebula --
    TrophyMonster(id: 'sn_t1', name: 'Dark Wisp', title: 'Shadow Drifter', worldId: 'shadow_nebula', baseImageIndex: 0, tintColor: Color(0xFFB39DDB), defeatsRequired: 1, flavorText: 'Floats through the darkness!'),
    TrophyMonster(id: 'sn_t2', name: 'Gloom Ghoul', title: 'Night Creeper', worldId: 'shadow_nebula', baseImageIndex: 3, tintColor: Color(0xFF9575CD), defeatsRequired: 1, flavorText: 'Only comes out at night!'),
    TrophyMonster(id: 'sn_t3', name: 'Void Vermin', title: 'Space Rat', worldId: 'shadow_nebula', baseImageIndex: 0, tintColor: Color(0xFF7E57C2), defeatsRequired: 2, flavorText: 'Chews through anything!'),
    TrophyMonster(id: 'sn_t4', name: 'Nebula Knight', title: 'Star Warrior', worldId: 'shadow_nebula', baseImageIndex: 3, tintColor: Color(0xFF7C4DFF), defeatsRequired: 2, flavorText: 'Has armor made of starlight!'),
    TrophyMonster(id: 'sn_t5', name: 'Shadow Overlord', title: 'Darkness Master', worldId: 'shadow_nebula', baseImageIndex: 0, tintColor: Color(0xFF6200EA), defeatsRequired: 3, flavorText: 'Controls all shadows!'),

    // -- Cavity Fortress --
    TrophyMonster(id: 'cf_t1', name: 'Plaque Pawn', title: 'Fortress Guard', worldId: 'cavity_fortress', baseImageIndex: 0, tintColor: Color(0xFFEF5350), defeatsRequired: 1, flavorText: 'The weakest fortress guard!'),
    TrophyMonster(id: 'cf_t2', name: 'Tartar Trooper', title: 'Crusty Soldier', worldId: 'cavity_fortress', baseImageIndex: 2, tintColor: Color(0xFFC62828), defeatsRequired: 1, flavorText: 'Tough and crusty armor!'),
    TrophyMonster(id: 'cf_t3', name: 'Crown Cruncher', title: 'Golden Fang', worldId: 'cavity_fortress', baseImageIndex: 1, tintColor: Color(0xFFFFD54F), defeatsRequired: 2, flavorText: 'Has a golden tooth crown!'),
    TrophyMonster(id: 'cf_t4', name: 'Enamel Eater', title: 'Tooth Destroyer', worldId: 'cavity_fortress', baseImageIndex: 2, tintColor: Color(0xFFFFB300), defeatsRequired: 2, flavorText: 'Eats tooth enamel for breakfast!'),
    TrophyMonster(id: 'cf_t5', name: 'Cavity King', title: 'Supreme Ruler', worldId: 'cavity_fortress', baseImageIndex: 3, tintColor: Color(0xFFFF1744), defeatsRequired: 3, flavorText: 'The ultimate boss of all cavities!'),
  ];

  static List<TrophyMonster> trophiesForWorld(String worldId) =>
      allTrophies.where((t) => t.worldId == worldId).toList();

  Future<List<String>> getCapturedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_capturedKey) ?? [];
  }

  Future<bool> isCaptured(String trophyId) async {
    final captured = await getCapturedIds();
    return captured.contains(trophyId);
  }

  Future<void> recordCapture(String trophyId) async {
    final prefs = await SharedPreferences.getInstance();
    final captured = prefs.getStringList(_capturedKey) ?? [];
    if (!captured.contains(trophyId)) {
      captured.add(trophyId);
      await prefs.setStringList(_capturedKey, captured);
    }
  }

  Future<int> getDefeatCount(String trophyId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_defeatPrefix$trophyId') ?? 0;
  }

  /// Record a defeat against a trophy monster.
  /// Returns whether it was captured (defeats >= required).
  Future<DefeatResult> recordDefeat(String trophyId) async {
    final trophy = allTrophies.firstWhere((t) => t.id == trophyId);
    final prefs = await SharedPreferences.getInstance();

    // Already captured? No-op.
    final captured = prefs.getStringList(_capturedKey) ?? [];
    if (captured.contains(trophyId)) {
      return DefeatResult(captured: true, currentDefeats: trophy.defeatsRequired, required: trophy.defeatsRequired);
    }

    final key = '$_defeatPrefix$trophyId';
    final defeats = (prefs.getInt(key) ?? 0) + 1;
    await prefs.setInt(key, defeats);

    final justCaptured = defeats >= trophy.defeatsRequired;
    if (justCaptured) {
      await recordCapture(trophyId);
    }

    return DefeatResult(captured: justCaptured, currentDefeats: defeats, required: trophy.defeatsRequired);
  }

  /// Get the next uncaptured monster from a world (in order).
  Future<TrophyMonster?> getNextUncaptured(String worldId) async {
    final captured = await getCapturedIds();
    final worldTrophies = trophiesForWorld(worldId);
    for (final trophy in worldTrophies) {
      if (!captured.contains(trophy.id)) return trophy;
    }
    return null;
  }

  Future<WallProgress> getWallProgress(String worldId) async {
    final captured = await getCapturedIds();
    final worldTrophies = trophiesForWorld(worldId);
    final count = worldTrophies.where((t) => captured.contains(t.id)).length;
    return WallProgress(captured: count, total: worldTrophies.length);
  }

  Future<bool> isWorldComplete(String worldId) async {
    final progress = await getWallProgress(worldId);
    return progress.captured == progress.total;
  }

  Future<int> getTotalCaptured() async {
    final captured = await getCapturedIds();
    return captured.length;
  }
}
