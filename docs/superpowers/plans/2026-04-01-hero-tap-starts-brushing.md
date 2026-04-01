# Hero Tap Starts Brushing — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make tapping the hero character on the home screen start brushing (instead of opening the shop), and remove the redundant BRUSH! button.

**Architecture:** The home screen's hero `GestureDetector` currently calls `_openShop()` — we rewire it to call `_startBrushing()` and remove the BRUSH! button widget + its idle bounce animation. The HEROES bottom nav button remains the only path to the shop. The first-launch voice `voice_tap_hero.mp3` already says "tap your hero" which now correctly describes the primary action (start brushing).

**Tech Stack:** Flutter/Dart, shared_preferences

**Parallel work note:** Another session is currently modifying files on `main`. This plan should be implemented in a **git worktree** (`isolation: "worktree"`) to avoid conflicts. The changes are scoped to `home_screen.dart` and its test files. If `home_screen.dart` was modified by the other session, a rebase/merge will be needed before landing.

---

### Task 1: Rewire hero tap from shop to brushing

**Files:**
- Modify: `lib/screens/home_screen.dart:767-772` (hero GestureDetector onTapUp)

This is the core change. The hero `GestureDetector.onTapUp` currently calls `_openShop()`. Change it to call `_startBrushing()`.

- [ ] **Step 1: Write the failing test**

In `test/screens/home_screen_test.dart`, add a test that verifies tapping the hero image triggers the brushing flow (navigates to BrushingScreen), not the shop:

```dart
testWidgets('tapping hero starts brushing flow', (tester) async {
  await pumpHome(tester);

  // Find the hero image area — it's inside a GestureDetector > Column > ClipOval
  // The hero name text "BLAZE" is directly below the hero image in the same Column
  final heroName = find.text('BLAZE');
  expect(heroName, findsOneWidget);

  // Tap on the hero name (which is inside the hero GestureDetector)
  await tester.tap(heroName);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump();

  // Verify we navigated to BrushingScreen (not HeroShopScreen)
  expect(find.byType(BrushingScreen), findsOneWidget);

  await tester.binding.setSurfaceSize(null);
});
```

Add the required import at the top of the test file:
```dart
import 'package:brush_quest/screens/brushing_screen.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/jimchabas/Projects/brush-quest && flutter test test/screens/home_screen_test.dart --name "tapping hero starts brushing flow" --no-pub`
Expected: FAIL — currently hero tap opens HeroShopScreen, not BrushingScreen.

- [ ] **Step 3: Change hero tap to start brushing**

In `lib/screens/home_screen.dart`, find the hero `GestureDetector` (around line 767-772):

```dart
// FIND THIS:
onTapUp: (_) {
  setState(() => _buttonPressed = false);
  _openShop();
},

// REPLACE WITH:
onTapUp: (_) {
  setState(() => _buttonPressed = false);
  _startBrushing();
},
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/jimchabas/Projects/brush-quest && flutter test test/screens/home_screen_test.dart --name "tapping hero starts brushing flow" --no-pub`
Expected: PASS

- [ ] **Step 5: Run dart analyze**

Run: `cd /Users/jimchabas/Projects/brush-quest && dart analyze lib/screens/home_screen.dart`
Expected: No issues found

- [ ] **Step 6: Commit**

```bash
git add lib/screens/home_screen.dart test/screens/home_screen_test.dart
git commit -m "feat: hero tap starts brushing instead of opening shop"
```

---

### Task 2: Remove the BRUSH! button and its idle bounce animation

**Files:**
- Modify: `lib/screens/home_screen.dart:59-61` (remove `_idleBounceController`, `_idleBounceAnimation`, `_idleBounceTimer` declarations)
- Modify: `lib/screens/home_screen.dart:111-127` (remove idle bounce init)
- Modify: `lib/screens/home_screen.dart:139` (remove `_idleBounceController.dispose()` and `_idleBounceTimer?.cancel()`)
- Modify: `lib/screens/home_screen.dart:870-921` (remove the entire BRUSH! button widget block)

- [ ] **Step 1: Update existing test that checks for BRUSH! button**

In `test/screens/home_screen_test.dart`, find the test `'BRUSH button is visible'` (line 120-126). Change it to verify the BRUSH button is NOT present:

```dart
testWidgets('BRUSH button is removed (hero is the CTA)', (tester) async {
  await pumpHome(tester);

  expect(find.text('BRUSH!'), findsNothing);

  await tester.binding.setSurfaceSize(null);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/jimchabas/Projects/brush-quest && flutter test test/screens/home_screen_test.dart --name "BRUSH button is removed" --no-pub`
Expected: FAIL — BRUSH! button still exists.

- [ ] **Step 3: Remove the BRUSH! button widget**

