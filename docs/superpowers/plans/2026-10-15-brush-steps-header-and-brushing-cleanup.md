# Brush Steps Header and Brushing Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Part A of v1.1 rework 2: the three brush steps share one HEROES · WEAPONS · WORLD header, each step opens with an instruction line, the back gesture goes one step back, and the brushing screen loses the monster counter and the sign under the timer.

**Architecture:** `PreBrushScreen` stays the coordinator. It builds one `StepHeader` (new widget, `lib/widgets/step_header.dart`) and hands it to the pages through a new required field, `BrushMode.header`; the Heroes & Weapons page shows it in place of its own tab bar, and the Map shows it in the same place, under its title row. The entry lines become "instruction, then progress". A `PopScope` whose `canPop` is true only on HEROES (and before the first step and after "Let's fight!") turns the back gesture into a step back; the X pops the route directly. The brushing screen's HUD keeps the mouth guide; the counter, the sign and their two painters go.

**Tech Stack:** Flutter 3.41.4 / Dart 3, very_good_analysis 7 lints, dart_code_linter (DCM), flutter_test widget tests with `FakeAudioService` and `TimedFakeAudioService`, SharedPreferences mocks.

**Spec:** `docs/superpowers/specs/2026-10-15-sticker-card-design.md`: **§3 (Part A) and decisions S6 and S7 in §2 only**. Not the sticker card (Part B, §4–§9) or the reminder (Part C). §3 amends `docs/superpowers/specs/2026-10-13-brush-steps-on-real-pages-design.md` (its §4.3 entry lines and the way back); everything else there stands, as built by `docs/superpowers/plans/2026-10-14-brush-steps-on-real-pages.md`.

**Dry run:** every code block and test below was applied to a scratch copy of this branch at `8f6872d` (outside the repo) and run. `dart format` changed nothing, `dart analyze` and DCM reported no issues, and all 1275 tests passed (1251 before). Each new test that pins a behaviour was also checked to fail once that behaviour is removed.

## Global Constraints

- **Part A only.** No sticker card, streak, flame, chest, greeting or reminder changes; Home, the victory screen, prices and earning are untouched.
- **R6 stands:** `HeroShopScreen()` and `WorldMapScreen()` built without `brushMode` are exactly as today. From Home the shop keeps its own two-tab `TabBar` and the Map has no header. Every Home-path test passes unchanged.
- **Kept, as pinned by the 2026-10-14 plan:** idle advance **8 s** (`PreBrushScreen.idleAdvance`), counted once the voice is quiet; voice-wait cap **12 s** (`PreBrushScreen.maxVoiceWait`); GO settle **400 ms** (`_goSettle`); launch delay **400 ms**; wait for "Let's fight!" at most **3 s**; load timeout **3 s**; page slide **400 ms**; the reveal scroll after the step's lines, never under his finger; the gold glow on the closest next unlock; "Tap to unlock it!" (never "Brush to unlock it!") in the steps; ruling R-2 (after "Let's fight!" the whole page ignores touches, the X and now the header included).
- **Instruction lines** (Buddy/George, house format: mp3, 22 050 Hz, mono, 64 kbps, about −24 LUFS; already recorded in `.remember/v1.1/voice-staging/`):
  - HEROES `voice_step_pick_hero.mp3` "Pick the hero who'll brush with you!" (1.67 s)
  - WEAPONS `voice_step_pick_weapon.mp3` "Now pick your weapon!" (1.07 s)
  - WORLD `voice_step_pick_world.mp3` "Pick the world where you'll fight!" (1.38 s)

  Each is followed by the step's existing progress line. The current item's own description no longer plays on entry; it still plays when he taps an item. No other new lines.
- **Header:**
  - Labels and icons: `'HEROES'` + `Icons.shield`, `'WEAPONS'` + `Icons.bolt` (the shop's tab icons), `'WORLD'` + `Icons.public` (Home's MAP button).
  - Bar: 48 px tall (`StepHeader.height`, the shop's tab bar height), 16 px side margins, fill white α 0.08, radius 16.
  - Lit tab: fill `Color(0xFF7C4DFF)` α 0.4, radius 16, label white. Other tabs: label `Colors.white54`.
  - Label: bold, 16 px, letterSpacing 2, after a 20 px icon and a 6 px gap. It is scaled down to fit and never cut.
  - Keys: the header `ValueKey('prebrush_header')`; the tabs `ValueKey('step_tab_0')`, `'step_tab_1'`, `'step_tab_2'`.
- **The way back:** the back gesture goes World → Weapons → Heroes → Home; the X goes Home from any step; during "Let's fight!" the back gesture goes Home.
- **Brushing screen:** remove the monster counter (starburst and number beside the mouth guide) and the phase sign under the timer. The mouth guide, the seconds and everything else stay where they are.
- **Code rules:**
  - Every delay is a `Timer?` field cancelled in `dispose()`. No `Future.delayed` in new code, and no new dialogs.
  - Run `dart format lib test` before every commit. `dart analyze` must say "No issues found!", `dart run dart_code_linter:metrics analyze lib` must say "no issues found!", and `flutter test` must pass.
  - At the end, run `semgrep --config auto lib/` and `gitleaks detect --source .`. gitleaks reports 9 historical false positives that predate this branch.
  - The very_good_analysis rules that bite most: `sort_child_properties_last`, `prefer_const_constructors`, `unawaited_futures`, `comment_references` (only `[name]`s that resolve), `unnecessary_lambdas`, `cast_nullable_to_non_nullable`, `use_build_context_synchronously`.
- **Git:**
  - The repo is public: never `git add` anything under `.remember/`. Stage files by name, never with `git add -A`.
  - Never push or switch branches (`feat/v1.1-brush-flow`, local).
  - Every commit message ends with these two lines:
    ```
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
    Claude-Session: https://claude.ai/code/session_01STWCtX8pE4SLhUiiBxVG9M
    ```
- Line numbers below are as of `8f6872d`. Earlier tasks shift them, so find each edit by the code quoted with it.

## Rulings (controller, for Jim's plan review)

**R-A1, where the header sits.** It sits under the title row on all three steps: on the Heroes & Weapons page where its own tab bar is, and on the Map in the same place. The coordinator builds the one `StepHeader` and passes it to the pages through `BrushMode.header`; each page puts it in that slot.

Why not one overlay drawn over both pages: with the app's font the shop's title "HEROES & WEAPONS" wraps to two lines, so its tab bar starts 104 px down, while the Map's title row ends at 88 px (measured at 360, 430 and 440 dp). An overlay in one fixed place would either cover the shop's title or float over the Map's path, and a large system text size moves the rows further.

The cost: between WEAPONS and the Map the header slides with the page, as the X and the title already do. Between HEROES and WEAPONS it stays still and only the lit tab changes. A header pinned at the very top of the screen would need no slot, but it would push the X off the top left, where §3.1 keeps it.

**R-A2, the lit tab.** A tap on the step he is already on does nothing and replays no line, as a tab bar does today (§3.1 says a tab tap behaves "as a tab tap does today").

**R-A3, the slide direction.** A step change that goes back (a header tap on an earlier step, or the back gesture) slides the shop in from the left and the Map out to the right. Going forward is unchanged. The spec says nothing on direction, but a back that slides like "next" looks like going forward.

**R-A4, no hold-back.** Header taps and back gestures ignore GO's 400 ms settle, which exists for double taps on GO. Each back is one step: two quick backs from the Map reach HEROES, and a third goes Home.

**R-A5, the X.** The X now calls `Navigator.pop()` instead of `maybePop()`, which would step back on WEAPONS and the Map. When the steps are the only route (some tests), the X does nothing, as before.

**R-A6, the brushing layout.** The sign and its 4 px gap become one empty 44 px box. The monster, the hero, the timer and the hit effects placed at fixed offsets around them stay exactly where they are (the dry run measured the timer's rect, unchanged). If Jim wants the battle column re-centred instead, delete the box and everything moves down 22 px.

**Noticed, not in scope (for Jim):**
- After a brush resumes from its checkpoint (the app came back within 3 minutes), the HUD with the mouth guide stays slid off the top of the screen until the next zone starts. The cause is that `_phaseTransitionController` only runs in `_switchToPhase`. This exists today; fixing it is a user-facing change (Tier 3).
- For Part B: the staged `voice_card_new.mp3` ("A new card!") has the name of an existing, different clip that the victory screen plays on a trophy capture (`victory_screen.dart:810`). Copying it in would change that line, so Part B needs a new name for one of the two.

## Review Focus

1. **A back gesture while a dialog is open on a step** (the purchase confirmation on WEAPONS, say; the unlock celebration is a dialog route too): only the dialog closes, the step stays and nothing is bought. Pinned by Task 4 "the back gesture with a dialog open closes only the dialog".
2. **Backs in quick succession from the Map** (the second while the shop is still sliding in): WEAPONS, then HEROES, with no duplicate GlobalKey; one more goes Home. Pinned by Task 4 "two quick backs from the Map: HEROES; one more is Home".
3. **A header tap while the Map is still sliding in:** HEROES at once with its lines, the Map gone, no duplicate GlobalKey. Pinned by Task 3 "a header tap as the Map slides in: HEROES, cleanly".
4. **A large system text size (2×) on a 360 dp phone:** the header's labels shrink to fit, nothing overflows, and every tab stays 48 px tall. Pinned by Task 1 "fits a 360 dp phone at text size 2.0x".
5. **After a step back, the steps still move on by themselves** (the idle count once the voice is quiet), and GO works once its settle is over. Pinned by Task 4 "after a step back the count runs again, and GO works".

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `lib/widgets/step_header.dart` | Create | `StepHeader`: the HEROES · WEAPONS · WORLD bar (look, lit tab, taps) |
| `lib/screens/brush_mode.dart` | Modify | `BrushMode.header` (required) |
| `lib/screens/hero_shop_screen.dart` | Modify | Brush mode: the header in place of its own tab bar |
| `lib/screens/world_map_screen.dart` | Modify | Brush mode: the header under its title row |
| `lib/screens/pre_brush_screen.dart` | Modify | The instruction lines; builds and lights the header; header taps; the back-direction slide; the back gesture; the X |
| `lib/services/audio_service.dart` | Modify | Preloads the three instruction lines |
| `assets/audio/voices/buddy/voice_step_pick_{hero,weapon,world}.mp3` | Add (copied) | The instruction lines |
| `lib/screens/brushing_screen.dart` | Modify | No monster counter, no phase sign, and their painters deleted |
| `test/widgets/step_header_test.dart` | Create | Task 1 |
| `test/audio/audio_assets_test.dart` | Modify | Mirror of the preload list; a check that AudioService preloads the new lines |
| `test/screens/pre_brush_screen_test.dart` | Modify | The new lines, the header, the back gesture |
| `test/screens/hero_shop_brush_mode_test.dart` | Modify | The header slot; swipes where tab taps were |
| `test/screens/world_map_brush_mode_test.dart` | Modify | The header slot |
| `test/screens/brushing_screen_test.dart` | Modify | No counter, no sign |
| `CLAUDE.md`, `STATUS.md` | Modify | The game-flow description |

---

### Task 1: The steps' header widget

**Files:**
- Create: `lib/widgets/step_header.dart`
- Create: `test/widgets/step_header_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces (Task 3 relies on these exact names):
  - `class StepHeader extends StatelessWidget { const StepHeader({super.key, required ValueListenable<int> current, required ValueChanged<int> onTap}); static const double height = 48; }`
  - `current` is the step on screen: 0 heroes, 1 weapons, 2 world. `onTap(i)` fires on every tap, the lit tab's included.
  - The tabs are keyed `ValueKey('step_tab_0')` (HEROES), `ValueKey('step_tab_1')` (WEAPONS) and `ValueKey('step_tab_2')` (WORLD).
  - A lit tab's label `Text` is `Colors.white` and its `AnimatedContainer` fill is `const Color(0xFF7C4DFF).withValues(alpha: 0.4)`. Any other tab has label `Colors.white54` and fill `Colors.transparent`.

- [ ] **Step 1: Write the failing widget tests**

Create `test/widgets/step_header_test.dart`:

```dart
// test/widgets/step_header_test.dart
//
// The steps' HEROES · WEAPONS · WORLD header (spec
// docs/superpowers/specs/2026-10-15-sticker-card-design.md §3.1).
import 'package:brush_quest/widgets/step_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // The app's font, so widths are a phone's (the test font is about twice
    // as wide).
    final fredoka = FontLoader('Fredoka')
      ..addFont(
        rootBundle.load(
          'assets/fonts/Fredoka/Fredoka-VariableFont_wdth_wght.ttf',
        ),
      );
    await fredoka.load();
  });

  const lit = Color(0xFF7C4DFF);

  /// The header across a phone [width] wide, in the app's theme.
  Future<ValueNotifier<int>> pumpHeader(
    WidgetTester tester, {
    double width = 430,
    ValueChanged<int>? onTap,
  }) async {
    final current = ValueNotifier<int>(0);
    addTearDown(current.dispose);
    await tester.binding.setSurfaceSize(Size(width, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Fredoka'),
        ),
        home: Scaffold(
          body: Center(
            child: StepHeader(current: current, onTap: onTap ?? (_) {}),
          ),
        ),
      ),
    );
    return current;
  }

  Finder tab(int index) => find.byKey(ValueKey('step_tab_$index'));

  Color labelColor(WidgetTester tester, String label) =>
      tester.widget<Text>(find.text(label)).style!.color!;

  Color? fill(WidgetTester tester, int index) {
    final box = tester.widget<AnimatedContainer>(
      find.descendant(of: tab(index), matching: find.byType(AnimatedContainer)),
    );
    return (box.decoration! as BoxDecoration).color;
  }

  testWidgets('HEROES, WEAPONS and WORLD, each with its icon', (tester) async {
    await pumpHeader(tester);
    expect(find.text('HEROES'), findsOneWidget);
    expect(find.text('WEAPONS'), findsOneWidget);
    expect(find.text('WORLD'), findsOneWidget);
    expect(find.byIcon(Icons.shield), findsOneWidget);
    expect(find.byIcon(Icons.bolt), findsOneWidget);
    expect(find.byIcon(Icons.public), findsOneWidget);
  });

  testWidgets('the size and place of the page tab bar: 48 px, 16 px in', (
    tester,
  ) async {
    await pumpHeader(tester);
    expect(StepHeader.height, 48);
    expect(tester.getSize(find.byType(StepHeader)).height, 48);
    expect(tester.getRect(tab(0)).left, 16);
    expect(tester.getRect(tab(2)).right, 430 - 16);
    for (var i = 0; i < 3; i++) {
      final rect = tester.getRect(tab(i));
      expect(rect.height, 48, reason: 'tab $i');
      expect(rect.width, closeTo((430 - 32) / 3, 0.01), reason: 'tab $i');
    }
  });

  testWidgets('lights the step he is on, and follows it', (tester) async {
    final current = await pumpHeader(tester);
    expect(labelColor(tester, 'HEROES'), Colors.white);
    expect(labelColor(tester, 'WEAPONS'), Colors.white54);
    expect(labelColor(tester, 'WORLD'), Colors.white54);
    expect(fill(tester, 0), lit.withValues(alpha: 0.4));
    expect(fill(tester, 1), Colors.transparent);
    expect(fill(tester, 2), Colors.transparent);
    current.value = 2;
    await tester.pump();
    expect(labelColor(tester, 'WORLD'), Colors.white);
    expect(labelColor(tester, 'HEROES'), Colors.white54);
    expect(fill(tester, 2), lit.withValues(alpha: 0.4));
    expect(fill(tester, 0), Colors.transparent);
  });

  testWidgets('reports every tap, on the lit tab too', (tester) async {
    final taps = <int>[];
    await pumpHeader(tester, onTap: taps.add);
    await tester.tap(tab(2));
    await tester.tap(find.text('WEAPONS'));
    await tester.tap(find.byIcon(Icons.shield)); // the lit one
    expect(taps, [2, 1, 0]);
  });

  for (final phone in const [
    (width: 320.0, textScale: 1.0),
    (width: 360.0, textScale: 1.0),
    (width: 360.0, textScale: 2.0),
  ]) {
    testWidgets('fits a ${phone.width.toInt()} dp phone at text size '
        '${phone.textScale}x', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = phone.textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpHeader(tester, width: phone.width);
      expect(tester.takeException(), isNull);
      for (final (index, label) in ['HEROES', 'WEAPONS', 'WORLD'].indexed) {
        final box = tester.getRect(tab(index));
        final text = tester.getRect(find.text(label));
        expect(box.height, 48, reason: label);
        expect(
          box.contains(text.topLeft) && box.contains(text.bottomRight),
          isTrue,
          reason: '$label: $text in $box',
        );
      }
    });
  }
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `flutter test test/widgets/step_header_test.dart`
Expected: FAIL to compile, because `package:brush_quest/widgets/step_header.dart` does not exist.

