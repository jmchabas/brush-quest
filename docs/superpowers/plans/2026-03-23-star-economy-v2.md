# Star Economy v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform Brush Quest from a cumulative-threshold economy into a spend-to-buy shop economy with a monster trophy wall, replacing the current card system.

**Architecture:** Three layered phases — (1) Foundation: retrofit StreakService with wallet/rank split and spending capability, (2) Shop: convert hero/weapon unlocks to purchases with a redesigned shop screen, (3) Trophy Wall: replace the 70-card album with a 25-monster deterministic capture system tied to brushing. Each phase produces working, testable software. Profile system deferred to a separate plan (pre-launch blocker but architecturally independent).

**Tech Stack:** Flutter/Dart, SharedPreferences, Firebase Firestore (sync), audioplayers (SFX/voice)

---

## Scope & Dependencies

```
Phase 1: Foundation (Tasks 1-3)
  StreakService wallet/rank split
  ├── No external dependencies
  └── All downstream code continues working (backward-compatible)

Phase 2: Shop Economy (Tasks 4-7)
  Hero/Weapon price system + Shop screen + Home/Victory updates
  ├── Depends on: Phase 1 (spendStars method)
  └── Can ship independently of Phase 3

Phase 3: Trophy Wall (Tasks 8-11)
  TrophyService + Trophy capture in brushing + TrophyWallScreen
  ├── Depends on: Phase 1 (bonus stars from captures)
  └── Can ship independently of Phase 2

Phase 4: Sync & Migration (Task 12)
  ├── Depends on: Phases 1-3 (final key inventory)
  └── Must ship with first release
```

**Files Overview:**

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `lib/services/streak_service.dart` | Add wallet/rank split, spendStars(), new earning rates |
| Modify | `lib/services/hero_service.dart` | Replace `unlockAt` with `price`, deduct stars on purchase |
| Modify | `lib/services/weapon_service.dart` | Same as hero_service |
| Create | `lib/services/trophy_service.dart` | 25 trophy monsters, deterministic capture, wall state |
| Modify | `lib/services/sync_service.dart` | Sync new keys (star_wallet, trophy_*, etc.) |
| Modify | `lib/screens/home_screen.dart` | Display Ranger Rank + wallet instead of single star count |
| Modify | `lib/screens/victory_screen.dart` | New earning display, trophy capture instead of card drop |
| Modify | `lib/screens/hero_shop_screen.dart` | Price-based shop with buy/confirm flow, 2 tabs |
| Create | `lib/screens/trophy_wall_screen.dart` | Per-world trophy wall, replaces card_album_screen |
| Modify | `lib/screens/brushing_screen.dart` | Connect phase monsters to trophy monsters |
| Deprecate | `lib/services/card_service.dart` | Replaced by trophy_service (keep for migration) |
| Deprecate | `lib/screens/card_album_screen.dart` | Replaced by trophy_wall_screen |
| Modify | `test/services/streak_service_test.dart` | Tests for wallet, spending, new earning rates |
| Create | `test/services/trophy_service_test.dart` | Trophy capture, wall completion, deterministic drops |
| Modify | `test/services/hero_service_test.dart` | Tests for price-based purchases |
| Modify | `test/services/weapon_service_test.dart` | Tests for price-based purchases |

---

## PHASE 1: FOUNDATION — Wallet/Rank Split

### Task 1: StreakService — Wallet and Ranger Rank

The core change: `total_stars` becomes the Ranger Rank (lifetime, never drops). A new `star_wallet` key tracks spendable balance. All star earnings now credit BOTH. A new `spendStars()` method deducts from wallet only.

**Files:**
- Modify: `lib/services/streak_service.dart`
- Modify: `test/services/streak_service_test.dart`

- [ ] **Step 1: Write failing tests for wallet/rank split**

In `test/services/streak_service_test.dart`, add a new test group:

```dart
group('Wallet and Ranger Rank', () {
  test('recordBrush credits both wallet and ranger rank', () async {
    final service = StreakService();
    await service.recordBrush();

    expect(await service.getWallet(), 2);       // New: 2 stars per brush
    expect(await service.getRangerRank(), 2);    // Lifetime total
  });

  test('spendStars deducts from wallet only', () async {
    final service = StreakService();
    await service.recordBrush(); // +2 to both
    await service.recordBrush(); // +2 to both → wallet=4, rank=4

    final success = await service.spendStars(3);
    expect(success, true);
    expect(await service.getWallet(), 1);        // 4 - 3
    expect(await service.getRangerRank(), 4);     // Unchanged
  });

  test('spendStars fails when insufficient balance', () async {
    final service = StreakService();
    await service.recordBrush(); // wallet=2

    final success = await service.spendStars(5);
    expect(success, false);
    expect(await service.getWallet(), 2);        // Unchanged
  });

  test('spendStars rejects zero and negative amounts', () async {
    final service = StreakService();
    await service.recordBrush();

    expect(await service.spendStars(0), false);
    expect(await service.spendStars(-1), false);
  });

  test('addBonusStars credits both wallet and rank', () async {
    final service = StreakService();
    await service.addBonusStars(5);

    expect(await service.getWallet(), 5);
    expect(await service.getRangerRank(), 5);
  });

  test('getTotalStars still works as alias for ranger rank (backward compat)', () async {
    final service = StreakService();
    await service.recordBrush();

    // getTotalStars is now an alias for getRangerRank
    expect(await service.getTotalStars(), await service.getRangerRank());
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/jimchabas/Projects/brush-quest && flutter test test/services/streak_service_test.dart`
Expected: FAIL — `getWallet`, `getRangerRank`, `spendStars` don't exist yet

- [ ] **Step 3: Implement wallet/rank split in StreakService**

In `lib/services/streak_service.dart`:

1. Add new key constant:
```dart
static const _keyStarWallet = 'star_wallet';
```

2. Change `recordBrush()` — line 79, change `starsEarned` from 1 to 2, and credit wallet:
```dart
const starsEarned = 2;
```

After the existing `await prefs.setInt(_keyTotalStars, totalStars);` (line 113), add:
```dart
// Credit wallet (spendable balance)
int wallet = prefs.getInt(_keyStarWallet) ?? 0;
wallet += starsEarned;
await prefs.setInt(_keyStarWallet, wallet);
```

3. Add new methods after `addBonusStars()`:
```dart
Future<int> getWallet() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt(_keyStarWallet) ?? 0;
}

Future<int> getRangerRank() async {
  return getTotalStars(); // Ranger Rank IS the lifetime total
}

/// Spend stars from the wallet. Returns true if successful.
/// Ranger Rank is never affected by spending.
Future<bool> spendStars(int amount) async {
  if (amount <= 0) return false;
  final prefs = await SharedPreferences.getInstance();
  final wallet = prefs.getInt(_keyStarWallet) ?? 0;
  if (wallet < amount) return false;
  await prefs.setInt(_keyStarWallet, wallet - amount);
  return true;
}
```

