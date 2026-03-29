# Star Economy Teaching Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the star/streak economy understandable to kids (through chest-based celebration) and parents (through a settings guide), driving retention behavior.

**Architecture:** Four independent components: (D) Parent Star Guide in settings, (A) Context-aware shop nudges, (B) Post-chest bonus reveals replacing StarRain waves, (C) First-time celebration overlays. Components D and A are fully independent. C depends on B.

**Tech Stack:** Flutter/Dart, SharedPreferences, AudioService voice queue, ElevenLabs TTS

**Spec:** `docs/superpowers/specs/2026-03-28-star-economy-teaching-design.md`

---

## File Map

| File | Action | Component |
|------|--------|-----------|
| `lib/screens/settings_screen.dart` | Modify: add "How Stars Work" section to Guide tab | D |
| `lib/screens/hero_shop_screen.dart` | Modify: replace `voice_need_stars.mp3` with context-aware nudges | A |
| `lib/screens/victory_screen.dart` | Modify: restructure post-chest bonus reveal + first-time celebrations | B, C |
| `lib/widgets/star_rain.dart` | Modify: remove bonus waves (base stars only) | B |
| `lib/services/streak_service.dart` | Modify: add first-time flag tracking methods | C |
| `test/services/streak_service_test.dart` | Modify: add tests for first-time flags | C |
| `test/screens/settings_screen_test.dart` | Modify: add test for star guide section | D |
| `test/screens/hero_shop_screen_test.dart` | Create or modify: test context-aware nudge logic | A |
| `test/screens/victory_screen_test.dart` | Modify: test post-chest bonus reveal | B, C |
| `assets/audio/voices/boy/` | Create: 12 new voice files via ElevenLabs | A, B, C |

---

### Task 1: Generate Voice Files (ElevenLabs)

**Files:**
- Create: `assets/audio/voices/boy/voice_shop_nudge_tonight.mp3`
- Create: `assets/audio/voices/boy/voice_shop_nudge_streak3.mp3`
- Create: `assets/audio/voices/boy/voice_shop_nudge_streak7.mp3`
- Create: `assets/audio/voices/boy/voice_shop_nudge_default.mp3`
- Create: `assets/audio/voices/boy/voice_chest_streak_bonus.mp3`
- Create: `assets/audio/voices/boy/voice_chest_mega_streak.mp3`
- Create: `assets/audio/voices/boy/voice_chest_daily_pair.mp3`
- Create: `assets/audio/voices/boy/voice_chest_comeback.mp3`
- Create: `assets/audio/voices/boy/voice_first_streak_3.mp3`
- Create: `assets/audio/voices/boy/voice_first_streak_7.mp3`
- Create: `assets/audio/voices/boy/voice_first_daily_pair.mp3`
- Create: `assets/audio/voices/boy/voice_first_comeback.mp3`

- [ ] **Step 1: Check ElevenLabs quota**

Run: `python3 scripts/check_elevenlabs_quota.py` (or check ElevenLabs dashboard)

If quota is available, proceed. If not, create silent placeholder MP3s for development and note the blocker.

- [ ] **Step 2: Generate voice files using ElevenLabs**

Use the BQ Buddy voice (boy voice style). Generate each file with these exact scripts:

**Component A — Shop Nudges:**
| File | Script |
|------|--------|
| `voice_shop_nudge_tonight.mp3` | "Brush tonight too and you'll earn a bonus star! That gets you closer!" |
| `voice_shop_nudge_streak3.mp3` | "Keep brushing every day! Something special happens at 3 days!" |
| `voice_shop_nudge_streak7.mp3` | "Almost at 7 days! That means DOUBLE bonus stars every time you brush!" |
| `voice_shop_nudge_default.mp3` | "Every brush earns you stars! You're getting closer!" |

**Component B — Chest Reveals (recurring):**
| File | Script |
|------|--------|
| `voice_chest_streak_bonus.mp3` | "You brushed your teeth every day this week — bonus star!" |
| `voice_chest_mega_streak.mp3` | "More than a week of brushing every day — 2 extra stars! Keep going and you get the same bonus tomorrow!" |
| `voice_chest_daily_pair.mp3` | "Morning AND night — full power!" |
| `voice_chest_comeback.mp3` | "Welcome back, Ranger! 3 bonus stars!" |

