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
  static Widget Function({required bool showWorldIntro})? debugBrushingBuilder;

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

  /// The carousel reports a new item when a page crosses its midpoint, so a
  /// quick swipe passes through items it never stops on. The choice is only
  /// saved (and its picker line spoken) once the carousel has been still for
  /// [_choiceSettle]; advancing saves a pending choice at once, silently.
  static const _choiceSettle = Duration(milliseconds: 300);
  Timer? _choiceTimer;
  String? _pendingChoice;
  Future<void>? _saving;

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
    _choiceTimer?.cancel();
    _launchTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_loaded || _leaving) return;
    if (state == AppLifecycleState.paused) {
      _cancelStepTimers();
      _commitChoice(speak: false);
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
      // getHistory() is most recent first.
      _lastBrushedWorldId = history.isEmpty ? null : history.first.worldId;

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
    _commitChoice(speak: false);
    switch (_step) {
      case PreBrushStep.hero:
        _enterStep(PreBrushStep.weapon);
      case PreBrushStep.weapon:
        _enterStep(PreBrushStep.world);
      case PreBrushStep.world:
        unawaited(_finish());
    }
  }

  void _onInteraction() {
    _cancelStepTimers();
    if (!_touched) setState(() => _touched = true);
    _idleTimer = Timer(PreBrushScreen.idleAfterTouch, _advance);
  }

  Future<void> _finish() async {
    if (_leaving) return;
    _leaving = true;
    unawaited(HapticFeedback.heavyImpact());
    unawaited(
      _audio.playVoice(
        'voice_lets_fight.mp3',
        clearQueue: true,
        interrupt: true,
      ),
    );
    unawaited(
      AnalyticsService().logBrushSessionStart(
        heroId: _heroId,
        weaponId: _weaponId,
        worldId: _worldId,
      ),
    );
    // The brushing screen reads the saved hero/weapon/world: make sure the
    // last choice has been written first.
    try {
      await _saving;
    } on Exception catch (e) {
      debugPrint('PreBrush save failed: $e');
    }
    if (!mounted) return;
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
        pageBuilder: (context, animation, secondaryAnimation) => builder != null
            ? builder(showWorldIntro: showWorldIntro)
            : BrushingScreen(showWorldIntro: showWorldIntro),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  // ── Choices ─────────────────────────────────────────────────

  void _onCarouselChanged(String id) {
    _pendingChoice = id;
    _choiceTimer?.cancel();
    _choiceTimer = Timer(_choiceSettle, () => _commitChoice(speak: true));
  }

  String get _currentChoiceId => switch (_step) {
    PreBrushStep.hero => '${_heroId}_stage$_heroStage',
    PreBrushStep.weapon => _weaponId,
    PreBrushStep.world => _worldId,
  };

  /// Saves the settled carousel choice. Settling back on the current item
  /// saves and says nothing.
  void _commitChoice({required bool speak}) {
    _choiceTimer?.cancel();
    final id = _pendingChoice;
    _pendingChoice = null;
    if (id == null || id == _currentChoiceId) return;
    _saving = switch (_step) {
      PreBrushStep.hero => _saveHero(id, speak: speak),
      PreBrushStep.weapon => _saveWeapon(id, speak: speak),
      PreBrushStep.world => _saveWorld(id, speak: speak),
    };
  }

  Future<void> _saveHero(String itemId, {required bool speak}) async {
    final parts = itemId.split('_stage');
    final heroId = parts.first;
    final stage = int.parse(parts.last);
    setState(() {
      _heroId = heroId;
      _heroStage = stage;
    });
    if (speak) {
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
    unawaited(AnalyticsService().logPreBrushChange(category: 'hero'));
    await _heroes.selectHero(heroId);
    await _heroes.setEvolutionStage(heroId, stage);
    final goal = await _goals.heroGoal();
    if (mounted) setState(() => _heroGoal = goal);
  }

  Future<void> _saveWeapon(String weaponId, {required bool speak}) async {
    setState(() => _weaponId = weaponId);
    if (speak) {
      unawaited(
        _audio.playVoice(
          _audio.weaponPickerVoiceFor(weaponId),
          clearQueue: true,
          interrupt: true,
        ),
      );
    }
    unawaited(AnalyticsService().logPreBrushChange(category: 'weapon'));
    await _weapons.selectWeapon(weaponId);
  }

  Future<void> _saveWorld(String worldId, {required bool speak}) async {
    setState(() => _worldId = worldId);
    if (speak) {
      unawaited(
        _audio.playVoice(
          'voice_world_$worldId.mp3',
          clearQueue: true,
          interrupt: true,
        ),
      );
    }
    unawaited(AnalyticsService().logPreBrushChange(category: 'world'));
    await _worlds.setCurrentWorld(worldId);
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

  /// Weapon and planet art is an opaque square on a dark background: show it
  /// the way the shop and the world map do, as a rounded square (weapons) or
  /// a circle (planets). Without a [size] it takes the largest square that
  /// fits, so a carousel page doesn't stretch the clip into an oval.
  Widget _squareArt(String path, {required bool round, double? size}) {
    final image = Image.asset(
      path,
      width: size,
      height: size,
      fit: BoxFit.cover,
    );
    final clipped = round
        ? ClipOval(child: image)
        : ClipRRect(borderRadius: BorderRadius.circular(16), child: image);
    if (size != null) return clipped;
    return Center(child: AspectRatio(aspectRatio: 1, child: clipped));
  }

  Widget _weaponArt(String weaponId, {double? size}) => _squareArt(
    WeaponService.getWeaponById(weaponId).imagePath,
    round: false,
    size: size,
  );

  Widget _planetArt(String worldId, {double? size}) => _squareArt(
    WorldService.getWorldById(worldId).imagePath,
    round: true,
    size: size,
  );

  Widget _goalImage(Goal goal, double size) => switch (goal.category) {
    GoalCategory.hero => _heroImage(goal.heroId, goal.stage, size),
    GoalCategory.weapon => _weaponArt(goal.itemId, size: size),
    GoalCategory.world => _planetArt(goal.itemId, size: size),
  };

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
          onChosen: _onCarouselChanged,
        );
      case PreBrushStep.weapon:
        return (
          items: [
            for (final id in _weaponItems)
              LoadoutItem(id: id, image: _weaponArt(id)),
          ],
          selected: _weaponId,
          onChosen: _onCarouselChanged,
        );
      case PreBrushStep.world:
        return (
          items: [
            for (final id in _worldItems)
              LoadoutItem(id: id, image: _planetArt(id)),
          ],
          selected: _worldId,
          onChosen: _onCarouselChanged,
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
        if (!didPop) return;
        // Keep what is centred, say nothing more: the screen is still
        // mounted (and its voice listener live) during the exit animation.
        _commitChoice(speak: false);
        _leaving = true;
        _cancelStepTimers();
        unawaited(_audio.stopVoice());
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
                          color: s == _step
                              ? Colors.cyanAccent
                              : Colors.white38,
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
                          ItemSilhouette(
                            // Only hero art has a transparent background.
                            opaqueArt: goal.category != GoalCategory.hero,
                            child: _goalImage(goal, 90),
                          ),
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
