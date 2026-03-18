import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CardRarity { common, rare, epic }

class MonsterCard {
  final String id;
  final String name;
  final String title;
  final String worldId;
  final int baseImageIndex; // 0-3 → monster_purple, monster_green, monster_orange, monster_red
  final Color tintColor;
  final CardRarity rarity;
  final String flavorText;

  const MonsterCard({
    required this.id,
    required this.name,
    required this.title,
    required this.worldId,
    required this.baseImageIndex,
    required this.tintColor,
    required this.rarity,
    required this.flavorText,
  });

  String get imagePath => _monsterImages[baseImageIndex];

  Color get rarityColor => switch (rarity) {
    CardRarity.common => const Color(0xFFB0BEC5),
    CardRarity.rare => const Color(0xFF40C4FF),
    CardRarity.epic => const Color(0xFFFFD54F),
  };

  String get rarityLabel => switch (rarity) {
    CardRarity.common => 'COMMON',
    CardRarity.rare => 'RARE',
    CardRarity.epic => 'EPIC',
  };

  static const _monsterImages = [
    'assets/images/monster_purple.png',
    'assets/images/monster_green.png',
    'assets/images/monster_orange.png',
    'assets/images/monster_red.png',
  ];
}

class CardDropResult {
  final MonsterCard card;
  final bool isNew;
  final int worldCollected;
  final int worldTotal;
  final String worldName;

  const CardDropResult({
    required this.card,
    this.isNew = true,
    this.worldCollected = 0,
    this.worldTotal = 7,
    this.worldName = '',
  });
}

class CardService {
  static const _collectedKey = 'collected_cards';

  // Legacy drop chance — kept for test compatibility but no longer used.
  // Every brush session now guarantees exactly 1 card.
  static double dropChance(int streak) => (0.40 + streak * 0.02).clamp(0.0, 0.70);

