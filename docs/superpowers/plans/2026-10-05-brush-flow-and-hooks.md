# Brush flow (Hero → Weapon → World) + visible hooks — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Before each brush, the child passes through three auto-advancing steps (Hero → Weapon → World). Each shows his choice and how close the next unlock is, and lets him switch to anything he owns. After brushing, the reward visibly lands: a streak flame gives bonus stars, the chest tier follows the streak, and the next goal fills and unlocks with one tap. A voice explains each link.

**Architecture:**
- New pure units hold the rules: `flame_tier.dart`, `goal_service.dart` (`GoalRules`), and the world-frontier rule in `WorldService`. All are unit-tested without widgets.
- A new `PreBrushScreen` sits between Home and `BrushingScreen`.
- `VictoryScreen` gains a flame beat before the chest, chest tiers, a goal beat after the chest and a flame closing strip.
- `HomeScreen` changes only the streak pill, which becomes a flame. The daily bonus stars visibly fly out of it.
- Purchases reuse the shop's logic through a new `UnlockService`.

**Tech Stack:** Flutter/Dart, `shared_preferences`, the existing `AudioService` / `FakeAudioService`, `flutter_test`. ElevenLabs (MCP) plus `ffmpeg` for voice clips.

**Spec:** `docs/superpowers/specs/2026-10-05-brush-flow-and-hooks-design.md`. Read it with this plan; the spec wins on any conflict except the rulings below.

**Rulings refining the spec** (the controller made these while writing the plan; Jim reviews them with the plan):
- **R1. Step voices stay short.** Existing picker lines are 3.4–5.6 s and world briefings are 5.1–6.6 s, so playing them on every step would make the flow about 19 s instead of the approved ≈9 s.
  - On auto-advance, a hero or weapon step plays only its progress clip ("Three more stars!").
  - The item's existing picker line plays only when the child switches to that item.
  - The world step plays the full `voice_world_<id>` briefing only when the planet differs from the last brushed one (a new planet, or the child switched). Otherwise it plays only the brushes-left clip.
  - Caps: 5 s per step normally, 8 s for a briefing step.
- **R2. Locked items are not in the carousel.** The carousel holds owned items only (every owned hero stage counts as an item). The closest next unlock sits in a **goal panel** under the carousel: a silhouette plus a meter. Tapping the panel plays the "need more" line. This avoids up to 22 locked silhouettes in a swipe row and keeps "the closest goal" the single target.
- **R3. Affordable but not yet unlocked.** If a goal is already affordable on a pre-brush step (he skipped the unlock last time), the meter shows full and Buddy says the new clip `voice_ready_to_unlock.mp3` ("Brush to unlock it!"). The unlock itself still happens on the victory screen (D5).
- **R4. The world goal's silhouette is the planet that unlocks next.** That is the world after the frontier; if the frontier is the last world, it is the frontier itself. The meter is the frontier's missions.
- **R5. Flame visuals are drawn in code.** The Material `Icons.local_fire_department` is used in four sizes and colours, so no flame image assets are needed. Chests are drawn in code already; tiers are palette swaps.
- **R6. No repeat of the tier-up line on Home.** A flame step only changes during a brush, and the victory screen already speaks the tier-up line (`voice_flame_tier_*`). The Home "whoosh" right after victory (`HomeScreen(skipGreeting: true)`) is therefore SFX plus pill pulse only. `voice_flame_got_bigger.mp3` plays only when Home opens without `skipGreeting` and finds a higher step than last seen (for example, the app was killed during victory).
- **R7. Test-only keys:** `ValueKey('home_hero_button')` on Home's hero `GestureDetector` and `ValueKey('victory_chest')` on the chest `GestureDetector`. No visual change.

## Global Constraints

- **Non-reader:** every piece of information the child needs is a picture, an animation or a Buddy (George) voice line. Text is decorative only.
- **Voice:** Buddy (George) only. New clips go to `assets/audio/voices/buddy/` as mp3, 22 050 Hz, mono, 64 kbps, about −24 LUFS integrated (existing clips measure −23 to −26).
- **Home:** no new elements. Only the streak pill changes. Nothing on Home pulses or bounces as a "tap here" cue (Jim's permanent rule); the one-time flame "whoosh" in Task 10 is the only animation, and it does not loop.
- **Economy:** prices, earn rules and existing saves are unchanged. The only new prefs key is `last_seen_flame_tier`.
- **Timers:** every delayed callback in a `StatefulWidget` is a `Timer?` field cancelled in `dispose()`. No bare `Future.delayed` in new code (standing rule).
- **Never block brushing:** if pre-brush data fails to load, skip straight to `BrushingScreen` (with its world intro).
- **Never gate visuals on voice completion.** Use fire-and-forget voice plus fixed delays or caps. A voice that never finishes (muted, missing file) must not stall any screen.
- **Effects:** at most 2 concurrent visual effects per character.
- **iOS:** no analytics and no new plugins or SDKs. `AnalyticsService` methods are already no-ops unless enabled (Android).
- **Tests:** TDD for logic; widget tests use `FakeAudioService` (`AudioService.testInstance = fake;`, reset to `null` in `tearDown`) and `SharedPreferences.setMockInitialValues`. Screens that touch Firebase use `setupFirebaseCoreMocks(); await Firebase.initializeApp();` in `setUpAll`, as `test/screens/victory_screen_test.dart` does.
- **Gates before each commit:** `dart format <changed files>`, `dart analyze` ("No issues found!"), and the task's tests. The controller runs the full `flutter test` after each task.
- **Commits:** explicit `git add <paths>` (never `-A`). Message trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Don't push.

## Review Focus

1. **Double tap on the Home hero** (or a tap during the push transition) must not push two `PreBrushScreen`s. Home's `_brushTapLocked` must cover the new path. → Task 7, test "double tap opens one pre-brush screen".
2. **App backgrounded during a pre-brush step:** timers must not advance into brushing while the app is paused. On resume, the current step restarts. → Task 7, test "pause stops auto-advance; resume restarts the step".
3. **Muted, or voice files missing:** the voice-end signal never fires, so every step must still advance at its cap and the victory sequence must still reach DONE. → Task 7, test "advances at the cap when the voice never ends"; Task 9, test "DONE appears when muted".
4. **Everything owned** (all heroes, stages, weapons, worlds): each step shows a crown and "You have them all!", the victory goal beat is skipped, nothing crashes. → Task 3 tests, Task 7 test "all owned", Task 9 test "no goal beat when all owned".
5. **Unlock tapped twice quickly, or the wallet changed under the screen:** at most one purchase (the `StreakService.isPurchasing` lock), and the card shows the result. → Task 4 test "double unlock spends once", Task 9 test "double tap unlocks once".

---

## File structure

| File | Status | Responsibility |
|---|---|---|
| `lib/services/flame_tier.dart` | new | Streak → flame step, chest tier, days to next step (pure) |
| `lib/services/world_service.dart` | modify | `getFrontierWorld()`; `recordMission()` counts toward the frontier |
| `lib/services/goal_service.dart` | new | `Goal`, `GoalRules` (pure), `GoalService` (reads services) |
| `lib/services/unlock_service.dart` | new | Buy + equip a hero / evolution / weapon (shared by shop and victory) |
| `lib/screens/hero_shop_screen.dart` | modify | Use `UnlockService` for its three purchase paths (behaviour unchanged) |
| `lib/services/audio_service.dart` | modify | `starsLeftVoiceFor`, `brushesLeftVoiceFor` |
| `assets/audio/voices/buddy/*.mp3` | new | 39 new clips |
| `lib/widgets/goal_meter.dart` | new | Star slots / star bar / rocket slots / crown |
| `lib/widgets/item_silhouette.dart` | new | Black silhouette of any image widget |
| `lib/widgets/loadout_carousel.dart` | new | Swipe/arrow carousel of owned items |
| `lib/widgets/flame_view.dart` | new | `FlameIcon` (4 steps) and `FlameStrip` (days to next step) |
| `lib/screens/pre_brush_screen.dart` | new | The three steps, timing, voice, hand-off to brushing |
| `lib/screens/brushing_screen.dart` | modify | `showWorldIntro` parameter |
| `lib/screens/home_screen.dart` | modify | Route hero tap via pre-brush; flame pill; welcome payoff; tier-up whoosh |
| `lib/screens/victory_screen.dart` | modify | Flame beat, chest tiers, goal beat with unlock, rockets, flame closing line |
| `lib/services/analytics_service.dart` | modify | 4 new Android-only events |
| `test/...` | new/modify | Listed per task |

---

### Task 1: Flame steps (pure rules)

**Files:**
- Create: `lib/services/flame_tier.dart`
- Test: `test/services/flame_tier_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `enum FlameTier { none, small, big, hot, golden }`, `enum ChestTier { wooden, silver, gold }`, `FlameTier flameTierFor(int streak)`, `ChestTier chestTierFor(int streak)`, `int? nextFlameTierAt(int streak)`, `int? daysToNextFlameTier(int streak)`, `FlameTier? reachedFlameTier({required int before, required int after})`, constants `kFlameBigAt = 3`, `kFlameHotAt = 7`, `kFlameGoldenAt = 14`.

- [ ] **Step 1: Write the failing test**

```dart
// test/services/flame_tier_test.dart
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
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/services/flame_tier_test.dart`
Expected: FAIL. Compilation error: `flame_tier.dart` doesn't exist.

- [ ] **Step 3: Implement**

```dart
// lib/services/flame_tier.dart
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
  final b = flameTierFor(before);
  final a = flameTierFor(after);
  if (a.index <= b.index || a == FlameTier.small) return null;
  return a;
}
```

- [ ] **Step 4: Run the test and confirm it passes**

Run: `flutter test test/services/flame_tier_test.dart`
Expected: PASS (all tests).

- [ ] **Step 5: Commit**

```bash
dart format lib/services/flame_tier.dart test/services/flame_tier_test.dart
dart analyze
git add lib/services/flame_tier.dart test/services/flame_tier_test.dart
git commit -m "feat(streak): flame steps and chest tiers as pure rules" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: World progress counts toward the furthest unfinished planet

**Files:**
- Modify: `lib/services/world_service.dart` (`recordMission()` at about lines 194-207; add `getFrontierWorld()` next to it)
- Test: `test/services/world_frontier_test.dart` (new)

**Interfaces:**
- Consumes: existing `WorldService.allWorlds`, `getWorldProgress`, `isWorldCompleted`, prefs keys `world_progress_<id>` and `current_world`.
- Produces: `Future<WorldData?> getFrontierWorld()`. `recordMission()` has the same signature and the new semantics.

World order and missions: candy_crater 5, slime_swamp 5, sugar_volcano 6, shadow_nebula 6, cavity_fortress 7, frozen_tundra 7, toxic_jungle 7, crystal_cave 8, storm_citadel 8, dark_dimension 10.

- [ ] **Step 1: Write the failing test**

```dart
// test/services/world_frontier_test.dart
import 'package:brush_quest/services/world_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = WorldService();

  Future<int> progress(String id) => service.getWorldProgress(id);

  test('frontier is the first unfinished world', () async {
    SharedPreferences.setMockInitialValues({'world_progress_candy_crater': 5});
    expect((await service.getFrontierWorld())!.id, 'slime_swamp');
  });

  test('a brush in a revisited finished world counts toward the frontier', () async {
    SharedPreferences.setMockInitialValues({
      'world_progress_candy_crater': 5,
      'world_progress_slime_swamp': 2,
      'current_world': 'candy_crater', // the child picked the old world
    });
    await service.recordMission();
    expect(await progress('candy_crater'), 5); // unchanged
    expect(await progress('slime_swamp'), 3);
    expect(await service.getCurrentWorldId(), 'candy_crater'); // scenery kept
  });

  test('finishing the frontier moves the current world to the next one', () async {
    SharedPreferences.setMockInitialValues({
      'world_progress_candy_crater': 5,
      'world_progress_slime_swamp': 4,
      'current_world': 'candy_crater',
    });
    await service.recordMission();
    expect(await progress('slime_swamp'), 5);
    expect(await service.getCurrentWorldId(), 'sugar_volcano');
  });

  test('finishing the last world keeps it current', () async {
    final values = <String, Object>{'current_world': 'dark_dimension'};
    for (final w in WorldService.allWorlds) {
      values['world_progress_${w.id}'] =
          w.id == 'dark_dimension' ? w.missionsRequired - 1 : w.missionsRequired;
    }
    SharedPreferences.setMockInitialValues(values);
    await service.recordMission();
    expect(await service.isAllWorldsCompleted(), isTrue);
    expect(await service.getCurrentWorldId(), 'dark_dimension');
  });

  test('when every world is finished, recordMission changes nothing', () async {
    final values = <String, Object>{'current_world': 'storm_citadel'};
    for (final w in WorldService.allWorlds) {
      values['world_progress_${w.id}'] = w.missionsRequired;
    }
    SharedPreferences.setMockInitialValues(values);
    expect(await service.getFrontierWorld(), isNull);
    await service.recordMission();
    expect(await progress('storm_citadel'), 8);
    expect(await progress('dark_dimension'), 10);
    expect(await service.getCurrentWorldId(), 'storm_citadel');
  });

  test('unlock rule is unchanged (no world re-locks)', () async {
    SharedPreferences.setMockInitialValues({'world_progress_candy_crater': 5});
    expect(await service.isWorldUnlocked('slime_swamp'), isTrue);
    expect(await service.isWorldUnlocked('sugar_volcano'), isFalse);
  });
}
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/services/world_frontier_test.dart`
Expected: FAIL. `getFrontierWorld` isn't defined. The revisit test would also fail on the old code (progress goes to candy_crater).

- [ ] **Step 3: Implement.** In `world_service.dart`, replace `recordMission()` and add `getFrontierWorld()` just above it:

```dart
  /// The first world, in order, that is not completed. A brush's mission
  /// progress always goes here, whichever world the child is playing in
  /// (spec §8.4). Null when every world is completed. (The first unfinished
  /// world is always unlocked: the world before it is, by definition, done.)
  Future<WorldData?> getFrontierWorld() async {
    for (final world in allWorlds) {
      if (!await isWorldCompleted(world.id)) return world;
    }
    return null;
  }

  Future<void> recordMission() async {
    final frontier = await getFrontierWorld();
    if (frontier == null) return; // every world finished
    final prefs = await SharedPreferences.getInstance();
    final key = '$_progressPrefix${frontier.id}';
    final current = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, current + 1);

    if (current + 1 >= frontier.missionsRequired) {
      final worldIndex = allWorlds.indexWhere((w) => w.id == frontier.id);
      if (worldIndex < allWorlds.length - 1) {
        await prefs.setString(_currentWorldKey, allWorlds[worldIndex + 1].id);
      }
    }
  }
```

- [ ] **Step 4: Run this test and the existing world and victory tests**

Run: `flutter test test/services/world_frontier_test.dart test/services/ test/screens/victory_screen_test.dart`
Expected: PASS. If an existing test asserted the old "progress goes to the selected world" behaviour, update it to the frontier rule and say so in the report. That rule is the spec's D11.

- [ ] **Step 5: Commit**

