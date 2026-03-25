import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'world_service.dart';

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
    'frozen_tundra', 'toxic_jungle', 'crystal_cave',
    'storm_citadel', 'dark_dimension',
  ];

  // 50 trophies: 5 per world, 10 worlds.
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

    // -- Frozen Tundra --
    TrophyMonster(id: 'ft_t1', name: 'Frost Sprite', title: 'Ice Dancer', worldId: 'frozen_tundra', baseImageIndex: 0, tintColor: Color(0xFF81D4FA), defeatsRequired: 1, flavorText: 'Leaves frost patterns everywhere it flies!'),
    TrophyMonster(id: 'ft_t2', name: 'Blizzard Bug', title: 'Snow Swirler', worldId: 'frozen_tundra', baseImageIndex: 1, tintColor: Color(0xFF4FC3F7), defeatsRequired: 1, flavorText: 'Creates mini snowstorms when angry!'),
    TrophyMonster(id: 'ft_t3', name: 'Icicle Imp', title: 'Sharp Frosty', worldId: 'frozen_tundra', baseImageIndex: 2, tintColor: Color(0xFF29B6F6), defeatsRequired: 1, flavorText: 'Throws tiny icicles like darts!'),
    TrophyMonster(id: 'ft_t4', name: 'Ice Golem', title: 'Frozen Giant', worldId: 'frozen_tundra', baseImageIndex: 3, tintColor: Color(0xFF039BE5), defeatsRequired: 2, flavorText: 'Made entirely of solid ice!'),
    TrophyMonster(id: 'ft_t5', name: 'Glacier King', title: 'Lord of Frost', worldId: 'frozen_tundra', baseImageIndex: 0, tintColor: Color(0xFF0277BD), defeatsRequired: 3, flavorText: 'Can freeze an entire planet in seconds!'),

    // -- Toxic Jungle --
    TrophyMonster(id: 'tj_t1', name: 'Vine Viper', title: 'Jungle Snapper', worldId: 'toxic_jungle', baseImageIndex: 1, tintColor: Color(0xFF66BB6A), defeatsRequired: 1, flavorText: 'Hides inside poisonous vines!'),
    TrophyMonster(id: 'tj_t2', name: 'Spore Specter', title: 'Puff Phantom', worldId: 'toxic_jungle', baseImageIndex: 0, tintColor: Color(0xFF43A047), defeatsRequired: 1, flavorText: 'Spreads toxic spores everywhere!'),
    TrophyMonster(id: 'tj_t3', name: 'Thorn Beetle', title: 'Spiky Scuttler', worldId: 'toxic_jungle', baseImageIndex: 2, tintColor: Color(0xFF2E7D32), defeatsRequired: 1, flavorText: 'Covered in sharp poisonous thorns!'),
    TrophyMonster(id: 'tj_t4', name: 'Acid Orchid', title: 'Toxic Bloom', worldId: 'toxic_jungle', baseImageIndex: 3, tintColor: Color(0xFF00C853), defeatsRequired: 2, flavorText: 'A beautiful flower that spits acid!'),
    TrophyMonster(id: 'tj_t5', name: 'Jungle Titan', title: 'Overgrown Terror', worldId: 'toxic_jungle', baseImageIndex: 1, tintColor: Color(0xFF1B5E20), defeatsRequired: 3, flavorText: 'An ancient tree monster that rules the jungle!'),

    // -- Crystal Cave --
    TrophyMonster(id: 'cc2_t1', name: 'Crystal Crawler', title: 'Gem Scuttler', worldId: 'crystal_cave', baseImageIndex: 0, tintColor: Color(0xFF80DEEA), defeatsRequired: 1, flavorText: 'Crawls across crystal walls!'),
    TrophyMonster(id: 'cc2_t2', name: 'Shard Sprite', title: 'Prism Flyer', worldId: 'crystal_cave', baseImageIndex: 1, tintColor: Color(0xFF4DD0E1), defeatsRequired: 1, flavorText: 'Splits light into rainbow beams!'),
    TrophyMonster(id: 'cc2_t3', name: 'Geode Guard', title: 'Rock Shell', worldId: 'crystal_cave', baseImageIndex: 2, tintColor: Color(0xFF26C6DA), defeatsRequired: 1, flavorText: 'Looks like a rock but is full of gems!'),
    TrophyMonster(id: 'cc2_t4', name: 'Quartz Lurker', title: 'Deep Dweller', worldId: 'crystal_cave', baseImageIndex: 3, tintColor: Color(0xFF00ACC1), defeatsRequired: 2, flavorText: 'Hides deep underground in quartz veins!'),
    TrophyMonster(id: 'cc2_t5', name: 'Diamond Titan', title: 'Unbreakable Lord', worldId: 'crystal_cave', baseImageIndex: 0, tintColor: Color(0xFF00838F), defeatsRequired: 3, flavorText: 'Armor harder than any diamond!'),

    // -- Storm Citadel --
    TrophyMonster(id: 'sc_t1', name: 'Thunder Imp', title: 'Spark Pest', worldId: 'storm_citadel', baseImageIndex: 2, tintColor: Color(0xFFFFD740), defeatsRequired: 1, flavorText: 'Zaps everything it touches!'),
    TrophyMonster(id: 'sc_t2', name: 'Gale Gremlin', title: 'Wind Whipper', worldId: 'storm_citadel', baseImageIndex: 3, tintColor: Color(0xFFFFCA28), defeatsRequired: 1, flavorText: 'Rides the wind like a surfboard!'),
    TrophyMonster(id: 'sc_t3', name: 'Lightning Larva', title: 'Bolt Worm', worldId: 'storm_citadel', baseImageIndex: 0, tintColor: Color(0xFFFFC107), defeatsRequired: 1, flavorText: 'Its body crackles with electricity!'),
    TrophyMonster(id: 'sc_t4', name: 'Storm Sentinel', title: 'Cloud Warden', worldId: 'storm_citadel', baseImageIndex: 1, tintColor: Color(0xFFFFB300), defeatsRequired: 2, flavorText: 'Guards the citadel from atop the clouds!'),
    TrophyMonster(id: 'sc_t5', name: 'Tempest Lord', title: 'Hurricane King', worldId: 'storm_citadel', baseImageIndex: 2, tintColor: Color(0xFFF57F17), defeatsRequired: 3, flavorText: 'Commands all storms across the galaxy!'),

    // -- Dark Dimension --
    TrophyMonster(id: 'dd_t1', name: 'Void Wisp', title: 'Shadow Flicker', worldId: 'dark_dimension', baseImageIndex: 0, tintColor: Color(0xFFCE93D8), defeatsRequired: 1, flavorText: 'Flickers in and out of existence!'),
    TrophyMonster(id: 'dd_t2', name: 'Shadow Stalker', title: 'Dark Hunter', worldId: 'dark_dimension', baseImageIndex: 3, tintColor: Color(0xFFBA68C8), defeatsRequired: 1, flavorText: 'Hunts through the darkest shadows!'),
    TrophyMonster(id: 'dd_t3', name: 'Abyss Crawler', title: 'Depth Creeper', worldId: 'dark_dimension', baseImageIndex: 1, tintColor: Color(0xFFAB47BC), defeatsRequired: 1, flavorText: 'Crawls up from the deepest abyss!'),
    TrophyMonster(id: 'dd_t4', name: 'Null Wraith', title: 'Void Phantom', worldId: 'dark_dimension', baseImageIndex: 2, tintColor: Color(0xFF9C27B0), defeatsRequired: 2, flavorText: 'Erases anything it touches from reality!'),
    TrophyMonster(id: 'dd_t5', name: 'Dimension Lord', title: 'Master of Void', worldId: 'dark_dimension', baseImageIndex: 3, tintColor: Color(0xFF6A1B9A), defeatsRequired: 3, flavorText: 'Rules over all dimensions of darkness!'),
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

  /// Auto-grant trophies for worlds that the player has already cleared.
  /// For each completed world, sets all trophy defeat counts to their
  /// required value and marks them as captured.
  Future<void> autoGrantClearedWorldTrophies() async {
    final worldService = WorldService();
    final prefs = await SharedPreferences.getInstance();
    final captured = prefs.getStringList(_capturedKey) ?? [];

    for (final worldId in worldIds) {
      final world = WorldService.getWorldById(worldId);
      final progress = await worldService.getWorldProgress(worldId);
      if (progress < world.missionsRequired) continue;

      // World is cleared — grant all its trophies
      final worldTrophies = trophiesForWorld(worldId);
      for (final trophy in worldTrophies) {
        if (captured.contains(trophy.id)) continue;

        // Set defeat count to required
        await prefs.setInt('$_defeatPrefix${trophy.id}', trophy.defeatsRequired);
        captured.add(trophy.id);
      }
    }

    await prefs.setStringList(_capturedKey, captured);
  }
}