**Component C — First-Time Celebrations:**
| File | Script |
|------|--------|
| `voice_first_streak_3.mp3` | "WHOA! You brushed your teeth three days in a row! That's a STREAK! And streaks give you BONUS STARS every time! Keep it going!" |
| `voice_first_streak_7.mp3` | "SEVEN DAYS! You're a streak CHAMPION! Now you get TWO bonus stars every time you brush! You're UNSTOPPABLE!" |
| `voice_first_daily_pair.mp3` | "You brushed this morning AND tonight! That's a full day of power! Here's a bonus star — try it again tomorrow!" |
| `voice_first_comeback.mp3` | "Hey, welcome back Space Ranger! It's been a while, but that's OK! Here are THREE bonus stars to get you going again!" |

- [ ] **Step 3: Place files in the correct directory**

All files go to `assets/audio/voices/boy/`. The AudioService routes via `_voiceAssetPath()` (audio_service.dart:86-88) which prepends `audio/voices/$_voiceStyle/`.

- [ ] **Step 4: Verify files are listed in pubspec.yaml**

Check that `assets/audio/voices/boy/` is already included in the flutter assets section of `pubspec.yaml`. The directory glob should already cover new files, but verify.

Run: `grep -n "voices/boy" pubspec.yaml`

- [ ] **Step 5: Commit**

```bash
git add assets/audio/voices/boy/voice_shop_nudge_*.mp3 assets/audio/voices/boy/voice_chest_*.mp3 assets/audio/voices/boy/voice_first_*.mp3
git commit -m "feat: add 12 voice files for star economy teaching"
```

---

### Task 2: Component D — Parent Star Guide in Settings

**Files:**
- Modify: `lib/screens/settings_screen.dart` (add to `_buildGuideTab()`)
- Modify: `test/screens/settings_screen_test.dart`

- [ ] **Step 1: Write the test**

Add a test to `test/screens/settings_screen_test.dart` that verifies the "How Stars Work" section exists in the Guide tab:

```dart
testWidgets('Guide tab shows How Stars Work section', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: SettingsScreen()),
  );
  await tester.pumpAndSettle();

  // Navigate to Guide tab (index 2)
  await tester.tap(find.text('Guide'));
  await tester.pumpAndSettle();

  expect(find.text('How Stars Work'), findsOneWidget);
  expect(find.text('Every brush'), findsOneWidget);
  expect(find.text('Earns 2 stars'), findsOneWidget);
  expect(find.text('Streak Bonus'), findsOneWidget);
  expect(find.text('Daily Pair Bonus'), findsOneWidget);
  expect(find.text('Comeback Bonus'), findsOneWidget);
  expect(find.text('Wallet vs Ranger Rank'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/settings_screen_test.dart --name "How Stars Work"`
Expected: FAIL — "How Stars Work" not found.

- [ ] **Step 3: Implement the Star Guide section**

In `lib/screens/settings_screen.dart`, find `_buildGuideTab()` (line ~1736) and add a "How Stars Work" section. Use the existing `_SectionHeader` pattern (lines 1749-1779) and card styling consistent with the rest of the Guide tab.

Add this method to the `_SettingsScreenState` class:

```dart
Widget _buildStarGuide() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SectionHeader(
        icon: Icons.star,
        label: 'How Stars Work',
        color: Colors.amber,
      ),
      const SizedBox(height: 12),
      _buildStarGuideCard(
        icon: Icons.cleaning_services,
        color: Colors.amber,
        title: 'Every brush',
        description: 'Earns 2 stars',
      ),
      const SizedBox(height: 8),
      _buildStarGuideCard(
        icon: Icons.local_fire_department,
        color: Colors.deepOrange,
        title: 'Streak Bonus',
        description: '3+ days in a row: +1 bonus star per brush\n7+ days in a row: +2 bonus stars per brush',
        tip: 'Tip: "Brush tonight so you keep your streak going!"',
      ),
      const SizedBox(height: 8),
      _buildStarGuideCard(
        icon: Icons.wb_twilight,
        color: Colors.purple,
        title: 'Daily Pair Bonus',
        description: 'Brush morning AND evening: +1 bonus star',
        tip: 'Tip: "You already brushed this morning — brush tonight for a bonus star!"',
      ),
      const SizedBox(height: 8),
      _buildStarGuideCard(
        icon: Icons.favorite,
        color: Colors.green,
        title: 'Comeback Bonus',
        description: 'First brush after a break: +3 welcome-back stars',
        tip: 'The app welcomes them back warmly. No guilt!',
      ),
      const SizedBox(height: 8),
      _buildStarGuideCard(
        icon: Icons.redeem,
        color: Colors.blue,
        title: 'Chest Rewards',
        description: 'Random bonus after each brush (0-5 stars)\nLonger streaks give better odds!',
      ),
      const SizedBox(height: 8),
      _buildStarGuideCard(
        icon: Icons.account_balance_wallet,
        color: Colors.amber,
        title: 'Wallet vs Ranger Rank',
        description: 'Star Wallet: Spendable — goes down when buying heroes/weapons\nRanger Rank: Lifetime total — never decreases, even after spending',
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          'Example: Morning brush (2 base + 1 streak = 3) + evening brush (2 base + 1 streak + 1 daily = 4) + chest reward. Total: 7+ stars with a 3-day streak!',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    ],
  );
}

Widget _buildStarGuideCard({
  required IconData icon,
  required Color color,
  required String title,
  required String description,
  String? tip,
}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
          ),
        ),
        if (tip != null) ...[
          const SizedBox(height: 6),
          Text(
            tip,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    ),
  );
}
```