```bash
dart format lib/services/world_service.dart test/services/world_frontier_test.dart
dart analyze
git add lib/services/world_service.dart test/services/world_frontier_test.dart
git commit -m "fix(worlds): a brush counts toward the furthest unfinished planet" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Goal rules and GoalService

**Files:**
- Create: `lib/services/goal_service.dart`
- Test: `test/services/goal_service_test.dart`

**Interfaces:**
- Consumes: `HeroService.allHeroes`, `HeroService.getEvolutionById(String)`, `HeroService.evolutionsForHero(String)`, `WeaponService.allWeapons`, `WorldService.allWorlds`; instance methods `getUnlockedHeroIds`, `getSelectedHeroId`, `getUnlockedEvolutionIds`, `getUnlockedWeaponIds`, `getWorldProgress`, `StreakService.getWallet`.
- Produces:
  - `enum GoalCategory { hero, weapon, world }`;
  - `class Goal { GoalCategory category; String itemId; String? evolutionHeroId; int stage; int cost; int have; bool get isEvolution; int get left; bool get affordable; String get heroId; }`;
  - `class GoalRules` with statics `heroGoal(...)`, `weaponGoal(...)`, `worldGoal(...)`, `overallGoal(Goal?, Goal?)`;
  - `class GoalService` with `Future<Goal?> heroGoal()`, `weaponGoal()`, `worldGoal()`, `overallGoal()`.

  A `null` goal means that category is complete.

Prices (from code): heroes blaze 0, frost 5, bolt 8, shadow 12, leaf 15, nova 20. Stages 2/3: blaze 10/20, frost 12/22, bolt 15/25, shadow 18/28, leaf 22/32, nova 25/35. Weapons: star_blaster 0, flame_sword 5, ice_hammer 14, lightning_wand 18, vine_whip 22, cosmic_burst 25.

- [ ] **Step 1: Write the failing test**

```dart
// test/services/goal_service_test.dart
import 'package:brush_quest/services/goal_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GoalRules.heroGoal', () {
    test('picks the cheaper of next upgrade and next new hero', () {
      // Blaze stage 2 = 10, next new hero = frost 5 -> frost.
      final g = GoalRules.heroGoal(
        unlockedHeroIds: ['blaze'],
        selectedHeroId: 'blaze',
        unlockedEvolutionIds: [],
        wallet: 3,
      )!;
      expect(g.itemId, 'frost');
      expect(g.isEvolution, isFalse);
      expect(g.cost, 5);
      expect(g.left, 2);
      expect(g.affordable, isFalse);
    });

    test('upgrade wins when cheaper', () {
      // Owns blaze, frost, bolt, shadow; next new = leaf 15; blaze stage2 = 10.
      final g = GoalRules.heroGoal(
        unlockedHeroIds: ['blaze', 'frost', 'bolt', 'shadow'],
        selectedHeroId: 'blaze',
        unlockedEvolutionIds: [],
        wallet: 10,
      )!;
      expect(g.itemId, 'blaze_stage2');
      expect(g.isEvolution, isTrue);
      expect(g.heroId, 'blaze');
      expect(g.stage, 2);
      expect(g.affordable, isTrue);
    });

    test('on a tie the upgrade wins', () {
      // Selected frost: frost stage2 = 12; next new = shadow 12.
      final g = GoalRules.heroGoal(
        unlockedHeroIds: ['blaze', 'frost', 'bolt'],
        selectedHeroId: 'frost',
        unlockedEvolutionIds: [],
        wallet: 0,
      )!;
      expect(g.itemId, 'frost_stage2');
    });

    test('next upgrade follows the owned stages of the selected hero', () {
      final g = GoalRules.heroGoal(
        unlockedHeroIds: ['blaze', 'frost', 'bolt', 'shadow', 'leaf', 'nova'],
        selectedHeroId: 'blaze',
        unlockedEvolutionIds: ['blaze_stage2'],
        wallet: 0,
      )!;
      expect(g.itemId, 'blaze_stage3');
      expect(g.cost, 20);
    });

    test('complete when every hero is owned and the selected hero is fully upgraded', () {
      final g = GoalRules.heroGoal(
        unlockedHeroIds: ['blaze', 'frost', 'bolt', 'shadow', 'leaf', 'nova'],
        selectedHeroId: 'nova',
        unlockedEvolutionIds: ['nova_stage2', 'nova_stage3'],
        wallet: 99,
      );
      expect(g, isNull);
    });
  });

  group('GoalRules.weaponGoal', () {
    test('cheapest locked weapon', () {
      final g = GoalRules.weaponGoal(
        unlockedWeaponIds: ['star_blaster', 'flame_sword'],
        wallet: 9,
      )!;
      expect(g.itemId, 'ice_hammer');
      expect(g.left, 5);
    });
    test('complete when all owned', () {
      expect(
        GoalRules.weaponGoal(
          unlockedWeaponIds: [
            'star_blaster', 'flame_sword', 'ice_hammer',
            'lightning_wand', 'vine_whip', 'cosmic_burst',
          ],
          wallet: 0,
        ),
        isNull,
      );
    });
  });

  group('GoalRules.worldGoal', () {
    test('counts the frontier missions; silhouette is the next planet', () {
      final g = GoalRules.worldGoal(
        progress: {'candy_crater': 5, 'slime_swamp': 2},
      )!;
      expect(g.category, GoalCategory.world);
      expect(g.itemId, 'sugar_volcano'); // unlocks when slime_swamp is done
      expect(g.cost, 5); // slime_swamp missionsRequired
      expect(g.have, 2);
      expect(g.left, 3);
      expect(g.affordable, isFalse); // worlds are never bought
    });
    test('last world: the goal is finishing it', () {
      final p = {
        'candy_crater': 5, 'slime_swamp': 5, 'sugar_volcano': 6,
        'shadow_nebula': 6, 'cavity_fortress': 7, 'frozen_tundra': 7,
        'toxic_jungle': 7, 'crystal_cave': 8, 'storm_citadel': 8,
        'dark_dimension': 4,
      };
      final g = GoalRules.worldGoal(progress: p)!;
      expect(g.itemId, 'dark_dimension');
      expect(g.left, 6);
    });
    test('complete when every world is finished', () {
      final p = {
        'candy_crater': 5, 'slime_swamp': 5, 'sugar_volcano': 6,
        'shadow_nebula': 6, 'cavity_fortress': 7, 'frozen_tundra': 7,
        'toxic_jungle': 7, 'crystal_cave': 8, 'storm_citadel': 8,
        'dark_dimension': 10,
      };
      expect(GoalRules.worldGoal(progress: p), isNull);
    });
  });

  group('GoalRules.overallGoal', () {
    const hero = Goal(category: GoalCategory.hero, itemId: 'frost', cost: 5, have: 3);
    const weapon = Goal(category: GoalCategory.weapon, itemId: 'flame_sword', cost: 5, have: 3);
    const farWeapon = Goal(category: GoalCategory.weapon, itemId: 'ice_hammer', cost: 14, have: 3);
    test('fewest stars left wins; tie goes to the hero', () {
      expect(GoalRules.overallGoal(hero, farWeapon), hero);
      expect(GoalRules.overallGoal(hero, weapon), hero);
      expect(GoalRules.overallGoal(null, weapon), weapon);
      expect(GoalRules.overallGoal(null, null), isNull);
    });
  });

  test('GoalService reads the services', () async {
    SharedPreferences.setMockInitialValues({
      'star_wallet': 4,
      'unlocked_heroes': ['blaze'],
      'selected_hero': 'blaze',
      'unlocked_weapons': ['star_blaster'],
      'world_progress_candy_crater': 1,
    });
    final s = GoalService();
    expect((await s.heroGoal())!.itemId, 'frost');
    expect((await s.weaponGoal())!.itemId, 'flame_sword');
    final w = (await s.worldGoal())!;
    expect(w.itemId, 'slime_swamp');
    expect(w.left, 4);
    expect((await s.overallGoal())!.itemId, 'frost');
  });
}
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/services/goal_service_test.dart`
Expected: FAIL. `goal_service.dart` doesn't exist.

- [ ] **Step 3: Implement**

```dart
// lib/services/goal_service.dart
import 'dart:math';

import 'hero_service.dart';
import 'streak_service.dart';
import 'weapon_service.dart';
import 'world_service.dart';

enum GoalCategory { hero, weapon, world }

/// The closest next unlock in one category (spec §5). A null goal means
/// the category is complete.
class Goal {
  final GoalCategory category;

  /// Hero id ('frost'), evolution id ('blaze_stage2'), weapon id, or — for
  /// worlds — the planet that unlocks next.
  final String itemId;

  /// Set for an evolution goal: the hero it upgrades.
  final String? evolutionHeroId;

  /// Evolution stage (2 or 3) for an evolution goal; 1 otherwise.
  final int stage;

  /// Stars (heroes, evolutions, weapons) or missions (worlds).
  final int cost;

  /// Wallet stars, or missions done in the frontier world.
  final int have;

  const Goal({
    required this.category,
    required this.itemId,
    this.evolutionHeroId,
    this.stage = 1,
    required this.cost,
    required this.have,
  });

  bool get isEvolution => evolutionHeroId != null;

  int get left => max(0, cost - have);

  /// Heroes, evolutions and weapons can be bought once the wallet covers
  /// them. Worlds unlock by brushing and are never bought.
  bool get affordable => category != GoalCategory.world && have >= cost;

  /// Hero to draw for a hero or evolution goal.
  String get heroId => evolutionHeroId ?? itemId;
}

/// Pure goal rules (no I/O).
class GoalRules {
  GoalRules._();

  /// Cheaper of: the next upgrade of the selected hero, the cheapest locked
  /// hero. A tie goes to the upgrade.
  static Goal? heroGoal({
    required List<String> unlockedHeroIds,
    required String selectedHeroId,
    required List<String> unlockedEvolutionIds,
    required int wallet,
  }) {
    var topStage = 1;
    for (final id in unlockedEvolutionIds) {
      final evo = HeroService.getEvolutionById(id);
      if (evo != null && evo.heroId == selectedHeroId && evo.stage > topStage) {
        topStage = evo.stage;
      }
    }
    Goal? upgrade;
    final nextEvo = HeroService.getEvolutionById(
      '${selectedHeroId}_stage${topStage + 1}',
    );
    if (nextEvo != null) {
      upgrade = Goal(
        category: GoalCategory.hero,
        itemId: nextEvo.id,
        evolutionHeroId: selectedHeroId,
        stage: nextEvo.stage,
        cost: nextEvo.price,
        have: wallet,
      );
    }

    Goal? newHero;
    for (final hero in HeroService.allHeroes) {
      if (unlockedHeroIds.contains(hero.id)) continue;
      if (newHero == null || hero.price < newHero.cost) {
        newHero = Goal(
          category: GoalCategory.hero,
          itemId: hero.id,
          cost: hero.price,
          have: wallet,
        );
      }
    }

    if (upgrade == null) return newHero;
    if (newHero == null) return upgrade;
    return newHero.cost < upgrade.cost ? newHero : upgrade;
  }

  static Goal? weaponGoal({
    required List<String> unlockedWeaponIds,
    required int wallet,
  }) {
    Goal? best;
    for (final weapon in WeaponService.allWeapons) {
      if (unlockedWeaponIds.contains(weapon.id)) continue;
      if (best == null || weapon.price < best.cost) {
        best = Goal(
          category: GoalCategory.weapon,
          itemId: weapon.id,
          cost: weapon.price,
          have: wallet,
        );
      }
    }
    return best;
  }

  /// Frontier = first unfinished world. The goal item is the planet that
  /// unlocks when the frontier is done (or the frontier itself if last).
  static Goal? worldGoal({required Map<String, int> progress}) {
    final worlds = WorldService.allWorlds;
    for (var i = 0; i < worlds.length; i++) {
      final w = worlds[i];
      final done = progress[w.id] ?? 0;
      if (done < w.missionsRequired) {
        final next = i + 1 < worlds.length ? worlds[i + 1] : w;
        return Goal(
          category: GoalCategory.world,
          itemId: next.id,
          cost: w.missionsRequired,
          have: done,
        );
      }
    }
    return null;
  }

  /// For the victory screen: fewest stars left; a tie goes to the hero.
  static Goal? overallGoal(Goal? hero, Goal? weapon) {
    if (hero == null) return weapon;
    if (weapon == null) return hero;
    return weapon.left < hero.left ? weapon : hero;
  }
}

/// Reads the current state and applies [GoalRules].
class GoalService {
  final HeroService _heroes;
  final WeaponService _weapons;
  final WorldService _worlds;
  final StreakService _streak;

  GoalService({
    HeroService? heroes,
    WeaponService? weapons,
    WorldService? worlds,
    StreakService? streak,
  }) : _heroes = heroes ?? HeroService(),
       _weapons = weapons ?? WeaponService(),
       _worlds = worlds ?? WorldService(),
       _streak = streak ?? StreakService();

  Future<Goal?> heroGoal() async => GoalRules.heroGoal(
    unlockedHeroIds: await _heroes.getUnlockedHeroIds(),
    selectedHeroId: await _heroes.getSelectedHeroId(),
    unlockedEvolutionIds: await _heroes.getUnlockedEvolutionIds(),
    wallet: await _streak.getWallet(),
  );

  Future<Goal?> weaponGoal() async => GoalRules.weaponGoal(
    unlockedWeaponIds: await _weapons.getUnlockedWeaponIds(),
    wallet: await _streak.getWallet(),
  );

  Future<Goal?> worldGoal() async {
    final progress = <String, int>{};
    for (final w in WorldService.allWorlds) {
      progress[w.id] = await _worlds.getWorldProgress(w.id);
    }
    return GoalRules.worldGoal(progress: progress);
  }

  Future<Goal?> overallGoal() async =>
      GoalRules.overallGoal(await heroGoal(), await weaponGoal());
}
```

Note: if `StreakService`'s constructor needs arguments in this codebase, adapt the default construction to match how other screens create it (they use `StreakService()`).

- [ ] **Step 4: Run the test and confirm it passes**

Run: `flutter test test/services/goal_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/services/goal_service.dart test/services/goal_service_test.dart
dart analyze
git add lib/services/goal_service.dart test/services/goal_service_test.dart
git commit -m "feat(goals): closest next unlock per category (pure rules + service)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: UnlockService (shared buy + equip), used by the shop

**Files:**
- Create: `lib/services/unlock_service.dart`
- Modify: `lib/screens/hero_shop_screen.dart`: the three purchase paths (hero at about lines 200-213; evolution at about 307-318; weapon at about 351-366)
- Test: `test/services/unlock_service_test.dart`

**Interfaces:**
- Consumes: `Goal`/`GoalCategory` (Task 3); `HeroService.purchaseHero/selectHero/purchaseEvolution/getSelectedHeroId/setEvolutionStage`, `HeroService.getEvolutionById`; `WeaponService.purchaseWeapon/selectWeapon`; `StreakService.getRangerRank`; `AnalyticsService().logHeroUnlock/logWeaponUnlock`.
- Produces: `class UnlockService { Future<bool> unlockHero(String heroId); Future<bool> unlockEvolution(String evolutionId); Future<bool> unlockWeapon(String weaponId); Future<bool> unlockGoal(Goal goal); }`.

  Semantics match the shop exactly:
  - hero: purchase, then select, then log `hero_unlock`;
  - evolution: purchase, then equip the stage only if that hero is selected;
  - weapon: purchase, then select, then log `weapon_unlock`;
  - returns false when the purchase fails;
  - a world goal returns false (worlds are not bought).

- [ ] **Step 1: Write the failing test**

```dart
// test/services/unlock_service_test.dart
import 'package:brush_quest/services/goal_service.dart';
import 'package:brush_quest/services/hero_service.dart';
import 'package:brush_quest/services/unlock_service.dart';
import 'package:brush_quest/services/weapon_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final unlock = UnlockService();

  Future<int> wallet() async =>
      (await SharedPreferences.getInstance()).getInt('star_wallet') ?? 0;

  test('hero: spends, unlocks and selects', () async {
    SharedPreferences.setMockInitialValues({'star_wallet': 7});
    expect(await unlock.unlockHero('frost'), isTrue);
    expect(await wallet(), 2);
    expect(await HeroService().getSelectedHeroId(), 'frost');
    expect(await HeroService().isHeroUnlocked('frost'), isTrue);
  });

  test('hero: not enough stars -> false, nothing changes', () async {
    SharedPreferences.setMockInitialValues({'star_wallet': 4});
    expect(await unlock.unlockHero('frost'), isFalse);
    expect(await wallet(), 4);
    expect(await HeroService().getSelectedHeroId(), 'blaze');
  });

  test('evolution of the selected hero is equipped', () async {
    SharedPreferences.setMockInitialValues({
      'star_wallet': 10,
      'selected_hero': 'blaze',
    });
    expect(await unlock.unlockEvolution('blaze_stage2'), isTrue);
    expect(await wallet(), 0);
    expect(await HeroService().getEvolutionStage('blaze'), 2);
  });

  test('evolution of another hero is bought but not equipped (shop rule)', () async {
    SharedPreferences.setMockInitialValues({
      'star_wallet': 12,
      'selected_hero': 'blaze',
      'unlocked_heroes': ['blaze', 'frost'],
    });
    expect(await unlock.unlockEvolution('frost_stage2'), isTrue);
    expect(await HeroService().getEvolutionStage('frost'), 1);
    expect(await HeroService().getSelectedHeroId(), 'blaze');
  });

  test('weapon: spends, unlocks and selects', () async {
    SharedPreferences.setMockInitialValues({'star_wallet': 5});
    expect(await unlock.unlockWeapon('flame_sword'), isTrue);
    expect(await wallet(), 0);
    expect(await WeaponService().getSelectedWeaponId(), 'flame_sword');
  });

  test('unlockGoal routes by category; worlds are never bought', () async {
    SharedPreferences.setMockInitialValues({'star_wallet': 10});
    const evo = Goal(
      category: GoalCategory.hero,
      itemId: 'blaze_stage2',
      evolutionHeroId: 'blaze',
      stage: 2,
      cost: 10,
      have: 10,
    );
    expect(await unlock.unlockGoal(evo), isTrue);
    const world = Goal(
      category: GoalCategory.world, itemId: 'slime_swamp', cost: 5, have: 5);
    expect(await unlock.unlockGoal(world), isFalse);
  });

  test('double unlock spends once', () async {
    SharedPreferences.setMockInitialValues({'star_wallet': 10});
    final results = await Future.wait([
      unlock.unlockHero('frost'),
      unlock.unlockHero('frost'),
    ]);
    expect(results.where((r) => r).length, greaterThanOrEqualTo(1));
    expect(await wallet(), 5); // spent exactly once
  });
}
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/services/unlock_service_test.dart`
Expected: FAIL. `unlock_service.dart` doesn't exist.

