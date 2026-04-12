# Cycle 13 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement 20 findings from the Cyclepro auto-full 9-agent analysis — fixing UX gaps, audio issues, code bugs, and principle violations across trophy wall, home screen, victory screen, shop, settings, and brushing screens.

**Architecture:** Changes are grouped into 6 independent streams by screen/system. Each stream modifies a distinct set of files. Audio changes use existing ElevenLabs voice files where possible; new voices are generated via the ElevenLabs MCP tool.

**Tech Stack:** Flutter/Dart, ElevenLabs TTS (Buddy/George voice), SharedPreferences

---

## Stream 1: Trophy Wall (Findings #2, #3)

### Task 1.1: Add voice to locked trophy taps

**Files:**
- Modify: `lib/screens/trophy_wall_screen.dart:116-131`

- [ ] **Step 1: Add voice line for locked trophy tap**

In `_onTrophyTap`, the `else` branch (uncaptured trophy, line 128-131) currently plays only `whoosh.mp3` SFX. Add a voice line to match the shop pattern (locked item → description + encouragement):

```dart
  } else {
    HapticFeedback.lightImpact();
    AudioService().playSfx('whoosh.mp3');
    // Add mystery voice for locked trophies (matches shop locked-item pattern)
    AudioService().playVoice('voice_keep_going.mp3', clearQueue: true, interrupt: true);
  }
```

Use `voice_keep_going.mp3` which already exists and says an encouraging "keep going" message. This matches the shop's "nudge voice" pattern for locked items (P7 consistency).

- [ ] **Step 2: Run tests**

```bash
flutter test test/screens/trophy_wall_screen_test.dart
```

- [ ] **Step 3: Commit**

```bash
git add lib/screens/trophy_wall_screen.dart
git commit -m "feat: add voice to locked trophy taps — P7 consistency with shop"
```

### Task 1.2: Show monster silhouettes for uncaught trophies

**Files:**
- Modify: `lib/screens/trophy_wall_screen.dart` (the trophy grid tile builder)

- [ ] **Step 1: Read the trophy grid tile builder**

Find the section that builds uncaptured trophy tiles (shows "???" and lock icon). Read the full widget code.

- [ ] **Step 2: Replace "???" tiles with dark silhouettes**

For uncaptured trophies, instead of showing a dark tile with "???" text, show the actual monster image with a dark color filter (silhouette effect):

```dart
// For uncaptured trophies, show silhouette instead of "???"
if (!isCaptured) {
  // Monster silhouette — dark tinted version of the real image
  ColorFiltered(
    colorFilter: const ColorFilter.mode(
      Color(0xFF1A1A2E),  // Very dark blue-purple tint
      BlendMode.srcATop,
    ),
    child: Image.asset(
      'assets/images/monsters/${trophy.imageFile}',
      fit: BoxFit.contain,
    ),
  )
}
```

The monster image path uses `trophy.imageFile`. Verify this property exists on `TrophyMonster` by reading `lib/services/trophy_service.dart`. If the property is named differently (e.g., `imagePath` or just derived from the ID), use the correct property.

Keep the lock icon overlay on top of the silhouette. Remove the "???" text entirely — the silhouette IS the mystery hint (like Pokemon Pokedex shadows).

- [ ] **Step 3: Run tests and verify**

```bash
flutter test test/screens/trophy_wall_screen_test.dart
flutter test
```

- [ ] **Step 4: Commit**

```bash
git add lib/screens/trophy_wall_screen.dart
git commit -m "feat: show monster silhouettes for uncaught trophies — Pokemon-style mystery"
```

---

## Stream 2: Victory Screen (Findings #12, #15, #17, #19, #20)

### Task 2.1: Fix back button bypassing forward hook (#19)

**Files:**
- Modify: `lib/screens/victory_screen.dart:1344-1352`

- [ ] **Step 1: Route all exits through _goHome()**

Change the PopScope so back always goes through `_goHome()`:

```dart
return PopScope(
  canPop: false,  // Never allow raw pop
  onPopInvokedWithResult: (didPop, _) {
    if (didPop) return;
    if (_showDoneButton) {
      _goHome();  // Route through _goHome for forward hook
    } else {
      HapticFeedback.lightImpact();
      _confettiController.forward(from: 0.0);
    }
  },
  child: Scaffold(
```

- [ ] **Step 2: Run tests**

```bash
flutter test test/screens/victory_screen_test.dart
```