Then call `_buildStarGuide()` inside `_buildGuideTab()`, placing it as the first section in the guide.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/settings_screen_test.dart --name "How Stars Work"`
Expected: PASS

- [ ] **Step 5: Run dart analyze**

Run: `dart analyze lib/screens/settings_screen.dart`
Expected: No issues

- [ ] **Step 6: Commit**

```bash
git add lib/screens/settings_screen.dart test/screens/settings_screen_test.dart
git commit -m "feat: add parent star guide to settings Guide tab"
```

---

### Task 3: Component A — Context-Aware Shop Nudges

**Files:**
- Modify: `lib/screens/hero_shop_screen.dart` (lines 113, 147, 199-228, 401)

- [ ] **Step 1: Add nudge voice selection method**

In `hero_shop_screen.dart`, add a method to the `_HeroShopScreenState` class that selects the appropriate voice file based on current streak and slot status. The class already has `_streakService` (line 23).

```dart
Future<String> _selectNudgeVoice() async {
  final streak = await _streakService.getStreak();
  final slots = await _streakService.getTodaySlots();

  // Priority 1: Morning done, evening not → nudge tonight
  if (slots.morningDone && !slots.eveningDone) {
    return 'voice_shop_nudge_tonight.mp3';
  }
  // Priority 2: Approaching 3-day streak
  if (streak >= 1 && streak < 3) {
    return 'voice_shop_nudge_streak3.mp3';
  }
  // Priority 3: Approaching 7-day streak
  if (streak >= 5 && streak < 7) {
    return 'voice_shop_nudge_streak7.mp3';
  }
  // Default
  return 'voice_shop_nudge_default.mp3';
}
```

- [ ] **Step 2: Replace all three `voice_need_stars.mp3` calls**

At lines 113, 147, and 401, replace:
```dart
AudioService().playVoice('voice_need_stars.mp3');
```
with:
```dart
_selectNudgeVoice().then((voice) => AudioService().playVoice(voice));
```

- [ ] **Step 3: Run dart analyze**

Run: `dart analyze lib/screens/hero_shop_screen.dart`
Expected: No issues

- [ ] **Step 4: Run existing shop tests**

Run: `flutter test test/screens/hero_shop_screen_test.dart` (if exists) or `flutter test`
Expected: All passing

- [ ] **Step 5: Commit**

```bash
git add lib/screens/hero_shop_screen.dart
git commit -m "feat: context-aware shop nudges based on streak and slot status"
```

---

### Task 4: Component B — Post-Chest Bonus Reveals

This is the biggest change. It restructures the victory screen so bonus stars emerge from the chest instead of playing as StarRain waves.

**Files:**
- Modify: `lib/widgets/star_rain.dart` (remove bonus waves)
- Modify: `lib/screens/victory_screen.dart` (add post-chest bonus reveal)

- [ ] **Step 1: Simplify StarRain to base stars only**

In `lib/widgets/star_rain.dart`, modify `_buildWaves()` (lines 102-153) to only emit the base wave. Remove the streak, daily, and comeback wave sections:

```dart
List<_StarWave> _buildWaves() {
  final waves = <_StarWave>[];

  // Only base brush stars — bonuses now reveal from the chest.
  waves.add(_StarWave(
    count: widget.baseStars,
    color: const Color(0xFFFFD54F), // gold
    glowColor: const Color(0xFFF176),
    sourceIcon: Icons.cleaning_services,
    sourceImagePath: 'assets/images/icon_toothbrush.png',
    label: 'You brushed!',
  ));

  return waves;
}
```

- [ ] **Step 2: Remove bonus parameters from StarRain widget**

In `star_rain.dart`, remove the `streakBonus`, `dailyBonus`, `comebackBonus`, and `currentStreak` parameters from the StarRain widget class since they're no longer used. Keep only `baseStars` and `onComplete`.

- [ ] **Step 3: Update StarRain call site in victory_screen.dart**

In `victory_screen.dart` (lines 884-891), simplify the StarRain widget call:

```dart
if (_starsEarnedThisSession > 0)
  StarRain(
    baseStars: 2,
    onComplete: _onStarRainComplete,
  ),
