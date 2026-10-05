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
/// by themselves once their line has played; a touch holds the step until
/// he has stopped touching for [idleAfterTouch].
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

  /// How long brushing waits, after [launchDelay], for "Let's fight!"
  /// (2.7 s) to finish. Brushing's countdown takes the voice channel.
  @visibleForTesting
  static Duration maxLaunchWait = const Duration(seconds: 3);
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

  /// Loading never holds up brushing (spec §8.5): past this, skip the steps.
  static const _loadTimeout = Duration(seconds: 3);

  /// Brushing reads the saved choices; it starts anyway after this.
  static const _saveTimeout = Duration(seconds: 2);

  PreBrushStep _step = PreBrushStep.hero;
  bool _loaded = false;
  bool _minElapsed = false;

  /// The child touched during this step: ✓ shows.
  bool _touched = false;

  /// Auto-advance waits from a touch until [PreBrushScreen.idleAfterTouch]
  /// has passed with no touch and the carousel at rest.
  bool _holdForTouch = false;
  bool _carouselMoving = false;

  /// In the background: nothing advances, speaks or launches.
  bool _paused = false;

  /// The steps are over, finishing (→ brushing) or closed (→ Home): nothing
  /// advances, speaks or saves from here on.
  bool _leaving = false;
  bool _closed = false;
  bool _waitingToLaunch = false;
  bool _launched = false;

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
  Timer? _launchCapTimer;

  /// The carousel reports a new item when a page crosses its midpoint, so a
  /// quick swipe passes through items it never stops on. The choice is only
  /// saved (and its picker line spoken) once the carousel has been at rest
  /// for [_choiceSettle]; advancing saves a pending choice at once, silently.
  static const _choiceSettle = Duration(milliseconds: 300);
  Timer? _choiceTimer;
  String? _pendingChoice;
  final List<Future<void>> _saves = [];

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
    _cancelLaunch();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_loaded || _closed || _launched) return;
    if (state == AppLifecycleState.paused && !_paused) {
      _paused = true;
      _cancelStepTimers();
      _commitChoice(speak: false);
      _cancelLaunch();
      unawaited(_audio.stopVoice());
    } else if (state == AppLifecycleState.resumed && _paused) {
      _paused = false;
      if (_leaving) {
        // The pause cut "Let's fight!": go straight to brushing.
        _launchBrushing(showWorldIntro: false);
      } else {
        _enterStep(_step);
      }
    }
  }

  Future<void> _load() async {
    try {
      await _loadChoices().timeout(_loadTimeout);
    } on Object catch (e) {
      // Any failure (a TypeError from a malformed record too) skips the
      // steps rather than leave the child on a blank screen.
      debugPrint('PreBrush load failed: $e');
      if (!mounted || _closed) return;
      unawaited(AnalyticsService().logPreBrushSkipped(reason: 'error'));
      unawaited(
        AnalyticsService().logBrushSessionStart(
          heroId: _heroId,
          weaponId: _weaponId,
          worldId: _worldId,
        ),
      );
      _launchBrushing(showWorldIntro: true);
      return;
    }
    if (!mounted || _closed) return;
    setState(() => _loaded = true);
    _enterStep(PreBrushStep.hero);
  }

  Future<void> _loadChoices() async {
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
  }

  // ── Step machine ────────────────────────────────────────────

  bool get _isBriefing =>
      _step == PreBrushStep.world && _worldId != _lastBrushedWorldId;

  Goal? get _goal => switch (_step) {
    PreBrushStep.hero => _heroGoal,
    PreBrushStep.weapon => _weaponGoal,
    PreBrushStep.world => _worldGoal,
  };

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
      _holdForTouch = false;
      _carouselMoving = false; // the new step builds a new carousel
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

  void _onVoiceChanged() {
    if (_waitingToLaunch) {
      _launchWhenQuiet();
    } else {
      _maybeAdvance();
    }
  }

  /// Advances once the step's line has played (voice-end gate). The caps in
  /// [_enterStep] and [_endTouchHold] advance anyway, so a voice that never
  /// ends can't hold the child here.
  void _maybeAdvance() {
    if (!mounted || _leaving || _paused || _holdForTouch || !_minElapsed) {
      return;
    }
    if (_audio.voicePipelineActiveNotifier.value) return;
    _advance();
  }

  void _advance() {
    if (!mounted || _leaving || _paused) return;
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

  // ── Touch ───────────────────────────────────────────────────

  void _onInteraction() {
    if (!_loaded || _leaving) return;
    _cancelStepTimers();
    _holdForTouch = true;
    if (!_touched) setState(() => _touched = true);
    _armIdle();
  }

  void _armIdle() {
    _idleTimer?.cancel();
    _idleTimer = Timer(PreBrushScreen.idleAfterTouch, _endTouchHold);
  }

  /// The child stopped touching. A picker line starts when the swipe
  /// settles, so it is usually still playing: hand over to the voice-end
  /// gate, capped like a step, rather than cut it.
  void _endTouchHold() {
    if (_carouselMoving) return; // its scroll end re-arms the idle wait
    _holdForTouch = false;
    _minElapsed = true;
    _capTimer?.cancel();
    _capTimer = Timer(PreBrushScreen.maxStep, _advance);
    _maybeAdvance();
  }

  /// Drags, flings and arrow animations: a moving carousel holds the step
  /// and the choice; both count from when it comes to rest. (A finger
  /// resting on the screen without moving it holds nothing.)
  bool _onCarouselScroll(ScrollNotification notification) {
    if (_leaving) return false;
    if (notification is ScrollStartNotification) {
      _carouselMoving = true;
    } else if (notification is ScrollEndNotification) {
      _carouselMoving = false;
      if (_holdForTouch) _armIdle();
      if (_pendingChoice != null) _armChoiceSettle();
    }
    return false;
  }

  // ── Finish ──────────────────────────────────────────────────

  Future<void> _finish() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    _choiceTimer?.cancel();
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
    // The brushing screen reads the saved hero, weapon and world.
    try {
      await Future.wait(_saves).timeout(_saveTimeout);
    } on Object catch (e) {
      debugPrint('PreBrush saves not finished: $e');
    }
    // A pause meanwhile launches on resume; X meanwhile stays closed.
    if (!mounted || _closed || _paused || _launched) return;
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

  void _onPop(bool didPop, Object? result) {
    if (!didPop) return;
    // Keep what is centred, then go quiet: the screen stays mounted (and its
    // voice listener live) during the exit animation.
    _commitChoice(speak: false);
    _closed = true;
    _leaving = true;
    _cancelStepTimers();
    _cancelLaunch();
    unawaited(_audio.stopVoice());
  }

  // ── Choices ─────────────────────────────────────────────────

  void _onCarouselChanged(String id) {
    if (_leaving) return;
    _pendingChoice = id;
    _armChoiceSettle();
  }

  void _armChoiceSettle() {
    _choiceTimer?.cancel();
    _choiceTimer = Timer(_choiceSettle, () {
      if (_carouselMoving) return; // its scroll end re-arms this
      _commitChoice(speak: true);
    });
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
    _saves.add(
      _guarded(switch (_step) {
        PreBrushStep.hero => () => _saveHero(id, speak: speak),
        PreBrushStep.weapon => () => _saveWeapon(id, speak: speak),
        PreBrushStep.world => () => _saveWorld(id, speak: speak),
      }),
    );
  }

  /// Runs [save] now (its first part updates the screen synchronously) and
  /// never fails: a failed write keeps the child's visible choice and is
  /// logged, and [_finish] can always await it.
  Future<void> _guarded(Future<void> Function() save) async {
    try {
      await save();
    } on Object catch (e) {
      debugPrint('PreBrush save failed: $e');
    }
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
    final String line;
    if (_step == PreBrushStep.world) {
      line = 'voice_need_more_brushes.mp3';
    } else if (_goal?.affordable ?? false) {
      line =
          'voice_ready_to_unlock.mp3'; // the full meter: "Brush to unlock it!"
    } else {
      line = 'voice_need_stars.mp3';
    }
    unawaited(_audio.playVoice(line, clearQueue: true, interrupt: true));
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
    return PopScope(
      onPopInvokedWithResult: _onPop,
      child: Scaffold(
        body: SpaceBackground(
          child: _loaded ? _buildSteps() : const SizedBox.expand(),
        ),
      ),
    );
  }

  Widget _buildSteps() {
    final c = _carousel();
    final goal = _goal;
    return SafeArea(
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
                    color: s == _step ? Colors.cyanAccent : Colors.white38,
                  ),
                ),
              const SizedBox(width: 12),
            ],
          ),
          // Once finishing, the choices are fixed: no swipes or taps that
          // could change the world brushing has already been told about.
          Expanded(
            child: IgnorePointer(
              ignoring: _leaving,
              child: Column(
                children: [
                  Expanded(
                    child: NotificationListener<ScrollNotification>(
                      onNotification: _onCarouselScroll,
                      child: LoadoutCarousel(
                        key: ValueKey('carousel_${_step.name}'),
                        items: c.items,
                        selectedId: c.selected,
                        onSelected: c.onChosen,
                        onInteraction: _onInteraction,
                      ),
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
                              ? const GoalMeter(
                                  have: 0,
                                  cost: 0,
                                  complete: true,
                                )
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
        ],
      ),
    );
  }
}
