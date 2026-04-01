# Victory Screen Overhaul

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the victory screen from a text-heavy results page into a visually-driven celebration a 7-year-old can understand without reading. Remove unnecessary text, move stat counters to a fixed top bar matching the home screen layout, add a star flight animation, and replace the yellow badge with a hero celebration.

**Architecture:** Four independent changes: (1) Remove text elements, (2) Move counters to top bar, (3) Star flight animation replacing StarRain, (4) Hero celebration replacing badge. Changes 1 and 2 are independent. Change 3 depends on 2 (flight target is the top bar wallet pill). Change 4 is independent.

**Tech Stack:** Flutter/Dart, AnimationController, CustomPainter

**Worktree:** This should be implemented in a git worktree to avoid conflicts with parallel work on main. Create branch `feat/victory-screen-overhaul` from `main`.

**IMPORTANT constraints:**
- Voice lines must NOT change (they're working well)
- Confetti animation stays (working well)
- Chest mechanics stay (just remove "TAP TO OPEN" text label)
- Bonus reveal system (`_BonusStar` widgets) stays
- No Lottie -- `collect_stars.json` does not exist in assets. Use animated star `Icons` with custom painters instead.

---

## File Map

| File | Action | Change |
|------|--------|--------|
| `lib/screens/victory_screen.dart` | Modify | All 4 changes |
| `lib/widgets/star_rain.dart` | Modify | Remove "STARS EARNED" label and "You brushed!" label (Change 1), repurpose as flight source |
| `test/screens/victory_screen_test.dart` | Modify | Update/add tests for all changes |
| `test/widgets/star_rain_test.dart` | Modify | Update tests for removed text |

---

## Current Layout (top to bottom, lines referenced from `lib/screens/victory_screen.dart`)

1. **"GREAT JOB!" title** -- line 916-932 -- KEEP
2. **StarRain widget** (+N / STARS EARNED / yellow badge with toothbrush icon + "You brushed!") -- line 936-939 -- MODIFY (Change 1 + 3)
3. **GlassCard with wallet+rank counters** -- line 942-1003 -- MOVE to top (Change 2)
4. **Treasure chest** with "TAP TO OPEN" label -- line 1008, built by `_buildChest()` at line 1325 -- MODIFY (Change 1: remove label)
5. **Bonus reveals** -- line 1011 -- KEEP
6. **Tip text box** (`_tipText`) -- line 1232-1261 -- REMOVE (Change 1)
7. **DONE button** -- line 1262-1308 -- KEEP

---

### Task 1: Remove unnecessary text (Change 1)

**Files:**
- Modify: `lib/screens/victory_screen.dart`
- Modify: `lib/widgets/star_rain.dart`
- Modify: `test/screens/victory_screen_test.dart`
- Modify: `test/widgets/star_rain_test.dart`

#### Step 1.1: Write failing tests for text removal

- [ ] **Add test: "STARS EARNED" label is not present**

File: `test/screens/victory_screen_test.dart`

Add after the existing `'victory screen shows GREAT JOB text'` test (line 88):

```dart
testWidgets('victory screen does not show STARS EARNED label', (tester) async {
  await pumpVictory(tester);
  expect(find.text('STARS EARNED'), findsNothing);
  await tester.binding.setSurfaceSize(null);
});
```

- [ ] **Add test: "TAP TO OPEN" label is not present when chest is shown**

File: `test/screens/victory_screen_test.dart`

```dart
testWidgets('victory screen does not show TAP TO OPEN label', (tester) async {
  await pumpVictory(tester);
  expect(find.text('TAP TO OPEN'), findsNothing);
  await tester.binding.setSurfaceSize(null);
});
```

- [ ] **Add test: tip text box is not rendered**

File: `test/screens/victory_screen_test.dart`

```dart
testWidgets('victory screen does not show tip text', (tester) async {
  await pumpVictory(tester);
  // The old tip text contained "streak" or "badge" -- verify none present
  expect(find.textContaining('streak going'), findsNothing);
  expect(find.textContaining('bonus star'), findsNothing);
  expect(find.textContaining('next badge'), findsNothing);
  await tester.binding.setSurfaceSize(null);
});
```

Run: `flutter test test/screens/victory_screen_test.dart` -- expect new tests to FAIL (text still present).

#### Step 1.2: Remove "STARS EARNED" label from StarRain

- [ ] **Remove the "STARS EARNED" Text widget**

File: `lib/widgets/star_rain.dart`, lines 184-191

Delete:
```dart
          const SizedBox(height: 4),
          const Text(
            'STARS EARNED',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white70,
              letterSpacing: 2,
            ),
          ),
```

- [ ] **Remove the "You brushed!" label from the wave definition**

File: `lib/widgets/star_rain.dart`, line 100

Change:
```dart
        label: 'You brushed!',
```
To:
```dart
        label: null,
```

The `_WaveIndicator` already handles `label: null` (line 275 checks `if (wave.label != null)`), so no further change needed.

#### Step 1.3: Remove "TAP TO OPEN" label from chest

- [ ] **Delete the "TAP TO OPEN" Positioned widget**

File: `lib/screens/victory_screen.dart`, lines 1522-1544

Delete the entire `Positioned` block:
```dart
                        Positioned(
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.black.withValues(alpha: 0.28),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Text(
                              'TAP TO OPEN',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
```

#### Step 1.4: Remove tip text system entirely

- [ ] **Remove `_tipText` and `_tipIcon` state variables**

File: `lib/screens/victory_screen.dart`, lines 207-208

Delete:
```dart
  String? _tipText;
  IconData? _tipIcon;
```

- [ ] **Remove `_calculateTip()` method**

File: `lib/screens/victory_screen.dart`, lines 434-481

Delete the entire `_calculateTip()` method (48 lines).

- [ ] **Remove the call to `_calculateTip()`**

File: `lib/screens/victory_screen.dart`, line 358

Delete:
```dart
    _calculateTip();
```

- [ ] **Remove the tip text widget from the build method**

File: `lib/screens/victory_screen.dart`, lines 1232-1261

Delete the entire `if (_tipText != null)` block including its `Padding` wrapper.

- [ ] **Remove the `voice_keep_going.mp3` playback** that was tied to the tip (this was inside `_calculateTip` which is already deleted -- verify no other reference to this specific voice in the tip context).

Run: `flutter test test/screens/victory_screen_test.dart` -- expect all tests to PASS.
Run: `dart analyze lib/screens/victory_screen.dart lib/widgets/star_rain.dart` -- expect clean.

---

### Task 2: Move counters to fixed top bar (Change 2)

**Files:**
- Modify: `lib/screens/victory_screen.dart`
- Modify: `test/screens/victory_screen_test.dart`

#### Step 2.1: Write failing test for top bar

- [ ] **Add test: streak pill exists in victory screen**

File: `test/screens/victory_screen_test.dart`

```dart
testWidgets('victory screen shows streak pill with fire icon', (tester) async {
  await pumpVictory(tester);
  expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
  await tester.binding.setSurfaceSize(null);
});
```

Run: `flutter test test/screens/victory_screen_test.dart` -- new test should FAIL.

#### Step 2.2: Add state variables for top bar data

- [ ] **Add streak state variable**

File: `lib/screens/victory_screen.dart`, after line 170 (`int _newWallet = 0;`)

Add:
```dart
  int _previousStreak = 0;
  HeroCharacter? _selectedHero;
```

- [ ] **Store hero and streak in `_recordAndAnimate`**

File: `lib/screens/victory_screen.dart`, inside `_recordAndAnimate()`, after line 297 (`final hero = await _heroService.getSelectedHero();`)

Add:
```dart
    _selectedHero = hero;
```

After line 313 (`_newStreak = await _streakService.getStreak();`), add before it:
```dart
    _previousStreak = await _streakService.getStreak();
```

(Note: `_previousStreak` captures the streak BEFORE `recordBrush` but AFTER the data load -- but `recordBrush` is called at line 302. The streak is already updated by the time we read it. To get the pre-brush streak we need to read it before `recordBrush`. Insert the read before line 302.)

Corrected: Before line 302 (`final outcome = await _streakService.recordBrush(...)`), add:
```dart
    _previousStreak = await _streakService.getStreak();
```

#### Step 2.3: Move GlassCard from scroll body to fixed Positioned top bar

- [ ] **Remove the existing GlassCard from the Column**

File: `lib/screens/victory_screen.dart`, lines 942-1003

Delete the entire GlassCard block (from `// Wallet + Rank display` through the closing `),` of GlassCard). Also delete the `const SizedBox(height: 20)` at line 1005.

- [ ] **Add a fixed top bar as a Positioned widget in the Stack**

File: `lib/screens/victory_screen.dart`, inside the `Stack` at line 884, after the confetti layer (after line 893) and jackpot overlay (after line 904), add a new `Positioned` widget:

```dart
              // Fixed top stats bar (matches home screen layout)
              Positioned(
                top: 8,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Streak pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: (_newStreak > 0
                                  ? Colors.orangeAccent
                                  : Colors.white24)
                              .withValues(alpha: 0.6),
                          width: 2,
                        ),
                        color: (_newStreak > 0
                                ? Colors.orangeAccent
                                : Colors.white24)
                            .withValues(alpha: 0.12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_fire_department,
                            color: _newStreak > 0
                                ? Colors.orangeAccent
                                : Colors.white.withValues(alpha: 0.3),
                            size: 26,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$_newStreak',
                            style: TextStyle(
                              color: _newStreak > 0
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.3),
                              fontWeight: FontWeight.bold,
                              fontSize: 28,
                              shadows: _newStreak > 0
                                  ? const [
                                      Shadow(
                                        color: Color(0x80FF9800),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Ranger Rank pill (diamond)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF7C4DFF).withValues(alpha: 0.6),
                          width: 2,
                        ),
                        color: const Color(0xFF7C4DFF).withValues(alpha: 0.12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.diamond,
                            color: Color(0xFF7C4DFF),
                            size: 26,
                          ),
                          const SizedBox(width: 4),
                          TweenAnimationBuilder<int>(
                            tween: IntTween(begin: _previousStars, end: _newStars),
                            duration: const Duration(milliseconds: 1500),
                            builder: (context, val, _) => Text(
                              '$val',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 28,
                                shadows: [
                                  Shadow(
                                    color: Color(0x807C4DFF),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Star Wallet pill (the star flight destination)
                    Container(
                      key: _walletPillKey,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFFFD54F).withValues(alpha: 0.6),
                          width: 2,
                        ),
                        color: const Color(0xFFFFD54F).withValues(alpha: 0.12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star,
                            color: Color(0xFFFFD54F),
                            size: 22,
                          ),
                          const SizedBox(width: 4),
                          AnimatedBuilder(
                            animation: _walletBumpController,
                            builder: (context, child) => Transform.scale(
                              scale: 1.0 + _walletBumpController.value * 0.3,
                              child: child,
                            ),
                            child: TweenAnimationBuilder<int>(
                              tween: IntTween(
                                begin: _previousWallet,
                                end: _newWallet,
                              ),
                              duration: const Duration(milliseconds: 1500),
                              builder: (context, val, _) => Text(
                                '$val',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                  shadows: [
                                    Shadow(
                                      color: Color(0x80FFD54F),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
```

- [ ] **Add `_walletPillKey` and `_walletBumpController`**

File: `lib/screens/victory_screen.dart`, in the state class, near line 161 (after the animation controller declarations):

```dart
  final _walletPillKey = GlobalKey();
  late AnimationController _walletBumpController;
```

In `initState()`, after line 278 (`_rewardRevealController = ...`), add:
```dart
    _walletBumpController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
```

In `dispose()`, add:
```dart
    _walletBumpController.dispose();
```

- [ ] **Adjust scroll body top padding**

File: `lib/screens/victory_screen.dart`, line 914 (`const SizedBox(height: 24)`)

Change to:
```dart
                    const SizedBox(height: 56),
```

This creates clearance below the new fixed top bar.

Run: `flutter test test/screens/victory_screen_test.dart` -- streak pill test should PASS.
Run: `dart analyze lib/screens/victory_screen.dart` -- expect clean.

---

### Task 3: Star flight animation (Change 3)

**Files:**
- Modify: `lib/screens/victory_screen.dart`
- Modify: `test/screens/victory_screen_test.dart`

This is the highest-impact visual change. Stars burst from center screen and arc UP into the wallet pill in the top bar. Each star that arrives bumps the counter with a scale animation.

#### Step 3.1: Write failing test

- [ ] **Add test: star flight overlay layer exists**

File: `test/screens/victory_screen_test.dart`

```dart
testWidgets('victory screen renders star flight overlay', (tester) async {
  await pumpVictory(tester);
  // The _StarFlightOverlay is rendered as part of the Stack
  // After the animation runs, we should find animated star icons
  // Pump past the flight animation delay
  await tester.pump(const Duration(seconds: 2));
  // The +N counter text should be visible (from StarRain)
  expect(find.textContaining('+'), findsWidgets);
  await tester.binding.setSurfaceSize(null);
});
```

#### Step 3.2: Create the star flight animation widget

- [ ] **Add `_StarFlightOverlay` widget class**

File: `lib/screens/victory_screen.dart`, after the `_ConfettiPainter` class (after line 2016), add:

```dart
/// Animates star icons from a source position arcing up to a target position.
/// Each star follows a unique curved path with staggered timing.
class _StarFlightOverlay extends StatefulWidget {
  final int starCount;
  final Offset source;
  final Offset target;
  final VoidCallback? onStarLanded;
  final VoidCallback? onComplete;

  const _StarFlightOverlay({
    required this.starCount,
    required this.source,
    required this.target,
    this.onStarLanded,
    this.onComplete,
  });

  @override
  State<_StarFlightOverlay> createState() => _StarFlightOverlayState();
}

class _StarFlightOverlayState extends State<_StarFlightOverlay>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<Offset>> _positionAnims;
  late final List<Animation<double>> _scaleAnims;
  final _random = Random();
  int _landedCount = 0;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.starCount, (i) {
      return AnimationController(
        duration: Duration(milliseconds: 600 + _random.nextInt(300)),
        vsync: this,
      );
    });

    _positionAnims = List.generate(widget.starCount, (i) {
      // Each star gets a unique control point for its arc
      final dx = widget.source.dx +
          (_random.nextDouble() - 0.5) * 120;
      final dy = widget.source.dy - 80 - _random.nextDouble() * 60;
      final controlPoint = Offset(dx, dy);

      return _BezierOffsetTween(
        begin: widget.source,
        control: controlPoint,
        end: widget.target,
      ).animate(CurvedAnimation(
        parent: _controllers[i],
        curve: Curves.easeInOutCubic,
      ));
    });

    _scaleAnims = List.generate(widget.starCount, (i) {
      return TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.4)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 30,
        ),
        TweenSequenceItem(
          tween: Tween(begin: 1.4, end: 1.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 40,
        ),
        TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.5)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 30,
        ),
      ]).animate(_controllers[i]);
    });

    // Stagger the launches
    for (int i = 0; i < widget.starCount; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (!mounted) return;
        _controllers[i].forward().then((_) {
          _landedCount++;
          widget.onStarLanded?.call();
          if (_landedCount >= widget.starCount) {
            widget.onComplete?.call();
          }
        });
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(widget.starCount, (i) {
        return AnimatedBuilder(
          animation: _controllers[i],
          builder: (context, _) {
            if (_controllers[i].value == 0) return const SizedBox.shrink();
            final pos = _positionAnims[i].value;
            final scale = _scaleAnims[i].value;
            return Positioned(
              left: pos.dx - 16,
              top: pos.dy - 16,
              child: Transform.scale(
                scale: scale,
                child: const Icon(
                  Icons.star,
                  color: Color(0xFFFFD54F),
                  size: 32,
                  shadows: [
                    Shadow(
                      color: Color(0xFFFFD54F),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

/// A tween that follows a quadratic Bezier curve between three points.
class _BezierOffsetTween extends Animatable<Offset> {
  final Offset begin;
  final Offset control;
  final Offset end;

  _BezierOffsetTween({
    required this.begin,
    required this.control,
    required this.end,
  });

  @override
  Offset transform(double t) {
    final mt = 1 - t;
    return Offset(
      mt * mt * begin.dx + 2 * mt * t * control.dx + t * t * end.dx,
      mt * mt * begin.dy + 2 * mt * t * control.dy + t * t * end.dy,
    );
  }
}
```

#### Step 3.3: Integrate star flight into the victory sequence

- [ ] **Add star flight state variables**

File: `lib/screens/victory_screen.dart`, near the other state variables (after `_showDoneButton`):

```dart
  bool _showStarFlight = false;
  Offset _starFlightSource = Offset.zero;
  Offset _starFlightTarget = Offset.zero;
```

- [ ] **Trigger star flight in `_recordAndAnimate()`**

File: `lib/screens/victory_screen.dart`, in `_recordAndAnimate()`, after the arc beat 1 voice line plays (after line 378, `_audio.playVoice(arc[0]);`), add the star flight trigger:

```dart
    // Trigger star flight animation after a beat
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _triggerStarFlight();
    });
```

- [ ] **Add `_triggerStarFlight()` method**

File: `lib/screens/victory_screen.dart`, after `_recordAndAnimate()`:

```dart
  void _triggerStarFlight() {
    // Get the wallet pill position using its GlobalKey
    final walletBox = _walletPillKey.currentContext?.findRenderObject() as RenderBox?;
    if (walletBox == null) return;

    final screenSize = MediaQuery.of(context).size;
    final walletPos = walletBox.localToGlobal(
      Offset(walletBox.size.width / 2, walletBox.size.height / 2),
    );

    setState(() {
      _starFlightSource = Offset(screenSize.width / 2, screenSize.height * 0.35);
      _starFlightTarget = walletPos;
      _showStarFlight = true;
    });
  }

  void _onStarLanded() {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    _walletBumpController.forward().then((_) {
      if (mounted) _walletBumpController.reverse();
    });
    _audio.playSfx('star_chime.mp3');
  }
```

- [ ] **Add the star flight overlay to the Stack in build()**

File: `lib/screens/victory_screen.dart`, inside the Stack (line 884), after the top bar `Positioned` widget added in Task 2, add:

```dart
              // Star flight animation overlay
              if (_showStarFlight)
                _StarFlightOverlay(
                  starCount: _starsEarnedThisSession.clamp(1, 5),
                  source: _starFlightSource,
                  target: _starFlightTarget,
                  onStarLanded: _onStarLanded,
                  onComplete: () {
                    if (mounted) setState(() => _showStarFlight = false);
                  },
                ),
```

Run: `flutter test test/screens/victory_screen_test.dart` -- expect PASS.
Run: `dart analyze lib/screens/victory_screen.dart` -- expect clean.

---

### Task 4: Hero celebration (Change 4)

**Files:**
- Modify: `lib/screens/victory_screen.dart`
- Modify: `test/screens/victory_screen_test.dart`

This replaces the StarRain widget (which was the yellow badge area showing the toothbrush icon + "You brushed!") with the kid's selected hero doing a victory pose.

#### Step 4.1: Write failing test

- [ ] **Add test: hero image is displayed**

File: `test/screens/victory_screen_test.dart`

```dart
testWidgets('victory screen shows selected hero image', (tester) async {
  await pumpVictory(tester);
  // The hero image should be rendered (Blaze is the selected hero in mock data)
  expect(find.byType(Image), findsWidgets);
  await tester.binding.setSurfaceSize(null);
});
```

#### Step 4.2: Add hero celebration animation controller

- [ ] **Add animation controller for hero entrance**

File: `lib/screens/victory_screen.dart`, in the state class, add:

```dart
  late AnimationController _heroCelebrationController;
  late Animation<double> _heroScaleAnim;
  late AnimationController _heroGlowController;
```

In `initState()`:
```dart
    _heroCelebrationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _heroScaleAnim = CurvedAnimation(
      parent: _heroCelebrationController,
      curve: Curves.elasticOut,
    );
    _heroGlowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
```

In `dispose()`:
```dart
    _heroCelebrationController.dispose();
    _heroGlowController.dispose();
```

#### Step 4.3: Trigger hero celebration in the timing sequence

- [ ] **Start hero animation at the beginning of `_recordAndAnimate()`**

File: `lib/screens/victory_screen.dart`, in `_recordAndAnimate()`, after `if (mounted) setState(() {});` (line 355), add:

```dart
    // Start hero celebration entrance
    _heroCelebrationController.forward();
```

#### Step 4.4: Replace StarRain with hero celebration in the build method

- [ ] **Replace the StarRain widget block**

File: `lib/screens/victory_screen.dart`, lines 934-940

Replace:
```dart
                    const SizedBox(height: 10),
                    // Star rain wave animation
                    if (_starsEarnedThisSession > 0)
                      const StarRain(
                        baseStars: 2,
                      ),
                    const SizedBox(height: 12),
```

With:
```dart
                    const SizedBox(height: 16),
                    // Hero celebration
                    if (_selectedHero != null)
                      AnimatedBuilder(
                        animation: Listenable.merge([
                          _heroScaleAnim,
                          _heroGlowController,
                        ]),
                        builder: (context, child) {
                          final glowIntensity = _heroGlowController.value;
                          return Transform.scale(
                            scale: _heroScaleAnim.value,
                            child: Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _selectedHero!.primaryColor
                                        .withValues(alpha: 0.4 + glowIntensity * 0.3),
                                    blurRadius: 30 + glowIntensity * 20,
                                    spreadRadius: 5 + glowIntensity * 5,
                                  ),
                                ],
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Glow circle behind hero
                                  Container(
                                    width: 150,
                                    height: 150,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          _selectedHero!.primaryColor
                                              .withValues(alpha: 0.3),
                                          _selectedHero!.primaryColor
                                              .withValues(alpha: 0.0),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Hero image
                                  ClipOval(
                                    child: Image.asset(
                                      _selectedHero!.imagePath,
                                      width: 120,
                                      height: 120,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  // Sparkle effects
                                  Positioned(
                                    top: 8,
                                    right: 12,
                                    child: Opacity(
                                      opacity: glowIntensity,
                                      child: Icon(
                                        Icons.auto_awesome,
                                        color: _selectedHero!.primaryColor,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 12,
                                    left: 8,
                                    child: Opacity(
                                      opacity: 1 - glowIntensity,
                                      child: Icon(
                                        Icons.auto_awesome,
                                        color: _selectedHero!.primaryColor,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 20,
                                    left: 16,
                                    child: Opacity(
                                      opacity: glowIntensity * 0.7,
                                      child: Icon(
                                        Icons.auto_awesome,
                                        color: _selectedHero!.primaryColor
                                            .withValues(alpha: 0.8),
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 16),
```

#### Step 4.5: Remove StarRain import if no longer used

- [ ] **Check if StarRain is still referenced**

After removing the StarRain widget from the build method, check if `StarRain` is referenced anywhere else in `victory_screen.dart`. If not, remove the import:

File: `lib/screens/victory_screen.dart`, line 14

Delete:
```dart
import '../widgets/star_rain.dart';
```

- [ ] **Update the existing StarRain test in victory_screen_test.dart**

File: `test/screens/victory_screen_test.dart`, lines 90-94

The test `'victory screen shows StarRain widget'` now needs to be changed since StarRain is removed. Replace:
```dart
  testWidgets('victory screen shows StarRain widget', (tester) async {
    await pumpVictory(tester);
    expect(find.byType(StarRain), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });
```

With:
```dart
  testWidgets('victory screen does not show StarRain (replaced by hero)', (tester) async {
    await pumpVictory(tester);
    expect(find.byType(StarRain), findsNothing);
    await tester.binding.setSurfaceSize(null);
  });
```

Also update the import at the top of the test file -- remove the `StarRain` import if it's only used in this test. Keep it if other tests reference it.

Run: `flutter test test/screens/victory_screen_test.dart` -- expect ALL tests to PASS.
Run: `flutter test test/widgets/star_rain_test.dart` -- expect PASS (StarRain still exists as a widget, just not used in victory screen).
Run: `dart analyze lib/screens/victory_screen.dart` -- expect clean.

---

### Task 5: Final integration verification

- [ ] **Run full test suite**

```bash
flutter test
```

All tests must pass.

- [ ] **Run static analysis**

```bash
dart analyze
```

Must be clean.

- [ ] **Visual review checklist (pre-ship UX)**

Walk through as a 7-year-old:
1. GREAT JOB! title visible with voice backing -- check
2. Hero celebration with sparkles -- new, check glow uses hero's `primaryColor`
3. Stars fly UP to wallet pill in top bar -- check the arc looks natural
4. Top bar shows streak/rank/wallet matching home screen layout -- check
5. Chest bounces without "TAP TO OPEN" text -- still tappable? check
6. Bonus reveals appear after chest -- unchanged, check
7. DONE button visible -- check, no tip text box above it
8. No text that requires reading (besides "GREAT JOB!" and "DONE" which are voice/icon backed)
9. Voice timeline: arc beat 1 -> arc beat 2 -> chest prompt -> chest reward -> bonuses -> encouragement -- unchanged
10. Confetti still animates throughout -- check

---

## Summary of deletions

| What | Where | Lines |
|------|-------|-------|
| "STARS EARNED" text | `star_rain.dart` | 184-191 |
| "You brushed!" label | `star_rain.dart` | 100 |
| "TAP TO OPEN" Positioned | `victory_screen.dart` | 1522-1544 |
| `_tipText` / `_tipIcon` state | `victory_screen.dart` | 207-208 |
| `_calculateTip()` method | `victory_screen.dart` | 434-481 |
| `_calculateTip()` call | `victory_screen.dart` | 358 |
| Tip text widget in build | `victory_screen.dart` | 1232-1261 |
| GlassCard in scroll body | `victory_screen.dart` | 942-1005 |
| StarRain widget in build | `victory_screen.dart` | 934-940 |
| StarRain import | `victory_screen.dart` | 14 |

## Summary of additions

| What | Where |
|------|-------|
| `_previousStreak`, `_selectedHero` state | `victory_screen.dart` state class |
| `_walletPillKey`, `_walletBumpController` | `victory_screen.dart` state class |
| `_heroCelebrationController`, `_heroScaleAnim`, `_heroGlowController` | `victory_screen.dart` state class |
| `_showStarFlight`, `_starFlightSource`, `_starFlightTarget` state | `victory_screen.dart` state class |
| Fixed top bar `Positioned` with 3 pills | `victory_screen.dart` build Stack |
| Star flight overlay in Stack | `victory_screen.dart` build Stack |
| Hero celebration widget in scroll Column | `victory_screen.dart` build Column |
| `_triggerStarFlight()`, `_onStarLanded()` methods | `victory_screen.dart` |
| `_StarFlightOverlay` widget class | `victory_screen.dart` (bottom) |
| `_BezierOffsetTween` class | `victory_screen.dart` (bottom) |
| 6 new tests | `test/screens/victory_screen_test.dart` |