```

Add a callback method `_onStarRainComplete` if one doesn't exist (or use the existing `onComplete`).

- [ ] **Step 4: Remove bonus voice lines from _recordAndAnimate()**

In `victory_screen.dart`, lines 379-389, remove the bonus-specific voice lines that currently play during the star rain phase. These will move to the post-chest reveal. Remove:

```dart
// REMOVE these lines (they move to post-chest):
if (_streakMultiplierBonus > 0 && _newStreak == 3) {
  _audio.playVoice('voice_super_power.mp3');
} else if (_streakMultiplierBonus > 0 && _newStreak == 7) {
  _audio.playVoice('voice_mega_power.mp3');
} else if (_streakMultiplierBonus > 0) {
  _audio.playVoice('voice_streak_bonus.mp3');
}

if (_dailyBonus > 0) {
  _audio.playVoice('voice_full_charge.mp3');
}
```

- [ ] **Step 5: Add post-chest bonus reveal to _openChest()**

In `victory_screen.dart`, modify `_openChest()` (lines 491-640). After the chest reward animation settles and the reward voice finishes, add the bonus reveal sequence. Find where the chest reward voice completes (after `await _audio.playVoice(_reward!.voiceFile)` around line 507) and add:

```dart
// After chest reward voice completes, reveal bonus stars from chest
await _revealBonusStars();
```

Add the `_revealBonusStars()` method to the class:

```dart
Future<void> _revealBonusStars() async {
  if (!mounted) return;

  // Streak bonus reveal
  if (_streakMultiplierBonus > 0) {
    setState(() => _showStreakBonus = true);
    if (_newStreak >= 7) {
      await _audio.playVoice('voice_chest_mega_streak.mp3');
    } else {
      await _audio.playVoice('voice_chest_streak_bonus.mp3');
    }
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 300));
  }

  // Daily pair bonus reveal
  if (_dailyBonus > 0) {
    setState(() => _showDailyBonus = true);
    await _audio.playVoice('voice_chest_daily_pair.mp3');
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 300));
  }

  // Comeback bonus reveal
  if (_comebackBonus > 0) {
    setState(() => _showComebackBonus = true);
    await _audio.playVoice('voice_chest_comeback.mp3');
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 300));
  }
}
```

- [ ] **Step 6: Add bonus reveal state variables and UI**

Add state booleans to `_VictoryScreenState`:

```dart
bool _showStreakBonus = false;
bool _showDailyBonus = false;
bool _showComebackBonus = false;
```

Add a bonus reveal overlay widget below the chest in the victory screen's build tree. Each bonus appears as a colored star icon with a brief scale-in animation, positioned near the chest:

```dart
Widget _buildBonusReveal() {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (_showStreakBonus)
        _BonusStar(
          icon: Icons.local_fire_department,
          color: _newStreak >= 7 ? Colors.blue : Colors.deepOrange,
          count: _streakMultiplierBonus,
        ),
      if (_showDailyBonus)
        _BonusStar(
          icon: Icons.wb_twilight,
          color: Colors.purple,
          count: _dailyBonus,
        ),
      if (_showComebackBonus)
        _BonusStar(
          icon: Icons.favorite,
          color: Colors.green,
          count: _comebackBonus,
        ),
    ],
  );
}
```

Create a `_BonusStar` widget that animates in with a scale + glow effect:

```dart
class _BonusStar extends StatefulWidget {
  final IconData icon;
  final Color color;
  final int count;

  const _BonusStar({
    required this.icon,
    required this.color,
    required this.count,
  });

  @override
  State<_BonusStar> createState() => _BonusStarState();
}

