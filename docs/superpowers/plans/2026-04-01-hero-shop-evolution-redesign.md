# Hero Shop Evolution Redesign

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the hero shop to show evolutions inline (one row per hero, three columns per stage), fix evolution voice lines, update stage 3 pricing, add sequential gating, and remove redundant UI elements (featured display, bottom sheet, checkmark badge).

**Architecture:** Four changes: (1) Economy — lower stage 3 prices to 25, add sequential gating requiring previous stage ownership, (2) Voice — generate 12 evolution-specific voice files and add mapping in audio_service, (3) UI — replace the 2-column hero grid + featured display + bottom sheet with a scrollable list of hero rows, each containing 3 evolution cells showing the composite hero+weapon image, (4) Cleanup — remove dead code.

**Tech Stack:** Flutter/Dart, ElevenLabs TTS MCP tool

---

## File Map

| File | Changes |
|------|---------|
| `lib/services/hero_service.dart` | Update stage 3 prices, add sequential gating to `purchaseEvolution()` |
| `lib/services/audio_service.dart` | Add `evolutionPickerVoices` map, `evolutionPickerVoiceFor()` method, preload new files |
| `lib/screens/hero_shop_screen.dart` | Replace `_buildHeroGrid()`, remove `_FeaturedHeroDisplay`, `_HeroCard`, `_showArmorBottomSheet`, `_buildEvolutionOption`. Add `_buildEvolutionGrid()`, `_HeroEvolutionRow`, `_EvolutionCell`. Update `_onHeroTap` → `_onEvolutionTap` |
| `test/services/hero_service_test.dart` | Add tests for sequential gating and updated prices |
| `assets/audio/voices/classic/` | 12 new voice files (6 stage-2 + 6 stage-3 evolution voices) |

---

### Task 1: Economy — Stage 3 pricing and sequential gating

**Files:**
- Modify: `lib/services/hero_service.dart:201-303` (prices), `lib/services/hero_service.dart:335-358` (gating)
- Test: `test/services/hero_service_test.dart`

- [ ] **Step 1: Write failing tests for sequential gating**

Add these tests to `test/services/hero_service_test.dart` inside the existing `group('HeroService', ...)`:

```dart
  group('evolution gating', () {
    test('cannot purchase stage 3 without owning stage 2', () async {
      SharedPreferences.setMockInitialValues({
        'unlocked_heroes': ['blaze'],
        'total_stars': 100,
      });
      final service = HeroService();
      // Attempt to buy stage 3 directly — should fail
      final result = await service.purchaseEvolution('blaze_stage3');
      expect(result, false);
    });

    test('can purchase stage 3 after owning stage 2', () async {
      SharedPreferences.setMockInitialValues({
        'unlocked_heroes': ['blaze'],
        'unlocked_evolutions': ['blaze_stage2'],
        'total_stars': 100,
      });
      final service = HeroService();
      final result = await service.purchaseEvolution('blaze_stage3');
      expect(result, true);
    });

    test('stage 2 can be purchased without gating', () async {
      SharedPreferences.setMockInitialValues({
        'unlocked_heroes': ['blaze'],
        'total_stars': 100,
      });
      final service = HeroService();
      final result = await service.purchaseEvolution('blaze_stage2');
      expect(result, true);
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/services/hero_service_test.dart`
Expected: `cannot purchase stage 3 without owning stage 2` should FAIL (purchase succeeds when it shouldn't).

- [ ] **Step 3: Update stage 3 prices in allEvolutions**

In `lib/services/hero_service.dart`, change all 6 stage-3 evolution prices:

| Evolution ID | Old Price | New Price |
|---|---|---|
| `blaze_stage3` | 35 | 25 |
| `frost_stage3` | 35 | 25 |
| `bolt_stage3` | 35 | 25 |
| `shadow_stage3` | 40 | 25 |
| `leaf_stage3` | 40 | 25 |
| `nova_stage3` | 40 | 25 |

Find each `HeroEvolution` with `stage: 3` and change its `price` value to `25`.

- [ ] **Step 4: Add sequential gating to purchaseEvolution()**

In `lib/services/hero_service.dart`, modify `purchaseEvolution()` (currently lines 335-358). Add a gating check after the stage-1 check:

Replace:
```dart
  Future<bool> purchaseEvolution(String evolutionId) async {
    if (_purchasing) return false;
    _purchasing = true;
    try {
      final evo = getEvolutionById(evolutionId);
      if (evo == null) return false;

      // Stage 1 is always free — no purchase needed
      if (evo.price == 0) return true;

      final prefs = await SharedPreferences.getInstance();
      final unlocked = prefs.getStringList(_unlockedEvolutionsKey) ?? [];
      if (unlocked.contains(evolutionId)) return true;
```

With:
```dart
  Future<bool> purchaseEvolution(String evolutionId) async {
    if (_purchasing) return false;
    _purchasing = true;
    try {
      final evo = getEvolutionById(evolutionId);
      if (evo == null) return false;

      // Stage 1 is always free — no purchase needed
      if (evo.price == 0) return true;

      final prefs = await SharedPreferences.getInstance();
      final unlocked = prefs.getStringList(_unlockedEvolutionsKey) ?? [];
      if (unlocked.contains(evolutionId)) return true;

      // Sequential gating: stage 3 requires stage 2 to be owned
      if (evo.stage >= 3) {
        final prevId = '${evo.heroId}_stage${evo.stage - 1}';
        if (!unlocked.contains(prevId)) return false;
      }
```

The rest of the method stays the same.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/services/hero_service_test.dart`
Expected: All tests pass including the 3 new gating tests.

- [ ] **Step 6: Run dart analyze**

Run: `dart analyze lib/services/hero_service.dart`
Expected: No issues.

- [ ] **Step 7: Commit**

```bash
git add lib/services/hero_service.dart test/services/hero_service_test.dart
git commit -m "feat: lower stage 3 prices to 25 + add sequential evolution gating"
```

---

### Task 2: Generate 12 evolution voice files

**Files:**
- Create: `assets/audio/voices/classic/voice_picker_evo_blaze_stage2.mp3`
- Create: `assets/audio/voices/classic/voice_picker_evo_blaze_stage3.mp3`
- Create: `assets/audio/voices/classic/voice_picker_evo_frost_stage2.mp3`
- Create: `assets/audio/voices/classic/voice_picker_evo_frost_stage3.mp3`
- Create: `assets/audio/voices/classic/voice_picker_evo_bolt_stage2.mp3`
- Create: `assets/audio/voices/classic/voice_picker_evo_bolt_stage3.mp3`
- Create: `assets/audio/voices/classic/voice_picker_evo_shadow_stage2.mp3`
- Create: `assets/audio/voices/classic/voice_picker_evo_shadow_stage3.mp3`
- Create: `assets/audio/voices/classic/voice_picker_evo_leaf_stage2.mp3`
- Create: `assets/audio/voices/classic/voice_picker_evo_leaf_stage3.mp3`
- Create: `assets/audio/voices/classic/voice_picker_evo_nova_stage2.mp3`
- Create: `assets/audio/voices/classic/voice_picker_evo_nova_stage3.mp3`

**Voice:** Classic (Jessica), voice ID `cgSgspJ2msm6clMCkdW9`

**Scripts:**

| File | Script |
|------|--------|
| `voice_picker_evo_blaze_stage2.mp3` | "Flame Knight! Fire armor with glowing flames!" |
| `voice_picker_evo_blaze_stage3.mp3` | "Inferno Lord! Legendary fire armor! Monsters flee in terror!" |
| `voice_picker_evo_frost_stage2.mp3` | "Crystal Knight! Ice armor with frost breath power!" |
| `voice_picker_evo_frost_stage3.mp3` | "Blizzard Lord! Ultimate ice armor! Freezes everything!" |
| `voice_picker_evo_bolt_stage2.mp3` | "Thunder Knight! Electric armor with crackling lightning!" |
| `voice_picker_evo_bolt_stage3.mp3` | "Storm Lord! Legendary lightning armor! Lightning strikes all!" |
| `voice_picker_evo_shadow_stage2.mp3` | "Phantom Knight! Dark armor with shadow energy!" |
| `voice_picker_evo_shadow_stage3.mp3` | "Void Lord! Legendary shadow armor! Invisible and deadly!" |
| `voice_picker_evo_leaf_stage2.mp3` | "Forest Knight! Living vine armor with nature magic!" |
| `voice_picker_evo_leaf_stage3.mp3` | "Ancient Guardian! Legendary nature armor! Unstoppable!" |
| `voice_picker_evo_nova_stage2.mp3` | "Star Knight! Golden armor with cosmic star power!" |
| `voice_picker_evo_nova_stage3.mp3` | "Celestial Lord! Legendary cosmic armor! Pure starlight!" |

- [ ] **Step 1: Generate all 12 voice files using ElevenLabs TTS**

Use `mcp__elevenlabs__text_to_speech` for each file. Voice ID: `cgSgspJ2msm6clMCkdW9`. Save to `assets/audio/voices/classic/`. Files may need renaming from auto-generated names.

- [ ] **Step 2: Verify all 12 files exist and have reasonable duration**

Run:
```bash
for f in voice_picker_evo_*; do echo "$f: $(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$f")s"; done
```
Expected: 12 files, each 2-4 seconds.

- [ ] **Step 3: Commit voice files**

```bash
git add assets/audio/voices/classic/voice_picker_evo_*.mp3
git commit -m "feat: add 12 evolution-specific voice files"
```

---

### Task 3: Voice mapping for evolutions

**Files:**
- Modify: `lib/services/audio_service.dart:104-111` (add map), `lib/services/audio_service.dart:388-390` (add method), `lib/services/audio_service.dart:183` (preload list)

- [ ] **Step 1: Add evolution voice map**

In `lib/services/audio_service.dart`, after the `heroPickerVoices` map (around line 111), add:

```dart
  static const Map<String, String> evolutionPickerVoices = {
    'blaze_stage2': 'voice_picker_evo_blaze_stage2.mp3',
    'blaze_stage3': 'voice_picker_evo_blaze_stage3.mp3',
    'frost_stage2': 'voice_picker_evo_frost_stage2.mp3',
    'frost_stage3': 'voice_picker_evo_frost_stage3.mp3',
    'bolt_stage2': 'voice_picker_evo_bolt_stage2.mp3',
    'bolt_stage3': 'voice_picker_evo_bolt_stage3.mp3',
    'shadow_stage2': 'voice_picker_evo_shadow_stage2.mp3',
    'shadow_stage3': 'voice_picker_evo_shadow_stage3.mp3',
    'leaf_stage2': 'voice_picker_evo_leaf_stage2.mp3',
    'leaf_stage3': 'voice_picker_evo_leaf_stage3.mp3',
    'nova_stage2': 'voice_picker_evo_nova_stage2.mp3',
    'nova_stage3': 'voice_picker_evo_nova_stage3.mp3',
  };
