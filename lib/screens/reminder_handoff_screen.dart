// lib/screens/reminder_handoff_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/audio_service.dart';
import '../services/hero_service.dart';
import '../services/reminder_plan.dart';
import '../services/reminder_service.dart';
import '../services/weapon_service.dart';
import '../widgets/parent_gate_dialog.dart';
import '../widgets/space_background.dart';
import 'after_brush_home.dart';
import 'reminder_parent_screen.dart';

/// Screen A of the bedtime reminder (spec
/// docs/superpowers/specs/2026-10-15-bedtime-reminder-design.md §3.1):
/// between the victory screen and Home, once or twice ever. For the child,
/// who can't read: a picture (his hero, an arrow, a grown-up with a
/// reminder bell) and Buddy's line. For a grown-up who missed the line, one
/// short caption under the lock ([grownUpCaption]). The lock opens the
/// GROWN-UP CHECK, then the parent's screen. The arrow, the back gesture, or [idleTimeout] without a touch go
/// Home as usual. Home itself is not changed.
class ReminderHandoffScreen extends StatefulWidget {
  const ReminderHandoffScreen({super.key, required this.offer});

  /// The first, or the second and last, time it is shown.
  final ReminderOffer offer;

  /// "Great mission! Grown-ups, tap the lock for a bedtime reminder."
  static const voiceLine = 'voice_reminder_handoff.mp3';

  /// The one line of text, for grown-ups (Jim, 2026-10-19): a parent who
  /// missed Buddy's line could not tell what the screen was. Not a button.
  static const grownUpCaption = 'Grown-ups: set a bedtime brushing reminder';

  /// This long without a touch: Home.
  static const idleTimeout = Duration(seconds: 15);

  @override
  State<ReminderHandoffScreen> createState() => _ReminderHandoffScreenState();
}

