# Brush Steps on the Real Pages Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The pre-brush Hero → Weapon → World steps become the real Heroes & Weapons page (HEROES tab, then WEAPONS tab) and the real Map page, each in a "brush mode" with an X, a big GO button, a gold glow on the closest next unlock, and an 8-second idle advance.

**Architecture:** `PreBrushScreen` stays the coordinator (steps, entry lines, GO, idle count, dialogs, lifecycle, launch into brushing). It hosts one `HeroShopScreen` in brush mode for the HEROES and WEAPONS steps and a `WorldMapScreen` in brush mode for the Map step, with GO as its Scaffold's floating button. A small `BrushMode` object (new, `lib/screens/brush_mode.dart`) is the whole contract between them; a page given no `BrushMode` behaves exactly as today.

**Tech Stack:** Flutter 3.41.4 / Dart 3, very_good_analysis 7 lints, flutter_test widget tests with `FakeAudioService` and `TimedFakeAudioService`, SharedPreferences mocks.

**Spec:** `docs/superpowers/specs/2026-10-13-brush-steps-on-real-pages-design.md` (approved by Jim 2026-10-14). It amends `docs/superpowers/specs/2026-10-05-brush-flow-and-hooks-design.md`; read both §-references there when a task cites them.

## Global Constraints

- R6: `HeroShopScreen()` and `WorldMapScreen()` built without `brushMode` look and sound exactly as today: same voices, music, analytics, paddings and layout. The only permitted change on that path is adding `ValueKey`s to cells/cards/planets and a `Timer?` in place of a `Future.delayed` with the same 300 ms timing.
- No new voice lines or art. Lines used: `AudioService.evolutionPickerVoiceFor`, `weaponPickerVoiceFor`, `'voice_world_<id>.mp3'`, `brushesLeftVoiceFor`, `starsLeftVoiceFor`, `'voice_tap_to_unlock.mp3'`, `'voice_have_them_all.mp3'`, `'voice_lets_fight.mp3'`. In the steps, "Tap to unlock it!" replaces "Brush to unlock it!" (`voice_ready_to_unlock.mp3` is never played by the steps).
- Timings: idle advance **8 s** (`PreBrushScreen.idleAdvance`); voice-wait cap **12 s** (`PreBrushScreen.maxVoiceWait`, see Ruling R-1 below); launch delay **400 ms**; max wait for "Let's fight!" **3 s**; load timeout **3 s**; page slide **400 ms**.
- GO button: 200 × 76 px, radius 24, gradient `[Color(0xFF7C4DFF), Color(0xFF9C27B0)]`, shadow `Color(0xFF7C4DFF)` α 0.4 blur 16 spread 2, pulse 1200 ms repeat-reverse scale 1.0 → 1.04, label `'GO!'` (30 px bold, letterSpacing 4) + `Icons.arrow_forward` (HEROES/WEAPONS) or `Icons.rocket_launch` (Map), 32 px. GO plays `'whoosh.mp3'` and a medium haptic.
- Glow: gold `Color(0xFFFFD54F)`, 3 px ring over the item's edge plus a pulsing shadow (α 0.25 → 0.60, blur 10 → 20, spread 1 → 3), 1200 ms repeat-reverse. Radius 12 on hero cells, 20 on weapon cards, a circle on planets.
- X button: the Map's back-button style: 56 × 56, radius 18, fill white α 0.08, border white α 0.18 width 1.5, `Icons.close` white 30 px. Its `InkWell` has key `ValueKey('brush_close')`.
- `kBrushGoClearance = 112` px of extra bottom padding on each page in brush mode.
- Analytics (Android only, via `AnalyticsService`): `pre_brush_change {category}` when the equipped hero/stage, weapon or world changes during the steps; `goal_unlocked {category, item, source: 'pre_brush'}` for every unlock during the steps; no `shop_visit` from the steps.
- Every delay in new code is a `Timer?` field cancelled in `dispose()`; no `Future.delayed` in new code. No new dialogs.
- Prices and earning are locked: never touch `price:` values or star rules.
- `dart format lib test` before every commit; `dart analyze` must say "No issues found!"; `flutter test` must pass. very_good_analysis rules that bite most: `sort_child_properties_last`, `prefer_const_constructors`, `unawaited_futures` (wrap with `unawaited(...)` from `dart:async`), `comment_references` (only `[name]`s that resolve), `unnecessary_lambdas`, `cast_nullable_to_non_nullable`, `use_build_context_synchronously`.
- The repo is public: never `git add` anything under `.remember/`. Stage files by name, never `git add -A`.
- Every commit message ends with these two lines:
  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01STWCtX8pE4SLhUiiBxVG9M
  ```
- Shared test setup (Firebase mocks, audioplayers channels, `AudioService.testInstance`) follows the existing files `test/screens/hero_shop_screen_test.dart` and `test/screens/pre_brush_screen_test.dart`.

**Ruling R-1 (controller, for Jim's plan review):** the spec says "a 6 s cap on waiting for the voice". Measured lines: Sugar Volcano's world line is 6.7 s plus "N more brushes" 1.1 s; Blaze's picker line is 6.0 s plus its progress line; unlock intro lines run 7.4–8.8 s. A 6 s cap would routinely start the 8 s count before those lines end, against the spec's main rule ("the count starts once the voice pipeline is idle"). The cap exists only for a voice that never ends, so it is **12 s**. If wrong, it is one constant.

**Ruling R-2:** after "Let's fight!" the whole page ignores touches, the X included (as the old steps ignored the carousel). System back still goes Home. A tap on a planet then would change the world brushing was already told about, and an unlock dialog then would block the launch.

## Review Focus

1. Leaving a page must not stop the next voice: the shop sliding away must not cut the Map's world line, and the Map fading away must not cut brushing's "3, 2, 1". Pinned by Task 2 "leaving the page leaves the voice to the steps", Task 3 "leaving the Map leaves the voice to brushing" and Task 4 "the pages never stop the voice while the steps run".
2. A dialog still open when the app comes back from the background: the count keeps waiting for the dialog. Pinned by Task 4 "back from the background with a dialog still open".
3. A touch that ends in a cancel (system gesture, app switch) must not hold the step forever. Pinned by Task 4 "a cancelled touch lets the count run again".
4. A scroll whose end never comes (its page is gone mid-fling) must not hold the step forever. Pinned by Task 4 "a scroll that never sends its end does not hold the step".
5. A saved hero or weapon id the game doesn't know (old or corrupted save) still gives a line and a page, not a crash. Pinned by Task 4 "a saved hero or weapon the game does not know".

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `lib/screens/brush_mode.dart` | Create | The contract: `BrushMode`, `BrushChange`, `BrushPing`, `BrushCloseButton`, `kBrushGoClearance`, `revealIfHidden()` |
| `lib/widgets/go_button.dart` | Create | `GoButton` |
| `lib/widgets/goal_glow.dart` | Create | `GoalGlow`, the pulsing gold ring |
| `lib/services/analytics_service.dart` | Modify | `logGoalUnlocked` gains `source` (default `'victory'`) |
| `lib/screens/hero_shop_screen.dart` | Modify | Optional `brushMode`; X, tab following/reporting, glow, reveal, padding, change reports; no entry/tab voice, music or shop_visit in brush mode |
| `lib/screens/world_map_screen.dart` | Modify | Optional `brushMode`; X, glow, reveal, padding, change report; no intro/world voice or music in brush mode |
| `lib/screens/pre_brush_screen.dart` | Rewrite | The coordinator on the real pages |
| `lib/widgets/loadout_carousel.dart` | Delete | Only the old steps used it |
| `test/widgets/brush_mode_widgets_test.dart` | Create | Task 1 tests |
| `test/services/analytics_service_test.dart` | Modify | `source` parameter test |
| `test/screens/hero_shop_brush_mode_test.dart` | Create | Task 2 tests (brush mode + R6 pins) |
| `test/screens/world_map_brush_mode_test.dart` | Create | Task 3 tests (brush mode + R6 pins) |
| `test/screens/pre_brush_screen_test.dart` | Rewrite | Task 4 tests |
| `test/screens/home_screen_test.dart`, `test/screens/home_flame_test.dart` | Modify | New idle knob name |
| `test/widgets/brush_flow_widgets_test.dart` | Modify | Drop the carousel tests |
| `CLAUDE.md`, `STATUS.md` | Modify | Game-flow description |

---

### Task 1: Brush-mode building blocks

**Files:**
- Create: `lib/screens/brush_mode.dart`
- Create: `lib/widgets/go_button.dart`
- Create: `lib/widgets/goal_glow.dart`
- Modify: `lib/services/analytics_service.dart` (method `logGoalUnlocked`, near line 199)
- Create: `test/widgets/brush_mode_widgets_test.dart`
- Modify: `test/services/analytics_service_test.dart`

**Interfaces:**
- Consumes: `GoalCategory` from `lib/services/goal_service.dart` (`enum GoalCategory { hero, weapon, world }`).
- Produces (later tasks rely on these exact names):
  - `class BrushMode { const BrushMode({required VoidCallback onClose, required ValueListenable<int> tab, required ValueChanged<int> onTabChanged, required ValueListenable<String?> highlightId, required Listenable reveal, required ValueChanged<BrushChange> onChanged}); }` with final fields of the same names.
  - `class BrushChange { const BrushChange.selected(GoalCategory category); const BrushChange.unlocked(GoalCategory category, String unlockedId); final GoalCategory category; final String? unlockedId; }` with value equality.
  - `class BrushPing extends ChangeNotifier { void ping(); }`
  - `const double kBrushGoClearance = 112;`
  - `Future<void> revealIfHidden(BuildContext context, {double bottomInset = kBrushGoClearance})`
  - `class BrushCloseButton extends StatelessWidget { const BrushCloseButton({super.key, required VoidCallback onTap}); }` (its `InkWell` keyed `ValueKey('brush_close')`)
  - `class GoButton extends StatefulWidget { const GoButton({super.key, required VoidCallback? onPressed, bool rocket = false}); }`
  - `class GoalGlow extends StatefulWidget { const GoalGlow({super.key, required Widget child, double borderRadius = 12, bool circle = false}); static const color = Color(0xFFFFD54F); }`
  - `AnalyticsService.logGoalUnlocked({required String category, required String item, String source = 'victory'})`

- [ ] **Step 1: Write the failing widget tests**

Create `test/widgets/brush_mode_widgets_test.dart`:

```dart
// test/widgets/brush_mode_widgets_test.dart
import 'dart:async';

import 'package:brush_quest/screens/brush_mode.dart';
import 'package:brush_quest/services/goal_service.dart';
import 'package:brush_quest/widgets/go_button.dart';
import 'package:brush_quest/widgets/goal_glow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

/// The Container GoalGlow paints with: its glow behind, its ring in front.
Finder _glowBox() => find
    .descendant(of: find.byType(GoalGlow), matching: find.byType(Container))
    .first;

void main() {
  group('GoButton', () {
    testWidgets('says GO! with an arrow, or with a rocket on the Map', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(GoButton(onPressed: () {})));
      expect(find.text('GO!'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
      expect(find.byIcon(Icons.rocket_launch), findsNothing);
      await tester.pumpWidget(_wrap(GoButton(onPressed: () {}, rocket: true)));
      expect(find.text('GO!'), findsOneWidget);
      expect(find.byIcon(Icons.rocket_launch), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsNothing);
    });

    testWidgets('is 200 x 76', (tester) async {
      await tester.pumpWidget(_wrap(GoButton(onPressed: () {})));
      expect(tester.getSize(find.byType(GoButton)), const Size(200, 76));
    });

    testWidgets('a tap presses it; without onPressed it does nothing', (
      tester,
    ) async {
      var presses = 0;
      await tester.pumpWidget(_wrap(GoButton(onPressed: () => presses++)));
      await tester.tap(find.byType(GoButton));
      expect(presses, 1);
      await tester.pumpWidget(_wrap(const GoButton(onPressed: null)));
      await tester.tap(find.byType(GoButton));
      expect(presses, 1);
    });

    testWidgets('pulses gently while it can be pressed', (tester) async {
      await tester.pumpWidget(_wrap(GoButton(onPressed: () {})));
      double scale() => tester
          .widget<Transform>(
            find
                .descendant(
                  of: find.byType(GoButton),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform
          .getMaxScaleOnAxis();
      expect(scale(), closeTo(1.0, 1e-6));
      await tester.pump(const Duration(milliseconds: 600));
      expect(scale(), greaterThan(1.0));
      expect(scale(), lessThanOrEqualTo(1.04 + 1e-6));
    });

    testWidgets('is still while it cannot be pressed', (tester) async {
      await tester.pumpWidget(_wrap(const GoButton(onPressed: null)));
      await tester.pumpAndSettle(); // nothing keeps animating
      final transform = tester.widget<Transform>(
        find
            .descendant(
              of: find.byType(GoButton),
              matching: find.byType(Transform),
            )
            .first,
      );
      expect(transform.transform.getMaxScaleOnAxis(), closeTo(1.0, 1e-6));
    });
  });

  group('GoalGlow', () {
    testWidgets('rings its child in gold without changing its size', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const GoalGlow(child: SizedBox(width: 100, height: 80))),
      );
      expect(tester.getSize(find.byType(GoalGlow)), const Size(100, 80));
      final box = tester.widget<Container>(_glowBox());
      final ring = box.foregroundDecoration! as BoxDecoration;
      final edge = (ring.border! as Border).top;
      expect(edge.width, 3);
      expect(edge.color.withValues(alpha: 1), GoalGlow.color);
      expect(ring.shape, BoxShape.rectangle);
      expect(ring.borderRadius, BorderRadius.circular(12));
    });

    testWidgets('a round ring for planets', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const GoalGlow(circle: true, child: SizedBox(width: 100, height: 100)),
        ),
      );
      final box = tester.widget<Container>(_glowBox());
      final ring = box.foregroundDecoration! as BoxDecoration;
      expect(ring.shape, BoxShape.circle);
      expect(ring.borderRadius, isNull);
    });

    testWidgets('its glow pulses', (tester) async {
      await tester.pumpWidget(
        _wrap(const GoalGlow(child: SizedBox(width: 50, height: 50))),
      );
      double blur() {
        final glow = tester.widget<Container>(_glowBox()).decoration!;
        return (glow as BoxDecoration).boxShadow!.single.blurRadius;
      }

      final start = blur();
      await tester.pump(const Duration(milliseconds: 600));
      expect(blur(), greaterThan(start));
    });
  });

  testWidgets('BrushCloseButton is a 56 px X that calls onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_wrap(BrushCloseButton(onTap: () => taps++)));
    expect(
      tester.getSize(find.byKey(const ValueKey('brush_close'))),
      const Size(56, 56),
    );
    expect(find.byIcon(Icons.close), findsOneWidget);
    await tester.tap(find.byType(BrushCloseButton));
    expect(taps, 1);
  });

  test('BrushChange is a selection or an unlock', () {
    const pick = BrushChange.selected(GoalCategory.weapon);
    const buy = BrushChange.unlocked(GoalCategory.hero, 'frost');
    expect(pick.category, GoalCategory.weapon);
    expect(pick.unlockedId, isNull);
    expect(buy.unlockedId, 'frost');
    expect(buy, const BrushChange.unlocked(GoalCategory.hero, 'frost'));
    expect(buy, isNot(pick));
    expect(buy.hashCode, const BrushChange.unlocked(GoalCategory.hero, 'frost').hashCode);
  });

  test('BrushPing tells its listeners once per ping', () {
    final ping = BrushPing();
    var heard = 0;
    ping
      ..addListener(() => heard++)
      ..ping()
      ..ping();
    expect(heard, 2);
    ping.dispose();
  });

  group('revealIfHidden', () {
    /// Twenty 100 px rows in a 600 px list (the test surface is 800 x 600),
    /// every row built, [key] on row [target].
    Future<ScrollPosition> pumpList(
      WidgetTester tester,
      GlobalKey key,
      int target,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              cacheExtent: 3000,
              children: [
                for (var i = 0; i < 20; i++)
                  SizedBox(
                    key: i == target ? key : null,
                    height: 100,
                    child: Text('row $i'),
                  ),
              ],
            ),
          ),
        ),
      );
      return tester.state<ScrollableState>(find.byType(Scrollable)).position;
    }

    testWidgets('scrolls a row below the screen into view, above GO', (
      tester,
    ) async {
      final key = GlobalKey();
      final position = await pumpList(tester, key, 12);
      unawaited(revealIfHidden(key.currentContext!));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      final row = tester.getRect(find.byKey(key));
      final view = tester.getRect(find.byType(ListView));
      expect(position.pixels, greaterThan(0));
      expect(row.top, greaterThanOrEqualTo(view.top));
      expect(row.bottom, lessThanOrEqualTo(view.bottom - kBrushGoClearance));
    });

    testWidgets('a row behind the GO zone counts as hidden', (tester) async {
      final key = GlobalKey();
      final position = await pumpList(tester, key, 5); // 500..600 of 600
      unawaited(revealIfHidden(key.currentContext!));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(position.pixels, greaterThan(0));
      final view = tester.getRect(find.byType(ListView));
      expect(
        tester.getRect(find.byKey(key)).bottom,
        lessThanOrEqualTo(view.bottom - kBrushGoClearance),
      );
    });

    testWidgets('leaves a row that is fully visible alone', (tester) async {
      final key = GlobalKey();
      final position = await pumpList(tester, key, 1);
      unawaited(revealIfHidden(key.currentContext!));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(position.pixels, 0);
    });

    testWidgets('moves only the nearest scroll view, not the pages around it', (
      tester,
    ) async {
      final key = GlobalKey();
      final pages = PageController();
      addTearDown(pages.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PageView(
              controller: pages,
              children: [
                ListView(
                  cacheExtent: 3000,
                  children: [
                    for (var i = 0; i < 20; i++)
                      SizedBox(
                        key: i == 12 ? key : null,
                        height: 100,
                        child: Text('row $i'),
                      ),
                  ],
                ),
                const SizedBox.expand(),
              ],
            ),
          ),
        ),
      );
      unawaited(revealIfHidden(key.currentContext!));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(pages.page, 0);
      expect(
        tester.getRect(find.byKey(key)).bottom,
        lessThanOrEqualTo(600 - kBrushGoClearance),
      );
    });
  });
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `flutter test test/widgets/brush_mode_widgets_test.dart`
Expected: FAIL to compile — `brush_mode.dart`, `go_button.dart` and `goal_glow.dart` don't exist.