```

- [ ] **Step 2: Add evolutionPickerVoiceFor() method**

After the `heroPickerVoiceFor()` method (around line 390), add:

```dart
  String evolutionPickerVoiceFor(String heroId, int stage) {
    if (stage <= 1) return heroPickerVoiceFor(heroId);
    final key = '${heroId}_stage$stage';
    return evolutionPickerVoices[key] ?? heroPickerVoiceFor(heroId);
  }
```

Stage 1 falls back to the base hero picker voice. Stages 2+ use the evolution voice. Unknown keys fall back to the base hero voice.

- [ ] **Step 3: Add voice files to preload list**

In `lib/services/audio_service.dart`, find the `_allAudioFiles` list. After the hero picker voices section, add all 12 evolution picker voices:

```dart
    // Evolution picker voices
    'voice_picker_evo_blaze_stage2.mp3',
    'voice_picker_evo_blaze_stage3.mp3',
    'voice_picker_evo_frost_stage2.mp3',
    'voice_picker_evo_frost_stage3.mp3',
    'voice_picker_evo_bolt_stage2.mp3',
    'voice_picker_evo_bolt_stage3.mp3',
    'voice_picker_evo_shadow_stage2.mp3',
    'voice_picker_evo_shadow_stage3.mp3',
    'voice_picker_evo_leaf_stage2.mp3',
    'voice_picker_evo_leaf_stage3.mp3',
    'voice_picker_evo_nova_stage2.mp3',
    'voice_picker_evo_nova_stage3.mp3',
