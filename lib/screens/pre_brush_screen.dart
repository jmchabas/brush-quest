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
  /// runs anyway. Longer than the longest real wait: a description he taps
  /// and its nudge (about 8 s), an unlock's intro line (8.8 s).
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

  /// After a step change GO ignores taps this long, while the next page
  /// slides in (the tab 300 ms, the Map 400 ms): a double tap moves one
  /// step, not two.
  static const _goSettle = Duration(milliseconds: 400);

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
  Timer? _goSettleTimer;

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
    // A step change slides the next page in, and the second tap of a double
    // tap lands then. The first step follows no change: GO works at once.
    if (_entered) {
      _goSettleTimer?.cancel();
      _goSettleTimer = Timer(_goSettle, () => _goSettleTimer = null);
    }
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
    if (!_entered || _leaving || _goSettleTimer != null) return;
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

  /// Stops the idle count and what feeds it, and GO's settle.
  void _stopCounting() {
    _cancelIdle();
    _voiceCapTimer?.cancel();
    _scrollQuietTimer?.cancel();
    _goSettleTimer?.cancel();
    _goSettleTimer = null;
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
    // A tap can start a line (a description, a nudge) while the voice is
    // busy, so the pipeline never goes quiet in between: the cap counts
    // from here, not from the start of the run.
    _armVoiceCap();
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
        // A finger on GO holds the count like one on the page; otherwise
        // the count could run out under it and one press move on twice.
        floatingActionButton: Listener(
          onPointerDown: _onPointerDown,
          onPointerUp: _onPointerEnd,
          onPointerCancel: _onPointerEnd,
          child: GoButton(
            key: const ValueKey('prebrush_go'),
            rocket: _step == PreBrushStep.world,
            onPressed: _entered && !_leaving ? _onGo : null,
          ),
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
                // The default layout (the pages stacked, centred), but the
                // page on its way out takes no taps: one landing on it as GO
                // moves on would change a choice the next step already
                // speaks about. Every page sits in an IgnorePointer under the
                // page's own key: neither page is rebuilt from scratch as one
                // starts to leave or is gone.
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.center,
                  children: [
                    for (final page in previous)
                      IgnorePointer(key: page.key, child: page),
                    if (current != null)
                      IgnorePointer(
                        key: current.key,
                        ignoring: false,
                        child: current,
                      ),
                  ],
                ),
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