- [ ] **Step 3: Create `lib/screens/brush_mode.dart`**

```dart
// lib/screens/brush_mode.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/goal_service.dart';

/// What the Heroes & Weapons page and the Map need to run as a step of the
/// brush flow (spec
/// docs/superpowers/specs/2026-10-13-brush-steps-on-real-pages-design.md
/// §5). A page built without one behaves exactly as when it is opened from
/// Home. A page keeps the same instance for its whole life.
@immutable
class BrushMode {
  const BrushMode({
    required this.onClose,
    required this.tab,
    required this.onTabChanged,
    required this.highlightId,
    required this.reveal,
    required this.onChanged,
  });

  /// The X: back to Home.
  final VoidCallback onClose;

  /// The Heroes & Weapons tab to show (0 heroes, 1 weapons). The page
  /// follows it; the Map ignores it.
  final ValueListenable<int> tab;

  /// He tapped or swiped to the other tab.
  final ValueChanged<int> onTabChanged;

  /// What glows as the closest next unlock: an evolution-cell id
  /// ('frost_stage1', 'blaze_stage2'), a weapon id or a planet id; null for
  /// nothing.
  final ValueListenable<String?> highlightId;

  /// Scroll the glowing item into view if it is not fully on screen.
  final Listenable reveal;

  /// After a selection or an unlock on the page.
  final ValueChanged<BrushChange> onChanged;
}

/// What a page did during the brush steps: equipped something he owns, or
/// bought something. Reported through [BrushMode.onChanged].
@immutable
class BrushChange {
  const BrushChange.selected(this.category) : unlockedId = null;

  const BrushChange.unlocked(this.category, String this.unlockedId);

  final GoalCategory category;

  /// The hero, evolution or weapon id just bought; null for a selection.
  final String? unlockedId;

  @override
  bool operator ==(Object other) =>
      other is BrushChange &&
      other.category == category &&
      other.unlockedId == unlockedId;

  @override
  int get hashCode => Object.hash(category, unlockedId);

  @override
  String toString() => unlockedId == null
      ? 'BrushChange.selected(${category.name})'
      : 'BrushChange.unlocked(${category.name}, $unlockedId)';
}

/// Tells its listeners once per [ping].
class BrushPing extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// Extra bottom padding on a page in brush mode: the floating GO button,
/// its margin and a little air, so the last row, card or planet can scroll
/// above GO.
const double kBrushGoClearance = 112;

/// Scrolls the item at [context] to 35% down its scroll view when any part
/// of it lies outside the visible area, which ends [bottomInset] above the
/// scroll view's bottom (where GO floats). Only the nearest scroll view
/// moves, never the tab pages around it.
Future<void> revealIfHidden(
  BuildContext context, {
  double bottomInset = kBrushGoClearance,
}) async {
  final item = context.findRenderObject();
  final scrollable = Scrollable.maybeOf(context);
  if (item is! RenderBox || !item.attached || !item.hasSize) return;
  if (scrollable == null) return;
  final view = scrollable.context.findRenderObject();
  if (view is! RenderBox || !view.attached || !view.hasSize) return;
  final top = item.localToGlobal(Offset.zero, ancestor: view).dy;
  final bottom = top + item.size.height;
  if (top >= 0 && bottom <= view.size.height - bottomInset) return;
  await scrollable.position.ensureVisible(
    item,
    alignment: 0.35,
    duration: const Duration(milliseconds: 600),
    curve: Curves.easeInOut,
  );
}

/// The X on a page in brush mode: the Map's 56 × 56 back button, with a
/// close icon.
class BrushCloseButton extends StatelessWidget {
  const BrushCloseButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('brush_close'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1.5,
            ),
          ),
          child: const Icon(Icons.close, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Create `lib/widgets/go_button.dart`**

```dart
// lib/widgets/go_button.dart
import 'package:flutter/material.dart';

/// The brush steps' big GO: the tutorial's NEXT gradient and glow, pulsing
/// gently. An arrow on the Heroes & Weapons steps, a rocket on the Map
/// ([rocket]): the label and the icon together, so a child who can't read
/// still knows it.
class GoButton extends StatefulWidget {
  const GoButton({super.key, required this.onPressed, this.rocket = false});

  /// Null disables it (after "Let's fight!").
  final VoidCallback? onPressed;
  final bool rocket;

  @override
  State<GoButton> createState() => _GoButtonState();
}