4. Update `addBonusStars()` to also credit wallet:
```dart
Future<void> addBonusStars(int amount) async {
  if (amount <= 0) return;
  final prefs = await SharedPreferences.getInstance();
  final current = prefs.getInt(_keyTotalStars) ?? 0;
  await prefs.setInt(_keyTotalStars, current + amount);
  // Also credit wallet
  final wallet = prefs.getInt(_keyStarWallet) ?? 0;
  await prefs.setInt(_keyStarWallet, wallet + amount);
}
```

- [ ] **Step 4: Update existing tests for 2-star base rate**

Existing tests assert `starsEarned == 1` and `stars == 1`. Update them:
- `test/services/streak_service_test.dart` line 21: change `expect(outcome.starsEarned, 1)` → `expect(outcome.starsEarned, 2)`
- Line 22: `expect(stars, 1)` → `expect(stars, 2)`
- Line 29: `expect(second.starsEarned, 1)` → `expect(second.starsEarned, 2)`
- Line 30: `expect(stars, 2)` → `expect(stars, 4)`
- Line 39: `expect(outcome.starsEarned, 1)` → `expect(outcome.starsEarned, 2)`
- Line 43: `expect(stars, 5)` → `expect(stars, 10)`

- [ ] **Step 5: Run all tests**

Run: `cd /Users/jimchabas/Projects/brush-quest && flutter test test/services/streak_service_test.dart`
Expected: ALL PASS

- [ ] **Step 6: Run dart analyze**

Run: `cd /Users/jimchabas/Projects/brush-quest && dart analyze lib/services/streak_service.dart`
Expected: No issues found

- [ ] **Step 7: Commit**

```bash
cd /Users/jimchabas/Projects/brush-quest
git add lib/services/streak_service.dart test/services/streak_service_test.dart
git commit -m "feat: add wallet/rank split to StreakService

Stars now earned at 2 per brush (was 1). New star_wallet key tracks
spendable balance separate from total_stars (Ranger Rank). Added
spendStars() for the shop economy. Backward compatible — getTotalStars()
still returns lifetime total."
```

---

### Task 2: Streak Bonuses — Daily Completion + Streak Multiplier

Add the new earning bonuses: +1 for completing both AM+PM, +1/+2 for streak length.

**Files:**
- Modify: `lib/services/streak_service.dart`
- Modify: `test/services/streak_service_test.dart`

- [ ] **Step 1: Write failing tests for streak bonuses**

```dart
group('Streak bonuses', () {
  test('daily completion bonus awards +1 when both slots done', () async {
    final service = StreakService();
    // Morning brush
    await service.recordBrush();
    // Simulate evening by checking slot logic
    // Note: Both brushes in same test will be same slot (same hour).
    // We need to test the bonus calculation separately.
    final bonus = service.calculateStreakBonus(streak: 1, bothSlotsDone: true);
    expect(bonus, 1); // +1 for daily completion
  });

  test('streak 3+ adds +1 per brush', () async {
    final bonus = StreakService().calculateStreakBonus(streak: 3, bothSlotsDone: false);
    expect(bonus, 1); // +1 streak bonus
  });

  test('streak 7+ adds +2 per brush (replaces +1)', () async {
    final bonus = StreakService().calculateStreakBonus(streak: 7, bothSlotsDone: false);
    expect(bonus, 2); // +2 streak bonus (not +1)
  });

  test('streak 7+ with both slots gives +3 total bonus', () async {
    final bonus = StreakService().calculateStreakBonus(streak: 7, bothSlotsDone: true);
    expect(bonus, 3); // +2 streak + 1 daily completion
  });

  test('streak 0-2 with one slot gives no bonus', () async {
    final bonus = StreakService().calculateStreakBonus(streak: 2, bothSlotsDone: false);
    expect(bonus, 0);
  });
});
```

- [ ] **Step 2: Run tests — verify fail**

Run: `cd /Users/jimchabas/Projects/brush-quest && flutter test test/services/streak_service_test.dart`
Expected: FAIL — `calculateStreakBonus` doesn't exist

- [ ] **Step 3: Implement calculateStreakBonus and integrate into recordBrush**

Add to `StreakService`:
```dart
/// Calculate bonus stars from streak length and daily slot completion.
/// Called after recordBrush to determine additional earnings.
int calculateStreakBonus({required int streak, required bool bothSlotsDone}) {
  int bonus = 0;
  if (bothSlotsDone) bonus += 1;        // Daily completion
  if (streak >= 7) {
    bonus += 2;                          // 7+ day streak
  } else if (streak >= 3) {
    bonus += 1;                          // 3+ day streak
  }
  return bonus;
}
```

Update `recordBrush()` to return a richer `BrushOutcome` that includes the bonus. After streak calculation (line 102), add:
```dart
// Calculate streak bonus
final slots = TodaySlotsStatus(
  morningDone: prefs.getString(_keyMorningDoneDate) == today,
  eveningDone: prefs.getString(_keyEveningDoneDate) == today,
);
final streakBonus = calculateStreakBonus(
  streak: streak,
  bothSlotsDone: slots.morningDone && slots.eveningDone,
);
final totalEarned = starsEarned + streakBonus;
```

Then use `totalEarned` instead of `starsEarned` when crediting:
```dart
totalStars += totalEarned;
await prefs.setInt(_keyTotalStars, totalStars);
int wallet = prefs.getInt(_keyStarWallet) ?? 0;
wallet += totalEarned;
await prefs.setInt(_keyStarWallet, wallet);
```

Update `BrushOutcome` to include bonus breakdown:
```dart
class BrushOutcome {
  final int baseStars;
  final int streakBonus;
  final int starsEarned; // baseStars + streakBonus
  final BrushSlot slot;
  final bool newSlotCompleted;

  const BrushOutcome({
    required this.baseStars,
    required this.streakBonus,
    required this.starsEarned,
    required this.slot,
    required this.newSlotCompleted,
  });
}
```

- [ ] **Step 4: Update existing tests for BrushOutcome shape change**

Any test that accesses `outcome.starsEarned` still works. Tests that construct `BrushOutcome` directly need the new fields.

- [ ] **Step 5: Run all streak_service tests**

Run: `cd /Users/jimchabas/Projects/brush-quest && flutter test test/services/streak_service_test.dart`
Expected: ALL PASS

- [ ] **Step 6: Commit**