class _BonusStarState extends State<_BonusStar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, color: widget.color, size: 28),
            const SizedBox(width: 6),
            Text(
              '+${widget.count}',
              style: TextStyle(
                color: widget.color,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(color: widget.color.withValues(alpha: 0.6), blurRadius: 8),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.star, color: Colors.amber, size: 20),
          ],
        ),
      ),
    );
  }
}
```

Place `_buildBonusReveal()` in the build tree below the chest widget, inside the same Stack or Column.

- [ ] **Step 7: Run dart analyze**

Run: `dart analyze lib/screens/victory_screen.dart lib/widgets/star_rain.dart`
Expected: No issues

- [ ] **Step 8: Run all tests**

Run: `flutter test`
Expected: All passing. Fix any broken tests caused by StarRain parameter changes.

- [ ] **Step 9: Commit**

```bash
git add lib/screens/victory_screen.dart lib/widgets/star_rain.dart
git commit -m "feat: move bonus star reveals from StarRain to post-chest sequence"
```

---

### Task 5: Component C — First-Time Celebration Flags

**Files:**
- Modify: `lib/services/streak_service.dart` (add flag methods)
- Modify: `test/services/streak_service_test.dart` (add flag tests)

- [ ] **Step 1: Write tests for first-time flags**

In `test/services/streak_service_test.dart`, add:

```dart
group('First-time celebration flags', () {
  test('hasSeenFirstStreak3 defaults to false', () async {
    final service = StreakService();
    expect(await service.hasSeenFirstStreak3(), false);
  });

  test('markFirstStreak3Seen sets flag to true', () async {
    final service = StreakService();
    await service.markFirstStreak3Seen();
    expect(await service.hasSeenFirstStreak3(), true);
  });

  test('hasSeenFirstStreak7 defaults to false', () async {
    final service = StreakService();
    expect(await service.hasSeenFirstStreak7(), false);
  });

  test('markFirstStreak7Seen sets flag to true', () async {
    final service = StreakService();
    await service.markFirstStreak7Seen();
    expect(await service.hasSeenFirstStreak7(), true);
  });

  test('hasSeenFirstDailyPair defaults to false', () async {
    final service = StreakService();
    expect(await service.hasSeenFirstDailyPair(), false);
  });

  test('markFirstDailyPairSeen sets flag to true', () async {
    final service = StreakService();
    await service.markFirstDailyPairSeen();
    expect(await service.hasSeenFirstDailyPair(), true);
  });

  test('hasSeenFirstComeback defaults to false', () async {
    final service = StreakService();
    expect(await service.hasSeenFirstComeback(), false);
  });

  test('markFirstComebackSeen sets flag to true', () async {
    final service = StreakService();
    await service.markFirstComebackSeen();
    expect(await service.hasSeenFirstComeback(), true);
  });

  test('resetProgress clears all first-time flags', () async {
    final service = StreakService();
    await service.markFirstStreak3Seen();
    await service.markFirstStreak7Seen();
    await service.markFirstDailyPairSeen();
    await service.markFirstComebackSeen();

    await service.resetProgress();

    expect(await service.hasSeenFirstStreak3(), false);
    expect(await service.hasSeenFirstStreak7(), false);
    expect(await service.hasSeenFirstDailyPair(), false);
    expect(await service.hasSeenFirstComeback(), false);
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/services/streak_service_test.dart --name "First-time"`
Expected: FAIL — methods don't exist yet.

- [ ] **Step 3: Implement first-time flag methods**

In `lib/services/streak_service.dart`, add SharedPreferences key constants alongside the existing ones (around line 72-84):

```dart
static const _keySeenFirstStreak3 = 'seen_first_streak_3';
static const _keySeenFirstStreak7 = 'seen_first_streak_7';
static const _keySeenFirstDailyPair = 'seen_first_daily_pair';
static const _keySeenFirstComeback = 'seen_first_comeback';
```

Add getter/setter methods:

```dart
Future<bool> hasSeenFirstStreak3() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_keySeenFirstStreak3) ?? false;
}

Future<void> markFirstStreak3Seen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_keySeenFirstStreak3, true);
}

Future<bool> hasSeenFirstStreak7() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_keySeenFirstStreak7) ?? false;
}

Future<void> markFirstStreak7Seen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_keySeenFirstStreak7, true);
}

Future<bool> hasSeenFirstDailyPair() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_keySeenFirstDailyPair) ?? false;
}

Future<void> markFirstDailyPairSeen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_keySeenFirstDailyPair, true);
}

