# Feedback Round 3 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement 8 feedback items: pricing rebalance, combined streak+daily-pair greeting popup, parent area icon, nav icons, fix evolution voices, fix hero image sizing, remove weapon badge from countdown.

**Architecture:** Economy rebalance (hero_service), voice fallback for missing styles (audio_service), combined bonus greeting popup with yesterday's daily pair detection (streak_service → greeting_service → home_screen), UI cleanups across home_screen and brushing_screen.

**Tech Stack:** Flutter/Dart, ElevenLabs TTS MCP

---

## File Map

| File | Changes |
|------|---------|
| `lib/services/hero_service.dart` | Rebalance hero + evolution prices |
| `lib/services/streak_service.dart` | Add `getYesterdaySlots()` method |
| `lib/services/greeting_service.dart` | Add `yesterdayBothDone` to GreetingResult + checkGreeting |
| `lib/services/audio_service.dart` | Voice style fallback to classic/ |
| `lib/screens/home_screen.dart` | Combined bonus popup, remove SunMoonTracker, parent area icon, nav icons |
| `lib/screens/brushing_screen.dart` | Remove weapon badge from countdown |
| `lib/screens/hero_shop_screen.dart` | Fix evolution cell image sizing |
| `test/services/hero_service_test.dart` | Update price assertions |
| `test/services/greeting_service_test.dart` | Update for `yesterdayBothDone` param |
| `assets/audio/voices/classic/` | 2 new combined bonus voice files |

---

### Task 1: Pricing rebalance

**Files:**
- Modify: `lib/services/hero_service.dart` (hero prices + evolution prices)
- Modify: `test/services/hero_service_test.dart`

New pricing table (every row is monotonically increasing):

| Hero | Base (old→new) | Stage 2 (old→new) | Stage 3 (old→new) |
|------|------|---------|---------|
| Blaze | 0→0 | 15→10 | 25→20 |
| Frost | 8→5 | 15→12 | 25→22 |
| Bolt | 18→8 | 15→15 | 25→25 |
| Shadow | 25→12 | 18→18 | 25→28 |
| Leaf | 33→15 | 18→22 | 25→32 |
| Nova | 40→20 | 18→25 | 25→35 |

- [ ] **Step 1: Update hero base prices in `allHeroes`**

In `hero_service.dart`, update the `price` field for each hero in the `allHeroes` list:
- frost: 8 → 5
- bolt: 18 → 8
- shadow: 25 → 12
- leaf: 33 → 15
- nova: 40 → 20

Blaze stays 0.

- [ ] **Step 2: Update evolution prices in `allEvolutions`**

Update the `price` field for each evolution:
- blaze_stage2: 15 → 10, blaze_stage3: 25 → 20
- frost_stage2: 15 → 12, frost_stage3: 25 → 22
- bolt_stage2: 15 → 15 (unchanged), bolt_stage3: 25 → 25 (unchanged)
- shadow_stage2: 18 → 18 (unchanged), shadow_stage3: 25 → 28
- leaf_stage2: 18 → 22, leaf_stage3: 25 → 32
- nova_stage2: 18 → 25, nova_stage3: 25 → 35

- [ ] **Step 3: Update tests**

Update any price assertions in `test/services/hero_service_test.dart` that reference the old prices. Run `flutter test test/services/hero_service_test.dart` and fix any failures.

- [ ] **Step 4: Run dart analyze + tests**

Run: `dart analyze lib/services/hero_service.dart && flutter test test/services/hero_service_test.dart`

- [ ] **Step 5: Commit**

```bash
git add lib/services/hero_service.dart test/services/hero_service_test.dart
git commit -m "feat: rebalance hero + evolution pricing — monotonic per row, no dead zones"
```

---

### Task 2: Generate 2 combined bonus voice files

**Files:**
- Create: `assets/audio/voices/classic/voice_streak_pair_bonus_high.mp3`
- Create: `assets/audio/voices/classic/voice_streak_pair_bonus_low.mp3`

**Voice:** Classic (Jessica), voice ID `cgSgspJ2msm6clMCkdW9`

**Scripts:**