- [ ] **Step 3: Commit**

```bash
git add lib/screens/victory_screen.dart
git commit -m "fix: victory back button routes through _goHome for forward hook"
```

### Task 2.2: Auto-open chest after delay (#17)

**Files:**
- Modify: `lib/screens/victory_screen.dart` (after chest + DONE button appear, around line 436-441)

- [ ] **Step 1: Add auto-open timer after chest appears**

After the chest and DONE button are shown (line 436-441), add a delayed auto-open so impatient kids don't miss the trophy:

```dart
// Auto-open chest after 4 seconds if untapped
Future.delayed(const Duration(seconds: 4), () {
  if (mounted && !_chestOpened) {
    _openChest();
  }
});
```

- [ ] **Step 2: Run tests**

```bash
flutter test test/screens/victory_screen_test.dart
```

- [ ] **Step 3: Commit**

```bash
git add lib/screens/victory_screen.dart
git commit -m "feat: auto-open chest after 4s if untapped — kids don't miss trophy"
```

### Task 2.3: Make victory stats bigger (#12)

**Files:**
- Modify: `lib/screens/victory_screen.dart` (the top stats bar)

- [ ] **Step 1: Read the victory stats bar code**

Find the top bar that shows streak, rank, and stars. Increase the icon and number size to make earned stats more prominent. The star count especially should be larger — this is the main reward signal.

- [ ] **Step 2: Increase stats pill size**

Increase icon size from current value to ~30px and text from current to ~24px. Make the star wallet pill the most prominent (largest size, yellow glow).

- [ ] **Step 3: Run tests and commit**

```bash
flutter test test/screens/victory_screen_test.dart
git add lib/screens/victory_screen.dart
git commit -m "feat: larger victory stats — star count is the hero of the reward"
```

### Task 2.4: Show legendary badge only on first encounter (#15)

**Files:**
- Modify: `lib/screens/victory_screen.dart` (legendary encounter section, around line 709)

- [ ] **Step 1: Gate legendary encounter with SharedPreferences**

Add a `has_seen_legendary` key. On first legendary encounter, show the full fanfare + voice. On subsequent victories, skip the legendary showcase entirely (just show normal chest). The badge was confusing Oliver because it appeared every time.

```dart
final prefs = await SharedPreferences.getInstance();
final hasSeenLegendary = prefs.getBool('has_seen_legendary') ?? false;

if (!hasSeenLegendary) {
  // Full legendary fanfare — first time only
  await prefs.setBool('has_seen_legendary', true);
  // ... existing legendary showcase code ...
} else {
  // Skip legendary encounter for returning legendary players
  // Just show the chest with normal rewards
}
```

Add `has_seen_legendary` to the `keysToReset` list in settings_screen.dart.

- [ ] **Step 2: Run tests and commit**

```bash
flutter test
git add lib/screens/victory_screen.dart lib/screens/settings_screen.dart
git commit -m "feat: show legendary badge only on first encounter — reduce Oliver confusion"
```

### Task 2.5: Fix brushing→victory audio dead zone (#20)

**Files:**
- Modify: `lib/screens/brushing_screen.dart` (the `_finishBrushing` method)

- [ ] **Step 1: Play victory SFX before stopping music**

In `_finishBrushing()`, instead of stopping everything then playing victory SFX after transition, play `victory.mp3` SFX BEFORE stopping music so there's a crossfade:

```dart
// Play victory SFX immediately (overlaps with fading music for smooth transition)
_audio.playSfx('victory.mp3');
// Brief delay for SFX to establish, then fade
await Future.delayed(const Duration(milliseconds: 400));
await _audio.stopVoice();
await _audio.stopMusic();
```

Then in victory_screen.dart `_recordAndAnimate`, remove the duplicate `_audio.playSfx('victory.mp3')` call at line 417 since it already played from brushing screen.

- [ ] **Step 2: Run tests and commit**

```bash
flutter test
git add lib/screens/brushing_screen.dart lib/screens/victory_screen.dart
git commit -m "fix: crossfade brushing→victory audio — no more 1.3s dead zone"
```

---

## Stream 3: Home Screen (Findings #6, #10, #11, #13, #21)

### Task 3.1: Change diamond icon to military badge (#10)

**Files:**
- Modify: `lib/screens/home_screen.dart:724-725`

- [ ] **Step 1: Replace Icons.diamond with Icons.military_tech**