- [ ] **Step 3: Implement the service**

```dart
// lib/services/unlock_service.dart
import 'dart:async';

import 'analytics_service.dart';
import 'goal_service.dart';
import 'hero_service.dart';
import 'streak_service.dart';
import 'weapon_service.dart';

/// Buy an item and equip it — the steps the shop runs after its
/// confirmation dialog (hero_shop_screen.dart), shared with the victory
/// screen's one-tap unlock (spec §6 step 4). Purchases keep the existing
/// `StreakService.isPurchasing` guard, so a double tap spends once.
class UnlockService {
  final HeroService _heroes;
  final WeaponService _weapons;
  final StreakService _streak;

  UnlockService({
    HeroService? heroes,
    WeaponService? weapons,
    StreakService? streak,
  }) : _heroes = heroes ?? HeroService(),
       _weapons = weapons ?? WeaponService(),
       _streak = streak ?? StreakService();

  Future<bool> unlockHero(String heroId) async {
    if (!await _heroes.purchaseHero(heroId)) return false;
    await _heroes.selectHero(heroId);
    final rank = await _streak.getRangerRank();
    unawaited(
      AnalyticsService().logHeroUnlock(heroId: heroId, starsAtUnlock: rank),
    );
    return true;
  }

  /// Equips the new stage only if that hero is the selected one — otherwise
  /// the child's hero would silently switch (same rule as the shop).
  Future<bool> unlockEvolution(String evolutionId) async {
    final evo = HeroService.getEvolutionById(evolutionId);
    if (evo == null) return false;
    if (!await _heroes.purchaseEvolution(evolutionId)) return false;
    if (await _heroes.getSelectedHeroId() == evo.heroId) {
      await _heroes.setEvolutionStage(evo.heroId, evo.stage);
    }
    return true;
  }

  Future<bool> unlockWeapon(String weaponId) async {
    if (!await _weapons.purchaseWeapon(weaponId)) return false;
    await _weapons.selectWeapon(weaponId);
    final rank = await _streak.getRangerRank();
    unawaited(
      AnalyticsService().logWeaponUnlock(
        weaponId: weaponId,
        starsAtUnlock: rank,
      ),
    );
    return true;
  }

  Future<bool> unlockGoal(Goal goal) {
    switch (goal.category) {
      case GoalCategory.hero:
        return goal.isEvolution
            ? unlockEvolution(goal.itemId)
            : unlockHero(goal.itemId);
      case GoalCategory.weapon:
        return unlockWeapon(goal.itemId);
      case GoalCategory.world:
        return Future.value(false);
    }
  }
}
```

- [ ] **Step 4: Use it in the shop.** Behaviour must stay identical. In `hero_shop_screen.dart`, add the field `final _unlock = UnlockService();` and the import. Then replace exactly these blocks:
  1. **Hero purchase.** Replace `final success = await _heroService.purchaseHero(hero.id);` and the following `if (success) { await _heroService.selectHero(hero.id); ... logHeroUnlock(...); ...` with `final success = await _unlock.unlockHero(hero.id);`. Keep the body `if (success) { unawaited(HapticFeedback.heavyImpact()); if (mounted) _showHeroUnlockAnimation(hero); await _loadData(); }`. Remove the now-duplicated `selectHero` and analytics lines.
  2. **Evolution purchase.** Replace `final success = await _heroService.purchaseEvolution(evolution.id);` and the `currentHero` / `setEvolutionStage` block inside `if (success)` with `final success = await _unlock.unlockEvolution(evolution.id);`. Keep `unawaited(HapticFeedback.heavyImpact()); await _loadData();`.
  3. **Weapon purchase.** Replace `final success = await _weaponService.purchaseWeapon(weapon.id);`, plus the `selectWeapon` and `logWeaponUnlock` calls inside `if (success)`, with `final success = await _unlock.unlockWeapon(weapon.id);`. Keep the haptic, `_showWeaponUnlockAnimation(weapon)` and `_loadData()`.

  The shop's `starsAtUnlock` used `_rank` (Ranger Rank). `UnlockService` reads `getRangerRank()`, which is the same value.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/services/unlock_service_test.dart test/screens/` (the shop tests live under `test/screens/`; run the whole folder)
Expected: PASS, with no change to existing shop tests.

- [ ] **Step 6: Commit**

```bash
dart format lib/services/unlock_service.dart lib/screens/hero_shop_screen.dart test/services/unlock_service_test.dart
dart analyze
git add lib/services/unlock_service.dart lib/screens/hero_shop_screen.dart test/services/unlock_service_test.dart
git commit -m "refactor(shop): shared UnlockService for buy + equip (no behaviour change)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Voice clips + AudioService helpers (controller-run: needs the ElevenLabs MCP)

**Files:**
- Create: 39 clips in `assets/audio/voices/buddy/` (listed below)
- Modify: `lib/services/audio_service.dart`: add two helpers next to `heroPickerVoiceFor` (about line 539)
- Modify: `test/audio/audio_assets_test.dart`: add a named const list `_audioFilesBrushFlow` and merge it into the list the test checks, following how the existing named lists are merged
- Test: `test/audio/brush_flow_voice_helpers_test.dart` (new)

**Interfaces:**
- Produces: `String starsLeftVoiceFor(int left)` → `voice_stars_left_<1..10>.mp3`, or `voice_stars_left_many.mp3` above 10. `String brushesLeftVoiceFor(int left)` → `voice_brushes_left_<n>.mp3`, with n clamped to 1..10. Plus the file names in the table.

**Clip list (exact text; George voice):**

| File | Text |
|---|---|
| `voice_flame_grow.mp3` | You brushed again! Your flame keeps growing! |
| `voice_flame_tier_3.mp3` | Three days of brushing in a row — your flame got bigger! A big flame gives you a bonus star every time you brush! |
| `voice_flame_tier_7.mp3` | A whole week of brushing! Your flame is super hot — now it gives you two bonus stars! |
| `voice_flame_tier_14.mp3` | Two weeks of brushing every day — you have the golden flame! |
| `voice_flame_bonus_1.mp3` | Your flame gave you a bonus star for brushing every day! |
| `voice_flame_bonus_2.mp3` | Your super flame gave you two bonus stars! |
| `voice_flame_new.mp3` | A new flame! Brush tomorrow to make it grow! |
| `voice_flame_see_you_next.mp3` | See you tomorrow! One more day for a bigger flame! |
| `voice_flame_see_you_keep.mp3` | See you tomorrow! Keep your flame growing! |
| `voice_flame_welcome_1.mp3` | Welcome back! You brush every day, so your flame gives you a star! |
| `voice_flame_welcome_2.mp3` | Welcome back! Your super flame gives you two stars! |
| `voice_flame_got_bigger.mp3` | Your flame got bigger! |
| `voice_stars_left_1.mp3` … `_10.mp3` | One more star! / Two more stars! / … / Ten more stars! |
| `voice_stars_left_many.mp3` | Lots more stars to go! |
| `voice_brushes_left_1.mp3` … `_10.mp3` | One more brush! / Two more brushes! / … / Ten more brushes! |
| `voice_tap_to_unlock.mp3` | Tap to unlock it! |
| `voice_unlocked_yours.mp3` | It's yours! Great job, Ranger! |
| `voice_have_them_all.mp3` | You have them all! |
| `voice_need_more_brushes.mp3` | Keep brushing to reach this planet! |
| `voice_ready_to_unlock.mp3` | Brush to unlock it! |

- [ ] **Step 1: Write the failing helper test**

```dart
// test/audio/brush_flow_voice_helpers_test.dart
import 'package:brush_quest/services/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final audio = AudioService();
  test('stars-left clips 1..10, then "lots more"', () {
    expect(audio.starsLeftVoiceFor(1), 'voice_stars_left_1.mp3');
    expect(audio.starsLeftVoiceFor(10), 'voice_stars_left_10.mp3');
    expect(audio.starsLeftVoiceFor(11), 'voice_stars_left_many.mp3');
    expect(audio.starsLeftVoiceFor(35), 'voice_stars_left_many.mp3');
  });
  test('brushes-left clips are clamped to 1..10', () {
    expect(audio.brushesLeftVoiceFor(1), 'voice_brushes_left_1.mp3');
    expect(audio.brushesLeftVoiceFor(10), 'voice_brushes_left_10.mp3');
    expect(audio.brushesLeftVoiceFor(0), 'voice_brushes_left_1.mp3');
    expect(audio.brushesLeftVoiceFor(12), 'voice_brushes_left_10.mp3');
  });
}
```

Run: `flutter test test/audio/brush_flow_voice_helpers_test.dart`. Expected: FAIL (methods don't exist).

- [ ] **Step 2: Add the helpers** in `audio_service.dart` next to `heroPickerVoiceFor`:

```dart
  /// "One more star!" … "Ten more stars!"; "Lots more stars to go!" above 10.
  String starsLeftVoiceFor(int left) => left >= 1 && left <= 10
      ? 'voice_stars_left_$left.mp3'
      : 'voice_stars_left_many.mp3';

  /// "One more brush!" … "Ten more brushes!" (worlds need at most 10).
  String brushesLeftVoiceFor(int left) =>
      'voice_brushes_left_${left.clamp(1, 10)}.mp3';
```

Run the helper test. Expected: PASS.

- [ ] **Step 3: Generate the clips.**
  - Use ElevenLabs `text_to_speech` with the premade voice **George**: find it with `search_voices` "George" and confirm it's the voice used for the existing Buddy clips by ear on one existing clip. Model `eleven_multilingual_v2`; output an mp3 at 44.1 kHz.
  - Save the raw files to the scratchpad. Convert each to the house format:
    ```bash
    ffmpeg -y -i RAW.mp3 -af "silenceremove=start_periods=1:start_threshold=-50dB,areverse,silenceremove=start_periods=1:start_threshold=-50dB,areverse,loudnorm=I=-24:TP=-3:LRA=7" -ar 22050 -ac 1 -b:a 64k assets/audio/voices/buddy/NAME.mp3
    ```
  - Check every file: `ffprobe` shows mp3/22050/mono, and `loudnorm` summary reads −25 to −23 LUFS.
  - Listen to three of them (`afplay`). Short clips must be under 1.5 s ("Three more stars!"); the flame lines run 2–5 s.

- [ ] **Step 4: Register the clips in `audio_assets_test.dart`** (the new `_audioFilesBrushFlow` list with all 39 names, merged like the existing lists). Run `flutter test test/audio/audio_assets_test.dart`. Expected: PASS (every listed file exists).

- [ ] **Step 5: Commit**

```bash
dart format lib/services/audio_service.dart test/audio/brush_flow_voice_helpers_test.dart test/audio/audio_assets_test.dart
dart analyze
git add lib/services/audio_service.dart test/audio/brush_flow_voice_helpers_test.dart test/audio/audio_assets_test.dart assets/audio/voices/buddy/voice_flame_*.mp3 assets/audio/voices/buddy/voice_stars_left_*.mp3 assets/audio/voices/buddy/voice_brushes_left_*.mp3 assets/audio/voices/buddy/voice_tap_to_unlock.mp3 assets/audio/voices/buddy/voice_unlocked_yours.mp3 assets/audio/voices/buddy/voice_have_them_all.mp3 assets/audio/voices/buddy/voice_need_more_brushes.mp3 assets/audio/voices/buddy/voice_ready_to_unlock.mp3
git commit -m "feat(audio): Buddy clips for the brush flow and streak flame" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Widgets — goal meter, silhouette, carousel, flame

**Files:**
- Create: `lib/widgets/goal_meter.dart`, `lib/widgets/item_silhouette.dart`, `lib/widgets/loadout_carousel.dart`, `lib/widgets/flame_view.dart`
- Test: `test/widgets/brush_flow_widgets_test.dart`

**Interfaces:**
- Consumes: `FlameTier`, `flameTierFor`, `daysToNextFlameTier`, `chestTierFor`, `ChestTier` (Task 1).
- Produces:
  - `GoalMeter({required int have, required int cost, GoalMeterStyle style = GoalMeterStyle.stars, bool complete = false, double unit = 22})`, `enum GoalMeterStyle { stars, rockets }`. Keys: filled slots `ValueKey('meter_filled')`, empty slots `ValueKey('meter_empty')`, bar `ValueKey('meter_bar')`, crown `ValueKey('meter_crown')`.
  - `ItemSilhouette({required Widget child, double opacity = 0.85})`.
  - `LoadoutItem({required String id, required Widget image})`; `LoadoutCarousel({required List<LoadoutItem> items, required String selectedId, required ValueChanged<String> onSelected, required VoidCallback onInteraction})`. Arrow buttons have keys `ValueKey('carousel_prev')` / `ValueKey('carousel_next')`.
  - `FlameIcon({required FlameTier tier})`, sizes 22/26/30/32/34 for none/small/big/hot/golden. `FlameStrip({required int streak})`: the current `FlameIcon`, then one `ValueKey('flame_day_empty')` icon per day to the next step, then the next `FlameIcon` and a chest-tier badge. At golden, the golden flame alone.

- [ ] **Step 1: Write the failing widget tests**