- [ ] **Step 3: Create `lib/widgets/step_header.dart`**

```dart
// lib/widgets/step_header.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The HEROES · WEAPONS · WORLD bar on each brush step (spec
/// docs/superpowers/specs/2026-10-15-sticker-card-design.md §3.1), in the
/// look of the Heroes & Weapons page's own tab bar. It lights the step in
/// [current] and reports every tap through [onTap]; the steps decide what a
/// tap does.
class StepHeader extends StatelessWidget {
  const StepHeader({super.key, required this.current, required this.onTap});

  /// The step on screen: 0 heroes, 1 weapons, 2 world.
  final ValueListenable<int> current;

  /// He tapped tab 0, 1 or 2 (the lit one too).
  final ValueChanged<int> onTap;

  /// As tall as the page's own tab bar, so what is below it stays put.
  static const double height = 48;

  static const _tabs = [
    (label: 'HEROES', icon: Icons.shield),
    (label: 'WEAPONS', icon: Icons.bolt),
    (label: 'WORLD', icon: Icons.public),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ValueListenableBuilder<int>(
        valueListenable: current,
        builder: (context, lit, _) => Row(
          children: [
            for (var i = 0; i < _tabs.length; i++)
              Expanded(
                child: _StepTab(
                  key: ValueKey('step_tab_$i'),
                  label: _tabs[i].label,
                  icon: _tabs[i].icon,
                  lit: i == lit,
                  onTap: () => onTap(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StepTab extends StatelessWidget {
  const _StepTab({
    super.key,
    required this.label,
    required this.icon,
    required this.lit,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool lit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = lit ? Colors.white : Colors.white54;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: lit
                ? const Color(0xFF7C4DFF).withValues(alpha: 0.4)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          // A narrow phone or a large system text size shrinks the label
          // instead of cutting it.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 2,
                  ),
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

- [ ] **Step 4: Run the tests**

Run: `flutter test test/widgets/step_header_test.dart`
Expected: 7 tests PASS. (In the dry run, the three "fits" tests failed when the `FittedBox` was removed.)

- [ ] **Step 5: Format, analyze, full suite**

Run: `dart format lib test && dart analyze && dart run dart_code_linter:metrics analyze lib && flutter test`
Expected: "No issues found!", DCM "no issues found!", all tests pass (1258).

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/step_header.dart test/widgets/step_header_test.dart
git commit -m "feat(pre-brush): the steps' HEROES · WEAPONS · WORLD header widget

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01STWCtX8pE4SLhUiiBxVG9M"
```

---

### Task 2: Each step opens with its instruction line

