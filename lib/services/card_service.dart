import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CardRarity { common, rare, epic }

class MonsterCard {
  final String id;
  final String name;
  final String title;
  final String worldId;
  final int baseImageIndex; // 0-3 → monster_blue, monster_green, monster_orange, monster_red
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
    'assets/images/monster_blue.png',
    'assets/images/monster_green.png',
    'assets/images/monster_orange.png',
    'assets/images/monster_red.png',
  ];
}

class CardDropResult {
  final MonsterCard card;
  final bool isNew;
  final int fragments; // fragments awarded if duplicate

  const CardDropResult({
    required this.card,
    required this.isNew,
    this.fragments = 0,
  });
}

class CardService {
  static const _collectedKey = 'collected_cards';
  static const _fragmentsKey = 'card_fragments';

  // ~40% base drop chance, boosted by streak
  static double dropChance(int streak) => (0.40 + streak * 0.02).clamp(0.0, 0.70);

  // 35 cards: 7 per world (4 common, 2 rare, 1 epic)
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
  ];

  static List<MonsterCard> cardsForWorld(String worldId) =>
      allCards.where((c) => c.worldId == worldId).toList();

  Future<List<String>> getCollectedCardIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_collectedKey) ?? [];
  }

  Future<int> getFragments() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_fragmentsKey) ?? 0;
  }

  Future<void> addFragments(int count) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_fragmentsKey) ?? 0;
    await prefs.setInt(_fragmentsKey, current + count);
  }

  Future<void> collectCard(String cardId) async {
    final prefs = await SharedPreferences.getInstance();
    final collected = prefs.getStringList(_collectedKey) ?? [];
    if (!collected.contains(cardId)) {
      collected.add(cardId);
      await prefs.setStringList(_collectedKey, collected);
    }
  }

  /// Roll for a card drop after brushing. Returns null if no drop.
  Future<CardDropResult?> rollCardDrop(String currentWorldId, int streak) async {
    final rng = Random();
    if (rng.nextDouble() > dropChance(streak)) return null;

    final collected = await getCollectedCardIds();

    // Pool: current world + all previous worlds
    final worldOrder = [
      'candy_crater', 'slime_swamp', 'sugar_volcano',
      'shadow_nebula', 'cavity_fortress',
    ];
    final currentIdx = worldOrder.indexOf(currentWorldId);
    final eligibleWorlds = worldOrder.sublist(0, currentIdx + 1);
    final pool = allCards.where((c) => eligibleWorlds.contains(c.worldId)).toList();
    if (pool.isEmpty) return null;

    // Weighted rarity selection
    final rarityRoll = rng.nextDouble();
    CardRarity targetRarity;
    if (rarityRoll < 0.10) {
      targetRarity = CardRarity.epic;
    } else if (rarityRoll < 0.35) {
      targetRarity = CardRarity.rare;
    } else {
      targetRarity = CardRarity.common;
    }

    // Filter pool by rarity, fall back to any rarity
    var candidates = pool.where((c) => c.rarity == targetRarity).toList();
    if (candidates.isEmpty) candidates = pool;

    // Prefer uncollected cards
    final uncollected = candidates.where((c) => !collected.contains(c.id)).toList();
    final MonsterCard card;
    if (uncollected.isNotEmpty) {
      card = uncollected[rng.nextInt(uncollected.length)];
      await collectCard(card.id);
      return CardDropResult(card: card, isNew: true);
    } else {
      // Duplicate → give 1 fragment
      card = candidates[rng.nextInt(candidates.length)];
      await addFragments(1);
      return CardDropResult(card: card, isNew: false, fragments: 1);
    }
  }

  /// Redeem 3 fragments for a random uncollected card from any eligible world.
  Future<MonsterCard?> redeemFragments(String currentWorldId) async {
    final fragments = await getFragments();
    if (fragments < 3) return null;

    final collected = await getCollectedCardIds();
    final worldOrder = [
      'candy_crater', 'slime_swamp', 'sugar_volcano',
      'shadow_nebula', 'cavity_fortress',
    ];
    final currentIdx = worldOrder.indexOf(currentWorldId);
    final eligibleWorlds = worldOrder.sublist(0, currentIdx + 1);
    final uncollected = allCards
        .where((c) => eligibleWorlds.contains(c.worldId) && !collected.contains(c.id))
        .toList();
    if (uncollected.isEmpty) return null;

    final rng = Random();
    final card = uncollected[rng.nextInt(uncollected.length)];
    await collectCard(card.id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_fragmentsKey, fragments - 3);
    return card;
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
    ];
    final currentIdx = worldOrder.indexOf(currentWorldId);
    final eligibleWorlds = worldOrder.sublist(0, currentIdx + 1);
    final uncollected = allCards
        .where((c) => eligibleWorlds.contains(c.worldId) && !collected.contains(c.id))
        .toList();
    if (uncollected.isEmpty) return null;
    return uncollected[Random().nextInt(uncollected.length)];
  }
}