In `lib/screens/home_screen.dart`, remove the entire BRUSH! button block. Find and delete:

```dart
// REMOVE THIS ENTIRE BLOCK (lines ~870-921):
// BRUSH button
AnimatedBuilder(
  animation: _idleBounceAnimation,
  builder: (context, child) {
    return Transform.scale(
      scale: _idleBounceAnimation.value,
      child: child,
    );
  },
  child: GestureDetector(
    onTap: _startBrushing,
    child: AnimatedBuilder(
      animation: _tapPulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + _tapPulseAnimation.value * 0.03,
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _selectedHero.primaryColor,
              _selectedHero.primaryColor.withValues(alpha: 0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: _selectedHero.primaryColor.withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Text(
          'BRUSH!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
          ),
        ),
      ),
    ),
  ),
),

const SizedBox(height: 10),
```

Also remove the `const SizedBox(height: 10),` that follows it (between the button and the Spacer).

- [ ] **Step 4: Remove idle bounce animation controller and timer**

These are only used by the BRUSH! button. Remove them from three places:

**A) Remove declarations** (around lines 59-61):
```dart
// REMOVE these three lines:
late AnimationController _idleBounceController;
late Animation<double> _idleBounceAnimation;
Timer? _idleBounceTimer;
```

**B) Remove initialization** in `initState` (around lines 111-127):
```dart
// REMOVE this block:
_idleBounceController = AnimationController(
  duration: const Duration(milliseconds: 600),
  vsync: this,
);
_idleBounceAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
  CurvedAnimation(parent: _idleBounceController, curve: Curves.elasticOut),
);

_idleBounceTimer = Timer(const Duration(seconds: 3), () {
  _idleBounceController.forward().then((_) => _idleBounceController.reverse());
  _idleBounceTimer = Timer.periodic(const Duration(seconds: 4), (_) {
    if (mounted) {
      _idleBounceController.forward().then((_) => _idleBounceController.reverse());
    }
  });
});
```

**C) Remove disposal** in `dispose` (around line 139-140):
```dart
// REMOVE these two lines:
_idleBounceController.dispose();
_idleBounceTimer?.cancel();
```

- [ ] **Step 5: Run tests to verify**

Run: `cd /Users/jimchabas/Projects/brush-quest && flutter test test/screens/home_screen_test.dart --no-pub`
Expected: ALL PASS (including the updated "BRUSH button is removed" test)

- [ ] **Step 6: Run dart analyze**

Run: `cd /Users/jimchabas/Projects/brush-quest && dart analyze lib/screens/home_screen.dart`
Expected: No issues found

- [ ] **Step 7: Commit**

```bash
git add lib/screens/home_screen.dart test/screens/home_screen_test.dart
git commit -m "refactor: remove BRUSH! button — hero is now the primary CTA"
```

---

### Task 3: Remove tap pulse animation (was only used for BRUSH! button visual)

**Files:**
- Modify: `lib/screens/home_screen.dart`

The `_tapPulseController` and `_tapPulseAnimation` were only used in the BRUSH! button's `AnimatedBuilder`. After removing the button, they are dead code.

- [ ] **Step 1: Verify _tapPulseAnimation is unused**

Search `home_screen.dart` for `_tapPulse` to confirm it's only referenced in declarations, init, and dispose — no widget references remain after Task 2.

- [ ] **Step 2: Remove tap pulse controller**

**A) Remove declarations** (around lines 56-57):
```dart
// REMOVE:
late AnimationController _tapPulseController;
late Animation<double> _tapPulseAnimation;
```

**B) Remove initialization** in `initState` (around lines 95-101):
```dart
// REMOVE:
_tapPulseController = AnimationController(
  duration: const Duration(milliseconds: 1500),
  vsync: this,
)..repeat(reverse: true);
_tapPulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
  CurvedAnimation(parent: _tapPulseController, curve: Curves.easeInOut),
);
```

**C) Remove disposal** in `dispose`:
```dart
// REMOVE:
_tapPulseController.dispose();
```

- [ ] **Step 3: Run dart analyze**

Run: `cd /Users/jimchabas/Projects/brush-quest && dart analyze lib/screens/home_screen.dart`
Expected: No issues found

- [ ] **Step 4: Run all tests**