```dart
// test/widgets/brush_flow_widgets_test.dart
import 'package:brush_quest/services/flame_tier.dart';
import 'package:brush_quest/widgets/flame_view.dart';
import 'package:brush_quest/widgets/goal_meter.dart';
import 'package:brush_quest/widgets/item_silhouette.dart';
import 'package:brush_quest/widgets/loadout_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('GoalMeter', () {
    testWidgets('up to 10 stars: one slot per star', (tester) async {
      await tester.pumpWidget(_wrap(const GoalMeter(have: 5, cost: 8)));
      expect(find.byKey(const ValueKey('meter_filled')), findsNWidgets(5));
      expect(find.byKey(const ValueKey('meter_empty')), findsNWidgets(3));
      expect(find.byKey(const ValueKey('meter_bar')), findsNothing);
    });
    testWidgets('wallet above the price fills every slot', (tester) async {
      await tester.pumpWidget(_wrap(const GoalMeter(have: 12, cost: 8)));
      expect(find.byKey(const ValueKey('meter_filled')), findsNWidgets(8));
      expect(find.byKey(const ValueKey('meter_empty')), findsNothing);
    });
    testWidgets('above 10 stars: a bar', (tester) async {
      await tester.pumpWidget(_wrap(const GoalMeter(have: 7, cost: 25)));
      expect(find.byKey(const ValueKey('meter_bar')), findsOneWidget);
      expect(find.byKey(const ValueKey('meter_filled')), findsNothing);
    });
    testWidgets('rockets: one per mission', (tester) async {
      await tester.pumpWidget(_wrap(const GoalMeter(
        have: 2, cost: 5, style: GoalMeterStyle.rockets)));
      expect(find.byKey(const ValueKey('meter_filled')), findsNWidgets(2));
      expect(find.byKey(const ValueKey('meter_empty')), findsNWidgets(3));
    });
    testWidgets('complete shows the crown only', (tester) async {
      await tester.pumpWidget(_wrap(const GoalMeter(
        have: 0, cost: 0, complete: true)));
      expect(find.byKey(const ValueKey('meter_crown')), findsOneWidget);
      expect(find.byKey(const ValueKey('meter_empty')), findsNothing);
    });
  });

  testWidgets('ItemSilhouette wraps its child in a black color filter',
      (tester) async {
    await tester.pumpWidget(_wrap(const ItemSilhouette(
      child: SizedBox(width: 10, height: 10, key: ValueKey('child')))));
    expect(find.byKey(const ValueKey('child')), findsOneWidget);
    expect(find.byType(ColorFiltered), findsOneWidget);
  });

  group('LoadoutCarousel', () {
    final items = [
      for (final id in ['a', 'b', 'c'])
        LoadoutItem(id: id, image: SizedBox(key: ValueKey('img_$id'), width: 50, height: 50)),
    ];
    testWidgets('arrows move the choice and report a touch', (tester) async {
      String? selected;
      var touches = 0;
      await tester.pumpWidget(_wrap(SizedBox(
        width: 360, height: 300,
        child: LoadoutCarousel(
          items: items,
          selectedId: 'a',
          onSelected: (id) => selected = id,
          onInteraction: () => touches++,
        ),
      )));
      await tester.tap(find.byKey(const ValueKey('carousel_next')));
      await tester.pumpAndSettle();
      expect(selected, 'b');
      expect(touches, greaterThanOrEqualTo(1));
      await tester.tap(find.byKey(const ValueKey('carousel_prev')));
      await tester.pumpAndSettle();
      expect(selected, 'a');
    });
    testWidgets('a single item hides the arrows', (tester) async {
      await tester.pumpWidget(_wrap(SizedBox(
        width: 360, height: 300,
        child: LoadoutCarousel(
          items: [items.first],
          selectedId: 'a',
          onSelected: (_) {},
          onInteraction: () {},
        ),
      )));
      expect(find.byKey(const ValueKey('carousel_next')), findsNothing);
      expect(find.byKey(const ValueKey('carousel_prev')), findsNothing);
    });
  });

  group('Flame', () {
    testWidgets('FlameIcon grows with the tier', (tester) async {
      double sizeFor(FlameTier t) {
        return (tester.widget(find.byType(Icon).last) as Icon).size!;
      }
      await tester.pumpWidget(_wrap(const FlameIcon(tier: FlameTier.small)));
      final small = sizeFor(FlameTier.small);
      await tester.pumpWidget(_wrap(const FlameIcon(tier: FlameTier.golden)));
      expect(sizeFor(FlameTier.golden), greaterThan(small));
    });
    testWidgets('FlameStrip shows days left to the next step', (tester) async {
      await tester.pumpWidget(_wrap(const FlameStrip(streak: 1)));
      expect(find.byKey(const ValueKey('flame_day_empty')), findsNWidgets(2));
      await tester.pumpWidget(_wrap(const FlameStrip(streak: 13)));
      expect(find.byKey(const ValueKey('flame_day_empty')), findsNWidgets(1));
      await tester.pumpWidget(_wrap(const FlameStrip(streak: 20)));
      expect(find.byKey(const ValueKey('flame_day_empty')), findsNothing);
    });
  });
}
```

Run: `flutter test test/widgets/brush_flow_widgets_test.dart`. Expected: FAIL (files missing).

- [ ] **Step 2: Implement `goal_meter.dart`**

```dart
// lib/widgets/goal_meter.dart
import 'package:flutter/material.dart';

enum GoalMeterStyle { stars, rockets }

/// How close a goal is, for a child who can't read: star slots (up to 10),
/// a star bar (more than 10), rocket slots (world missions), or a crown
/// when the category is complete (spec §4.1).
class GoalMeter extends StatelessWidget {
  final int have;
  final int cost;
  final GoalMeterStyle style;
  final bool complete;
  final double unit;

  const GoalMeter({
    super.key,
    required this.have,
    required this.cost,
    this.style = GoalMeterStyle.stars,
    this.complete = false,
    this.unit = 22,
  });

  static const _maxSlots = 10;

  @override
  Widget build(BuildContext context) {
    if (complete) {
      return Icon(
        Icons.workspace_premium,
        key: const ValueKey('meter_crown'),
        color: Colors.amberAccent,
        size: unit * 1.8,
      );
    }
    final filled = have.clamp(0, cost);
    final rockets = style == GoalMeterStyle.rockets;
    if (!rockets && cost > _maxSlots) {
      final fraction = cost == 0 ? 1.0 : filled / cost;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            key: const ValueKey('meter_bar'),
            width: unit * 8,
            height: unit * 0.7,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(unit),
              color: Colors.white.withValues(alpha: 0.15),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: fraction,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(unit),
                  color: Colors.amberAccent,
                ),
              ),
            ),
          ),
          SizedBox(width: unit * 0.3),
          Icon(Icons.star, color: Colors.amberAccent, size: unit * 1.2),
        ],
      );
    }
    final icon = rockets ? Icons.rocket_launch : Icons.star;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: unit * 0.15,
      children: [
        for (var i = 0; i < cost; i++)
          Icon(
            icon,
            key: ValueKey(i < filled ? 'meter_filled' : 'meter_empty'),
            size: unit,
            color: i < filled
                ? (rockets ? Colors.cyanAccent : Colors.amberAccent)
                : Colors.white.withValues(alpha: 0.25),
          ),
      ],
    );
  }
}
```

- [ ] **Step 3: Implement `item_silhouette.dart`**

```dart
// lib/widgets/item_silhouette.dart
import 'package:flutter/material.dart';

/// A dark silhouette of [child] (keeps its shape, paints it black) for a
/// locked "next goal" item.
class ItemSilhouette extends StatelessWidget {
  final Widget child;
  final double opacity;

  const ItemSilhouette({super.key, required this.child, this.opacity = 0.85});

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        Colors.black.withValues(alpha: opacity),
        BlendMode.srcATop,
      ),
      child: child,
    );
  }
}
```

- [ ] **Step 4: Implement `loadout_carousel.dart`**

```dart
// lib/widgets/loadout_carousel.dart
import 'package:flutter/material.dart';

class LoadoutItem {
  final String id;
  final Widget image;
  const LoadoutItem({required this.id, required this.image});
}

/// Owned items in a swipe row: the choice is centred and big, neighbours
/// peek in from the sides, ‹ › arrows for kids who don't swipe (spec §4.1).
class LoadoutCarousel extends StatefulWidget {
  final List<LoadoutItem> items;
  final String selectedId;
  final ValueChanged<String> onSelected;

  /// Any touch — pauses the step's auto-advance.
  final VoidCallback onInteraction;

  const LoadoutCarousel({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onSelected,
    required this.onInteraction,
  });

  @override
  State<LoadoutCarousel> createState() => _LoadoutCarouselState();
}

class _LoadoutCarouselState extends State<LoadoutCarousel> {
  late PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = _indexOf(widget.selectedId);
    _controller = PageController(viewportFraction: 0.6, initialPage: _index);
  }

  int _indexOf(String id) {
    final i = widget.items.indexWhere((item) => item.id == id);
    return i < 0 ? 0 : i;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int delta) {
    widget.onInteraction();
    final next = (_index + delta).clamp(0, widget.items.length - 1);
    if (next == _index) return;
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final many = widget.items.length > 1;
    return Listener(
      onPointerDown: (_) => widget.onInteraction(),
      child: Row(
        children: [
          if (many)
            IconButton(
              key: const ValueKey('carousel_prev'),
              iconSize: 48,
              color: Colors.white70,
              icon: const Icon(Icons.chevron_left),
              onPressed: _index > 0 ? () => _go(-1) : null,
            ),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.items.length,
              onPageChanged: (i) {
                setState(() => _index = i);
                widget.onSelected(widget.items[i].id);
              },
              itemBuilder: (context, i) => AnimatedScale(
                scale: i == _index ? 1.0 : 0.7,
                duration: const Duration(milliseconds: 200),
                child: AnimatedOpacity(
                  opacity: i == _index ? 1.0 : 0.5,
                  duration: const Duration(milliseconds: 200),
                  child: widget.items[i].image,
                ),
              ),
            ),
          ),
          if (many)
            IconButton(
              key: const ValueKey('carousel_next'),
              iconSize: 48,
              color: Colors.white70,
              icon: const Icon(Icons.chevron_right),
              onPressed: _index < widget.items.length - 1
                  ? () => _go(1)
                  : null,
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Implement `flame_view.dart`**

```dart
// lib/widgets/flame_view.dart
import 'package:flutter/material.dart';

import '../services/flame_tier.dart';

/// The streak flame in four steps (spec §7.1), drawn with the same Material
/// icon the Home streak pill already uses.
class FlameIcon extends StatelessWidget {
  final FlameTier tier;
  const FlameIcon({super.key, required this.tier});

  static double sizeFor(FlameTier tier) => switch (tier) {
    FlameTier.none => 22,
    FlameTier.small => 26,
    FlameTier.big => 30,
    FlameTier.hot => 32,
    FlameTier.golden => 34,
  };

  static Color colorFor(FlameTier tier) => switch (tier) {
    FlameTier.none => Colors.white30,
    FlameTier.small => Colors.orangeAccent,
    FlameTier.big => Colors.deepOrangeAccent,
    FlameTier.hot => Colors.lightBlueAccent,
    FlameTier.golden => Colors.amber,
  };

  @override
  Widget build(BuildContext context) {
    final glow = tier == FlameTier.hot || tier == FlameTier.golden;
    return Icon(
      Icons.local_fire_department,
      size: sizeFor(tier),
      color: colorFor(tier),
      shadows: glow
          ? [Shadow(color: colorFor(tier), blurRadius: 12)]
          : null,
    );
  }
}

/// Today's flame, the days still to brush (empty small flames), then the
/// next flame and its chest tier. At the golden flame: the flame alone.
class FlameStrip extends StatelessWidget {
  final int streak;
  const FlameStrip({super.key, required this.streak});

  @override
  Widget build(BuildContext context) {
    final current = flameTierFor(streak);
    final days = daysToNextFlameTier(streak);
    final nextAt = nextFlameTierAt(streak);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FlameIcon(tier: current),
        if (days != null && nextAt != null) ...[
          const SizedBox(width: 8),
          for (var i = 0; i < days; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Icon(
                Icons.local_fire_department,
                key: const ValueKey('flame_day_empty'),
                size: 18,
                color: Colors.white.withValues(alpha: 0.25),
              ),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_forward, size: 18, color: Colors.white54),
          const SizedBox(width: 4),
          FlameIcon(tier: flameTierFor(nextAt)),
          const SizedBox(width: 6),
          _ChestBadge(tier: chestTierFor(nextAt)),
        ],
      ],
    );
  }
}

class _ChestBadge extends StatelessWidget {
  final ChestTier tier;
  const _ChestBadge({required this.tier});

  @override
  Widget build(BuildContext context) {
    final color = switch (tier) {
      ChestTier.wooden => const Color(0xFF8D5A33),
      ChestTier.silver => const Color(0xFFB0BEC5),
      ChestTier.gold => const Color(0xFFFFD54F),
    };
    return Icon(Icons.inventory_2, size: 22, color: color);
  }
}
```

- [ ] **Step 6: Run the widget tests and confirm they pass**

Run: `flutter test test/widgets/brush_flow_widgets_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
dart format lib/widgets/goal_meter.dart lib/widgets/item_silhouette.dart lib/widgets/loadout_carousel.dart lib/widgets/flame_view.dart test/widgets/brush_flow_widgets_test.dart
dart analyze
git add lib/widgets/goal_meter.dart lib/widgets/item_silhouette.dart lib/widgets/loadout_carousel.dart lib/widgets/flame_view.dart test/widgets/brush_flow_widgets_test.dart
git commit -m "feat(widgets): goal meter, silhouette, loadout carousel, streak flame" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Pre-brush screen, brushing hand-off, Home routing

**Files:**
- Create: `lib/screens/pre_brush_screen.dart`
- Modify: `lib/screens/brushing_screen.dart`: constructor (line 21-22) and `_prepareSession()` (about line 863)
- Modify: `lib/screens/home_screen.dart`: `_startBrushingFlow()` (about lines 704-727) and `_launchBrushingScreen()` (about 729-778)
- Modify: `lib/services/analytics_service.dart`: add `logPreBrushChange({required String category})` and `logPreBrushSkipped({required String reason})`, following the existing `if (!_enabled) return; await _fa.logEvent(...)` pattern
- Test: `test/screens/pre_brush_screen_test.dart` (new); add to `test/screens/home_screen_test.dart`

**Interfaces:**
- Consumes:
  - `GoalService`/`Goal` (Task 3), `GoalMeter`/`ItemSilhouette`/`LoadoutCarousel` (Task 6);
  - `AudioService().starsLeftVoiceFor/brushesLeftVoiceFor/heroPickerVoiceFor/evolutionPickerVoiceFor/weaponPickerVoiceFor`, `voicePipelineActiveNotifier`;
  - `HeroService.buildHeroImage(heroId, stage:, weaponId:, size:)`, `HeroService.evolutionsForHero`, `WeaponService.getWeaponById(id).imagePath`, `WorldService.getWorldById(id).imagePath`, `StreakService.getHistory()` (`BrushRecord.worldId`).
- Produces:
  - `PreBrushScreen()` with static test knobs `minStep`, `maxStep`, `maxBriefingStep`, `idleAfterTouch`, `launchDelay` (Durations) and `debugBrushingBuilder` (`Widget Function(bool showWorldIntro)?`);
  - `BrushingScreen({bool showWorldIntro = true})`;
  - `enum PreBrushStep { hero, weapon, world }`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/screens/pre_brush_screen_test.dart