```

- [ ] **Step 4: Run dart analyze**

Run: `dart analyze lib/services/audio_service.dart`
Expected: No issues.

- [ ] **Step 5: Commit**

```bash
git add lib/services/audio_service.dart
git commit -m "feat: add evolution voice mapping and preload list"
```

---

### Task 4: UI Redesign — Evolution grid layout

This is the largest task. Replace the heroes tab layout entirely.

**Files:**
- Modify: `lib/screens/hero_shop_screen.dart`

**Overview of removals:**
- Remove `_FeaturedHeroDisplay` class (lines 1111-1197)
- Remove `_HeroCard` class (lines 827-957)
- Remove `_showArmorBottomSheet()` method (lines 265-374)
- Remove `_buildEvolutionOption()` method (lines 376-552)
- Remove `_buildHeroGrid()` method (lines 733-777)
- Remove `_onHeroTap()` method (lines 101-135)

**Overview of additions:**
- Add `_onEvolutionTap()` method — handles equip/purchase/locked for evolution cells
- Add `_buildEvolutionGrid()` method — scrollable list of hero rows
- Add `_HeroEvolutionRow` widget — one row per hero with 3 evolution cells
- Add `_EvolutionCell` widget — shows hero image + state indicator

#### Step-by-step:

- [ ] **Step 1: Add `_onEvolutionTap()` method**

Replace `_onHeroTap()` (lines 101-135) with:

```dart
  Future<void> _onEvolutionTap(HeroCharacter hero, HeroEvolution evolution) async {
    final isHeroOwned = _unlockedHeroes.contains(hero.id);
    final isEvoOwned = evolution.stage == 1
        ? isHeroOwned
        : _unlockedEvolutions.contains(evolution.id);
    final currentStage = _evolutionStages[hero.id] ?? 1;
    final isEquipped = _selectedHeroId == hero.id && currentStage == evolution.stage;

    if (isEquipped) return;

    if (!isHeroOwned) {
      // Hero not purchased yet — only stage 1 cell is tappable for purchase
      if (evolution.stage != 1) return;
      if (_wallet >= hero.price) {
        if (hero.price > 0) {
          final confirmed = await _showPurchaseConfirmation(hero.name, hero.price);
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
        HapticFeedback.lightImpact();
        _playSelectionVoice(AudioService().evolutionPickerVoiceFor(hero.id, evolution.stage));
        AudioService().playVoice(await _selectNudgeVoice());
        _showCannotAffordSnackBar(price: hero.price, wallet: _wallet, accentColor: hero.primaryColor);
      }
      return;
    }

    if (isEvoOwned) {
      // Equip this evolution + select hero
      await _heroService.selectHero(hero.id);
      await _heroService.setEvolutionStage(hero.id, evolution.stage);
      HapticFeedback.mediumImpact();
      _playSelectionVoice(AudioService().evolutionPickerVoiceFor(hero.id, evolution.stage));
      await _loadData();
    } else if (_wallet >= evolution.price) {
      // Check sequential gating: stage 3 needs stage 2
      if (evolution.stage >= 3) {
        final prevId = '${hero.id}_stage${evolution.stage - 1}';
        if (!_unlockedEvolutions.contains(prevId)) {
          HapticFeedback.lightImpact();
          return;
        }
      }
      final confirmed = await _showPurchaseConfirmation(evolution.name, evolution.price);
      if (!confirmed) return;
      final success = await _heroService.purchaseEvolution(evolution.id);
      if (success) {
        await _heroService.selectHero(hero.id);
        await _heroService.setEvolutionStage(hero.id, evolution.stage);
        HapticFeedback.heavyImpact();
        await _loadData();
      }
    } else {
      HapticFeedback.lightImpact();
      _playSelectionVoice(AudioService().evolutionPickerVoiceFor(hero.id, evolution.stage));
      AudioService().playVoice(await _selectNudgeVoice());
      _showCannotAffordSnackBar(price: evolution.price, wallet: _wallet, accentColor: hero.primaryColor);
    }
  }
```

- [ ] **Step 2: Replace `_buildHeroGrid()` with `_buildEvolutionGrid()`**

Replace the `_buildHeroGrid()` method (lines 733-777) with:

```dart
  Widget _buildEvolutionGrid() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      itemCount: HeroService.allHeroes.length,
      itemBuilder: (context, index) {
        final hero = HeroService.allHeroes[index];
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
          onEvolutionTap: (evo) => _onEvolutionTap(hero, evo),
        );
      },
    );
  }
