/// Streak flame and chest steps — spec
/// docs/superpowers/specs/2026-10-05-brush-flow-and-hooks-design.md §7.1.
/// Pure functions (no I/O, no Flutter) so the rules are easy to test.
library;

enum FlameTier { none, small, big, hot, golden }

enum ChestTier { wooden, silver, gold }

/// Streak days where each flame step starts.
const int kFlameBigAt = 3;
const int kFlameHotAt = 7;
const int kFlameGoldenAt = 14;

FlameTier flameTierFor(int streak) {
  if (streak <= 0) return FlameTier.none;
  if (streak < kFlameBigAt) return FlameTier.small;
  if (streak < kFlameHotAt) return FlameTier.big;
  if (streak < kFlameGoldenAt) return FlameTier.hot;
  return FlameTier.golden;
}

/// Chest look by streak. Same steps as the odds table in
/// victory_screen.dart `_rollChestReward` (under 3 / 3-6 / 7+ days), so a
/// fancier chest really is a better chest.
ChestTier chestTierFor(int streak) {
  if (streak >= kFlameHotAt) return ChestTier.gold;
  if (streak >= kFlameBigAt) return ChestTier.silver;
  return ChestTier.wooden;
}

/// Streak length where the next flame step starts, or null at golden.
int? nextFlameTierAt(int streak) {
  if (streak < kFlameBigAt) return kFlameBigAt;
  if (streak < kFlameHotAt) return kFlameHotAt;
  if (streak < kFlameGoldenAt) return kFlameGoldenAt;
  return null;
}

/// Days of brushing until the next flame step, or null at golden (14+).
int? daysToNextFlameTier(int streak) {
  final next = nextFlameTierAt(streak);
  if (next == null) return null;
  return next - (streak < 0 ? 0 : streak);
}

/// The flame step this brush moved up to (big, hot or golden), or null.
/// Going from none to small is a "new flame", not a step-up.
FlameTier? reachedFlameTier({required int before, required int after}) {
  final was = flameTierFor(before);
  final now = flameTierFor(after);
  if (now.index <= was.index || now == FlameTier.small) return null;
  return now;
}