Future<bool> hasSeenFirstComeback() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_keySeenFirstComeback) ?? false;
}

Future<void> markFirstComebackSeen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_keySeenFirstComeback, true);
}
```

Also update `resetProgress()` to clear these flags. Find the existing `resetProgress()` method and add:

```dart
await prefs.remove(_keySeenFirstStreak3);
await prefs.remove(_keySeenFirstStreak7);
await prefs.remove(_keySeenFirstDailyPair);
await prefs.remove(_keySeenFirstComeback);
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/services/streak_service_test.dart --name "First-time"`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/services/streak_service.dart test/services/streak_service_test.dart
git commit -m "feat: add first-time celebration flag tracking to StreakService"
```

---

### Task 6: Component C — First-Time Celebrations in Victory Screen

**Files:**
- Modify: `lib/screens/victory_screen.dart` (enhance `_revealBonusStars()` from Task 4)

- [ ] **Step 1: Add first-time detection to _revealBonusStars()**

Modify the `_revealBonusStars()` method added in Task 4 to check first-time flags and play the longer celebration voice instead of the recurring one:

```dart
Future<void> _revealBonusStars() async {
  if (!mounted) return;

  // Streak bonus reveal
  if (_streakMultiplierBonus > 0) {
    setState(() => _showStreakBonus = true);
    if (_newStreak >= 7) {
      final seenBefore = await _streakService.hasSeenFirstStreak7();
      if (!seenBefore) {
        await _streakService.markFirstStreak7Seen();
        HapticFeedback.heavyImpact();
        await _audio.playVoice('voice_first_streak_7.mp3');
      } else {
        await _audio.playVoice('voice_chest_mega_streak.mp3');
      }
    } else {
      final seenBefore = await _streakService.hasSeenFirstStreak3();
      if (!seenBefore) {
        await _streakService.markFirstStreak3Seen();
        HapticFeedback.heavyImpact();
        await _audio.playVoice('voice_first_streak_3.mp3');
      } else {
        await _audio.playVoice('voice_chest_streak_bonus.mp3');
      }
    }
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 300));
  }

  // Daily pair bonus reveal
  if (_dailyBonus > 0) {
    setState(() => _showDailyBonus = true);
    final seenBefore = await _streakService.hasSeenFirstDailyPair();
    if (!seenBefore) {
      await _streakService.markFirstDailyPairSeen();
      HapticFeedback.heavyImpact();
      await _audio.playVoice('voice_first_daily_pair.mp3');
    } else {
      await _audio.playVoice('voice_chest_daily_pair.mp3');
    }
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 300));
  }

  // Comeback bonus reveal
  if (_comebackBonus > 0) {
    setState(() => _showComebackBonus = true);
    final seenBefore = await _streakService.hasSeenFirstComeback();
    if (!seenBefore) {
      await _streakService.markFirstComebackSeen();
      HapticFeedback.heavyImpact();
      await _audio.playVoice('voice_first_comeback.mp3');
    } else {
      await _audio.playVoice('voice_chest_comeback.mp3');
    }
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 300));
  }
}
```

- [ ] **Step 2: Run dart analyze**

Run: `dart analyze lib/screens/victory_screen.dart`
Expected: No issues

- [ ] **Step 3: Run all tests**

Run: `flutter test`
Expected: All passing

- [ ] **Step 4: Commit**

```bash
git add lib/screens/victory_screen.dart
git commit -m "feat: first-time celebrations with longer voice lines for streak/daily/comeback"
```

---

### Task 7: Final Integration Test + Cleanup

**Files:**
- All modified files from Tasks 2-6

- [ ] **Step 1: Run full dart analyze**

Run: `dart analyze`
Expected: No issues across entire project

- [ ] **Step 2: Run full test suite**

Run: `flutter test`
Expected: All tests pass

- [ ] **Step 3: Build APK**

Run:
```bash
export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"
flutter build apk
```
Expected: BUILD SUCCESSFUL

- [ ] **Step 4: Commit final state**

If any cleanup was needed, commit it:
```bash
git add -A
git commit -m "chore: cleanup and integration fixes for star economy teaching"
```

- [ ] **Step 5: Push to GitHub**

```bash
git push origin main
```

- [ ] **Step 6: Upload APK to Google Drive**

```bash
rclone copy build/app/outputs/flutter-apk/app-release.apk gdrive:BrushQuest/apk/
```

- [ ] **Step 7: Verify upload**

```bash
rclone ls gdrive:BrushQuest/apk/
```