class _ReminderHandoffScreenState extends State<ReminderHandoffScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  /// The 15 s without a touch. Stopped while the gate or the parent's screen
  /// is up; cancelled in dispose.
  Timer? _idleTimer;

  /// This page's entrance transition, while Buddy waits for it to end.
  Animation<double>? _entrance;
  bool _gateOpen = false;
  bool _leaving = false;
  String _heroId = 'blaze';
  int _stage = 1;
  String _weaponId = 'star_blaster';

  @override
  void initState() {
    super.initState();
    unawaited(_loadHero());
    unawaited(ReminderService().noteOfferShown(widget.offer));
    // The route can't be read until the first frame is built.
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakWhenSettled());
    _restartIdle();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _entrance?.removeStatusListener(_onEntranceStatus);
    _pulse.dispose();
    super.dispose();
  }

  /// Buddy's line, once, when this page has settled. The page before it (the
  /// victory screen) does not go at once: the navigator keeps it under this
  /// one until this one has finished fading in, and its dispose then stops
  /// the voice channel. A line started on entry would be cut about 300 ms in.
  void _speakWhenSettled() {
    if (!mounted) return;
    final entrance = ModalRoute.of(context)?.animation;
    if (entrance == null || entrance.isCompleted) {
      _speak();
      return;
    }
    _entrance = entrance;
    entrance.addStatusListener(_onEntranceStatus);
  }

  void _onEntranceStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _entrance?.removeStatusListener(_onEntranceStatus);
    _entrance = null;
    // The page before this one is disposed in the frame in which the fade
    // ends, so the line starts after that frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _speak());
  }

  /// Not if the grown-up was quicker: the lock or the arrow already stopped
  /// the voice, and the line must not start over the check.
  void _speak() {
    if (!mounted || _leaving || _gateOpen) return;
    unawaited(AudioService().playVoice(ReminderHandoffScreen.voiceLine));
  }

  Future<void> _loadHero() async {
    final heroes = HeroService();
    final hero = await heroes.getSelectedHero();
    final stage = await heroes.getEvolutionStage(hero.id);
    final weaponId = await WeaponService().getSelectedWeaponId();
    if (!mounted) return;
    setState(() {
      _heroId = hero.id;
      _stage = stage;
      _weaponId = weaponId;
    });
  }

  /// Any touch starts the 15 s again ("15 s with no tap", spec §3.1).
  void _restartIdle() {
    _idleTimer?.cancel();
    if (_gateOpen || _leaving) return;
    _idleTimer = Timer(
      ReminderHandoffScreen.idleTimeout,
      () => _leave(ReminderOfferResult.timeout),
    );
  }

  /// Home as usual: the arrow, the back gesture, or the 15 s. Nothing here
  /// waits for the voice to stop: AudioService.stopVoice catches only
  /// Exception, and a stop that fails with an Error or never reports back
  /// would otherwise leave the child on his only route with no way out.
  void _leave(ReminderOfferResult result) {
    if (_leaving || !mounted) return;
    _leaving = true;
    _idleTimer?.cancel();
    unawaited(ReminderService().noteOfferResult(result));
    unawaited(AudioService().stopVoice());
    unawaited(AfterBrushHome.go(context));
  }

  /// Whether this page is still on the navigator. The parent's screen going
  /// Home ([AfterBrushHome.go]) removes every route below it, this page too,
  /// while this State stays mounted until the next frame.
  bool get _onNavigator => ModalRoute.of(context)?.isActive ?? false;

  /// The lock: the GROWN-UP CHECK, then the parent's screen. Cancelling the
  /// check, or backing out of that screen before deciding, comes back here
  /// and the 15 s start again. Backing out after TURN ON (during "Reminder
  /// set") goes Home: the parent has decided.
  Future<void> _openLock() async {
    if (_gateOpen || _leaving) return;
    _gateOpen = true;
    _idleTimer?.cancel();
    unawaited(HapticFeedback.lightImpact());
    unawaited(AudioService().stopVoice());
    unawaited(
      ReminderService().noteOfferResult(ReminderOfferResult.gateOpened),
    );
    final passed = await showParentGate(context);
    if (!mounted) return;
    if (passed ?? false) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ReminderParentScreen()),
      );
      // The parent's screen took Home itself and removed this page with it:
      // nothing left to do here (and no second trip Home).
      if (!mounted || !_onNavigator) return;
      final reminderOn = (await ReminderService().settings()).anyOn;
      if (!mounted || !_onNavigator) return;
      if (reminderOn) {
        _leaving = true;
        unawaited(AfterBrushHome.go(context));
        return;
      }
    }
    if (!mounted) return;
    _gateOpen = false;
    _restartIdle();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave(ReminderOfferResult.skipped);
      },
      child: Scaffold(
        body: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _restartIdle(),
          child: SpaceBackground(
            child: SafeArea(
              child: Column(
                children: [
                  const Spacer(),
                  _HandOffPicture(
                    heroId: _heroId,
                    stage: _stage,
                    weaponId: _weaponId,
                  ),
                  const Spacer(),
                  _LockButton(pulse: _pulse, onTap: _openLock),
                  const SizedBox(height: 20),
                  const _GrownUpCaption(),
                  const Spacer(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 24, 24),
                      child: _SkipArrow(
                        onTap: () => _leave(ReminderOfferResult.skipped),
                      ),
                    ),
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

/// His hero, an arrow, a grown-up with a ringing bell: "a grown-up sets a
/// reminder". Not a button.
class _HandOffPicture extends StatelessWidget {
  const _HandOffPicture({
    required this.heroId,
    required this.stage,
    required this.weaponId,
  });

  final String heroId;
  final int stage;
  final String weaponId;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('handoff_picture'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        HeroService.buildHeroImage(
          heroId,
          stage: stage,
          weaponId: weaponId,
          size: 120,
        ),
        Icon(
          Icons.trending_flat_rounded,
          color: Colors.white.withValues(alpha: 0.5),
          size: 56,
        ),
        const SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.person_rounded, color: Colors.white, size: 110),
              Positioned(
                right: 0,
                top: 2,
                child: Icon(
                  Icons.notifications_active_rounded,
                  color: Color(0xFFFFD54F),
                  size: 48,
                  shadows: [Shadow(color: Color(0xCC000000), blurRadius: 6)],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The caption under the lock, for a grown-up who missed Buddy's line:
/// calm, readable, and not a button (the lock is).
class _GrownUpCaption extends StatelessWidget {
  const _GrownUpCaption();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Text(
        ReminderHandoffScreen.grownUpCaption,
        key: const ValueKey('handoff_caption'),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.75),
          fontSize: 18,
          fontWeight: FontWeight.w500,
          height: 1.3,
        ),
      ),
    );
  }
}

/// The big gold lock the grown-up taps, gently pulsing.
class _LockButton extends StatelessWidget {
  const _LockButton({required this.pulse, required this.onTap});

  final Animation<double> pulse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) =>
          Transform.scale(scale: 1 + pulse.value * 0.06, child: child),
      // The glow is painted out here, not by the Ink: a Material clips what
      // its Ink paints to the Ink's own box, which cut the glow off flat.
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD54F).withValues(alpha: 0.45),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            key: const ValueKey('handoff_lock'),
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Ink(
              width: 150,
              height: 150,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFFFD54F), Color(0xFFFFA000)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(
                Icons.lock_rounded,
                color: Colors.white,
                size: 76,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The skip arrow, 72 px: Home as usual.
class _SkipArrow extends StatelessWidget {
  const _SkipArrow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.10),
      shape: CircleBorder(
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: InkWell(
        key: const ValueKey('handoff_skip'),
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 72,
          height: 72,
          child: Icon(
            Icons.arrow_forward_rounded,
            color: Colors.white,
            size: 40,
          ),
        ),
      ),
    );
  }
}