```bash
cd /Users/jimchabas/Projects/brush-quest
git add lib/services/streak_service.dart test/services/streak_service_test.dart
git commit -m "feat: add streak bonuses to star earnings

+1 for completing both AM+PM slots, +1 at 3+ day streak, +2 at 7+ day
streak. BrushOutcome now includes baseStars and streakBonus breakdown."
```

---

### Task 3: Fix Victory Screen Card Image Bug

The codebase scan found a broken image path at `victory_screen.dart` line 670. Fix it while we're touching this file.

**Files:**
- Modify: `lib/screens/victory_screen.dart:670`

- [ ] **Step 1: Fix the image path**

At line 670, change:
```dart
'assets/images/monster_${card.baseImageIndex + 1}.png',
```
to:
```dart
card.imagePath,
```

The `MonsterCard.imagePath` getter correctly maps `baseImageIndex` to `monster_purple.png`, `monster_green.png`, etc.

- [ ] **Step 2: Run dart analyze**

Run: `cd /Users/jimchabas/Projects/brush-quest && dart analyze lib/screens/victory_screen.dart`
Expected: No issues

- [ ] **Step 3: Commit**

```bash
cd /Users/jimchabas/Projects/brush-quest
git add lib/screens/victory_screen.dart
git commit -m "fix: use card.imagePath for victory screen card reveal

Was using monster_\${baseImageIndex + 1}.png which generates nonexistent
paths. The MonsterCard.imagePath getter maps correctly to the actual
monster_purple/green/orange/red.png assets."
```

---

## PHASE 2: SHOP ECONOMY

### Task 4: HeroService — Price-Based Purchases

Replace cumulative `unlockAt` thresholds with `price` that deducts stars via `spendStars()`.

**Files:**
- Modify: `lib/services/hero_service.dart`
- Modify: `test/services/hero_service_test.dart`

- [ ] **Step 1: Write failing tests for price-based purchases**

```dart
group('Price-based purchases', () {
  test('purchaseHero deducts stars from wallet', () async {
    // Seed wallet with enough stars
    SharedPreferences.setMockInitialValues({
      'star_wallet': 20,
      'total_stars': 20,
    });
    final heroService = HeroService();

    // Frost costs 15 stars
    final success = await heroService.purchaseHero('frost');
    expect(success, true);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('star_wallet'), 5); // 20 - 15
    expect(prefs.getInt('total_stars'), 20); // Rank unchanged
  });

  test('purchaseHero fails with insufficient wallet', () async {
    SharedPreferences.setMockInitialValues({
      'star_wallet': 10,
      'total_stars': 50,
    });
    final heroService = HeroService();

    // Frost costs 15
    final success = await heroService.purchaseHero('frost');
    expect(success, false);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('star_wallet'), 10); // Unchanged
  });

  test('purchaseHero returns true without deducting if already owned', () async {
    SharedPreferences.setMockInitialValues({
      'star_wallet': 50,
      'total_stars': 50,
      'unlocked_heroes': ['blaze', 'frost'],
    });
    final heroService = HeroService();

    final success = await heroService.purchaseHero('frost');
    expect(success, true);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('star_wallet'), 50); // Not deducted — already owned
  });
});
```

- [ ] **Step 2: Run tests — verify fail**

Run: `cd /Users/jimchabas/Projects/brush-quest && flutter test test/services/hero_service_test.dart`
Expected: FAIL — `purchaseHero` doesn't exist

- [ ] **Step 3: Implement price-based purchases**

In `lib/services/hero_service.dart`:

1. Rename `unlockAt` to `price` in `HeroCharacter` class and all hero definitions. Update prices per the approved design:

```dart
class HeroCharacter {
  // ... existing fields ...
  final int price;  // Was: unlockAt
  // ...
}
```

Hero prices (adjusted from thresholds to purchase prices):
| Hero | Old unlockAt | New price |
|------|-------------|-----------|
| Blaze | 0 (starter) | 0 (starter) |
| Frost | 14 | 15 |
| Bolt | 30 | 20 |
| Shadow | 50 | 30 |
| Leaf | 74 | 35 |
| Nova | 98 | 40 |

2. Replace `unlockHero()` with `purchaseHero()`:

```dart
Future<bool> purchaseHero(String heroId) async {
  if (_purchasing) return false;
  _purchasing = true;
  try {
    final hero = getHeroById(heroId);
    if (hero.id != heroId) return false;
    final prefs = await SharedPreferences.getInstance();

    final unlocked = prefs.getStringList(_unlockedKey) ?? ['blaze'];
    if (unlocked.contains(heroId)) return true; // Already owned

    if (hero.price == 0) {
      // Starter hero — free
      unlocked.add(heroId);
      await prefs.setStringList(_unlockedKey, unlocked);
      return true;
    }

    // Deduct from wallet
    final success = await StreakService().spendStars(hero.price);
    if (!success) return false;

    unlocked.add(heroId);
    await prefs.setStringList(_unlockedKey, unlocked);
    return true;
  } finally {
    _purchasing = false;
  }
}
```

3. Keep `unlockHero()` as a deprecated wrapper for backward compatibility during migration:
```dart
@Deprecated('Use purchaseHero instead')
Future<bool> unlockHero(String heroId) => purchaseHero(heroId);
```

4. Update `getNextLockedHero()` → sorted by price (already ordered correctly).

- [ ] **Step 4: Update existing hero_service tests**

Replace references to `unlockAt` with `price`. Update threshold checks to wallet checks.

- [ ] **Step 5: Run all hero tests**

Run: `cd /Users/jimchabas/Projects/brush-quest && flutter test test/services/hero_service_test.dart`
Expected: ALL PASS

- [ ] **Step 6: Commit**

```bash
cd /Users/jimchabas/Projects/brush-quest
git add lib/services/hero_service.dart test/services/hero_service_test.dart
git commit -m "feat: convert heroes to price-based purchases

Replace unlockAt thresholds with price field. purchaseHero() now deducts
from star wallet via StreakService.spendStars(). Old unlockHero() kept
as deprecated wrapper. Prices: Frost=15, Bolt=20, Shadow=30, Leaf=35, Nova=40."
```

---

### Task 5: WeaponService — Price-Based Purchases

Identical pattern to Task 4 for weapons.

**Files:**
- Modify: `lib/services/weapon_service.dart`
- Modify: `test/services/weapon_service_test.dart`

- [ ] **Step 1: Write failing tests (mirror Task 4 pattern)**

Same test structure as hero tests, adapted for weapon IDs and prices.

- [ ] **Step 2: Run tests — verify fail**

- [ ] **Step 3: Implement price-based weapon purchases**