  // 70 cards: 7 per world (4 common, 2 rare, 1 epic) x 10 worlds
  static const List<MonsterCard> allCards = [
    // ── World 1: Candy Crater ──
    MonsterCard(id: 'cc_01', name: 'Gummy Grub', title: 'Sugar Slimer', worldId: 'candy_crater', baseImageIndex: 0, tintColor: Color(0xFFFF80AB), rarity: CardRarity.common, flavorText: 'Leaves sticky gum trails everywhere!'),
    MonsterCard(id: 'cc_02', name: 'Lollipop Lurker', title: 'Sweet Stalker', worldId: 'candy_crater', baseImageIndex: 1, tintColor: Color(0xFFF48FB1), rarity: CardRarity.common, flavorText: 'Hides inside giant lollipops!'),
    MonsterCard(id: 'cc_03', name: 'Candy Cruncher', title: 'Jaw Breaker', worldId: 'candy_crater', baseImageIndex: 0, tintColor: Color(0xFFCE93D8), rarity: CardRarity.common, flavorText: 'Can eat 100 candies in one bite!'),
    MonsterCard(id: 'cc_04', name: 'Taffy Twister', title: 'Stretchy Menace', worldId: 'candy_crater', baseImageIndex: 1, tintColor: Color(0xFFEF9A9A), rarity: CardRarity.common, flavorText: 'Stretches like taffy to dodge attacks!'),
    MonsterCard(id: 'cc_05', name: 'Mint Marauder', title: 'Cool Criminal', worldId: 'candy_crater', baseImageIndex: 0, tintColor: Color(0xFF80CBC4), rarity: CardRarity.rare, flavorText: 'So minty your eyes water!'),
    MonsterCard(id: 'cc_06', name: 'Caramel Captain', title: 'Sticky Leader', worldId: 'candy_crater', baseImageIndex: 1, tintColor: Color(0xFFFFCC80), rarity: CardRarity.rare, flavorText: 'Commands a fleet of candy ships!'),
    MonsterCard(id: 'cc_07', name: 'Sugar King', title: 'Sweetness Supreme', worldId: 'candy_crater', baseImageIndex: 0, tintColor: Color(0xFFFF4081), rarity: CardRarity.epic, flavorText: 'The ultimate sugar monster!'),

    // ── World 2: Slime Swamp ──
    MonsterCard(id: 'ss_01', name: 'Goo Goblin', title: 'Slime Spitter', worldId: 'slime_swamp', baseImageIndex: 1, tintColor: Color(0xFF69F0AE), rarity: CardRarity.common, flavorText: 'Spits green goo at everything!'),
    MonsterCard(id: 'ss_02', name: 'Muck Monster', title: 'Mud Dweller', worldId: 'slime_swamp', baseImageIndex: 2, tintColor: Color(0xFF81C784), rarity: CardRarity.common, flavorText: 'Lives deep in the muckiest mud!'),
    MonsterCard(id: 'ss_03', name: 'Puddle Pest', title: 'Splash Fiend', worldId: 'slime_swamp', baseImageIndex: 1, tintColor: Color(0xFFA5D6A7), rarity: CardRarity.common, flavorText: 'Loves jumping in puddles!'),
    MonsterCard(id: 'ss_04', name: 'Bog Beast', title: 'Swamp Stomper', worldId: 'slime_swamp', baseImageIndex: 2, tintColor: Color(0xFF4DB6AC), rarity: CardRarity.common, flavorText: 'Shakes the ground when it walks!'),
    MonsterCard(id: 'ss_05', name: 'Toxic Toad', title: 'Poison Hopper', worldId: 'slime_swamp', baseImageIndex: 1, tintColor: Color(0xFF00E676), rarity: CardRarity.rare, flavorText: 'Its tongue is super sticky!'),
    MonsterCard(id: 'ss_06', name: 'Slime Serpent', title: 'Ooze Snake', worldId: 'slime_swamp', baseImageIndex: 2, tintColor: Color(0xFF26A69A), rarity: CardRarity.rare, flavorText: 'Slithers through slime like water!'),
    MonsterCard(id: 'ss_07', name: 'Swamp Lord', title: 'King of Ooze', worldId: 'slime_swamp', baseImageIndex: 1, tintColor: Color(0xFF00BFA5), rarity: CardRarity.epic, flavorText: 'Rules the entire swamp!'),

    // ── World 3: Sugar Volcano ──
    MonsterCard(id: 'sv_01', name: 'Ember Imp', title: 'Fire Starter', worldId: 'sugar_volcano', baseImageIndex: 2, tintColor: Color(0xFFFF8A65), rarity: CardRarity.common, flavorText: 'Sets everything on fire!'),
    MonsterCard(id: 'sv_02', name: 'Lava Larva', title: 'Hot Crawler', worldId: 'sugar_volcano', baseImageIndex: 3, tintColor: Color(0xFFFF7043), rarity: CardRarity.common, flavorText: 'Born inside a volcano!'),
    MonsterCard(id: 'sv_03', name: 'Cinder Critter', title: 'Ash Maker', worldId: 'sugar_volcano', baseImageIndex: 2, tintColor: Color(0xFFFF5722), rarity: CardRarity.common, flavorText: 'Leaves ash clouds behind!'),
    MonsterCard(id: 'sv_04', name: 'Magma Mite', title: 'Molten Menace', worldId: 'sugar_volcano', baseImageIndex: 3, tintColor: Color(0xFFE64A19), rarity: CardRarity.common, flavorText: 'Too hot to touch!'),
    MonsterCard(id: 'sv_05', name: 'Blaze Beetle', title: 'Flame Runner', worldId: 'sugar_volcano', baseImageIndex: 2, tintColor: Color(0xFFFFAB40), rarity: CardRarity.rare, flavorText: 'The fastest bug on the volcano!'),
    MonsterCard(id: 'sv_06', name: 'Pyro Python', title: 'Fire Fang', worldId: 'sugar_volcano', baseImageIndex: 3, tintColor: Color(0xFFFF6E40), rarity: CardRarity.rare, flavorText: 'Breathes fireballs!'),
    MonsterCard(id: 'sv_07', name: 'Volcano King', title: 'Eruption Lord', worldId: 'sugar_volcano', baseImageIndex: 2, tintColor: Color(0xFFDD2C00), rarity: CardRarity.epic, flavorText: 'Makes volcanoes erupt on command!'),

    // ── World 4: Shadow Nebula ──
    MonsterCard(id: 'sn_01', name: 'Dark Wisp', title: 'Shadow Drifter', worldId: 'shadow_nebula', baseImageIndex: 0, tintColor: Color(0xFFB39DDB), rarity: CardRarity.common, flavorText: 'Floats through the darkness!'),
    MonsterCard(id: 'sn_02', name: 'Gloom Ghoul', title: 'Night Creeper', worldId: 'shadow_nebula', baseImageIndex: 3, tintColor: Color(0xFF9575CD), rarity: CardRarity.common, flavorText: 'Only comes out at night!'),
    MonsterCard(id: 'sn_03', name: 'Void Vermin', title: 'Space Rat', worldId: 'shadow_nebula', baseImageIndex: 0, tintColor: Color(0xFF7E57C2), rarity: CardRarity.common, flavorText: 'Chews through anything!'),
    MonsterCard(id: 'sn_04', name: 'Phantom Flea', title: 'Ghost Hopper', worldId: 'shadow_nebula', baseImageIndex: 3, tintColor: Color(0xFFAB47BC), rarity: CardRarity.common, flavorText: 'Now you see it, now you don\'t!'),
    MonsterCard(id: 'sn_05', name: 'Eclipse Eel', title: 'Dark Swimmer', worldId: 'shadow_nebula', baseImageIndex: 0, tintColor: Color(0xFFCE93D8), rarity: CardRarity.rare, flavorText: 'Swims through shadows!'),
    MonsterCard(id: 'sn_06', name: 'Nebula Knight', title: 'Star Warrior', worldId: 'shadow_nebula', baseImageIndex: 3, tintColor: Color(0xFF7C4DFF), rarity: CardRarity.rare, flavorText: 'Has armor made of starlight!'),
    MonsterCard(id: 'sn_07', name: 'Shadow Overlord', title: 'Darkness Master', worldId: 'shadow_nebula', baseImageIndex: 0, tintColor: Color(0xFF6200EA), rarity: CardRarity.epic, flavorText: 'Controls all shadows!'),

    // ── World 5: Cavity Fortress ──
    MonsterCard(id: 'cf_01', name: 'Plaque Pawn', title: 'Fortress Guard', worldId: 'cavity_fortress', baseImageIndex: 0, tintColor: Color(0xFFEF5350), rarity: CardRarity.common, flavorText: 'The weakest fortress guard!'),
    MonsterCard(id: 'cf_02', name: 'Decay Drone', title: 'Rot Flyer', worldId: 'cavity_fortress', baseImageIndex: 1, tintColor: Color(0xFFE53935), rarity: CardRarity.common, flavorText: 'Flies around spreading decay!'),
    MonsterCard(id: 'cf_03', name: 'Tartar Trooper', title: 'Crusty Soldier', worldId: 'cavity_fortress', baseImageIndex: 2, tintColor: Color(0xFFC62828), rarity: CardRarity.common, flavorText: 'Tough and crusty armor!'),
    MonsterCard(id: 'cf_04', name: 'Gingivitis Giant', title: 'Gum Crusher', worldId: 'cavity_fortress', baseImageIndex: 3, tintColor: Color(0xFFB71C1C), rarity: CardRarity.common, flavorText: 'The biggest monster around!'),
    MonsterCard(id: 'cf_05', name: 'Crown Cruncher', title: 'Golden Fang', worldId: 'cavity_fortress', baseImageIndex: 1, tintColor: Color(0xFFFFD54F), rarity: CardRarity.rare, flavorText: 'Has a golden tooth crown!'),
    MonsterCard(id: 'cf_06', name: 'Enamel Eater', title: 'Tooth Destroyer', worldId: 'cavity_fortress', baseImageIndex: 2, tintColor: Color(0xFFFFB300), rarity: CardRarity.rare, flavorText: 'Eats tooth enamel for breakfast!'),
    MonsterCard(id: 'cf_07', name: 'Cavity King', title: 'Supreme Ruler', worldId: 'cavity_fortress', baseImageIndex: 3, tintColor: Color(0xFFFF1744), rarity: CardRarity.epic, flavorText: 'The ultimate boss of all cavities!'),

    // ── World 6: Frozen Tundra ──
    MonsterCard(id: 'ft_01', name: 'Frost Nibbler', title: 'Ice Chomper', worldId: 'frozen_tundra', baseImageIndex: 0, tintColor: Color(0xFF81D4FA), rarity: CardRarity.common, flavorText: 'Nibbles on icicles for breakfast!'),
    MonsterCard(id: 'ft_02', name: 'Blizzard Bug', title: 'Snow Buzzer', worldId: 'frozen_tundra', baseImageIndex: 1, tintColor: Color(0xFF4FC3F7), rarity: CardRarity.common, flavorText: 'Creates tiny snowstorms wherever it flies!'),
    MonsterCard(id: 'ft_03', name: 'Snowball Snapper', title: 'Frozen Fury', worldId: 'frozen_tundra', baseImageIndex: 2, tintColor: Color(0xFF29B6F6), rarity: CardRarity.common, flavorText: 'Throws snowballs at lightning speed!'),
    MonsterCard(id: 'ft_04', name: 'Glacier Gremlin', title: 'Icy Trickster', worldId: 'frozen_tundra', baseImageIndex: 3, tintColor: Color(0xFF039BE5), rarity: CardRarity.common, flavorText: 'Hides inside glaciers and jumps out!'),
    MonsterCard(id: 'ft_05', name: 'Avalanche Yeti', title: 'Mountain Rumbler', worldId: 'frozen_tundra', baseImageIndex: 0, tintColor: Color(0xFF0288D1), rarity: CardRarity.rare, flavorText: 'One stomp starts an avalanche!'),
    MonsterCard(id: 'ft_06', name: 'Hailstorm Hawk', title: 'Sky Freezer', worldId: 'frozen_tundra', baseImageIndex: 2, tintColor: Color(0xFF0277BD), rarity: CardRarity.rare, flavorText: 'Drops hailstones from the clouds!'),
    MonsterCard(id: 'ft_07', name: 'Ice Titan', title: 'Frozen Overlord', worldId: 'frozen_tundra', baseImageIndex: 0, tintColor: Color(0xFF01579B), rarity: CardRarity.epic, flavorText: 'Can freeze an entire planet solid!'),

    // ── World 7: Toxic Jungle ──
    MonsterCard(id: 'tj_01', name: 'Vine Viper', title: 'Leaf Lurker', worldId: 'toxic_jungle', baseImageIndex: 1, tintColor: Color(0xFF66BB6A), rarity: CardRarity.common, flavorText: 'Wraps around trees like a sneaky vine!'),
    MonsterCard(id: 'tj_02', name: 'Spore Spitter', title: 'Puff Blaster', worldId: 'toxic_jungle', baseImageIndex: 2, tintColor: Color(0xFF4CAF50), rarity: CardRarity.common, flavorText: 'Shoots stinky spore clouds!'),
    MonsterCard(id: 'tj_03', name: 'Mossy Muncher', title: 'Green Gobbler', worldId: 'toxic_jungle', baseImageIndex: 3, tintColor: Color(0xFF43A047), rarity: CardRarity.common, flavorText: 'Eats moss faster than you can blink!'),
    MonsterCard(id: 'tj_04', name: 'Thorn Tumbler', title: 'Prickly Roller', worldId: 'toxic_jungle', baseImageIndex: 0, tintColor: Color(0xFF388E3C), rarity: CardRarity.common, flavorText: 'Rolls into a spiky ball to attack!'),
    MonsterCard(id: 'tj_05', name: 'Venom Frog', title: 'Poison Hopper', worldId: 'toxic_jungle', baseImageIndex: 1, tintColor: Color(0xFF2E7D32), rarity: CardRarity.rare, flavorText: 'Its tongue glows bright green!'),
    MonsterCard(id: 'tj_06', name: 'Fungus Fury', title: 'Mushroom Menace', worldId: 'toxic_jungle', baseImageIndex: 3, tintColor: Color(0xFF1B5E20), rarity: CardRarity.rare, flavorText: 'Grows mushrooms on everything it touches!'),
    MonsterCard(id: 'tj_07', name: 'Jungle Hydra', title: 'Overgrowth King', worldId: 'toxic_jungle', baseImageIndex: 1, tintColor: Color(0xFF00C853), rarity: CardRarity.epic, flavorText: 'Has three heads and each one bites!'),

    // ── World 8: Crystal Cave ──
    MonsterCard(id: 'cr_01', name: 'Gem Gnat', title: 'Sparkle Fly', worldId: 'crystal_cave', baseImageIndex: 0, tintColor: Color(0xFF80DEEA), rarity: CardRarity.common, flavorText: 'Glows like a tiny flying diamond!'),
    MonsterCard(id: 'cr_02', name: 'Quartz Crawler', title: 'Cave Creeper', worldId: 'crystal_cave', baseImageIndex: 1, tintColor: Color(0xFF4DD0E1), rarity: CardRarity.common, flavorText: 'Skitters across crystal walls!'),
    MonsterCard(id: 'cr_03', name: 'Prism Pup', title: 'Rainbow Rascal', worldId: 'crystal_cave', baseImageIndex: 2, tintColor: Color(0xFF26C6DA), rarity: CardRarity.common, flavorText: 'Splits light into rainbows when it barks!'),
    MonsterCard(id: 'cr_04', name: 'Stalactite Snail', title: 'Drip Rider', worldId: 'crystal_cave', baseImageIndex: 3, tintColor: Color(0xFF00BCD4), rarity: CardRarity.common, flavorText: 'Hangs from cave ceilings upside down!'),
    MonsterCard(id: 'cr_05', name: 'Diamond Drill', title: 'Gem Borer', worldId: 'crystal_cave', baseImageIndex: 0, tintColor: Color(0xFF00ACC1), rarity: CardRarity.rare, flavorText: 'Drills through solid rock in seconds!'),
    MonsterCard(id: 'cr_06', name: 'Amethyst Angler', title: 'Deep Glower', worldId: 'crystal_cave', baseImageIndex: 1, tintColor: Color(0xFF00838F), rarity: CardRarity.rare, flavorText: 'Lures prey with a glowing crystal lure!'),
    MonsterCard(id: 'cr_07', name: 'Crystal Colossus', title: 'Cavern Guardian', worldId: 'crystal_cave', baseImageIndex: 0, tintColor: Color(0xFF006064), rarity: CardRarity.epic, flavorText: 'Made entirely of unbreakable crystal!'),

    // ── World 9: Storm Citadel ──
    MonsterCard(id: 'sc_01', name: 'Spark Sprite', title: 'Zap Fairy', worldId: 'storm_citadel', baseImageIndex: 2, tintColor: Color(0xFFFFD740), rarity: CardRarity.common, flavorText: 'Tiny but shocks everything it touches!'),
    MonsterCard(id: 'sc_02', name: 'Thunder Tick', title: 'Boom Bug', worldId: 'storm_citadel', baseImageIndex: 3, tintColor: Color(0xFFFFC400), rarity: CardRarity.common, flavorText: 'Makes a tiny thunder sound when it jumps!'),
    MonsterCard(id: 'sc_03', name: 'Lightning Lizard', title: 'Bolt Dasher', worldId: 'storm_citadel', baseImageIndex: 0, tintColor: Color(0xFFFFAB00), rarity: CardRarity.common, flavorText: 'Runs as fast as a lightning bolt!'),
    MonsterCard(id: 'sc_04', name: 'Gale Goblin', title: 'Wind Troubler', worldId: 'storm_citadel', baseImageIndex: 1, tintColor: Color(0xFFFF8F00), rarity: CardRarity.common, flavorText: 'Blows everything away with a sneeze!'),
    MonsterCard(id: 'sc_05', name: 'Cyclone Crab', title: 'Whirlwind Pincher', worldId: 'storm_citadel', baseImageIndex: 2, tintColor: Color(0xFFF57F17), rarity: CardRarity.rare, flavorText: 'Spins so fast it becomes a tornado!'),
    MonsterCard(id: 'sc_06', name: 'Voltage Vulture', title: 'Storm Soarer', worldId: 'storm_citadel', baseImageIndex: 3, tintColor: Color(0xFFE65100), rarity: CardRarity.rare, flavorText: 'Rides lightning bolts through the sky!'),
    MonsterCard(id: 'sc_07', name: 'Storm Emperor', title: 'Thunder Sovereign', worldId: 'storm_citadel', baseImageIndex: 2, tintColor: Color(0xFFFF6D00), rarity: CardRarity.epic, flavorText: 'Commands every storm in the galaxy!'),

    // ── World 10: Dark Dimension ──
    MonsterCard(id: 'dd_01', name: 'Void Mite', title: 'Darkness Nibbler', worldId: 'dark_dimension', baseImageIndex: 0, tintColor: Color(0xFFE040FB), rarity: CardRarity.common, flavorText: 'So dark you can barely see it!'),
    MonsterCard(id: 'dd_02', name: 'Rift Rat', title: 'Dimension Hopper', worldId: 'dark_dimension', baseImageIndex: 1, tintColor: Color(0xFFD500F9), rarity: CardRarity.common, flavorText: 'Jumps between dimensions for fun!'),
    MonsterCard(id: 'dd_03', name: 'Warp Worm', title: 'Space Bender', worldId: 'dark_dimension', baseImageIndex: 2, tintColor: Color(0xFFAA00FF), rarity: CardRarity.common, flavorText: 'Bends space around itself to hide!'),
    MonsterCard(id: 'dd_04', name: 'Null Newt', title: 'Zero Crawler', worldId: 'dark_dimension', baseImageIndex: 3, tintColor: Color(0xFF9C27B0), rarity: CardRarity.common, flavorText: 'Erases footprints as it walks!'),
    MonsterCard(id: 'dd_05', name: 'Entropy Eagle', title: 'Chaos Flyer', worldId: 'dark_dimension', baseImageIndex: 0, tintColor: Color(0xFF8E24AA), rarity: CardRarity.rare, flavorText: 'Its wings scatter reality like dust!'),
    MonsterCard(id: 'dd_06', name: 'Abyss Anaconda', title: 'Deep Dark Coiler', worldId: 'dark_dimension', baseImageIndex: 1, tintColor: Color(0xFF6A1B9A), rarity: CardRarity.rare, flavorText: 'Wraps around entire planets!'),
    MonsterCard(id: 'dd_07', name: 'Dimension Devourer', title: 'Reality Breaker', worldId: 'dark_dimension', baseImageIndex: 3, tintColor: Color(0xFF4A148C), rarity: CardRarity.epic, flavorText: 'Eats entire dimensions for lunch!'),
  ];