| File | Script |
|------|--------|
| `voice_streak_pair_bonus_high.mp3` | "You've been brushing more than seven days in a row AND morning and evening — amazing! That's three bonus stars every brush! Keep brushing every day to keep earning them!" |
| `voice_streak_pair_bonus_low.mp3` | "You've been brushing three days in a row AND morning and evening — awesome! That's two bonus stars every brush! Keep brushing every day and you'll earn even more!" |

- [ ] **Step 1: Generate both voice files via ElevenLabs TTS**
- [ ] **Step 2: Rename from auto-generated names to correct filenames**
- [ ] **Step 3: Verify duration (~5-7s each)**

---

### Task 3: Voice style fallback to classic

**Files:**
- Modify: `lib/services/audio_service.dart`

Currently, if a voice file doesn't exist in the active voice style directory (buddy/boy), playback fails silently. Add a fallback: try the current style first, if asset not found, retry with classic/.

- [ ] **Step 1: Modify `_voiceAssetPath` to support fallback**

The current `_voiceAssetPath` method (line ~86) returns:
```dart
return 'audio/voices/$_voiceStyle/$fileName';
```

We cannot check if an asset exists synchronously before playing. Instead, add error handling in `_pumpVoiceQueue()` (the method that actually plays the voice). After catching a playback error, retry with the classic path:

Find the `_pumpVoiceQueue()` method. In the try/catch around `_voicePlayer.play(AssetSource(_voiceAssetPath(request.fileName)))`, add a fallback:

```dart
try {
  await _voicePlayer.play(AssetSource(_voiceAssetPath(request.fileName)));
} catch (e) {
  // Fallback to classic voice style if current style doesn't have this file
  if (_voiceStyle != 'classic') {
    try {
      await _voicePlayer.play(AssetSource('audio/voices/classic/${request.fileName}'));
    } catch (_) {
      // Both styles failed — skip this voice
    }
  }
}
```

- [ ] **Step 2: Add combined bonus voices to preload list**

Add to `_allAudioFiles`:
```dart
    'voice_streak_pair_bonus_high.mp3',
    'voice_streak_pair_bonus_low.mp3',
```

- [ ] **Step 3: Run dart analyze**

Run: `dart analyze lib/services/audio_service.dart`

- [ ] **Step 4: Commit**

```bash
git add lib/services/audio_service.dart
git commit -m "feat: voice style fallback to classic + add combined bonus voice preload"
```

---

### Task 4: Yesterday daily pair detection

**Files:**
- Modify: `lib/services/streak_service.dart`
- Test: `test/services/streak_service_test.dart` (if exists, otherwise skip)

- [ ] **Step 1: Add `getYesterdaySlots()` method**

Add to `StreakService`, after `getTodaySlots()` (around line 296):

```dart
  /// Check if yesterday had both morning and evening brushing sessions.
  Future<TodaySlotsStatus> getYesterdaySlots() async {
    final history = await getHistory();
    final yesterday = _yesterdayString();
    bool hadMorning = false;
    bool hadEvening = false;
    for (final record in history) {
      if (record.date == yesterday) {
        final hour = int.parse(record.time.split(':')[0]);
        if (hour < 12) {
          hadMorning = true;
        } else {
          hadEvening = true;
        }
      }
    }
    return TodaySlotsStatus(morningDone: hadMorning, eveningDone: hadEvening);
  }
```

Note: `_yesterdayString()` already exists (around line 323-326). `getHistory()` returns `List<BrushRecord>` with `date` (YYYY-MM-DD) and `time` (HH:MM) fields.

- [ ] **Step 2: Run dart analyze**

Run: `dart analyze lib/services/streak_service.dart`

- [ ] **Step 3: Commit**

```bash
git add lib/services/streak_service.dart
git commit -m "feat: add getYesterdaySlots() for daily pair detection"
```

---

### Task 5: Combined bonus greeting popup + remove SunMoonTracker

**Files:**
- Modify: `lib/services/greeting_service.dart` (add `yesterdayBothDone` field)
- Modify: `lib/screens/home_screen.dart` (popup + SunMoonTracker removal)
- Modify: `test/services/greeting_service_test.dart` (update for new param)

- [ ] **Step 1: Add `yesterdayBothDone` to GreetingResult**

In `greeting_service.dart`, add field to `GreetingResult`:

```dart
class GreetingResult {
  final GreetingState state;
  final String voiceFile;
  final int brushStreak;
  final int wallet;
  final bool yesterdayBothDone;  // NEW
  // ... constructor updated
}
```

