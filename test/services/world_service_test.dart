import 'package:flutter_test/flutter_test.dart';
import 'package:brush_quest/services/world_service.dart';

void main() {
  group('WorldService daily modifier', () {
    test('returns deterministic modifier for same date', () {
      final service = WorldService();
      final date = DateTime(2026, 2, 25);
      final a = service.getDailyModifier(date);
      final b = service.getDailyModifier(date);
      expect(a.type, b.type);
      expect(a.title, b.title);
    });

    test('modifier values stay within safe bounds', () {
      final service = WorldService();
      for (int i = 0; i < 30; i++) {
        final m = service.getDailyModifier(DateTime(2026, 1, 1 + i));
        expect(m.damageMultiplier >= 1.0, true);
        expect(m.bossChanceMultiplier >= 1.0, true);
        expect(m.chestBonusStars >= 0, true);
      }
    });
  });
}
