import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/streak_service.dart';
import '../services/audio_service.dart';
import '../services/hero_service.dart';
import '../services/weapon_service.dart';
import '../services/world_service.dart';
import '../services/greeting_service.dart';
import '../widgets/space_background.dart';
import '../widgets/mute_button.dart';
import 'brushing_screen.dart';
import 'hero_shop_screen.dart';
import 'world_map_screen.dart';
import 'settings_screen.dart';
import 'card_album_screen.dart';
import '../services/analytics_service.dart';

class HomeScreen extends StatefulWidget {
  final bool skipGreeting;
  const HomeScreen({super.key, this.skipGreeting = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _streakService = StreakService();
  final _heroService = HeroService();
  final _weaponService = WeaponService();
  final _worldService = WorldService();
  final _greetingService = GreetingService();
  bool _greetingChecked = false;
  int _totalStars = 0;  // Ranger Rank (lifetime total)
  int _wallet = 0;
  int _streak = 0;
  int _totalBrushes = 0;
  bool _bossReady = false;
  HeroCharacter _selectedHero = HeroService.allHeroes[0];
  WeaponItem _selectedWeapon = WeaponService.allWeapons[0];
  WorldData? _currentWorld;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;
  late AnimationController _auraController;
  late AnimationController _tapPulseController;
  late Animation<double> _tapPulseAnimation;
  late AnimationController _breatheController;
  late Animation<double> _breatheAnimation;
  bool _buttonPressed = false;
  static const _welcomeBackVoices = [
    'voice_welcome_back.mp3',
    'voice_keep_it_up.mp3',
    'voice_go_go_go.mp3',
  ];

  static const Map<String, String> _unlockVoices = {
    'frost': 'voice_unlock_next_frost.mp3',
    'bolt': 'voice_unlock_next_bolt.mp3',
    'shadow': 'voice_unlock_next_shadow.mp3',
    'leaf': 'voice_unlock_next_leaf.mp3',
    'nova': 'voice_unlock_next_nova.mp3',
    'flame_sword': 'voice_unlock_next_flame_sword.mp3',
    'ice_hammer': 'voice_unlock_next_ice_hammer.mp3',
    'lightning_wand': 'voice_unlock_next_lightning_wand.mp3',
    'vine_whip': 'voice_unlock_next_vine_whip.mp3',
    'cosmic_burst': 'voice_unlock_next_cosmic_shield.mp3',
  };

  @override
  void initState() {
    super.initState();
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
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _tapPulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _tapPulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _tapPulseController, curve: Curves.easeInOut),
    );

    _breatheController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _breatheAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOut),
    );

  }

  @override
  void dispose() {
    AudioService().stopMusic();
    _pulseController.dispose();
    _floatController.dispose();
    _auraController.dispose();
    _tapPulseController.dispose();
    _breatheController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final wallet = await _streakService.getWallet();
    final rank = await _streakService.getRangerRank();
    final hero = await _heroService.getSelectedHero();
    final weapon = await _weaponService.getSelectedWeapon();
    final streak = await _streakService.getStreak();
    final totalBrushes = await _streakService.getTotalBrushes();
    final bossReady = (totalBrushes % 5) == 4;
    final world = await _worldService.getCurrentWorld();

    if (mounted) {
      setState(() {
        _totalStars = rank;
        _wallet = wallet;
        _selectedHero = hero;
        _selectedWeapon = weapon;
        _streak = streak;
        _totalBrushes = totalBrushes;
        _bossReady = bossReady;
        _currentWorld = world;
      });
      _checkGreeting();
      // Ambient music on home screen (very low volume)
      AudioService().playMusic('battle_music_loop.mp3');
      AudioService().setMusicVolume(0.06);
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
          final voice = _welcomeBackVoices[Random().nextInt(_welcomeBackVoices.length)];
          AudioService().playVoice(voice);
        }
      }
      return;
    }

    final totalBrushes = await _streakService.getTotalBrushes();
    if (totalBrushes == 0) {
      // First-launch: kid just finished onboarding, guide them to tap the hero
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        AudioService().playVoice('voice_tap_hero.mp3');
      }
      return;
    }

    final now = DateTime.now();
    final todayDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final lastGreetingDate = await _greetingService.getLastGreetingDate();

    final nextHero = await _heroService.getNextLockedHero();
    final nextWeapon = await _weaponService.getNextLockedWeapon();

    final result = _greetingService.checkGreeting(
      totalBrushes: totalBrushes,
      brushStreak: _streak,
      totalStars: _totalStars,
      nextHeroName: nextHero?.name,
      nextHeroUnlockAt: nextHero?.price,
      nextWeaponName: nextWeapon?.name,
      nextWeaponUnlockAt: nextWeapon?.price,
      todayDate: todayDate,
      lastGreetingDate: lastGreetingDate,
      nextHeroId: nextHero?.id,
      nextHeroImagePath: nextHero?.imagePath,
      nextWeaponId: nextWeapon?.id,
      nextWeaponImagePath: nextWeapon?.imagePath,
    );

    if (result != null && mounted) {
      await _greetingService.markGreetingShown(todayDate);
      AnalyticsService().logDailyLogin(streak: _streak);
      _showGreetingPopup(result);
    } else if (lastGreetingDate == todayDate && mounted) {
      // Already greeted today — play a random welcome back voice
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        final voice = _welcomeBackVoices[Random().nextInt(_welcomeBackVoices.length)];
        AudioService().playVoice(voice);
      }
    }
  }

  void _showGreetingPopup(GreetingResult greeting) {
    AudioService().playVoice(greeting.voiceFile);
    // Queue unlock tease voice AFTER the greeting voice finishes
    if (greeting.teaseItemId != null) {
      final unlockVoice = _unlockVoices[greeting.teaseItemId];
      if (unlockVoice != null) {
        AudioService().playVoice(unlockVoice);
      }
    }
    HapticFeedback.mediumImpact();

    final title = switch (greeting.state) {
      GreetingState.justStarted => 'HEY SPACE RANGER!',
      GreetingState.streak2to4 => 'WELCOME BACK!',
      GreetingState.streak5to9 => 'WELCOME BACK!',
      GreetingState.streak10to19 => 'SUPER RANGER!',
      GreetingState.streak20plus => 'LEGENDARY!',
      GreetingState.returning => 'WELCOME BACK!',
    };

    showDialog(
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
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF69F0AE),
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    letterSpacing: 3,
                  ),
                ),
                if (greeting.brushStreak >= 2) ...[
                  const SizedBox(height: 12),
                  Text(
                    '\u{1F525} ${greeting.brushStreak} DAY STREAK!',
                    style: const TextStyle(
                      color: Color(0xFFFFD54F),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      letterSpacing: 1,
                    ),
                  ),
                ],
                if (greeting.teaseItemImagePath != null &&
                    greeting.teaseItemUnlockAt != null &&
                    greeting.teaseStarsAway != null &&
                    greeting.teaseStarsAway! > 0) ...[
                  const SizedBox(height: 16),
                  // Next unlock item icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFFD54F).withValues(alpha: 0.6),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD54F).withValues(alpha: 0.3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        greeting.teaseItemImagePath!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Progress bar toward unlock
                  SizedBox(
                    width: 160,
                    child: Column(
                      children: [
                        // Star icons showing progress
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Color(0xFFFFD54F),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${greeting.totalStars}',
                              style: const TextStyle(
                                color: Color(0xFFFFD54F),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              ' / ${greeting.teaseItemUnlockAt}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: greeting.totalStars / greeting.teaseItemUnlockAt!,
                            minHeight: 8,
                            backgroundColor: Colors.white.withValues(alpha: 0.1),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFFFD54F),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => Navigator.of(dialogContext).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF69F0AE).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF69F0AE).withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Text(
                      "LET'S GO!",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // Auto-dismiss when voice finishes + 0.5s (minimum 3s)
    final showTime = DateTime.now();
    void dismissWhenReady() {
      if (!mounted) return;
      final elapsed = DateTime.now().difference(showTime);
      if (elapsed < const Duration(seconds: 3)) {
        // Ensure minimum display time
        Future.delayed(const Duration(seconds: 3) - elapsed, () {
          if (mounted) Navigator.of(context, rootNavigator: true).maybePop();
        });
      } else {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) Navigator.of(context, rootNavigator: true).maybePop();
        });
      }
    }
    void listener() {
      if (!AudioService().voicePipelineActiveNotifier.value) {
        AudioService().voicePipelineActiveNotifier.removeListener(listener);
        dismissWhenReady();
      }
    }
    // If voice is already done, dismiss with minimum delay
    if (!AudioService().voicePipelineActiveNotifier.value) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) Navigator.of(context, rootNavigator: true).maybePop();
      });
    } else {
      AudioService().voicePipelineActiveNotifier.addListener(listener);
    }
  }

  void _startBrushing() {
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

    AudioService().playVoice(
      'voice_lets_fight.mp3',
      clearQueue: true,
      interrupt: true,
    );
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _launchBrushingScreen();
    });
  }

  void _launchBrushingScreen() {
    AnalyticsService().logBrushSessionStart(
      heroId: _selectedHero.id,
      weaponId: _selectedWeapon.id,
      worldId: '', // world selected in brushing screen
      isBossSession: _bossReady,
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
        .then((_) => _loadStats());
  }

  void _openShop() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const HeroShopScreen()))
        .then((_) => _loadStats());
  }

  void _openWorldMap() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const WorldMapScreen()))
        .then((_) => _loadStats());
  }

  void _openCards() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const CardAlbumScreen()))
        .then((_) => _loadStats());
  }

  void _openSettings() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SettingsScreen()))
        .then((_) => _loadStats());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Stack(
            children: [
              // Top-left settings gear
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  onPressed: () {
                    AudioService().playSfx('whoosh.mp3');
                    _openSettings();
                  },
                  icon: Icon(
                    Icons.settings,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 26,
                  ),
                ),
              ),
              // Top-right controls
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [const MuteButton()],
                ),
              ),

              Column(
                children: [
                  const SizedBox(height: 40),

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

                  // Stats row: streak pill + star pill
                  Row(
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
                            color: (_streak > 0
                                    ? Colors.orangeAccent
                                    : _totalBrushes > 0
                                        ? const Color(0xFF00E5FF)
                                        : Colors.white24)
                                .withValues(alpha: 0.6),
                            width: 2,
                          ),
                          color: (_streak > 0
                                  ? Colors.orangeAccent
                                  : _totalBrushes > 0
                                      ? const Color(0xFF00E5FF)
                                      : Colors.white24)
                              .withValues(alpha: 0.12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_streak == 0 && _totalBrushes > 0) ...[
                              const Icon(
                                Icons.rocket_launch,
                                color: Color(0xFF00E5FF),
                                size: 22,
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'NEW!',
                                style: TextStyle(
                                  color: Color(0xFF00E5FF),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  letterSpacing: 1,
                                ),
                              ),
                            ] else ...[
                              Icon(
                                Icons.local_fire_department,
                                color: _streak > 0
                                    ? Colors.orangeAccent
                                    : Colors.white.withValues(alpha: 0.3),
                                size: 26,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$_streak',
                                style: TextStyle(
                                  color: _streak > 0
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.3),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 28,
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
                      const SizedBox(width: 12),
                      // Ranger Rank pill (shield — the "pride number")
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
                              Icons.shield,
                              color: Color(0xFF7C4DFF),
                              size: 26,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$_totalStars',
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
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Star Wallet pill (spendable stars)
                      Container(
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
                    ],
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
                          scale: _buttonPressed ? 0.92 : _pulseAnimation.value,
                          child: child,
                        ),
                      );
                    },
                    child: GestureDetector(
                      onTapDown: (_) => setState(() => _buttonPressed = true),
                      onTapUp: (_) {
                        setState(() => _buttonPressed = false);
                        _openShop();
                      },
                      onTapCancel: () => setState(() => _buttonPressed = false),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Hero circle with aura
                          AnimatedBuilder(
                            animation: _auraController,
                            builder: (context, child) {
                              final auraSize = 310 + _auraController.value * 16;
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
                                                    _auraController.value * 0.2,
                                              ),
                                          blurRadius: 40,
                                          spreadRadius: 10,
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
                                                color: _selectedHero.primaryColor,
                                                width: 4,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: _selectedHero.primaryColor
                                                      .withValues(alpha: 0.6),
                                                  blurRadius: 30,
                                                  spreadRadius: 5,
                                                ),
                                              ],
                                            ),
                                            child: ClipOval(
                                              child: Image.asset(
                                                _selectedHero.imagePath,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                          // Weapon badge
                                          Positioned(
                                            right: 6,
                                            bottom: 6,
                                            child: Container(
                                              width: 52,
                                              height: 52,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: const Color(0xFF0D0B2E),
                                                border: Border.all(
                                                  color: _selectedWeapon
                                                      .primaryColor,
                                                  width: 3,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: _selectedWeapon
                                                        .primaryColor
                                                        .withValues(alpha: 0.5),
                                                    blurRadius: 10,
                                                  ),
                                                ],
                                              ),
                                              child: ClipOval(
                                                child: Image.asset(
                                                  _selectedWeapon.imagePath,
                                                  width: 46,
                                                  height: 46,
                                                  fit: BoxFit.cover,
                                                ),
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
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // BRUSH button
                  GestureDetector(
                    onTap: _startBrushing,
                    child: AnimatedBuilder(
                      animation: _tapPulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 1.0 + _tapPulseAnimation.value * 0.03,
                          child: child,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _selectedHero.primaryColor,
                              _selectedHero.primaryColor.withValues(alpha: 0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: _selectedHero.primaryColor.withValues(alpha: 0.5),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Text(
                          'BRUSH!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Today's Mission teaser
                  if (_currentWorld != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: _currentWorld!.themeColor.withValues(alpha: 0.1),
                        border: Border.all(
                          color: _currentWorld!.themeColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.public,
                            color: _currentWorld!.themeColor,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _currentWorld!.name.toUpperCase(),
                            style: TextStyle(
                              color: _currentWorld!.themeColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Boss fight badge
                  if (_bossReady) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: const Color(0xFFFF5252).withValues(alpha: 0.15),
                        border: Border.all(
                          color: const Color(0xFFFF5252).withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF5252).withValues(alpha: 0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.workspace_premium,
                            color: Color(0xFFFF5252),
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'BOSS FIGHT READY!',
                            style: TextStyle(
                              color: Color(0xFFFF5252),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const Spacer(),

                  // Secondary nav row — hidden until first brush
                  if (_totalBrushes > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: _SmallNavButton(
                              icon: Icons.rocket_launch,
                              label: 'MAP',
                              color: const Color(0xFF00E5FF),
                              onTap: _openWorldMap,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SmallNavButton(
                              icon: Icons.shield,
                              label: 'HEROES',
                              color: const Color(0xFF7C4DFF),
                              onTap: _openShop,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SmallNavButton(
                              icon: Icons.style,
                              label: 'CARDS',
                              color: const Color(0xFFFFD54F),
                              onTap: _openCards,
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
    );
  }
}

class _SmallNavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SmallNavButton({
    required this.icon,
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
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
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