```

Update the reference in `build()` — find where `_buildHeroGrid()` is called and replace with `_buildEvolutionGrid()`.

- [ ] **Step 3: Remove `_showArmorBottomSheet()` and `_buildEvolutionOption()`**

Delete `_showArmorBottomSheet()` (lines 265-374) and `_buildEvolutionOption()` (lines 376-552) entirely.

- [ ] **Step 4: Add `_HeroEvolutionRow` widget**

Add this class (replaces `_HeroCard` — delete `_HeroCard` class entirely):

```dart
class _HeroEvolutionRow extends StatelessWidget {
  final HeroCharacter hero;
  final List<HeroEvolution> evolutions;
  final bool isHeroOwned;
  final bool isSelected;
  final int currentStage;
  final int wallet;
  final String selectedWeaponId;
  final List<String> unlockedEvolutions;
  final ValueChanged<HeroEvolution> onEvolutionTap;

  const _HeroEvolutionRow({
    required this.hero,
    required this.evolutions,
    required this.isHeroOwned,
    required this.isSelected,
    required this.currentStage,
    required this.wallet,
    required this.selectedWeaponId,
    required this.unlockedEvolutions,
    required this.onEvolutionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? hero.primaryColor.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(
                  color: hero.primaryColor.withValues(alpha: 0.2),
                  blurRadius: 12,
                )]
              : null,
        ),
        child: Row(
          children: [
            for (int i = 0; i < evolutions.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: _EvolutionCell(
                  hero: hero,
                  evolution: evolutions[i],
                  isHeroOwned: isHeroOwned,
                  isOwned: evolutions[i].stage == 1
                      ? isHeroOwned
                      : unlockedEvolutions.contains(evolutions[i].id),
                  isEquipped: isSelected && currentStage == evolutions[i].stage,
                  isGated: evolutions[i].stage >= 3 &&
                      !unlockedEvolutions.contains('${hero.id}_stage${evolutions[i].stage - 1}'),
                  wallet: wallet,
                  weaponId: selectedWeaponId,
                  onTap: () => onEvolutionTap(evolutions[i]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Add `_EvolutionCell` widget**

```dart
class _EvolutionCell extends StatelessWidget {
  final HeroCharacter hero;
  final HeroEvolution evolution;
  final bool isHeroOwned;
  final bool isOwned;
  final bool isEquipped;
  final bool isGated;
  final int wallet;
  final String weaponId;
  final VoidCallback onTap;

  const _EvolutionCell({
    required this.hero,
    required this.evolution,
    required this.isHeroOwned,
    required this.isOwned,
    required this.isEquipped,
    required this.isGated,
    required this.wallet,
    required this.weaponId,
    required this.onTap,
  });

  int get _displayPrice {
    // Stage 1 uses the hero's base price (for un-purchased heroes)
    if (evolution.stage == 1 && !isHeroOwned) return hero.price;
    return evolution.price;
  }

  bool get _canAfford => wallet >= _displayPrice;

  @override
  Widget build(BuildContext context) {
    final locked = !isOwned;
    final showPrice = locked && _displayPrice > 0;
    final showLock = locked && (isGated || (!isHeroOwned && evolution.stage > 1));

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isEquipped
              ? hero.primaryColor.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEquipped
                ? hero.primaryColor.withValues(alpha: 0.7)
                : locked
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.15),
            width: isEquipped ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Hero evolution image
            AspectRatio(
              aspectRatio: 1,
              child: Opacity(
                opacity: locked ? 0.4 : 1.0,
                child: ColorFiltered(
                  colorFilter: locked
                      ? ColorFilter.matrix(_partialDesaturationMatrix(0.4))
                      : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      HeroService.buildHeroImage(
                        hero.id,
                        stage: evolution.stage,
                        weaponId: weaponId,
                        size: 200, // Oversized — constrained by AspectRatio parent
                      ),
                      if (showLock)
                        Icon(
                          Icons.lock,
                          color: Colors.white.withValues(alpha: 0.7),
                          size: 24,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Status indicator
            if (isEquipped)
              Icon(Icons.check_circle, color: hero.primaryColor, size: 18)
            else if (showPrice)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star,
                    color: _canAfford
                        ? const Color(0xFFFFD54F)
                        : Colors.white.withValues(alpha: 0.3),
                    size: 14,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '$_displayPrice',
                    style: TextStyle(
                      color: _canAfford
                          ? const Color(0xFFFFD54F)
                          : Colors.white.withValues(alpha: 0.3),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            else if (isOwned && !isEquipped)
              Icon(
                Icons.check_circle_outline,
                color: Colors.white.withValues(alpha: 0.3),
                size: 16,
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Remove `_FeaturedHeroDisplay` class**

Delete the entire `_FeaturedHeroDisplay` class (lines 1111-1197).

- [ ] **Step 7: Ensure `_partialDesaturationMatrix` is still accessible**

The function `_partialDesaturationMatrix` was used in `_HeroCard` (being deleted) but is also used by `_EvolutionCell`. It's a top-level or static function — verify it's still present in the file after removals. It should be defined somewhere around line 957-980. Do NOT delete it.

- [ ] **Step 8: Run dart analyze**

Run: `dart analyze lib/screens/hero_shop_screen.dart`
Expected: No issues. Fix any unused import warnings or dead references.

- [ ] **Step 9: Run flutter test**

Run: `flutter test`
Expected: All tests pass.

- [ ] **Step 10: Commit**

```bash
git add lib/screens/hero_shop_screen.dart
git commit -m "feat: redesign hero shop — evolution grid with 3 columns per hero row"
```

---

### Task 5: Quality gates and final verification

- [ ] **Step 1: Run full dart analyze**

Run: `dart analyze`
Expected: No issues.

- [ ] **Step 2: Run full test suite**

Run: `flutter test`
Expected: All tests pass.

---

## Self-Review Checklist

**Spec coverage:**
- [x] 1a: Remove featured display + checkmark → Task 4, Steps 4-6
- [x] 1b: Evolution columns layout → Task 4, Steps 2-5
- [x] 1c: Stage 3 pricing to 25 + sequential gating → Task 1
- [x] 1d: Evolution-specific voices → Tasks 2 + 3
- [x] 1e: Weapon shown in grid images → Task 4, Step 5 (buildHeroImage uses weaponId)

**Type consistency:**
- `evolutionPickerVoiceFor(heroId, stage)` — defined in Task 3, used in Task 4 Step 1
- `_partialDesaturationMatrix` — exists in file, used in Task 4 Step 5
- `HeroService.buildHeroImage(heroId, stage, weaponId, size)` — existing method, used in Task 4 Step 5
- `_unlockedEvolutions` — existing state field, used in Task 4 Steps 1, 2, 4
- `_evolutionStages` — existing state field, used in Task 4 Step 2