Run: `cd /Users/jimchabas/Projects/brush-quest && flutter test test/screens/home_screen_test.dart test/home_screen_layout_test.dart --no-pub`
Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
git add lib/screens/home_screen.dart
git commit -m "refactor: remove unused tap pulse animation (was BRUSH! button only)"
```

---

### Task 4: Update first-launch voice context

**Files:**
- Modify: `lib/screens/home_screen.dart:225-231` (first-launch voice logic in `_checkGreeting`)

The first-launch voice `voice_tap_hero.mp3` currently plays when `totalBrushes == 0` and says something like "tap your hero." This is actually *still correct* — tapping the hero now starts brushing, which is exactly what a first-time user should do. 

However, we should verify the voice content makes sense in the new context. If it says "tap your hero to see the shop" or similar, we'd need a new voice file. 

- [ ] **Step 1: Listen to voice_tap_hero.mp3**

Play the file to verify what it says:
```bash
afplay /Users/jimchabas/Projects/brush-quest/assets/audio/voices/classic/voice_tap_hero.mp3
```

**If it says something like "Tap your hero to get started" or "Tap your hero"** → the voice is correct for the new flow. Skip to Step 3.

**If it says something like "Tap your hero to see the shop" or "Tap your hero to pick a character"** → the voice is misleading and needs to be replaced or the guidance voice line changed. Proceed to Step 2.

- [ ] **Step 2: (Conditional) Update the voice file reference**

If the voice says something shop-related, change the voice file to one of the existing welcome voices that doesn't reference the shop:

```dart
// In _checkGreeting, first-launch block:
// FIND:
AudioService().playVoice('voice_tap_hero.mp3');

// REPLACE WITH (if voice is misleading):
AudioService().playVoice('voice_go_go_go.mp3');
```

Note: If a new ElevenLabs voice is needed, that's a separate task (Tier 3 — needs Jim's approval for audio changes).

- [ ] **Step 3: Write a test for first-launch voice behavior**

This test already exists implicitly (the greeting logic is tested), but add an explicit test in `test/screens/home_screen_test.dart` to document the expected first-launch behavior:

```dart
testWidgets('first-launch plays tap hero voice', (tester) async {
  SharedPreferences.setMockInitialValues({
    'selected_hero': 'blaze',
    'selected_weapon': 'star_blaster',
    'total_stars': 0,
    'current_streak': 0,
    'total_brushes': 0,
    'muted': false,
  });

  await tester.binding.setSurfaceSize(const Size(430, 932));
  await tester.pumpWidget(
    const MaterialApp(home: HomeScreen()),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));

  // Verify the first-launch voice was played
  expect(fakeAudio.playedVoices, contains('voice_tap_hero.mp3'));

  await tester.binding.setSurfaceSize(null);
});
```

- [ ] **Step 4: Run tests**

Run: `cd /Users/jimchabas/Projects/brush-quest && flutter test test/screens/home_screen_test.dart --no-pub`
Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
git add lib/screens/home_screen.dart test/screens/home_screen_test.dart
git commit -m "test: verify first-launch voice works with hero-as-CTA flow"
```

---

### Task 5: Full regression — run all tests and analyze

**Files:** None modified — verification only.

- [ ] **Step 1: Run dart analyze on entire project**

Run: `cd /Users/jimchabas/Projects/brush-quest && dart analyze`
Expected: No issues found

- [ ] **Step 2: Run full test suite**

Run: `cd /Users/jimchabas/Projects/brush-quest && flutter test --no-pub`
Expected: All tests pass (should be 671+ tests)

- [ ] **Step 3: Verify no dead imports**

Run: `cd /Users/jimchabas/Projects/brush-quest && dart analyze lib/screens/home_screen.dart`

Check that removing the BRUSH button didn't leave orphaned imports (e.g., if `_tapPulseAnimation` was the last user of some import).

- [ ] **Step 4: Final commit if any cleanup was needed**

```bash
git add -A
git commit -m "chore: cleanup after hero-tap-starts-brushing refactor"
```

---

## Summary of changes

| Before | After |
|--------|-------|
| Hero tap → opens hero shop (same as HEROES nav button) | Hero tap → starts brushing |
| BRUSH! button → starts brushing | Removed — hero is the CTA |
| HEROES nav button → opens hero shop | Unchanged — now the **only** path to shop |
| Idle bounce animation on BRUSH! button | Removed (dead code) |
| Tap pulse animation on BRUSH! button | Removed (dead code) |
| First-launch voice "tap your hero" → leads to shop | First-launch voice "tap your hero" → leads to brushing (correct!) |

## Files touched

- `lib/screens/home_screen.dart` — main changes (rewire hero tap, remove button + animations)
- `test/screens/home_screen_test.dart` — update/add tests

## Risk notes

- **Other session conflict:** `home_screen.dart` is the primary file modified. If the other session (greeting popup simplification) also touches this file after this plan's branch point, a merge will be needed. The greeting simplification commits (`4f1319f`, `a44e269`) are already on main, so as long as the other session doesn't make *more* changes to `home_screen.dart`, this should merge cleanly.
- **Voice file:** `voice_tap_hero.mp3` must be audited (Task 4 Step 1). If it references the shop, it will mislead users in the new flow.