import 'package:brush_quest/screens/pre_brush_screen.dart';
import 'package:brush_quest/services/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/fake_audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeAudioService audio;
  bool? launchedWithIntro;

  setUp(() {
    audio = FakeAudioService();
    AudioService.testInstance = audio;
    launchedWithIntro = null;
    PreBrushScreen.minStep = const Duration(milliseconds: 300);
    PreBrushScreen.maxStep = const Duration(milliseconds: 500);
    PreBrushScreen.maxBriefingStep = const Duration(milliseconds: 800);
    PreBrushScreen.idleAfterTouch = const Duration(milliseconds: 400);
    PreBrushScreen.launchDelay = const Duration(milliseconds: 50);
    PreBrushScreen.debugBrushingBuilder = (intro) {
      launchedWithIntro = intro;
      return const Scaffold(body: Text('BRUSHING'));
    };
  });

  tearDown(() {
    AudioService.testInstance = null;
    PreBrushScreen.debugBrushingBuilder = null;
  });

  Future<void> pumpScreen(WidgetTester tester, Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    await tester.pumpWidget(const MaterialApp(home: PreBrushScreen()));
    await tester.pump(); // load
    await tester.pump();
  }

  List<String> voices() => audio.playedVoiceLines;

  final returningKid = <String, Object>{
    'total_brushes': 4,
    'star_wallet': 3,
    'unlocked_heroes': ['blaze'],
    'selected_hero': 'blaze',
    'unlocked_weapons': ['star_blaster'],
    'selected_weapon': 'star_blaster',
    'current_world': 'candy_crater',
    'world_progress_candy_crater': 2,
    'brush_history': [
      '{"date":"2026-10-04","time":"19:30","heroId":"blaze","worldId":"candy_crater"}',
    ],
  };

  // The fake never raises voicePipelineActiveNotifier, so each step advances
  // at minStep (300 ms). Pump 350 ms per step: long enough for one step,
  // short enough not to run into the next step's timer (which starts later).
  const oneStep = Duration(milliseconds: 350);

  testWidgets('three steps auto-advance, then brushing without its world intro',
      (tester) async {
    await pumpScreen(tester, returningKid);
    expect(find.byKey(const ValueKey('prebrush_step_hero')), findsOneWidget);
    expect(voices().first, 'voice_stars_left_2.mp3'); // frost 5 - wallet 3
    await tester.pump(oneStep); // hero -> weapon
    expect(find.byKey(const ValueKey('prebrush_step_weapon')), findsOneWidget);
    expect(voices().last, 'voice_stars_left_2.mp3'); // flame sword 5 - 3
    await tester.pump(oneStep); // weapon -> world
    expect(find.byKey(const ValueKey('prebrush_step_world')), findsOneWidget);
    expect(voices().last, 'voice_brushes_left_3.mp3'); // 5 - 2, same planet
    await tester.pump(oneStep); // world -> fight
    expect(voices().last, 'voice_lets_fight.mp3');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('BRUSHING'), findsOneWidget);
    expect(launchedWithIntro, isFalse);
    expect(voices(), [
      'voice_stars_left_2.mp3',
      'voice_stars_left_2.mp3',
      'voice_brushes_left_3.mp3',
      'voice_lets_fight.mp3',
    ]);
  });

  testWidgets('a new planet plays its full briefing', (tester) async {
    final prefs = Map<String, Object>.from(returningKid)
      ..['current_world'] = 'slime_swamp'
      ..['world_progress_candy_crater'] = 5;
    await pumpScreen(tester, prefs);
    await tester.pump(oneStep);
    await tester.pump(oneStep);
    expect(voices(), contains('voice_world_slime_swamp.mp3'));
    expect(voices().last, 'voice_brushes_left_5.mp3'); // slime_swamp 0 of 5
  });

  testWidgets('a touch pauses auto-advance; idle continues', (tester) async {
    PreBrushScreen.idleAfterTouch = const Duration(seconds: 1);
    final prefs = Map<String, Object>.from(returningKid)
      ..['unlocked_heroes'] = ['blaze', 'frost'];
    await pumpScreen(tester, prefs);
    await tester.tap(find.byKey(const ValueKey('carousel_next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // page animation
    expect(find.byKey(const ValueKey('prebrush_go')), findsOneWidget);
    expect(voices(), contains('voice_picker_hero_frost.mp3'));
    // Past minStep and maxStep, but still on the hero step: the touch paused it.
    expect(find.byKey(const ValueKey('prebrush_step_hero')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 900)); // 1 s idle elapsed
    expect(find.byKey(const ValueKey('prebrush_step_weapon')), findsOneWidget);
    final p = await SharedPreferences.getInstance();
    expect(p.getString('selected_hero'), 'frost');
  });

  testWidgets('GO advances at once', (tester) async {
    PreBrushScreen.idleAfterTouch = const Duration(seconds: 1);
    final prefs = Map<String, Object>.from(returningKid)
      ..['unlocked_heroes'] = ['blaze', 'frost'];
    await pumpScreen(tester, prefs);
    await tester.tap(find.byKey(const ValueKey('carousel_next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('prebrush_go')));
    await tester.pump();
    expect(find.byKey(const ValueKey('prebrush_step_weapon')), findsOneWidget);
  });

  testWidgets('goal panel tap plays the need-more line for its category',
      (tester) async {
    await pumpScreen(tester, returningKid);
    await tester.tap(find.byKey(const ValueKey('prebrush_goal')));
    await tester.pump();
    expect(voices().last, 'voice_need_stars.mp3');
  });

  testWidgets('everything owned: crowns and "you have them all"', (tester) async {
    final all = <String, Object>{
      'total_brushes': 400,
      'star_wallet': 0,
      'unlocked_heroes': ['blaze', 'frost', 'bolt', 'shadow', 'leaf', 'nova'],
      'selected_hero': 'nova',
      'unlocked_evolutions': ['nova_stage2', 'nova_stage3'],
      'evolution_stage_nova': 3,
      'unlocked_weapons': [
        'star_blaster', 'flame_sword', 'ice_hammer',
        'lightning_wand', 'vine_whip', 'cosmic_burst',
      ],
      'current_world': 'dark_dimension',
    };
    for (final w in ['candy_crater', 'slime_swamp']) {
      all['world_progress_$w'] = 5;
    }
    all.addAll({
      'world_progress_sugar_volcano': 6, 'world_progress_shadow_nebula': 6,
      'world_progress_cavity_fortress': 7, 'world_progress_frozen_tundra': 7,
      'world_progress_toxic_jungle': 7, 'world_progress_crystal_cave': 8,
      'world_progress_storm_citadel': 8, 'world_progress_dark_dimension': 10,
    });
    await pumpScreen(tester, all);
    expect(find.byKey(const ValueKey('meter_crown')), findsOneWidget);
    expect(voices().first, 'voice_have_them_all.mp3');
  });

  testWidgets('advances at the cap when the voice never ends', (tester) async {
    await pumpScreen(tester, returningKid);
    audio.voicePipelineActiveNotifier.value = true; // stuck voice
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('prebrush_step_weapon')), findsOneWidget);
  });

  testWidgets('pause stops auto-advance; resume restarts the step', (tester) async {
    await pumpScreen(tester, returningKid);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const ValueKey('prebrush_step_hero')), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(oneStep);
    expect(find.byKey(const ValueKey('prebrush_step_weapon')), findsOneWidget);
  });

  testWidgets('a load error skips to brushing with its world intro',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'total_brushes': 3,
      'brush_history': ['not json'], // getHistory() throws FormatException
    });
    await tester.pumpWidget(const MaterialApp(home: PreBrushScreen()));
    await tester.pumpAndSettle();
    expect(find.text('BRUSHING'), findsOneWidget);
    expect(launchedWithIntro, isTrue);
  });
}
```

Note for the implementer: if `StreakService.getHistory()` already tolerates bad JSON, make the load-error test inject the failure another way. For example, add `@visibleForTesting static bool debugFailLoad = false;` on `PreBrushScreen`, checked at the top of `_load()`, and set it in that test. Don't remove the test.

Run: `flutter test test/screens/pre_brush_screen_test.dart`. Expected: FAIL (`pre_brush_screen.dart` doesn't exist).

- [ ] **Step 2: Add `showWorldIntro` to BrushingScreen.** In `brushing_screen.dart`:

```dart
class BrushingScreen extends StatefulWidget {
  /// False when the child came through the pre-brush steps: the World step
  /// already introduced the planet, so the session starts at the countdown.
  final bool showWorldIntro;
  const BrushingScreen({super.key, this.showWorldIntro = true});
```

In `_prepareSession()`, replace `if (!restored) { unawaited(_startWorldIntro()); }` with:

```dart
    if (!restored) {
      if (widget.showWorldIntro) {
        unawaited(_startWorldIntro());
      } else {
        unawaited(_skipWorldIntro());
      }
    }
```

Add, next to `_dismissWorldIntro()`:

```dart
  /// Pre-brush path: no world intro. Same hand-off as _dismissWorldIntro
  /// (stop the last pre-brush voice, yield a microtask so "Three!" isn't
  /// dropped on Android, then count down).
  Future<void> _skipWorldIntro() async {
    unawaited(_audio.stopVoice());
    if (!mounted) return;
    setState(() => _showWorldIntro = false);
    await Future<void>.value();
    if (!mounted) return;
    setState(() => _sessionStage = SessionStage.countdown);
    _startCountdown();
  }
```

- [ ] **Step 3: Implement `pre_brush_screen.dart`**

```dart
// lib/screens/pre_brush_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../services/goal_service.dart';
import '../services/hero_service.dart';
import '../services/streak_service.dart';
import '../services/weapon_service.dart';
import '../services/world_service.dart';
import '../widgets/goal_meter.dart';
import '../widgets/item_silhouette.dart';
import '../widgets/loadout_carousel.dart';
import '../widgets/space_background.dart';
import 'brushing_screen.dart';

enum PreBrushStep { hero, weapon, world }

/// Hero → Weapon → World before each brush (spec
/// docs/superpowers/specs/2026-10-05-brush-flow-and-hooks-design.md §4).
/// Each step shows the child's choice in a carousel of everything he owns,
/// and the closest next unlock as a silhouette with a meter. Steps advance
/// by themselves; any touch pauses until he stops touching.
class PreBrushScreen extends StatefulWidget {
  const PreBrushScreen({super.key});

  @visibleForTesting
  static Duration minStep = const Duration(seconds: 3);
  @visibleForTesting
  static Duration maxStep = const Duration(seconds: 5);
  @visibleForTesting
  static Duration maxBriefingStep = const Duration(seconds: 8);
  @visibleForTesting
  static Duration idleAfterTouch = const Duration(seconds: 4);
  @visibleForTesting
  static Duration launchDelay = const Duration(milliseconds: 400);
  @visibleForTesting
  static Widget Function(bool showWorldIntro)? debugBrushingBuilder;

  @override
  State<PreBrushScreen> createState() => _PreBrushScreenState();
}

class _PreBrushScreenState extends State<PreBrushScreen>
    with WidgetsBindingObserver {
  final _heroes = HeroService();
  final _weapons = WeaponService();
  final _worlds = WorldService();
  final _streak = StreakService();
  final _goals = GoalService();
  AudioService get _audio => AudioService();

  PreBrushStep _step = PreBrushStep.hero;
  bool _loaded = false;
  bool _leaving = false;
  bool _touched = false;
  bool _minElapsed = false;

  String _heroId = 'blaze';
  int _heroStage = 1;
  String _weaponId = 'star_blaster';
  String _worldId = 'candy_crater';
  String? _lastBrushedWorldId;

  List<String> _heroItems = const [];
  List<String> _weaponItems = const [];
  List<String> _worldItems = const [];

  Goal? _heroGoal;
  Goal? _weaponGoal;
  Goal? _worldGoal;

  Timer? _minTimer;
  Timer? _capTimer;
  Timer? _idleTimer;
  Timer? _launchTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audio.voicePipelineActiveNotifier.addListener(_onVoiceChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audio.voicePipelineActiveNotifier.removeListener(_onVoiceChanged);
    _cancelStepTimers();
    _launchTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_loaded || _leaving) return;
    if (state == AppLifecycleState.paused) {
      _cancelStepTimers();
      unawaited(_audio.stopVoice());
    } else if (state == AppLifecycleState.resumed) {
      _enterStep(_step);
    }
  }

  Future<void> _load() async {
    try {
      final unlockedHeroes = await _heroes.getUnlockedHeroIds();
      final unlockedEvos = await _heroes.getUnlockedEvolutionIds();
      _heroId = await _heroes.getSelectedHeroId();
      _heroStage = await _heroes.getEvolutionStage(_heroId);
      final unlockedWeapons = await _weapons.getUnlockedWeaponIds();
      _weaponId = await _weapons.getSelectedWeaponId();
      _worldId = await _worlds.getCurrentWorldId();
      final history = await _streak.getHistory();
      _lastBrushedWorldId = history.isEmpty ? null : history.last.worldId;

      _heroItems = [
        for (final hero in HeroService.allHeroes)
          if (unlockedHeroes.contains(hero.id)) ...[
            '${hero.id}_stage1',
            for (final evo in HeroService.evolutionsForHero(hero.id))
              if (evo.stage > 1 && unlockedEvos.contains(evo.id)) evo.id,
          ],
      ];
      _weaponItems = [
        for (final w in WeaponService.allWeapons)
          if (unlockedWeapons.contains(w.id)) w.id,
      ];
      final worlds = <String>[];
      for (final w in WorldService.allWorlds) {
        if (await _worlds.isWorldUnlocked(w.id)) worlds.add(w.id);
      }
      _worldItems = worlds;

      _heroGoal = await _goals.heroGoal();
      _weaponGoal = await _goals.weaponGoal();
      _worldGoal = await _goals.worldGoal();
      if (!mounted) return;
      setState(() => _loaded = true);
      _enterStep(PreBrushStep.hero);
    } on Exception catch (e) {
      debugPrint('PreBrush load failed: $e');
      unawaited(AnalyticsService().logPreBrushSkipped(reason: 'error'));
      _launchBrushing(showWorldIntro: true);
    }
  }

  // ── Step machine ────────────────────────────────────────────

  bool get _isBriefing =>
      _step == PreBrushStep.world && _worldId != _lastBrushedWorldId;

  void _cancelStepTimers() {
    _minTimer?.cancel();
    _capTimer?.cancel();
    _idleTimer?.cancel();
  }

  void _enterStep(PreBrushStep step) {
    _cancelStepTimers();
    setState(() {
      _step = step;
      _touched = false;
      _minElapsed = false;
    });
    final lines = _entryVoices();
    for (var i = 0; i < lines.length; i++) {
      unawaited(
        _audio.playVoice(lines[i], clearQueue: i == 0, interrupt: i == 0),
      );
    }
    _minTimer = Timer(PreBrushScreen.minStep, () {
      _minElapsed = true;
      _maybeAdvance();
    });
    _capTimer = Timer(
      _isBriefing ? PreBrushScreen.maxBriefingStep : PreBrushScreen.maxStep,
      _advance,
    );
  }

  List<String> _entryVoices() {
    switch (_step) {
      case PreBrushStep.hero:
        return [_progressVoice(_heroGoal)];
      case PreBrushStep.weapon:
        return [_progressVoice(_weaponGoal)];
      case PreBrushStep.world:
        return [
          if (_isBriefing) 'voice_world_$_worldId.mp3',
          _progressVoice(_worldGoal),
        ];
    }
  }

  String _progressVoice(Goal? goal) {
    if (goal == null) return 'voice_have_them_all.mp3';
    if (goal.category == GoalCategory.world) {
      return _audio.brushesLeftVoiceFor(goal.left);
    }
    if (goal.affordable) return 'voice_ready_to_unlock.mp3';
    return _audio.starsLeftVoiceFor(goal.left);
  }

  void _onVoiceChanged() => _maybeAdvance();

  void _maybeAdvance() {
    if (!mounted || _leaving || _touched || !_minElapsed) return;
    if (_audio.voicePipelineActiveNotifier.value) return;
    _advance();
  }

  void _advance() {
    if (!mounted || _leaving) return;
    _cancelStepTimers();
    switch (_step) {
      case PreBrushStep.hero:
        _enterStep(PreBrushStep.weapon);
      case PreBrushStep.weapon:
        _enterStep(PreBrushStep.world);
      case PreBrushStep.world:
        _finish();
    }
  }

  void _onInteraction() {
    _cancelStepTimers();
    if (!_touched) setState(() => _touched = true);
    _idleTimer = Timer(PreBrushScreen.idleAfterTouch, _advance);
  }

  void _finish() {
    if (_leaving) return;
    _leaving = true;
    HapticFeedback.heavyImpact();
    unawaited(
      _audio.playVoice('voice_lets_fight.mp3', clearQueue: true, interrupt: true),
    );
    unawaited(
      AnalyticsService().logBrushSessionStart(
        heroId: _heroId,
        weaponId: _weaponId,
        worldId: _worldId,
      ),
    );
    _launchTimer = Timer(
      PreBrushScreen.launchDelay,
      () => _launchBrushing(showWorldIntro: false),
    );
  }