Weapon prices (adjusted from thresholds):
| Weapon | Old unlockAt | New price |
|--------|-------------|-----------|
| Star Blaster | 0 (starter) | 0 (starter) |
| Flame Sword | 6 | 10 |
| Ice Hammer | 22 | 15 |
| Lightning Wand | 40 | 18 |
| Vine Whip | 62 | 22 |
| Cosmic Burst | 88 | 25 |

Same pattern: rename `unlockAt` → `price`, add `purchaseWeapon()`, deprecate `unlockWeapon()`.

- [ ] **Step 4: Update existing tests**

- [ ] **Step 5: Run all weapon tests**

Run: `cd /Users/jimchabas/Projects/brush-quest && flutter test test/services/weapon_service_test.dart`
Expected: ALL PASS

- [ ] **Step 6: Commit**

```bash
cd /Users/jimchabas/Projects/brush-quest
git add lib/services/weapon_service.dart test/services/weapon_service_test.dart
git commit -m "feat: convert weapons to price-based purchases

Same pattern as heroes. Prices: Flame Sword=10, Ice Hammer=15,
Lightning Wand=18, Vine Whip=22, Cosmic Burst=25."
```

---

### Task 6: Shop Screen — Buy Flow with Prices

Redesign `hero_shop_screen.dart` to show prices, wallet balance, buy confirmation, and purchase animations.

**Files:**
- Modify: `lib/screens/hero_shop_screen.dart`

- [ ] **Step 1: Update header to show Ranger Rank + Wallet**

Replace the current star count display (line 29, `_stars`) with two displays:
- Ranger Rank: shield icon + large number (left side of header)
- Star Wallet: coin icon + number (right side of header)

Load both in `_loadData()`:
```dart
final wallet = await _streakService.getWallet();
final rank = await _streakService.getRangerRank();
```

- [ ] **Step 2: Update hero/weapon tiles to show prices**

Each tile currently shows:
- Locked: grayed out, shows `unlockAt` threshold
- Unlocked: full color, tappable to select

Change to:
- Unowned + affordable: full color with price tag + pulsing "BUY" indicator
- Unowned + unaffordable: slightly dimmed, price tag shown, "X more stars" label
- Owned + selected: full color with checkmark
- Owned + unselected: full color, tappable to equip

Display price as a row of star icon + number: `⭐ 15`

- [ ] **Step 3: Add purchase confirmation dialog**

For items costing > 10 stars, show confirmation:
```dart
Future<bool> _confirmPurchase(String itemName, int price) async {
  return await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Get $itemName?',
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.star, color: Colors.amber, size: 28),
            const SizedBox(width: 4),
            Text('$price', style: const TextStyle(color: Colors.amber, fontSize: 28, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not yet', style: TextStyle(color: Colors.white54, fontSize: 18)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('YES!', style: TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold)),
            ),
          ]),
        ],
      ),
    ),
  ) ?? false;
}
```

- [ ] **Step 4: Update _onHeroTap and _onWeaponTap to use purchase flow**

Replace the current threshold-check logic (lines 68-116) with:
```dart
Future<void> _onHeroTap(HeroCharacter hero) async {
  if (_unlockedHeroes.contains(hero.id)) {
    // Already owned — equip
    await _heroService.selectHero(hero.id);
    HapticFeedback.mediumImpact();
    _playSelectionVoice(AudioService().heroPickerVoiceFor(hero.id));
    await _loadData();
  } else if (_wallet >= hero.price) {
    // Can afford — confirm and purchase
    if (hero.price > 10) {
      final confirmed = await _confirmPurchase(hero.name, hero.price);
      if (!confirmed) return;
    }
    final success = await _heroService.purchaseHero(hero.id);
    if (success) {
      await _heroService.selectHero(hero.id);
      HapticFeedback.heavyImpact();
      AnalyticsService().logHeroUnlock(heroId: hero.id, starsAtUnlock: _rank);
      if (mounted) _showHeroUnlockAnimation(hero);
      await _loadData();
    }
  } else {
    // Can't afford
    HapticFeedback.lightImpact();
    _playSelectionVoice(AudioService().heroPickerVoiceFor(hero.id));
    AudioService().playVoice('voice_need_stars.mp3');
  }
}
```

Same pattern for `_onWeaponTap`.

- [ ] **Step 5: Run dart analyze**

Run: `cd /Users/jimchabas/Projects/brush-quest && dart analyze lib/screens/hero_shop_screen.dart`
Expected: No issues

- [ ] **Step 6: Commit**

```bash
cd /Users/jimchabas/Projects/brush-quest
git add lib/screens/hero_shop_screen.dart
git commit -m "feat: shop screen with price-based purchases

Shows Ranger Rank + wallet in header. Hero/weapon tiles display prices.
Confirmation dialog for items > 10 stars. Wallet balance updates after
purchase. Voice feedback for can't-afford state."
```

---

### Task 7: Home Screen + Victory Screen — Wallet/Rank Display

Update both screens to show the dual-number display and new earning rates.

**Files:**
- Modify: `lib/screens/home_screen.dart`
- Modify: `lib/screens/victory_screen.dart`

- [ ] **Step 1: Home screen — dual display**

In `_loadStats()` (line 128), load wallet alongside rank:
```dart
final wallet = await _streakService.getWallet();
final rank = await _streakService.getRangerRank();
```

Replace the single `_totalStars` display with:
- **Ranger Rank**: Shield icon + large number (primary, 3x size)
- **Star Wallet**: Coin/purse icon + number (secondary, smaller)

When wallet is 0, show empty coin purse icon (no number).

- [ ] **Step 2: Home screen — remove "next unlock" progress bar**

The current home screen shows "X stars until FROST" with a progress bar based on cumulative thresholds. This no longer applies — the shop is where you browse and buy. Remove the threshold-based progress bar. Optionally replace with a "Saving For" feature later (Task in future plan).

- [ ] **Step 3: Victory screen — update star earning display**

In `_recordAndAnimate()`, the current flow shows "+1 star!" voice. Update to:
- Show base earning: "+2 stars!"
- Show bonus if any: "+1 streak bonus!"
- Use `outcome.starsEarned` (which now includes base + streak bonus)
- Update the wallet counter animation (was showing `_newStars` which is cumulative)

Add wallet tracking:
```dart
_previousWallet = await _streakService.getWallet();
// ... after recordBrush ...
_newWallet = await _streakService.getWallet();
```

Show `_newWallet` as the primary number in the victory star animation (not `_newStars`).

- [ ] **Step 4: Victory screen — remove threshold-based unlock teaser**

Remove `_computeNextUnlock()` and the "X stars until [HERO]" progress bar. The shop handles this now.

- [ ] **Step 5: Run dart analyze on both files**

Run: `cd /Users/jimchabas/Projects/brush-quest && dart analyze lib/screens/home_screen.dart lib/screens/victory_screen.dart`