  static List<MonsterCard> cardsForWorld(String worldId) =>
      allCards.where((c) => c.worldId == worldId).toList();

  Future<List<String>> getCollectedCardIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_collectedKey) ?? [];
  }

  Future<void> collectCard(String cardId) async {
    final prefs = await SharedPreferences.getInstance();
    final collected = prefs.getStringList(_collectedKey) ?? [];
    if (!collected.contains(cardId)) {
      collected.add(cardId);
      await prefs.setStringList(_collectedKey, collected);
    }
  }

  static const _worldOrder = [
    'candy_crater', 'slime_swamp', 'sugar_volcano',
    'shadow_nebula', 'cavity_fortress',
    'frozen_tundra', 'toxic_jungle', 'crystal_cave',
    'storm_citadel', 'dark_dimension',
  ];

  /// Guaranteed card drop after every brush session.
  /// - Drops from current world first, prioritising uncollected cards.
  /// - If current world is complete, moves to the next incomplete world.
  /// - If ALL 70 cards are collected, drops a random duplicate (isNew = false).
  Future<CardDropResult> guaranteedCardDrop(String currentWorldId) async {
    final rng = Random();
    final collected = await getCollectedCardIds();

    // Find the target world: current world if it has uncollected cards,
    // otherwise the next world with uncollected cards.
    String? targetWorldId;
    final currentIdx = _worldOrder.indexOf(currentWorldId);
    if (currentIdx < 0) {
      targetWorldId = _worldOrder.first;
    } else {
      // Check current world first
      final currentWorldCards = cardsForWorld(currentWorldId);
      final hasUncollected = currentWorldCards.any((c) => !collected.contains(c.id));
      if (hasUncollected) {
        targetWorldId = currentWorldId;
      } else {
        // Search subsequent worlds for uncollected cards
        for (int i = currentIdx + 1; i < _worldOrder.length; i++) {
          final wCards = cardsForWorld(_worldOrder[i]);
          if (wCards.any((c) => !collected.contains(c.id))) {
            targetWorldId = _worldOrder[i];
            break;
          }
        }
        // If nothing after, search earlier worlds
        if (targetWorldId == null) {
          for (int i = 0; i < currentIdx; i++) {
            final wCards = cardsForWorld(_worldOrder[i]);
            if (wCards.any((c) => !collected.contains(c.id))) {
              targetWorldId = _worldOrder[i];
              break;
            }
          }
        }
      }
    }

    // ALL 70 cards collected — drop a random duplicate
    if (targetWorldId == null) {
      final card = allCards[rng.nextInt(allCards.length)];
      final worldCards = cardsForWorld(card.worldId);
      final worldCollectedCount = worldCards.where((c) => collected.contains(c.id)).length;
      return CardDropResult(
        card: card,
        isNew: false,
        worldCollected: worldCollectedCount,
        worldTotal: worldCards.length,
        worldName: _worldNameForId(card.worldId),
      );
    }

    // Pick from uncollected cards in the target world
    final targetCards = cardsForWorld(targetWorldId);
    final uncollected = targetCards.where((c) => !collected.contains(c.id)).toList();

    // Weighted rarity selection among uncollected
    final rarityRoll = rng.nextDouble();
    CardRarity targetRarity;
    if (rarityRoll < 0.10) {
      targetRarity = CardRarity.epic;
    } else if (rarityRoll < 0.35) {
      targetRarity = CardRarity.rare;
    } else {
      targetRarity = CardRarity.common;
    }

    var candidates = uncollected.where((c) => c.rarity == targetRarity).toList();
    if (candidates.isEmpty) candidates = uncollected;

    final card = candidates[rng.nextInt(candidates.length)];
    await collectCard(card.id);

    // Calculate world progress after collecting
    final worldCollectedCount = targetCards.where(
      (c) => collected.contains(c.id) || c.id == card.id,
    ).length;

    return CardDropResult(
      card: card,
      isNew: true,
      worldCollected: worldCollectedCount,
      worldTotal: targetCards.length,
      worldName: _worldNameForId(targetWorldId),
    );
  }

  /// Legacy method kept for backward compatibility.
  /// Delegates to [guaranteedCardDrop] — always returns a card.
  Future<CardDropResult?> rollCardDrop(String currentWorldId, int streak) async {
    return guaranteedCardDrop(currentWorldId);
  }

  static String _worldNameForId(String worldId) {
    const names = {
      'candy_crater': 'Candy Crater',
      'slime_swamp': 'Slime Swamp',
      'sugar_volcano': 'Sugar Volcano',
      'shadow_nebula': 'Shadow Nebula',
      'cavity_fortress': 'Cavity Fortress',
      'frozen_tundra': 'Frozen Tundra',
      'toxic_jungle': 'Toxic Jungle',
      'crystal_cave': 'Crystal Cave',
      'storm_citadel': 'Storm Citadel',
      'dark_dimension': 'Dark Dimension',
    };
    return names[worldId] ?? 'Unknown World';
  }

  /// Progressive card reveal: commons always visible (4),
  /// rares revealed when all commons collected (→6),
  /// epic revealed when all rares collected (→7).
  static List<MonsterCard> visibleCardsForWorld(String worldId, List<String> collectedIds) {
    final worldCards = cardsForWorld(worldId);
    final commons = worldCards.where((c) => c.rarity == CardRarity.common).toList();
    final rares = worldCards.where((c) => c.rarity == CardRarity.rare).toList();
    final epics = worldCards.where((c) => c.rarity == CardRarity.epic).toList();

    final allCommonsCollected = commons.every((c) => collectedIds.contains(c.id));
    final allRaresCollected = rares.every((c) => collectedIds.contains(c.id));

    final visible = <MonsterCard>[...commons];
    if (allCommonsCollected) visible.addAll(rares);
    if (allCommonsCollected && allRaresCollected) visible.addAll(epics);
    return visible;
  }

  int get totalCards => allCards.length;

  Future<int> getCollectedCount() async {
    final collected = await getCollectedCardIds();
    return collected.length;
  }

  /// Get a random uncollected card for "tomorrow's preview" teaser.
  Future<MonsterCard?> getPreviewCard(String currentWorldId) async {
    final collected = await getCollectedCardIds();
    final worldOrder = [
      'candy_crater', 'slime_swamp', 'sugar_volcano',
      'shadow_nebula', 'cavity_fortress',
      'frozen_tundra', 'toxic_jungle', 'crystal_cave',
      'storm_citadel', 'dark_dimension',
    ];
    final currentIdx = worldOrder.indexOf(currentWorldId);
    if (currentIdx < 0) return null;
    final eligibleWorlds = worldOrder.sublist(0, currentIdx + 1);
    final uncollected = allCards
        .where((c) => eligibleWorlds.contains(c.worldId) && !collected.contains(c.id))
        .toList();
    if (uncollected.isEmpty) return null;
    return uncollected[Random().nextInt(uncollected.length)];
  }
}