```dart
// Before:
Icons.diamond,
// After:
Icons.military_tech,
```

`Icons.military_tech` is a medal/badge icon — literal representation of "rank" that a child would understand (P11). Keep the purple color `0xFF7C4DFF`.

- [ ] **Step 2: Run tests and commit**

```bash
flutter test test/home_screen_layout_test.dart
git add lib/screens/home_screen.dart
git commit -m "fix: diamond icon → military_tech badge for Ranger Rank (P11)"
```

### Task 3.2: Replace greeting popup text with visual icons (#11)

**Files:**
- Modify: `lib/screens/home_screen.dart:228-293`

- [ ] **Step 1: Replace text titles with icon-based greetings**

Replace the text-only title with large animated emoji/icon combos that convey emotion without reading:

```dart
final title = switch (greeting.state) {
  GreetingState.justStarted => null,  // Skip title, show hero icon instead
  GreetingState.streak2to4 => null,
  GreetingState.streak5to9 => null,
  GreetingState.streak10to19 => null,
  GreetingState.streak20plus => null,
  GreetingState.returning => null,
  GreetingState.freshStart => null,
};
```

Replace the `Text(title)` widget with a Row of large icons that convey the greeting state visually:

- `justStarted`: Large rocket icon (🚀) 48px — "new journey"
- `streak2to4` / `streak5to9`: Fire icon (🔥) 48px — "streak going"
- `streak10to19`: Star + fire combo 48px — "super streak"
- `streak20plus`: Crown or trophy icon 48px — "legendary"
- `returning`: Wave hand icon 48px — "welcome back"
- `freshStart`: Rocket + sparkle icons 48px — "new adventure"

Keep the streak number display (🔥 7 DAY STREAK!) since the fire emoji + number is semi-visual, but make the number MUCH larger (32px) so it's the focal point instead of the text.

Remove or significantly reduce the text labels. The voice carries the meaning; the popup should be visual-first.

- [ ] **Step 2: Run tests and commit**

```bash
flutter test test/screens/home_screen_test.dart
git add lib/screens/home_screen.dart
git commit -m "feat: greeting popup — icon-first design, text removed (P1)"
```

### Task 3.3: Add progress animation on home return (#6)

**Files:**
- Modify: `lib/screens/home_screen.dart`

- [ ] **Step 1: Animate stat changes on return from brushing**

When returning from brushing with `skipGreeting: true`, the stat pills update via `_loadStats()`. Add a brief scale+glow animation to pills that changed value:

Store the previous values before `_loadStats()`. After reload, if a value increased, trigger a pulse animation on that pill (scale to 1.2x then back to 1.0x over 600ms with a glow effect).

Focus on the star wallet pill — it's the most important change signal. Add a brief "+N" floating text that rises and fades above the pill.

- [ ] **Step 2: Run tests and commit**

```bash
flutter test
git add lib/screens/home_screen.dart
git commit -m "feat: animate stat changes on home return — progress is visible"
```

### Task 3.4: Add streak break voice + animation (#13)

**Files:**
- Modify: `lib/screens/home_screen.dart`

- [ ] **Step 1: Add voice on streak break**

In `_checkGreeting`, when `greeting.state == GreetingState.freshStart` AND `totalBrushes > 2` (not a brand new user), play a voice line after the greeting popup appears: "Let's start a new streak!" 

Use an existing voice file that fits — `voice_greet_fresh_start.mp3` already plays via the greeting system. Add a micro-animation on the streak pill: pulse the rocket icon when streak resets.

- [ ] **Step 2: Run tests and commit**

```bash
flutter test
git add lib/screens/home_screen.dart
git commit -m "feat: streak break voice + pill animation — visual story for non-readers"
```

### Task 3.5: Fix greeting voice continuing after dismiss (#21)

**Files:**
- Modify: `lib/screens/home_screen.dart`

- [ ] **Step 1: Stop voice when greeting popup is dismissed**

Find the greeting popup's `showDialog` call. The dialog is `barrierDismissible: true`. When the popup is dismissed (either by barrier tap or auto-dismiss), call `AudioService().stopVoice()` to prevent the streak teach voice from continuing into the home screen:

Add a `.then((_) => AudioService().stopVoice())` after the `showDialog` call, or use `Navigator.of(dialogContext).pop()` handler to stop voice on dismiss.

- [ ] **Step 2: Run tests and commit**