- [ ] **Step 6: Commit**

```bash
cd /Users/jimchabas/Projects/brush-quest
git add lib/screens/home_screen.dart lib/screens/victory_screen.dart
git commit -m "feat: show Ranger Rank + wallet on home and victory screens

Home screen displays shield (rank) + coin purse (wallet). Victory screen
shows wallet earnings with streak bonus breakdown. Removed threshold-based
unlock progress bars (shop handles purchasing now)."
```

---

## PHASE 3: TROPHY WALL

### Task 8: TrophyService — 25 Monster Trophies

Create the new service that replaces CardService with 25 deterministic monsters.

**Files:**
- Create: `lib/services/trophy_service.dart`
- Create: `test/services/trophy_service_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:brush_quest/services/trophy_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TrophyService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('has 5 monsters per world, 5 worlds = 25 total', () {
      expect(TrophyService.allTrophies.length, 25);
      for (final worldId in TrophyService.worldIds) {
        final worldTrophies = TrophyService.trophiesForWorld(worldId);
        expect(worldTrophies.length, 5, reason: 'World $worldId should have 5 trophies');
      }
    });

    test('recordCapture marks monster as captured', () async {
      final service = TrophyService();
      await service.recordCapture('cc_t1');

      final captured = await service.getCapturedIds();
      expect(captured, contains('cc_t1'));
    });

    test('isWorldComplete returns true when all 5 captured', () async {
      final service = TrophyService();
      final worldTrophies = TrophyService.trophiesForWorld('candy_crater');
      for (final t in worldTrophies) {
        await service.recordCapture(t.id);
      }
      expect(await service.isWorldComplete('candy_crater'), true);
    });

    test('getDefeatProgress tracks defeats toward capture', () async {
      final service = TrophyService();
      // Monster requires 2 defeats to capture
      final trophy = TrophyService.allTrophies.firstWhere((t) => t.defeatsRequired > 1);

      await service.recordDefeat(trophy.id);
      expect(await service.getDefeatCount(trophy.id), 1);
      expect(await service.isCaptured(trophy.id), false);
    });

    test('recordDefeat auto-captures when defeats reach threshold', () async {
      final service = TrophyService();
      final trophy = TrophyService.allTrophies.firstWhere((t) => t.defeatsRequired == 1);

      final result = await service.recordDefeat(trophy.id);
      expect(result.captured, true);
      expect(await service.isCaptured(trophy.id), true);
    });

    test('getNextUncaptured returns monster from current world', () async {
      final service = TrophyService();
      final next = await service.getNextUncaptured('candy_crater');
      expect(next, isNotNull);
      expect(next!.worldId, 'candy_crater');
    });

    test('getWallProgress returns captured/total for a world', () async {
      final service = TrophyService();
      await service.recordCapture('cc_t1');
      final progress = await service.getWallProgress('candy_crater');
      expect(progress.captured, 1);
      expect(progress.total, 5);
    });
  });
}
```

- [ ] **Step 2: Run tests — verify fail**

Run: `cd /Users/jimchabas/Projects/brush-quest && flutter test test/services/trophy_service_test.dart`
Expected: FAIL — file doesn't exist

- [ ] **Step 3: Implement TrophyService**

Create `lib/services/trophy_service.dart`:

```dart
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

  // 25 trophies: 5 per world. Reuse the best monsters from CardService.
  // defeatsRequired: 1 for common-feel, 2 for tough, 3 for boss.
  static const List<TrophyMonster> allTrophies = [
    // ── Candy Crater ──
    TrophyMonster(id: 'cc_t1', name: 'Gummy Grub', title: 'Sugar Slimer', worldId: 'candy_crater', baseImageIndex: 0, tintColor: Color(0xFFFF80AB), defeatsRequired: 1, flavorText: 'Leaves sticky gum trails everywhere!'),
    TrophyMonster(id: 'cc_t2', name: 'Lollipop Lurker', title: 'Sweet Stalker', worldId: 'candy_crater', baseImageIndex: 1, tintColor: Color(0xFFF48FB1), defeatsRequired: 1, flavorText: 'Hides inside giant lollipops!'),
    TrophyMonster(id: 'cc_t3', name: 'Taffy Twister', title: 'Stretchy Menace', worldId: 'candy_crater', baseImageIndex: 1, tintColor: Color(0xFFEF9A9A), defeatsRequired: 1, flavorText: 'Stretches like taffy to dodge attacks!'),
    TrophyMonster(id: 'cc_t4', name: 'Mint Marauder', title: 'Cool Criminal', worldId: 'candy_crater', baseImageIndex: 0, tintColor: Color(0xFF80CBC4), defeatsRequired: 2, flavorText: 'So minty your eyes water!'),
    TrophyMonster(id: 'cc_t5', name: 'Sugar King', title: 'Sweetness Supreme', worldId: 'candy_crater', baseImageIndex: 0, tintColor: Color(0xFFFF4081), defeatsRequired: 3, flavorText: 'The ultimate sugar monster!'),

    // ── Slime Swamp ──
    TrophyMonster(id: 'ss_t1', name: 'Goo Goblin', title: 'Slime Spitter', worldId: 'slime_swamp', baseImageIndex: 1, tintColor: Color(0xFF69F0AE), defeatsRequired: 1, flavorText: 'Spits green goo at everything!'),
    TrophyMonster(id: 'ss_t2', name: 'Muck Monster', title: 'Mud Dweller', worldId: 'slime_swamp', baseImageIndex: 2, tintColor: Color(0xFF81C784), defeatsRequired: 1, flavorText: 'Lives deep in the muckiest mud!'),
    TrophyMonster(id: 'ss_t3', name: 'Bog Beast', title: 'Swamp Stomper', worldId: 'slime_swamp', baseImageIndex: 2, tintColor: Color(0xFF4DB6AC), defeatsRequired: 1, flavorText: 'Shakes the ground when it walks!'),
    TrophyMonster(id: 'ss_t4', name: 'Toxic Toad', title: 'Poison Hopper', worldId: 'slime_swamp', baseImageIndex: 1, tintColor: Color(0xFF00E676), defeatsRequired: 2, flavorText: 'Its tongue is super sticky!'),
    TrophyMonster(id: 'ss_t5', name: 'Swamp Lord', title: 'King of Ooze', worldId: 'slime_swamp', baseImageIndex: 1, tintColor: Color(0xFF00BFA5), defeatsRequired: 3, flavorText: 'Rules the entire swamp!'),

    // ── Sugar Volcano ──
    TrophyMonster(id: 'sv_t1', name: 'Ember Imp', title: 'Fire Starter', worldId: 'sugar_volcano', baseImageIndex: 2, tintColor: Color(0xFFFF8A65), defeatsRequired: 1, flavorText: 'Sets everything on fire!'),
    TrophyMonster(id: 'sv_t2', name: 'Lava Larva', title: 'Hot Crawler', worldId: 'sugar_volcano', baseImageIndex: 3, tintColor: Color(0xFFFF7043), defeatsRequired: 1, flavorText: 'Born inside a volcano!'),
    TrophyMonster(id: 'sv_t3', name: 'Magma Mite', title: 'Molten Menace', worldId: 'sugar_volcano', baseImageIndex: 3, tintColor: Color(0xFFE64A19), defeatsRequired: 2, flavorText: 'Too hot to touch!'),
    TrophyMonster(id: 'sv_t4', name: 'Pyro Python', title: 'Fire Fang', worldId: 'sugar_volcano', baseImageIndex: 3, tintColor: Color(0xFFFF6E40), defeatsRequired: 2, flavorText: 'Breathes fireballs!'),
    TrophyMonster(id: 'sv_t5', name: 'Volcano King', title: 'Eruption Lord', worldId: 'sugar_volcano', baseImageIndex: 2, tintColor: Color(0xFFDD2C00), defeatsRequired: 3, flavorText: 'Makes volcanoes erupt on command!'),

    // ── Shadow Nebula ──
    TrophyMonster(id: 'sn_t1', name: 'Dark Wisp', title: 'Shadow Drifter', worldId: 'shadow_nebula', baseImageIndex: 0, tintColor: Color(0xFFB39DDB), defeatsRequired: 1, flavorText: 'Floats through the darkness!'),
    TrophyMonster(id: 'sn_t2', name: 'Gloom Ghoul', title: 'Night Creeper', worldId: 'shadow_nebula', baseImageIndex: 3, tintColor: Color(0xFF9575CD), defeatsRequired: 1, flavorText: 'Only comes out at night!'),
    TrophyMonster(id: 'sn_t3', name: 'Void Vermin', title: 'Space Rat', worldId: 'shadow_nebula', baseImageIndex: 0, tintColor: Color(0xFF7E57C2), defeatsRequired: 2, flavorText: 'Chews through anything!'),
    TrophyMonster(id: 'sn_t4', name: 'Nebula Knight', title: 'Star Warrior', worldId: 'shadow_nebula', baseImageIndex: 3, tintColor: Color(0xFF7C4DFF), defeatsRequired: 2, flavorText: 'Has armor made of starlight!'),
    TrophyMonster(id: 'sn_t5', name: 'Shadow Overlord', title: 'Darkness Master', worldId: 'shadow_nebula', baseImageIndex: 0, tintColor: Color(0xFF6200EA), defeatsRequired: 3, flavorText: 'Controls all shadows!'),

    // ── Cavity Fortress ──
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
```

