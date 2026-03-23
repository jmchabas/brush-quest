# Bonus Communication System — Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the star bonus system visible and understandable to 3-7 year old kids through three redundant touchpoints: victory screen star rain waves, sun-moon daily tracker on home screen, and hero voice lines for daily pair + streak milestones.

**Architecture:** Extend `BrushOutcome` to expose a granular bonus breakdown (base vs daily vs streak). Rework the victory screen star display into sequential animated waves, each from a visually distinct source. Add a sun-moon widget to the home screen that shows daily pair progress with a pulsing bonus star. Add voice lines triggered at streak milestones and daily pair completion.

**Tech Stack:** Flutter/Dart, SharedPreferences, audioplayers, ElevenLabs TTS (for voice line generation)

---

## File Map

| Action | File | Responsibility |
|--------|------|---------------|
| Modify | `lib/services/streak_service.dart` | Extend `BrushOutcome` with `dailyBonus` and `streakMultiplierBonus` fields |
| Modify | `test/services/streak_service_test.dart` | Test bonus breakdown |
| Create | `lib/widgets/star_rain.dart` | Self-contained star rain wave animation widget |
| Create | `test/widgets/star_rain_test.dart` | StarRain widget tests |
| Modify | `lib/screens/victory_screen.dart` | Replace single "+N STAR" with `StarRain` wave sequence |
| Modify | `test/screens/victory_screen_test.dart` | Test wave display |
| Create | `lib/widgets/sun_moon_tracker.dart` | Sun-moon daily pair tracker widget |
| Modify | `lib/screens/home_screen.dart` | Add `SunMoonTracker` below hero |
| Modify | `test/screens/home_screen_test.dart` | Test tracker display |
| Modify | `lib/services/audio_service.dart` | Add voice line constants for new lines |
| Create | `assets/audio/voices/classic/voice_full_charge.mp3` | Daily pair voice line |
| Create | `assets/audio/voices/classic/voice_super_power.mp3` | 3-day streak milestone voice |
| Create | `assets/audio/voices/classic/voice_mega_power.mp3` | 7-day streak milestone voice |
| Create | `assets/audio/voices/classic/voice_streak_bonus.mp3` | Generic streak bonus voice |

---

## Task 1: Extend BrushOutcome with Bonus Breakdown

**Files:**
- Modify: `lib/services/streak_service.dart:8-22` (BrushOutcome class)
- Modify: `lib/services/streak_service.dart:74-83` (calculateStreakBonus)
- Modify: `lib/services/streak_service.dart:175-181` (return statement)
- Test: `test/services/streak_service_test.dart`

- [ ] **Step 1: Write failing tests for bonus breakdown**

In `test/services/streak_service_test.dart`, add these tests:

```dart
test('BrushOutcome exposes dailyBonus separately from streakMultiplierBonus', () async {
  // Setup: morning already done, 5-day streak, now evening brush
  SharedPreferences.setMockInitialValues({
    'morning_done_date': _todayString(),
    'current_streak': 5,
    'last_brush_date': _todayString(),
    'today_brush_count': 1,
    'today_date': _todayString(),
    'total_stars': 10,
    'star_wallet': 10,
    'total_brushes': 10,
  });
  final service = StreakService();
  // Evening brush (hour >= 15) — need to mock time or test via calculateStreakBonus
  final bonus = service.calculateStreakBonusDetailed(streak: 5, bothSlotsDone: true);
  expect(bonus.dailyBonus, 1);
  expect(bonus.streakMultiplierBonus, 1);
  expect(bonus.total, 2);
});

test('7-day streak gives streakMultiplierBonus of 2', () {
  final service = StreakService();
  final bonus = service.calculateStreakBonusDetailed(streak: 7, bothSlotsDone: false);
  expect(bonus.dailyBonus, 0);
  expect(bonus.streakMultiplierBonus, 2);
  expect(bonus.total, 2);
});

test('no streak and single slot gives zero bonus', () {
  final service = StreakService();
  final bonus = service.calculateStreakBonusDetailed(streak: 1, bothSlotsDone: false);
  expect(bonus.dailyBonus, 0);
  expect(bonus.streakMultiplierBonus, 0);
  expect(bonus.total, 0);
});

test('7-day streak with both slots gives max bonus of 3', () {
  final service = StreakService();
  final bonus = service.calculateStreakBonusDetailed(streak: 7, bothSlotsDone: true);
  expect(bonus.dailyBonus, 1);
  expect(bonus.streakMultiplierBonus, 2);
  expect(bonus.total, 3);
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd ~/Projects/brush-quest && flutter test test/services/streak_service_test.dart -v`
Expected: FAIL — `calculateStreakBonusDetailed` and `BonusBreakdown` not defined.

