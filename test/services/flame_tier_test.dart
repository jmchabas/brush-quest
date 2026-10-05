import 'package:brush_quest/services/flame_tier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('flameTierFor', () {
    test('steps at 1, 3, 7 and 14 days', () {
      expect(flameTierFor(0), FlameTier.none);
      expect(flameTierFor(1), FlameTier.small);
      expect(flameTierFor(2), FlameTier.small);
      expect(flameTierFor(3), FlameTier.big);
      expect(flameTierFor(6), FlameTier.big);
      expect(flameTierFor(7), FlameTier.hot);
      expect(flameTierFor(13), FlameTier.hot);
      expect(flameTierFor(14), FlameTier.golden);
      expect(flameTierFor(400), FlameTier.golden);
    });
    test('negative streak is none', () {
      expect(flameTierFor(-1), FlameTier.none);
    });
  });

  group('chestTierFor (matches _rollChestReward odds steps)', () {
    test('wooden under 3, silver 3-6, gold 7+', () {
      expect(chestTierFor(0), ChestTier.wooden);
      expect(chestTierFor(2), ChestTier.wooden);
      expect(chestTierFor(3), ChestTier.silver);
      expect(chestTierFor(6), ChestTier.silver);
      expect(chestTierFor(7), ChestTier.gold);
      expect(chestTierFor(30), ChestTier.gold);
    });
  });

  group('days to next flame step', () {
    test('counts down to 3, 7, 14 and stops at golden', () {
      expect(daysToNextFlameTier(0), 3);
      expect(daysToNextFlameTier(1), 2);
      expect(daysToNextFlameTier(2), 1);
      expect(daysToNextFlameTier(3), 4);
      expect(daysToNextFlameTier(6), 1);
      expect(daysToNextFlameTier(7), 7);
      expect(daysToNextFlameTier(13), 1);
      expect(daysToNextFlameTier(14), isNull);
      expect(nextFlameTierAt(5), 7);
      expect(nextFlameTierAt(20), isNull);
    });
  });

  group('reachedFlameTier', () {
    test('reports big, hot and golden step-ups only', () {
      expect(reachedFlameTier(before: 2, after: 3), FlameTier.big);
      expect(reachedFlameTier(before: 6, after: 7), FlameTier.hot);
      expect(reachedFlameTier(before: 13, after: 14), FlameTier.golden);
    });
    test('no step-up within a step, on a second brush, or when starting', () {
      expect(reachedFlameTier(before: 3, after: 4), isNull);
      expect(reachedFlameTier(before: 5, after: 5), isNull);
      expect(reachedFlameTier(before: 0, after: 1), isNull); // a new flame
      expect(reachedFlameTier(before: 9, after: 1), isNull); // broken streak
    });
  });
}