- [ ] **Step 4: Run tests**

Run: `cd /Users/jimchabas/Projects/brush-quest && flutter test test/services/trophy_service_test.dart`
Expected: ALL PASS

- [ ] **Step 5: Run dart analyze**

Run: `cd /Users/jimchabas/Projects/brush-quest && dart analyze lib/services/trophy_service.dart`

- [ ] **Step 6: Commit**

```bash
cd /Users/jimchabas/Projects/brush-quest
git add lib/services/trophy_service.dart test/services/trophy_service_test.dart
git commit -m "feat: add TrophyService with 25 deterministic monsters

5 monsters per world across 5 worlds. Each requires 1-3 defeats to
capture (bosses take 3). No randomness, no duplicates. Replaces the
70-card rarity-weighted system."
```

---

### Task 9: Brushing Screen — Connect Monsters to Trophies

The current brushing screen generates random monsters with no identity. Connect each phase's monster to the current trophy target.

**Files:**
- Modify: `lib/screens/brushing_screen.dart`

- [ ] **Step 1: Load trophy target at session start**

In `initState()` / `_startSession()`, load the current trophy monster the player is working toward:

```dart
final _trophyService = TrophyService();
TrophyMonster? _currentTrophyTarget;

// In init:
_currentTrophyTarget = await _trophyService.getNextUncaptured(_world.id);
```

- [ ] **Step 2: Use trophy monster's appearance for the battle**

In `_createMonster()` (line 612), if `_currentTrophyTarget` is set, use its `baseImageIndex` and `tintColor`:

```dart
_MonsterSlot _createMonster() {
  final imageIndex = _currentTrophyTarget?.baseImageIndex
      ?? _random.nextInt(_monsterImages.length);
  return _MonsterSlot(
    imageIndex: imageIndex,
    health: 1.0,
    alive: true,
    wobblePhase: _random.nextDouble() * 2 * pi,
    personality: _MonsterPersonality.random(_random),
    trophyTint: _currentTrophyTarget?.tintColor,
  );
}
```

Add `trophyTint` field to `_MonsterSlot` and apply it in the render method where the monster image is drawn with a color overlay.

**Note:** There are TWO monster creation methods — `_createMonster()` (line 612, generic random) and `_createWorldMonster()` (line 622, uses world's `monsterIndices`). The one called during battle init is `_createMonster()` at line 481. Update `_createMonster()` with trophy data. `_createWorldMonster()` can be left as-is (it's a fallback) or removed if unused after this change.

- [ ] **Step 3: Pass trophy target ID to VictoryScreen**

When navigating to VictoryScreen (look for `Navigator.pushReplacement` to `VictoryScreen`), pass the current trophy target:

```dart
VictoryScreen(
  // ... existing params ...
  trophyTargetId: _currentTrophyTarget?.id,
)
```

Add the parameter to `VictoryScreen`'s constructor.

**Note:** The brushing screen currently passes `starsCollected: 1` to VictoryScreen. Since VictoryScreen calls `recordBrush()` internally and gets the actual earning from the outcome, this display-hint param should be removed or updated. Simplest: remove the `starsCollected` parameter entirely — VictoryScreen already computes it via `_starsEarnedThisSession`.

- [ ] **Step 4: Run dart analyze**

Run: `cd /Users/jimchabas/Projects/brush-quest && dart analyze lib/screens/brushing_screen.dart`

- [ ] **Step 5: Commit**

```bash
cd /Users/jimchabas/Projects/brush-quest
git add lib/screens/brushing_screen.dart
git commit -m "feat: connect brushing monsters to trophy targets

Battle monsters now use the trophy target's image and tint. The kid
fights the monster they're trying to capture, not a random one.
Trophy target ID passed to VictoryScreen for capture reveal."
```

---

### Task 10: Victory Screen — Trophy Capture Reveal

Replace the card drop sequence with a trophy capture moment.

**Files:**
- Modify: `lib/screens/victory_screen.dart`