```bash
flutter test
git add lib/screens/home_screen.dart
git commit -m "fix: stop greeting voice on popup dismiss — no voice leaking to home"
```

---

## Stream 4: Shop & Onboarding (Findings #22, #23, #24, #9)

### Task 4.1: Fix evolution gating snackbars — icon+voice (#24)

**Files:**
- Modify: `lib/screens/hero_shop_screen.dart:139-145, 186-201`

- [ ] **Step 1: Replace text snackbars with icon-only + voice**

For "Get ${hero.name} first!" (line 142):
```dart
// Replace text-only SnackBar with icon-only + voice
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock, color: Colors.amber, size: 24),
        const SizedBox(width: 8),
        // Show hero thumbnail instead of text name
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/images/heroes/${hero.id}.png',
            width: 32, height: 32,
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.arrow_forward, color: Colors.white70, size: 20),
        const SizedBox(width: 8),
        const Icon(Icons.star, color: Color(0xFFFFD54F), size: 24),
      ],
    ),
    backgroundColor: hero.primaryColor.withValues(alpha: 0.9),
    duration: const Duration(seconds: 2),
    behavior: SnackBarBehavior.floating,
  ),
);
```

For "Unlock the previous evolution first!" (line 193): Similar pattern — show lock icon + previous stage thumbnail + arrow + current stage thumbnail. Remove all text.

- [ ] **Step 2: Run tests and commit**

```bash
flutter test test/screens/hero_shop_screen_test.dart
git add lib/screens/hero_shop_screen.dart
git commit -m "feat: evolution snackbars → icon-only (P1 — kids can't read)"
```

### Task 4.2: Improve evolution stage visibility (#22)

**Files:**
- Modify: `lib/screens/hero_shop_screen.dart` (evolution grid/cell layout)

- [ ] **Step 1: Read the evolution cell layout**

Find how evolution stages are displayed in the hero grid. Currently they show as 3 small thumbnails.

- [ ] **Step 2: Add arrow progression indicators**

Between each evolution stage cell, add a small arrow icon (→) to visually communicate "this transforms into that." Make Stage 2 and 3 cells slightly larger or add a glow border to indicate they're upgrades, not separate items.

- [ ] **Step 3: Run tests and commit**

```bash
flutter test test/screens/hero_shop_screen_test.dart
git add lib/screens/hero_shop_screen.dart
git commit -m "feat: evolution stages show arrow progression — clearer upgrade path"
```

### Task 4.3: Fix world intro "TAP TO FIGHT" icon (#23)

**Files:**
- Modify: `lib/screens/brushing_screen.dart` (around line 4120 where "TAP TO FIGHT!" is built)

- [ ] **Step 1: Find the TAP TO FIGHT button icon**

Read the code around line 4120. Identify what icon is currently used. Replace with `Icons.rocket_launch` or `Icons.flash_on` (lightning bolt) — something that says "fight/action", not "microphone."

- [ ] **Step 2: Run tests and commit**

```bash
flutter test
git add lib/screens/brushing_screen.dart
git commit -m "fix: TAP TO FIGHT icon — rocket instead of microphone"
```

### Task 4.4: Retheme onboarding P3 mouth guide (#9)

**Files:**
- Modify: `lib/screens/onboarding_screen.dart`

- [ ] **Step 1: Read the page 3 builder**

Find the page 3 widget that shows the mouth guide with "FOLLOW THE GUIDE" title and "LET'S GO!" button.

- [ ] **Step 2: Retheme with space aesthetic**

1. Change "LET'S GO!" button color to match pages 1-2 (pink/purple gradient, not teal/green)
2. Add a neon border/glow around the mouth guide to match the space theme
3. Replace "FOLLOW THE GUIDE" title with "BATTLE ZONES!" or similar
4. Add a subtle space-themed border to the mouth diagram (glowing ring, star particles)

Keep the mouth guide functional — only change the visual wrapping, not the actual teeth/quadrant highlighting logic.

- [ ] **Step 3: Run tests and commit**

```bash
flutter test test/screens/onboarding_screen_test.dart
git add lib/screens/onboarding_screen.dart
git commit -m "feat: onboarding P3 — space-themed mouth guide, consistent button color"
```

---

## Stream 5: Audio (Findings #8)

### Task 5.1: Add K.O. voice variety (#8)

**Files:**
- Modify: `lib/screens/brushing_screen.dart:1470-1474`