  void _launchBrushing({required bool showWorldIntro}) {
    if (!mounted) return;
    _leaving = true;
    final builder = PreBrushScreen.debugBrushingBuilder;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder != null
            ? builder(showWorldIntro)
            : BrushingScreen(showWorldIntro: showWorldIntro),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  // ── Choices ─────────────────────────────────────────────────

  Future<void> _onHeroChosen(String itemId) async {
    final parts = itemId.split('_stage');
    final heroId = parts.first;
    final stage = int.parse(parts.last);
    await _heroes.selectHero(heroId);
    await _heroes.setEvolutionStage(heroId, stage);
    final goal = await _goals.heroGoal();
    if (!mounted) return;
    setState(() {
      _heroId = heroId;
      _heroStage = stage;
      _heroGoal = goal;
    });
    unawaited(AnalyticsService().logPreBrushChange(category: 'hero'));
    unawaited(
      _audio.playVoice(
        stage == 1
            ? _audio.heroPickerVoiceFor(heroId)
            : _audio.evolutionPickerVoiceFor(heroId, stage),
        clearQueue: true,
        interrupt: true,
      ),
    );
  }

  Future<void> _onWeaponChosen(String weaponId) async {
    await _weapons.selectWeapon(weaponId);
    if (!mounted) return;
    setState(() => _weaponId = weaponId);
    unawaited(AnalyticsService().logPreBrushChange(category: 'weapon'));
    unawaited(
      _audio.playVoice(
        _audio.weaponPickerVoiceFor(weaponId),
        clearQueue: true,
        interrupt: true,
      ),
    );
  }

  Future<void> _onWorldChosen(String worldId) async {
    await _worlds.setCurrentWorld(worldId);
    if (!mounted) return;
    setState(() => _worldId = worldId);
    unawaited(AnalyticsService().logPreBrushChange(category: 'world'));
    unawaited(
      _audio.playVoice(
        'voice_world_$worldId.mp3',
        clearQueue: true,
        interrupt: true,
      ),
    );
  }

  void _onGoalTap() {
    _onInteraction();
    final world = _step == PreBrushStep.world;
    unawaited(
      _audio.playVoice(
        world ? 'voice_need_more_brushes.mp3' : 'voice_need_stars.mp3',
        clearQueue: true,
        interrupt: true,
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────

  Widget _heroImage(String heroId, int stage, double size) =>
      HeroService.buildHeroImage(
        heroId,
        stage: stage,
        weaponId: _weaponId,
        size: size,
      );

  Widget _goalImage(Goal goal, double size) {
    switch (goal.category) {
      case GoalCategory.hero:
        return _heroImage(goal.heroId, goal.stage, size);
      case GoalCategory.weapon:
        return Image.asset(
          WeaponService.getWeaponById(goal.itemId).imagePath,
          width: size,
          height: size,
        );
      case GoalCategory.world:
        return Image.asset(
          WorldService.getWorldById(goal.itemId).imagePath,
          width: size,
          height: size,
        );
    }
  }

  ({List<LoadoutItem> items, String selected, ValueChanged<String> onChosen})
  _carousel() {
    switch (_step) {
      case PreBrushStep.hero:
        return (
          items: [
            for (final id in _heroItems)
              LoadoutItem(
                id: id,
                image: _heroImage(
                  id.split('_stage').first,
                  int.parse(id.split('_stage').last),
                  220,
                ),
              ),
          ],
          selected: '${_heroId}_stage$_heroStage',
          onChosen: (id) => unawaited(_onHeroChosen(id)),
        );
      case PreBrushStep.weapon:
        return (
          items: [
            for (final id in _weaponItems)
              LoadoutItem(
                id: id,
                image: Image.asset(WeaponService.getWeaponById(id).imagePath),
              ),
          ],
          selected: _weaponId,
          onChosen: (id) => unawaited(_onWeaponChosen(id)),
        );
      case PreBrushStep.world:
        return (
          items: [
            for (final id in _worldItems)
              LoadoutItem(
                id: id,
                image: Image.asset(WorldService.getWorldById(id).imagePath),
              ),
          ],
          selected: _worldId,
          onChosen: (id) => unawaited(_onWorldChosen(id)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: SpaceBackground(child: SizedBox.expand()));
    }
    final c = _carousel();
    final goal = switch (_step) {
      PreBrushStep.hero => _heroGoal,
      PreBrushStep.weapon => _weaponGoal,
      PreBrushStep.world => _worldGoal,
    };
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _cancelStepTimers();
          unawaited(_audio.stopVoice());
        }
      },
      child: Scaffold(
        body: SpaceBackground(
          child: SafeArea(
            child: Column(
              key: ValueKey('prebrush_step_${_step.name}'),
              children: [
                Row(
                  children: [
                    IconButton(
                      key: const ValueKey('prebrush_back'),
                      iconSize: 36,
                      color: Colors.white70,
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const Spacer(),
                    for (final s in PreBrushStep.values)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          switch (s) {
                            PreBrushStep.hero => Icons.person,
                            PreBrushStep.weapon => Icons.bolt,
                            PreBrushStep.world => Icons.public,
                          },
                          size: s == _step ? 30 : 22,
                          color: s == _step ? Colors.cyanAccent : Colors.white38,
                        ),
                      ),
                    const SizedBox(width: 12),
                  ],
                ),
                Expanded(
                  child: LoadoutCarousel(
                    key: ValueKey('carousel_${_step.name}'),
                    items: c.items,
                    selectedId: c.selected,
                    onSelected: c.onChosen,
                    onInteraction: _onInteraction,
                  ),
                ),
                GestureDetector(
                  key: const ValueKey('prebrush_goal'),
                  onTap: goal == null ? null : _onGoalTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (goal != null)
                          ItemSilhouette(child: _goalImage(goal, 90)),
                        const SizedBox(height: 8),
                        goal == null
                            ? const GoalMeter(have: 0, cost: 0, complete: true)
                            : GoalMeter(
                                have: goal.have,
                                cost: goal.cost,
                                style: goal.category == GoalCategory.world
                                    ? GoalMeterStyle.rockets
                                    : GoalMeterStyle.stars,
                              ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: 88,
                  child: _touched
                      ? IconButton(
                          key: const ValueKey('prebrush_go'),
                          iconSize: 72,
                          color: Colors.greenAccent,
                          icon: const Icon(Icons.check_circle),
                          onPressed: _advance,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

If `SpaceBackground`'s constructor differs (check `lib/widgets/space_background.dart`), use it the way `home_screen.dart` does.

- [ ] **Step 4: Add all four spec §10 analytics methods** to `analytics_service.dart`. Tasks 8 and 9 call the last two.

```dart
  Future<void> logPreBrushChange({required String category}) async {
    if (!_enabled) return;
    await _fa.logEvent(
      name: 'pre_brush_change',
      parameters: {'category': category},
    );
  }

  Future<void> logPreBrushSkipped({required String reason}) async {
    if (!_enabled) return;
    await _fa.logEvent(
      name: 'pre_brush_skipped',
      parameters: {'reason': reason},
    );
  }

  Future<void> logGoalUnlocked({
    required String category,
    required String item,
  }) async {
    if (!_enabled) return;
    await _fa.logEvent(
      name: 'goal_unlocked',
      parameters: {'category': category, 'item': item, 'source': 'victory'},
    );
  }

  Future<void> logFlameTierReached({required String tier}) async {
    if (!_enabled) return;
    await _fa.logEvent(name: 'flame_tier_reached', parameters: {'tier': tier});
  }
```

- [ ] **Step 5: Route Home through the pre-brush screen.** In `home_screen.dart`, first add `key: const ValueKey('home_hero_button'),` to the hero `GestureDetector`, the one whose `onTapUp` calls `_startBrushing()` (about line 1297). This is a test hook only (R7). Then:
  - (a) Extract the body of `_launchBrushingScreen()`'s `.then((_) async { ... })` into `Future<void> _afterBrushReturn() async { ... }`, unchanged.
  - (b) In `_startBrushingFlow()`, after the camera block, read `final totalBrushes = prefs.getInt('total_brushes') ?? 0;`.
    - If `totalBrushes == 0`, keep today's code exactly: the "Let's fight!" voice plus 400 ms, then `_launchBrushingScreen()`.
    - Otherwise, log the skip reason only on the first-brush path. Then call `_launchPreBrush()` immediately, with no "Let's fight!" (the pre-brush screen plays it at the end).
  - (c) Add:

```dart
  void _launchPreBrush() {
    Navigator.of(context)
        .push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const PreBrushScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          ),
        )
        .then((_) => _afterBrushReturn());
  }
```

  `_brushTapLocked` is already set by `_startBrushing()` and cleared in `_afterBrushReturn()`, so a double tap opens one screen. `PreBrushScreen` replaces itself with `BrushingScreen`, and the victory screen rebuilds Home with `pushAndRemoveUntil`, so `.then` fires on replacement or removal. Both cases are safe, because `_afterBrushReturn` checks `mounted`.

  On the first-brush path in `_startBrushingFlow()`, add `unawaited(AnalyticsService().logPreBrushSkipped(reason: 'first_brush'));` before `_launchBrushingScreen()`.

- [ ] **Step 6: Home tests.** Add this group at the end of `main()` in `test/screens/home_screen_test.dart`. It reuses that file's `setUpAll`/`setUp`/`tearDown`, its `fakeAudio`, and `todayString()`; add `import 'package:brush_quest/screens/pre_brush_screen.dart';`.

```dart
  group('brush flow routing (v1.1)', () {
    setUp(() {
      // Keep the pre-brush screen on its first step for these tests.
      PreBrushScreen.minStep = const Duration(seconds: 30);
      PreBrushScreen.maxStep = const Duration(seconds: 30);
      PreBrushScreen.debugBrushingBuilder =
          (_) => const Scaffold(body: Text('BRUSHING'));
    });
    tearDown(() {
      PreBrushScreen.debugBrushingBuilder = null;
      PreBrushScreen.minStep = const Duration(seconds: 3);
      PreBrushScreen.maxStep = const Duration(seconds: 5);
    });

    Future<void> pumpHomeWith(WidgetTester tester, int totalBrushes) async {
      final today = todayString();
      SharedPreferences.setMockInitialValues({
        'selected_hero': 'blaze',
        'selected_weapon': 'star_blaster',
        'total_stars': 7,
        'star_wallet': 3,
        'current_streak': 2,
        'last_brush_date': today,
        'total_brushes': totalBrushes,
        'today_date': today,
        'camera_mode_configured': true,
        'muted': false,
      });
      await tester.binding.setSurfaceSize(const Size(430, 932));
      await tester.pumpWidget(
        const MaterialApp(home: HomeScreen(skipGreeting: true)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
    }

    Future<void> disposeAll(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1)); // let delayed callbacks no-op
      await tester.binding.setSurfaceSize(null);
    }

    testWidgets('first-ever brush skips the pre-brush steps', (tester) async {
      await pumpHomeWith(tester, 0);
      await tester.tap(find.byKey(const ValueKey('home_hero_button')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(PreBrushScreen), findsNothing);
      expect(fakeAudio.playedVoiceLines, contains('voice_lets_fight.mp3'));
      // Dispose Home before its 400 ms launch delay so the real brushing
      // screen never opens in this test.
      await disposeAll(tester);
    });

    testWidgets('a returning child goes through the pre-brush steps',
        (tester) async {
      await pumpHomeWith(tester, 3);
      await tester.tap(find.byKey(const ValueKey('home_hero_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(PreBrushScreen), findsOneWidget);
      await disposeAll(tester);
    });

    testWidgets('double tap opens one pre-brush screen', (tester) async {
      await pumpHomeWith(tester, 3);
      await tester.tap(find.byKey(const ValueKey('home_hero_button')));
      await tester.tap(
        find.byKey(const ValueKey('home_hero_button')),
        warnIfMissed: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(PreBrushScreen), findsOneWidget);
      await disposeAll(tester);
    });
  });
```

- [ ] **Step 7: Run the tests**

Run: `flutter test test/screens/pre_brush_screen_test.dart test/screens/home_screen_test.dart test/screens/brushing_screen_test.dart test/screens/brushing_lifecycle_test.dart`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
dart format lib/screens/pre_brush_screen.dart lib/screens/brushing_screen.dart lib/screens/home_screen.dart lib/services/analytics_service.dart test/screens/pre_brush_screen_test.dart test/screens/home_screen_test.dart
dart analyze
git add lib/screens/pre_brush_screen.dart lib/screens/brushing_screen.dart lib/screens/home_screen.dart lib/services/analytics_service.dart test/screens/pre_brush_screen_test.dart test/screens/home_screen_test.dart
git commit -m "feat(brush-flow): Hero -> Weapon -> World steps before each brush" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Victory — flame beat before the chest, chest tiers

**Files:**
- Modify: `lib/screens/victory_screen.dart`:
  - `_recordAndAnimate()` (lines 353-468; the chest is revealed at its end);
  - `_revealBonusStars()` (493-562) and its call block inside `_openChest()` (about 600-650);
  - `_buildChest()` (from line 1604): colour constants.
- Test: `test/screens/victory_flame_test.dart` (new)

**Interfaces:**
- Consumes: `flameTierFor`, `reachedFlameTier`, `chestTierFor`, `ChestTier` (Task 1); `FlameStrip` (Task 6); the new voice files (Task 5).
- Produces: state fields `bool _showFlameBeat`, `int _flameBonusStars`. The method `String? flameBeatVoiceFor({required int previousStreak, required int newStreak, required int streakMultiplierBonus, required int comebackBonus})` is a static, `@visibleForTesting` pure function on `VictoryScreen`, so it can be unit tested.

- [ ] **Step 1: Write the failing tests**

```dart
// test/screens/victory_flame_test.dart
import 'package:brush_quest/screens/victory_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String? v(int prev, int next, {int mult = 0, int comeback = 0}) =>
      VictoryScreen.flameBeatVoiceFor(
        previousStreak: prev,
        newStreak: next,
        streakMultiplierBonus: mult,
        comebackBonus: comeback,
      );

  test('tier-up lines win', () {
    expect(v(2, 3, mult: 1), 'voice_flame_tier_3.mp3');
    expect(v(6, 7, mult: 2), 'voice_flame_tier_7.mp3');
    expect(v(13, 14, mult: 2), 'voice_flame_tier_14.mp3');
  });
  test('bonus lines when the flame pays out', () {
    expect(v(3, 4, mult: 1), 'voice_flame_bonus_1.mp3');
    expect(v(8, 9, mult: 2), 'voice_flame_bonus_2.mp3');
    expect(v(4, 4, mult: 1), 'voice_flame_bonus_1.mp3'); // second brush today
  });
  test('new flame after a break or on the very first day', () {
    expect(v(9, 1, comeback: 3), 'voice_flame_new.mp3');
    expect(v(0, 1), 'voice_flame_new.mp3');
  });
  test('grow on days 1-2, nothing on a second brush the same day', () {
    expect(v(1, 2), 'voice_flame_grow.mp3');
    expect(v(2, 2), isNull);
  });
}
```

Run: `flutter test test/screens/victory_flame_test.dart`. Expected: FAIL (`flameBeatVoiceFor` doesn't exist).

- [ ] **Step 2: Add the pure voice rule** as a static on `VictoryScreen`:

```dart
  /// The one flame line for the flame beat (spec §7.3): tier-up, then
  /// bonus, then new, then grow. Null when nothing changed (a second brush
  /// today with no bonus).
  @visibleForTesting
  static String? flameBeatVoiceFor({
    required int previousStreak,
    required int newStreak,
    required int streakMultiplierBonus,
    required int comebackBonus,
  }) {
    final reached = reachedFlameTier(before: previousStreak, after: newStreak);
    if (reached == FlameTier.big) return 'voice_flame_tier_3.mp3';
    if (reached == FlameTier.hot) return 'voice_flame_tier_7.mp3';
    if (reached == FlameTier.golden) return 'voice_flame_tier_14.mp3';
    if (streakMultiplierBonus >= 2) return 'voice_flame_bonus_2.mp3';
    if (streakMultiplierBonus == 1) return 'voice_flame_bonus_1.mp3';
    if (comebackBonus > 0 || (previousStreak == 0 && newStreak == 1)) {
      return 'voice_flame_new.mp3';
    }
    if (newStreak > previousStreak) return 'voice_flame_grow.mp3';
    return null;
  }
```

Run the test. Expected: PASS.

- [ ] **Step 3: Flame beat in the sequence.** Add these imports to `victory_screen.dart`: `../services/flame_tier.dart` and `../widgets/flame_view.dart` (`AnalyticsService` is already imported). In `_recordAndAnimate()`, just before the block that reveals the chest (`unawaited(_audio.playSfx('whoosh.mp3')); setState(() => _showChest = true);`), insert:

```dart
    // ── Flame beat (spec §6 step 2): the flame grows and the bonus stars
    // come out of it, with the line that says why. Fire-and-forget voice;
    // a fixed pause paces the visuals (never wait on voice completion).
    _flameBonusStars = _streakMultiplierBonus + _dailyBonus + _comebackBonus;
    setState(() => _showFlameBeat = true);
    if (_flameBonusStars > 0) unawaited(_audio.playSfx('star_chime.mp3'));
    final flameLine = VictoryScreen.flameBeatVoiceFor(
      previousStreak: _previousStreak,
      newStreak: _newStreak,
      streakMultiplierBonus: _streakMultiplierBonus,
      comebackBonus: _comebackBonus,
    );
    if (flameLine != null) unawaited(_audio.playVoice(flameLine));
    final reached =
        reachedFlameTier(before: _previousStreak, after: _newStreak);
    if (reached != null) {
      unawaited(AnalyticsService().logFlameTierReached(tier: reached.name));
    }
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
```

`_recordAndAnimate()` already uses `Future.delayed` for its pacing. Matching that idiom is acceptable inside this existing async sequence, which already guards `mounted` after each await. Don't add `Future.delayed` anywhere else.

Add the fields `bool _showFlameBeat = false;` and `int _flameBonusStars = 0;`. In the build, show it where the existing bonus pills or streak area appear near the top. If there's no such area, put it directly under the wallet pill row:

```dart
if (_showFlameBeat)
  Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      FlameIcon(tier: flameTierFor(_newStreak)),
      if (_flameBonusStars > 0)
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 600),
          builder: (context, t, child) => Opacity(
            opacity: t,
            child: Transform.translate(offset: Offset(0, -20 * t), child: child),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _flameBonusStars; i++)
                const Icon(Icons.star, color: Colors.amberAccent, size: 22),
            ],
          ),
        ),
    ],
  ),
```

- [ ] **Step 4: Remove the old post-chest bonus voices.** In `_openChest()`, delete the block from `// ── Post-chest bonus star reveals` through the end of the `else if (hasBonuses) { ... mark first-time flags ... }` chain, and delete the method `_revealBonusStars()`. Bonus voices now play in the flame beat. Keep `int voiceSlotsRemaining = 3;`. The P2+ (trophy, world, milestone) code is unchanged.

- [ ] **Step 5: Chest tiers.** In `_buildChest()`, introduce local colours from `chestTierFor(_newStreak)` and replace the hard-coded body gradient and band colours. Wooden keeps today's exact colours:

```dart
    final tier = chestTierFor(_newStreak);
    final (bodyTop, bodyBottom, edge, band) = switch (tier) {
      ChestTier.wooden => (const Color(0xFF8D5A33), const Color(0xFF5D3420),
          const Color(0xFF4E2A17), const Color(0xFFFFD54F)),
      ChestTier.silver => (const Color(0xFFCFD8DC), const Color(0xFF90A4AE),
          const Color(0xFF607D8B), const Color(0xFFECEFF1)),
      ChestTier.gold => (const Color(0xFFFFE082), const Color(0xFFFFB300),
          const Color(0xFFE65100), const Color(0xFFFFF8E1)),
    };
```

Use `bodyTop`/`bodyBottom` in the chest body `LinearGradient` (today `[Color(0xFF8D5A33), Color(0xFF5D3420)]`), `edge` for the `0xFF4E2A17` border, and `band` for the gold band/lock colour. Find every use in `_buildChest()`, for both the unopened and opened chest, and keep `const` where you can.

Also add `key: const ValueKey('victory_chest'),` to the chest `GestureDetector` (`onTap: _chestOpened ? null : _openChest`, about line 1620). This is a test hook only (R7).

- [ ] **Step 6: Widget test for the order.** Add to `test/screens/victory_flame_test.dart`, with these imports added to the file: `firebase_core`, `firebase_core_platform_interface/test.dart` (with the `// ignore: depend_on_referenced_packages` comment, as in `victory_screen_test.dart`), `flutter/material.dart`, `flutter/services.dart`, `shared_preferences`, `../audio/fake_audio_service.dart` and `brush_quest/services/audio_service.dart`. Wrap the existing `test(...)` calls and this group in the same `main()`:

```dart
  group('flame beat in the victory sequence', () {
    late FakeAudioService fakeAudio;

    setUpAll(() async {
      setupFirebaseCoreMocks();
      await Firebase.initializeApp();
      for (final name in ['xyz.luan/audioplayers.global', 'xyz.luan/audioplayers']) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(MethodChannel(name), (call) async => 1);
      }
    });
    setUp(() {
      fakeAudio = FakeAudioService();
      AudioService.testInstance = fakeAudio;
    });
    tearDown(() => AudioService.testInstance = null);

    String day(int offset) {
      final d = DateTime.now().add(Duration(days: offset));
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    testWidgets('reaching 3 days: tier line before the chest, old lines gone',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'total_stars': 5,
        'star_wallet': 0,
        'current_streak': 2,
        'best_streak': 2,
        'last_brush_date': day(-1), // this brush makes the streak 3
        'total_brushes': 5,
        'selected_hero': 'blaze',
        'selected_weapon': 'star_blaster',
        'unlocked_heroes': ['blaze'],
        'unlocked_weapons': ['star_blaster'],
        'current_world': 'candy_crater',
        'collected_cards': <String>[],
        'muted': false,
      });
      await tester.binding.setSurfaceSize(const Size(430, 932));
      await tester.pumpWidget(
        const MaterialApp(
          home: VictoryScreen(totalHits: 10, monstersDefeated: 4),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 4)); // flame beat, chest drops
      final voices = fakeAudio.playedVoiceLines;
      expect(voices, contains('voice_flame_tier_3.mp3'));
      expect(find.byKey(const ValueKey('victory_chest')), findsOneWidget);
      final before = voices.length;
      await tester.tap(find.byKey(const ValueKey('victory_chest')));
      await tester.pump(const Duration(seconds: 2));
      // Chest voices come after the flame line.
      expect(voices.length, greaterThan(before));
      expect(
        voices.indexOf('voice_flame_tier_3.mp3'),
        lessThan(before),
      );
      expect(voices, isNot(contains('voice_first_streak_3.mp3')));
      expect(voices, isNot(contains('voice_chest_streak_bonus.mp3')));
      await tester.pump(const Duration(seconds: 70)); // drain sequence timers
      await tester.binding.setSurfaceSize(null);
    });
  });
```

- [ ] **Step 7: Run the tests**

Run: `flutter test test/screens/victory_flame_test.dart test/screens/victory_screen_test.dart`
Expected: PASS. Existing tests that asserted the removed streak voices (`voice_first_streak_3`, `voice_chest_streak_bonus`, `voice_chest_mega_streak`, `voice_first_streak_7`) must be updated to the flame lines; list each change in the report.

- [ ] **Step 8: Commit**

```bash
dart format lib/screens/victory_screen.dart test/screens/victory_flame_test.dart test/screens/victory_screen_test.dart
dart analyze
git add lib/screens/victory_screen.dart test/screens/victory_flame_test.dart test/screens/victory_screen_test.dart
git commit -m "feat(victory): flame beat explains the bonus stars; chest tiers by streak" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Victory — goal fill + one-tap unlock, world rockets, flame closing line

**Files:**
- Modify: `lib/screens/victory_screen.dart`:
  - `_openChest()`: insert a goal beat right after the chest reward voice and bonus-star credit, before `// ── Trophy defeat/capture ──`;
  - the trophy card area (about line 977): rockets under the world text;
  - `_showForwardHookSequence()` (about 819-845): replaced.
- Test: `test/screens/victory_goal_test.dart` (new)

**Interfaces:**
- Consumes: `GoalService().overallGoal()`, `GoalService().worldGoal()`, `Goal` (Task 3); `UnlockService().unlockGoal(goal)` (Task 4); `GoalMeter`, `ItemSilhouette`, `FlameStrip` (Task 6); `daysToNextFlameTier` (Task 1); `StreakService.getYesterdaySlots()`; voices `voice_tap_to_unlock.mp3`, `voice_unlocked_yours.mp3`, the `starsLeftVoiceFor` clips, `voice_flame_see_you_next.mp3`, `voice_flame_see_you_keep.mp3`, `voice_forward_tonight.mp3`.
- Produces: the pure rule `static String closingVoiceFor({required int hour, required bool yesterdayBoth, required int newStreak})`, `@visibleForTesting` on `VictoryScreen`.

- [ ] **Step 1: Write the failing tests (pure part)**

```dart
// test/screens/victory_goal_test.dart
import 'package:brush_quest/screens/victory_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String c(int hour, bool both, int streak) => VictoryScreen.closingVoiceFor(
    hour: hour, yesterdayBoth: both, newStreak: streak);

  test('twice-a-day child brushing in the morning hears "see you tonight"', () {
    expect(c(8, true, 5), 'voice_forward_tonight.mp3');
  });
  test('otherwise the flame closing line', () {
    expect(c(8, false, 2), 'voice_flame_see_you_next.mp3'); // 1 day to big
    expect(c(20, true, 4), 'voice_flame_see_you_keep.mp3'); // 3 days to hot
    expect(c(20, false, 6), 'voice_flame_see_you_next.mp3');
    expect(c(20, false, 30), 'voice_flame_see_you_keep.mp3'); // golden
  });
}
```

Run: `flutter test test/screens/victory_goal_test.dart`. Expected: FAIL.

- [ ] **Step 2: Add `closingVoiceFor`** to `VictoryScreen`:

```dart
  /// Closing line (spec §7.3): "see you tonight" only for a child who
  /// brushed morning and evening yesterday and is brushing in the morning
  /// now; otherwise the flame line.
  @visibleForTesting
  static String closingVoiceFor({
    required int hour,
    required bool yesterdayBoth,
    required int newStreak,
  }) {
    if (hour < 12 && yesterdayBoth) return 'voice_forward_tonight.mp3';
    return daysToNextFlameTier(newStreak) == 1
        ? 'voice_flame_see_you_next.mp3'
        : 'voice_flame_see_you_keep.mp3';
  }
```

Run the test. Expected: PASS.

- [ ] **Step 3: Goal beat.** Add these imports to `victory_screen.dart`: `../services/goal_service.dart`, `../services/unlock_service.dart`, `../widgets/goal_meter.dart` and `../widgets/item_silhouette.dart` (`hero_service.dart` and `weapon_service.dart` are already imported; add any that aren't). In `_openChest()`, after the chest-bonus credit block (`if (totalBonus > 0) { ... setState }`) and before the trophy section, insert:

```dart
        // ── Goal beat (spec §6 step 4): stars fill the closest goal; when
        // it's full, one tap unlocks it. Visual flow never waits on voice.
        _goal = await GoalService().overallGoal();
        if (_goal != null && mounted) {
          setState(() => _showGoal = true);
          if (voiceSlotsRemaining > 0) {
            unawaited(
              _audio.playVoice(
                _goal!.affordable
                    ? 'voice_tap_to_unlock.mp3'
                    : _audio.starsLeftVoiceFor(_goal!.left),
              ),
            );
            voiceSlotsRemaining--;
          }
          await Future.delayed(const Duration(milliseconds: 1200));
          if (!mounted) return;
        }
```

Add the fields `Goal? _goal;`, `bool _showGoal = false;`, `bool _goalUnlocked = false;`, `bool _unlocking = false;`, plus the tap handler:

```dart
  Future<void> _onGoalTap() async {
    final goal = _goal;
    if (goal == null || !goal.affordable || _goalUnlocked || _unlocking) return;
    _unlocking = true;
    final ok = await UnlockService().unlockGoal(goal);
    _unlocking = false;
    if (!mounted || !ok) return;
    unawaited(HapticFeedback.heavyImpact());
    unawaited(_confettiController.repeat());
    unawaited(_audio.playVoice('voice_unlocked_yours.mp3', interrupt: true));
    unawaited(
      AnalyticsService().logGoalUnlocked(
        category: goal.category.name,
        item: goal.itemId,
      ),
    );
    _newWallet = await _streakService.getWallet();
    if (mounted) setState(() => _goalUnlocked = true);
  }
```

In the build, near the chest or the trophy card (choose the spot that doesn't overlap at 360×640; the trophy card sits below), add:

```dart
if (_showGoal && _goal != null)
  GestureDetector(
    key: const ValueKey('victory_goal'),
    onTap: _onGoalTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedScale(
          scale: (_goal!.affordable && !_goalUnlocked) ? 1.1 : 1.0,
          duration: const Duration(milliseconds: 400),
          child: _goalUnlocked
              ? _goalImage(_goal!, 96)
              : ItemSilhouette(child: _goalImage(_goal!, 96)),
        ),
        const SizedBox(height: 6),
        GoalMeter(
          have: _goalUnlocked ? _goal!.cost : _newWallet,
          cost: _goal!.cost,
        ),
      ],
    ),
  ),
```

`_goalImage` uses the same code as the pre-brush screen: hero via `HeroService.buildHeroImage(goal.heroId, stage: goal.stage, weaponId: _heroWeaponId, size:)`, weapon via `Image.asset(WeaponService.getWeaponById(id).imagePath)`. Copy it into the victory state as a private method; don't import the pre-brush screen.

- [ ] **Step 4: World rockets.** After the trophy card's world text (`if (_showWorldProgress) ...[ Text(...) ]`), add a rockets meter for the frontier:

```dart
if (_showWorldProgress && _worldGoal != null)
  Padding(
    padding: const EdgeInsets.only(top: 6),
    child: GoalMeter(
      have: _worldGoal!.have,
      cost: _worldGoal!.cost,
      style: GoalMeterStyle.rockets,
      unit: 18,
    ),
  ),
```

Set `_worldGoal = await GoalService().worldGoal();` in the same place `_showWorldProgress = true` is set, and add the field `Goal? _worldGoal;`.

- [ ] **Step 5: Flame closing strip and line.** Replace the body of `_showForwardHookSequence()`:

```dart
  Future<void> _showForwardHookSequence() async {
    if (_forwardHookFired) return;
    _forwardHookFired = true;
    final yesterday = await _streakService.getYesterdaySlots();
    if (!mounted) return;
    setState(() => _showFlameStrip = true);
    final line = VictoryScreen.closingVoiceFor(
      hour: DateTime.now().hour,
      yesterdayBoth: yesterday.morningDone && yesterday.eveningDone,
      newStreak: _newStreak,
    );
    await _audio.playVoice(line);
  }
```

Add `bool _showFlameStrip = false;` and, above the DONE button in the build, `if (_showFlameStrip) FlameStrip(streak: _newStreak),`. Remove the now-unused `_ForwardHookType` enum and its `voice_full_power` / `voice_forward_morning` mapping if nothing else uses them. `dart analyze` will tell you.

- [ ] **Step 6: Widget tests.** Append to `test/screens/victory_goal_test.dart`, adding the same imports and Firebase/audioplayers `setUpAll` as Task 8 Step 6, plus `brush_quest/widgets/flame_view.dart`:

```dart
  group('goal beat and closing (widget)', () {
    late FakeAudioService fakeAudio;

    setUpAll(() async {
      setupFirebaseCoreMocks();
      await Firebase.initializeApp();
      for (final name in ['xyz.luan/audioplayers.global', 'xyz.luan/audioplayers']) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(MethodChannel(name), (call) async => 1);
      }
    });
    setUp(() {
      fakeAudio = FakeAudioService();
      AudioService.testInstance = fakeAudio;
    });
    tearDown(() => AudioService.testInstance = null);

    String today() {
      final d = DateTime.now();
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    Map<String, Object> base() => {
      'total_stars': 5,
      'current_streak': 2,
      'best_streak': 3,
      'last_brush_date': today(),
      'today_brush_count': 1,
      'today_date': today(),
      'total_brushes': 5,
      'selected_hero': 'blaze',
      'selected_weapon': 'star_blaster',
      'unlocked_heroes': ['blaze'],
      'unlocked_weapons': ['star_blaster'],
      'current_world': 'candy_crater',
      'collected_cards': <String>[],
      'muted': false,
    };

    Future<void> pumpThroughChest(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      await tester.pumpWidget(
        const MaterialApp(
          home: VictoryScreen(totalHits: 10, monstersDefeated: 4),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      await tester.tap(find.byKey(const ValueKey('victory_chest')));
      await tester.pump(const Duration(seconds: 3)); // chest + goal beat
    }

    Future<void> drain(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 70));
      await tester.binding.setSurfaceSize(null);
    }

    testWidgets('affordable goal: tap unlocks once and selects it',
        (tester) async {
      // wallet 3 + base 2 + chest >= 1 -> at least 6 >= frost (5)
      SharedPreferences.setMockInitialValues({...base(), 'star_wallet': 3});
      await pumpThroughChest(tester);
      expect(find.byKey(const ValueKey('victory_goal')), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      final before = prefs.getInt('star_wallet')!;
      await tester.tap(find.byKey(const ValueKey('victory_goal')));
      await tester.tap(
        find.byKey(const ValueKey('victory_goal')),
        warnIfMissed: false,
      );
      await tester.pump(const Duration(seconds: 1));
      expect(prefs.getString('selected_hero'), 'frost');
      expect(prefs.getStringList('unlocked_heroes'), contains('frost'));
      expect(prefs.getInt('star_wallet'), before - 5);
      expect(
        fakeAudio.playedVoiceLines.where((v) => v == 'voice_unlocked_yours.mp3'),
        hasLength(1),
      );
      await drain(tester);
    });

    testWidgets('not affordable: no unlock, stars-left line', (tester) async {
      // Next goals: blaze_stage2 10 (hero), ice_hammer 14 (weapon).
      // Max wallet after this brush: 0 + 2 + 5 (chest) + 1 (modifier) = 8.
      SharedPreferences.setMockInitialValues({
        ...base(),
        'star_wallet': 0,
        'unlocked_heroes': ['blaze', 'frost', 'bolt'],
        'unlocked_weapons': ['star_blaster', 'flame_sword'],
      });
      await pumpThroughChest(tester);
      final prefs = await SharedPreferences.getInstance();
      final wallet = prefs.getInt('star_wallet')!;
      expect(
        fakeAudio.playedVoiceLines,
        contains('voice_stars_left_${10 - wallet}.mp3'),
      );
      await tester.tap(
        find.byKey(const ValueKey('victory_goal')),
        warnIfMissed: false,
      );
      await tester.pump(const Duration(seconds: 1));
      expect(prefs.getString('selected_hero'), 'blaze');
      expect(prefs.getInt('star_wallet'), wallet);
      await drain(tester);
    });

    testWidgets('no goal beat when all owned', (tester) async {
      SharedPreferences.setMockInitialValues({
        ...base(),
        'unlocked_heroes': ['blaze', 'frost', 'bolt', 'shadow', 'leaf', 'nova'],
        'selected_hero': 'nova',
        'unlocked_evolutions': ['nova_stage2', 'nova_stage3'],
        'unlocked_weapons': [
          'star_blaster', 'flame_sword', 'ice_hammer',
          'lightning_wand', 'vine_whip', 'cosmic_burst',
        ],
      });
      await pumpThroughChest(tester);
      expect(find.byKey(const ValueKey('victory_goal')), findsNothing);
      await drain(tester);
    });

    testWidgets('DONE appears when muted', (tester) async {
      SharedPreferences.setMockInitialValues(base());
      await fakeAudio.toggleMute();
      await pumpThroughChest(tester);
      await tester.pump(const Duration(seconds: 15));
      expect(find.text('DONE'), findsOneWidget);
      await drain(tester);
    });

    testWidgets('closing line plays and the flame strip shows', (tester) async {
      SharedPreferences.setMockInitialValues(base());
      await pumpThroughChest(tester);
      await tester.pump(const Duration(seconds: 15));
      final last = fakeAudio.playedVoiceLines.last;
      expect(
        last.startsWith('voice_flame_see_you_') ||
            last == 'voice_forward_tonight.mp3',
        isTrue,
        reason: 'last voice was $last',
      );
      expect(find.byType(FlameStrip), findsOneWidget);
      await drain(tester);
    });
  });
```

If the fake's `toggleMute()` is named differently, use the fake's mute API.

- [ ] **Step 7: Run the tests**

Run: `flutter test test/screens/victory_goal_test.dart test/screens/victory_flame_test.dart test/screens/victory_screen_test.dart`
Expected: PASS. Update existing tests that asserted `voice_forward_morning` or `voice_full_power`, and say so in the report.

- [ ] **Step 8: Commit**

```bash
dart format lib/screens/victory_screen.dart test/screens/victory_goal_test.dart test/screens/victory_screen_test.dart
dart analyze
git add lib/screens/victory_screen.dart test/screens/victory_goal_test.dart test/screens/victory_screen_test.dart
git commit -m "feat(victory): goal fill with one-tap unlock, world rockets, flame closing line" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Home — flame pill, welcome-back payoff, tier-up whoosh

**Files:**
- Modify: `lib/screens/home_screen.dart`:
  - streak pill (about lines 1040-1070): the `Icons.local_fire_department` icon becomes `FlameIcon`;
  - `_claimAndAnimateDailyBonus()` (378-388);
  - `_showGreetingPopup()` (390-404): the streak-teach voices;
  - `_loadStats()` (219+): tier-up check.
- Test: `test/screens/home_flame_test.dart` (new)

**Interfaces:**
- Consumes: `flameTierFor`, `FlameTier` (Task 1); `FlameIcon` (Task 6); voices `voice_flame_welcome_1/2.mp3`, `voice_flame_got_bigger.mp3`.
- Produces: new prefs key `last_seen_flame_tier` (int, `FlameTier.index`). `@visibleForTesting static String? welcomeFlameVoiceFor(int dailyBonus)` on `HomeScreen`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/screens/home_flame_test.dart
import 'package:brush_quest/screens/home_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('welcome line matches the daily bonus', () {
    expect(HomeScreen.welcomeFlameVoiceFor(0), isNull);
    expect(HomeScreen.welcomeFlameVoiceFor(1), 'voice_flame_welcome_1.mp3');
    expect(HomeScreen.welcomeFlameVoiceFor(2), 'voice_flame_welcome_2.mp3');
  });
}
```

Then add these widget tests to the same file: a `main()` with the Firebase/audioplayers `setUpAll`, `fakeAudio` set-up and tear-down copied from `home_screen_test.dart`, plus imports for `flame_tier.dart`, `flame_view.dart`, `shared_preferences`, `flutter/material.dart` and the fake.

```dart
  String day(int offset) {
    final d = DateTime.now().add(Duration(days: offset));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> pumpHomeWith(
    WidgetTester tester,
    Map<String, Object> extra,
  ) async {
    SharedPreferences.setMockInitialValues({
      'selected_hero': 'blaze',
      'selected_weapon': 'star_blaster',
      'total_brushes': 5,
      'camera_mode_configured': true,
      'muted': false,
      ...extra,
    });
    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(skipGreeting: true)),
    );
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  Future<void> disposeAll(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    await tester.binding.setSurfaceSize(null);
  }

  testWidgets('streak pill uses FlameIcon at the right tier', (tester) async {
    await pumpHomeWith(tester, {'current_streak': 7, 'last_brush_date': day(0)});
    final tiers = tester
        .widgetList<FlameIcon>(find.byType(FlameIcon))
        .map((w) => w.tier);
    expect(tiers, contains(FlameTier.hot));
    await disposeAll(tester);
  });

  testWidgets('daily bonus plays the welcome flame line once per day',
      (tester) async {
    await pumpHomeWith(tester, {'current_streak': 4, 'last_brush_date': day(-1)});
    expect(fakeAudio.playedVoiceLines, contains('voice_flame_welcome_1.mp3'));
    expect(
      fakeAudio.playedVoiceLines.where((v) => v.startsWith('voice_streak_teach')),
      isEmpty,
    );
    fakeAudio.resetTracking();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(skipGreeting: true)),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(
      fakeAudio.playedVoiceLines,
      isNot(contains('voice_flame_welcome_1.mp3')),
    );
    await disposeAll(tester);
  });

  testWidgets('tier-up after victory: whoosh, no repeated line (R6)',
      (tester) async {
    await pumpHomeWith(tester, {
      'current_streak': 3,
      'last_brush_date': day(0),
      'last_seen_flame_tier': FlameTier.small.index,
    });
    expect(fakeAudio.playedSfx, contains('whoosh.mp3'));
    expect(
      fakeAudio.playedVoiceLines,
      isNot(contains('voice_flame_got_bigger.mp3')),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('last_seen_flame_tier'), FlameTier.big.index);
    await disposeAll(tester);
  });

  testWidgets('broken streak: no flame voice or whoosh', (tester) async {
    await pumpHomeWith(tester, {
      'current_streak': 1,
      'last_brush_date': day(0),
      'last_seen_flame_tier': FlameTier.hot.index,
    });
    expect(
      fakeAudio.playedVoiceLines.where((v) => v.startsWith('voice_flame_')),
      isEmpty,
    );
    expect(fakeAudio.playedSfx, isNot(contains('whoosh.mp3')));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('last_seen_flame_tier'), FlameTier.small.index);
    await disposeAll(tester);
  });
```

If Home plays `whoosh.mp3` on load for another reason (check first), assert on the whoosh being played exactly once more than a baseline pump without the tier change.

Run: `flutter test test/screens/home_flame_test.dart`. Expected: FAIL.

- [ ] **Step 2: Implement**
  - (a) Add the static to `HomeScreen`:

```dart
  @visibleForTesting
  static String? welcomeFlameVoiceFor(int dailyBonus) => switch (dailyBonus) {
    <= 0 => null,
    1 => 'voice_flame_welcome_1.mp3',
    _ => 'voice_flame_welcome_2.mp3',
  };
```

  - (b) In the streak pill, replace the `Icon(Icons.local_fire_department, color: ..., size: 26)` with `FlameIcon(tier: flameTierFor(_streak))`. Keep the rocket branch for `_streak == 0 && _totalBrushes > 0`, the number text and the pill border logic unchanged. Give the pill container a `GlobalKey _streakPillKey` for the star flight.
  - (c) In `_showGreetingPopup()`, delete the four `voice_streak_teach_*` branches.
  - (d) Replace `_claimAndAnimateDailyBonus()`:

```dart
  Future<void> _claimAndAnimateDailyBonus() async {
    final bonus = await _streakService.claimDailyBonus();
    if (bonus <= 0 || !mounted) return;
    final newWallet = await _streakService.getWallet();
    final line = HomeScreen.welcomeFlameVoiceFor(bonus);
    if (line != null) unawaited(AudioService().playVoice(line));
    setState(() => _dailyBonusFlight = bonus); // drives the star flight
    _dailyBonusTimer?.cancel();
    _dailyBonusTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      unawaited(AudioService().playSfx('star_chime.mp3'));
      setState(() {
        _dailyBonusFlight = 0;
        _wallet = newWallet;
      });
      unawaited(_statPulseController.forward(from: 0));
    });
  }
```

    Add the fields `int _dailyBonusFlight = 0;` and `Timer? _dailyBonusTimer;` (cancel the timer in `dispose()`). In the build, while `_dailyBonusFlight > 0`, overlay `_dailyBonusFlight` star icons that animate from the streak pill's centre to the wallet pill's centre. Use a `TweenAnimationBuilder<Offset>` over 900 ms with positions read from the two pill `GlobalKey`s, the same pattern as the victory screen's `_triggerStarFlight`. This is the one Home animation the spec allows (§7.2); it does not loop.

  - (e) Tier-up whoosh in `_loadStats()`, after `_streak` is set:

```dart
    final prefs = await SharedPreferences.getInstance();
    final tier = flameTierFor(_streak);
    final lastSeen = prefs.getInt('last_seen_flame_tier');
    await prefs.setInt('last_seen_flame_tier', tier.index);
    if (lastSeen != null &&
        tier.index > lastSeen &&
        tier.index >= FlameTier.big.index &&
        mounted) {
      unawaited(AudioService().playSfx('whoosh.mp3'));
      unawaited(_statPulseController.forward(from: 0));
      // R6: right after victory (skipGreeting) the tier-up line was just
      // spoken there — whoosh only. A cold open still gets the line.
      if (!widget.skipGreeting) {
        unawaited(AudioService().playVoice('voice_flame_got_bigger.mp3'));
      }
    }
```

    The first run after the update has no `last_seen_flame_tier`, so nothing plays. Only real step-ups play; a broken streak just writes the lower tier silently. Run this check only on the first `_loadStats()` after `initState` (guard with a `bool _flameTierChecked` field), so it doesn't repeat on every return from a sub-screen.

- [ ] **Step 3: Run the tests**

Run: `flutter test test/screens/home_flame_test.dart test/screens/home_screen_test.dart test/home_screen_layout_test.dart`
Expected: PASS. If `home_screen_layout_test.dart` pins the pill's icon size (26), update it to `FlameIcon` and say so in the report.

- [ ] **Step 4: Commit**

```bash
dart format lib/screens/home_screen.dart test/screens/home_flame_test.dart
dart analyze
git add lib/screens/home_screen.dart test/screens/home_flame_test.dart test/screens/home_screen_test.dart test/home_screen_layout_test.dart
git commit -m "feat(home): streak flame grows; welcome-back stars fly from the flame" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: Audio timelines, docs, full gates

**Files:**
- Test: `test/audio/brush_flow_timeline_test.dart` (new)
- Modify: `CLAUDE.md` (the "Game Flow" section, steps 2-5); `docs/ios-port/review-notes.md` (one line on the pre-brush steps, if the notes describe the brush flow)

**Interfaces:**
- Consumes: everything above. `FakeAudioService.playTimeline`, `playedVoiceLines`.

- [ ] **Step 1: Write the voice-order tests.** The app has one voice channel with a queue (real and fake), so overlap is impossible by construction. What can go wrong is order, stale lines and duplicates, and these tests pin those. Create `test/audio/brush_flow_timeline_test.dart` with the Firebase/audioplayers `setUpAll` and the fake set-up and tear-down from Task 9 Step 6, then:

```dart
  testWidgets('victory voice order: flame, chest, goal, closing', (tester) async {
    String d(int o) {
      final x = DateTime.now().add(Duration(days: o));
      return '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
    }
    SharedPreferences.setMockInitialValues({
      'total_stars': 5, 'star_wallet': 0, 'current_streak': 3,
      'best_streak': 3, 'last_brush_date': d(-1), 'total_brushes': 9,
      'selected_hero': 'blaze', 'selected_weapon': 'star_blaster',
      'unlocked_heroes': ['blaze'], 'unlocked_weapons': ['star_blaster'],
      'current_world': 'candy_crater', 'collected_cards': <String>[],
      'muted': false,
    });
    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpWidget(const MaterialApp(
      home: VictoryScreen(totalHits: 10, monstersDefeated: 4)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    await tester.tap(find.byKey(const ValueKey('victory_chest')));
    await tester.pump(const Duration(seconds: 20));
    final v = fakeAudio.playedVoiceLines;
    final flame = v.indexWhere((x) => x.startsWith('voice_flame_bonus_'));
    final chest = v.indexWhere((x) => x.startsWith('voice_chest_'));
    final goal = v.indexWhere((x) =>
        x.startsWith('voice_stars_left_') || x == 'voice_tap_to_unlock.mp3');
    final closing = v.lastIndexWhere((x) =>
        x.startsWith('voice_flame_see_you_') || x == 'voice_forward_tonight.mp3');
    expect(flame, isNonNegative, reason: '$v');
    expect(chest, greaterThan(flame), reason: '$v');
    expect(goal, greaterThan(chest), reason: '$v');
    expect(closing, greaterThan(goal), reason: '$v');
    expect(v.where((x) => x == v[closing]), hasLength(1));
    await tester.pump(const Duration(seconds: 70));
    await tester.binding.setSurfaceSize(null);
  });
```

  The pre-brush order is already pinned exactly by Task 7's first test (the full `voices()` list). For Home, the welcome-line and no-teach-lines checks are in Task 10.

- [ ] **Step 2: Update `CLAUDE.md` "Game Flow".** Step 2 becomes: "Home screen → tap the hero. From the second brush on: Hero → Weapon → World steps (auto-advance about 3 s each; switch to anything owned; closest next unlock with a star or rocket meter)." Step 5 becomes: "Victory → flame beat (bonus stars from the streak flame) → chest (wooden/silver/gold by streak) → goal fill with one-tap unlock → trophy and world rockets → flame closing line."

- [ ] **Step 3: Full gates (controller verifies too)**

```bash
dart format --output=none --set-exit-if-changed .
dart analyze
dart run dart_code_linter:metrics analyze lib
flutter test
semgrep --config auto lib/
gitleaks detect --source . --log-opts="release/v29..HEAD" --no-banner
```

Expected: format clean, "No issues found!", DCM no issues, all tests pass, semgrep 0 findings, no leaks.

- [ ] **Step 4: Commit**

```bash
git add test/audio/brush_flow_timeline_test.dart CLAUDE.md docs/ios-port/review-notes.md
git commit -m "test(audio): brush-flow voice timelines; docs: game flow for v1.1" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

After this task the controller dispatches the final whole-branch review. Then Jim and Oliver do the real-device test (spec §11, Hard Block) before any upload.