Update `checkGreeting()` method signature to accept `bool yesterdayBothDone` and pass it through to the constructor.

- [ ] **Step 2: Update `_checkGreeting()` in home_screen.dart**

In the `_checkGreeting()` method, before calling `checkGreeting()`, get yesterday's slots:

```dart
    final yesterdaySlots = await _streakService.getYesterdaySlots();
    
    final result = _greetingService.checkGreeting(
      totalBrushes: totalBrushes,
      brushStreak: _streak,
      wallet: _wallet,
      todayDate: todayDate,
      lastGreetingDate: lastGreetingDate,
      yesterdayBothDone: yesterdaySlots.morningDone && yesterdaySlots.eveningDone,
    );
```

- [ ] **Step 3: Update `_showGreetingPopup()` voice selection**

Replace the current streak bonus voice logic:

```dart
    // Current (replace this):
    if (greeting.brushStreak >= 7) {
      AudioService().playVoice('voice_streak_bonus_explain_high.mp3');
    } else if (greeting.brushStreak >= 3) {
      AudioService().playVoice('voice_streak_bonus_explain_low.mp3');
    }
```

With combined logic:

```dart
    if (greeting.brushStreak >= 7 && greeting.yesterdayBothDone) {
      AudioService().playVoice('voice_streak_pair_bonus_high.mp3');
    } else if (greeting.brushStreak >= 7) {
      AudioService().playVoice('voice_streak_bonus_explain_high.mp3');
    } else if (greeting.brushStreak >= 3 && greeting.yesterdayBothDone) {
      AudioService().playVoice('voice_streak_pair_bonus_low.mp3');
    } else if (greeting.brushStreak >= 3) {
      AudioService().playVoice('voice_streak_bonus_explain_low.mp3');
    }
```

- [ ] **Step 4: Update bonus badge to show combined number**

In the popup's bonus star badge section, update the number calculation:

```dart
    final streakBonus = greeting.brushStreak >= 7 ? 2 : (greeting.brushStreak >= 3 ? 1 : 0);
    final pairBonus = (greeting.yesterdayBothDone && greeting.brushStreak >= 3) ? 1 : 0;
    final totalBonus = streakBonus + pairBonus;
```

Then show `totalBonus` in the badge:
```dart
    if (totalBonus > 0) ...[
      // ... badge container ...
      Text('+$totalBonus', ...),
      Icon(Icons.star, ...),
    ],
```

- [ ] **Step 5: Remove SunMoonTracker from home screen**

In `home_screen.dart`, find and delete the SunMoonTracker widget (around lines 831-834):
```dart
    // DELETE:
    SunMoonTracker(
      morningDone: _morningDone,
      eveningDone: _eveningDone,
    ),
```

Also remove the import for `sun_moon_tracker.dart` if it becomes unused.

Remove the `_morningDone` and `_eveningDone` state variables if they're no longer used elsewhere. Check for other references first.

- [ ] **Step 6: Update greeting_service_test.dart**

Add `yesterdayBothDone: false` (or true) parameter to every `checkGreeting()` call in the test file.

- [ ] **Step 7: Run dart analyze + flutter test**

Run: `dart analyze && flutter test`

- [ ] **Step 8: Commit**

```bash
git add lib/services/greeting_service.dart lib/screens/home_screen.dart test/services/greeting_service_test.dart
git commit -m "feat: combined streak+daily-pair greeting popup, remove SunMoonTracker"
```

---

### Task 6: Parent Area icon + label

**Files:**
- Modify: `lib/screens/home_screen.dart` (settings button, around lines 473-499)

- [ ] **Step 1: Change settings icon to shield + label**

Find the settings IconButton (around line 473-499). Replace the icon and add a "PARENTS" label.

Replace `Icons.settings` with `Icons.shield`:

```dart
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.shield, color: Colors.white, size: 20),
        const SizedBox(height: 2),
        const Text(
          'PARENTS',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 8,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    ),
```

Adjust the container padding to accommodate the label.

- [ ] **Step 2: Run dart analyze**
- [ ] **Step 3: Commit**

```bash
git add lib/screens/home_screen.dart
git commit -m "feat: rename settings to Parent Area with shield icon"
```

---

### Task 7: Better nav icons

**Files:**
- Modify: `lib/screens/home_screen.dart` (nav button icons, lines 845-872)