class _GoButtonState extends State<GoButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant GoButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  /// It pulses only while it can be pressed.
  void _syncPulse() {
    final enabled = widget.onPressed != null;
    if (enabled && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!enabled && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Transform.scale(
        scale: 1.0 + _pulse.value * 0.04,
        child: child,
      ),
      child: Semantics(
        button: true,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: enabled ? 1.0 : 0.5,
            child: Container(
              width: 200,
              height: 76,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C4DFF), Color(0xFF9C27B0)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C4DFF).withValues(alpha: 0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'GO!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    widget.rocket ? Icons.rocket_launch : Icons.arrow_forward,
                    color: Colors.white,
                    size: 32,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Create `lib/widgets/goal_glow.dart`**

```dart
// lib/widgets/goal_glow.dart
import 'package:flutter/material.dart';

/// A pulsing gold ring on the closest next unlock, on a page in brush mode
/// (spec 2026-10-13 §4.1). It paints around [child] without changing its
/// size: the glow behind it, the ring over its edge. [circle] for planets.
class GoalGlow extends StatefulWidget {
  const GoalGlow({
    super.key,
    required this.child,
    this.borderRadius = 12,
    this.circle = false,
  });

  final Widget child;

  /// Corner radius of the ring; unused for a [circle].
  final double borderRadius;
  final bool circle;

  static const color = Color(0xFFFFD54F);

  @override
  State<GoalGlow> createState() => _GoalGlowState();
}

class _GoalGlowState extends State<GoalGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    duration: const Duration(milliseconds: 1200),
    vsync: this,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shape = widget.circle ? BoxShape.circle : BoxShape.rectangle;
    final radius = widget.circle
        ? null
        : BorderRadius.circular(widget.borderRadius);
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = _pulse.value;
        return Container(
          decoration: BoxDecoration(
            shape: shape,
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: GoalGlow.color.withValues(alpha: 0.25 + 0.35 * t),
                blurRadius: 10 + 10 * t,
                spreadRadius: 1 + 2 * t,
              ),
            ],
          ),
          foregroundDecoration: BoxDecoration(
            shape: shape,
            borderRadius: radius,
            border: Border.all(
              color: GoalGlow.color.withValues(alpha: 0.7 + 0.3 * t),
              width: 3,
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
```

- [ ] **Step 6: Run the widget tests**

Run: `flutter test test/widgets/brush_mode_widgets_test.dart`
Expected: PASS (all tests).

- [ ] **Step 7: Write the failing analytics test**

In `test/services/analytics_service_test.dart`, give `_RecordingAnalytics` a parameter log. Replace its `logEvent` override with:

```dart
  /// Every event with its parameters: {'name': ..., ...parameters}.
  final List<Map<String, Object?>> events = [];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {
    calls.add('logEvent($name)');
    events.add({'name': name, ...?parameters});
  }
```

(declare the `events` field next to `calls`). Then add this test at the end of the `'AnalyticsService on Android (unchanged behaviour)'` group:

```dart
    test('goal_unlocked says where the unlock happened', () async {
      final fake = _RecordingAnalytics();
      final service = AnalyticsService.forTesting(
        isAndroid: true,
        analytics: fake,
      );
      await service.init();
      await service.logGoalUnlocked(category: 'hero', item: 'frost');
      await service.logGoalUnlocked(
        category: 'weapon',
        item: 'flame_sword',
        source: 'pre_brush',
      );
      expect(fake.events, [
        {
          'name': 'goal_unlocked',
          'category': 'hero',
          'item': 'frost',
          'source': 'victory',
        },
        {
          'name': 'goal_unlocked',
          'category': 'weapon',
          'item': 'flame_sword',
          'source': 'pre_brush',
        },
      ]);
    });
```

- [ ] **Step 8: Run it to make sure it fails**

Run: `flutter test test/services/analytics_service_test.dart`
Expected: FAIL to compile — `logGoalUnlocked` has no `source` parameter.

- [ ] **Step 9: Add the `source` parameter**

In `lib/services/analytics_service.dart`, replace `logGoalUnlocked` with:

```dart
  /// [source]: 'victory' (the victory screen's one-tap unlock) or
  /// 'pre_brush' (bought on a page during the brush steps).
  Future<void> logGoalUnlocked({
    required String category,
    required String item,
    String source = 'victory',
  }) async {
    if (!_enabled) return;
    await _fa.logEvent(
      name: 'goal_unlocked',
      parameters: {'category': category, 'item': item, 'source': source},
    );
  }
```

The victory screen's call stays as it is (its default is `'victory'`).

- [ ] **Step 10: Run the tests, analyze, format**

Run: `flutter test test/services/analytics_service_test.dart test/widgets/brush_mode_widgets_test.dart test/screens/victory_goal_test.dart && dart format lib test && dart analyze`
Expected: all PASS; `dart analyze` says "No issues found!".

- [ ] **Step 11: Commit**

```bash
git add lib/screens/brush_mode.dart lib/widgets/go_button.dart lib/widgets/goal_glow.dart lib/services/analytics_service.dart test/widgets/brush_mode_widgets_test.dart test/services/analytics_service_test.dart
git commit -m "feat(brush-mode): GO button, goal glow and the brush-mode contract

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01STWCtX8pE4SLhUiiBxVG9M"
```

---

### Task 2: The Heroes & Weapons page in brush mode

**Files:**
- Modify: `lib/screens/hero_shop_screen.dart`
- Create: `test/screens/hero_shop_brush_mode_test.dart`
- Unchanged and must still pass: `test/screens/hero_shop_screen_test.dart`

**Interfaces:**
- Consumes (Task 1): `BrushMode`, `BrushChange`, `BrushPing`, `BrushCloseButton`, `kBrushGoClearance`, `revealIfHidden`, `GoalGlow`; `GoalCategory`.
- Produces (Task 4 relies on these):
  - `const HeroShopScreen({Key? key, BrushMode? brushMode})`
  - `@visibleForTesting static AnalyticsService? HeroShopScreen.debugAnalytics` (used for `shop_visit` only)
  - Keys: each evolution cell `ValueKey('evo_cell_<evolution id>')` (e.g. `evo_cell_frost_stage1`, `evo_cell_blaze_stage2`); each weapon card `ValueKey('weapon_card_<weapon id>')`.
  - In brush mode: `onTabChanged(index)` on a tab tap or swipe (not for changes the steps asked for through `tab`); `onChanged(BrushChange.selected(GoalCategory.hero|weapon))` after equipping something owned; `onChanged(BrushChange.unlocked(GoalCategory.hero, <hero id or evolution id>))` / `(GoalCategory.weapon, <weapon id>)` after a purchase.

- [ ] **Step 1: Write the failing tests**

Create `test/screens/hero_shop_brush_mode_test.dart`:

```dart
// test/screens/hero_shop_brush_mode_test.dart
//
// The Heroes & Weapons page in brush mode (spec 2026-10-13 §4, §5) and the
// pins that it is unchanged when opened from Home (R6).
import 'package:brush_quest/screens/brush_mode.dart';
import 'package:brush_quest/screens/hero_shop_screen.dart';
import 'package:brush_quest/services/analytics_service.dart';
import 'package:brush_quest/services/audio_service.dart';
import 'package:brush_quest/services/goal_service.dart';
import 'package:brush_quest/services/streak_service.dart';
import 'package:brush_quest/widgets/goal_glow.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/fake_audio_service.dart';

/// Records events (AnalyticsService is a no-op on the test host).
class _RecordingAnalytics extends Fake implements FirebaseAnalytics {
  final List<Map<String, Object?>> events = [];

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {}

  @override
  Future<void> setConsent({
    bool? adStorageConsentGranted,
    bool? analyticsStorageConsentGranted,
    bool? adPersonalizationSignalsConsentGranted,
    bool? adUserDataConsentGranted,
    bool? functionalityStorageConsentGranted,
    bool? personalizationStorageConsentGranted,
    bool? securityStorageConsentGranted,
  }) async {}

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {
    events.add({'name': name, ...?parameters});
  }
}

/// Stands in for the brush steps: owns what the page follows and records
/// what it reports.
class _Steps {
  final tab = ValueNotifier<int>(0);
  final highlight = ValueNotifier<String?>(null);
  final reveal = BrushPing();
  final tabsReported = <int>[];
  final changes = <BrushChange>[];
  var closes = 0;

  late final mode = BrushMode(
    onClose: () => closes++,
    tab: tab,
    onTabChanged: tabsReported.add,
    highlightId: highlight,
    reveal: reveal,
    onChanged: changes.add,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeAudioService fakeAudio;
  late _RecordingAnalytics recorder;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    for (final name in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), (call) async => 1);
    }
  });

  setUp(() async {
    fakeAudio = FakeAudioService();
    AudioService.testInstance = fakeAudio;
    recorder = _RecordingAnalytics();
    final analytics = AnalyticsService.forTesting(
      isAndroid: true,
      analytics: recorder,
    );
    await analytics.init();
    HeroShopScreen.debugAnalytics = analytics;
  });

  tearDown(() {
    AudioService.testInstance = null;
    HeroShopScreen.debugAnalytics = null;
    StreakService.isPurchasing = false;
  });

  Future<_Steps> pumpShop(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
    bool brush = true,
    String? highlight,
    int tab = 0,
  }) async {
    SharedPreferences.setMockInitialValues({
      'star_wallet': 3,
      'total_stars': 13,
      'unlocked_heroes': ['blaze'],
      'selected_hero': 'blaze',
      'unlocked_weapons': ['star_blaster'],
      'selected_weapon': 'star_blaster',
      'muted': false,
      'current_world': 'candy_crater',
      ...prefs,
    });
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final steps = _Steps()
      ..highlight.value = highlight
      ..tab.value = tab;
    await tester.pumpWidget(
      MaterialApp(
        home: brush
            ? HeroShopScreen(brushMode: steps.mode)
            : const HeroShopScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    return steps;
  }

  Finder glowIn(String key) => find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(GoalGlow),
  );

  ScrollableState heroList(WidgetTester tester) =>
      tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );

  Iterable<Map<String, Object?>> shopVisits() =>
      recorder.events.where((e) => e['name'] == 'shop_visit');

  Future<void> buy(WidgetTester tester, Finder item) async {
    await tester.tap(item);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('YES!'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('brush mode', () {
    testWidgets('an X instead of the back arrow; it asks the steps to close', (
      tester,
    ) async {
      final steps = await pumpShop(tester);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(find.byIcon(Icons.close), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('brush_close')));
      await tester.pump();
      expect(steps.closes, 1);
      // The steps stop the voice when they close, not the page.
      expect(fakeAudio.callsFor('stopVoice'), isEmpty);
    });

    testWidgets('no entry line, tab line, music or shop visit', (
      tester,
    ) async {
      await pumpShop(tester);
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('WEAPONS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(fakeAudio.playedVoiceLines, isEmpty);
      expect(fakeAudio.callsFor('playMusic'), isEmpty);
      expect(fakeAudio.callsFor('setMusicVolume'), isEmpty);
      expect(shopVisits(), isEmpty);
    });

    testWidgets('follows the steps to WEAPONS without reporting it back', (
      tester,
    ) async {
      final steps = await pumpShop(tester);
      steps.tab.value = 1;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 1);
      expect(
        find.byKey(const ValueKey('weapon_card_flame_sword')),
        findsOneWidget,
      );
      expect(steps.tabsReported, isEmpty);
    });

    testWidgets('reports a tab tap and a swipe to the steps', (tester) async {
      final steps = await pumpShop(tester);
      await tester.tap(find.text('WEAPONS'));
      await tester.pump();
      expect(steps.tabsReported, [1]);
      steps.tab.value = 1; // the steps take the weapon step
      await tester.pump(const Duration(milliseconds: 400));
      await tester.fling(find.byType(TabBarView), const Offset(300, 0), 1500);
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(steps.tabsReported, [1, 0]);
      expect(fakeAudio.playedVoiceLines, isEmpty); // no tab lines
    });

    testWidgets('the highlighted hero cell glows, and only it', (
      tester,
    ) async {
      final steps = await pumpShop(tester, highlight: 'frost_stage1');
      expect(glowIn('evo_cell_frost_stage1'), findsOneWidget);
      expect(find.byType(GoalGlow), findsOneWidget);
      steps.highlight.value = 'blaze_stage2';
      await tester.pump();
      expect(glowIn('evo_cell_blaze_stage2'), findsOneWidget);
      expect(find.byType(GoalGlow), findsOneWidget);
      steps.highlight.value = null;
      await tester.pump();
      expect(find.byType(GoalGlow), findsNothing);
    });

    testWidgets('the highlighted weapon card glows', (tester) async {
      await pumpShop(tester, tab: 1, highlight: 'flame_sword');
      expect(glowIn('weapon_card_flame_sword'), findsOneWidget);
      expect(find.byType(GoalGlow), findsOneWidget);
    });

    testWidgets('a reveal scrolls a far-down glow above GO', (tester) async {
      final steps = await pumpShop(tester, highlight: 'nova_stage1');
      final list = tester.getRect(find.byType(ListView));
      expect(
        tester.getRect(find.byType(GoalGlow)).bottom,
        greaterThan(list.bottom - kBrushGoClearance),
        reason: 'Nova is the last row: off screen at first',
      );
      steps.reveal.ping();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      final glow = tester.getRect(find.byType(GoalGlow));
      expect(glow.top, greaterThanOrEqualTo(list.top));
      expect(glow.bottom, lessThanOrEqualTo(list.bottom - kBrushGoClearance));
    });

    testWidgets('a reveal leaves a glow already on screen alone', (
      tester,
    ) async {
      final steps = await pumpShop(tester, highlight: 'frost_stage1');
      steps.reveal.ping();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(heroList(tester).position.pixels, 0);
    });

    testWidgets('the last row can scroll above GO', (tester) async {
      await pumpShop(tester);
      expect(
        tester.widget<ListView>(find.byType(ListView)).padding,
        const EdgeInsets.fromLTRB(12, 8, 12, 16 + kBrushGoClearance),
      );
      final position = heroList(tester).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      expect(
        tester.getRect(find.byKey(const ValueKey('evo_cell_nova_stage1'))).bottom,
        lessThanOrEqualTo(
          tester.getRect(find.byType(ListView)).bottom - kBrushGoClearance,
        ),
      );
    });

    testWidgets('buying a hero: the page celebrates, equips and reports it', (
      tester,
    ) async {
      final steps = await pumpShop(
        tester,
        prefs: {'star_wallet': 6},
        highlight: 'frost_stage1',
      );
      await buy(tester, find.byKey(const ValueKey('evo_cell_frost_stage1')));
      expect(find.text('FROST UNLOCKED!'), findsOneWidget);
      expect(fakeAudio.playedVoiceLines.last, 'voice_intro_hero_frost.mp3');
      await tester.pump(const Duration(seconds: 7)); // it closes after 6 s
      await tester.pump(const Duration(milliseconds: 500)); // and fades out
      expect(find.text('FROST UNLOCKED!'), findsNothing);
      expect(steps.changes, [
        const BrushChange.unlocked(GoalCategory.hero, 'frost'),
      ]);
      final saved = await SharedPreferences.getInstance();
      expect(saved.getString('selected_hero'), 'frost');
      expect(saved.getInt('star_wallet'), 1);
    });

    testWidgets('equipping an owned upgrade reports a selection', (
      tester,
    ) async {
      final steps = await pumpShop(
        tester,
        prefs: {
          'unlocked_evolutions': ['blaze_stage2'],
        },
      );
      await tester.tap(find.byKey(const ValueKey('evo_cell_blaze_stage2')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(steps.changes, [const BrushChange.selected(GoalCategory.hero)]);
      expect(fakeAudio.playedVoiceLines, ['voice_picker_evo_blaze_stage2.mp3']);
      final saved = await SharedPreferences.getInstance();
      expect(saved.getInt('evolution_stage_blaze'), 2);
    });

    testWidgets('buying a weapon reports it', (tester) async {
      final steps = await pumpShop(
        tester,
        prefs: {'star_wallet': 6},
        tab: 1,
        highlight: 'flame_sword',
      );
      await buy(tester, find.byKey(const ValueKey('weapon_card_flame_sword')));
      await tester.pump(const Duration(seconds: 7)); // it closes after 6 s
      expect(steps.changes, [
        const BrushChange.unlocked(GoalCategory.weapon, 'flame_sword'),
      ]);
      final saved = await SharedPreferences.getInstance();
      expect(saved.getString('selected_weapon'), 'flame_sword');
    });

    testWidgets('leaving the page leaves the voice to the steps', (
      tester,
    ) async {
      await pumpShop(tester);
      await tester.pumpWidget(const SizedBox());
      expect(fakeAudio.callsFor('stopVoice'), isEmpty);
    });
  });

  group('from Home (unchanged)', () {
    testWidgets('entry line, tab line, music and shop visit as before', (
      tester,
    ) async {
      await pumpShop(tester, brush: false);
      expect(fakeAudio.playedVoiceLines, ['voice_entry_hero_hq.mp3']);
      expect(
        fakeAudio.calls,
        contains(
          const AudioCall('playMusic', {
            'fileName': 'battle_music_loop.mp3',
            'isRetry': false,
          }),
        ),
      );
      expect(
        fakeAudio.calls,
        contains(const AudioCall('setMusicVolume', {'volume': 0.05})),
      );
      expect(shopVisits(), hasLength(1));
      await tester.tap(find.text('WEAPONS'));
      await tester.pump();
      expect(fakeAudio.playedVoiceLines.last, 'voice_tab_weapons.mp3');
    });

    testWidgets('a back arrow, its own padding, no X and no glow', (
      tester,
    ) async {
      await pumpShop(tester, brush: false);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.byType(GoalGlow), findsNothing);
      expect(
        tester.widget<ListView>(find.byType(ListView)).padding,
        const EdgeInsets.fromLTRB(12, 8, 12, 16),
      );
    });

    testWidgets('leaving the page stops the voice, as before', (tester) async {
      await pumpShop(tester, brush: false);
      await tester.pumpWidget(const SizedBox());
      expect(fakeAudio.callsFor('stopVoice'), isNotEmpty);
    });
  });
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `flutter test test/screens/hero_shop_brush_mode_test.dart`
Expected: FAIL to compile — `HeroShopScreen` has no `brushMode` or `debugAnalytics`.

- [ ] **Step 3: Imports and the widget class**

In `lib/screens/hero_shop_screen.dart`, add to the imports:

```dart
import '../services/goal_service.dart';
import '../widgets/goal_glow.dart';
import 'brush_mode.dart';
```

Replace the `HeroShopScreen` class with:

```dart
class HeroShopScreen extends StatefulWidget {
  const HeroShopScreen({super.key, this.brushMode});

  /// Set when the page is a step of the brush flow (pre_brush_screen.dart);
  /// null when it is opened from Home, where it works exactly as it always
  /// has.
  final BrushMode? brushMode;

  /// Where shop_visit goes. The singleton does nothing on a test host (it
  /// only reaches Firebase on Android), so tests swap in a recording one.
  @visibleForTesting
  static AnalyticsService? debugAnalytics;

  @override
  State<HeroShopScreen> createState() => _HeroShopScreenState();
}
```

- [ ] **Step 4: State fields, initState, didUpdateWidget, dispose**

In `_HeroShopScreenState`, replace everything from `late TabController _tabController;` through the end of `dispose()` with:

```dart
  late TabController _tabController;

  /// Brush mode: the tab the steps last knew about.
  int _reportedTab = 0;

  /// Brush mode: the id that glows (see BrushMode.highlightId).
  String? _highlightId;

  /// Wraps the glowing cell or card, so a reveal can find it.
  final _glowKey = GlobalKey();

  Timer? _entryVoiceTimer;

  static const _brushCacheExtent = 4000.0;

  @override
  void initState() {
    super.initState();
    final brush = widget.brushMode;
    _reportedTab = brush?.tab.value ?? 0;
    _highlightId = brush?.highlightId.value;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: _reportedTab,
    );
    _tabController.addListener(_onTabControllerChanged);
    if (brush != null) {
      brush.tab.addListener(_followStepsTab);
      brush.highlightId.addListener(_onHighlightChanged);
      brush.reveal.addListener(_revealGlow);
    }
    // Show the wallet immediately before async load refines it
    SharedPreferences.getInstance().then((p) {
      if (mounted) {
        setState(() {
          _wallet = p.getInt('star_wallet') ?? 0;
        });
      }
    });
    _loadData();
    // In brush mode the steps speak, Home's music plays on, and it is not a
    // shop visit (spec 2026-10-13 §4.3, §6).
    if (brush != null) return;
    _entryVoiceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        AudioService().playVoice(
          'voice_entry_hero_hq.mp3',
          clearQueue: true,
          interrupt: true,
        );
      }
    });
    // Ambient music — low volume so voice lines stay clear.
    // Serialize playMusic + setMusicVolume via postFrame so initState isn't
    // blocked and the calls don't race on iOS (proven pattern from
    // home_screen.dart:232-241). Without await, on iOS the volume gets
    // applied to the prior disposed player and the new shop player is silent.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await AudioService().playMusic('battle_music_loop.mp3');
      if (!mounted) return;
      await AudioService().setMusicVolume(0.05);
      if (!mounted) return;
      unawaited(AudioService().ensureMusicPlaying());
    });
    (HeroShopScreen.debugAnalytics ?? AnalyticsService()).logShopVisit();
  }

  @override
  void didUpdateWidget(covariant HeroShopScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(
      identical(oldWidget.brushMode, widget.brushMode),
      'A page keeps its brush mode for its whole life.',
    );
  }

  @override
  void dispose() {
    final brush = widget.brushMode;
    if (brush == null) {
      AudioService().stopVoice();
    } else {
      // The steps own the voice: the next step speaks while this page
      // slides away.
      brush.tab.removeListener(_followStepsTab);
      brush.highlightId.removeListener(_onHighlightChanged);
      brush.reveal.removeListener(_revealGlow);
    }
    _entryVoiceTimer?.cancel();
    // Do NOT stopMusic here — see world_map_screen dispose. Shared
    // battle_music_loop; Home restores volume on didPopNext.
    _tabController.dispose();
    super.dispose();
  }

  void _onTabControllerChanged() {
    final brush = widget.brushMode;
    if (brush == null) {
      if (!_tabController.indexIsChanging) return;
      final voice = _tabController.index == 0
          ? 'voice_tab_heroes.mp3'
          : 'voice_tab_weapons.mp3';
      AudioService().playVoice(voice, clearQueue: true, interrupt: true);
      return;
    }
    // Brush mode: a tab tap or a swipe moves the steps; they speak, not the
    // tab.
    final index = _tabController.index;
    if (index == _reportedTab) return;
    _reportedTab = index;
    brush.onTabChanged(index);
  }

  /// The steps moved to the other tab (GO or the idle count).
  void _followStepsTab() {
    final index = widget.brushMode!.tab.value;
    _reportedTab = index;
    if (_tabController.index != index) _tabController.animateTo(index);
  }

  void _onHighlightChanged() {
    if (!mounted) return;
    setState(() => _highlightId = widget.brushMode!.highlightId.value);
  }

  void _revealGlow() {
    final glow = _glowKey.currentContext;
    if (glow != null) unawaited(revealIfHidden(glow));
  }

  /// Brush mode: tells the steps what changed, even if this page is already
  /// sliding away.
  void _reportChange(BrushChange change) =>
      widget.brushMode?.onChanged(change);
```

- [ ] **Step 5: Report changes from the tap handlers**

In `_onEvolutionTap`, add one `_reportChange` line at each of these three places (the surrounding code stays as it is):

```dart
        final success = await _unlock.unlockHero(hero.id);
        if (success) {
          unawaited(HapticFeedback.heavyImpact());
          if (mounted) _showHeroUnlockAnimation(hero);
          await _loadData();
          _reportChange(BrushChange.unlocked(GoalCategory.hero, hero.id));
        }
```

```dart
    if (isEvoOwned) {
      // Equip this evolution + select hero
      await _heroService.selectHero(hero.id);
      await _heroService.setEvolutionStage(hero.id, evolution.stage);
      unawaited(HapticFeedback.mediumImpact());
      _playSelectionVoice(
        AudioService().evolutionPickerVoiceFor(hero.id, evolution.stage),
      );
      await _loadData();
      _reportChange(const BrushChange.selected(GoalCategory.hero));
    } else if (_wallet >= evolution.price) {
```

```dart
      final success = await _unlock.unlockEvolution(evolution.id);
      if (success) {
        unawaited(HapticFeedback.heavyImpact());
        await _loadData();
        _reportChange(BrushChange.unlocked(GoalCategory.hero, evolution.id));
      }
```

In `_onWeaponTap`:

```dart
    if (_unlockedWeapons.contains(weapon.id)) {
      // Already selected — no-op to avoid unnecessary work
      if (_selectedWeaponId == weapon.id) return;
      await _weaponService.selectWeapon(weapon.id);
      unawaited(HapticFeedback.mediumImpact());
      _playSelectionVoice(AudioService().weaponPickerVoiceFor(weapon.id));
      await _loadData();
      _reportChange(const BrushChange.selected(GoalCategory.weapon));
    } else if (_wallet >= weapon.price) {
```

```dart
      final success = await _unlock.unlockWeapon(weapon.id);
      if (success) {
        unawaited(HapticFeedback.heavyImpact());
        // Finding #8: Don't play voice here — the unlock dialog's initState
        // plays the intro voice. Playing it here too causes an audible stutter.
        if (mounted) _showWeaponUnlockAnimation(weapon);
        await _loadData();
        _reportChange(BrushChange.unlocked(GoalCategory.weapon, weapon.id));
      }
```

- [ ] **Step 6: The X in the header**

In `build`, add `final brush = widget.brushMode;` as the first line of the method, and replace the header's first child (the `GestureDetector` with `Icons.arrow_back`) with:

```dart
                    if (brush != null)
                      BrushCloseButton(onTap: brush.onClose)
                    else
                      GestureDetector(
                        onTap: () {
                          AudioService().stopVoice();
                          Navigator.of(context).pop();
                        },
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
```

- [ ] **Step 7: Padding, every row built, glow on the grids**

Replace `_buildEvolutionGrid` with:

```dart
  Widget _buildEvolutionGrid() {
    final selectedHero = HeroService.allHeroes.firstWhere(
      (h) => h.id == _selectedHeroId,
      orElse: () => HeroService.allHeroes.first,
    );
    final selectedStage = _evolutionStages[selectedHero.id] ?? 1;
    final brush = widget.brushMode;

    // +1 item for the featured hero header at index 0 (C15 T3-19 symmetry
    // with Weapons tab). The remaining indices map to the hero roster.
    // Brush mode: room under the last row for GO, and every row built so a
    // reveal can reach the glow.
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        16.0 + (brush == null ? 0.0 : kBrushGoClearance),
      ),
      cacheExtent: brush == null ? null : _brushCacheExtent,
      itemCount: HeroService.allHeroes.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _FeaturedHeroDisplay(hero: selectedHero, stage: selectedStage);
        }
        final hero = HeroService.allHeroes[index - 1];
        final isHeroOwned = _unlockedHeroes.contains(hero.id);
        final isSelected = _selectedHeroId == hero.id;
        final currentStage = _evolutionStages[hero.id] ?? 1;
        final evolutions = HeroService.evolutionsForHero(hero.id);

        return _HeroEvolutionRow(
          hero: hero,
          evolutions: evolutions,
          isHeroOwned: isHeroOwned,
          isSelected: isSelected,
          currentStage: currentStage,
          wallet: _wallet,
          selectedWeaponId: _selectedWeaponId,
          unlockedEvolutions: _unlockedEvolutions,
          highlightId: _highlightId,
          glowKey: _glowKey,
          onEvolutionTap: (evo) => _onEvolutionTap(hero, evo),
        );
      },
    );
  }
```

Replace `_buildWeaponGrid` with:

```dart
  Widget _buildWeaponGrid() {
    final selectedWeapon = WeaponService.allWeapons.firstWhere(
      (w) => w.id == _selectedWeaponId,
      orElse: () => WeaponService.allWeapons.first,
    );
    final brush = widget.brushMode;

    return CustomScrollView(
      cacheExtent: brush == null ? null : _brushCacheExtent,
      slivers: [
        // Featured selected weapon display
        SliverToBoxAdapter(
          child: _FeaturedWeaponDisplay(weapon: selectedWeapon),
        ),
        // Weapon grid
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            16.0 + (brush == null ? 0.0 : kBrushGoClearance),
          ),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.68,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final weapon = WeaponService.allWeapons[index];
              final isUnlocked = _unlockedWeapons.contains(weapon.id);
              final isSelected = _selectedWeaponId == weapon.id;
              final canAfford = _wallet >= weapon.price;

              return _WeaponCard(
                key: ValueKey('weapon_card_${weapon.id}'),
                weapon: weapon,
                isUnlocked: isUnlocked,
                isSelected: isSelected,
                canAfford: canAfford,
                currentStars: _wallet,
                highlighted: weapon.id == _highlightId,
                glowKey: _glowKey,
                onTap: () => _onWeaponTap(weapon),
              );
            }, childCount: WeaponService.allWeapons.length),
          ),
        ),
      ],
    );
  }