- [ ] **Step 3: Implement BonusBreakdown class and updated BrushOutcome**

In `lib/services/streak_service.dart`, add `BonusBreakdown` class after line 5 (before `BrushSlot` enum):

```dart
class BonusBreakdown {
  final int dailyBonus;
  final int streakMultiplierBonus;
  int get total => dailyBonus + streakMultiplierBonus;

  const BonusBreakdown({
    required this.dailyBonus,
    required this.streakMultiplierBonus,
  });
}
```

Update `BrushOutcome` (lines 8-22) to add the breakdown field:

```dart
class BrushOutcome {
  final int baseStars;
  final int streakBonus; // Keep for backward compat (= breakdown.total)
  final int starsEarned;
  final BrushSlot slot;
  final bool newSlotCompleted;
  final BonusBreakdown breakdown;

  const BrushOutcome({
    required this.baseStars,
    required this.streakBonus,
    required this.starsEarned,
    required this.slot,
    required this.newSlotCompleted,
    required this.breakdown,
  });
}
```

Add `calculateStreakBonusDetailed` method (after existing `calculateStreakBonus`, ~line 83):

```dart
BonusBreakdown calculateStreakBonusDetailed({
  required int streak,
  required bool bothSlotsDone,
}) {
  final dailyBonus = bothSlotsDone ? 1 : 0;
  int streakMultiplierBonus = 0;
  if (streak >= 7) {
    streakMultiplierBonus = 2;
  } else if (streak >= 3) {
    streakMultiplierBonus = 1;
  }
  return BonusBreakdown(
    dailyBonus: dailyBonus,
    streakMultiplierBonus: streakMultiplierBonus,
  );
}
```

Update `recordBrush` return (around line 132-181) to compute and include the breakdown:

```dart
final breakdown = calculateStreakBonusDetailed(
  streak: streak,
  bothSlotsDone: updatedSlots.morningDone && updatedSlots.eveningDone,
);
final streakBonus = breakdown.total;
```

And update the return statement to include `breakdown: breakdown`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd ~/Projects/brush-quest && flutter test test/services/streak_service_test.dart -v`
Expected: All tests PASS including new bonus breakdown tests.

- [ ] **Step 5: Run dart analyze**

Run: `cd ~/Projects/brush-quest && dart analyze lib/services/streak_service.dart`
Expected: No issues.

- [ ] **Step 6: Commit**

```bash
cd ~/Projects/brush-quest
git add lib/services/streak_service.dart test/services/streak_service_test.dart
git commit -m "feat: expose bonus breakdown in BrushOutcome (daily vs streak)"
```

---

## Task 2: Star Rain Wave Widget

**Files:**
- Create: `lib/widgets/star_rain.dart`
- Test: (tested via victory screen widget test)

- [ ] **Step 1: Create the StarRain widget**

Create `lib/widgets/star_rain.dart`. This is a self-contained widget that takes a `BonusBreakdown`, base stars, chest bonus, and animates sequential waves:

```dart
import 'package:flutter/material.dart';

/// Data for each wave of the star rain animation.
class StarWave {
  final int count;
  final Color color;
  final Color glowColor;
  final IconData sourceIcon;
  final String label; // e.g., "STREAK BONUS"
  final bool hasTrail; // fire trail for streak stars

  const StarWave({
    required this.count,
    required this.color,
    required this.glowColor,
    required this.sourceIcon,
    required this.label,
    this.hasTrail = false,
  });
}