- [ ] **Step 1: Create K.O. voice rotation pool**

Replace the single `voice_awesome.mp3` with a rotation pool using existing voice files:

```dart
static const _koVoices = [
  'voice_awesome.mp3',
  'voice_wow_amazing.mp3',
  'voice_super.mp3',
  'voice_so_strong.mp3',
  'voice_nice_combo.mp3',
];
```

Verify each of these files exists in `assets/audio/voices/buddy/`. If any don't exist, remove them from the list.

- [ ] **Step 2: Replace hardcoded voice with random pick**

```dart
// Before:
_audio.playVoice('voice_awesome.mp3');

// After:
final koVoice = _koVoices[_random.nextInt(_koVoices.length)];
_audio.playVoice(koVoice);
```

- [ ] **Step 3: Run tests and commit**

```bash
flutter test
git add lib/screens/brushing_screen.dart
git commit -m "feat: K.O. voice variety — 5 rotating lines instead of always 'awesome'"
```

---

## Stream 6: Settings (Findings #14, #16, #18)

### Task 6.1: Simplify Stars tab (#14)

**Files:**
- Modify: `lib/screens/settings_screen.dart` (Stars tab builder)

- [ ] **Step 1: Read the Stars tab**

Find the Stars tab content builder. Read what it currently shows (detailed star economy math).

- [ ] **Step 2: Simplify to essential info**

Remove the detailed math breakdown. Replace with a simple visual summary:
- "How to earn stars" with 3 icon rows: toothbrush → star (brush to earn), fire → bonus star (streak bonus), 2x → bonus (morning + evening)
- Keep it to ONE screen height, no scrolling needed
- Remove any formulas or specific numbers — the Guide tab has the detailed explanation

- [ ] **Step 3: Run tests and commit**

```bash
flutter test test/screens/settings_screen_test.dart
git add lib/screens/settings_screen.dart
git commit -m "feat: simplify Stars tab — visual summary, no math"
```

### Task 6.2: Add separate "Delete cloud data" button (#16)

**Files:**
- Modify: `lib/screens/settings_screen.dart` (Account section, when signed in)

- [ ] **Step 1: Add "Delete cloud data" button**

In the Account section, when the user is signed in, add a "Delete cloud data" button below the "Sign out" button. This calls `SyncService().deleteCloudData()` without resetting local progress. Include a confirmation dialog.

```dart
TextButton(
  onPressed: () => _handleDeleteCloudData(),
  child: const Text(
    'Delete cloud data',
    style: TextStyle(color: Colors.redAccent, fontSize: 12),
  ),
),
```

The `_handleDeleteCloudData` method shows a confirmation dialog, then calls `SyncService().deleteCloudData()` and shows a success/failure SnackBar.

- [ ] **Step 2: Run tests and commit**

```bash
flutter test test/screens/settings_screen_test.dart
git add lib/screens/settings_screen.dart
git commit -m "feat: separate delete cloud data button — COPPA compliance"
```

### Task 6.3: Add cross-service purchase mutex (#18)

**Files:**
- Modify: `lib/services/hero_service.dart`
- Modify: `lib/services/weapon_service.dart`
- Modify: `lib/services/streak_service.dart`

- [ ] **Step 1: Move purchase lock to StreakService**

Add a shared `static bool _globalPurchasing = false` to `StreakService` with `static bool get isPurchasing => _globalPurchasing` and `static set isPurchasing(bool v) => _globalPurchasing = v`.

- [ ] **Step 2: Use shared lock in both services**

In `HeroService.purchaseHero` and `HeroService.purchaseEvolution`, replace `_purchasing` with `StreakService.isPurchasing`. Same in `WeaponService.purchaseWeapon`.

```dart
if (StreakService.isPurchasing) return false;
StreakService.isPurchasing = true;
try {
  // ... purchase logic ...
} finally {
  StreakService.isPurchasing = false;
}
```

Remove the per-service `static bool _purchasing` fields.

- [ ] **Step 3: Run tests and commit**

```bash
flutter test test/services/hero_service_test.dart test/services/weapon_service_test.dart
git add lib/services/hero_service.dart lib/services/weapon_service.dart lib/services/streak_service.dart
git commit -m "fix: shared purchase mutex across hero+weapon services — prevents race"
```

---

## Verification

After all streams complete:

```bash
dart analyze
flutter test
flutter build apk
bash scripts/fitness-gates.sh
```

All must pass before shipping.