```

In `_HeroEvolutionRow`: add two fields and constructor parameters,

```dart
  /// Brush mode: the evolution id that glows, or null.
  final String? highlightId;
  final Key? glowKey;
```

(`required this.highlightId, required this.glowKey,` in the constructor), and in its `build`, give each `_EvolutionCell` a key and the highlight:

```dart
              Expanded(
                child: _EvolutionCell(
                  key: ValueKey('evo_cell_${evolutions[i].id}'),
                  hero: hero,
                  evolution: evolutions[i],
                  isHeroOwned: isHeroOwned,
                  isOwned: evolutions[i].stage == 1
                      ? isHeroOwned
                      : unlockedEvolutions.contains(evolutions[i].id),
                  isEquipped: isSelected && currentStage == evolutions[i].stage,
                  isGated:
                      evolutions[i].stage >= 3 &&
                      !unlockedEvolutions.contains(
                        '${hero.id}_stage${evolutions[i].stage - 1}',
                      ),
                  wallet: wallet,
                  weaponId: selectedWeaponId,
                  highlighted: evolutions[i].id == highlightId,
                  glowKey: glowKey,
                  onTap: () => onEvolutionTap(evolutions[i]),
                ),
              ),
```

In `_EvolutionCell`: add `super.key` and two parameters to the constructor,

```dart
  const _EvolutionCell({
    super.key,
    required this.hero,
    required this.evolution,
    required this.isHeroOwned,
    required this.isOwned,
    required this.isEquipped,
    required this.isGated,
    required this.wallet,
    required this.weaponId,
    required this.onTap,
    this.highlighted = false,
    this.glowKey,
  });
```

with the fields

```dart
  /// Brush mode: the closest next unlock.
  final bool highlighted;
  final Key? glowKey;
```

and at the end of `_EvolutionCellState.build`, replace `return cell;` with:

```dart
    if (widget.highlighted) {
      cell = GoalGlow(key: widget.glowKey, child: cell);
    }
    return cell;
```

In `_WeaponCard`: the same constructor change (`super.key`, `this.highlighted = false`, `this.glowKey`, fields as above), and at the end of `_WeaponCardState.build`, replace `return card;` with:

```dart
    if (widget.highlighted) {
      card = GoalGlow(key: widget.glowKey, borderRadius: 20, child: card);
    }
    return card;
```

- [ ] **Step 8: Run the new and the existing shop tests**

Run: `flutter test test/screens/hero_shop_brush_mode_test.dart test/screens/hero_shop_screen_test.dart`
Expected: all PASS.

- [ ] **Step 9: Format, analyze, full suite**

Run: `dart format lib test && dart analyze && flutter test`
Expected: "No issues found!"; all tests pass (the pre-brush steps still use the carousel at this point, untouched).

- [ ] **Step 10: Commit**

```bash
git add lib/screens/hero_shop_screen.dart test/screens/hero_shop_brush_mode_test.dart
git commit -m "feat(shop): brush mode for the Heroes & Weapons page

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01STWCtX8pE4SLhUiiBxVG9M"
```

---

### Task 3: The Map page in brush mode

**Files:**
- Modify: `lib/screens/world_map_screen.dart`
- Create: `test/screens/world_map_brush_mode_test.dart`
- Unchanged and must still pass: `test/screens/world_map_screen_test.dart`

**Interfaces:**
- Consumes (Task 1): `BrushMode`, `BrushChange`, `BrushPing`, `BrushCloseButton`, `kBrushGoClearance`, `revealIfHidden`, `GoalGlow`; `GoalCategory`.
- Produces (Task 4 relies on these):
  - `const WorldMapScreen({Key? key, BrushMode? brushMode})`
  - Key: each planet node `ValueKey('planet_<world id>')` (e.g. `planet_slime_swamp`).
  - In brush mode: `onChanged(const BrushChange.selected(GoalCategory.world))` after he picks another open planet. The Map never reads `tab` and never calls `onTabChanged`.

- [ ] **Step 1: Write the failing tests**

Create `test/screens/world_map_brush_mode_test.dart`:

```dart
// test/screens/world_map_brush_mode_test.dart
//
// The Map in brush mode (spec 2026-10-13 §4, §5) and the pins that it is
// unchanged when opened from Home (R6). Test order matters: the first test
// opens the Map in brush mode, and the second checks that this did not use
// up the once-a-session intro (a static flag).
import 'package:brush_quest/screens/brush_mode.dart';
import 'package:brush_quest/screens/world_map_screen.dart';
import 'package:brush_quest/services/audio_service.dart';
import 'package:brush_quest/services/goal_service.dart';
import 'package:brush_quest/services/world_service.dart';
import 'package:brush_quest/widgets/goal_glow.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/fake_audio_service.dart';

/// Stands in for the brush steps: owns what the page follows and records
/// what it reports.
class _Steps {
  final tab = ValueNotifier<int>(0);
  final highlight = ValueNotifier<String?>(null);
  final reveal = BrushPing();
  final changes = <BrushChange>[];
  var closes = 0;