/// Displays earned stars in sequential animated waves.
///
/// Each wave arrives from a different visual source with distinct colors:
/// - Wave 1 (base): yellow stars, tooth icon
/// - Wave 2 (streak): orange/blue fire stars, fire icon
/// - Wave 3 (daily): gold+silver stars, sun-moon icon
/// - Wave 4 (chest): purple stars, chest icon
///
/// The widget auto-plays the sequence on mount. Tap anywhere to skip
/// to the final total.
class StarRain extends StatefulWidget {
  final int baseStars;
  final int streakBonus;
  final int dailyBonus;
  final int currentStreak;
  final VoidCallback? onComplete;

  const StarRain({
    super.key,
    required this.baseStars,
    this.streakBonus = 0,
    this.dailyBonus = 0,
    this.currentStreak = 0,
    this.onComplete,
  });

  @override
  State<StarRain> createState() => _StarRainState();
}

class _StarRainState extends State<StarRain> with TickerProviderStateMixin {
  final List<StarWave> _waves = [];
  int _currentWaveIndex = -1;
  int _runningTotal = 0;
  bool _skipped = false;
  late final int _grandTotal;

  // Per-wave animation controllers
  final List<AnimationController> _waveControllers = [];
  final List<Animation<double>> _waveScaleAnims = [];
  final List<Animation<double>> _waveFadeAnims = [];

  // Running total counter animation
  late AnimationController _counterController;
  late IntTween _counterTween;

  @override
  void initState() {
    super.initState();
    _buildWaves();
    _grandTotal = widget.baseStars + widget.streakBonus + widget.dailyBonus;

    _counterController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _counterTween = IntTween(begin: 0, end: 0);

    // Create a controller per wave
    for (var i = 0; i < _waves.length; i++) {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );
      _waveControllers.add(controller);
      _waveScaleAnims.add(
        CurvedAnimation(parent: controller, curve: Curves.elasticOut),
      );
      _waveFadeAnims.add(
        CurvedAnimation(parent: controller, curve: Curves.easeIn),
      );
    }

    _playSequence();
  }

  void _buildWaves() {
    // Wave 1: Base stars (always present)
    _waves.add(StarWave(
      count: widget.baseStars,
      color: const Color(0xFFFFD54F), // Gold
      glowColor: const Color(0xFFFFA000),
      sourceIcon: Icons.cleaning_services, // Tooth/brush icon
      label: '',
    ));

    // Wave 2: Streak bonus (if any)
    if (widget.streakBonus > 0) {
      final isHighStreak = widget.currentStreak >= 7;
      _waves.add(StarWave(
        count: widget.streakBonus,
        color: isHighStreak ? const Color(0xFF64B5F6) : const Color(0xFFFF8A65), // Blue or orange
        glowColor: isHighStreak ? const Color(0xFF1E88E5) : const Color(0xFFFF5722),
        sourceIcon: Icons.local_fire_department,
        label: isHighStreak ? 'MEGA POWER!' : 'STREAK BONUS!',
        hasTrail: true,
      ));
    }

    // Wave 3: Daily bonus (if both morning + evening)
    if (widget.dailyBonus > 0) {
      _waves.add(StarWave(
        count: widget.dailyBonus,
        color: const Color(0xFFE0E0E0), // Silver-gold
        glowColor: const Color(0xFFFFD54F),
        sourceIcon: Icons.brightness_6, // Sun + moon icon
        label: 'FULL CHARGE!',
      ));
    }

    // Wave 4: Chest bonus (added later after chest opens)
    // Not included in StarRain — chest has its own reveal animation.
  }

  Future<void> _playSequence() async {
    for (var i = 0; i < _waves.length; i++) {
      if (_skipped || !mounted) return;
      await Future.delayed(Duration(milliseconds: i == 0 ? 200 : 500));
      if (_skipped || !mounted) return;

      setState(() => _currentWaveIndex = i);

      // Animate the wave in
      _waveControllers[i].forward();

      // Update running total
      final prevTotal = _runningTotal;
      _runningTotal += _waves[i].count;
      _counterTween = IntTween(begin: prevTotal, end: _runningTotal);
      _counterController.forward(from: 0);

      // Wait for wave animation to mostly complete before next
      await Future.delayed(const Duration(milliseconds: 400));
    }

    // Sequence complete
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) widget.onComplete?.call();
  }

  void _skip() {
    if (_skipped) return;
    _skipped = true;
    setState(() {
      _currentWaveIndex = _waves.length - 1;
      _runningTotal = _grandTotal;
    });
    // Snap all wave controllers to end
    for (final c in _waveControllers) {
      if (!c.isCompleted) c.forward();
    }
    _counterTween = IntTween(begin: _grandTotal, end: _grandTotal);
    _counterController.forward(from: 1.0);
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _counterController.dispose();
    for (final c in _waveControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _skip,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Running total counter
          AnimatedBuilder(
            animation: _counterController,
            builder: (context, child) {
              final value = _counterTween.evaluate(_counterController);
              return Text(
                '+$value',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  shadows: [
                    Shadow(color: Color(0xFFFFD54F), blurRadius: 20),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          const Text(
            'STARS EARNED',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 16),
          // Wave indicators row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_waves.length, _buildWaveIndicator),
          ),
        ],
      ),
    );
  }

  Widget _buildWaveIndicator(int index) {
    final wave = _waves[index];
    final visible = index <= _currentWaveIndex;

    if (!visible) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Opacity(
          opacity: 0.2,
          child: _buildStarCluster(wave, 0.6),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: AnimatedBuilder(
        animation: _waveControllers[index],
        builder: (context, child) {
          final scale = _waveScaleAnims[index].value;
          final fade = _waveFadeAnims[index].value;
          return Opacity(
            opacity: fade,
            child: Transform.scale(
              scale: 0.5 + scale * 0.5,
              child: _buildStarCluster(wave, 1.0),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStarCluster(StarWave wave, double opacity) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Source icon
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: wave.color.withAlpha(40),
            boxShadow: [
              BoxShadow(
                color: wave.glowColor.withAlpha((80 * opacity).round()),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(wave.sourceIcon, color: wave.color, size: 22),
        ),
        const SizedBox(height: 4),
        // Star count
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(wave.count, (i) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Icon(
              Icons.star,
              size: 18,
              color: wave.color,
              shadows: [
                Shadow(color: wave.glowColor, blurRadius: 8),
              ],
            ),
          )),
        ),
        if (wave.label.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            wave.label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: wave.color,
              letterSpacing: 1,
            ),
          ),
        ],
      ],
    );
  }
}
```

- [ ] **Step 2: Write StarRain widget tests**

Create `test/widgets/star_rain_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brush_quest/widgets/star_rain.dart';