- [ ] **Step 1: Replace card drop with trophy defeat/capture**

In `_openChest()` (line 428), after the chest reward sequence, replace the card drop code (lines 461-512) with:

```dart
// ── Trophy defeat/capture ──
if (_trophyTargetId != null) {
  final result = await _trophyService.recordDefeat(_trophyTargetId!);
  if (!mounted) return;

  await Future.delayed(const Duration(milliseconds: 500));
  if (!mounted) return;

  if (result.captured) {
    // CAPTURED! Big celebration
    setState(() {
      _showTrophyCapture = true;
      _trophyCaptured = true;
    });
    HapticFeedback.heavyImpact();
    _audio.playSfx('victory.mp3');
    _trophyFlyController.forward();
    await _audio.playVoice('voice_trophy_captured.mp3');
    // Play monster-specific voice
    final trophy = TrophyService.allTrophies.firstWhere((t) => t.id == _trophyTargetId);
    await _audio.playVoice('voice_card_${trophy.id.replaceAll('_t', '_')}.mp3');
  } else {
    // Damaged but not captured yet — show progress
    setState(() {
      _showTrophyCapture = true;
      _trophyCaptured = false;
      _trophyDefeats = result.currentDefeats;
      _trophyRequired = result.required;
    });
    _audio.playVoice('voice_trophy_damaged.mp3');
  }

  // Show wall progress
  final wallProgress = await _trophyService.getWallProgress(_world.id);
  final worldComplete = await _trophyService.isWorldComplete(_world.id);
  if (!mounted) return;
  setState(() {
    _showWorldProgress = true;
    _worldJustCompleted = worldComplete;
  });
}
```

- [ ] **Step 2: Update trophy capture UI**

Replace the card reveal widget (the `_buildCardDropReveal` section around lines 620-710) with a trophy capture widget:

When captured:
- Monster shrinks into a trophy frame with whoosh + flash
- "You CAUGHT [name]!" text with voice
- Big celebration particles

When not yet captured (still fighting):
- Show monster with damage cracks
- "[1/3] Keep fighting!" progress dots
- Voice: "Almost there! X more fights!"

- [ ] **Step 3: Remove all CardService AND CardAlbumScreen references from VictoryScreen**

Remove imports of `card_service.dart` AND `card_album_screen.dart`, the `_cardService` field, `_cardDrop`, `_showCardDrop`, `_cardFlyController`, `_cardGlowController`, and all related animation code. Also remove the "Tap to see album >" link (around line 715) that navigates to `CardAlbumScreen`. The trophy system is simpler — fewer animation controllers needed.

- [ ] **Step 4: Run dart analyze**

Run: `cd /Users/jimchabas/Projects/brush-quest && dart analyze lib/screens/victory_screen.dart`

- [ ] **Step 5: Commit**

```bash
cd /Users/jimchabas/Projects/brush-quest
git add lib/screens/victory_screen.dart
git commit -m "feat: replace card drop with trophy capture on victory screen

Post-brush now shows trophy defeat progress or capture celebration.
Captured: whoosh + flash + voice celebration. In progress: damage cracks
+ progress dots. Removed all CardService integration."
```

---

### Task 11: Trophy Wall Screen

Create the new screen that replaces the card album.

**Files:**
- Create: `lib/screens/trophy_wall_screen.dart`
- Modify: `lib/screens/home_screen.dart` (navigation)

- [ ] **Step 1: Create TrophyWallScreen**

```dart
// lib/screens/trophy_wall_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/trophy_service.dart';
import '../services/world_service.dart';
import '../services/audio_service.dart';
import '../widgets/space_background.dart';

class TrophyWallScreen extends StatefulWidget {
  const TrophyWallScreen({super.key});

  @override
  State<TrophyWallScreen> createState() => _TrophyWallScreenState();
}

class _TrophyWallScreenState extends State<TrophyWallScreen> {
  final _trophyService = TrophyService();
  final _worldService = WorldService();
  List<String> _capturedIds = [];
  String _currentWorldId = 'candy_crater';
  int _totalCaptured = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final captured = await _trophyService.getCapturedIds();
    final world = await _worldService.getCurrentWorldId();
    if (mounted) {
      setState(() {
        _capturedIds = captured;
        _currentWorldId = world;
        _totalCaptured = captured.length;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const SpaceBackground(),
          SafeArea(
            child: Column(
              children: [
                // Header: back button + total progress
                _buildHeader(),
                // World selector (horizontal scroll of planet icons)
                _buildWorldSelector(),
                // Trophy grid for selected world
                Expanded(child: _buildTrophyGrid()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ... implementation of header (shows "12/25 MONSTERS CAUGHT"),
  // world selector (5 planet icons, tap to switch),
  // and trophy grid (5 large tiles, 2 columns + 1 centered bottom)
}
```

Trophy tile states:
- **Captured**: Full-color monster image with glow, tappable (plays roar)
- **In progress**: Silhouette with defeat progress dots (e.g., "1/3")
- **Locked**: Dark silhouette with "?" — no progress, not yet fighting this one

- [ ] **Step 2: Tap interaction — monster roar**

When tapping a captured trophy:
```dart
void _onTrophyTap(TrophyMonster trophy) {
  HapticFeedback.mediumImpact();
  AudioService().playVoice('voice_card_${trophy.id.replaceAll('_t', '_')}.mp3');
  // Show full-screen detail: big monster image + name spoken aloud
  _showTrophyDetail(trophy);
}
```

- [ ] **Step 3: Update home screen navigation**

In `home_screen.dart`, replace the CARDS button that navigates to `CardAlbumScreen` with a TROPHIES button that navigates to `TrophyWallScreen`. Look for the card album navigation (search for `CardAlbumScreen` or `card_album`) and replace.

- [ ] **Step 4: Run dart analyze**

Run: `cd /Users/jimchabas/Projects/brush-quest && dart analyze lib/screens/trophy_wall_screen.dart lib/screens/home_screen.dart`

- [ ] **Step 5: Commit**

```bash
cd /Users/jimchabas/Projects/brush-quest
git add lib/screens/trophy_wall_screen.dart lib/screens/home_screen.dart
git commit -m "feat: add TrophyWallScreen replacing card album

Per-world trophy wall with 5 large monster tiles. Captured monsters
shown in color with tap-to-roar. Uncaptured shown as silhouettes.
Total progress counter at top. Home screen now navigates here
instead of card album."
```

---

## PHASE 4: SYNC & MIGRATION

### Task 12: Sync Service + Data Migration

Update cloud sync to handle new keys and migrate existing users.

**Files:**
- Modify: `lib/services/sync_service.dart`
- Modify: `lib/main.dart` (migration on startup)

- [ ] **Step 1: Add new sync keys**