**Files:**
- Add (copy): `assets/audio/voices/buddy/voice_step_pick_hero.mp3`, `voice_step_pick_weapon.mp3`, `voice_step_pick_world.mp3`, from `.remember/v1.1/voice-staging/`
- Modify: `lib/services/audio_service.dart:524-564` (`_brushFlowVoices`)
- Modify: `lib/screens/pre_brush_screen.dart:58-62` (`maxVoiceWait`'s comment), `:280-291` (`_entryLines`)
- Modify: `test/audio/audio_assets_test.dart:250-290` (the `_brushFlowVoices` mirror), `:596-599` (end of `main`)
- Modify: `test/screens/pre_brush_screen_test.dart`: the 12 tests listed in Step 2

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces (Tasks 3 and 4 assert these): each step's entry lines are `['voice_step_pick_hero.mp3', <progress>]`, `['voice_step_pick_weapon.mp3', <progress>]` or `['voice_step_pick_world.mp3', <progress>]`. `<progress>` is unchanged: `voice_tap_to_unlock.mp3`, `voice_stars_left_<n>.mp3`, `voice_stars_left_many.mp3`, `voice_brushes_left_<n>.mp3` or `voice_have_them_all.mp3`. With the test kid `returningKid` the lines are: HEROES `['voice_step_pick_hero.mp3', 'voice_stars_left_2.mp3']`, WEAPONS `['voice_step_pick_weapon.mp3', 'voice_stars_left_2.mp3']`, WORLD `['voice_step_pick_world.mp3', 'voice_brushes_left_3.mp3']`.

- [ ] **Step 1: Register the lines in the asset test**

In `test/audio/audio_assets_test.dart`, replace the mirror's comment line

```dart
/// v1.1 brush flow + streak flame lines (mirrors AudioService._brushFlowVoices).
const _brushFlowVoices = [
```

with

```dart
/// v1.1 brush flow + streak flame lines and the steps' instruction lines
/// (mirrors AudioService._brushFlowVoices).
const _brushFlowVoices = [
```

and end that list with the three new files (the last two lines are already there):

```dart
  'voice_need_more_brushes.mp3',
  'voice_ready_to_unlock.mp3',
  'voice_step_pick_hero.mp3',
  'voice_step_pick_weapon.mp3',
  'voice_step_pick_world.mp3',
];
```

At the end of `main()`, after the test `'Report orphaned audio files (informational, does not fail)'`, add:

```dart
  // -----------------------------------------------------------------------
  // 6. The steps' instruction lines are in AudioService's own preload list
  //    (the mirror above can't see that private list, so read the source).
  // -----------------------------------------------------------------------
  test("the steps' instruction lines are preloaded", () {
    final source = File(
      '$root/lib/services/audio_service.dart',
    ).readAsStringSync();
    final start = source.indexOf('static const _brushFlowVoices = [');
    expect(start, isNonNegative);
    final list = source.substring(start, source.indexOf('];', start));
    for (final file in const [
      'voice_step_pick_hero.mp3',
      'voice_step_pick_weapon.mp3',
      'voice_step_pick_world.mp3',
    ]) {
      expect(list, contains("'$file'"), reason: file);
    }
  });
```

- [ ] **Step 2: Change the step tests to the new lines**

In `test/screens/pre_brush_screen_test.dart`, make these edits. Each "replace" block is the file's current text; replace it with the block after it.

**2.1** Test `'opens on the HEROES tab with the hero line and the goal'` (line 317). Replace:

```dart
  testWidgets('opens on the HEROES tab with the hero line and the goal', (
    tester,
  ) async {
    await pumpScreen(tester, returningKid);
    expect(stepIs(PreBrushStep.hero), findsOneWidget);
    expect(find.byType(HeroShopScreen), findsOneWidget);
    expect(tabIndex(tester), 0);
    // Blaze's picker line, then Frost (5) minus the wallet (3).
    expect(voices(), ['voice_picker_hero_blaze.mp3', 'voice_stars_left_2.mp3']);
```

with:

```dart
  testWidgets('opens on the HEROES tab with its instruction and the goal', (
    tester,
  ) async {
    await pumpScreen(tester, returningKid);
    expect(stepIs(PreBrushStep.hero), findsOneWidget);
    expect(find.byType(HeroShopScreen), findsOneWidget);
    expect(tabIndex(tester), 0);
    // "Pick the hero who'll brush with you!", then Frost (5) minus the
    // wallet (3). Not Blaze's own description: that plays when he taps him.
    expect(voices(), ['voice_step_pick_hero.mp3', 'voice_stars_left_2.mp3']);
```

**2.2** Test `'GO: WEAPONS on the same page, then the Map, then the fight'` (line 335). Replace:

```dart
    // The Star Blaster's line, then the Flame Sword (5) minus 3.
    expect(voices().sublist(2), [
      'voice_picker_weapon_star_blaster.mp3',
      'voice_stars_left_2.mp3',
    ]);
```

with:

```dart
    // "Now pick your weapon!", then the Flame Sword (5) minus 3.
    expect(voices().sublist(2), [
      'voice_step_pick_weapon.mp3',
      'voice_stars_left_2.mp3',
    ]);
```

and in the same test replace:

```dart
    // Candy Crater's line, then 3 of its 5 missions to go.
    expect(voices().sublist(4), [
      'voice_world_candy_crater.mp3',
      'voice_brushes_left_3.mp3',
    ]);
```

with:

```dart
    // "Pick the world where you'll fight!", then 3 of Candy Crater's 5
    // missions to go.
    expect(voices().sublist(4), [
      'voice_step_pick_world.mp3',
      'voice_brushes_left_3.mp3',
    ]);
```

**2.3** Test `'everything owned: "You have them all" and no glow'` (line 415). Replace:

```dart
    expect(voices(), [
      'voice_picker_evo_nova_stage3.mp3',
      'voice_have_them_all.mp3',
    ]);
```

with:

```dart
    expect(voices(), ['voice_step_pick_hero.mp3', 'voice_have_them_all.mp3']);
```

and in the same test replace `'voice_world_dark_dimension.mp3',` (in `expect(voices().sublist(4), [...])`) with `'voice_step_pick_world.mp3',`.

**2.4** Test `'tapping a tab is a step change, with that step\'s lines'` (line 467). Replace:

```dart
    expect(voices(), [
      'voice_picker_weapon_star_blaster.mp3',
      'voice_stars_left_2.mp3',
    ]);
```

with:

```dart
    expect(voices(), ['voice_step_pick_weapon.mp3', 'voice_stars_left_2.mp3']);
```

and in the same test replace:

```dart
    expect(voices(), ['voice_picker_hero_blaze.mp3', 'voice_stars_left_2.mp3']);
```

with:

```dart
    expect(voices(), ['voice_step_pick_hero.mp3', 'voice_stars_left_2.mp3']);
```

**2.5** Test `'a swipe to the other tab is a step change too'` (line 493): replace `'voice_picker_weapon_star_blaster.mp3',` with `'voice_step_pick_weapon.mp3',`.

**2.6** Tests `'a finger on GO holds the count: one press, one step'` (line 548) and `'a double tap on GO on HEROES moves one step'` (line 571) hold the same block. In both, replace:

```dart
    expect(voices(), [
      'voice_picker_hero_blaze.mp3',
      'voice_stars_left_2.mp3',
      'voice_picker_weapon_star_blaster.mp3',
      'voice_stars_left_2.mp3',
    ]);
```

with:

```dart
    expect(voices(), [
      'voice_step_pick_hero.mp3',
      'voice_stars_left_2.mp3',
      'voice_step_pick_weapon.mp3',
      'voice_stars_left_2.mp3',
    ]);
```

**2.7** Test `'the page sliding away takes no taps'` (line 750): replace `final world = timed.voiceNamed('voice_world_candy_crater.mp3')!;` with `final world = timed.voiceNamed('voice_step_pick_world.mp3')!;`.

**2.8** Test `'a saved hero or weapon the game does not know: still a line'` (line 820). The picker lines it pinned no longer play on entry. Replace the whole test with:

```dart
  testWidgets('a saved hero or weapon the game does not know: the steps '
      'run as usual', (tester) async {
    await pumpScreen(
      tester,
      kid({'selected_hero': 'robo', 'selected_weapon': 'laser_sword'}),
    );
    expect(voices().first, 'voice_step_pick_hero.mp3');
    expect(tester.takeException(), isNull);
    await tapGo(tester);
    expect(voices()[2], 'voice_step_pick_weapon.mp3');
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.byType(HeroShopScreen), findsOneWidget);
  });
```

**2.9** Test `'timeline: a step\'s lines in turn, and the count waits'` (line 1036). Replace from its `final timed = useTimedVoices(` through `expect(progress.startedAt, greaterThanOrEqualTo(picker.endedAt!));` with:

```dart
    // The clips' real lengths.
    final timed = useTimedVoices(
      tester,
      lengths: const {
        'voice_step_pick_hero.mp3': Duration(milliseconds: 1672),
        'voice_stars_left_2.mp3': Duration(milliseconds: 993),
      },
    );
    await pumpScreen(tester, returningKid);
    await pumpFor(tester, const Duration(milliseconds: 3500)); // lines: 2.7 s
    expect(stepIs(PreBrushStep.hero), findsOneWidget);
    await pumpUntilFound(tester, stepIs(PreBrushStep.weapon));
    final instruction = timed.voiceNamed('voice_step_pick_hero.mp3')!;
    final progress = timed.voiceNamed('voice_stars_left_2.mp3')!;
    expect(instruction.cut, isFalse);
    expect(progress.startedAt, greaterThanOrEqualTo(instruction.endedAt!));
```

(The rest of the test, from `final quiet = ...`, stays.)

**2.10** Test `'timeline: each tap re-arms the voice cap; the count waits for what he taps'` (line 1117). The run of voice must still be longer than the 12 s cap, so the first tap now lands during the step's (shorter) lines. Replace from the comment `// The real knobs. ...` through `final frostAt = timed.clock();` with:

```dart
    // The real knobs. The step's lines and two descriptions he taps make
    // one unbroken run of voice of 18.5 s, longer than the 12 s cap.
    PreBrushScreen.idleAdvance = const Duration(seconds: 8);
    final timed = useTimedVoices(
      tester,
      lengths: const {
        'voice_step_pick_hero.mp3': Duration(milliseconds: 1672),
        'voice_stars_left_2.mp3': Duration(seconds: 1),
        'voice_picker_hero_bolt.mp3': Duration(seconds: 6),
        'voice_picker_hero_frost.mp3': Duration(seconds: 7),
        'voice_shop_nudge_default.mp3': Duration(seconds: 2),
      },
    );
    await pumpScreen(tester, returningKid);
    // Before the step's lines are over (2.7 s).
    await pumpFor(tester, const Duration(seconds: 2));
    // Bolt (8) and Frost (5) are out of reach: each tap plays the hero's
    // line, then the nudge.
    await tester.tap(find.byKey(const ValueKey('evo_cell_bolt_stage1')));
    final boltAt = timed.clock();
    await pumpFor(tester, const Duration(milliseconds: 7500));
    await tester.tap(find.byKey(const ValueKey('evo_cell_frost_stage1')));
    final frostAt = timed.clock();
```

and in the same test replace `final weapon = timed.voiceNamed('voice_picker_weapon_star_blaster.mp3')!;` with `final weapon = timed.voiceNamed('voice_step_pick_weapon.mp3')!;`. (In the dry run, with the tap's cap re-arm removed from `_onPointerEnd`, this test fails: 1.5 s instead of at least 8 s.)

**2.11** Test `'timeline: GO cuts the lines; the next ones never overlap'` (line 1166). Replace:

```dart
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
```

with:

```dart
    final timed = useTimedVoices(
      tester,
      lengths: const {'voice_step_pick_hero.mp3': Duration(milliseconds: 1672)},
    );
    await pumpScreen(tester, returningKid);
    await pumpFor(tester, const Duration(seconds: 1));
    await tapGo(tester); // inside "Pick the hero..."
    await pumpFor(tester, const Duration(seconds: 5));
    final hero = timed.voiceNamed('voice_step_pick_hero.mp3')!;
    final weapon = timed.voiceNamed('voice_step_pick_weapon.mp3')!;
```

- [ ] **Step 3: Run them to make sure they fail**

Run: `flutter test test/screens/pre_brush_screen_test.dart test/audio/audio_assets_test.dart`
Expected: FAIL.
- The 12 step tests edited in Step 2 (items 2.1–2.11; 2.6 covers two tests). They still hear the old picker and world lines.
- In the asset test: `voice_step_pick_*.mp3 exists` (×3) and `the steps' instruction lines are preloaded`.

- [ ] **Step 4: Copy the clips**

```bash
cp .remember/v1.1/voice-staging/voice_step_pick_hero.mp3 \
   .remember/v1.1/voice-staging/voice_step_pick_weapon.mp3 \
   .remember/v1.1/voice-staging/voice_step_pick_world.mp3 \
   assets/audio/voices/buddy/
for f in hero weapon world; do afinfo assets/audio/voices/buddy/voice_step_pick_$f.mp3 | grep -E "Data format|estimated duration"; done
```

Expected: each is `1 ch, 22050 Hz, .mp3`, lasting about 1.67 s, 1.07 s and 1.38 s. (`pubspec.yaml` already lists `assets/audio/voices/buddy/`.)

- [ ] **Step 5: Preload them**

In `lib/services/audio_service.dart`, replace

```dart
  /// v1.1 brush flow + streak flame lines (spec 2026-10-05 §7.3, §9).
  static const _brushFlowVoices = [
```

with

```dart
  /// v1.1 brush flow + streak flame lines (spec 2026-10-05 §7.3, §9), and
  /// the steps' instruction lines (spec 2026-10-15 §3.2).
  static const _brushFlowVoices = [
```

and end the list with:

```dart
    'voice_need_more_brushes.mp3',
    'voice_ready_to_unlock.mp3',
    'voice_step_pick_hero.mp3',
    'voice_step_pick_weapon.mp3',
    'voice_step_pick_world.mp3',
  ];
```

- [ ] **Step 6: The entry lines**

In `lib/screens/pre_brush_screen.dart`, replace `_entryLines` (lines 280–291):

```dart
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
```

with:

```dart
  /// What the step asks him to do, then how far its goal is (spec
  /// 2026-10-15 §3.2). The item's own description plays when he taps it.
  List<String> _entryLines(PreBrushStep step) => [
    switch (step) {
      PreBrushStep.hero => 'voice_step_pick_hero.mp3',
      PreBrushStep.weapon => 'voice_step_pick_weapon.mp3',
      PreBrushStep.world => 'voice_step_pick_world.mp3',
    },
    _progressLine(_goalFor(step)),
  ];
```

The step's lines are now at most about 2.8 s, so the cap's comment (lines 58–62) needs new reasons; the 12 s value stays. Replace:

```dart
  /// A voice that never ends cannot hold a step: past this the idle count
  /// runs anyway. Longer than the longest real wait: a world line and its
  /// progress line (7.8 s), an unlock's intro line (8.8 s).
```

with:

```dart
  /// A voice that never ends cannot hold a step: past this the idle count
  /// runs anyway. Longer than the longest real wait: a description he taps
  /// and its nudge (about 8 s), an unlock's intro line (8.8 s).
```

`_Loadout` keeps `heroId`, `heroStage`, `weaponId` and `worldId`: `_refresh` and the session analytics still use them.

- [ ] **Step 7: Run the tests**

Run: `flutter test test/screens/pre_brush_screen_test.dart test/audio/audio_assets_test.dart`
Expected: all PASS. If a timing assertion misses by one 50 ms frame, check the frame arithmetic in that test before touching the screen: the screen's timings are the spec's.

- [ ] **Step 8: Format, analyze, full suite**

Run: `dart format lib test && dart analyze && dart run dart_code_linter:metrics analyze lib && flutter test`
Expected: "No issues found!", DCM "no issues found!", all tests pass (1262).

- [ ] **Step 9: Commit**

```bash
git add assets/audio/voices/buddy/voice_step_pick_hero.mp3 assets/audio/voices/buddy/voice_step_pick_weapon.mp3 assets/audio/voices/buddy/voice_step_pick_world.mp3 lib/services/audio_service.dart lib/screens/pre_brush_screen.dart test/audio/audio_assets_test.dart test/screens/pre_brush_screen_test.dart
git commit -m "feat(pre-brush): each step opens with what to do, then how far the goal is

\"Pick the hero who'll brush with you!\", \"Now pick your weapon!\" and
\"Pick the world where you'll fight!\" replace the item descriptions on
entry; a tap on an item still plays its description.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01STWCtX8pE4SLhUiiBxVG9M"
```

---

### Task 3: One header on the three steps

**Files:**
- Modify: `lib/screens/brush_mode.dart:7-21` (comment, constructor), `:41-43` (new field)
- Modify: `lib/screens/hero_shop_screen.dart:688-733` (the tab bar)
- Modify: `lib/screens/world_map_screen.dart:196-198` (after the title row)
- Modify: `lib/screens/pre_brush_screen.dart`:
  - imports `:13-14`
  - class comment `:44-50`
  - fields `:130-141`
  - `dispose` `:188-192`
  - `_enterStep` `:313`
  - `_onTabChanged` `:352-357`
  - `transitionBuilder` `:675-683`
- Modify: `test/screens/hero_shop_brush_mode_test.dart`, `test/screens/world_map_brush_mode_test.dart`, `test/screens/pre_brush_screen_test.dart`
- Unchanged and must still pass: `test/screens/hero_shop_screen_test.dart`, `test/screens/world_map_screen_test.dart`

**Interfaces:**
- Consumes (Task 1): `StepHeader({required ValueListenable<int> current, required ValueChanged<int> onTap})`, `StepHeader.height`, the keys `step_tab_<i>`, the label colours. Consumes (Task 2): the entry lines.
- Produces (Task 4 relies on these):
  - `BrushMode({..., required Widget header})` with `final Widget header`.
  - In brush mode `HeroShopScreen` has no `TabBar`; `brushMode.header` sits where it was, and swipes still change the tab. `WorldMapScreen` shows `brushMode.header` under its title row, then an 8 px gap.
  - `PreBrushScreen` hands the pages `StepHeader(key: ValueKey('prebrush_header'), ...)`, keeps it lit on the current step, and enters the tapped step (`_onHeaderTap`).
  - `bool _backward`: true when the last step change went to an earlier step; the shop and the Map then slide the other way.

- [ ] **Step 1: The page tests**

In `test/screens/hero_shop_brush_mode_test.dart`:

Replace the file's opening comment (lines 1–4) with:

```dart
// test/screens/hero_shop_brush_mode_test.dart
//
// The Heroes & Weapons page in brush mode (spec 2026-10-13 §4, §5; the
// steps' header, spec 2026-10-15 §3.1) and the pins that it is unchanged
// when opened from Home (R6).
```

After `import 'package:brush_quest/widgets/goal_glow.dart';` add:

```dart
import 'package:brush_quest/widgets/step_header.dart';
```

In `_Steps`, replace `late final mode = BrushMode(...)` with:

```dart
  late final mode = BrushMode(
    onClose: () => closes++,
    tab: tab,
    onTabChanged: tabsReported.add,
    highlightId: highlight,
    reveal: reveal,
    onChanged: changes.add,
    // Stands in for the steps' header: as wide as the page, as tall as the
    // real one.
    header: const SizedBox(
      key: ValueKey('steps_header'),
      width: double.infinity,
      height: StepHeader.height,
    ),
  );
```

After the helper `shopVisits()` add:

```dart
  int tabIndex(WidgetTester tester) =>
      tester.widget<TabBarView>(find.byType(TabBarView)).controller!.index;

  /// A swipe across the tabs. It reaches the tab controller only once the
  /// page has settled, about 0.75 s after the fling.
  Future<void> swipe(WidgetTester tester, double dx) async {
    await tester.fling(find.byType(TabBarView), Offset(dx, 0), 1500);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }
```

In the test `'no entry line, tab line, music or shop visit'`, replace:

```dart
      await tester.tap(find.text('WEAPONS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(fakeAudio.playedVoiceLines, isEmpty);
```

with:

```dart
      // Its tab bar is hidden: a swipe is how the page itself changes tab.
      await swipe(tester, -300);
      expect(fakeAudio.playedVoiceLines, isEmpty);
```

In the test `'follows the steps to WEAPONS without reporting it back'`, replace `expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 1);` with `expect(tabIndex(tester), 1);`.

Replace the whole test `'reports a tab tap and a swipe to the steps'` with these two tests:

```dart
    testWidgets('reports a swipe either way to the steps', (tester) async {
      final steps = await pumpShop(tester);
      await swipe(tester, -300);
      expect(steps.tabsReported, [1]);
      steps.tab.value = 1; // the steps take the weapon step
      await tester.pump(const Duration(milliseconds: 400));
      await swipe(tester, 300);
      expect(steps.tabsReported, [1, 0]);
      expect(fakeAudio.playedVoiceLines, isEmpty); // no tab lines
    });

    testWidgets("the steps' header takes the place of its tab bar", (
      tester,
    ) async {
      await pumpShop(tester, brush: false);
      final tabBar = tester.getRect(find.byType(TabBar));
      final pageTop = tester.getRect(find.byType(TabBarView)).top;
      await tester.pumpWidget(const SizedBox()); // a fresh page next
      await tester.pump(const Duration(seconds: 1));
      await pumpShop(tester);
      expect(find.byType(TabBar), findsNothing);
      final header = tester.getRect(find.byKey(const ValueKey('steps_header')));
      expect(header.top, tabBar.top);
      expect(header.bottom, tabBar.bottom);
      // Below it the heroes and weapons start where they do from Home.
      expect(tester.getRect(find.byType(TabBarView)).top, pageTop);
    });
```

The `SizedBox` pump in between matters: a brush-mode page must not replace a Home-mode one in place, because the page asserts that its `brushMode` never changes.

In the group `'from Home (unchanged)'`, replace the start of `'a back arrow, its own padding, no X and no glow'`:

```dart
    testWidgets('a back arrow, its own padding, no X and no glow', (
      tester,
    ) async {
      await pumpShop(tester, brush: false);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
```

with:

```dart
    testWidgets('a back arrow, its own tab bar and padding, no X and no glow', (
      tester,
    ) async {
      await pumpShop(tester, brush: false);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);
```

In `test/screens/world_map_brush_mode_test.dart`:

Replace the comment after the file name (lines 3–6) with:

```dart
// The Map in brush mode (spec 2026-10-13 §4, §5; the steps' header, spec
// 2026-10-15 §3.1) and the pins that it is unchanged when opened from Home
// (R6). Test order matters: the first test opens the Map in brush mode, and
// the second checks that this did not use up the once-a-session intro (a
// static flag).
```

(The first two tests keep their places; the new test below goes third.)

After `import 'package:brush_quest/widgets/goal_glow.dart';` add `import 'package:brush_quest/widgets/step_header.dart';`.

In `_Steps`, replace `late final mode = BrushMode(...)` with:

```dart
  late final mode = BrushMode(
    onClose: () => closes++,
    tab: tab,
    onTabChanged: (_) {},
    highlightId: highlight,
    reveal: reveal,
    onChanged: changes.add,
    // Stands in for the steps' header: as wide as the page, as tall as the
    // real one.
    header: const SizedBox(
      key: ValueKey('steps_header'),
      width: double.infinity,
      height: StepHeader.height,
    ),
  );
```

Just before the test `'an X instead of the back arrow; it asks the steps to close'` (line 134), add:

```dart
  testWidgets("brush mode: the steps' header under the title row, as on the "
      'shop', (tester) async {
    await pumpMap(tester);
    final header = tester.getRect(find.byKey(const ValueKey('steps_header')));
    final close = tester.getRect(find.byKey(const ValueKey('brush_close')));
    // The title row is the X with 16 px around it.
    expect(header.top, close.bottom + 16);
    expect(header.height, StepHeader.height);
    // 8 px below it, as on the shop, the path begins.
    expect(scrollView(tester).top, header.bottom + 8);
  });
```

- [ ] **Step 2: The step tests**

In `test/screens/pre_brush_screen_test.dart`:

Replace the helper (lines 174–175)

```dart
  int tabIndex(WidgetTester tester) =>
      tester.widget<TabBar>(find.byType(TabBar)).controller!.index;
```

with:

```dart
  /// The shop's tab (its own tab bar is hidden in brush mode).
  int tabIndex(WidgetTester tester) =>
      tester.widget<TabBarView>(find.byType(TabBarView)).controller!.index;
  final header = find.byKey(const ValueKey('prebrush_header'));
  Finder headerTab(PreBrushStep step) =>
      find.byKey(ValueKey('step_tab_${step.index}'));
  Color labelColor(WidgetTester tester, String label) =>
      tester.widget<Text>(find.text(label)).style!.color!;
```

Replace the whole test `'tapping a tab is a step change, with that step\'s lines'` (under `// ── Tabs ──`) with these five tests:

```dart
  testWidgets('one header on every step, the step he is on lit', (
    tester,
  ) async {
    await pumpScreen(tester, returningKid);
    expect(header, findsOneWidget);
    // The page's own HEROES/WEAPONS bar gives way to it.
    expect(find.byType(TabBar), findsNothing);
    expect(labelColor(tester, 'HEROES'), Colors.white);
    expect(labelColor(tester, 'WEAPONS'), Colors.white54);
    expect(labelColor(tester, 'WORLD'), Colors.white54);
    await tapGo(tester);
    await pumpFor(tester, goSettled);
    expect(header, findsOneWidget);
    expect(labelColor(tester, 'HEROES'), Colors.white54);
    expect(labelColor(tester, 'WEAPONS'), Colors.white);
    await tapGo(tester);
    await pumpFor(tester, const Duration(milliseconds: 500)); // the slide
    expect(find.byType(WorldMapScreen), findsOneWidget);
    expect(header, findsOneWidget);
    expect(labelColor(tester, 'WEAPONS'), Colors.white54);
    expect(labelColor(tester, 'WORLD'), Colors.white);
    expect(find.byType(TabBar), findsNothing);
  });

  testWidgets('a header tab goes to its step with its lines, the Map too', (
    tester,
  ) async {
    await pumpScreen(tester, returningKid);
    audio.resetTracking();
    await tester.tap(headerTab(PreBrushStep.world));
    await tester.pump();
    expect(stepIs(PreBrushStep.world), findsOneWidget);
    expect(voices(), ['voice_step_pick_world.mp3', 'voice_brushes_left_3.mp3']);
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.byType(WorldMapScreen), findsOneWidget);
    expect(find.byType(HeroShopScreen), findsNothing);
    expect(glowOn('planet_slime_swamp'), findsOneWidget);

    audio.resetTracking();
    await tester.tap(headerTab(PreBrushStep.weapon));
    await tester.pump();
    expect(stepIs(PreBrushStep.weapon), findsOneWidget);
    expect(voices(), ['voice_step_pick_weapon.mp3', 'voice_stars_left_2.mp3']);
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.byType(WorldMapScreen), findsNothing);
    expect(tabIndex(tester), 1); // the shop comes back on its WEAPONS tab
    expect(glowOn('weapon_card_flame_sword'), findsOneWidget);

    audio.resetTracking();
    await tester.tap(headerTab(PreBrushStep.hero));
    await tester.pump();
    expect(stepIs(PreBrushStep.hero), findsOneWidget);
    expect(voices(), ['voice_step_pick_hero.mp3', 'voice_stars_left_2.mp3']);
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(tabIndex(tester), 0);
    expect(glowOn('evo_cell_frost_stage1'), findsOneWidget);
    // The steps speak, never the page's tab lines.
    expect(
      audio
          .callsFor('playVoice')
          .where((c) => '${c.args['fileName']}'.startsWith('voice_tab_')),
      isEmpty,
    );
  });

  testWidgets('the lit tab does nothing', (tester) async {
    await pumpScreen(tester, returningKid);
    final heard = voices().length;
    await tester.tap(headerTab(PreBrushStep.hero));
    await tester.pump();
    expect(stepIs(PreBrushStep.hero), findsOneWidget);
    expect(voices(), hasLength(heard));
  });

  testWidgets('going back, the page comes in from the left', (tester) async {
    await pumpScreen(tester, returningKid);
    await tapGo(tester);
    await pumpFor(tester, goSettled);
    await tapGo(tester);
    await pumpFor(tester, const Duration(milliseconds: 200)); // mid-slide
    // On to the Map: it comes in from the right, the shop leaves left.
    expect(tester.getTopLeft(find.byType(WorldMapScreen)).dx, greaterThan(0));
    expect(tester.getTopLeft(find.byType(HeroShopScreen)).dx, lessThan(0));
    await pumpFor(tester, const Duration(milliseconds: 300));
    await tester.tap(headerTab(PreBrushStep.hero));
    await tester.pump();
    await pumpFor(tester, const Duration(milliseconds: 200)); // mid-slide
    // Back to the shop: it comes in from the left, the Map leaves right.
    expect(tester.getTopLeft(find.byType(HeroShopScreen)).dx, lessThan(0));
    expect(tester.getTopLeft(find.byType(WorldMapScreen)).dx, greaterThan(0));
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(tester.getTopLeft(find.byType(HeroShopScreen)).dx, 0);
  });

  testWidgets('a header tap as the Map slides in: HEROES, cleanly', (
    tester,
  ) async {
    await pumpScreen(tester, returningKid);
    await tapGo(tester);
    await pumpFor(tester, goSettled);
    await tapGo(tester); // the Map slides in
    await pumpFor(tester, const Duration(milliseconds: 150));
    // Two headers for now: the shop's, leaving (it takes no taps), and the
    // Map's, coming in.
    expect(header, findsNWidgets(2));
    await tester.tap(headerTab(PreBrushStep.hero).last);
    await tester.pump();
    expect(stepIs(PreBrushStep.hero), findsOneWidget);
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull); // no duplicate GlobalKey
    expect(find.byType(WorldMapScreen), findsNothing);
    expect(find.byType(HeroShopScreen), findsOneWidget);
    expect(header, findsOneWidget);
    expect(tabIndex(tester), 0);
    expect(glowOn('evo_cell_frost_stage1'), findsOneWidget);
    expect(voices().sublist(voices().length - 2), [
      'voice_step_pick_hero.mp3',
      'voice_stars_left_2.mp3',
    ]);
  });
```

(`.last` is the Map's header: in the switcher's stack, the page leaving comes first.)

Just before the test `'"Let\'s fight!" plays out before brushing starts'` (line 986), add:

```dart
  testWidgets('after "Let\'s fight!" the header changes nothing', (
    tester,
  ) async {
    await pumpScreen(tester, returningKid);
    await goToTheFight(tester);
    audio.voicePipelineActiveNotifier.value = true; // hold the launch
    final heard = voices().length;
    await tester.tap(
      headerTab(PreBrushStep.hero),
      warnIfMissed: false, // ignored on purpose
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(stepIs(PreBrushStep.world), findsOneWidget);
    expect(voices().sublist(heard), isEmpty);
    audio.voicePipelineActiveNotifier.value = false;
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.text('BRUSHING'), findsOneWidget);
  });
```

In the phone tests (`'fits a $name phone on every step, GO on screen'`), after `expect(tester.takeException(), isNull, reason: step.name);` add:

```dart
        final headerRect = tester.getRect(header);
        expect(
          screen.intersect(headerRect),
          headerRect,
          reason: '${step.name}: $headerRect',
        );
```

- [ ] **Step 3: Run them to make sure they fail**

Run: `flutter test test/screens/hero_shop_brush_mode_test.dart test/screens/world_map_brush_mode_test.dart test/screens/pre_brush_screen_test.dart`
Expected: FAIL to compile: `BrushMode` has no named parameter `header`.

- [ ] **Step 4: `BrushMode.header`**

In `lib/screens/brush_mode.dart`, replace the class comment and constructor (lines 7–21):

```dart
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
```

with:

```dart
/// What the Heroes & Weapons page and the Map need to run as a step of the
/// brush flow (spec
/// docs/superpowers/specs/2026-10-13-brush-steps-on-real-pages-design.md
/// §5, and 2026-10-15-sticker-card-design.md §3). A page built without one
/// behaves exactly as when it is opened from Home. A page keeps the same
/// instance for its whole life.
@immutable
class BrushMode {
  const BrushMode({
    required this.onClose,
    required this.tab,
    required this.onTabChanged,
    required this.highlightId,
    required this.reveal,
    required this.onChanged,
    required this.header,
  });
```

and replace the class's last field (lines 41–43):

```dart
  /// After a selection or an unlock on the page.
  final ValueChanged<BrushChange> onChanged;
}
```

with:

```dart
  /// After a selection or an unlock on the page.
  final ValueChanged<BrushChange> onChanged;

  /// The steps' HEROES · WEAPONS · WORLD header. The page shows it under its
  /// title row: the Heroes & Weapons page in place of its own tab bar, the
  /// Map in the same place.
  final Widget header;
}
```

- [ ] **Step 5: The shop shows the header in place of its tab bar**

In `lib/screens/hero_shop_screen.dart` `build`, replace the tab bar (lines 688–733, from `// Tab bar` through the `),` that closes its `Container`, just before `const SizedBox(height: 8),`) with:

```dart
              // Tab bar. Brush mode: the steps' header takes its place (spec
              // 2026-10-15 §3.1); a swipe still changes the tab.
              if (brush != null)
                brush.header
              else
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: const Color(0xFF7C4DFF).withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 2,
                    ),
                    tabs: const [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shield, size: 20),
                            SizedBox(width: 8),
                            Text('HEROES'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bolt, size: 20),
                            SizedBox(width: 8),
                            Text('WEAPONS'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
```

From Home it is the same `Container` and `TabBar` as before, one level deeper. `brush` is the `final brush = widget.brushMode;` already at the top of `build`. Nothing else in the page changes: `_tabController`, the `TabBarView` and `_onTabControllerChanged` (swipes report through `onTabChanged`) stay.

- [ ] **Step 6: The Map shows the header under its title row**

In `lib/screens/world_map_screen.dart` `build`, between the title row's `Padding` (it ends at line 196) and `// World path — scrollable adventure trail`, add:

```dart
              // Brush mode: the steps' header, where the Heroes & Weapons
              // page has its tab bar (spec 2026-10-15 §3.1).
              if (brush != null) ...[brush.header, const SizedBox(height: 8)],

```

- [ ] **Step 7: The coordinator builds, lights and follows the header**

In `lib/screens/pre_brush_screen.dart`:

After `import '../widgets/space_background.dart';` add `import '../widgets/step_header.dart';`.

Replace the class comment (lines 44–50) with:

```dart
/// Hero → Weapon → World before each brush, on the real pages (spec
/// docs/superpowers/specs/2026-10-13-brush-steps-on-real-pages-design.md,
/// amended by 2026-10-15-sticker-card-design.md §3): the Heroes & Weapons
/// page on its HEROES tab, the same page on its WEAPONS tab, then the Map,
/// each in brush mode under one HEROES · WEAPONS · WORLD header and above a
/// big GO. A step also moves on by itself after [idleAdvance] with no touch,
/// scroll or dialog once the voice is quiet. After the Map: "Let's fight!",
/// then brushing.
```

Replace the fields from `// What the pages follow.` through the end of `_brushMode` (lines 130–141) with:

```dart
  // What the pages follow.
  final _tab = ValueNotifier<int>(0);
  final _highlight = ValueNotifier<String?>(null);
  final _reveal = BrushPing();

  /// The step the header lights (a [PreBrushStep] index).
  final _headerStep = ValueNotifier<int>(0);
  late final BrushMode _brushMode = BrushMode(
    onClose: _onClose,
    tab: _tab,
    onTabChanged: _onTabChanged,
    highlightId: _highlight,
    reveal: _reveal,
    onChanged: _onPageChanged,
    header: StepHeader(
      key: const ValueKey('prebrush_header'),
      current: _headerStep,
      onTap: _onHeaderTap,
    ),
  );

  /// The last step change went back (a header tap): the shop and the Map
  /// then slide the other way.
  bool _backward = false;
```

In `dispose()`, after `_reveal.dispose();` add `_headerStep.dispose();`. (The pages and the header, children of this screen, have already removed their listeners.)

In `_enterStep`, replace `setState(() => _step = step);` with:

```dart
    setState(() {
      _backward = step.index < _step.index;
      _step = step;
    });
    _headerStep.value = step.index;
```

Replace `_onTabChanged` (lines 352–357) with:

```dart
  /// A swipe on the Heroes & Weapons page (its own tab bar is hidden in
  /// brush mode).
  void _onTabChanged(int index) {
    if (!_entered || _leaving || _step == PreBrushStep.world) return;
    final step = index == 1 ? PreBrushStep.weapon : PreBrushStep.hero;
    if (step != _step) _enterStep(step);
  }

  /// A tab of the steps' header: that step, with its lines (spec 2026-10-15
  /// §3.1). The page follows: the shop's tabs slide, or the shop and the Map
  /// change places. The lit tab does nothing, as a tab bar's lit tab.
  void _onHeaderTap(int index) {
    if (!_entered || _leaving) return;
    final step = PreBrushStep.values[index];
    if (step != _step) _enterStep(step);
  }
```

In `_buildSteps`, replace the `transitionBuilder` and its comment (lines 675–683):

```dart
                // A new closure each build: Flutter then rebuilds the page
                // on its way out with the outgoing slide (to the left).
                transitionBuilder: (child, animation) => SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset(child.key == pageKey ? 1.0 : -1.0, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
```

with:

```dart
                // A new closure each build: Flutter then rebuilds the page
                // on its way out with this build's slide. Going on, the new
                // page comes in from the right and the old one leaves to the
                // left; going back, the other way round.
                transitionBuilder: (child, animation) {
                  final fromRight = (child.key == pageKey) != _backward;
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset(fromRight ? 1.0 : -1.0, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  );
                },
```

The `IgnorePointer(ignoring: _leaving)` around the pages now covers the header too (it lives in the page), so after "Let's fight!" the header takes no taps (ruling R-2). `_onHeaderTap`'s own `_leaving` check is a second guard.

- [ ] **Step 8: Run the tests**

Run: `flutter test test/screens/hero_shop_brush_mode_test.dart test/screens/world_map_brush_mode_test.dart test/screens/hero_shop_screen_test.dart test/screens/world_map_screen_test.dart test/screens/pre_brush_screen_test.dart`
Expected: all PASS. (In the dry run, `'going back, the page comes in from the left'` failed with the old one-way slide: the shop's left edge was +55 px instead of below 0.)

- [ ] **Step 9: Format, analyze, full suite**

Run: `dart format lib test && dart analyze && dart run dart_code_linter:metrics analyze lib && flutter test`
Expected: "No issues found!", DCM "no issues found!", all tests pass (1269).

- [ ] **Step 10: Commit**

```bash
git add lib/screens/brush_mode.dart lib/screens/hero_shop_screen.dart lib/screens/world_map_screen.dart lib/screens/pre_brush_screen.dart test/screens/hero_shop_brush_mode_test.dart test/screens/world_map_brush_mode_test.dart test/screens/pre_brush_screen_test.dart
git commit -m "feat(pre-brush): one HEROES · WEAPONS · WORLD header on the three steps

The steps hand the pages one header: the Heroes & Weapons page shows it
in place of its own tab bar, the Map in the same place. A tap goes to
that step with its lines; going back, the page slides in from the left.
Pages opened from Home are unchanged.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01STWCtX8pE4SLhUiiBxVG9M"
```

---

### Task 4: The back gesture goes one step back

**Files:**
- Modify: `lib/screens/pre_brush_screen.dart`:
  - `_backward`'s comment (added in Task 3)
  - `_onClose` (line 593)
  - `_onPop` (lines 595–604)
  - `build`'s `PopScope` (lines 610–611)
- Modify: `test/screens/pre_brush_screen_test.dart`

**Interfaces:**
- Consumes (Task 3): `_enterStep` setting `_backward`; the header and its keys; `tabIndex`. Consumes (Task 2): the entry lines.
- Produces:
  - `bool get _canPop` is true before the first step, after "Let's fight!" and on HEROES, so the back gesture goes Home from there.
  - On WEAPONS and the Map, `canPop` is false and a back calls `_onPop(false, …)`, which runs `_stepBack()` (WORLD → WEAPONS, WEAPONS → HEROES).
  - The X calls `Navigator.pop()`.

- [ ] **Step 1: Write the failing tests**

In `test/screens/pre_brush_screen_test.dart`:

Replace the file's opening comment (lines 1–6) with:

```dart
// test/screens/pre_brush_screen_test.dart
//
// The brush steps on the real pages (spec
// docs/superpowers/specs/2026-10-13-brush-steps-on-real-pages-design.md,
// amended by 2026-10-15-sticker-card-design.md §3): HEROES tab → WEAPONS
// tab → Map under one header, the instruction lines, GO and the idle count,
// dialogs, the background, X, the back gesture, "Let's fight!" and the
// voice timelines.
```

Just before the helper comment `/// Installs a voice channel that takes time, with its clock on the test's` add:

```dart
  /// A system back (Android's back button or gesture): the message the
  /// engine sends, as Flutter's own navigator tests do.
  Future<void> systemBack(WidgetTester tester) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMessageCodec().encodeMessage(const {'method': 'popRoute'}),
      (_) {},
    );
    await tester.pump();
  }

  /// From a stand-in Home, GO twice: the Map, slid in.
  Future<void> openOnTheMap(WidgetTester tester) async {
    await openFromHome(tester);
    await tapGo(tester);
    await pumpFor(tester, goSettled);
    await tapGo(tester);
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(stepIs(PreBrushStep.world), findsOneWidget);
  }

```

Just before the test `'back after "Let\'s fight!" goes Home; brushing never starts'` add:

```dart
  testWidgets('the back gesture: the Map, WEAPONS, HEROES, then Home', (
    tester,
  ) async {
    PreBrushScreen.idleAdvance = const Duration(seconds: 30);
    SharedPreferences.setMockInitialValues(returningKid);
    await openOnTheMap(tester);

    audio.resetTracking();
    await systemBack(tester);
    expect(stepIs(PreBrushStep.weapon), findsOneWidget);
    expect(voices(), ['voice_step_pick_weapon.mp3', 'voice_stars_left_2.mp3']);
    await pumpFor(tester, const Duration(milliseconds: 100));
    // The shop comes back from the left, on its WEAPONS tab, its glow on.
    expect(tester.getTopLeft(find.byType(HeroShopScreen)).dx, lessThan(0));
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(find.byType(WorldMapScreen), findsNothing);
    expect(tabIndex(tester), 1);
    expect(glowOn('weapon_card_flame_sword'), findsOneWidget);

    audio.resetTracking();
    await systemBack(tester);
    expect(stepIs(PreBrushStep.hero), findsOneWidget);
    expect(voices(), ['voice_step_pick_hero.mp3', 'voice_stars_left_2.mp3']);
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(tabIndex(tester), 0);
    expect(find.byType(PreBrushScreen), findsOneWidget);

    await systemBack(tester);
    await tester.pumpAndSettle();
    expect(find.byType(PreBrushScreen), findsNothing);
    expect(find.byKey(const ValueKey('open')), findsOneWidget);
    expect(audio.callsFor('stopVoice'), isNotEmpty);
    expect(launchedWithIntro, isNull);
  });

  testWidgets('X goes Home from the Map, not one step back', (tester) async {
    PreBrushScreen.idleAdvance = const Duration(seconds: 30);
    SharedPreferences.setMockInitialValues(returningKid);
    await openOnTheMap(tester);
    final heard = voices().length;
    await tester.tap(find.byKey(const ValueKey('brush_close')));
    await tester.pumpAndSettle();
    expect(find.byType(PreBrushScreen), findsNothing);
    expect(find.byKey(const ValueKey('open')), findsOneWidget);
    expect(voices(), hasLength(heard)); // no WEAPONS lines on the way out
    expect(launchedWithIntro, isNull);
  });

  testWidgets('the back gesture with a dialog open closes only the dialog', (
    tester,
  ) async {
    PreBrushScreen.idleAdvance = const Duration(seconds: 30);
    SharedPreferences.setMockInitialValues(kid({'star_wallet': 6}));
    await openFromHome(tester);
    await tapGo(tester);
    await pumpFor(tester, const Duration(milliseconds: 500));
    // The Flame Sword (5) is his to buy: its confirmation opens.
    await tester.tap(find.byKey(const ValueKey('weapon_card_flame_sword')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Get FLAME SWORD?'), findsOneWidget);
    final heard = voices().length;
    await systemBack(tester);
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(find.text('Get FLAME SWORD?'), findsNothing);
    expect(stepIs(PreBrushStep.weapon), findsOneWidget);
    expect(voices(), hasLength(heard));
    final saved = await SharedPreferences.getInstance();
    expect(saved.getInt('star_wallet'), 6); // nothing bought
  });

  testWidgets('two quick backs from the Map: HEROES; one more is Home', (
    tester,
  ) async {
    PreBrushScreen.idleAdvance = const Duration(seconds: 30);
    SharedPreferences.setMockInitialValues(returningKid);
    await openOnTheMap(tester);
    await systemBack(tester);
    await tester.pump(const Duration(milliseconds: 100)); // shop sliding in
    await systemBack(tester);
    expect(stepIs(PreBrushStep.hero), findsOneWidget);
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    expect(find.byType(WorldMapScreen), findsNothing);
    expect(tabIndex(tester), 0);
    expect(voices().sublist(voices().length - 2), [
      'voice_step_pick_hero.mp3',
      'voice_stars_left_2.mp3',
    ]);
    await systemBack(tester);
    await tester.pumpAndSettle();
    expect(find.byType(PreBrushScreen), findsNothing);
  });

  testWidgets('after a step back the count runs again, and GO works', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(returningKid);
    await openOnTheMap(tester);
    await systemBack(tester); // WEAPONS
    final waited = await pumpUntilFound(tester, stepIs(PreBrushStep.world));
    expect(waited, greaterThanOrEqualTo(PreBrushScreen.idleAdvance));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await systemBack(tester); // WEAPONS again
    await pumpFor(tester, goSettled);
    await tapGo(tester);
    expect(stepIs(PreBrushStep.world), findsOneWidget);
  });

```

In the test `'back after "Let\'s fight!" goes Home; brushing never starts'`, send a real system back. Replace:

```dart
    unawaited(tester.state<NavigatorState>(find.byType(Navigator)).maybePop());
```

with:

```dart
    await systemBack(tester); // Home, not the Map: ruling 2 stands
```

(`dart:async` stays imported: other tests still use `unawaited`.)

- [ ] **Step 2: Run them to make sure they fail**

Run: `flutter test test/screens/pre_brush_screen_test.dart`
Expected: FAIL in exactly three tests, where the back gesture still goes Home from the Map: `'the back gesture: the Map, WEAPONS, HEROES, then Home'`, `'two quick backs from the Map: HEROES; one more is Home'` and `'after a step back the count runs again, and GO works'`. Three tests already pass and must keep passing: `'X goes Home from the Map, not one step back'`, `'the back gesture with a dialog open closes only the dialog'` and `'back after "Let\'s fight!" ...'`. They pin what this task must not break; in the dry run the first failed when the X kept `maybePop()`, and the last when `_leaving` was left out of `_canPop`.

- [ ] **Step 3: Implement the way back**

In `lib/screens/pre_brush_screen.dart`, update `_backward`'s comment (from Task 3):

```dart
  /// The last step change went back (a header tap or the back gesture): the
  /// shop and the Map then slide the other way.
  bool _backward = false;
```

Replace `_onClose` and `_onPop` (lines 593–604):

```dart
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
```

with:

```dart
  /// The X: Home from any step (spec 2026-10-15 §3.3). pop() leaves
  /// whatever the back gesture would do aside; [_onPop] then goes quiet.
  void _onClose() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  /// The back gesture leaves the screen only from HEROES, before the first
  /// step and after "Let's fight!" (ruling 2 of the rebuilt steps); on
  /// WEAPONS and the Map it goes one step back.
  bool get _canPop => !_entered || _leaving || _step == PreBrushStep.hero;

  void _onPop(bool didPop, Object? result) {
    if (!didPop) {
      _stepBack();
      return;
    }
    // Go quiet: the screen stays mounted (and its voice listener live)
    // during the exit animation.
    _closed = true;
    _leaving = true;
    _stopCounting();
    _cancelLaunch();
    unawaited(_audio.stopVoice());
  }

  /// The back gesture on WEAPONS or the Map: the step before, with its
  /// lines (spec 2026-10-15 §3.3).
  void _stepBack() {
    if (!_entered || _leaving) return;
    switch (_step) {
      case PreBrushStep.hero:
        return; // [_canPop] lets this one through to Home
      case PreBrushStep.weapon:
        _enterStep(PreBrushStep.hero);
      case PreBrushStep.world:
        _enterStep(PreBrushStep.weapon);
    }
  }
```

In `build`, give the `PopScope` its `canPop`:

```dart
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: _onPop,
      child: Scaffold(
```

`_enterStep`'s `setState` rebuilds the `PopScope`, so `canPop` follows each step change. A back while a dialog is open pops the dialog's own route first and never reaches this `PopScope`. The route Home pushes is a fade `PageRouteBuilder`, with no iOS edge swipe, so Android's back button and gesture are the only back gestures.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/screens/pre_brush_screen_test.dart test/screens/home_screen_test.dart test/screens/home_flame_test.dart`
Expected: all PASS.

- [ ] **Step 5: Format, analyze, full suite**

Run: `dart format lib test && dart analyze && dart run dart_code_linter:metrics analyze lib && flutter test`
Expected: "No issues found!", DCM "no issues found!", all tests pass (1274).

- [ ] **Step 6: Commit**

```bash
git add lib/screens/pre_brush_screen.dart test/screens/pre_brush_screen_test.dart
git commit -m "feat(pre-brush): the back gesture goes one step back; X still goes Home

World -> Weapons -> Heroes -> Home. During \"Let's fight!\" back still goes
Home. A back with a dialog open closes only the dialog.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01STWCtX8pE4SLhUiiBxVG9M"
```

---

### Task 5: The brushing screen without the counter and the sign

**Files:**
- Modify: `lib/screens/brushing_screen.dart`:
  - `:1868-1872` (delete `_getPhaseProgress`)
  - `:2238-2252` (the sign under the timer)
  - `:2553-2605` (`_buildMissionHud`'s counter)
  - `:4640-4933` (delete `_SmallBurstPainter` and `_PhaseProgressIconPainter`)
- Modify: `test/screens/brushing_screen_test.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks (independent of Tasks 1–4).
- Produces: nothing new. The victory screen still gets `monstersDefeated` (`_monstersDefeated` stays: it is counted and passed on). `_timerPulseController` stays: the timer uses it.

- [ ] **Step 1: Write the failing test**

In `test/screens/brushing_screen_test.dart`, after `import 'package:brush_quest/screens/brushing_screen.dart';` add:

```dart
import 'package:brush_quest/widgets/mouth_guide.dart';
```

and at the end of `main()`, after the test `'world intro has a close button'`, add:

```dart
  testWidgets('brushing: the mouth guide and the seconds, no monster counter '
      'and no sign under the timer', (tester) async {
    // A fresh checkpoint: the screen opens mid-brush, 20 s into a zone.
    SharedPreferences.setMockInitialValues({
      'phase_duration': 30,
      'camera_enabled': false,
      'camera_mode_configured': true,
      'selected_hero': 'blaze',
      'selected_weapon': 'star_blaster',
      'current_world': 'candy_crater',
      'muted': false,
      'total_brushes': 5,
      'session_checkpoint_ts': DateTime.now().millisecondsSinceEpoch,
      'session_checkpoint_phase': 'topLeft',
      'session_checkpoint_seconds': 20,
      'session_checkpoint_world': 'candy_crater',
    });
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // The game screen's own layout is not under test here.
    final origOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) return;
      origOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = origOnError);

    await tester.pumpWidget(const MaterialApp(home: BrushingScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // The painters are private: match them by name.
    Finder painted(String painter) => find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint && '${widget.painter.runtimeType}' == painter,
      description: 'CustomPaint with a $painter',
    );
    expect(find.byType(MouthGuide), findsOneWidget);
    expect(find.text('20'), findsOneWidget); // the zone's seconds
    // The counter: its starburst and its number (0 monsters so far).
    expect(painted('_SmallBurstPainter'), findsNothing);
    expect(find.text('0'), findsNothing);
    // The sign under the timer (crossed swords, shield, hourglass, target).
    expect(painted('_PhaseProgressIconPainter'), findsNothing);

    // Past initState's delays, so no timer outlives the test.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
```

The checkpoint path (`brushing_lifecycle_test.dart` uses it too) opens the screen mid-brush without the countdown. Before this task the screen shows exactly one of each: the starburst, the `'0'`, the sign; and `'20'` and `'0'` are its only two texts.

- [ ] **Step 2: Run it to make sure it fails**

Run: `flutter test test/screens/brushing_screen_test.dart`
Expected: FAIL: "Found 1 widget with CustomPaint with a _SmallBurstPainter".

- [ ] **Step 3: Remove the sign under the timer, keep its room**

In `_buildBrushing` (lines 2238–2252), replace:

```dart
                              // Timer
                              _buildTimer(screenHeight),
                              const SizedBox(height: 4),
                              // Phase-progress icon strip (replaces text encouragements)
                              AnimatedBuilder(
                                animation: _timerPulseController,
                                builder: (context, _) => CustomPaint(
                                  size: const Size(40, 40),
                                  painter: _PhaseProgressIconPainter(
                                    progress: _getPhaseProgress(),
                                    themeColor: _world.themeColor,
                                    pulseValue: _timerPulseController.value,
                                  ),
                                ),
                              ),
                            ],
```

with:

```dart
                              // Timer
                              _buildTimer(screenHeight),
                              // Where the phase sign was (its 4 px gap and
                              // 40 px; spec 2026-10-15 §3.4): the monster,
                              // the hero and the effects placed around them
                              // keep their places.
                              const SizedBox(height: 44),
                            ],
```

- [ ] **Step 4: Remove the monster counter, keep the mouth guide**

In `_buildMissionHud` (lines 2553–2605), replace:

```dart
              // Mouth guide — prominent so the kid sees where to brush
              AnimatedBuilder(
                animation: _mouthGuideGlowController,
                builder: (context, _) => MouthGuide(
                  activeQuadrant:
                      _phaseToMouthQuadrant[_phase] ?? MouthQuadrant.topLeft,
                  glowAnim: _mouthGuideGlowController.value,
                  highlightColor: _world.themeColor,
                  size: 82,
                ),
              ),
              const SizedBox(width: 8),
              // Phase name + zone label
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Monster defeated counter — burst icon + number only
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.34),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CustomPaint(
                            size: const Size(16, 16),
                            painter: _SmallBurstPainter(
                              color: _world.themeColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$_monstersDefeated',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
```

with:

```dart
              // Mouth guide — prominent so the kid sees where to brush. The
              // monster counter beside it is gone (spec 2026-10-15 §3.4); the
              // Row keeps the guide at the left.
              AnimatedBuilder(
                animation: _mouthGuideGlowController,
                builder: (context, _) => MouthGuide(
                  activeQuadrant:
                      _phaseToMouthQuadrant[_phase] ?? MouthQuadrant.topLeft,
                  glowAnim: _mouthGuideGlowController.value,
                  highlightColor: _world.themeColor,
                  size: 82,
                ),
              ),
            ],
```

Keep the `Row`. The column around the HUD centres anything narrower than the screen, so the guide alone would move to the middle. The HUD's height stays 94 px, the guide's own (82 × 1.15), which was always taller than the counter.

- [ ] **Step 5: Delete what is now unused**

Delete `_getPhaseProgress()` and its comment (lines 1868–1872):

```dart
  /// Returns the phase progress as 0.0 to 1.0 (0 = just started, 1 = phase ending)
  double _getPhaseProgress() {
    if (_phaseDuration <= 0) return 0.0;
    return (1.0 - _phaseSecondsLeft / _phaseDuration).clamp(0.0, 1.0);
  }

```

Delete the two painter classes (lines 4640–4933). Delete everything from the comment `/// Small burst/explosion icon for the defeated counter in the HUD.` (with `class _SmallBurstPainter`) through the end of `class _PhaseProgressIconPainter` (its `shouldRepaint` and closing `}`). Stop just before `/// Pulsing pause icon for the pause overlay (replaces static icon + "PAUSED" text).`, and keep one blank line between `_ImpactShapePainter`'s closing `}` and that comment.

Then check that nothing still uses them:

Run: `grep -n "_SmallBurstPainter\|_PhaseProgressIconPainter\|_getPhaseProgress" lib/screens/brushing_screen.dart`
Expected: no output.

- [ ] **Step 6: Run the brushing tests**

Run: `flutter test test/screens/brushing_screen_test.dart test/screens/brushing_lifecycle_test.dart test/screens/brushing_camera_permission_test.dart test/flows/camera_mode_flow_test.dart`
Expected: all PASS. (The dry run measured the timer's rect at 430 × 932 before and after this task: `Rect.fromLTRB(179.0, 703.6, 251.0, 748.6)` both times.)

- [ ] **Step 7: Format, analyze, full suite**

Run: `dart format lib test && dart analyze && dart run dart_code_linter:metrics analyze lib && flutter test`
Expected: "No issues found!", DCM "no issues found!", all tests pass (1275).

- [ ] **Step 8: Commit**

```bash
git add lib/screens/brushing_screen.dart test/screens/brushing_screen_test.dart
git commit -m "feat(brushing): remove the monster counter and the sign under the timer

Oliver asked what they were for. The mouth guide and the seconds stay, and
the sign's room is kept so nothing else on the screen moves.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01STWCtX8pE4SLhUiiBxVG9M"
```

---

### Task 6: Describe the new steps

**Files:**
- Modify: `CLAUDE.md` (Game Flow, step 2 at line 85; step 4's bullets near line 89)
- Modify: `STATUS.md` (the "Pre-brush" line, line 18)

**Interfaces:** none (docs).

- [ ] **Step 1: CLAUDE.md**

Replace Game Flow step 2 (the line that starts `2. Home screen → tap the hero`) with:

```markdown
2. Home screen → tap the hero (it IS the brush button); the streak pill shows a flame that grows with the streak. From the second brush on, the steps run on the real pages in brush mode: the Heroes & Weapons page (HEROES tab, then WEAPONS), then the World Map, under one HEROES · WEAPONS · WORLD header (a tap on a tab goes to that step). Each step opens with what to do ("Pick the hero who'll brush with you!") and how far the next unlock is; taps on items play the page's own lines. Each has an X (back to Home), a big GO and a gold glow on the closest next unlock, which he can buy right there. The back gesture goes one step back (from HEROES, Home). About 8 s without a touch moves on once the voice is quiet. "Let's fight!" plays out before brushing
```

In step 4's bullets, after `   - Compact mouth indicator stays visible in header during brushing`, add:

```markdown
   - No monster counter and no sign under the timer (removed in v1.1: Oliver couldn't tell what they meant)
```

- [ ] **Step 2: STATUS.md**

Replace the line that starts `  - **Pre-brush:** from the second brush on` with these two lines:

```markdown
  - **Pre-brush:** from the second brush on, tapping the hero opens the real Heroes & Weapons page (HEROES, then WEAPONS) and the World Map in brush mode, under one HEROES · WEAPONS · WORLD header: each step opens with its instruction line, then how far the next unlock is; an X (Home), a big GO, the closest next unlock glowing (buyable right there), the back gesture one step back, about 8 s idle advance (rebuilt 2026-10-14; header, instruction lines and way back added 2026-10-15).
  - **Brushing:** no monster counter and no sign under the timer (2026-10-15); the mouth guide and the seconds stay where they were.
```

- [ ] **Step 3: Format, analyze, full suite**

Run: `dart format lib test && dart analyze && flutter test`
Expected: "No issues found!"; all tests pass (1275).

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md STATUS.md
git commit -m "docs: the steps' header, instruction lines and way back; the cleaner brushing screen

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01STWCtX8pE4SLhUiiBxVG9M"
```

---

### Task 7: Device check before Jim sees it (controller, not a subagent)

**Files:** none changed, unless the check finds a problem; then fix it in a new commit with a test.

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

Expected: no format changes; "No issues found!" from the analyzer and "no issues found!" from DCM; 1275 tests pass; semgrep 0 findings; gitleaks only the 9 historical false positives.

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

You need a returning kid: finish the tutorial and one brush, or stop the app and edit `shared_prefs/FlutterSharedPreferences.xml` through `adb shell run-as com.brushquest.brush_quest`. Keys are prefixed `flutter.`: set `onboarding_completed` true, `total_brushes` ≥ 1, and `star_wallet` 6 so Frost and the Flame Sword are buyable. Read the file first and keep its format.

- [ ] **Step 3: Screenshots**

Take each at phone size with `adb exec-out screencap -p > <scratchpad>/<name>.png`:
- `steps-heroes.png`, `steps-weapons.png`, `steps-map.png`: the three steps.
- `home-heroes.png`, `home-map.png`: the same pages opened from Home.
- `brushing.png`: mid-brush.

Read each one and check:
- On all three steps, the same HEROES · WEAPONS · WORLD header sits under the X and the title, with the current step lit. The X is at the top left.
- On the Map, the header is in the place the shop's tab bar has relative to its title row.
- From Home, the shop still has its own two-tab bar and the Map has no header.
- The labels are whole; on a 360 dp emulator profile too.
- Brushing shows nothing beside the mouth guide and nothing under the timer, and the monster, the hero and the timer are where build 41 had them.

Anything else that differs from Home (fonts, colours, art, the wallet pill, the planet path) is a defect.

- [ ] **Step 4: First-person walkthrough (CLAUDE.md Pre-Ship UX Checklist)**

As a 7-year-old who can't read, on each step: does the instruction line make the step's job clear before the progress line? Does a tap on an item still say what it is? Then run the way back:
1. Tap WORLD in the header, then HEROES.
2. From the Map, use the back gesture: WEAPONS comes back, sliding in from the left.
3. Back again: HEROES. Back again: Home.
4. The X on the Map: Home.
5. A back gesture during "Let's fight!": Home.
6. Do nothing after a back: the step moves on by itself again.

Trace the audio timeline: the instruction line, then its progress line, never overlapping; a back or a header tap mid-line cuts the line and the new step's lines start; "Let's fight!" plays into "3, 2, 1". On the brushing screen, ask: is anything left that he would ask "what is that for?" about? Note anything that collides.

- [ ] **Step 5: Report**

Write the results (the screenshots compared, defects found and fixed, the walkthrough notes) into the SDD ledger. Then offer Jim a Part A test build (the next version code after 41, Play internal, needs his go). Parts B and C follow their own plans.