Replace the Material Design icons with more recognizable ones:

| Button | Old Icon | New Icon | Why |
|--------|----------|----------|-----|
| MAP | `Icons.rocket_launch` | `Icons.public` | Globe = world/map |
| HEROES | `Icons.auto_awesome` | `Icons.military_tech` | Medal = hero achievement |
| MONSTERS | `Icons.bug_report` | `Icons.pest_control` | Creature silhouette = monster |

- [ ] **Step 1: Update the 3 icon values**

In the nav buttons section (~lines 845-872):
- Change `Icons.rocket_launch` → `Icons.public`
- Change `Icons.auto_awesome` → `Icons.military_tech`
- Change `Icons.bug_report` → `Icons.pest_control`

- [ ] **Step 2: Run dart analyze**
- [ ] **Step 3: Commit**

```bash
git add lib/screens/home_screen.dart
git commit -m "feat: better nav icons — globe for map, medal for heroes, creature for monsters"
```

---

### Task 8: Fix evolution cell image sizing

**Files:**
- Modify: `lib/screens/hero_shop_screen.dart` (_EvolutionCell)

The current code passes `size: 200` to `buildHeroImage()` inside an `AspectRatio(1)` container that's only ~100px wide. The explicit size fights with parent constraints.

- [ ] **Step 1: Fix image rendering in `_EvolutionCell`**

In the `_EvolutionCell` build method, replace the `HeroService.buildHeroImage()` call with a direct `Image.asset` that fills the parent naturally:

Replace:
```dart
    HeroService.buildHeroImage(
      hero.id,
      stage: evolution.stage,
      weaponId: weaponId,
      size: 200,
    ),
```

With:
```dart
    Image.asset(
      'assets/images/heroes/hero_${hero.id}_stage${evolution.stage}_$weaponId.png',
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          'assets/images/hero_${hero.id}.png',
          fit: BoxFit.contain,
        );
      },
    ),
```

No explicit width/height — the image fills the `AspectRatio(1)` parent naturally.

- [ ] **Step 2: Run dart analyze**
- [ ] **Step 3: Commit**

```bash
git add lib/screens/hero_shop_screen.dart
git commit -m "fix: evolution cell images fill parent instead of fixed 200px size"
```

---

### Task 9: Remove weapon badge from countdown

**Files:**
- Modify: `lib/screens/brushing_screen.dart` (lines 1767-1796)

- [ ] **Step 1: Delete the weapon badge `Positioned` widget**

In `_buildCountdown()`, inside the `Stack` that contains the hero image, delete the `Positioned` widget (lines 1767-1796) that renders the 44x44 weapon badge circle.

- [ ] **Step 2: Run dart analyze**

Check for unused `_weapon` references. If `_weapon` is still used elsewhere in the file (likely for attack effects), keep it. If only used for the badge, remove it.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/brushing_screen.dart
git commit -m "fix: remove redundant weapon badge from countdown — hero image already shows weapon"
```

---

### Task 10: Quality gates

- [ ] **Step 1: Run full dart analyze**

Run: `dart analyze`
Expected: No issues.

- [ ] **Step 2: Run full test suite**

Run: `flutter test`
Expected: All tests pass.

---

## Parallelization Guide

```
Independent (run in parallel):
  ├── Task 1: Pricing rebalance (hero_service.dart)
  ├── Task 2: Generate voice files (ElevenLabs TTS)  
  ├── Task 3: Voice fallback (audio_service.dart)
  ├── Task 4: Yesterday slots detection (streak_service.dart)
  ├── Task 6: Parent Area icon (home_screen.dart settings button)
  ├── Task 7: Nav icons (home_screen.dart nav buttons)
  ├── Task 8: Fix evolution images (hero_shop_screen.dart)
  └── Task 9: Remove weapon badge (brushing_screen.dart)

Sequential (depends on above):
  ├── Task 5: Combined bonus popup (depends on Tasks 2, 3, 4)
  └── Task 10: Quality gates (depends on all)
```

Tasks 1, 2, 3, 4, 6, 7, 8, 9 are fully independent. Task 5 integrates Tasks 2+3+4.

Note: Tasks 5, 6, 7 all touch `home_screen.dart` but different sections — they can be done by one subagent sequentially or carefully merged if done in parallel.