  late final mode = BrushMode(
    onClose: () => closes++,
    tab: tab,
    onTabChanged: (_) {},
    highlightId: highlight,
    reveal: reveal,
    onChanged: changes.add,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeAudioService fakeAudio;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    for (final name in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), (call) async => 1);
    }
  });

  setUp(() {
    fakeAudio = FakeAudioService();
    AudioService.testInstance = fakeAudio;
  });

  tearDown(() => AudioService.testInstance = null);

  Future<_Steps> pumpMap(
    WidgetTester tester, {
    bool brush = true,
    String? highlight,
    Map<String, int> progress = const {},
  }) async {
    final prefs = <String, Object>{
      'current_world': 'candy_crater',
      'muted': false,
    };
    for (final world in WorldService.allWorlds) {
      prefs['world_progress_${world.id}'] = progress[world.id] ?? 0;
    }
    SharedPreferences.setMockInitialValues(prefs);
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final steps = _Steps()..highlight.value = highlight;
    await tester.pumpWidget(
      MaterialApp(
        home: brush
            ? WorldMapScreen(brushMode: steps.mode)
            : const WorldMapScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return steps;
  }

  Rect scrollView(WidgetTester tester) =>
      tester.getRect(find.byType(SingleChildScrollView));

  testWidgets('brush mode: no intro, world line or music when it opens', (
    tester,
  ) async {
    await pumpMap(tester);
    expect(fakeAudio.playedVoiceLines, isEmpty);
    expect(fakeAudio.callsFor('playMusic'), isEmpty);
    expect(fakeAudio.callsFor('setMusicVolume'), isEmpty);
  });

  testWidgets('from Home: its intro once a session, world line and music', (
    tester,
  ) async {
    await pumpMap(tester, brush: false);
    expect(fakeAudio.playedVoiceLines, [
      'voice_world_map_intro.mp3',
      'voice_world_candy_crater.mp3',
    ]);
    expect(
      fakeAudio.calls,
      contains(const AudioCall('setMusicVolume', {'volume': 0.04})),
    );
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.byType(GoalGlow), findsNothing);
    expect(
      tester.widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
          .padding,
      const EdgeInsets.only(bottom: 40, top: 8),
    );
  });

  testWidgets('an X instead of the back arrow; it asks the steps to close', (
    tester,
  ) async {
    final steps = await pumpMap(tester);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
    await tester.tap(find.byKey(const ValueKey('brush_close')));
    await tester.pump();
    expect(steps.closes, 1);
    expect(fakeAudio.callsFor('stopVoice'), isEmpty);
  });

  testWidgets('the highlighted planet glows in a circle', (tester) async {
    await pumpMap(tester, highlight: 'slime_swamp');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('planet_slime_swamp')),
        matching: find.byType(GoalGlow),
      ),
      findsOneWidget,
    );
    expect(find.byType(GoalGlow), findsOneWidget);
    expect(tester.widget<GoalGlow>(find.byType(GoalGlow)).circle, isTrue);
  });

  testWidgets('a reveal scrolls a far planet above GO', (tester) async {
    final steps = await pumpMap(tester, highlight: 'dark_dimension');
    expect(
      tester.getRect(find.byType(GoalGlow)).top,
      greaterThan(scrollView(tester).bottom),
      reason: 'the last planet starts off screen',
    );
    steps.reveal.ping();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    final glow = tester.getRect(find.byType(GoalGlow));
    expect(glow.top, greaterThanOrEqualTo(scrollView(tester).top));
    expect(
      glow.bottom,
      lessThanOrEqualTo(scrollView(tester).bottom - kBrushGoClearance),
    );
  });

  testWidgets('the last planet can scroll above GO', (tester) async {
    await pumpMap(tester);
    expect(
      tester.widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
          .padding,
      const EdgeInsets.only(bottom: 40 + kBrushGoClearance, top: 8),
    );
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    expect(
      tester.getRect(find.byKey(const ValueKey('planet_dark_dimension'))).bottom,
      lessThanOrEqualTo(scrollView(tester).bottom - kBrushGoClearance),
    );
  });

  testWidgets('picking an open planet: its line once, saved, reported', (
    tester,
  ) async {
    final steps = await pumpMap(tester, progress: {'candy_crater': 5});
    await tester.tap(find.byKey(const ValueKey('planet_slime_swamp')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // The page's own line from the tap; the reload does not say it again.
    expect(fakeAudio.playedVoiceLines, ['voice_world_slime_swamp.mp3']);
    expect(fakeAudio.callsFor('playMusic'), isEmpty);
    expect(steps.changes, [const BrushChange.selected(GoalCategory.world)]);
    final saved = await SharedPreferences.getInstance();
    expect(saved.getString('current_world'), 'slime_swamp');
  });

  testWidgets('a locked planet: its line and "Keep brushing", no change', (
    tester,
  ) async {
    final steps = await pumpMap(tester);
    await tester.tap(find.byKey(const ValueKey('planet_slime_swamp')));
    await tester.pump();
    expect(fakeAudio.playedVoiceLines, [
      'voice_world_slime_swamp.mp3',
      'voice_need_more_brushes.mp3',
    ]);
    expect(steps.changes, isEmpty);
  });

  testWidgets('leaving the Map leaves the voice to brushing', (tester) async {
    await pumpMap(tester);
    await tester.pumpWidget(const SizedBox());
    expect(fakeAudio.callsFor('stopVoice'), isEmpty);
  });

  testWidgets('from Home, leaving the Map stops the voice, as before', (
    tester,
  ) async {
    await pumpMap(tester, brush: false);
    await tester.pumpWidget(const SizedBox());
    expect(fakeAudio.callsFor('stopVoice'), isNotEmpty);
  });
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `flutter test test/screens/world_map_brush_mode_test.dart`
Expected: FAIL to compile — `WorldMapScreen` has no `brushMode`.

- [ ] **Step 3: Imports, widget class, state**

In `lib/screens/world_map_screen.dart`, add to the imports:

```dart
import '../services/goal_service.dart';
import '../widgets/goal_glow.dart';
import 'brush_mode.dart';
```

Replace the `WorldMapScreen` class with:

```dart
class WorldMapScreen extends StatefulWidget {
  const WorldMapScreen({super.key, this.brushMode});

  /// Set when the Map is the last step of the brush flow
  /// (pre_brush_screen.dart); null when it is opened from Home, where it
  /// works exactly as it always has.
  final BrushMode? brushMode;

  @override
  State<WorldMapScreen> createState() => _WorldMapScreenState();
}
```

In `_WorldMapScreenState`, after `final Map<String, bool> _unlocked = {};` add:

```dart
  /// Brush mode: the planet that glows (see BrushMode.highlightId).
  String? _highlightId;

  /// Wraps the glowing planet, so a reveal can find it.
  final _glowKey = GlobalKey();
```

Replace `initState` with:

```dart
  @override
  void initState() {
    super.initState();
    final brush = widget.brushMode;
    if (brush != null) {
      _highlightId = brush.highlightId.value;
      brush.highlightId.addListener(_onHighlightChanged);
      brush.reveal.addListener(_revealGlow);
    }
    _loadData();
  }

  @override
  void didUpdateWidget(covariant WorldMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(
      identical(oldWidget.brushMode, widget.brushMode),
      'A page keeps its brush mode for its whole life.',
    );
  }

  void _onHighlightChanged() {
    if (!mounted) return;
    setState(() => _highlightId = widget.brushMode!.highlightId.value);
  }

  void _revealGlow() {
    final glow = _glowKey.currentContext;
    if (glow != null) unawaited(revealIfHidden(glow));
  }
```

In `_loadData`, directly after the `setState(() { ... });` block and before the `// Ambient music` comment, add:

```dart
      // In brush mode the steps speak and Home's music plays on (spec
      // 2026-10-13 §4.3): no music change, no intro, no world line.
      if (widget.brushMode != null) return;
```

Replace `dispose` with:

```dart
  @override
  void dispose() {
    final brush = widget.brushMode;
    if (brush == null) {
      AudioService().stopVoice();
    } else {
      // The steps own the voice: brushing's countdown starts while the Map
      // fades away.
      brush.highlightId.removeListener(_onHighlightChanged);
      brush.reveal.removeListener(_revealGlow);
    }
    // Do NOT stopMusic here. All screens share battle_music_loop; this dispose
    // runs ~300ms after Home's didPopNext restarts music (route exit
    // animation), so stopping here killed the music Home just started (v25
    // home-silent-on-return bug). Home restores its own volume on didPopNext.
    super.dispose();
  }
```

- [ ] **Step 4: The X, the padding, the planets**

In `build`, add `final brush = widget.brushMode;` as the first line, and replace the header row's first child (the `Material` with the `InkWell` and `Icons.arrow_back`) with:

```dart
                    if (brush != null)
                      BrushCloseButton(onTap: brush.onClose)
                    else
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            AudioService().stopVoice();
                            Navigator.of(context).pop();
                          },
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
```

Replace the scroll view's padding with:

```dart
                child: SingleChildScrollView(
                  // Brush mode: room under the last planet for GO.
                  padding: EdgeInsets.only(
                    bottom: 40.0 + (brush == null ? 0.0 : kBrushGoClearance),
                    top: 8,
                  ),
                  child: _buildAdventurePath(context),
                ),
```

In `_buildAdventurePath`, give the `_PlanetNode` a key and the highlight (its `onTap` stays exactly as it is):

```dart
          child: _PlanetNode(
            key: ValueKey('planet_${world.id}'),
            world: world,
            isUnlocked: isUnlocked,
            isCurrent: isCurrent,
            isCompleted: isCompleted,
            progress: progress,
            highlighted: world.id == _highlightId,
            glowKey: _glowKey,
            onTap: () {
```

Replace `_setCurrentWorld` with:

```dart
  Future<void> _setCurrentWorld(WorldData world) async {
    await _worldService.setCurrentWorld(world.id);
    await _loadData();
    // The planet node already shows the new current planet; the voice was
    // played by onTap. Brush mode: the steps read the new world back.
    widget.brushMode?.onChanged(
      const BrushChange.selected(GoalCategory.world),
    );
  }
```

In `_PlanetNode`, add `super.key` and two parameters:

```dart
  const _PlanetNode({
    super.key,
    required this.world,
    required this.isUnlocked,
    required this.isCurrent,
    required this.isCompleted,
    required this.progress,
    required this.onTap,
    this.highlighted = false,
    this.glowKey,
  });
```

with the fields

```dart
  /// Brush mode: the planet that opens next.
  final bool highlighted;
  final Key? glowKey;
```

In `_PlanetNodeState.build`, after `final opacity = ...;` add the planet image as a local:

```dart
    final planet = SizedBox(
      width: planetSize,
      height: planetSize,
      child: ColorFiltered(
        colorFilter: widget.isUnlocked
            ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
            : ColorFilter.mode(
                Colors.black.withValues(alpha: 0.35),
                BlendMode.srcATop,
              ),
        child: ClipOval(
          child: Image.asset(widget.world.imagePath, fit: BoxFit.cover),
        ),
      ),
    );
```

and in the `Stack` that held the `// Planet image` `SizedBox`, replace that `SizedBox(...)` with:

```dart
                  // Planet image (brush mode: the planet that opens next
                  // glows)
                  if (widget.highlighted)
                    GoalGlow(key: widget.glowKey, circle: true, child: planet)
                  else
                    planet,
```

- [ ] **Step 5: Run the new and the existing Map tests**

Run: `flutter test test/screens/world_map_brush_mode_test.dart test/screens/world_map_screen_test.dart`
Expected: all PASS.

- [ ] **Step 6: Format, analyze, full suite**

Run: `dart format lib test && dart analyze && flutter test`
Expected: "No issues found!"; all tests pass.

- [ ] **Step 7: Commit**

```bash
git add lib/screens/world_map_screen.dart test/screens/world_map_brush_mode_test.dart
git commit -m "feat(map): brush mode for the Map page

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01STWCtX8pE4SLhUiiBxVG9M"
```

---

### Task 4: The steps on the real pages

**Files:**
- Rewrite: `lib/screens/pre_brush_screen.dart`
- Rewrite: `test/screens/pre_brush_screen_test.dart`
- Modify: `test/screens/home_screen_test.dart`, `test/screens/home_flame_test.dart` (knob rename only)

**Interfaces:**
- Consumes: Task 1 (`BrushMode`, `BrushChange`, `BrushPing`, `kBrushGoClearance`, `GoButton`, `GoalGlow`, `logGoalUnlocked(source:)`), Task 2 (`HeroShopScreen(brushMode:)`, `HeroShopScreen.debugAnalytics`, keys `evo_cell_*`, `weapon_card_*`, tab reporting), Task 3 (`WorldMapScreen(brushMode:)`, keys `planet_*`), `GoalService`/`Goal`/`GoalCategory`, `AudioService` (`playVoice`, `playSfx`, `stopVoice`, `voicePipelineActiveNotifier`, `evolutionPickerVoiceFor`, `weaponPickerVoiceFor`, `starsLeftVoiceFor`, `brushesLeftVoiceFor`).
- Produces: `PreBrushScreen` with `@visibleForTesting` statics `idleAdvance` (8 s), `maxVoiceWait` (12 s), `launchDelay` (400 ms), `maxLaunchWait` (3 s), `debugBrushingBuilder`, `debugAnalytics`; `enum PreBrushStep { hero, weapon, world }`; keys `ValueKey('prebrush_go')` (the GO button) and `ValueKey('prebrush_step_<hero|weapon|world>')` (an empty marker for the current step). The knobs `minStep`, `maxStep`, `maxBriefingStep` and `idleAfterTouch` are gone.

Notes for the implementer (why the code is shaped this way):
- A dialog over the steps (purchase confirmation, unlock celebration) makes the steps' route not current. `ModalRoute.isCurrentOf(context)` in `didChangeDependencies` re-runs when that changes; that is how the count waits for dialogs without the pages reporting them.
- GO is the Scaffold's floating button: the page's floating snack bars ("2 more stars") then appear above it, and the page's own Scaffold, nested inside, doesn't show them a second time. GO is built from the first frame (disabled until the first step starts): a floating button that first appears after the first frame scales in from zero, and a tap during that scale misses it.
- The `AnimatedSwitcher`'s `transitionBuilder` must be a new closure every build. Flutter only rebuilds the outgoing page's transition when the builder changes, and the outgoing page must get the slide-out-left tween.
- A page that goes away mid-scroll never sends `ScrollEndNotification`; `_scrollQuiet` (400 ms without a scroll notification) releases the hold.

- [ ] **Step 1: Write the failing tests**

Replace the whole of `test/screens/pre_brush_screen_test.dart` with:

```dart
// test/screens/pre_brush_screen_test.dart
//
// The brush steps on the real pages (spec
// docs/superpowers/specs/2026-10-13-brush-steps-on-real-pages-design.md):
// HEROES tab → WEAPONS tab → Map, GO and the idle count, dialogs, the
// background, X, "Let's fight!" and the voice timelines.
import 'dart:async';

import 'package:brush_quest/screens/brush_mode.dart';
import 'package:brush_quest/screens/brushing_screen.dart';
import 'package:brush_quest/screens/hero_shop_screen.dart';
import 'package:brush_quest/screens/pre_brush_screen.dart';
import 'package:brush_quest/screens/world_map_screen.dart';
import 'package:brush_quest/services/analytics_service.dart';
import 'package:brush_quest/services/audio_service.dart';
import 'package:brush_quest/services/streak_service.dart';
import 'package:brush_quest/widgets/goal_glow.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/fake_audio_service.dart';
import '../audio/timed_fake_audio_service.dart';

/// Records the events the steps send (AnalyticsService is a no-op on the
/// test host, so the tests inject an Android-mode one around this fake).
class _RecordingAnalytics extends Fake implements FirebaseAnalytics {
  final List<Map<String, Object?>> events = [];

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {}

  @override
  Future<void> setConsent({
    bool? adStorageConsentGranted,
    bool? analyticsStorageConsentGranted,
    bool? adPersonalizationSignalsConsentGranted,
    bool? adUserDataConsentGranted,
    bool? functionalityStorageConsentGranted,
    bool? personalizationStorageConsentGranted,
    bool? securityStorageConsentGranted,
  }) async {}

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {
    events.add({'name': name, ...?parameters});
  }
}

/// Records route replacements (brushing replaces the pre-brush screen).
class _ReplaceLog extends NavigatorObserver {
  final replaced = <Route<dynamic>?>[];

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    replaced.add(newRoute);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeAudioService audio;
  late _RecordingAnalytics recorder;
  bool? launchedWithIntro;

  setUpAll(() async {
    // The hand-off group builds the real BrushingScreen (Firebase, audio
    // players, wakelock), and tearDown's `testInstance = null` builds a real
    // AudioService, whose players talk to the audioplayers channels.
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers.global'),
        (call) async => 1,
      )
      ..setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers'),
        (call) async => 1,
      )
      ..setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/wakelock_plus'),
        (call) async => true,
      );
  });

  setUp(() async {
    audio = FakeAudioService();
    AudioService.testInstance = audio;
    recorder = _RecordingAnalytics();
    final analytics = AnalyticsService.forTesting(
      isAndroid: true,
      analytics: recorder,
    );
    await analytics.init();
    PreBrushScreen.debugAnalytics = analytics;
    HeroShopScreen.debugAnalytics = analytics;
    launchedWithIntro = null;
    PreBrushScreen.idleAdvance = const Duration(seconds: 1);
    PreBrushScreen.launchDelay = const Duration(milliseconds: 50);
    PreBrushScreen.debugBrushingBuilder = ({required showWorldIntro}) {
      launchedWithIntro = showWorldIntro;
      return const Scaffold(body: Text('BRUSHING'));
    };
  });

  tearDown(() {
    AudioService.testInstance = null;
    PreBrushScreen.debugBrushingBuilder = null;
    PreBrushScreen.debugAnalytics = null;
    HeroShopScreen.debugAnalytics = null;
    PreBrushScreen.idleAdvance = const Duration(seconds: 8);
    PreBrushScreen.maxVoiceWait = const Duration(seconds: 12);
    PreBrushScreen.launchDelay = const Duration(milliseconds: 400);
    PreBrushScreen.maxLaunchWait = const Duration(seconds: 3);
    StreakService.isPurchasing = false;
  });

  // A child on his fifth brush: 3 stars, Blaze and the Star Blaster, 2 of
  // Candy Crater's 5 missions. Goals: Frost (5), Flame Sword (5), and Slime
  // Swamp, which opens after 3 more brushes.
  final returningKid = <String, Object>{
    'total_brushes': 4,
    'star_wallet': 3,
    'unlocked_heroes': ['blaze'],
    'selected_hero': 'blaze',
    'unlocked_weapons': ['star_blaster'],
    'selected_weapon': 'star_blaster',
    'current_world': 'candy_crater',
    'world_progress_candy_crater': 2,
    'muted': false,
  };

  Map<String, Object> kid(Map<String, Object> changes) => {
    ...returningKid,
    ...changes,
  };

  // Every hero but Nova, and Blaze maxed: the hero goal is Nova (20), the
  // last row of the list.
  final farGoal = kid({
    'unlocked_heroes': ['blaze', 'frost', 'bolt', 'shadow', 'leaf'],
    'unlocked_evolutions': ['blaze_stage2', 'blaze_stage3'],
    'evolution_stage_blaze': 3,
  });

  final go = find.byKey(const ValueKey('prebrush_go'));
  Finder stepIs(PreBrushStep step) =>
      find.byKey(ValueKey('prebrush_step_${step.name}'));
  List<String> voices() => audio.playedVoiceLines;
  Finder glowOn(String key) => find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(GoalGlow),
  );
  int tabIndex(WidgetTester tester) =>
      tester.widget<TabBar>(find.byType(TabBar)).controller!.index;
  ScrollableState heroList(WidgetTester tester) =>
      tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
  Iterable<Map<String, Object?>> eventsNamed(String name) =>
      recorder.events.where((e) => e['name'] == name);

  Future<void> useSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    Map<String, Object> prefs,
  ) async {
    SharedPreferences.setMockInitialValues(prefs);
    await useSurface(tester);
    await tester.pumpWidget(const MaterialApp(home: PreBrushScreen()));
    await tester.pump(); // load
    await tester.pump(); // the first page
  }

  /// Pumps [total] in 50 ms frames, so frame-driven animations (the tab
  /// slide, the page slide, the reveal scroll) run as on a device.
  Future<void> pumpFor(WidgetTester tester, Duration total) async {
    const frame = Duration(milliseconds: 50);
    var left = total;
    while (left > Duration.zero) {
      final next = left < frame ? left : frame;
      await tester.pump(next);
      left -= next;
    }
  }

  /// Pumps 50 ms frames until [done]; returns how long that took.
  Future<Duration> pumpUntil(
    WidgetTester tester,
    bool Function() done, {
    Duration max = const Duration(seconds: 20),
  }) async {
    var waited = Duration.zero;
    while (!done()) {
      if (waited >= max) fail('not done after $max');
      await tester.pump(const Duration(milliseconds: 50));
      waited += const Duration(milliseconds: 50);
    }
    return waited;
  }

  Future<Duration> pumpUntilFound(WidgetTester tester, Finder finder) =>
      pumpUntil(tester, () => finder.evaluate().isNotEmpty);

  Future<void> tapGo(WidgetTester tester) async {
    await tester.tap(go);
    await tester.pump();
  }

  /// Opens the screen from a stand-in Home, so X has somewhere to go back to.
  Future<void> openFromHome(WidgetTester tester) async {
    await useSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: IconButton(
                key: const ValueKey('open'),
                icon: const Icon(Icons.play_arrow),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PreBrushScreen(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // route transition
  }

  /// Installs a voice channel that takes time, with its clock on the test's
  /// fake time. Lines not in [lengths] take 2 s.
  TimedFakeAudioService useTimedVoices(
    WidgetTester tester, {
    Map<String, Duration> lengths = const {},
  }) {
    final timed = TimedFakeAudioService(lengths: lengths);
    final start = tester.binding.clock.now();
    timed.clock = () => tester.binding.clock.now().difference(start);
    AudioService.testInstance = timed;
    audio = timed;
    return timed;
  }

  /// Runs [body] with debugPrint collected, so expected error logs are
  /// checked rather than printed.
  Future<List<String?>> collectDebugPrint(Future<void> Function() body) async {
    final printed = <String?>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => printed.add(message);
    try {
      await body();
    } finally {
      debugPrint = original;
    }
    return printed;
  }

  /// Taps Frost's cell (5 stars) and waits for the purchase dialog.
  Future<void> openFrostPurchase(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('evo_cell_frost_stage1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Get FROST?'), findsOneWidget);
  }

  // ── The three pages ───────────────────────────────────────────

  testWidgets('opens on the HEROES tab with the hero line and the goal', (
    tester,
  ) async {
    await pumpScreen(tester, returningKid);
    expect(stepIs(PreBrushStep.hero), findsOneWidget);
    expect(find.byType(HeroShopScreen), findsOneWidget);
    expect(tabIndex(tester), 0);
    // Blaze's picker line, then Frost (5) minus the wallet (3).
    expect(voices(), ['voice_picker_hero_blaze.mp3', 'voice_stars_left_2.mp3']);
    expect(glowOn('evo_cell_frost_stage1'), findsOneWidget);
    expect(find.byType(GoalGlow), findsOneWidget);
    expect(find.byKey(const ValueKey('brush_close')), findsOneWidget);
    expect(
      find.descendant(of: go, matching: find.byIcon(Icons.arrow_forward)),
      findsOneWidget,
    );
  });

  testWidgets('GO: WEAPONS on the same page, then the Map, then the fight', (
    tester,
  ) async {
    await pumpScreen(tester, returningKid);
    final shop = tester.state(find.byType(HeroShopScreen));

    await tapGo(tester);
    expect(stepIs(PreBrushStep.weapon), findsOneWidget);
    expect(audio.playedSfx, ['whoosh.mp3']);
    // The Star Blaster's line, then the Flame Sword (5) minus 3.
    expect(voices().sublist(2), [
      'voice_picker_weapon_star_blaster.mp3',
      'voice_stars_left_2.mp3',
    ]);
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(tabIndex(tester), 1);
    expect(tester.state(find.byType(HeroShopScreen)), same(shop));
    expect(glowOn('weapon_card_flame_sword'), findsOneWidget);

    await tapGo(tester);
    expect(stepIs(PreBrushStep.world), findsOneWidget);
    // Candy Crater's line, then 3 of its 5 missions to go.
    expect(voices().sublist(4), [
      'voice_world_candy_crater.mp3',
      'voice_brushes_left_3.mp3',
    ]);
    await pumpFor(tester, const Duration(milliseconds: 500)); // the slide
    expect(find.byType(WorldMapScreen), findsOneWidget);
    expect(find.byType(HeroShopScreen), findsNothing);
    expect(glowOn('planet_slime_swamp'), findsOneWidget); // opens next
    expect(
      find.descendant(of: go, matching: find.byIcon(Icons.rocket_launch)),
      findsOneWidget,
    );

    await tapGo(tester);
    expect(voices().last, 'voice_lets_fight.mp3');
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.text('BRUSHING'), findsOneWidget);
    expect(launchedWithIntro, isFalse);
  });

  testWidgets('each step moves on by itself once quiet, then brushing', (
    tester,
  ) async {
    await pumpScreen(tester, returningKid);
    final toWeapon = await pumpUntilFound(tester, stepIs(PreBrushStep.weapon));
    expect(toWeapon, greaterThanOrEqualTo(PreBrushScreen.idleAdvance));
    expect(
      toWeapon,
      lessThan(PreBrushScreen.idleAdvance + const Duration(milliseconds: 200)),
    );
    // The tab slide (300 ms) holds the count, then the whole idle time.
    final toWorld = await pumpUntilFound(tester, stepIs(PreBrushStep.world));
    expect(
      toWorld,
      greaterThanOrEqualTo(
        PreBrushScreen.idleAdvance + const Duration(milliseconds: 250),
      ),
    );
    final toFight = await pumpUntil(
      tester,
      () => voices().last == 'voice_lets_fight.mp3',
    );
    expect(toFight, greaterThanOrEqualTo(PreBrushScreen.idleAdvance));
    await pumpUntilFound(tester, find.text('BRUSHING'));
    expect(launchedWithIntro, isFalse);
    expect(audio.playedSfx, isEmpty); // the whoosh is GO's
  });

  testWidgets('an affordable goal: "Tap to unlock it!", never "Brush to..."', (
    tester,
  ) async {
    await pumpScreen(tester, kid({'star_wallet': 6}));
    expect(voices().last, 'voice_tap_to_unlock.mp3'); // Frost costs 5
    await tapGo(tester);
    expect(voices().last, 'voice_tap_to_unlock.mp3'); // Flame Sword costs 5
    expect(voices(), isNot(contains('voice_ready_to_unlock.mp3')));
  });

  testWidgets('everything owned: "You have them all" and no glow', (
    tester,
  ) async {
    await pumpScreen(tester, {
      'total_brushes': 400,
      'star_wallet': 0,
      'unlocked_heroes': ['blaze', 'frost', 'bolt', 'shadow', 'leaf', 'nova'],
      'selected_hero': 'nova',
      'unlocked_evolutions': ['nova_stage2', 'nova_stage3'],
      'evolution_stage_nova': 3,
      'unlocked_weapons': [
        'star_blaster',
        'flame_sword',
        'ice_hammer',
        'lightning_wand',
        'vine_whip',
        'cosmic_burst',
      ],
      'selected_weapon': 'cosmic_burst',
      'current_world': 'dark_dimension',
      'world_progress_candy_crater': 5,
      'world_progress_slime_swamp': 5,
      'world_progress_sugar_volcano': 6,
      'world_progress_shadow_nebula': 6,
      'world_progress_cavity_fortress': 7,
      'world_progress_frozen_tundra': 7,
      'world_progress_toxic_jungle': 7,
      'world_progress_crystal_cave': 8,
      'world_progress_storm_citadel': 8,
      'world_progress_dark_dimension': 10,
      'muted': false,
    });
    expect(voices(), [
      'voice_picker_evo_nova_stage3.mp3',
      'voice_have_them_all.mp3',
    ]);
    expect(find.byType(GoalGlow), findsNothing);
    await tapGo(tester);
    expect(voices().last, 'voice_have_them_all.mp3');
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(find.byType(GoalGlow), findsNothing);
    await tapGo(tester);
    expect(voices().sublist(4), [
      'voice_world_dark_dimension.mp3',
      'voice_have_them_all.mp3',
    ]);
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.byType(GoalGlow), findsNothing);
  });

  // ── Tabs ──────────────────────────────────────────────────────

  testWidgets('tapping a tab is a step change, with that step\'s lines', (
    tester,
  ) async {
    await pumpScreen(tester, returningKid);
    audio.resetTracking();
    await tester.tap(find.text('WEAPONS'));
    await tester.pump();
    expect(stepIs(PreBrushStep.weapon), findsOneWidget);
    expect(voices(), [
      'voice_picker_weapon_star_blaster.mp3',
      'voice_stars_left_2.mp3',
    ]);
    await pumpFor(tester, const Duration(milliseconds: 400));
    audio.resetTracking();
    await tester.tap(find.text('HEROES'));
    await tester.pump();
    expect(stepIs(PreBrushStep.hero), findsOneWidget);
    expect(voices(), ['voice_picker_hero_blaze.mp3', 'voice_stars_left_2.mp3']);
    expect(
      audio
          .callsFor('playVoice')
          .where((c) => '${c.args['fileName']}'.startsWith('voice_tab_')),
      isEmpty,
    );
  });

  testWidgets('a swipe to the other tab is a step change too', (tester) async {
    await pumpScreen(tester, returningKid);
    await tester.fling(find.byType(TabBarView), const Offset(-300, 0), 1500);
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(stepIs(PreBrushStep.weapon), findsOneWidget);
    expect(tabIndex(tester), 1);
    expect(voices().sublist(2), [
      'voice_picker_weapon_star_blaster.mp3',
      'voice_stars_left_2.mp3',
    ]);
  });

  testWidgets('a step change clears the page\'s snack bars', (tester) async {
    await pumpScreen(tester, returningKid);
    // Bolt (8) is out of reach with 3 stars: the page's "5 more" snack bar.
    await tester.tap(find.byKey(const ValueKey('evo_cell_bolt_stage1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('5 more'), findsOneWidget);
    await tapGo(tester);
    await tester.pump();
    expect(find.text('5 more'), findsNothing);
  });

  // ── What holds the idle count ─────────────────────────────────

  testWidgets('a touch holds the count; lifting it starts again from zero', (
    tester,
  ) async {
    await pumpScreen(tester, returningKid);
    await pumpFor(tester, const Duration(milliseconds: 700));
    final finger = await tester.startGesture(
      tester.getCenter(find.text('HEROES & WEAPONS')),
    );
    await pumpFor(tester, const Duration(seconds: 2));
    expect(stepIs(PreBrushStep.hero), findsOneWidget);
    await finger.up();
    final waited = await pumpUntilFound(tester, stepIs(PreBrushStep.weapon));
    expect(waited, greaterThanOrEqualTo(PreBrushScreen.idleAdvance));
  });

  testWidgets('a cancelled touch lets the count run again', (tester) async {
    await pumpScreen(tester, returningKid);
    final finger = await tester.startGesture(
      tester.getCenter(find.text('HEROES & WEAPONS')),
    );
    await pumpFor(tester, const Duration(seconds: 2));
    expect(stepIs(PreBrushStep.hero), findsOneWidget);
    await finger.cancel();
    final waited = await pumpUntilFound(tester, stepIs(PreBrushStep.weapon));
    expect(waited, greaterThanOrEqualTo(PreBrushScreen.idleAdvance));
  });

  testWidgets('a scroll holds the count until it ends', (tester) async {
    await pumpScreen(tester, returningKid);
    unawaited(
      heroList(tester).position.animateTo(
        300,
        duration: const Duration(seconds: 2),
        curve: Curves.linear,
      ),
    );
    await pumpFor(tester, const Duration(milliseconds: 1900));
    expect(stepIs(PreBrushStep.hero), findsOneWidget);
    final waited = await pumpUntilFound(tester, stepIs(PreBrushStep.weapon));
    // The last 100 ms of the scroll, then the whole idle time.
    expect(waited, greaterThanOrEqualTo(PreBrushScreen.idleAdvance));
  });

  testWidgets('a scroll that never sends its end does not hold the step', (
    tester,
  ) async {
    await pumpScreen(tester, returningKid);
    // As when a page goes away mid-fling: a start, and no end ever.
    final page = tester.element(find.text('HEROES & WEAPONS'));
    ScrollStartNotification(
      metrics: heroList(tester).position.copyWith(),
      context: page,
    ).dispatch(page);
    final waited = await pumpUntilFound(tester, stepIs(PreBrushStep.weapon));
    expect(waited, greaterThanOrEqualTo(PreBrushScreen.idleAdvance));
    expect(
      waited,
      lessThan(PreBrushScreen.idleAdvance + const Duration(milliseconds: 700)),
    );
  });

  testWidgets('a dialog holds the count; it starts again once it closes', (
    tester,
  ) async {
    await pumpScreen(tester, kid({'star_wallet': 6}));
    await openFrostPurchase(tester);
    await pumpFor(tester, const Duration(seconds: 3));
    expect(stepIs(PreBrushStep.hero), findsOneWidget);
    await tester.tap(find.text('Not yet'));
    await tester.pump();
    final waited = await pumpUntilFound(tester, stepIs(PreBrushStep.weapon));
    expect(waited, greaterThanOrEqualTo(PreBrushScreen.idleAdvance));
  });

  testWidgets('back from the background with a dialog still open: it waits', (
    tester,
  ) async {
    await pumpScreen(tester, kid({'star_wallet': 6}));
    await openFrostPurchase(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpFor(tester, const Duration(seconds: 3));
    expect(stepIs(PreBrushStep.hero), findsOneWidget);
    expect(find.text('Get FROST?'), findsOneWidget);
    await tester.tap(find.text('Not yet'));
    await tester.pump();
    await pumpUntilFound(tester, stepIs(PreBrushStep.weapon));
  });

  testWidgets('a voice that never ends cannot hold a step: past the cap', (
    tester,
  ) async {
    PreBrushScreen.maxVoiceWait = const Duration(seconds: 2);
    await pumpScreen(tester, returningKid);
    audio.voicePipelineActiveNotifier.value = true; // stuck
    await pumpFor(tester, const Duration(milliseconds: 2800));
    expect(stepIs(PreBrushStep.hero), findsOneWidget);
    final waited = await pumpUntilFound(tester, stepIs(PreBrushStep.weapon));
    expect(waited, lessThan(const Duration(milliseconds: 600)));
  });

  // ── On the page: unlocks, picks, the glow ─────────────────────

  testWidgets('an unlock: celebrated, equipped, the glow moves, pre_brush', (
    tester,
  ) async {
    PreBrushScreen.idleAdvance = const Duration(seconds: 30);
    await pumpScreen(tester, kid({'star_wallet': 6}));
    await openFrostPurchase(tester);
    await tester.tap(find.text('YES!'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('FROST UNLOCKED!'), findsOneWidget);
    expect(voices().last, 'voice_intro_hero_frost.mp3');
    final heard = voices().length;
    await pumpFor(tester, const Duration(seconds: 7)); // closes after 6 s
    expect(find.text('FROST UNLOCKED!'), findsNothing);
    final saved = await SharedPreferences.getInstance();
    expect(saved.getString('selected_hero'), 'frost');
    expect(saved.getInt('star_wallet'), 1);
    // Bolt (8) is now the closest: Frost's upgrade costs 12.
    expect(glowOn('evo_cell_bolt_stage1'), findsOneWidget);
    expect(find.byType(GoalGlow), findsOneWidget);
    expect(voices(), hasLength(heard)); // no extra line after an unlock
    expect(eventsNamed('goal_unlocked'), [
      {
        'name': 'goal_unlocked',
        'category': 'hero',
        'item': 'frost',
        'source': 'pre_brush',
      },
    ]);
    expect(eventsNamed('pre_brush_change'), [
      {'name': 'pre_brush_change', 'category': 'hero'},
    ]);
    expect(stepIs(PreBrushStep.hero), findsOneWidget);
  });

  testWidgets('a pick is a pre_brush_change; the steps are no shop visit', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      kid({
        'unlocked_weapons': ['star_blaster', 'flame_sword'],
      }),
    );
    await tapGo(tester);
    await pumpFor(tester, const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('weapon_card_flame_sword')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(voices().last, 'voice_picker_weapon_flame_sword.mp3'); // the page's
    expect(eventsNamed('pre_brush_change'), [
      {'name': 'pre_brush_change', 'category': 'weapon'},
    ]);
    expect(eventsNamed('shop_visit'), isEmpty);
    final saved = await SharedPreferences.getInstance();
    expect(saved.getString('selected_weapon'), 'flame_sword');
  });

  testWidgets('a goal far down the list scrolls into view after the lines', (
    tester,
  ) async {
    await pumpScreen(tester, farGoal);
    expect(glowOn('evo_cell_nova_stage1'), findsOneWidget);
    await pumpFor(tester, const Duration(milliseconds: 800));
    expect(heroList(tester).position.pixels, greaterThan(0));
    final glow = tester.getRect(find.byType(GoalGlow));
    final list = tester.getRect(find.byType(ListView));
    expect(glow.top, greaterThanOrEqualTo(list.top));
    expect(glow.bottom, lessThanOrEqualTo(list.bottom - kBrushGoClearance));
  });

  testWidgets('a touch while the lines play: no scroll afterwards', (
    tester,
  ) async {
    final timed = useTimedVoices(tester); // each line 2 s
    await pumpScreen(tester, farGoal);
    final finger = await tester.startGesture(
      tester.getCenter(find.text('HEROES & WEAPONS')),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await finger.up();
    await pumpFor(tester, const Duration(milliseconds: 4500)); // lines over
    expect(timed.voices.every((v) => v.endedAt != null), isTrue);
    expect(heroList(tester).position.pixels, 0);
  });

  testWidgets('a saved hero or weapon the game does not know: still a line', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      kid({'selected_hero': 'robo', 'selected_weapon': 'laser_sword'}),
    );
    expect(voices().first, 'voice_great_choice.mp3');
    expect(tester.takeException(), isNull);
    await tapGo(tester);
    expect(voices()[2], 'voice_awesome.mp3');
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.byType(HeroShopScreen), findsOneWidget);
  });

  testWidgets('the pages never stop the voice while the steps run', (
    tester,
  ) async {
    await pumpScreen(tester, returningKid);
    await tapGo(tester);
    await pumpFor(tester, const Duration(milliseconds: 400));
    await tapGo(tester);
    await pumpFor(tester, const Duration(milliseconds: 600)); // shop gone
    expect(find.byType(HeroShopScreen), findsNothing);
    expect(audio.callsFor('stopVoice'), isEmpty);
    await tapGo(tester);
    await pumpFor(tester, const Duration(seconds: 1)); // the Map gone too
    expect(find.byType(WorldMapScreen), findsNothing);
    expect(audio.callsFor('stopVoice'), isEmpty);
  });

  // ── The background ────────────────────────────────────────────

  testWidgets('a pause stops the count; back, it starts again from zero', (
    tester,
  ) async {
    await pumpScreen(tester, returningKid);
    await pumpFor(tester, const Duration(milliseconds: 700));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 3));
    expect(stepIs(PreBrushStep.hero), findsOneWidget);
    expect(audio.callsFor('stopVoice'), isNotEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final waited = await pumpUntilFound(tester, stepIs(PreBrushStep.weapon));
    expect(waited, greaterThanOrEqualTo(PreBrushScreen.idleAdvance));
  });

  testWidgets('a resume with no pause before it changes nothing', (
    tester,
  ) async {
    await pumpScreen(tester, returningKid);
    await pumpFor(tester, const Duration(milliseconds: 600));
    final heard = voices().length;
    // The notification shade or a system dialog: inactive, then resumed.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(voices(), hasLength(heard));
    // The first count ran on (about 400 ms left), no fresh start.
    final waited = await pumpUntilFound(tester, stepIs(PreBrushStep.weapon));
    expect(waited, lessThan(const Duration(milliseconds: 600)));
  });

  testWidgets('a pause after "Let\'s fight!" launches brushing on resume', (
    tester,
  ) async {
    // Frames stop while paused, so a route pushed in the background can't be
    // seen with a finder: watch the navigator instead.
    final routes = _ReplaceLog();
    SharedPreferences.setMockInitialValues(returningKid);
    await useSurface(tester);
    await tester.pumpWidget(
      MaterialApp(home: const PreBrushScreen(), navigatorObservers: [routes]),
    );
    await tester.pump();
    await tester.pump();
    await tapGo(tester);
    await tapGo(tester);
    await tapGo(tester);
    expect(voices().last, 'voice_lets_fight.mp3');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 5)); // past every launch timer
    expect(routes.replaced, isEmpty); // nothing launched in the background
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(routes.replaced, hasLength(1));
    expect(find.text('BRUSHING'), findsOneWidget);
    expect(launchedWithIntro, isFalse);
  });

  // ── X, back, "Let's fight!" and the launch ────────────────────

  testWidgets('X goes back to Home with his pick kept; then nothing plays', (
    tester,
  ) async {
    PreBrushScreen.idleAdvance = const Duration(seconds: 30);
    SharedPreferences.setMockInitialValues(
      kid({
        'unlocked_heroes': ['blaze', 'frost'],
      }),
    );
    await openFromHome(tester);
    await tester.tap(find.byKey(const ValueKey('evo_cell_frost_stage1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(voices().last, 'voice_picker_hero_frost.mp3');
    final heard = voices().length;
    await tester.tap(find.byKey(const ValueKey('brush_close')));
    await tester.pumpAndSettle();
    expect(find.byType(PreBrushScreen), findsNothing);
    expect(find.byKey(const ValueKey('open')), findsOneWidget);
    expect(audio.callsFor('stopVoice'), isNotEmpty);
    final saved = await SharedPreferences.getInstance();
    expect(saved.getString('selected_hero'), 'frost');
    await tester.pump(const Duration(seconds: 35)); // past every step timer
    expect(voices(), hasLength(heard));
    expect(launchedWithIntro, isNull);
  });

  testWidgets('back after "Let\'s fight!" goes Home; brushing never starts', (
    tester,
  ) async {
    PreBrushScreen.launchDelay = const Duration(milliseconds: 400);
    SharedPreferences.setMockInitialValues(returningKid);
    await openFromHome(tester);
    await tapGo(tester);
    await tapGo(tester);
    await tapGo(tester);
    expect(voices().last, 'voice_lets_fight.mp3');
    await tester.pump(const Duration(milliseconds: 200)); // inside the delay
    unawaited(tester.state<NavigatorState>(find.byType(Navigator)).maybePop());
    await tester.pumpAndSettle();
    expect(find.text('BRUSHING'), findsNothing);
    expect(find.byKey(const ValueKey('open')), findsOneWidget);
    expect(
      tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
      isFalse,
    );
    expect(launchedWithIntro, isNull);
  });

  testWidgets('after "Let\'s fight!" a tap on the page changes nothing', (
    tester,
  ) async {
    // Slime Swamp is open too.
    await pumpScreen(tester, kid({'world_progress_candy_crater': 5}));
    await tapGo(tester);
    await tapGo(tester);
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tapGo(tester);
    audio.voicePipelineActiveNotifier.value = true; // hold the launch
    final heard = voices().length;
    await tester.tap(
      find.byKey(const ValueKey('planet_slime_swamp')),
      warnIfMissed: false, // ignored on purpose
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(voices().sublist(heard), isEmpty);
    final saved = await SharedPreferences.getInstance();
    expect(saved.getString('current_world'), 'candy_crater');
    audio.voicePipelineActiveNotifier.value = false;
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.text('BRUSHING'), findsOneWidget);
  });

  testWidgets('"Let\'s fight!" plays out before brushing starts', (
    tester,
  ) async {
    await pumpScreen(tester, returningKid);
    await tapGo(tester);
    await tapGo(tester);
    await tapGo(tester);
    audio.voicePipelineActiveNotifier.value = true; // "Let's fight!" playing
    await tester.pump(const Duration(milliseconds: 500)); // past the delay
    expect(find.text('BRUSHING'), findsNothing);
    expect(audio.callsFor('stopVoice'), isEmpty);
    audio.voicePipelineActiveNotifier.value = false; // the line ends
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.text('BRUSHING'), findsOneWidget);
  });

  testWidgets('a "Let\'s fight!" that never ends still launches at the cap', (
    tester,
  ) async {
    PreBrushScreen.maxLaunchWait = const Duration(milliseconds: 500);
    await pumpScreen(tester, returningKid);
    await tapGo(tester);
    await tapGo(tester);
    await tapGo(tester);
    audio.voicePipelineActiveNotifier.value = true; // stuck
    await tester.pump(const Duration(milliseconds: 400)); // delay + part of cap
    expect(find.text('BRUSHING'), findsNothing);
    await tester.pump(const Duration(milliseconds: 300)); // the cap
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('BRUSHING'), findsOneWidget);
  });

  testWidgets('a load error goes straight to brushing with its world intro', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'total_brushes': 3,
      // A string where a number belongs: getInt throws a TypeError.
      'world_progress_candy_crater': 'two',
    });
    final printed = await collectDebugPrint(() async {
      await tester.pumpWidget(const MaterialApp(home: PreBrushScreen()));
      await tester.pumpAndSettle();
    });
    expect(find.text('BRUSHING'), findsOneWidget);
    expect(launchedWithIntro, isTrue);
    expect(printed.single, startsWith('PreBrush load failed'));
    expect(eventsNamed('pre_brush_skipped'), [
      {'name': 'pre_brush_skipped', 'reason': 'error'},
    ]);
  });

  // ── Voice timelines (a voice channel that takes time) ─────────

  testWidgets('timeline: a step\'s lines in turn, and the count waits', (
    tester,
  ) async {
    final timed = useTimedVoices(
      tester,
      lengths: const {
        'voice_picker_hero_blaze.mp3': Duration(milliseconds: 6008),
        'voice_stars_left_2.mp3': Duration(milliseconds: 993),
      },
    );
    await pumpScreen(tester, returningKid);
    await pumpFor(tester, const Duration(milliseconds: 7900)); // lines: 7.0 s
    expect(stepIs(PreBrushStep.hero), findsOneWidget);
    await pumpUntilFound(tester, stepIs(PreBrushStep.weapon));
    final picker = timed.voiceNamed('voice_picker_hero_blaze.mp3')!;
    final progress = timed.voiceNamed('voice_stars_left_2.mp3')!;
    expect(picker.cut, isFalse);
    expect(progress.startedAt, greaterThanOrEqualTo(picker.endedAt!));
    final quiet = timed.clock() - progress.endedAt!;
    expect(quiet, greaterThanOrEqualTo(PreBrushScreen.idleAdvance));
    expect(
      quiet,
      lessThan(PreBrushScreen.idleAdvance + const Duration(milliseconds: 100)),
    );
  });

  testWidgets('timeline: the count waits for a description he taps', (
    tester,
  ) async {
    final timed = useTimedVoices(
      tester,
      lengths: const {
        'voice_picker_weapon_ice_hammer.mp3': Duration(seconds: 8),
        'voice_shop_nudge_default.mp3': Duration(seconds: 2),
      },
    );
    await pumpScreen(tester, returningKid);
    await tapGo(tester); // WEAPONS: two lines of 2 s
    await pumpFor(tester, const Duration(milliseconds: 4100));
    // Ice Hammer (14) is out of reach: its line, then the nudge.
    await tester.tap(find.byKey(const ValueKey('weapon_card_ice_hammer')));
    await tester.pump();
    final tapAt = timed.clock();
    await pumpFor(tester, const Duration(milliseconds: 10900));
    expect(stepIs(PreBrushStep.weapon), findsOneWidget);
    await pumpUntilFound(tester, stepIs(PreBrushStep.world));
    expect(
      timed.clock() - tapAt,
      greaterThanOrEqualTo(const Duration(seconds: 11)),
    );
    expect(timed.voiceNamed('voice_picker_weapon_ice_hammer.mp3')!.cut, isFalse);
  });

  testWidgets('timeline: GO cuts the lines; the next ones never overlap', (
    tester,
  ) async {
    final timed = useTimedVoices(
      tester,
      lengths: const {'voice_picker_hero_blaze.mp3': Duration(seconds: 6)},
    );
    await pumpScreen(tester, returningKid);
    await pumpFor(tester, const Duration(seconds: 1));
    await tapGo(tester);
    await pumpFor(tester, const Duration(seconds: 5));
    final hero = timed.voiceNamed('voice_picker_hero_blaze.mp3')!;
    final weapon = timed.voiceNamed('voice_picker_weapon_star_blaster.mp3')!;
    expect(hero.cut, isTrue);
    // The hero step's "two more stars" never played: dropped from the queue.
    expect(timed.voiceNamed('voice_stars_left_2.mp3')!.dropped, isTrue);
    expect(weapon.startedAt, greaterThanOrEqualTo(hero.endedAt!));
    final played = timed.voices.where((v) => v.startedAt != null).toList();
    for (var i = 1; i < played.length; i++) {
      expect(
        played[i].startedAt,
        greaterThanOrEqualTo(played[i - 1].endedAt!),
        reason: '$played',
      );
    }
  });

  // ── Phones ────────────────────────────────────────────────────

  for (final phone in const [
    (size: Size(360, 640), top: 24.0, bottom: 48.0),
    (size: Size(430, 932), top: 59.0, bottom: 34.0),
  ]) {
    final name = '${phone.size.width.toInt()}x${phone.size.height.toInt()}';
    testWidgets('fits a $name phone on every step, GO on screen', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(phone.size);
      final ratio = tester.view.devicePixelRatio;
      final insets = FakeViewPadding(
        top: phone.top * ratio,
        bottom: phone.bottom * ratio,
      );
      tester.view
        ..padding = insets
        ..viewPadding = insets;
      addTearDown(() async {
        tester.view
          ..resetPadding()
          ..resetViewPadding();
        await tester.binding.setSurfaceSize(null);
      });
      SharedPreferences.setMockInitialValues(
        kid({
          'unlocked_heroes': ['blaze', 'frost', 'bolt'],
          'unlocked_weapons': ['star_blaster', 'flame_sword'],
        }),
      );
      await tester.pumpWidget(const MaterialApp(home: PreBrushScreen()));
      await tester.pump();
      await tester.pump();
      final screen = Offset.zero & phone.size;
      for (final step in PreBrushStep.values) {
        expect(stepIs(step), findsOneWidget);
        expect(tester.takeException(), isNull, reason: step.name);
        final goRect = tester.getRect(go);
        expect(
          screen.contains(goRect.topLeft) && screen.contains(goRect.bottomRight),
          isTrue,
          reason: '${step.name}: $goRect',
        );
        if (step != PreBrushStep.world) {
          await tapGo(tester);
          await pumpFor(tester, const Duration(milliseconds: 500));
        }
      }
    });
  }

  group('brushing hand-off', () {
    Future<void> pumpBrushing(
      WidgetTester tester, {
      required bool showWorldIntro,
    }) async {
      SharedPreferences.setMockInitialValues({
        'phase_duration': 20,
        'camera_enabled': false,
        'selected_hero': 'blaze',
        'selected_weapon': 'star_blaster',
        'current_world': 'candy_crater',
        'total_brushes': 4,
        'muted': false,
      });
      await tester.binding.setSurfaceSize(const Size(430, 932));
      // The game screen's own layout is not under test here.
      final onError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        onError?.call(details);
      };
      addTearDown(() => FlutterError.onError = onError);
      await tester.pumpWidget(
        MaterialApp(home: BrushingScreen(showWorldIntro: showWorldIntro)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    Future<void> disposeBrushing(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2)); // initState's 1.5 s delay
      await tester.binding.setSurfaceSize(null);
    }

    testWidgets('after the pre-brush steps brushing starts at the countdown', (
      tester,
    ) async {
      await pumpBrushing(tester, showWorldIntro: false);
      expect(voices(), isNot(contains('voice_world_candy_crater.mp3')));
      expect(voices(), contains('voice_three.mp3'));
      expect(find.text('3'), findsWidgets);
      await disposeBrushing(tester);
    });

    testWidgets('by default brushing still opens with the world intro', (
      tester,
    ) async {
      await pumpBrushing(tester, showWorldIntro: true);
      expect(voices(), contains('voice_world_candy_crater.mp3'));
      expect(voices(), isNot(contains('voice_three.mp3')));
      await disposeBrushing(tester);
    });
  });
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `flutter test test/screens/pre_brush_screen_test.dart`
Expected: FAIL — `PreBrushScreen.idleAdvance`, `maxVoiceWait` and `debugAnalytics` don't exist yet, and the old screen has no `prebrush_go` GO button or brush-mode pages.

- [ ] **Step 3: Rewrite `lib/screens/pre_brush_screen.dart`**

Replace the whole file with:

```dart
// lib/screens/pre_brush_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../services/goal_service.dart';
import '../services/hero_service.dart';
import '../services/weapon_service.dart';
import '../services/world_service.dart';
import '../widgets/go_button.dart';
import '../widgets/space_background.dart';
import 'brush_mode.dart';
import 'brushing_screen.dart';
import 'hero_shop_screen.dart';
import 'world_map_screen.dart';

enum PreBrushStep { hero, weapon, world }

/// What the steps speak and glow about: the child's choices and goals.
typedef _Loadout = ({
  String heroId,
  int heroStage,
  String weaponId,
  String worldId,
  Goal? heroGoal,
  Goal? weaponGoal,
  Goal? worldGoal,
});

/// Until the first read: what a new game starts with.
const _Loadout _starterLoadout = (
  heroId: 'blaze',
  heroStage: 1,
  weaponId: 'star_blaster',
  worldId: 'candy_crater',
  heroGoal: null,
  weaponGoal: null,
  worldGoal: null,
);

/// Hero → Weapon → World before each brush, on the real pages (spec
/// docs/superpowers/specs/2026-10-13-brush-steps-on-real-pages-design.md):
/// the Heroes & Weapons page on its HEROES tab, the same page on its
/// WEAPONS tab, then the Map, each in brush mode under a big GO. A step
/// also moves on by itself after [idleAdvance] with no touch, scroll or
/// dialog once the voice is quiet. After the Map: "Let's fight!", then
/// brushing.
class PreBrushScreen extends StatefulWidget {
  const PreBrushScreen({super.key});

  /// How long a quiet step waits before it moves on by itself.
  @visibleForTesting
  static Duration idleAdvance = const Duration(seconds: 8);

  /// A voice that never ends cannot hold a step: past this the idle count
  /// runs anyway. Longer than the longest real wait: a world line and its
  /// progress line (7.8 s), an unlock's intro line (8.8 s).
  @visibleForTesting
  static Duration maxVoiceWait = const Duration(seconds: 12);

  @visibleForTesting
  static Duration launchDelay = const Duration(milliseconds: 400);

  /// How long brushing waits, after [launchDelay], for "Let's fight!"
  /// (2.7 s) to finish. Brushing's countdown takes the voice channel.
  @visibleForTesting
  static Duration maxLaunchWait = const Duration(seconds: 3);

  @visibleForTesting
  static Widget Function({required bool showWorldIntro})? debugBrushingBuilder;

  /// Where the step events go. The singleton does nothing on a test host (it
  /// only reaches Firebase on Android), so tests swap in a recording one.
  @visibleForTesting
  static AnalyticsService? debugAnalytics;

  @override
  State<PreBrushScreen> createState() => _PreBrushScreenState();
}

class _PreBrushScreenState extends State<PreBrushScreen>
    with WidgetsBindingObserver {
  final _heroes = HeroService();
  final _weapons = WeaponService();
  final _worlds = WorldService();
  final _goals = GoalService();
  AudioService get _audio => AudioService();
  AnalyticsService get _analytics =>
      PreBrushScreen.debugAnalytics ?? AnalyticsService();

  /// Loading never holds up brushing: past this, skip the steps.
  static const _loadTimeout = Duration(seconds: 3);

  /// "Let's fight!" waits at most this long for a change to be read back.
  static const _refreshTimeout = Duration(seconds: 2);

  /// A scroll that sends no end (its page went away mid-fling) stops
  /// holding the count after this long without a scroll notification.
  static const _scrollQuiet = Duration(milliseconds: 400);

  static const _shopKey = ValueKey('prebrush_shop');
  static const _mapKey = ValueKey('prebrush_map');

  PreBrushStep _step = PreBrushStep.hero;
  _Loadout _now = _starterLoadout;

  bool _loaded = false;

  /// The first step has started.
  bool _entered = false;

  /// In the background: nothing counts, speaks or launches.
  bool _paused = false;

  /// After "Let's fight!" (→ brushing) or X (→ Home): nothing counts,
  /// speaks or changes any more.
  bool _leaving = false;
  bool _closed = false;
  bool _waitingToLaunch = false;
  bool _launched = false;

  // What the pages follow.
  final _tab = ValueNotifier<int>(0);
  final _highlight = ValueNotifier<String?>(null);
  final _reveal = BrushPing();
  late final BrushMode _brushMode = BrushMode(
    onClose: _onClose,
    tab: _tab,
    onTabChanged: _onTabChanged,
    highlightId: _highlight,
    reveal: _reveal,
    onChanged: _onPageChanged,
  );

  // What holds the idle count (spec §4.2).
  final Set<int> _pointers = {};
  bool _scrolling = false;
  bool _routeCurrent = true;
  bool _voiceCapReached = false;

  /// Scroll the glow into view once this step's lines are over, unless he
  /// touches first.
  bool _revealPending = false;

  Timer? _idleTimer;
  Timer? _voiceCapTimer;
  Timer? _scrollQuietTimer;
  Timer? _launchTimer;
  Timer? _launchCapTimer;

  /// Page changes are read back one at a time, in order.
  Future<void> _refreshing = Future<void>.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audio.voicePipelineActiveNotifier.addListener(_onVoiceChanged);
    unawaited(_load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A dialog on top (purchase, unlock celebration) holds the count; it
    // starts again from zero once the dialog closes.
    final current = ModalRoute.isCurrentOf(context) ?? true;
    if (current == _routeCurrent) return;
    _routeCurrent = current;
    _reconsider();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audio.voicePipelineActiveNotifier.removeListener(_onVoiceChanged);
    _stopCounting();
    _cancelLaunch();
    // The pages (children) have already removed their listeners.
    _tab.dispose();
    _highlight.dispose();
    _reveal.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_closed || _launched) return;
    if (state == AppLifecycleState.paused && !_paused) {
      _paused = true;
      _stopCounting();
      _scrolling = false;
      _pointers.clear();
      if (!_loaded) return; // _load waits for the resume
      _cancelLaunch();
      unawaited(_audio.stopVoice());
    } else if (state == AppLifecycleState.resumed && _paused) {
      _paused = false;
      if (!_loaded) return; // _load starts the first step itself
      if (_leaving) {
        // The pause cut "Let's fight!": go straight to brushing.
        _launchBrushing(showWorldIntro: false);
      } else if (!_entered) {
        _enterStep(PreBrushStep.hero);
      } else {
        _armVoiceCap();
        _reconsider(); // the count starts again from zero
      }
    }
  }

  // ── Loading ─────────────────────────────────────────────────

  Future<void> _load() async {
    try {
      _now = await _readLoadout().timeout(_loadTimeout);
    } on Object catch (e) {
      // Any failure (a TypeError from a malformed record too) skips the
      // steps rather than leave the child on a blank screen.
      debugPrint('PreBrush load failed: $e');
      if (!mounted || _closed) return;
      unawaited(_analytics.logPreBrushSkipped(reason: 'error'));
      unawaited(
        _analytics.logBrushSessionStart(
          heroId: _now.heroId,
          weaponId: _now.weaponId,
          worldId: _now.worldId,
        ),
      );
      _launchBrushing(showWorldIntro: true);
      return;
    }
    if (!mounted || _closed) return;
    setState(() => _loaded = true);
    if (_paused) return; // the first step starts on resume
    _enterStep(PreBrushStep.hero);
  }

  Future<_Loadout> _readLoadout() async {
    final heroId = await _heroes.getSelectedHeroId();
    return (
      heroId: heroId,
      heroStage: await _heroes.getEvolutionStage(heroId),
      weaponId: await _weapons.getSelectedWeaponId(),
      worldId: await _worlds.getCurrentWorldId(),
      heroGoal: await _goals.heroGoal(),
      weaponGoal: await _goals.weaponGoal(),
      worldGoal: await _goals.worldGoal(),
    );
  }

  // ── Steps ───────────────────────────────────────────────────

  Goal? _goalFor(PreBrushStep step) => switch (step) {
    PreBrushStep.hero => _now.heroGoal,
    PreBrushStep.weapon => _now.weaponGoal,
    PreBrushStep.world => _now.worldGoal,
  };

  /// What the page glows: a new hero on its first cell, anything else on
  /// its own id.
  String? _highlightFor(PreBrushStep step) {
    final goal = _goalFor(step);
    if (goal == null) return null;
    if (goal.category == GoalCategory.hero && !goal.isEvolution) {
      return '${goal.itemId}_stage1';
    }
    return goal.itemId;
  }

  /// The step's description line, then how far its goal is (spec §4.3).
  List<String> _entryLines(PreBrushStep step) => [
    switch (step) {
      PreBrushStep.hero => _audio.evolutionPickerVoiceFor(
        _now.heroId,
        _now.heroStage,
      ),
      PreBrushStep.weapon => _audio.weaponPickerVoiceFor(_now.weaponId),
      PreBrushStep.world => 'voice_world_${_now.worldId}.mp3',
    },
    _progressLine(_goalFor(step)),
  ];

  String _progressLine(Goal? goal) {
    if (goal == null) return 'voice_have_them_all.mp3';
    if (goal.category == GoalCategory.world) {
      return _audio.brushesLeftVoiceFor(goal.left);
    }
    // He can buy it right here, so not "Brush to unlock it!".
    if (goal.affordable) return 'voice_tap_to_unlock.mp3';
    return _audio.starsLeftVoiceFor(goal.left);
  }

  void _enterStep(PreBrushStep step) {
    _entered = true;
    _cancelIdle();
    ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
    setState(() => _step = step);
    // A scroll on the page left behind may never send its end. Reset before
    // the tab moves: the tab's own slide starts right after.
    _scrolling = false;
    _scrollQuietTimer?.cancel();
    if (step != PreBrushStep.world) {
      _tab.value = step == PreBrushStep.hero ? 0 : 1;
    }
    _highlight.value = _highlightFor(step);
    _revealPending = true;
    final lines = _entryLines(step);
    for (var i = 0; i < lines.length; i++) {
      unawaited(
        _audio.playVoice(lines[i], clearQueue: i == 0, interrupt: i == 0),
      );
    }
    _armVoiceCap();
    _reconsider();
  }

  void _onGo() {
    if (!_entered || _leaving) return;
    unawaited(HapticFeedback.mediumImpact());
    unawaited(_audio.playSfx('whoosh.mp3'));
    _advance();
  }

  void _advance() {
    if (!mounted || _leaving) return;
    switch (_step) {
      case PreBrushStep.hero:
        _enterStep(PreBrushStep.weapon);
      case PreBrushStep.weapon:
        _enterStep(PreBrushStep.world);
      case PreBrushStep.world:
        unawaited(_finish());
    }
  }

  /// A tab tap or a swipe on the Heroes & Weapons page.
  void _onTabChanged(int index) {
    if (!_entered || _leaving || _step == PreBrushStep.world) return;
    final step = index == 1 ? PreBrushStep.weapon : PreBrushStep.hero;
    if (step != _step) _enterStep(step);
  }

  // ── The idle count ──────────────────────────────────────────

  bool get _countHeld =>
      !_entered ||
      _leaving ||
      _paused ||
      !_routeCurrent ||
      _pointers.isNotEmpty ||
      _scrolling ||
      (_audio.voicePipelineActiveNotifier.value && !_voiceCapReached);

  /// Runs the idle count when nothing holds it and stops it when something
  /// does: each start counts from zero.
  void _reconsider() {
    if (!mounted || _countHeld) {
      _cancelIdle();
      return;
    }
    if (_revealPending) {
      _revealPending = false;
      _revealWhenStill();
    }
    _idleTimer ??= Timer(PreBrushScreen.idleAdvance, _onIdle);
  }

  /// The step's lines are over: once its layout is done and nothing moves,
  /// the page shows its glow if it is off screen. Never under his finger.
  void _revealWhenStill() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _leaving || _pointers.isNotEmpty) return;
      if (_scrolling) {
        _revealPending = true; // after the tab slide
        return;
      }
      _reveal.ping();
    });
  }

  void _onIdle() {
    _idleTimer = null;
    if (!mounted || _countHeld) return;
    _advance();
  }

  void _cancelIdle() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  /// Stops the idle count and what feeds it.
  void _stopCounting() {
    _cancelIdle();
    _voiceCapTimer?.cancel();
    _scrollQuietTimer?.cancel();
  }

  void _onVoiceChanged() {
    if (_waitingToLaunch) {
      _launchWhenQuiet();
      return;
    }
    if (_leaving || _closed) return;
    if (_audio.voicePipelineActiveNotifier.value) {
      _armVoiceCap(); // a new line: the cap counts from here
    } else {
      _voiceCapTimer?.cancel();
      _voiceCapReached = false;
    }
    _reconsider();
  }

  void _armVoiceCap() {
    _voiceCapTimer?.cancel();
    _voiceCapReached = false;
    _voiceCapTimer = Timer(PreBrushScreen.maxVoiceWait, () {
      _voiceCapReached = true;
      _reconsider();
    });
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointers.add(event.pointer);
    // He is exploring: never move the page under his finger.
    _revealPending = false;
    _reconsider();
  }

  void _onPointerEnd(PointerEvent event) {
    _pointers.remove(event.pointer);
    _reconsider();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification is ScrollEndNotification) {
      _scrollQuietTimer?.cancel();
      _scrolling = false;
      _reconsider();
    } else if (notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification) {
      _scrollQuietTimer?.cancel();
      _scrollQuietTimer = Timer(_scrollQuiet, () {
        _scrolling = false;
        _reconsider();
      });
      if (!_scrolling) {
        _scrolling = true;
        _reconsider();
      }
    }
    return false;
  }

  // ── What the pages report ───────────────────────────────────

  void _onPageChanged(BrushChange change) {
    if (!mounted || _closed) return;
    final unlocked = change.unlockedId;
    if (unlocked != null) {
      unawaited(
        _analytics.logGoalUnlocked(
          category: change.category.name,
          item: unlocked,
          source: 'pre_brush',
        ),
      );
    }
    _refreshing = _refreshing.then((_) => _refresh());
  }

  /// Reads the choices and goals back after the page changed something:
  /// logs what changed and moves the glow to the next closest unlock.
  Future<void> _refresh() async {
    final _Loadout next;
    try {
      next = await _readLoadout();
    } on Object catch (e) {
      debugPrint('PreBrush refresh failed: $e');
      return;
    }
    if (!mounted || _closed) return;
    final before = _now;
    _now = next;
    if (next.heroId != before.heroId || next.heroStage != before.heroStage) {
      unawaited(_analytics.logPreBrushChange(category: 'hero'));
    }
    if (next.weaponId != before.weaponId) {
      unawaited(_analytics.logPreBrushChange(category: 'weapon'));
    }
    if (next.worldId != before.worldId) {
      unawaited(_analytics.logPreBrushChange(category: 'world'));
    }
    if (!_leaving) _highlight.value = _highlightFor(_step);
  }

  // ── Leaving ─────────────────────────────────────────────────

  Future<void> _finish() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    _stopCounting();
    unawaited(HapticFeedback.heavyImpact());
    unawaited(
      _audio.playVoice(
        'voice_lets_fight.mp3',
        clearQueue: true,
        interrupt: true,
      ),
    );
    // The last change is read back, so the session starts with it.
    try {
      await _refreshing.timeout(_refreshTimeout);
    } on Object catch (e) {
      debugPrint('PreBrush refresh not finished: $e');
    }
    if (!mounted || _closed) return;
    unawaited(
      _analytics.logBrushSessionStart(
        heroId: _now.heroId,
        weaponId: _now.weaponId,
        worldId: _now.worldId,
      ),
    );
    // A pause meanwhile launches on resume.
    if (_paused || _launched) return;
    _launchTimer = Timer(PreBrushScreen.launchDelay, () {
      _waitingToLaunch = true;
      _launchCapTimer = Timer(PreBrushScreen.maxLaunchWait, _launchNow);
      _launchWhenQuiet();
    });
  }

  void _launchWhenQuiet() {
    if (_audio.voicePipelineActiveNotifier.value) return;
    _launchNow();
  }

  void _launchNow() {
    if (!_waitingToLaunch) return;
    _cancelLaunch();
    _launchBrushing(showWorldIntro: false);
  }

  void _cancelLaunch() {
    _waitingToLaunch = false;
    _launchTimer?.cancel();
    _launchCapTimer?.cancel();
  }

  void _launchBrushing({required bool showWorldIntro}) {
    if (!mounted || _closed || _launched) return;
    // Only from the top: after X this screen animates away above Home, and
    // pushReplacement would replace Home instead.
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
    _launched = true;
    _leaving = true;
    final builder = PreBrushScreen.debugBrushingBuilder;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => builder != null
            ? builder(showWorldIntro: showWorldIntro)
            : BrushingScreen(showWorldIntro: showWorldIntro),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _onClose() => unawaited(Navigator.of(context).maybePop());

  void _onPop(bool didPop, Object? result) {
    if (!didPop) return;
    // Go quiet: the screen stays mounted (and its voice listener live)
    // during the exit animation.
    _closed = true;
    _leaving = true;
    _stopCounting();
    _cancelLaunch();
    unawaited(_audio.stopVoice());
  }

  // ── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: _onPop,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0B2E),
        // As the Scaffold's floating button, GO has the page's floating
        // snack bars ("2 more stars") shown above it. It is there from the
        // first frame (disabled until the first step): a floating button
        // that appears later scales in from nothing, and a tap then misses.
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: GoButton(
          key: const ValueKey('prebrush_go'),
          rocket: _step == PreBrushStep.world,
          onPressed: _entered && !_leaving ? _onGo : null,
        ),
        body: _loaded
            ? _buildSteps()
            : const SpaceBackground(child: SizedBox.expand()),
      ),
    );
  }

  Widget _buildSteps() {
    final pageKey = _step == PreBrushStep.world ? _mapKey : _shopKey;
    return Stack(
      fit: StackFit.expand,
      children: [
        Listener(
          onPointerDown: _onPointerDown,
          onPointerUp: _onPointerEnd,
          onPointerCancel: _onPointerEnd,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            // After "Let's fight!" the choices are fixed.
            child: IgnorePointer(
              ignoring: _leaving,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                // A new closure each build: Flutter then rebuilds the page
                // on its way out with the outgoing slide (to the left).
                transitionBuilder: (child, animation) => SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset(child.key == pageKey ? 1.0 : -1.0, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
                child: _step == PreBrushStep.world
                    ? WorldMapScreen(key: _mapKey, brushMode: _brushMode)
                    : HeroShopScreen(key: _shopKey, brushMode: _brushMode),
              ),
            ),
          ),
        ),
        // Which step this is (for tests); draws nothing.
        Positioned(
          left: 0,
          top: 0,
          child: SizedBox.shrink(key: ValueKey('prebrush_step_${_step.name}')),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Rename the knob in the Home tests**

Run:

```bash
perl -0pi -e 's/PreBrushScreen\.minStep = const Duration\(seconds: 30\);\n\s*PreBrushScreen\.maxStep = const Duration\(seconds: 30\);/PreBrushScreen.idleAdvance = const Duration(seconds: 30);/g; s/PreBrushScreen\.minStep = const Duration\(seconds: 3\);\n\s*PreBrushScreen\.maxStep = const Duration\(seconds: 5\);/PreBrushScreen.idleAdvance = const Duration(seconds: 8);/g; s/PreBrushScreen\.minStep = const Duration\(milliseconds: 100\);\n\s*PreBrushScreen\.maxStep = const Duration\(milliseconds: 200\);/PreBrushScreen.idleAdvance = const Duration(milliseconds: 100);/g' test/screens/home_screen_test.dart test/screens/home_flame_test.dart
grep -n "minStep\|maxStep\|idleAfterTouch\|maxBriefingStep" test lib -r
```

Expected: the `grep` prints nothing.

In `test/screens/home_screen_test.dart`, in the test `'Home waits to refresh until it is shown again after brushing starts'`, change the loop that waits for brushing from 20 to 40 frames (the three pages and their slides take longer than the old carousel):

```dart
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
```

- [ ] **Step 5: Run the pre-brush and Home tests**

Run: `flutter test test/screens/pre_brush_screen_test.dart test/screens/home_screen_test.dart test/screens/home_flame_test.dart`
Expected: all PASS. If a timing assertion misses by one 50 ms frame, check the frame arithmetic in that test before touching the screen code; the screen's timings are the spec's.

- [ ] **Step 6: Format, analyze, full suite**

Run: `dart format lib test && dart analyze && flutter test`
Expected: "No issues found!"; all tests pass. (`lib/widgets/loadout_carousel.dart` is now unused but still compiles; Task 5 removes it.)

- [ ] **Step 7: Commit**

```bash
git add lib/screens/pre_brush_screen.dart test/screens/pre_brush_screen_test.dart test/screens/home_screen_test.dart test/screens/home_flame_test.dart
git commit -m "feat(pre-brush): the steps run on the real Heroes & Weapons and Map pages

HEROES tab, WEAPONS tab, then the Map, each in brush mode under a big
GO. About 8 s without a touch, scroll or dialog moves on once the voice
is quiet. The closest next unlock glows and can be bought right there.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01STWCtX8pE4SLhUiiBxVG9M"
```

---

### Task 5: Remove the carousel; describe the new flow

**Files:**
- Delete: `lib/widgets/loadout_carousel.dart`
- Modify: `test/widgets/brush_flow_widgets_test.dart`
- Modify: `CLAUDE.md` (Game Flow, step 2), `STATUS.md` (the "Pre-brush" line, near line 16)

**Interfaces:**
- Consumes: nothing new. Produces: nothing (removal and docs).

- [ ] **Step 1: Delete the widget**

Run: `git rm lib/widgets/loadout_carousel.dart`

- [ ] **Step 2: Drop its tests**

In `test/widgets/brush_flow_widgets_test.dart`:
- remove the line `import 'package:brush_quest/widgets/loadout_carousel.dart';`;
- remove the whole `group('LoadoutCarousel', () { ... });`;
- in `group('Task 6 additions', ...)`, remove the `Widget carousel({...}) => _wrap(...);` helper and the three tests `'carousel opens on the selected item'`, `'a swipe moves the choice and reports a touch'` and `'carousel arrows are at least 48 px (small fingers)'`. Every other test in the file stays.

Then run: `grep -rn "LoadoutCarousel\|loadout_carousel\|LoadoutItem\|carousel_" lib test`
Expected: no output.

- [ ] **Step 3: Describe the new flow**

In `CLAUDE.md`, replace Game Flow step 2 with:

```markdown
2. Home screen → tap the hero (it IS the brush button); the streak pill shows a flame that grows with the streak. From the second brush on, the steps run on the real pages in brush mode: the Heroes & Weapons page (HEROES tab, then WEAPONS), then the World Map. Each has an X (back to Home), a big GO and a gold glow on the closest next unlock, which he can buy right there; taps play the page's own lines. About 8 s without a touch moves on once the voice is quiet. "Let's fight!" plays out before brushing
```

In `STATUS.md`, replace the line that starts `  - **Pre-brush:** from the second brush on` with:

```markdown
  - **Pre-brush:** from the second brush on, tapping the hero opens the real Heroes & Weapons page (HEROES, then WEAPONS) and the World Map in brush mode: an X, a big GO, the closest next unlock glowing (buyable right there), about 8 s idle advance (rebuilt 2026-10-14 after Jim's feedback on the carousel steps).
```

- [ ] **Step 4: Format, analyze, full suite**

Run: `dart format lib test && dart analyze && flutter test`
Expected: "No issues found!"; all tests pass.

- [ ] **Step 5: Commit**

```bash
git add test/widgets/brush_flow_widgets_test.dart CLAUDE.md STATUS.md
git commit -m "chore(pre-brush): remove the carousel; describe the steps on the real pages

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01STWCtX8pE4SLhUiiBxVG9M"
```

(`git rm` in Step 1 already staged the deletion.)

---

### Task 6: Device check before Jim sees it (controller, not a subagent)

**Files:** none changed unless the check finds a problem (then fix in a new commit with a test).

- [ ] **Step 1: All quality gates**

```bash
cd /Users/jimchabas/Projects/brush-quest
dart format --set-exit-if-changed lib test
dart analyze
dart run dart_code_linter:metrics analyze lib
flutter test
semgrep --config auto lib/
gitleaks detect --source .
```

Expected: no format changes, "No issues found!" twice, all tests pass, semgrep 0 findings, gitleaks no leaks.

- [ ] **Step 2: A debug build on the emulator**

```bash
export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"
export ANDROID_SDK_ROOT=$HOME/Library/Android/sdk
$ANDROID_SDK_ROOT/emulator/emulator -avd test_pixel -no-snapshot-save &
$ANDROID_SDK_ROOT/platform-tools/adb wait-for-device
flutter build apk --debug
$ANDROID_SDK_ROOT/platform-tools/adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Get a returning kid: finish the tutorial and one brush, or stop the app and edit `shared_prefs/FlutterSharedPreferences.xml` with `adb shell run-as com.brushquest.brush_quest` (keys are prefixed `flutter.`: `onboarding_completed` true, `total_brushes` ≥ 1, `star_wallet` 6 so Frost and the Flame Sword are buyable). Read the file first and keep its format.

- [ ] **Step 3: Visual parity screenshots**

With `adb exec-out screencap -p > <scratchpad>/<name>.png`, take six screenshots at phone size:
- `home-heroes.png`: Home → shop button → HEROES tab; `steps-heroes.png`: Home → hero tap → HEROES step.
- `home-weapons.png` and `steps-weapons.png`: the same for WEAPONS.
- `home-map.png` and `steps-map.png`: Home → map button, and the Map step.

Read each pair. The only differences allowed: the X in place of the back arrow (the header 4 px taller), GO at the bottom, the extra bottom padding, and the gold glow. Anything else (fonts, colours, art, tab bar, wallet pill, planet path) is a defect: fix it before Jim sees it.

- [ ] **Step 4: First-person walkthrough (CLAUDE.md Pre-Ship UX Checklist)**

As a 7-year-old who can't read, on each step: Is the GO arrow/rocket enough to know what to press? Does every tap say something that makes sense here? Does "Tap to unlock it!" point at the glowing item on screen? Trace the audio timeline: entry lines, a description tap, GO mid-line, an unlock (confirmation → celebration → no extra line), the Map's "Let's fight!" into "3, 2, 1". Note anything that collides.

- [ ] **Step 5: Report**

Write the results (screenshots compared, defects found and fixed, walkthrough notes) into the SDD ledger, then update the checklist artifact's v1.1 tab (items v1–v4, d1–d5) and offer Jim the next build (`1.1.0+41`, Play internal, needs his go).