void main() {
  testWidgets('shows correct number of wave indicators for base only', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: StarRain(baseStars: 2)),
    ));
    await tester.pump();
    // Only base wave — 1 indicator group
    expect(find.byIcon(Icons.cleaning_services), findsOneWidget);
    expect(find.byIcon(Icons.local_fire_department), findsNothing);
  });

  testWidgets('shows streak wave when streakBonus > 0', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: StarRain(baseStars: 2, streakBonus: 1, currentStreak: 3)),
    ));
    await tester.pump();
    expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
  });

  testWidgets('shows daily wave when dailyBonus > 0', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: StarRain(baseStars: 2, dailyBonus: 1)),
    ));
    await tester.pump();
    expect(find.byIcon(Icons.brightness_6), findsOneWidget);
  });

  testWidgets('tap to skip jumps to grand total', (tester) async {
    bool completed = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: StarRain(
        baseStars: 2,
        streakBonus: 1,
        dailyBonus: 1,
        currentStreak: 3,
        onComplete: () => completed = true,
      )),
    ));
    await tester.pump();
    await tester.tap(find.byType(StarRain));
    await tester.pump();
    expect(completed, isTrue);
    expect(find.text('+4'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd ~/Projects/brush-quest && flutter test test/widgets/star_rain_test.dart -v`
Expected: FAIL — StarRain not yet created.

- [ ] **Step 4: Create the StarRain widget** (code from Step 1 above)

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd ~/Projects/brush-quest && flutter test test/widgets/star_rain_test.dart -v`
Expected: PASS

- [ ] **Step 6: Run dart analyze on the new widget**

Run: `cd ~/Projects/brush-quest && dart analyze lib/widgets/star_rain.dart`
Expected: No issues.

- [ ] **Step 7: Commit**

```bash
cd ~/Projects/brush-quest
git add lib/widgets/star_rain.dart test/widgets/star_rain_test.dart
git commit -m "feat: add StarRain wave animation widget for bonus visibility"
```

---

## Task 3: Integrate StarRain into Victory Screen

**Files:**
- Modify: `lib/screens/victory_screen.dart`
- Test: `test/screens/victory_screen_test.dart`

This task reworks the victory screen to use the new `StarRain` widget and play voice lines for streak milestones and daily pair completion.

- [ ] **Step 1: Add state variables for bonus breakdown**

In `victory_screen.dart`, add new state variables in `_VictoryScreenState` immediately after the `_newWallet` declaration:

```dart
// Bonus breakdown for star rain waves
int _dailyBonus = 0;
int _streakMultiplierBonus = 0;
```

- [ ] **Step 2: Capture breakdown from BrushOutcome in _recordAndAnimate**

In `_recordAndAnimate()`, right after `_starsEarnedThisSession = outcome.starsEarned;`, extract the breakdown:

```dart
_dailyBonus = outcome.breakdown.dailyBonus;
_streakMultiplierBonus = outcome.breakdown.streakMultiplierBonus;
```

- [ ] **Step 3: Replace the big star icon + "+N STAR" display with StarRain**

In the build method, find the `AnimatedBuilder` block that uses `_starScale` and `_starRotationController` (the large 120x120 gold circle with the star icon), along with the `"+$_starsEarnedThisSession STAR THIS SESSION"` text below it. Replace the entire block (from the `AnimatedBuilder` through the "+N STAR" text) with:

```dart
// Star rain wave animation
if (_starsEarnedThisSession > 0)
  StarRain(
    baseStars: 2,
    streakBonus: _streakMultiplierBonus,
    dailyBonus: _dailyBonus,
    currentStreak: _newStreak,
    onComplete: () {
      // Star rain done — continues to chest sequence
    },
  ),
```

Keep the existing animated counter (TweenAnimationBuilder for total stars / wallet) below the StarRain.

- [ ] **Step 4: Add voice lines for streak milestones and daily pair**

In `_recordAndAnimate()`, after the arc beat 2 voice (`await _audio.playVoice(arc[1])`) and before `_starController.forward()`, add milestone voice lines:

```dart
// Play bonus-specific voice lines after the star rain
if (_streakMultiplierBonus > 0 && _newStreak == 3) {
  // First time hitting 3-day streak — teaching moment
  _audio.playVoice('voice_super_power.mp3');
} else if (_streakMultiplierBonus > 0 && _newStreak == 7) {
  // First time hitting 7-day streak — big celebration
  _audio.playVoice('voice_mega_power.mp3');
} else if (_streakMultiplierBonus > 0) {
  // Generic streak bonus voice
  _audio.playVoice('voice_streak_bonus.mp3');
}

if (_dailyBonus > 0) {
  _audio.playVoice('voice_full_charge.mp3');
}
```

**Note:** These voice files are created in Task 6. Until then, `playVoice` will fail silently (the existing `FakeAudioService` used in tests is a no-op, and `AudioService.playVoice` catches file-not-found errors). Tests will pass.

- [ ] **Step 5: Import StarRain widget**

Add to imports at top of `victory_screen.dart`:

```dart
import '../widgets/star_rain.dart';
```

- [ ] **Step 6: Remove old star animation controllers that are no longer needed**

The `_starController`, `_starScale`, `_starRotationController`, and `_starGlowController` controlled the single big star animation. These can be removed since StarRain handles its own animations. Remove:
- Controller declarations: find `_starController`, `_starScale`, `_starRotationController`, `_starGlowController` in the state class variable declarations
- Their disposal calls in `dispose()`
- The `.forward()` and `.repeat()` calls in `_recordAndAnimate()` (the three lines after arc beat 2: `_starController.forward()`, `_starRotationController.repeat()`, `_starGlowController.repeat(reverse: true)`)
- The entire `AnimatedBuilder` block in `build()` that references `_starScale` and renders the 120x120 gold circle with the star icon

- [ ] **Step 7: Run tests**

Run: `cd ~/Projects/brush-quest && flutter test test/screens/victory_screen_test.dart -v`
Expected: Tests pass. May need to update tests that look for old "STAR THIS SESSION" text.

- [ ] **Step 8: Run dart analyze**

Run: `cd ~/Projects/brush-quest && dart analyze lib/screens/victory_screen.dart`
Expected: No issues.

- [ ] **Step 9: Commit**

```bash
cd ~/Projects/brush-quest
git add lib/screens/victory_screen.dart lib/widgets/star_rain.dart test/screens/victory_screen_test.dart
git commit -m "feat: replace single star display with sequential star rain waves on victory screen"
```

---

## Task 4: Sun-Moon Daily Tracker Widget

**Files:**
- Create: `lib/widgets/sun_moon_tracker.dart`
- Test: `test/widgets/sun_moon_tracker_test.dart`

- [ ] **Step 1: Write failing widget test**

Create `test/widgets/sun_moon_tracker_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brush_quest/widgets/sun_moon_tracker.dart';

void main() {
  testWidgets('shows two empty slots when neither session done', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SunMoonTracker(morningDone: false, eveningDone: false)),
    ));

    // Both icons should be present but dimmed
    expect(find.byIcon(Icons.wb_sunny), findsOneWidget);
    expect(find.byIcon(Icons.nightlight_round), findsOneWidget);
  });

  testWidgets('sun fills when morning done', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SunMoonTracker(morningDone: true, eveningDone: false)),
    ));

    // Bonus star should be visible (pulsing between sun and moon)
    expect(find.byIcon(Icons.star), findsOneWidget);
  });

  testWidgets('both filled shows completed state', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SunMoonTracker(morningDone: true, eveningDone: true)),
    ));

    expect(find.byIcon(Icons.wb_sunny), findsOneWidget);
    expect(find.byIcon(Icons.nightlight_round), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd ~/Projects/brush-quest && flutter test test/widgets/sun_moon_tracker_test.dart -v`
Expected: FAIL — file/class not found.

- [ ] **Step 3: Implement SunMoonTracker widget**

Create `lib/widgets/sun_moon_tracker.dart`:

```dart
import 'package:flutter/material.dart';

/// Displays two circular slots (sun for morning, moon for evening)
/// with a bonus star pulsing on the arc between them when one is
/// complete but not the other.
///
/// When both are complete, the star bursts and the pair glows connected.
class SunMoonTracker extends StatefulWidget {
  final bool morningDone;
  final bool eveningDone;

  const SunMoonTracker({
    super.key,
    required this.morningDone,
    required this.eveningDone,
  });

  @override
  State<SunMoonTracker> createState() => _SunMoonTrackerState();
}

class _SunMoonTrackerState extends State<SunMoonTracker>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  bool get _bothDone => widget.morningDone && widget.eveningDone;
  bool get _oneDone => widget.morningDone != widget.eveningDone;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSlot(
            icon: Icons.wb_sunny,
            filled: widget.morningDone,
            activeColor: const Color(0xFFFFD54F), // Gold
            size: 42,
          ),
          const SizedBox(width: 4),
          _buildBonusStar(),
          const SizedBox(width: 4),
          _buildSlot(
            icon: Icons.nightlight_round,
            filled: widget.eveningDone,
            activeColor: const Color(0xFF90CAF9), // Silver-blue
            size: 42,
          ),
        ],
      ),
    );
  }

  Widget _buildSlot({
    required IconData icon,
    required bool filled,
    required Color activeColor,
    required double size,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? activeColor.withAlpha(50) : Colors.white.withAlpha(15),
        border: Border.all(
          color: filled ? activeColor.withAlpha(180) : Colors.white.withAlpha(40),
          width: 2,
        ),
        boxShadow: filled
            ? [BoxShadow(color: activeColor.withAlpha(80), blurRadius: 12, spreadRadius: 2)]
            : null,
      ),
      child: Icon(
        icon,
        size: 22,
        color: filled ? activeColor : Colors.white.withAlpha(60),
      ),
    );
  }

  Widget _buildBonusStar() {
    // Both done: show a static glowing star
    if (_bothDone) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD54F).withAlpha(120),
              blurRadius: 16,
              spreadRadius: 4,
            ),
          ],
        ),
        child: const Icon(
          Icons.star,
          size: 24,
          color: Color(0xFFFFD54F),
          shadows: [Shadow(color: Color(0xFFFFD54F), blurRadius: 12)],
        ),
      );
    }

    // One done: show a pulsing star (teasing the bonus)
    if (_oneDone) {
      return AnimatedBuilder(
        animation: _pulseAnim,
        builder: (context, child) {
          return Opacity(
            opacity: _pulseAnim.value,
            child: Transform.scale(
              scale: 0.8 + _pulseAnim.value * 0.2,
              child: const Icon(
                Icons.star,
                size: 22,
                color: Color(0xFFFFD54F),
                shadows: [Shadow(color: Color(0xFFFFD54F), blurRadius: 8)],
              ),
            ),
          );
        },
      );
    }

    // Neither done: dim placeholder
    return Icon(
      Icons.star_outline,
      size: 18,
      color: Colors.white.withAlpha(30),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd ~/Projects/brush-quest && flutter test test/widgets/sun_moon_tracker_test.dart -v`
Expected: PASS

- [ ] **Step 5: Run dart analyze**

Run: `cd ~/Projects/brush-quest && dart analyze lib/widgets/sun_moon_tracker.dart`
Expected: No issues.

- [ ] **Step 6: Commit**

```bash
cd ~/Projects/brush-quest
git add lib/widgets/sun_moon_tracker.dart test/widgets/sun_moon_tracker_test.dart
git commit -m "feat: add SunMoonTracker widget for daily pair bonus visibility"
```

---

## Task 5: Integrate SunMoonTracker into Home Screen

**Files:**
- Modify: `lib/screens/home_screen.dart`
- Test: `test/screens/home_screen_test.dart`

- [ ] **Step 1: Add slot state to HomeScreen**

In `_HomeScreenState` (around line 37), add:

```dart
bool _morningDone = false;
bool _eveningDone = false;
```

- [ ] **Step 2: Load slot state in _loadStats**

In `_loadStats()` (around line 125), add after existing loads:

```dart
final slots = await _streakService.getTodaySlots();
```

This call must go **before** the `setState(() { ... })` block (alongside the other `await` calls in `_loadStats`). Then assign the values **inside** the existing `setState` closure:

```dart
setState(() {
  // ... existing assignments ...
  _morningDone = slots.morningDone;
  _eveningDone = slots.eveningDone;
});
```

The method `getTodaySlots()` exists at `streak_service.dart:239` and returns `TodaySlotsStatus`.

- [ ] **Step 3: Add SunMoonTracker to the widget tree**

In the build method, add the tracker below the hero character and above the BRUSH button. Find the Column that contains the hero display (around line 762-905) and the brush button (around line 909-949). Between them, add:

```dart
const SizedBox(height: 12),
SunMoonTracker(
  morningDone: _morningDone,
  eveningDone: _eveningDone,
),
const SizedBox(height: 8),
```

- [ ] **Step 4: Add import**

At top of `home_screen.dart`:

```dart
import '../widgets/sun_moon_tracker.dart';
```

- [ ] **Step 5: Run tests**

Run: `cd ~/Projects/brush-quest && flutter test test/screens/home_screen_test.dart -v`
Expected: PASS (may need to add sun_moon_tracker mock initial values to SharedPreferences in test setup)

- [ ] **Step 6: Run dart analyze**

Run: `cd ~/Projects/brush-quest && dart analyze lib/screens/home_screen.dart`
Expected: No issues.

- [ ] **Step 7: Commit**

```bash
cd ~/Projects/brush-quest
git add lib/screens/home_screen.dart test/screens/home_screen_test.dart
git commit -m "feat: add sun-moon daily tracker to home screen below hero"
```

---

## Task 6: Generate Voice Lines

**Files:**
- Create: voice MP3 files in `assets/audio/voices/classic/`
- Modify: `lib/services/audio_service.dart` (add constants)
- Modify: `pubspec.yaml` (assets already covered by folder declaration)

This task generates the four new voice lines using ElevenLabs MCP and registers them in the audio service.

- [ ] **Step 1: Generate voice lines via ElevenLabs**

Use the ElevenLabs MCP text-to-speech tool to generate 4 voice files. Use the same voice as the existing "classic" narrator (Jessica — warm & clear). The voice lines:

1. **voice_full_charge.mp3**: "Full charge! Morning and night — bonus star!"
2. **voice_super_power.mp3**: "Whoa! Three days of brushing — your power is SUPER strong now!"
3. **voice_mega_power.mp3**: "MEGA POWER! You are UNSTOPPABLE!"
4. **voice_streak_bonus.mp3**: "Your streak is giving you extra stars!"

Save each to `~/Projects/brush-quest/assets/audio/voices/classic/`

**Fallback:** If ElevenLabs MCP is unavailable, create 1-second silent MP3 placeholder files and add a `// TODO: Replace with real voice lines` comment in audio_service.dart. The app will play silence but won't crash.

- [ ] **Step 2: Add voice line constants to AudioService**

In `lib/services/audio_service.dart`, add to the existing voice file constants section:

```dart
// Bonus communication voice lines
static const voiceFullCharge = 'voice_full_charge.mp3';
static const voiceSuperPower = 'voice_super_power.mp3';
static const voiceMegaPower = 'voice_mega_power.mp3';
static const voiceStreakBonus = 'voice_streak_bonus.mp3';
```

Add these to the `_allAudioFiles` list in audio_service.dart (used for preloading on startup). Insert them in the voice files section, near the other `voice_chest_*.mp3` entries:

```dart
'voice_full_charge.mp3',
'voice_super_power.mp3',
'voice_mega_power.mp3',
'voice_streak_bonus.mp3',
```

- [ ] **Step 3: Update victory screen to use constants**

In `victory_screen.dart`, replace the hardcoded string voice file references with `AudioService.voiceFullCharge`, etc.

- [ ] **Step 4: Run dart analyze**

Run: `cd ~/Projects/brush-quest && dart analyze lib/services/audio_service.dart lib/screens/victory_screen.dart`
Expected: No issues.

- [ ] **Step 5: Run all tests**

Run: `cd ~/Projects/brush-quest && flutter test`
Expected: All tests pass. Audio asset tests may need updating to include new files.

- [ ] **Step 6: Commit**

```bash
cd ~/Projects/brush-quest
git add assets/audio/voices/classic/voice_full_charge.mp3 \
  assets/audio/voices/classic/voice_super_power.mp3 \
  assets/audio/voices/classic/voice_mega_power.mp3 \
  assets/audio/voices/classic/voice_streak_bonus.mp3 \
  lib/services/audio_service.dart \
  lib/screens/victory_screen.dart
git commit -m "feat: add voice lines for daily pair and streak milestone celebrations"
```

---

## Task 7: Integration Testing and Polish

**Files:**
- All modified files
- Test: full test suite

- [ ] **Step 1: Run full test suite**

Run: `cd ~/Projects/brush-quest && flutter test`
Expected: All tests pass.

- [ ] **Step 2: Run dart analyze on entire project**

Run: `cd ~/Projects/brush-quest && dart analyze`
Expected: No issues.

- [ ] **Step 3: Verify the UX walkthrough as a 7-year-old**

Per CLAUDE.md pre-ship UX checklist, walk through the full flow:
1. Open app → home screen shows sun-moon tracker (both empty on fresh day)
2. Tap BRUSH → brushing session → victory screen shows star rain waves (base only for day 1)
3. Return home → sun slot is filled, bonus star pulses toward moon
4. Brush again (evening) → victory screen shows base wave + daily bonus wave with "FULL CHARGE!" voice
5. Day 3 → victory screen shows base + streak wave with "SUPER POWER!" voice
6. Day 7 → victory screen shows base + bigger streak wave (blue) with "MEGA POWER!" voice

- [ ] **Step 4: Commit any polish fixes**

```bash
cd ~/Projects/brush-quest
# Stage only files modified during polish (list specific files found during polish)
git add lib/screens/victory_screen.dart lib/screens/home_screen.dart lib/widgets/star_rain.dart lib/widgets/sun_moon_tracker.dart
git commit -m "chore: integration polish for bonus communication phase 1"
```

---

## Phase 2 Preview (Not in this plan)

After Phase 1 ships and we observe how kids react:
- **Streak flame evolution** — replace fire icon with living flame character that grows
- **Pre-brush power forecast** — interstitial showing bonuses about to be earned
- **Milestone full-screen celebrations** — 3-day and 7-day overlays with flame transformation
- **Audio escalation** — reward sounds get richer with streak length
- **Push notifications** — parent-facing reminders with flame character state
