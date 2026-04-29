import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/streak_service.dart';
import '../services/audio_service.dart';
import '../services/hero_service.dart';
import '../services/weapon_service.dart';

import '../services/greeting_service.dart';
import '../widgets/space_background.dart';
import '../widgets/mute_button.dart';
import 'brushing_screen.dart';
import 'hero_shop_screen.dart';
import 'world_map_screen.dart';
import 'settings_screen.dart';
import 'trophy_wall_screen.dart';
import '../services/analytics_service.dart';
import '../services/trophy_service.dart';

class HomeScreen extends StatefulWidget {
  final bool skipGreeting;
  const HomeScreen({super.key, this.skipGreeting = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _streakService = StreakService();
  final _heroService = HeroService();
  final _weaponService = WeaponService();
  final _trophyService = TrophyService();

  final _greetingService = GreetingService();
  bool _greetingChecked = false;
  int _totalStars = 0; // Ranger Rank (lifetime total)
  int _wallet = 0;
  int _streak = 0;
  int _totalBrushes = 0;
  int _trophyCount = 0;
  HeroCharacter _selectedHero = HeroService.allHeroes[0];
  int _evolutionStage = 1;
  WeaponItem _selectedWeapon = WeaponService.allWeapons[0];

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;
  late AnimationController _auraController;
  late AnimationController _breatheController;
  late Animation<double> _breatheAnimation;
  late AnimationController _statPulseController;
  late Animation<double> _statPulseAnimation;
  bool _buttonPressed = false;
  int _showStarDelta = 0;
  bool _starDeltaVisible = false;
  bool _streakPulseActive = false;
  // Guard against rapid repeat taps on the hero. Oliver (v19) reported
  // needing "multiple taps" to start brushing — there's an intentional short
  // delay after tap before navigation (for the whoosh + voice to land) and
  // a re-tap in that window would previously queue a second brush launch.
  bool _brushTapLocked = false;
  // True for ~4s after a brush session completes (only when entering home via
  // skipGreeting from victory). Drives the "last brush ✓" affirmation sticker
  // near the hero — a persistent visual proof that the last session counted,
  // not just the ephemeral wallet-delta float.
  bool _postBrushAffirmation = false;
  Timer? _affirmationTimer;
  // C15 T3-30: dedicated home-return voice pool, recorded specifically for the
  // "you just came back to the home screen" context in the Buddy (George)
  // voice. Previous pool borrowed `voice_keep_it_up` + `voice_go_go_go` from
  // mid-brush encouragement — coach-shouting-at-exercise tone, wrong context.
  static const _welcomeBackVoices = [
    'voice_home_return_1.mp3',
    'voice_home_return_2.mp3',
    'voice_home_return_3.mp3',
    'voice_home_return_4.mp3',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStats();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _floatController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _auraController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat(reverse: true);

    _breatheController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _breatheAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOut),
    );

    _statPulseController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _statPulseAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2), weight: 50),
          TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 50),
        ]).animate(
          CurvedAnimation(
            parent: _statPulseController,
            curve: Curves.easeInOut,
          ),
        );
  }

  @override
  void dispose() {
    _affirmationTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    AudioService().stopVoice();
    AudioService().stopMusic();
    _pulseController.dispose();
    _floatController.dispose();
    _auraController.dispose();
    _breatheController.dispose();
    _statPulseController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh wallet/streak/etc. when the app comes back to the foreground so
    // cross-device Firestore writes (e.g. a brush completed on another tablet)
    // are reflected immediately without requiring explicit navigation.
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(_refreshStats());
    }
  }

  /// Refresh stats without re-triggering greeting / music. Used on app resume.
  Future<void> _refreshStats() async {
    final wallet = await _streakService.getWallet();
    final rank = await _streakService.getRangerRank();
    final streak = await _streakService.getStreak();
    final totalBrushes = await _streakService.getTotalBrushes();
    final trophyCount = await _trophyService.getTotalCaptured();
    if (!mounted) return;
    setState(() {
      _totalStars = rank;
      _wallet = wallet;
      _streak = streak;
      _totalBrushes = totalBrushes;
      _trophyCount = trophyCount;
    });
    // Daily bonus is idempotent by date — safe to attempt on every resume.
    unawaited(_claimAndAnimateDailyBonus());
  }

  Future<void> _loadStats() async {
    // Auto-grant trophies for worlds already cleared
    await TrophyService().autoGrantClearedWorldTrophies();

    // Read wallet BEFORE claiming daily bonus so the greeting popup
    // shows the pre-bonus amount.  The bonus is claimed after the
    // greeting dismisses, and the wallet pill animates the bump.
    final wallet = await _streakService.getWallet();
    final rank = await _streakService.getRangerRank();
    final hero = await _heroService.getSelectedHero();
    final weapon = await _weaponService.getSelectedWeapon();
    final evolutionStage = await _heroService.getEvolutionStage(hero.id);
    final streak = await _streakService.getStreak();
    final totalBrushes = await _streakService.getTotalBrushes();
    final trophyCount = await _trophyService.getTotalCaptured();

    if (mounted) {
      setState(() {
        _totalStars = rank;
        _wallet = wallet;
        _selectedHero = hero;
        _evolutionStage = evolutionStage;
        _selectedWeapon = weapon;
        _streak = streak;
        _totalBrushes = totalBrushes;
        _trophyCount = trophyCount;
      });
      // Post-brush affirmation — when we arrive via skipGreeting from victory,
      // pulse the wallet pill and show a "✓" sticker near the hero for ~4s so
      // the kid sees tangible evidence that the last session registered. The
      // victory screen's wallet-delta float is ephemeral; this sticks around.
      if (widget.skipGreeting && totalBrushes > 0) {
        unawaited(_statPulseController.forward(from: 0));
        setState(() => _postBrushAffirmation = true);
        _affirmationTimer?.cancel();
        _affirmationTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) setState(() => _postBrushAffirmation = false);
        });
      }
      unawaited(_checkGreeting());
      // Ambient music on home screen (very low volume).
      // PLAN.md 1D-2 fix 3: serialize playMusic + setMusicVolume so the
      // volume isn't applied to the previous (disposed) player. Without
      // the await chain the calls race and on iOS the home screen ends
      // up silent after a victory→home transition. Schedule via post-
      // frame so the home animation isn't blocked by the asset load.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await AudioService().playMusic('battle_music_loop.mp3');
        if (!mounted) return;
        await AudioService().setMusicVolume(0.06);
        // Belt-and-suspenders: if the new player ended up in a stuck
        // state (iOS audioplayers occasionally fails post-dispose), the
        // health check inside ensureMusicPlaying restarts it.
        unawaited(AudioService().ensureMusicPlaying());
      });
    }
  }

  Future<void> _checkGreeting() async {
    if (_greetingChecked) return;
    _greetingChecked = true;
    // Skip full greeting when returning from a brush session,
    // but play a brief closure voice so the transition isn't silent.
    if (widget.skipGreeting) {
      if (!AudioService().isMuted) {
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          final voice =
              _welcomeBackVoices[Random().nextInt(_welcomeBackVoices.length)];
          unawaited(AudioService().playVoice(voice));
        }
      }
      // Ensure daily bonus is claimed on the brush-return path too, not only
      // on the greeting-popup path — otherwise a session where the kid opens
      // the app post-brush via an unusual route loses the bonus for the day.
      unawaited(_claimAndAnimateDailyBonus());
      return;
    }

    final totalBrushes = await _streakService.getTotalBrushes();
    if (totalBrushes == 0) {
      // First-launch: kid just finished onboarding, guide them to tap the hero
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        unawaited(AudioService().playVoice('voice_tap_hero.mp3'));
      }
      return;
    }

    final now = DateTime.now();
    final todayDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final lastGreetingDate = await _greetingService.getLastGreetingDate();
    final yesterdaySlots = await _streakService.getYesterdaySlots();

    final result = _greetingService.checkGreeting(
      totalBrushes: totalBrushes,
      brushStreak: _streak,
      wallet: _wallet,
      todayDate: todayDate,
      lastGreetingDate: lastGreetingDate,
      yesterdayBothDone:
          yesterdaySlots.morningDone && yesterdaySlots.eveningDone,
    );

    if (result != null && mounted) {
      await _greetingService.markGreetingShown(todayDate);
      unawaited(AnalyticsService().logDailyLogin(streak: _streak));
      _showGreetingPopup(
        result,
        pulseStreak:
            result.state == GreetingState.freshStart && totalBrushes > 2,
      );
    } else if (lastGreetingDate == todayDate && mounted) {
      // Already greeted today — play a random welcome back voice
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        final voice =
            _welcomeBackVoices[Random().nextInt(_welcomeBackVoices.length)];
        unawaited(AudioService().playVoice(voice));
      }
    }
    // Claim daily bonus AFTER greeting flow (so wallet pill shows pre-bonus
    // value during popup, then bumps after dismissal).
    await _claimAndAnimateDailyBonus();
  }

  /// Claims the daily streak bonus and refreshes the wallet display.
  Future<void> _claimAndAnimateDailyBonus() async {
    final bonus = await _streakService.claimDailyBonus();
    if (bonus > 0 && mounted) {
      // Refresh wallet to include the newly-claimed bonus
      final newWallet = await _streakService.getWallet();
      setState(() {
        _wallet = newWallet;
      });
    }
  }

  void _showGreetingPopup(GreetingResult greeting, {bool pulseStreak = false}) {
    AudioService().playVoice(greeting.voiceFile);
    // Queue streak teach voice (Layer 2) — shorter replacements (~4s each).
    // Layer 3 (voice_streak_bonus) eliminated; redundant with teach voices.
    if (greeting.brushStreak >= 7 && greeting.yesterdayBothDone) {
      AudioService().playVoice('voice_streak_teach_high_pair.mp3');
    } else if (greeting.brushStreak >= 7) {
      AudioService().playVoice('voice_streak_teach_high.mp3');
    } else if (greeting.brushStreak >= 3 && greeting.yesterdayBothDone) {
      AudioService().playVoice('voice_streak_teach_low_pair.mp3');
    } else if (greeting.brushStreak >= 3) {
      AudioService().playVoice('voice_streak_teach_low.mp3');
    }
    HapticFeedback.mediumImpact();

    // Non-flame icons for streak2to4 / streak5to9 so the top icon doesn't
    // duplicate the flame shown in the streak row below (Oliver v19: "2 times
    // the same graphics"). Fire theme preserved via color, not icon.
    final greetingIcon = switch (greeting.state) {
      GreetingState.justStarted => Icons.rocket_launch,
      GreetingState.streak2to4 => Icons.rocket_launch,
      GreetingState.streak5to9 => Icons.bolt,
      GreetingState.streak10to19 => Icons.star,
      GreetingState.streak20plus => Icons.emoji_events,
      GreetingState.returning => Icons.waving_hand,
      GreetingState.freshStart => Icons.rocket_launch,
    };

    final greetingColor = switch (greeting.state) {
      GreetingState.justStarted => const Color(0xFF00E5FF),
      GreetingState.streak2to4 => const Color(0xFFFF6D00),
      GreetingState.streak5to9 => const Color(0xFFFF6D00),
      GreetingState.streak10to19 => const Color(0xFFFFD54F),
      GreetingState.streak20plus => const Color(0xFFFFD54F),
      GreetingState.returning => const Color(0xFF69F0AE),
      GreetingState.freshStart => const Color(0xFF00E5FF),
    };

    final dialogFuture = showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 400),
          curve: Curves.elasticOut,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 280),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A0A2E), Color(0xFF0D1B2A)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFF69F0AE).withValues(alpha: 0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF69F0AE).withValues(alpha: 0.3),
                  blurRadius: 20,
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(greetingIcon, color: greetingColor, size: 56),
                if (greeting.brushStreak >= 2) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        color: Color(0xFFFF6D00),
                        size: 36,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${greeting.brushStreak}',
                        style: const TextStyle(
                          color: Color(0xFFFFD54F),
                          fontWeight: FontWeight.bold,
                          fontSize: 32,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.star,
                        color: Color(0xFFFFD54F),
                        size: 28,
                      ),
                    ],
                  ),
                  // Parent-facing caption so the popup is readable at a glance
                  // (Oliver v19: "nothing written for the parent to understand").
                  // Kids can't read this but it never replaces the icon + voice
                  // that kids actually parse.
                  const SizedBox(height: 4),
                  Text(
                    '${greeting.brushStreak} days in a row!',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
                // Comeback badge — returning user with broken streak
                // Visual-only (heart + stars) since the child can't read
                if (greeting.isComeback) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF69F0AE).withValues(alpha: 0.25),
                          const Color(0xFF00E5FF).withValues(alpha: 0.25),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF69F0AE).withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.favorite,
                          color: Color(0xFF69F0AE),
                          size: 24,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '+3',
                          style: TextStyle(
                            color: Color(0xFF69F0AE),
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.star, color: Color(0xFFFFD54F), size: 24),
                      ],
                    ),
                  ),
                ],
                // Bonus star badge — visual cause-effect: streak -> bonus stars
                // Shows fire icon (streak) -> arrow -> star + bonus amount
                if (greeting.brushStreak >= 3) ...[
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final streakBonus = greeting.brushStreak >= 7 ? 2 : 1;
                      final pairBonus = greeting.yesterdayBothDone ? 1 : 0;
                      final totalBonus = streakBonus + pairBonus;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFFFD54F).withValues(alpha: 0.25),
                              const Color(0xFFFF6D00).withValues(alpha: 0.25),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(
                              0xFFFFD54F,
                            ).withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Fire icon (your streak)
                            const Icon(
                              Icons.local_fire_department,
                              color: Colors.orangeAccent,
                              size: 24,
                            ),
                            const SizedBox(width: 4),
                            // Arrow showing cause -> effect
                            const Icon(
                              Icons.arrow_forward,
                              color: Color(0xFFFFD54F),
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            // Star + bonus amount (the reward)
                            Text(
                              '+$totalBonus',
                              style: const TextStyle(
                                color: Color(0xFFFFD54F),
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.star,
                              color: Color(0xFFFFD54F),
                              size: 24,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    // Track whether the voice-pipeline listener is still attached so the
    // dialog's .then cleanup can always detach it. Without this, if the dialog
    // is dismissed (barrier tap / auto-dismiss) before the voice ends, the
    // listener stays attached to the singleton notifier forever — a quiet leak
    // that accumulates one orphaned listener per greeting.
    final audio = AudioService();
    var listenerAttached = false;
    // Tracks whether the dialog was closed by the auto-dismiss path (voice
    // ended + floor elapsed) vs user tap on the barrier. If the kid tapped
    // the barrier, they were trying to reach the hero behind it — the .then
    // block interprets that as "start brushing" so it takes a single tap.
    var autoDismissed = false;
    final showTime = DateTime.now();
    void scheduleAutoDismiss(Duration delay) {
      Future.delayed(delay, () {
        if (!mounted) return;
        autoDismissed = true;
        Navigator.of(context, rootNavigator: true).maybePop();
      });
    }

    void dismissWhenReady() {
      if (!mounted) return;
      final elapsed = DateTime.now().difference(showTime);
      // Reduced from 5s — the old floor kept the dialog up even after the
      // voice ended, making the home screen feel frozen. 2s is enough to
      // register the greeting but short enough that the kid doesn't
      // re-tap thinking nothing happened.
      const floor = Duration(seconds: 2);
      if (elapsed < floor) {
        scheduleAutoDismiss(floor - elapsed);
      } else {
        scheduleAutoDismiss(const Duration(milliseconds: 500));
      }
    }

    void listener() {
      if (!audio.voicePipelineActiveNotifier.value) {
        audio.voicePipelineActiveNotifier.removeListener(listener);
        listenerAttached = false;
        dismissWhenReady();
      }
    }

    dialogFuture.then((_) {
      if (listenerAttached) {
        audio.voicePipelineActiveNotifier.removeListener(listener);
        listenerAttached = false;
      }
      audio.stopVoice();
      if (pulseStreak && mounted) {
        setState(() => _streakPulseActive = true);
        _statPulseController.forward(from: 0).then((_) {
          if (mounted) setState(() => _streakPulseActive = false);
        });
      }
      // User-initiated dismiss → kid was tapping the hero behind the dialog.
      // Honor that intent by launching the brush flow on this single tap.
      if (!autoDismissed && mounted) {
        _startBrushing();
      }
    });

    if (!audio.voicePipelineActiveNotifier.value) {
      scheduleAutoDismiss(const Duration(seconds: 2));
    } else {
      audio.voicePipelineActiveNotifier.addListener(listener);
      listenerAttached = true;
    }
  }

  void _startBrushing() {
    if (_brushTapLocked) return;
    _brushTapLocked = true;
    HapticFeedback.heavyImpact();
    AudioService().playSfx('whoosh.mp3');
    _startBrushingFlow();
  }

  Future<void> _startBrushingFlow() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    if (!prefs.containsKey('camera_mode_configured')) {
      if (!prefs.containsKey('camera_enabled')) {
        await prefs.setBool('camera_enabled', false);
      }
      await prefs.setBool('camera_mode_configured', true);
    }

    unawaited(
      AudioService().playVoice(
        'voice_lets_fight.mp3',
        clearQueue: true,
        interrupt: true,
      ),
    );
    // Tightened from 1500ms — home isn't disposed on push, so the lets-fight
    // voice keeps playing across the transition. 400ms is enough for the
    // whoosh SFX to land before nav without stalling the kid.
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _launchBrushingScreen();
    });
  }

  void _launchBrushingScreen() {
    AnalyticsService().logBrushSessionStart(
      heroId: _selectedHero.id,
      weaponId: _selectedWeapon.id,
      worldId: '', // world selected in brushing screen
    );
    Navigator.of(context)
        .push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const BrushingScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOut,
                        ),
                      ),
                      child: child,
                    ),
                  );
                },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        )
        .then((_) async {
          _brushTapLocked = false;
          final prevWallet = _wallet;
          final prevStreak = _streak;
          await _loadStats();
          if (!mounted) return;
          final walletDelta = _wallet - prevWallet;
          if (walletDelta > 0 || _streak != prevStreak) {
            unawaited(_statPulseController.forward(from: 0));
          }
          if (walletDelta > 0) {
            setState(() {
              _showStarDelta = walletDelta;
              _starDeltaVisible = true;
            });
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted) setState(() => _starDeltaVisible = false);
            });
          }
        });
  }

  void _openShop() {
    AudioService().stopVoice();
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const HeroShopScreen()))
        .then((_) => _loadStats());
  }

  void _openWorldMap() {
    AudioService().stopVoice();
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const WorldMapScreen()))
        .then((_) => _loadStats());
  }

  void _openTrophies() {
    AudioService().stopVoice();
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const TrophyWallScreen()))
        .then((_) => _loadStats());
  }

  void _openSettings() {
    AudioService().stopVoice();
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SettingsScreen()))
        .then((_) => _loadStats());
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) SystemNavigator.pop();
      },
      child: Scaffold(
        body: SpaceBackground(
          child: SafeArea(
            child: Stack(
              children: [
                // Top-left parent area button
                Positioned(
                  top: 8,
                  left: 8,
                  child: GestureDetector(
                    onTap: () {
                      AudioService().playSfx('whoosh.mp3');
                      _openSettings();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.white.withValues(alpha: 0.12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_outline,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(height: 2),
                          Text(
                            'PARENTS',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Top-right controls
                const Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [MuteButton()],
                  ),
                ),

                Column(
                  children: [
                    const SizedBox(height: 70),

                    // Title (36px, strokeWidth 3)
                    Stack(
                      children: [
                        Text(
                          'BRUSH QUEST',
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 3,
                                foreground: Paint()
                                  ..style = PaintingStyle.stroke
                                  ..strokeWidth = 3
                                  ..color = const Color(0xFF7C4DFF),
                              ),
                        ),
                        Text(
                          'BRUSH QUEST',
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 3,
                                shadows: [
                                  Shadow(
                                    color: const Color(
                                      0xFF7C4DFF,
                                    ).withValues(alpha: 0.8),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Stats row: streak, rank, wallet, trophies
                    // Use Row with Expanded so all 4 pills are equal width
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          // Streak pill
                          Expanded(
                            child: AnimatedBuilder(
                              animation: _statPulseAnimation,
                              builder: (context, child) {
                                final scale = _streakPulseActive
                                    ? _statPulseAnimation.value
                                    : 1.0;
                                return Transform.scale(
                                  scale: scale,
                                  child: child,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color:
                                        (_streak > 0
                                                ? Colors.orangeAccent
                                                : _totalBrushes > 0
                                                ? const Color(0xFFFFB74D)
                                                : Colors.white24)
                                            .withValues(alpha: 0.6),
                                    width: 2,
                                  ),
                                  color:
                                      (_streak > 0
                                              ? Colors.orangeAccent
                                              : _totalBrushes > 0
                                              ? const Color(0xFFFFB74D)
                                              : Colors.white24)
                                          .withValues(alpha: 0.12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_streak == 0 && _totalBrushes > 0) ...[
                                      const Icon(
                                        Icons.rocket_launch,
                                        color: Color(0xFFFFB74D),
                                        size: 22,
                                      ),
                                    ] else ...[
                                      Icon(
                                        Icons.local_fire_department,
                                        color: _streak > 0
                                            ? Colors.orangeAccent
                                            : Colors.white.withValues(
                                                alpha: 0.3,
                                              ),
                                        size: 26,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$_streak',
                                        style: TextStyle(
                                          color: _streak > 0
                                              ? Colors.white
                                              : Colors.white.withValues(
                                                  alpha: 0.3,
                                                ),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 22,
                                          shadows: _streak > 0
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
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Ranger Rank pill (shield — the "pride number")
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(
                                    0xFF7C4DFF,
                                  ).withValues(alpha: 0.6),
                                  width: 2,
                                ),
                                color: const Color(
                                  0xFF7C4DFF,
                                ).withValues(alpha: 0.12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.military_tech,
                                    color: Color(0xFF7C4DFF),
                                    size: 26,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$_totalStars',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 22,
                                      shadows: [
                                        Shadow(
                                          color: Color(0x807C4DFF),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Star Wallet pill (spendable stars)
                          Expanded(
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                AnimatedBuilder(
                                  animation: _statPulseAnimation,
                                  builder: (context, child) {
                                    final scale = _starDeltaVisible
                                        ? _statPulseAnimation.value
                                        : 1.0;
                                    return Transform.scale(
                                      scale: scale,
                                      child: child,
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: const Color(
                                          0xFFFFD54F,
                                        ).withValues(alpha: 0.6),
                                        width: 2,
                                      ),
                                      color: const Color(
                                        0xFFFFD54F,
                                      ).withValues(alpha: 0.12),
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
                                        Text(
                                          '$_wallet',
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
                                      ],
                                    ),
                                  ),
                                ),
                                // Floating "+N" indicator
                                if (_showStarDelta > 0)
                                  Positioned(
                                    top: -18,
                                    left: 0,
                                    right: 0,
                                    child: Center(
                                      child: AnimatedOpacity(
                                        opacity: _starDeltaVisible ? 1.0 : 0.0,
                                        duration: const Duration(
                                          milliseconds: 400,
                                        ),
                                        child: AnimatedSlide(
                                          offset: Offset(
                                            0,
                                            _starDeltaVisible ? 0.0 : 0.5,
                                          ),
                                          duration: const Duration(
                                            milliseconds: 400,
                                          ),
                                          child: Text(
                                            '+$_showStarDelta',
                                            style: const TextStyle(
                                              color: Color(0xFFFFD54F),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              shadows: [
                                                Shadow(
                                                  color: Color(0x80000000),
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Trophy count pill (monsters captured)
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(
                                    0xFFFF80AB,
                                  ).withValues(alpha: 0.6),
                                  width: 2,
                                ),
                                color: const Color(
                                  0xFFFF80AB,
                                ).withValues(alpha: 0.12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    'assets/images/icon_monsters.png',
                                    width: 22,
                                    height: 22,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$_trophyCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 22,
                                      shadows: [
                                        Shadow(
                                          color: Color(0x80FF80AB),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Hero as BRUSH button
                    AnimatedBuilder(
                      animation: Listenable.merge([
                        _pulseAnimation,
                        _floatAnimation,
                        _auraController,
                      ]),
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _floatAnimation.value),
                          child: Transform.scale(
                            scale: _buttonPressed
                                ? 0.92
                                : _pulseAnimation.value,
                            child: child,
                          ),
                        );
                      },
                      child: GestureDetector(
                        onTapDown: (_) => setState(() => _buttonPressed = true),
                        onTapUp: (_) {
                          setState(() => _buttonPressed = false);
                          _startBrushing();
                        },
                        onTapCancel: () =>
                            setState(() => _buttonPressed = false),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Hero circle with aura
                            AnimatedBuilder(
                              animation: _auraController,
                              builder: (context, child) {
                                // More pronounced aura for the "tap me" affordance.
                                // Larger size swing + stronger alpha swing makes
                                // the hero read as actively tappable rather than
                                // a static portrait (C14 Agent-1 finding: hero
                                // had no visual tap affordance).
                                final auraSize =
                                    310 + _auraController.value * 30;
                                return Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Outer aura glow
                                    Container(
                                      width: auraSize,
                                      height: auraSize,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: _selectedHero.primaryColor
                                                .withValues(
                                                  alpha:
                                                      0.3 +
                                                      _auraController.value *
                                                          0.4,
                                                ),
                                            blurRadius:
                                                40 +
                                                _auraController.value * 18,
                                            spreadRadius:
                                                10 +
                                                _auraController.value * 6,
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Hero circle + weapon badge with breathing animation
                                    ScaleTransition(
                                      scale: _breatheAnimation,
                                      child: SizedBox(
                                        width: 300,
                                        height: 300,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Container(
                                              width: 290,
                                              height: 290,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: _selectedHero
                                                      .primaryColor,
                                                  width: 4,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: _selectedHero
                                                        .primaryColor
                                                        .withValues(alpha: 0.6),
                                                    blurRadius: 30,
                                                    spreadRadius: 5,
                                                  ),
                                                ],
                                              ),
                                              child: ClipOval(
                                                child:
                                                    HeroService.buildHeroImage(
                                                      _selectedHero.id,
                                                      stage: _evolutionStage,
                                                      weaponId:
                                                          _selectedWeapon.id,
                                                      size: 180,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            // Voice prompt guides first-time users to tap hero
                            const SizedBox(height: 10),
                            Text(
                              _selectedHero.name,
                              style: TextStyle(
                                color: _selectedHero.primaryColor,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 3,
                              ),
                            ),
                            // "Last brush ✓" affirmation sticker — only visible
                            // for ~4s after the kid returns from a completed
                            // brush. Gives tangible proof that the session
                            // registered, beyond the ephemeral wallet float.
                            // Icon-only by design (non-reader).
                            const SizedBox(height: 8),
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 400),
                              opacity: _postBrushAffirmation ? 1.0 : 0.0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF00E676,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF00E676,
                                    ).withValues(alpha: 0.5),
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF00E676),
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Spacer(),

                    // Secondary nav row — always visible
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: _SmallNavButton(
                              icon: Icons.public,
                              label: 'MAP',
                              color: const Color(0xFF00E5FF),
                              onTap: _openWorldMap,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SmallNavButton(
                              imagePath: 'assets/images/icon_heroes.png',
                              label: 'HEROES',
                              color: const Color(0xFF7C4DFF),
                              onTap: _openShop,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SmallNavButton(
                              imagePath: 'assets/images/icon_monsters.png',
                              label: 'MONSTERS',
                              color: const Color(0xFFFF80AB),
                              onTap: _openTrophies,
                              // Trophy count shown in top stats row
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallNavButton extends StatelessWidget {
  final IconData? icon;
  final String? imagePath;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SmallNavButton({
    this.icon,
    this.imagePath,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AudioService().playSfx('whoosh.mp3');
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.45), width: 1.5),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 8),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (imagePath != null)
              Image.asset(imagePath!, width: 36, height: 36)
            else
              Icon(icon, color: color, size: 36),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