In `sync_service.dart`, add to `_syncKeys`:
```dart
'star_wallet',
'trophy_captured',
```

Add to `_prefixSyncKeys`:
```dart
'trophy_defeats_',
```

- [ ] **Step 2: Update progress score calculation**

Update `_progressScoreFromPrefs` and `_progressScoreFromCloud` to include trophies in the merge score. Do NOT include `star_wallet` in the score — a device with low wallet but more purchased items has more progress, and the existing `heroes * 30 + weapons * 20` already captures that.

Add trophies:
```dart
// In _progressScoreFromPrefs:
final trophies = (prefs.getStringList('trophy_captured') ?? const []).length;
// Add to return: + trophies * 25

// In _progressScoreFromCloud:
final trophies = (cloudData['trophy_captured'] is List) ? (cloudData['trophy_captured'] as List).length : 0;
// Add to return: + trophies * 25
```

Updated formula: `brushes * 8 + stars * 5 + heroes * 30 + weapons * 20 + achievements * 15 + worldProgress * 3 + trophies * 25`

- [ ] **Step 3: Create migration function**

In `lib/services/streak_service.dart`, add a one-time migration:

```dart
/// Migrate from v1 (cumulative) to v2 (wallet) economy.
/// Credits existing total_stars to star_wallet if wallet key doesn't exist.
/// Run once on app startup.
///
/// DESIGN DECISION: Existing users keep ALL previously-unlocked heroes/weapons
/// AND get their full star total credited to the wallet. This is intentional
/// per spec: "Oliver arrives feeling RICHER." He walks into the new shop with
/// spendable stars and can buy things immediately. The fact that he also kept
/// his old unlocks for free is a one-time migration bonus.
static Future<void> migrateToWalletEconomy() async {
  final prefs = await SharedPreferences.getInstance();
  // Only migrate if wallet key doesn't exist yet (idempotent)
  if (prefs.containsKey('star_wallet')) return;

  final totalStars = prefs.getInt('total_stars') ?? 0;
  await prefs.setInt('star_wallet', totalStars);
  // Mark migration done (wallet key now exists)
}
```

- [ ] **Step 4: Call migration in main.dart**

In `main()`, after Firebase init but before `runApp()`:
```dart
await StreakService.migrateToWalletEconomy();
```

- [ ] **Step 5: Write migration tests**

Add to `test/services/streak_service_test.dart`:

```dart
group('Migration', () {
  test('migrateToWalletEconomy copies total_stars to star_wallet', () async {
    SharedPreferences.setMockInitialValues({'total_stars': 42});
    await StreakService.migrateToWalletEconomy();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('star_wallet'), 42);
  });

  test('migrateToWalletEconomy is idempotent', () async {
    SharedPreferences.setMockInitialValues({'total_stars': 42, 'star_wallet': 10});
    await StreakService.migrateToWalletEconomy();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('star_wallet'), 10); // NOT overwritten
  });

  test('migrateToWalletEconomy handles zero stars', () async {
    SharedPreferences.setMockInitialValues({});
    await StreakService.migrateToWalletEconomy();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('star_wallet'), 0);
  });
});
```

- [ ] **Step 6: Run migration tests**

Run: `cd /Users/jimchabas/Projects/brush-quest && flutter test test/services/streak_service_test.dart`
Expected: ALL PASS

- [ ] **Step 7: Update existing screen tests that reference card system or old star rates**

The following test files will break and need updates:
- `test/screens/victory_screen_test.dart` — remove CardService/CardAlbumScreen references, update star earning assertions from 1 to 2
- `test/screens/home_screen_test.dart` — update star display expectations
- `test/screens/brushing_screen_test.dart` — update VictoryScreen constructor params

For each: search for `card_service`, `card_album`, `starsEarned, 1`, `starsCollected`, and update to match the new API.

- [ ] **Step 8: Run full test suite**

Run: `cd /Users/jimchabas/Projects/brush-quest && flutter test`
Expected: ALL PASS

- [ ] **Step 9: Run dart analyze on all modified files**

Run: `cd /Users/jimchabas/Projects/brush-quest && dart analyze lib/`

- [ ] **Step 10: Commit**

```bash
cd /Users/jimchabas/Projects/brush-quest
git add lib/services/sync_service.dart lib/services/streak_service.dart lib/main.dart test/
git commit -m "feat: sync new economy keys + v1→v2 migration

Syncs star_wallet and trophy_* keys to Firestore. Migration credits
existing total_stars to wallet on first launch. Existing unlocked
heroes/weapons preserved."
```

---

## Post-Implementation Notes

### What's Deferred (Separate Plans)

1. **Multi-profile system** ("Who's brushing?") — BLOCKER before shipping to Oliver. Architecturally independent; scopes all SharedPreferences keys by profile ID. Separate plan needed.

2. **"Saving For" goal feature** — UX enhancement for Phase 2. Tap an item to set as goal, shows progress bar on home/victory screens. Nice to have, not blocking.

3. **Worlds 6-10 trophies** — The current 10-world WorldService stays unchanged. Only worlds 1-5 have trophies. Worlds 6-10 trophies can be added later by extending `TrophyService.allTrophies`.

4. **Hero skins** — New shop category. Needs skin asset creation + a `SkinService`. Separate plan.

5. **Parent IAP** — Google Play billing integration. Separate plan.

6. **Voice lines** — New voice files needed: `voice_trophy_captured.mp3`, `voice_trophy_damaged.mp3`, `voice_wallet_empty.mp3`. Can use existing voices as placeholders initially.

### Testing Strategy

- Unit tests cover service layer (Tasks 1-2, 4-5, 8, 12)
- Existing screen tests (`test/screens/victory_screen_test.dart`, `home_screen_test.dart`, `brushing_screen_test.dart`) WILL break and must be updated in Task 12
- Migration tests (Task 12) verify wallet credit + idempotency
- Manual testing: build APK and test full flow on device before shipping
- Run `flutter test` (full suite) at end of each phase to catch regressions

### Voice File Placeholders

New voice lines needed but not yet recorded:
- `voice_trophy_captured.mp3` → placeholder: reuse `voice_card_new.mp3`
- `voice_trophy_damaged.mp3` → placeholder: reuse `voice_keep_going.mp3`
- `voice_wallet_empty.mp3` → placeholder: reuse `voice_need_stars.mp3`
- Trophy-specific voices: reuse existing `voice_card_*.mp3` files — the trophy IDs use `_t` suffix (`cc_t1`) while card IDs don't (`cc_01`). In code, map trophy IDs to card voice files: `voice_card_${trophy.id.replaceAll('_t', '_0')}.mp3` (e.g., `cc_t1` → `voice_card_cc_01.mp3`)
