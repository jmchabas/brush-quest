import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:brush_quest/services/card_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CardService', () {
    late CardService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = CardService();
    });

    // ── Card catalog integrity ──

    test('allCards contains exactly 70 cards', () {
      expect(CardService.allCards.length, 70);
    });

    test('every card has a unique id', () {
      final ids = CardService.allCards.map((c) => c.id).toSet();
      expect(ids.length, CardService.allCards.length);
    });

    test('each world has exactly 7 cards', () {
      final worlds = CardService.allCards.map((c) => c.worldId).toSet();
      expect(worlds.length, 10);
      for (final world in worlds) {
        final count = CardService.allCards.where((c) => c.worldId == world).length;
        expect(count, 7, reason: 'World $world should have 7 cards');
      }
    });

    test('each world has 4 common, 2 rare, 1 epic', () {
      final worlds = CardService.allCards.map((c) => c.worldId).toSet();
      for (final world in worlds) {
        final cards = CardService.cardsForWorld(world);
        final commons = cards.where((c) => c.rarity == CardRarity.common).length;
        final rares = cards.where((c) => c.rarity == CardRarity.rare).length;
        final epics = cards.where((c) => c.rarity == CardRarity.epic).length;
        expect(commons, 4, reason: '$world should have 4 commons');
        expect(rares, 2, reason: '$world should have 2 rares');
        expect(epics, 1, reason: '$world should have 1 epic');
      }
    });

    test('cardsForWorld returns only cards matching that world', () {
      final cards = CardService.cardsForWorld('candy_crater');
      expect(cards.length, 7);
      for (final c in cards) {
        expect(c.worldId, 'candy_crater');
      }
    });

    test('cardsForWorld returns empty for unknown world', () {
      final cards = CardService.cardsForWorld('nonexistent_world');
      expect(cards, isEmpty);
    });

    // ── Collection starts empty ──

    test('collection starts empty', () async {
      final ids = await service.getCollectedCardIds();
      expect(ids, isEmpty);
    });

    test('collected count starts at zero', () async {
      final count = await service.getCollectedCount();
      expect(count, 0);
    });

    // ── Collecting cards ──

    test('collectCard adds card to collection', () async {
      await service.collectCard('cc_01');
      final ids = await service.getCollectedCardIds();
      expect(ids, contains('cc_01'));
      expect(ids.length, 1);
    });

    test('collectCard is idempotent (duplicates ignored)', () async {
      await service.collectCard('cc_01');
      await service.collectCard('cc_01');
      final ids = await service.getCollectedCardIds();
      expect(ids.length, 1);
    });

    test('multiple different cards can be collected', () async {
      await service.collectCard('cc_01');
      await service.collectCard('ss_01');
      await service.collectCard('sv_01');
      final ids = await service.getCollectedCardIds();
      expect(ids.length, 3);
      expect(ids, containsAll(['cc_01', 'ss_01', 'sv_01']));
    });

    test('getCollectedCount reflects number of collected cards', () async {
      await service.collectCard('cc_01');
      await service.collectCard('cc_02');
      final count = await service.getCollectedCount();
      expect(count, 2);
    });

    // ── Drop chance ──

    test('dropChance is 40% at streak 0', () {
      expect(CardService.dropChance(0), closeTo(0.40, 0.001));
    });

    test('dropChance increases with streak', () {
      expect(CardService.dropChance(5), closeTo(0.50, 0.001));
      expect(CardService.dropChance(10), closeTo(0.60, 0.001));
    });

    test('dropChance caps at 70%', () {
      expect(CardService.dropChance(100), closeTo(0.70, 0.001));
      expect(CardService.dropChance(20), closeTo(0.70, 0.001));
    });

    // ── rollCardDrop returns null when all collected ──

    test('rollCardDrop returns null when all eligible cards collected', () async {
      // Collect all candy_crater cards
      for (final c in CardService.cardsForWorld('candy_crater')) {
        await service.collectCard(c.id);
      }
      // Run many trials — should always be null
      for (int i = 0; i < 20; i++) {
        final result = await service.rollCardDrop('candy_crater', 15);
        expect(result, isNull);
      }
    });

    // ── Progressive card visibility ──

    test('visibleCardsForWorld shows only commons initially', () {
      final visible = CardService.visibleCardsForWorld('candy_crater', []);
      expect(visible.length, 4);
      for (final c in visible) {
        expect(c.rarity, CardRarity.common);
      }
    });

    test('visibleCardsForWorld reveals rares after all commons collected', () {
      final commonIds = CardService.cardsForWorld('candy_crater')
          .where((c) => c.rarity == CardRarity.common)
          .map((c) => c.id)
          .toList();
      final visible = CardService.visibleCardsForWorld('candy_crater', commonIds);
      expect(visible.length, 6); // 4 common + 2 rare
      final rareVisible = visible.where((c) => c.rarity == CardRarity.rare);
      expect(rareVisible.length, 2);
    });

    test('visibleCardsForWorld does NOT reveal epic with only commons collected', () {
      final commonIds = CardService.cardsForWorld('candy_crater')
          .where((c) => c.rarity == CardRarity.common)
          .map((c) => c.id)
          .toList();
      final visible = CardService.visibleCardsForWorld('candy_crater', commonIds);
      final epicVisible = visible.where((c) => c.rarity == CardRarity.epic);
      expect(epicVisible, isEmpty);
    });

    test('visibleCardsForWorld reveals epic after all commons and rares collected', () {
      final commonAndRareIds = CardService.cardsForWorld('candy_crater')
          .where((c) => c.rarity != CardRarity.epic)
          .map((c) => c.id)
          .toList();
      final visible = CardService.visibleCardsForWorld('candy_crater', commonAndRareIds);
      expect(visible.length, 7); // all 7
      final epicVisible = visible.where((c) => c.rarity == CardRarity.epic);
      expect(epicVisible.length, 1);
    });

    // ── Preview card ──

    test('getPreviewCard returns a card for valid world', () async {
      final card = await service.getPreviewCard('candy_crater');
      expect(card, isNotNull);
      expect(card!.worldId, 'candy_crater');
    });

    test('getPreviewCard returns null when all eligible cards collected', () async {
      // Collect all candy_crater cards
      for (final c in CardService.cardsForWorld('candy_crater')) {
        await service.collectCard(c.id);
      }
      final card = await service.getPreviewCard('candy_crater');
      expect(card, isNull);
    });

    test('getPreviewCard returns null for invalid world', () async {
      final card = await service.getPreviewCard('nonexistent_world');
      expect(card, isNull);
    });

    test('getPreviewCard can return cards from previous worlds', () async {
      // Collect all candy_crater cards so preview must come from slime_swamp pool
      for (final c in CardService.cardsForWorld('candy_crater')) {
        await service.collectCard(c.id);
      }
      final card = await service.getPreviewCard('slime_swamp');
      expect(card, isNotNull);
      // Should be from slime_swamp since candy_crater is fully collected
      expect(card!.worldId, 'slime_swamp');
    });

    // ── MonsterCard properties ──

    test('MonsterCard imagePath returns correct asset path', () {
      final card = CardService.allCards.first;
      expect(card.imagePath, startsWith('assets/images/monster_'));
      expect(card.imagePath, endsWith('.png'));
    });

    test('MonsterCard rarityLabel matches enum', () {
      final common = CardService.allCards.firstWhere((c) => c.rarity == CardRarity.common);
      final rare = CardService.allCards.firstWhere((c) => c.rarity == CardRarity.rare);
      final epic = CardService.allCards.firstWhere((c) => c.rarity == CardRarity.epic);
      expect(common.rarityLabel, 'COMMON');
      expect(rare.rarityLabel, 'RARE');
      expect(epic.rarityLabel, 'EPIC');
    });

    test('totalCards matches allCards.length', () {
      expect(service.totalCards, 70);
    });
  });
}
