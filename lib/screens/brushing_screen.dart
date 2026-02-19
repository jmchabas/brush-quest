import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/audio_service.dart';
import '../services/hero_service.dart';
import '../services/world_service.dart';
import '../services/camera_service.dart';
import '../services/weapon_service.dart';
import '../services/streak_service.dart';
import '../widgets/space_background.dart';
import '../widgets/mute_button.dart';
import '../widgets/glass_card.dart';
import '../widgets/mouth_guide.dart';
import 'victory_screen.dart';

class BrushingScreen extends StatefulWidget {
  const BrushingScreen({super.key});

  @override
  State<BrushingScreen> createState() => _BrushingScreenState();
}

enum BrushPhase { countdown, topLeft, topRight, bottomLeft, bottomRight, done }

const brushPhaseOrder = [
  BrushPhase.topLeft,
  BrushPhase.topRight,
  BrushPhase.bottomLeft,
  BrushPhase.bottomRight,
];

// Attack style variations
enum AttackStyle { chargeSlash, uppercut, spinAttack, energyBeam, powerSlam }

class _DamagePopup {
  String text;
  double x, y, opacity, offsetY, rotation, scale;
  Color color;
  _DamagePopup({
    required this.text, required this.x, required this.y, required this.color,
    required this.opacity, required this.offsetY, this.rotation = 0, this.scale = 1.0,
  });
}

class _Particle {
  double x, y, vx, vy, size, opacity, life;
  Color color;
  _Particle({
    required this.x, required this.y, required this.vx, required this.vy,
    required this.size, required this.color, this.opacity = 1.0, this.life = 1.0,
  });
}

class _HitSpark {
  double x, y, vx, vy, life, size;
  Color color;
  _HitSpark({
    required this.x, required this.y, required this.vx, required this.vy,
    required this.color, this.life = 1.0, this.size = 3.0,
  });
}

// Floating star animation
class _FloatingStar {
  double x, y, targetX, targetY, progress, size;
  _FloatingStar({
    required this.x, required this.y,
    required this.targetX, required this.targetY,
    required this.progress, required this.size,
  });
}

// Debris chunk for monster death explosion
class _MonsterDebris {
  double x, y, vx, vy, rotation, rotationSpeed, size, life;
  Color color;
  _MonsterDebris({
    required this.x, required this.y, required this.vx, required this.vy,
    required this.rotation, required this.rotationSpeed, required this.size,
    required this.color,
  }) : life = 1.0;
}

class _MonsterPersonality {
  final double bobSpeed;
  final double bobAmount;
  final double wobbleAmount;
  final double sizeMultiplier;
  final Color tintColor;
  final double tintStrength;
  final String name;
  final int entranceStyle; // 0=scale, 1=slide left, 2=slide right, 3=drop

  _MonsterPersonality({
    required this.bobSpeed,
    required this.bobAmount,
    required this.wobbleAmount,
    required this.sizeMultiplier,
    required this.tintColor,
    required this.tintStrength,
    required this.name,
    required this.entranceStyle,
  });

  static const _firstNames = [
    'Captain', 'Lord', 'Evil', 'Dr.', 'King', 'Mega', 'Super',
    'Tiny', 'Big', 'Dark', 'Slimy', 'Smelly', 'Grumpy', 'Fuzzy',
  ];
  static const _lastNames = [
    'Plaque', 'Cavity', 'Gumrot', 'Slime', 'Tartar', 'Decay',
    'Mold', 'Stinky', 'Goop', 'Fuzz', 'Rot', 'Crud', 'Blob',
  ];
  static const _tintColors = [
    Color(0xFFFF4081), Color(0xFF7C4DFF), Color(0xFF00BCD4),
    Color(0xFFFF6E40), Color(0xFF69F0AE), Color(0xFFFFD54F),
    Color(0xFFE040FB), Color(0xFF40C4FF), Color(0xFFFF6D00),
  ];

  factory _MonsterPersonality.random(Random rng) {
    return _MonsterPersonality(
      bobSpeed: 0.6 + rng.nextDouble() * 0.9,
      bobAmount: 2.0 + rng.nextDouble() * 8.0,
      wobbleAmount: 0.02 + rng.nextDouble() * 0.05,
      sizeMultiplier: 0.9 + rng.nextDouble() * 0.2,
      tintColor: _tintColors[rng.nextInt(_tintColors.length)],
      tintStrength: 0.05 + rng.nextDouble() * 0.2,
      name: '${_firstNames[rng.nextInt(_firstNames.length)]} ${_lastNames[rng.nextInt(_lastNames.length)]}',
      entranceStyle: rng.nextInt(4),
    );
  }

  factory _MonsterPersonality.boss(Random rng) {
    return _MonsterPersonality(
      bobSpeed: 0.4 + rng.nextDouble() * 0.3,
      bobAmount: 4.0 + rng.nextDouble() * 6.0,
      wobbleAmount: 0.01 + rng.nextDouble() * 0.02,
      sizeMultiplier: 1.1 + rng.nextDouble() * 0.1,
      tintColor: const Color(0xFFFFD54F),
      tintStrength: 0.15,
      name: 'THE CAVITY KING',
      entranceStyle: 3,
    );
  }
}

class _MonsterSlot {
  final int imageIndex;
  final _MonsterPersonality personality;
  double health;
  bool alive;
  double hitRecoil;
  double wobblePhase;
  bool isDefeating;
  double defeatProgress;
  final List<_MonsterDebris> debris;
  _MonsterSlot({
    required this.imageIndex, required this.health, required this.alive,
    required this.wobblePhase, required this.personality,
  }) : hitRecoil = 0.0, isDefeating = false, defeatProgress = 0.0, debris = [];
}

class _BrushingScreenState extends State<BrushingScreen>
    with TickerProviderStateMixin {
  final _audio = AudioService();
  final _heroService = HeroService();
  final _worldService = WorldService();
  final _cameraService = CameraService();
  final _weaponService = WeaponService();

  HeroCharacter _hero = HeroService.allHeroes[0];
  WorldData _world = WorldService.allWorlds[0];
  WeaponItem _weapon = WeaponService.allWeapons[0];

  BrushPhase _phase = BrushPhase.countdown;
  int _countdownValue = 3;
  int _phaseSecondsLeft = 30;
  Timer? _timer;
  Timer? _baseAttackTimer;
  bool _isPaused = false;
  bool _showGoText = false;

  // Animation controllers
  late AnimationController _attackSequenceController;
  late AnimationController _phaseTransitionController;
  late AnimationController _monsterEntranceController;
  late AnimationController _flashController;
  late AnimationController _screenShakeController;
  late AnimationController _monsterBreathController;
  late AnimationController _particleController;
  late AnimationController _timerPulseController;
  late AnimationController _heroIdleController;

  bool _monsterEntering = false;

  final _random = Random();

  // Combat system
  int _attackStyleIndex = 0;
  int _totalHits = 0;
  bool _isFinisher = false;
  AttackStyle get _currentAttackStyle => AttackStyle.values[_attackStyleIndex % AttackStyle.values.length];

  // Damage popups + sparks
  final List<_DamagePopup> _damagePopups = [];
  final List<_HitSpark> _hitSparks = [];
  Timer? _damageCleanupTimer;

  // Battle particles
  final List<_Particle> _particles = [];

  // Single monster per phase
  late _MonsterSlot _monster;

  // Floating star effects (visual only)
  final List<_FloatingStar> _floatingStars = [];
  Timer? _starCleanupTimer;

  // Camera & motion detection
  bool _cameraReady = false;
  int _lastAttackTime = 0;
  bool _motionGlow = false; // visual feedback for motion detected
  bool _showZoneBanner = false; // "NEW MONSTER!" banner between phases
  bool _heroLunging = false; // hero attack lunge animation
  int _monstersDefeated = 0; // monsters killed by damage during this session
  Timer? _stallTimer; // mercy timer when camera works but no motion detected

  // Mouth guide overlay
  bool _showMouthGuideOverlay = false;
  late AnimationController _mouthGuideGlowController;

  // Companion speech bubbles (icon-only for non-readers)
  IconData? _companionIcon;
  bool _showCompanionBubble = false;
  Timer? _companionTimer;
  int _encouragementIndex = 0;

  // Boss battle system
  bool _isBossSession = false;
  bool _isBossPhase = false;

  static const _phaseNames = {
    BrushPhase.topLeft: 'TOP LEFT',
    BrushPhase.topRight: 'TOP RIGHT',
    BrushPhase.bottomLeft: 'BOTTOM LEFT',
    BrushPhase.bottomRight: 'BOTTOM RIGHT',
  };

  static const _phaseToMouthQuadrant = {
    BrushPhase.topLeft: MouthQuadrant.topLeft,
    BrushPhase.topRight: MouthQuadrant.topRight,
    BrushPhase.bottomLeft: MouthQuadrant.bottomLeft,
    BrushPhase.bottomRight: MouthQuadrant.bottomRight,
  };

  static const _phaseVoiceFiles = {
    BrushPhase.topLeft: 'voice_top_left.mp3',
    BrushPhase.topRight: 'voice_top_right.mp3',
    BrushPhase.bottomLeft: 'voice_bottom_left.mp3',
    BrushPhase.bottomRight: 'voice_bottom_right.mp3',
  };

  static const _monsterImages = [
    'assets/images/monster_purple.png',
    'assets/images/monster_green.png',
    'assets/images/monster_orange.png',
    'assets/images/monster_red.png',
  ];

  static const _damageTexts = ['POW!', 'ZAP!', 'BOOM!', 'WHAM!', 'BAM!', 'SLASH!', 'SMASH!', 'HIT!'];

  static const _companionIcons = [
    Icons.star, Icons.bolt, Icons.whatshot, Icons.rocket_launch,
    Icons.auto_awesome, Icons.emoji_events, Icons.flash_on, Icons.favorite,
  ];

  bool _playedEncouragement = false;
  bool _playedAlmostThere = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    // Enter immersive mode for brushing (camera permission already requested on home screen)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Init single monster
    _monster = _createMonster();

    _attackSequenceController = AnimationController(
      duration: const Duration(milliseconds: 1200), vsync: this,
    );
    _phaseTransitionController = AnimationController(
      duration: const Duration(milliseconds: 500), vsync: this,
    );
    _monsterEntranceController = AnimationController(
      duration: const Duration(milliseconds: 600), vsync: this,
    );
    _flashController = AnimationController(
      duration: const Duration(milliseconds: 120), vsync: this,
    );
    _screenShakeController = AnimationController(
      duration: const Duration(milliseconds: 250), vsync: this,
    );
    _monsterBreathController = AnimationController(
      duration: const Duration(milliseconds: 1500), vsync: this,
    )..repeat(reverse: true);
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 50), vsync: this,
    )..repeat();
    _particleController.addListener(_updateParticlesAndSparks);
    _timerPulseController = AnimationController(
      duration: const Duration(milliseconds: 500), vsync: this,
    )..repeat(reverse: true);
    _heroIdleController = AnimationController(
      duration: const Duration(milliseconds: 1200), vsync: this,
    )..repeat(reverse: true);
    _mouthGuideGlowController = AnimationController(
      duration: const Duration(milliseconds: 700), vsync: this,
    )..repeat(reverse: true);

    _initParticles();
    _loadHeroAndWorld();
    _initCamera();
    _startCountdown();

    _damageCleanupTimer = Timer.periodic(
      const Duration(milliseconds: 40),
      (_) => _cleanupEffects(),
    );
    _starCleanupTimer = Timer.periodic(
      const Duration(milliseconds: 30),
      (_) => _updateFloatingStars(),
    );
  }

  _MonsterSlot _createMonster() {
    return _MonsterSlot(
      imageIndex: _random.nextInt(_monsterImages.length),
      health: 1.0, alive: true,
      wobblePhase: _random.nextDouble() * 2 * pi,
      personality: _MonsterPersonality.random(_random),
    );
  }

  _MonsterSlot _createWorldMonster() {
    return _MonsterSlot(
      imageIndex: _world.monsterIndices[_random.nextInt(_world.monsterIndices.length)],
      health: 1.0, alive: true,
      wobblePhase: _random.nextDouble() * 2 * pi,
      personality: _MonsterPersonality.random(_random),
    );
  }

  void _initParticles() {
    _particles.clear();
    for (int i = 0; i < 30; i++) {
      _particles.add(_createParticle());
    }
  }

  _Particle _createParticle() {
    return _Particle(
      x: _random.nextDouble(),
      y: _random.nextDouble(),
      vx: (_random.nextDouble() - 0.5) * 0.003,
      vy: -_random.nextDouble() * 0.004 - 0.001,
      size: _random.nextDouble() * 4 + 1,
      color: _world.gradientColors.isNotEmpty
          ? _world.gradientColors[_random.nextInt(_world.gradientColors.length)]
          : Colors.white,
      opacity: _random.nextDouble() * 0.6 + 0.2,
      life: _random.nextDouble(),
    );
  }

  void _updateParticlesAndSparks() {
    if (!mounted || _isPaused) return;
    for (int i = 0; i < _particles.length; i++) {
      final p = _particles[i];
      p.x += p.vx;
      p.y += p.vy;
      p.life -= 0.006;
      p.opacity = (p.life).clamp(0, 0.7);
      if (p.life <= 0 || p.y < -0.1 || p.y > 1.1 || p.x < -0.1 || p.x > 1.1) {
        _particles[i] = _createParticle();
        _particles[i].y = 0.85 + _random.nextDouble() * 0.15;
      }
    }
    for (final s in _hitSparks) {
      s.x += s.vx;
      s.y += s.vy;
      s.vy += 0.3;
      s.life -= 0.05;
    }
    _hitSparks.removeWhere((s) => s.life <= 0);

    // Decay hit recoil and update debris for single monster
    if (_monster.hitRecoil > 0.01) {
      _monster.hitRecoil -= 0.06;
      if (_monster.hitRecoil < 0.01) _monster.hitRecoil = 0.0;
    }
    if (_monster.isDefeating) {
      _monster.defeatProgress += 0.025;
      if (_monster.defeatProgress >= 1.0) {
        _monster.isDefeating = false;
        _monster.defeatProgress = 1.0;
        _monster.debris.clear();
      }
    }
    for (final d in _monster.debris) {
      d.x += d.vx;
      d.y += d.vy;
      d.vy += 0.4; // gravity
      d.rotation += d.rotationSpeed;
      d.life -= 0.03;
    }
    _monster.debris.removeWhere((d) => d.life <= 0);
  }

  void _updateFloatingStars() {
    if (!mounted || _floatingStars.isEmpty) return;
    setState(() {
      for (final star in _floatingStars) {
        star.progress += 0.025;
        final t = star.progress.clamp(0.0, 1.0);
        final curve = Curves.easeInOut.transform(t);
        star.x = star.x + (star.targetX - star.x) * 0.05;
        star.y = star.y + (star.targetY - star.y) * 0.05 + sin(star.progress * 8) * 0.5;
        star.size = 20 * (1.0 - curve * 0.5);
      }
      _floatingStars.removeWhere((s) => s.progress >= 1.0);
    });
  }

  Future<void> _initCamera() async {
    final ready = await _cameraService.initialize();
    if (mounted) {
      setState(() => _cameraReady = ready);
    }
  }

  void _startMotionDetection() {
    if (!_cameraReady) return;
    _cameraService.startMotionDetection((intensity) {
      if (!mounted || _isPaused || _phase == BrushPhase.done) return;

      // Threshold: ignore tiny noise, respond to real brushing motion
      if (intensity < 0.04) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      // Variable cooldown based on brushing intensity:
      // Gentle motion → 800ms, normal brushing → 500ms, vigorous → 300ms
      final cooldownMs = _intensityToCooldown(intensity);

      if (now - _lastAttackTime >= cooldownMs) {
        _lastAttackTime = now;
        // Show motion glow feedback — hero lights up when brushing detected
        setState(() => _motionGlow = true);
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) setState(() => _motionGlow = false);
        });
        _triggerAttack();
        _resetStallTimer(); // Reset mercy timer on successful attack
      }
    });
  }

  /// Map motion intensity to attack cooldown in milliseconds.
  /// Higher brushing intensity = shorter cooldown = faster attacks.
  int _intensityToCooldown(double intensity) {
    if (intensity >= 0.4) return 300;  // vigorous brushing
    if (intensity >= 0.15) return 500; // normal brushing
    return 800;                         // gentle motion
  }

  /// Mercy timer: if camera is active but no motion detected for 10 seconds,
  /// fire a single attack to prevent total stall (e.g. phone placed badly).
  void _resetStallTimer() {
    _stallTimer?.cancel();
    if (!_cameraReady) return;
    _stallTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && !_isPaused && _phase != BrushPhase.done && _phase != BrushPhase.countdown) {
        _triggerAttack();
        _resetStallTimer(); // Keep mercy timer running
      }
    });
  }

  void _stopMotionDetection() {
    _cameraService.stopMotionDetection();
  }

  Future<void> _loadHeroAndWorld() async {
    final hero = await _heroService.getSelectedHero();
    final world = await _worldService.getCurrentWorld();
    final weapon = await _weaponService.getSelectedWeapon();
    final totalBrushes = await StreakService().getTotalBrushes();
    if (mounted) {
      setState(() {
        _hero = hero;
        _world = world;
        _weapon = weapon;
        _isBossSession = totalBrushes > 0 && (totalBrushes + 1) % 5 == 0;
        _monster = _createWorldMonster();
        _initParticles();
      });
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _timer?.cancel();
    _baseAttackTimer?.cancel();
    _stallTimer?.cancel();
    _companionTimer?.cancel();
    _damageCleanupTimer?.cancel();
    _starCleanupTimer?.cancel();
    _stopMotionDetection();
    _attackSequenceController.dispose();
    _phaseTransitionController.dispose();
    _monsterEntranceController.dispose();
    _flashController.dispose();
    _screenShakeController.dispose();
    _monsterBreathController.dispose();
    _particleController.removeListener(_updateParticlesAndSparks);
    _particleController.dispose();
    _timerPulseController.dispose();
    _heroIdleController.dispose();
    _mouthGuideGlowController.dispose();
    _audio.stopMusic();
    super.dispose();
  }

  // ==================== COUNTDOWN ====================

  void _startCountdown() {
    setState(() => _phase = BrushPhase.countdown);
    _audio.playVoice('voice_countdown.mp3');
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownValue > 1) {
        setState(() => _countdownValue--);
        _audio.playSfx('countdown_beep.mp3');
      } else {
        timer.cancel();
        setState(() { _countdownValue = 0; _showGoText = true; });
        HapticFeedback.heavyImpact();
        _audio.playSfx('countdown_beep.mp3');
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) _startBrushing();
        });
      }
    });
  }

  // ==================== BRUSHING ====================

  void _startBrushing() {
    _totalHits = 0;
    _attackStyleIndex = 0;

    // Start battle music (2-min pre-looped file for reliable Android playback)
    _audio.playMusic('battle_music_loop.mp3');

    // Companion speech bubbles every 8 seconds
    _companionTimer?.cancel();
    _companionTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _showNextCompanionMessage(),
    );

    _switchToPhase(BrushPhase.topLeft);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPaused) return;
      setState(() => _phaseSecondsLeft--);

      if (_phaseSecondsLeft == 20 && !_playedEncouragement) {
        _playedEncouragement = true;
        final voices = _audio.encouragementVoices;
        _audio.playVoice(voices[_encouragementIndex % voices.length]);
        _encouragementIndex++;
      }
      if (_phaseSecondsLeft == 10 && !_playedAlmostThere) {
        _playedAlmostThere = true;
        _audio.playVoice('voice_almost_there.mp3');
      }

      if (_phaseSecondsLeft <= 0) {
        _playedEncouragement = false;
        _playedAlmostThere = false;
        final currentIndex = brushPhaseOrder.indexOf(_phase);
        if (currentIndex < brushPhaseOrder.length - 1) {
          _triggerFinisher(() {
            _monstersDefeated++;
            _startMonsterDeath(_monster);
            _playDefeatAnimation(() {
              final nextIndex = currentIndex + 1;
              final isLastPhase = nextIndex == brushPhaseOrder.length - 1;
              if (_isBossSession && isLastPhase) {
                _isBossPhase = true;
                _monster = _createBossMonster();
              } else {
                _monster = _createWorldMonster();
              }
              _switchToPhase(brushPhaseOrder[nextIndex]);
              _playEntranceAnimation();
              setState(() => _showZoneBanner = true);
              Future.delayed(const Duration(milliseconds: 1200), () {
                if (mounted) setState(() => _showZoneBanner = false);
              });
            });
          });
        } else {
          _triggerFinisher(() {
            _monstersDefeated++;
            _startMonsterDeath(_monster);
            _playDefeatAnimation(() { timer.cancel(); _finishBrushing(); });
          });
        }
      }
    });

    // Attack system: motion-only when camera works, timer fallback without camera
    if (_cameraReady) {
      _startMotionDetection();
      _resetStallTimer();
    } else {
      _startBaseAttackTimer();
    }
  }

  /// Fallback attack timer: ONLY used when camera is unavailable.
  /// When camera works, attacks come exclusively from motion detection.
  void _startBaseAttackTimer() {
    _baseAttackTimer?.cancel();
    _baseAttackTimer = Timer.periodic(
      const Duration(milliseconds: 2500),
      (_) {
        if (mounted && !_isPaused && _phase != BrushPhase.done && _phase != BrushPhase.countdown) {
          _triggerAttack();
        }
      },
    );
  }

  void _startMonsterDeath(_MonsterSlot monster) {
    monster.alive = false;
    monster.health = 0;
    monster.isDefeating = true;
    monster.defeatProgress = 0.0;
    monster.debris.clear();
    for (int i = 0; i < 14; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed = 4.0 + _random.nextDouble() * 8;
      monster.debris.add(_MonsterDebris(
        x: 0, y: 0,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed - 3,
        rotation: _random.nextDouble() * 2 * pi,
        rotationSpeed: (_random.nextDouble() - 0.5) * 0.3,
        size: 6 + _random.nextDouble() * 12,
        color: _world.themeColor,
      ));
    }
  }


  void _triggerFinisher(VoidCallback onComplete) {
    _baseAttackTimer?.cancel();
    _stallTimer?.cancel();
    setState(() => _isFinisher = true);
    _attackStyleIndex = 4;
    _attackSequenceController.forward(from: 0);
    _screenShakeController.forward(from: 0);
    _flashController.forward(from: 0).then((_) => _flashController.reverse());
    HapticFeedback.heavyImpact();
    _audio.playSfx('zap.mp3');

    for (int i = 0; i < 30; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed = 4.0 + _random.nextDouble() * 8;
      _hitSparks.add(_HitSpark(
        x: 0, y: 0,
        vx: cos(angle) * speed, vy: sin(angle) * speed,
        color: _weapon.primaryColor, life: 1.0,
        size: 2 + _random.nextDouble() * 5,
      ));
    }

    setState(() {
      _damagePopups.add(_DamagePopup(
        text: 'FINISH!', x: 0.5, y: 0.15,
        color: Colors.yellowAccent, opacity: 1.0, offsetY: 0,
        rotation: 0, scale: 2.0,
      ));
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() => _isFinisher = false);
        onComplete();
      }
    });
  }

  void _playDefeatAnimation(VoidCallback onComplete) {
    _baseAttackTimer?.cancel();
    _audio.playSfx('monster_defeat.mp3');
    HapticFeedback.heavyImpact();
    _flashController.forward(from: 0).then((_) => _flashController.reverse());
    _spawnDefeatSparks();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) onComplete();
    });
  }

  void _spawnDefeatSparks() {
    for (int i = 0; i < 20; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed = 3.0 + _random.nextDouble() * 6;
      _hitSparks.add(_HitSpark(
        x: 0, y: 0,
        vx: cos(angle) * speed, vy: sin(angle) * speed,
        color: _world.themeColor, life: 1.0,
        size: 2.0 + _random.nextDouble() * 4,
      ));
    }
  }

  void _playEntranceAnimation() {
    setState(() => _monsterEntering = true);
    _monsterEntranceController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() => _monsterEntering = false);
        if (_cameraReady) {
          _resetStallTimer();
        } else {
          _startBaseAttackTimer();
        }
      }
    });
  }

  void _switchToPhase(BrushPhase newPhase) {
    setState(() {
      _phase = newPhase;
      _phaseSecondsLeft = 30;
      _showMouthGuideOverlay = true;
    });
    _phaseTransitionController.forward(from: 0);
    _audio.playSfx('whoosh.mp3');
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _phaseVoiceFiles.containsKey(newPhase)) {
        _audio.playVoice(_phaseVoiceFiles[newPhase]!);
      }
    });
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) setState(() => _showMouthGuideOverlay = false);
    });
  }

  void _triggerAttack() {
    if (_phase == BrushPhase.done || _phase == BrushPhase.countdown) return;
    _audio.playSfx(_audio.nextHitSound());
    HapticFeedback.lightImpact();

    setState(() {
      _totalHits++;
      _attackStyleIndex = _totalHits % AttackStyle.values.length;
      if (_monster.alive) {
        _monster.hitRecoil = 1.0;
        // Each attack does damage (boss takes half damage)
        _monster.health -= _isBossPhase ? 0.04 : 0.08;
        if (_monster.health <= 0) {
          _monster.health = 0;
        }
      }
    });

    _attackSequenceController.forward(from: 0);
    _screenShakeController.forward(from: 0);
    _flashController.forward(from: 0).then((_) => _flashController.reverse());

    // Hero lunge animation
    setState(() => _heroLunging = true);
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _heroLunging = false);
    });

    _spawnDamagePopup();
    _spawnHitSparks();

    // Monster killed by damage — trigger early phase transition!
    if (_monster.alive && _monster.health <= 0) {
      _monsterKilledByDamage();
    }
  }

  /// Called when the monster's health is depleted by attacks (before the timer runs out).
  /// Spawns a NEW monster in the SAME phase — the kid earns bonus stars
  /// for killing fast, but must keep brushing until the 30s phase timer ends.
  /// This ensures the full 2-minute brushing session is always completed.
  void _monsterKilledByDamage() {
    _baseAttackTimer?.cancel();
    _stallTimer?.cancel();
    _monstersDefeated++;
    final wasBoss = _isBossPhase;
    setState(() {
      _damagePopups.add(_DamagePopup(
        text: wasBoss ? 'BOSS K.O.!' : 'K.O.!', x: 0.5, y: 0.12,
        color: wasBoss ? const Color(0xFFFFD54F) : Colors.yellowAccent,
        opacity: 1.0, offsetY: 0,
        rotation: 0, scale: wasBoss ? 2.6 : 2.2,
      ));
    });

    _startMonsterDeath(_monster);
    _audio.playSfx('monster_defeat.mp3');
    HapticFeedback.heavyImpact();
    _flashController.forward(from: 0).then((_) => _flashController.reverse());
    _spawnDefeatSparks();

    // Spawn a new monster in the same phase after death animation
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted || _phase == BrushPhase.done || _phase == BrushPhase.countdown) return;
      setState(() {
        _isBossPhase = false; // Boss was one-time, back to normal
        _monster = _createWorldMonster();
      });
      _playEntranceAnimation();
    });
  }

  void _showNextCompanionMessage() {
    if (!mounted || _isPaused || _phase == BrushPhase.done) return;
    final icon = _companionIcons[_random.nextInt(_companionIcons.length)];
    setState(() {
      _companionIcon = icon;
      _showCompanionBubble = true;
    });

    final voices = _audio.encouragementVoices;
    _audio.playVoice(voices[_encouragementIndex % voices.length]);
    _encouragementIndex++;

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _showCompanionBubble = false);
    });
  }

  _MonsterSlot _createBossMonster() {
    return _MonsterSlot(
      imageIndex: _random.nextInt(_monsterImages.length),
      health: 1.0,
      alive: true,
      wobblePhase: _random.nextDouble() * 2 * pi,
      personality: _MonsterPersonality.boss(_random),
    );
  }

  void _spawnDamagePopup() {
    final text = _damageTexts[_random.nextInt(_damageTexts.length)];
    setState(() {
      _damagePopups.add(_DamagePopup(
        text: text,
        x: 0.25 + _random.nextDouble() * 0.5,
        y: 0.1 + _random.nextDouble() * 0.3,
        color: _weapon.primaryColor,
        opacity: 1.0, offsetY: 0,
        rotation: (_random.nextDouble() - 0.5) * 0.4,
        scale: 1.0,
      ));
    });
  }

  void _spawnHitSparks() {
    for (int i = 0; i < 8; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed = 2.0 + _random.nextDouble() * 5;
      _hitSparks.add(_HitSpark(
        x: 0, y: 0,
        vx: cos(angle) * speed, vy: sin(angle) * speed - 2,
        color: _weapon.primaryColor, life: 1.0,
        size: 1.5 + _random.nextDouble() * 3,
      ));
    }
  }

  void _cleanupEffects() {
    if (_damagePopups.isEmpty && _hitSparks.isEmpty) return;
    setState(() {
      for (final p in _damagePopups) {
        p.offsetY -= 2.5;
        p.opacity -= 0.035;
        p.scale *= 1.005;
      }
      _damagePopups.removeWhere((p) => p.opacity <= 0);
    });
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
    if (_isPaused) {
      _monsterBreathController.stop();
      _heroIdleController.stop();
      _baseAttackTimer?.cancel();
      _stallTimer?.cancel();
      _companionTimer?.cancel();
    } else {
      _monsterBreathController.repeat(reverse: true);
      _heroIdleController.repeat(reverse: true);
      if (_cameraReady) {
        _resetStallTimer();
      } else {
        _startBaseAttackTimer();
      }
      _companionTimer = Timer.periodic(
        const Duration(seconds: 8),
        (_) => _showNextCompanionMessage(),
      );
    }
  }

  void _quitBrushing() {
    _timer?.cancel();
    _baseAttackTimer?.cancel();
    _audio.stopMusic();
    Navigator.of(context).pop();
  }

  void _finishBrushing() {
    _baseAttackTimer?.cancel();
    _stallTimer?.cancel();
    _companionTimer?.cancel();
    _stopMotionDetection();
    _audio.stopMusic();
    setState(() => _phase = BrushPhase.done);
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            VictoryScreen(starsCollected: 1, totalHits: _totalHits, monstersDefeated: _monstersDefeated, isBossSession: _isBossSession),
        transitionsBuilder: (context, anim, secondaryAnimation, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  String _getEncouragementText() {
    if (_phaseSecondsLeft > 20) return _cameraReady ? 'BRUSH TO ATTACK!' : 'FIGHT THAT MONSTER!';
    if (_phaseSecondsLeft > 10) return 'KEEP BRUSHING!';
    if (_phaseSecondsLeft > 5) return 'ALMOST THERE!';
    return 'FINISH IT OFF!';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) { if (!didPop) _togglePause(); },
      child: _phase == BrushPhase.countdown
          ? _buildCountdown()
          : _buildBrushing(),
    );
  }

  // ==================== COUNTDOWN UI ====================

  Widget _buildCountdown() {
    final displayText = _showGoText ? 'GO!' : (_countdownValue > 0 ? '$_countdownValue' : '');
    final textColor = _showGoText ? const Color(0xFF69F0AE) : Colors.white;
    final fontSize = _showGoText ? 140.0 : 120.0;
    return Scaffold(
      body: SpaceBackground(
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_showGoText)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 200),
                  duration: const Duration(milliseconds: 400),
                  builder: (context, radius, _) => Container(
                    width: radius * 2, height: radius * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        const Color(0xFF69F0AE).withValues(alpha: 0.4),
                        const Color(0xFF69F0AE).withValues(alpha: 0.0),
                      ]),
                    ),
                  ),
                ),
              TweenAnimationBuilder<double>(
                key: ValueKey('$_countdownValue-$_showGoText'),
                tween: Tween(begin: 0.5, end: 1.5),
                duration: const Duration(milliseconds: 800),
                curve: Curves.elasticOut,
                builder: (context, scale, _) => Transform.scale(
                  scale: scale,
                  child: Text(displayText, style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontSize: fontSize, fontWeight: FontWeight.bold, color: textColor,
                    shadows: [Shadow(color: (_showGoText ? const Color(0xFF69F0AE) : const Color(0xFF00E5FF)).withValues(alpha: 0.8), blurRadius: 40)],
                  )),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== BRUSHING UI ====================

  Widget _buildBrushing() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final monsterSize = _isBossPhase ? 220.0 : 180.0;
    final heroSize = 140.0;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _screenShakeController,
        builder: (context, child) {
          final t = _screenShakeController.value;
          final sx = sin(t * pi * 6) * 5 * (1 - t);
          final sy = cos(t * pi * 4) * 4 * (1 - t);
          return Transform.translate(offset: Offset(sx, sy), child: child);
        },
        child: _WorldBackground(
          world: _world,
          child: Stack(
            children: [
              // World particles
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _particleController,
                  builder: (context, _) => CustomPaint(
                    painter: _WorldParticlePainter(particles: _particles, particleType: _world.particleType),
                  ),
                ),
              ),

              SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    // Phase indicator: mouth guide + zone name + stars
                    Padding(
                      padding: const EdgeInsets.only(left: 12, right: 76),
                      child: SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
                            .animate(CurvedAnimation(parent: _phaseTransitionController, curve: Curves.elasticOut)),
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Row(
                            children: [
                              // Compact mouth guide
                              AnimatedBuilder(
                                animation: _mouthGuideGlowController,
                                builder: (context, _) => MouthGuide(
                                  activeQuadrant: _phaseToMouthQuadrant[_phase] ?? MouthQuadrant.topLeft,
                                  glowAnim: _mouthGuideGlowController.value,
                                  highlightColor: _world.themeColor,
                                  size: 50,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(_phaseNames[_phase] ?? '', maxLines: 1,
                                      style: TextStyle(
                                        color: _world.themeColor, fontWeight: FontWeight.bold,
                                        fontSize: 16, letterSpacing: 2,
                                      )),
                                    Text(_monster.personality.name.toUpperCase(),
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.5),
                                        fontSize: 10, letterSpacing: 1,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Monsters defeated counter
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.whatshot, color: Colors.orangeAccent, size: 18),
                                    const SizedBox(width: 3),
                                    Text('$_monstersDefeated',
                                      style: const TextStyle(
                                        color: Colors.orangeAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // === BATTLE ARENA: Monster on top, Hero on bottom ===
                    Expanded(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Main battle column
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // BIG MONSTER
                              _buildBigMonster(monsterSize),

                              const SizedBox(height: 8),

                              // Monster health bar
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 48),
                                child: _buildMonsterHealthBar(),
                              ),

                              const SizedBox(height: 16),

                              // Attack effects zone (spacer)
                              const SizedBox(height: 24),

                              // HERO
                              _buildHero(heroSize),

                              const SizedBox(height: 12),

                              // Timer
                              _buildTimer(screenHeight),
                              const SizedBox(height: 4),
                              Text(_getEncouragementText(), style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: _phaseSecondsLeft <= 5 ? Colors.orangeAccent : _world.themeColor,
                                fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 15,
                              )),
                            ],
                          ),

                          // Battle effect overlay (between monster and hero)
                          if (_attackSequenceController.isAnimating)
                            Positioned.fill(
                              child: AnimatedBuilder(
                                animation: _attackSequenceController,
                                builder: (context, _) {
                                  return CustomPaint(
                                    painter: _WeaponBattleEffectPainter(
                                      progress: _attackSequenceController.value,
                                      weapon: _weapon,
                                      attackStyle: _currentAttackStyle,
                                      isFinisher: _isFinisher,
                                    ),
                                  );
                                },
                              ),
                            ),

                          // Hit sparks
                          AnimatedBuilder(
                            animation: _particleController,
                            builder: (context, _) => CustomPaint(
                              size: Size(screenWidth, screenHeight),
                              painter: _HitSparkPainter(sparks: _hitSparks),
                            ),
                          ),

                          // Damage popups
                          ..._damagePopups.map((popup) => Positioned(
                            left: popup.x * screenWidth - 40,
                            top: popup.offsetY + 120,
                            child: Transform.rotate(
                              angle: popup.rotation,
                              child: Transform.scale(
                                scale: popup.scale,
                                child: Opacity(
                                  opacity: popup.opacity.clamp(0, 1),
                                  child: Text(popup.text, style: TextStyle(
                                    color: popup.color, fontSize: 26, fontWeight: FontWeight.bold,
                                    shadows: [Shadow(color: popup.color.withValues(alpha: 0.8), blurRadius: 10),
                                             Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 4)],
                                  )),
                                ),
                              ),
                            ),
                          )),

                          // Floating stars
                          ..._floatingStars.map((star) => Positioned(
                            left: star.x - star.size / 2,
                            top: star.y - star.size / 2,
                            child: Opacity(
                              opacity: (1.0 - star.progress).clamp(0, 1),
                              child: Icon(Icons.star, color: Colors.yellowAccent, size: star.size),
                            ),
                          )),

                          // Companion encouragement (icon burst, no text)
                          if (_showCompanionBubble && _companionIcon != null)
                            Positioned(
                              bottom: 210,
                              child: TweenAnimationBuilder<double>(
                                key: ValueKey(_companionIcon.hashCode + DateTime.now().millisecondsSinceEpoch),
                                tween: Tween(begin: 0.0, end: 1.0),
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.elasticOut,
                                builder: (context, value, child) => Opacity(
                                  opacity: value.clamp(0.0, 1.0),
                                  child: Transform.scale(scale: 0.3 + value * 0.7, child: child),
                                ),
                                child: Container(
                                  width: 56, height: 56,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _hero.primaryColor.withValues(alpha: 0.25),
                                    border: Border.all(color: _hero.primaryColor.withValues(alpha: 0.6), width: 2),
                                    boxShadow: [BoxShadow(
                                      color: _hero.primaryColor.withValues(alpha: 0.5),
                                      blurRadius: 16,
                                    )],
                                  ),
                                  child: Icon(_companionIcon!, color: Colors.white, size: 30),
                                ),
                              ),
                            ),

                          // Zone transition banner
                          if (_showZoneBanner)
                            Center(
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.0, end: 1.0),
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.elasticOut,
                                builder: (context, value, child) => Transform.scale(
                                  scale: value,
                                  child: child,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: _isBossPhase
                                      ? [const Color(0xFFFFD54F).withValues(alpha: 0.95), const Color(0xFFFF6D00).withValues(alpha: 0.7)]
                                      : [_world.themeColor.withValues(alpha: 0.9), _world.themeColor.withValues(alpha: 0.6)],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [BoxShadow(
                                      color: (_isBossPhase ? const Color(0xFFFFD54F) : _world.themeColor).withValues(alpha: 0.5),
                                      blurRadius: 30, spreadRadius: 5,
                                    )],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(_isBossPhase ? 'BOSS BATTLE!' : 'NEW MONSTER!',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 4,
                                          shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(_monster.personality.name.toUpperCase(),
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.7),
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                          // Mouth guide overlay at phase transitions
                          if (_showMouthGuideOverlay && _phaseToMouthQuadrant.containsKey(_phase))
                            Center(
                              child: MouthGuideOverlay(
                                quadrant: _phaseToMouthQuadrant[_phase]!,
                                themeColor: _world.themeColor,
                                label: _phaseNames[_phase] ?? '',
                                onDismiss: () {
                                  if (mounted) setState(() => _showMouthGuideOverlay = false);
                                },
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),

              // Controls + camera indicator
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, right: 8),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      // Camera status indicator
                      if (_cameraReady)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: _motionGlow
                                ? const Color(0xFF69F0AE).withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.videocam,
                            color: _motionGlow ? const Color(0xFF69F0AE) : Colors.white38,
                            size: 18,
                          ),
                        ),
                      const MuteButton(),
                      IconButton(onPressed: _togglePause, icon: const Icon(Icons.pause, color: Colors.white70, size: 24)),
                    ]),
                  ),
                ),
              ),

              // Flash overlay
              AnimatedBuilder(
                animation: _flashController,
                builder: (context, _) => _flashController.value > 0
                    ? Container(color: _weapon.primaryColor.withValues(alpha: _flashController.value * 0.15))
                    : const SizedBox.shrink(),
              ),

              if (_isPaused) _buildPauseOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== BIG MONSTER ====================

  Widget _buildBigMonster(double size) {
    final damageProgress = 1.0 - _monster.health;

    // Death explosion
    if (_monster.isDefeating) {
      return SizedBox(
        width: size + 60,
        height: size + 60,
        child: AnimatedBuilder(
          animation: _particleController,
          builder: (context, _) => CustomPaint(
            painter: _MonsterDeathPainter(
              progress: _monster.defeatProgress,
              debris: _monster.debris,
              themeColor: _world.themeColor,
              monsterSize: size,
            ),
          ),
        ),
      );
    }

    if (!_monster.alive) return SizedBox(width: size, height: size);

    final effectiveSize = size * _monster.personality.sizeMultiplier;

    Widget monsterImage = ColorFiltered(
      colorFilter: ColorFilter.mode(
        _monster.personality.tintColor.withValues(alpha: _monster.personality.tintStrength),
        BlendMode.overlay,
      ),
      child: ClipOval(
        child: Image.asset(
          _monsterImages[_monster.imageIndex],
          width: effectiveSize, height: effectiveSize, fit: BoxFit.cover,
        ),
      ),
    );

    Widget monsterWidget = AnimatedBuilder(
      animation: _monsterBreathController,
      builder: (context, child) {
        final breathT = _monsterBreathController.value;
        final p = _monster.personality;

        double scaleX = 1.0, scaleY = 1.0, rotation = 0.0;
        double translateX = 0.0, translateY = 0.0;

        // Personality-driven wobble + rotation
        final wobble = sin((breathT * p.bobSpeed + _monster.wobblePhase) * pi);
        scaleX = 1.0 + wobble * p.wobbleAmount;
        scaleY = 1.0 + wobble * p.wobbleAmount;
        rotation = sin((breathT * p.bobSpeed + _monster.wobblePhase) * pi * 2) * p.wobbleAmount;
        translateY += sin(breathT * p.bobSpeed * pi * 2) * p.bobAmount;

        // Damage shake: more damaged = more erratic
        if (damageProgress > 0.3) {
          final intensity = (damageProgress - 0.3) * 12;
          translateX += sin(breathT * pi * 12 + _monster.wobblePhase) * intensity;
          translateY += cos(breathT * pi * 10 + _monster.wobblePhase) * intensity * 0.5;
          rotation += sin(breathT * pi * 8) * (damageProgress - 0.3) * 0.1;
        }
        // Angry jitter at low health
        if (damageProgress > 0.6) {
          final jitter = (damageProgress - 0.6) * 5;
          translateX += (sin(breathT * pi * 20) * jitter);
          scaleX *= 1.0 + sin(breathT * pi * 6) * 0.02;
        }

        // Hit recoil: squash/stretch + knockback
        if (_monster.hitRecoil > 0.01) {
          if (_monster.hitRecoil > 0.5) {
            final t = (_monster.hitRecoil - 0.5) * 2;
            scaleX *= 1.0 + t * 0.25;
            scaleY *= 1.0 - t * 0.15;
          } else {
            final t = _monster.hitRecoil * 2;
            scaleX *= 1.0 - t * 0.08;
            scaleY *= 1.0 + t * 0.06;
          }
          translateY -= _monster.hitRecoil * 25; // knockback upward
        }

        final glowAlpha = (0.15 + breathT * 0.15) * (0.5 + damageProgress * 0.5);

        return Transform.translate(
          offset: Offset(translateX, translateY),
          child: Transform.rotate(
            angle: rotation,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(scaleX, scaleY, 1.0),
              child: SizedBox(
                width: size + 30,
                height: size + 40,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Shadow ellipse underneath
                    Positioned(
                      bottom: 0,
                      child: Container(
                        width: size * 0.7,
                        height: size * 0.12,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(size),
                          boxShadow: [BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 12, spreadRadius: 4,
                          )],
                        ),
                      ),
                    ),
                    // Red glow aura
                    if (glowAlpha > 0.01)
                      Container(
                        width: size + 20, height: size + 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(
                            color: Colors.redAccent.withValues(alpha: glowAlpha),
                            blurRadius: 24, spreadRadius: 8,
                          )],
                        ),
                      ),
                    // Energy ring particles
                    CustomPaint(
                      size: Size(size + 30, size + 30),
                      painter: _EnergyRingPainter(
                        animValue: breathT,
                        color: _world.themeColor,
                        health: _monster.health,
                      ),
                    ),
                    // Monster image
                    Positioned(bottom: 10, child: child!),
                    // Vignette overlay
                    Positioned(
                      bottom: 10,
                      child: Container(
                        width: size, height: size,
                        decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(
                          colors: [Colors.transparent, Colors.transparent, Colors.black.withValues(alpha: 0.4), Colors.black.withValues(alpha: 0.8)],
                          stops: const [0.0, 0.5, 0.8, 1.0],
                        )),
                      ),
                    ),
                    // Health-dependent color tinting
                    if (damageProgress > 0.5)
                      Positioned(
                        bottom: 10,
                        child: Container(
                          width: size, height: size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red.withValues(alpha: (damageProgress - 0.5) * 0.3),
                          ),
                        ),
                      ),
                    // Damage cracks
                    if (damageProgress > 0.3)
                      Positioned(bottom: 10, child: CustomPaint(
                        size: Size(size, size),
                        painter: _DamageCrackPainter(
                          progress: damageProgress, color: Colors.white,
                          glowColor: damageProgress > 0.5 ? _weapon.primaryColor : null,
                        ),
                      )),
                    // Dizzy spiral eyes (50-70% damage)
                    if (damageProgress > 0.5 && damageProgress <= 0.7)
                      Positioned(bottom: 10, child: CustomPaint(
                        size: Size(size, size),
                        painter: _MonsterOverlayPainter(animValue: breathT),
                      )),
                    // Red pulse overlay (> 70% damage)
                    if (damageProgress > 0.7)
                      Positioned(bottom: 10, child: Container(
                        width: size, height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red.withValues(alpha: 0.1 + breathT * 0.2),
                        ),
                      )),
                    // White flash on hit
                    if (_monster.hitRecoil > 0.6)
                      Positioned(bottom: 10, child: Container(
                        width: size, height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: (_monster.hitRecoil - 0.6) * 2),
                        ),
                      )),
                    // Boss crown glow + label
                    if (_isBossPhase) ...[
                      Positioned(
                        top: -5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFFFD54F), Color(0xFFFF6D00)]),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [BoxShadow(
                              color: const Color(0xFFFFD54F).withValues(alpha: 0.6),
                              blurRadius: 12, spreadRadius: 2,
                            )],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.workspace_premium, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text('BOSS', style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 2,
                              )),
                            ],
                          ),
                        ),
                      ),
                      // Boss golden aura
                      Positioned(bottom: 10, child: Container(
                        width: size + 30, height: size + 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(
                            color: const Color(0xFFFFD54F).withValues(alpha: 0.15 + breathT * 0.15),
                            blurRadius: 30, spreadRadius: 12,
                          )],
                        ),
                      )),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
      child: monsterImage,
    );

    // Entrance animation with personality-driven style
    if (_monsterEntering) {
      monsterWidget = AnimatedBuilder(
        animation: _monsterEntranceController,
        builder: (context, child) {
          final t = CurvedAnimation(parent: _monsterEntranceController, curve: Curves.bounceOut).value;
          switch (_monster.personality.entranceStyle) {
            case 1: // Slide from left
              return Transform.translate(
                offset: Offset(-200 * (1 - t), 0),
                child: Opacity(opacity: t, child: child),
              );
            case 2: // Slide from right
              return Transform.translate(
                offset: Offset(200 * (1 - t), 0),
                child: Opacity(opacity: t, child: child),
              );
            case 3: // Drop from above
              return Transform.translate(
                offset: Offset(0, -200 * (1 - t)),
                child: Opacity(opacity: t, child: child),
              );
            default: // Scale up (original)
              return Transform.scale(
                scale: 0.3 + t * 0.7,
                child: Opacity(opacity: t, child: child),
              );
          }
        },
        child: monsterWidget,
      );
    }

    return monsterWidget;
  }

  // ==================== MONSTER HEALTH BAR ====================

  Widget _buildMonsterHealthBar() {
    final health = _monster.health.clamp(0.0, 1.0);
    final healthColor = Color.lerp(const Color(0xFFFF5252), const Color(0xFF69F0AE), health)!;

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 18,
            child: LinearProgressIndicator(
              value: health,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(healthColor),
            ),
          ),
        ),
        Positioned.fill(
          child: Center(
            child: Text(
              'MONSTER HP',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== HERO ====================

  Widget _buildHero(double size) {
    final avatar = ClipOval(
      child: Image.asset(_hero.imagePath, width: size, height: size, fit: BoxFit.cover),
    );

    return AnimatedBuilder(
      animation: _heroIdleController,
      builder: (context, child) {
        final pulse = 0.3 + _heroIdleController.value * 0.3;
        final bob = sin(_heroIdleController.value * pi) * 3;
        // Motion glow: hero glows brighter when camera detects motion
        final glowBoost = _motionGlow ? 0.4 : 0.0;
        // Attack lunge: hero jumps upward toward monster
        final lungeOffset = _heroLunging ? -30.0 : 0.0;
        final lungeScale = _heroLunging ? 1.12 : 1.0;
        return Transform.translate(
          offset: Offset(0, bob + lungeOffset),
          child: Transform.scale(
            scale: lungeScale,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Glow
              Container(
                width: size + 16, height: size + 16,
                decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                  BoxShadow(color: _hero.primaryColor.withValues(alpha: pulse + glowBoost), blurRadius: 20 + (glowBoost * 20), spreadRadius: 4 + (glowBoost * 8)),
                ]),
              ),
              child!,
              // Ring border
              Container(
                width: size, height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _hero.primaryColor.withValues(alpha: 0.8 + glowBoost * 0.2), width: 3),
                ),
              ),
              // Weapon badge — shows equipped weapon icon on the hero
              Positioned(
                right: -8,
                bottom: -8,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: _heroLunging ? 54 : 46,
                  height: _heroLunging ? 54 : 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _weapon.primaryColor.withValues(alpha: _heroLunging ? 1.0 : 0.85),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: _weapon.primaryColor.withValues(alpha: _heroLunging ? 0.9 : 0.5),
                        blurRadius: _heroLunging ? 24 : 10,
                        spreadRadius: _heroLunging ? 6 : 2,
                      ),
                    ],
                  ),
                  child: Icon(_weapon.icon, color: Colors.white, size: _heroLunging ? 28 : 24),
                ),
              ),
            ],
          ),
          ),
        );
      },
      child: avatar,
    );
  }

  Widget _buildTimer(double screenHeight) {
    final isUrgent = _phaseSecondsLeft <= 5;
    final isCritical = _phaseSecondsLeft <= 3;
    Widget timerText = Text(
      _phaseSecondsLeft.toString().padLeft(2, '0'),
      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
        fontSize: (screenHeight * 0.05).clamp(36.0, 56.0),
        fontWeight: FontWeight.bold,
        color: isUrgent ? Colors.orangeAccent : Colors.white,
      ),
    );
    if (isUrgent) {
      timerText = AnimatedBuilder(
        animation: _timerPulseController,
        builder: (context, child) => Transform.scale(
          scale: 1.0 + _timerPulseController.value * 0.15, child: child,
        ),
        child: timerText,
      );
    }
    if (isCritical) {
      return Stack(alignment: Alignment.center, children: [
        AnimatedBuilder(
          animation: _timerPulseController,
          builder: (context, _) => Container(width: 80, height: 80, decoration: BoxDecoration(
            shape: BoxShape.circle, boxShadow: [BoxShadow(
              color: Colors.redAccent.withValues(alpha: 0.3 * _timerPulseController.value),
              blurRadius: 30, spreadRadius: 10,
            )],
          )),
        ),
        timerText,
      ]);
    }
    return timerText;
  }

  Widget _buildPauseOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.pause_circle_filled, size: 80, color: Colors.white54),
          const SizedBox(height: 24),
          Text('PAUSED', style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 6,
          )),
          const SizedBox(height: 48),
          GestureDetector(
            onTap: _togglePause,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF7C4DFF), Color(0xFF9C27B0)]),
                borderRadius: BorderRadius.circular(40),
                boxShadow: [BoxShadow(color: const Color(0xFF7C4DFF).withValues(alpha: 0.5), blurRadius: 20)],
              ),
              child: Text('RESUME', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 4,
              )),
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _quitBrushing,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white24),
              ),
              child: Text('QUIT', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white70, letterSpacing: 3,
              )),
            ),
          ),
        ],
      )),
    );
  }
}

// ==================== PAINTERS ====================

class _WorldBackground extends StatelessWidget {
  final WorldData world;
  final Widget child;
  const _WorldBackground({required this.world, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [
          world.gradientColors.length > 2 ? world.gradientColors[2] : const Color(0xFF0D0B2E),
          world.gradientColors.length > 1 ? world.gradientColors[1].withValues(alpha: 0.6) : const Color(0xFF0D0B2E),
          world.gradientColors.isNotEmpty ? world.gradientColors[0].withValues(alpha: 0.3) : const Color(0xFF0D0B2E),
          world.gradientColors.length > 2 ? world.gradientColors[2] : const Color(0xFF0D0B2E),
        ],
        stops: const [0.0, 0.3, 0.6, 1.0],
      )),
      child: child,
    );
  }
}

class _WorldParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final String particleType;
  _WorldParticlePainter({required this.particles, required this.particleType});
  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final x = p.x * size.width;
      final y = p.y * size.height;
      final paint = Paint()..color = p.color.withValues(alpha: p.opacity.clamp(0, 1));
      switch (particleType) {
        case 'bubble':
          paint.style = PaintingStyle.stroke; paint.strokeWidth = 1;
          canvas.drawCircle(Offset(x, y), p.size + 1, paint);
        case 'ember':
          paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
          canvas.drawCircle(Offset(x, y), p.size, paint);
        case 'twinkle':
          paint.strokeWidth = 1.5; paint.strokeCap = StrokeCap.round;
          canvas.drawLine(Offset(x - p.size, y), Offset(x + p.size, y), paint);
          canvas.drawLine(Offset(x, y - p.size), Offset(x, y + p.size), paint);
        case 'crack':
          paint.strokeWidth = 1; paint.strokeCap = StrokeCap.round;
          canvas.drawLine(Offset(x, y), Offset(x + p.vx * 600, y + p.vy * 600), paint);
        default:
          final path = Path();
          path.moveTo(x, y - p.size); path.lineTo(x + p.size * 0.6, y);
          path.lineTo(x, y + p.size); path.lineTo(x - p.size * 0.6, y); path.close();
          canvas.drawPath(path, paint);
      }
    }
  }
  @override
  bool shouldRepaint(_WorldParticlePainter oldDelegate) => true;
}

class _HitSparkPainter extends CustomPainter {
  final List<_HitSpark> sparks;
  _HitSparkPainter({required this.sparks});
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.35;
    for (final s in sparks) {
      if (s.life <= 0) continue;
      final paint = Paint()
        ..color = s.color.withValues(alpha: s.life.clamp(0, 1))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(Offset(cx + s.x, cy + s.y), s.size * s.life, paint);
    }
  }
  @override
  bool shouldRepaint(_HitSparkPainter oldDelegate) => true;
}

/// Energy ring particles orbiting the monster
class _EnergyRingPainter extends CustomPainter {
  final double animValue;
  final Color color;
  final double health;

  _EnergyRingPainter({required this.animValue, required this.color, required this.health});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.width * 0.42;
    final particleCount = 8;

    for (int i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * 2 * pi + animValue * pi * 2;
      final x = cx + cos(angle) * radius;
      final y = cy + sin(angle) * radius * 0.4; // elliptical orbit
      final alpha = (0.3 + (1 - health) * 0.4).clamp(0.0, 0.7);
      final particleSize = 2.0 + (1 - health) * 3;
      final paint = Paint()
        ..color = color.withValues(alpha: alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(Offset(x, y), particleSize, paint);
    }
  }

  @override
  bool shouldRepaint(_EnergyRingPainter oldDelegate) => animValue != oldDelegate.animValue || health != oldDelegate.health;
}

/// Weapon-aware battle effect painter
class _WeaponBattleEffectPainter extends CustomPainter {
  final double progress;
  final WeaponItem weapon;
  final AttackStyle attackStyle;
  final bool isFinisher;

  _WeaponBattleEffectPainter({
    required this.progress,
    required this.weapon,
    required this.attackStyle,
    this.isFinisher = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.35;

    final impactStart = 0.35;
    final impactEnd = 0.7;
    if (progress < impactStart || progress > impactEnd) return;

    final impactProgress = ((progress - impactStart) / (impactEnd - impactStart)).clamp(0.0, 1.0);
    final fadeAlpha = (1.0 - impactProgress) * 0.9;
    final lineWidth = isFinisher ? 6.0 : 4.0;

    final color1 = weapon.primaryColor;
    final color2 = weapon.secondaryColor;

    final paint = Paint()
      ..color = color1.withValues(alpha: fadeAlpha)
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = color2.withValues(alpha: fadeAlpha * 0.3)
      ..strokeWidth = lineWidth * 3
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    switch (weapon.effectType) {
      case AttackEffectType.flameSword:
        final slashLen = size.width * 0.4 * impactProgress;
        for (int i = 0; i < 3; i++) {
          final offset = (i - 1) * 8.0;
          canvas.drawLine(
            Offset(cx - slashLen + offset, cy - slashLen * 0.3 + offset),
            Offset(cx + slashLen + offset, cy + slashLen * 0.3 + offset),
            paint,
          );
        }
        canvas.drawLine(
          Offset(cx - slashLen, cy - slashLen * 0.3),
          Offset(cx + slashLen, cy + slashLen * 0.3),
          glowPaint,
        );
        break;

      case AttackEffectType.iceHammer:
        for (int i = 0; i < 2; i++) {
          final waveProgress = (impactProgress - i * 0.2).clamp(0.0, 1.0);
          if (waveProgress <= 0) continue;
          final radius = size.width * 0.25 * waveProgress;
          final wavePaint = Paint()
            ..color = color1.withValues(alpha: (1 - waveProgress) * fadeAlpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = lineWidth * 2 * (1 - waveProgress);
          canvas.drawCircle(Offset(cx, cy), radius, wavePaint);
        }
        for (int i = 0; i < 6; i++) {
          final angle = i * pi / 3;
          final len = size.width * 0.15 * impactProgress;
          canvas.drawLine(
            Offset(cx, cy),
            Offset(cx + cos(angle) * len, cy + sin(angle) * len),
            paint,
          );
        }
        break;

      case AttackEffectType.lightningWand:
        final path = Path();
        path.moveTo(cx, cy + size.height * 0.3);
        final segments = 6;
        for (int i = 1; i <= segments; i++) {
          final t = i / segments;
          final y = cy + size.height * 0.3 - size.height * 0.3 * t * impactProgress;
          final x = cx + (i % 2 == 0 ? 1 : -1) * 20 * impactProgress;
          path.lineTo(x, y);
        }
        paint.strokeWidth = lineWidth * 1.5;
        canvas.drawPath(path, paint);
        canvas.drawPath(path, glowPaint);
        if (impactProgress > 0.5) {
          for (int side = -1; side <= 1; side += 2) {
            final boltPath = Path();
            boltPath.moveTo(cx + side * 10, cy);
            boltPath.lineTo(cx + side * 40, cy - 20);
            boltPath.lineTo(cx + side * 25, cy - 40);
            canvas.drawPath(boltPath, paint);
          }
        }
        break;

      case AttackEffectType.vineWhip:
        final path = Path();
        path.moveTo(cx - size.width * 0.3, cy + 30);
        path.quadraticBezierTo(
          cx, cy - 40 * impactProgress,
          cx + size.width * 0.3 * impactProgress, cy,
        );
        paint.strokeWidth = lineWidth * 1.5;
        canvas.drawPath(path, paint);
        canvas.drawPath(path, glowPaint);
        final path2 = Path();
        path2.moveTo(cx + size.width * 0.3, cy + 30);
        path2.quadraticBezierTo(
          cx, cy - 20 * impactProgress,
          cx - size.width * 0.25 * impactProgress, cy + 10,
        );
        canvas.drawPath(path2, paint);
        break;

      case AttackEffectType.cosmicBurst:
        final colors = [
          const Color(0xFFFF4081),
          const Color(0xFFFFD54F),
          const Color(0xFF7C4DFF),
          const Color(0xFF00E5FF),
          const Color(0xFF69F0AE),
          const Color(0xFFFF6E40),
        ];
        for (int i = 0; i < 8; i++) {
          final angle = i * pi / 4 + impactProgress * pi * 0.5;
          final len = size.width * 0.3 * impactProgress;
          final beamPaint = Paint()
            ..color = colors[i % colors.length].withValues(alpha: fadeAlpha)
            ..strokeWidth = lineWidth
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(
            Offset(cx, cy),
            Offset(cx + cos(angle) * len, cy + sin(angle) * len),
            beamPaint,
          );
        }
        final starPaint = Paint()
          ..color = Colors.white.withValues(alpha: fadeAlpha * 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
        canvas.drawCircle(Offset(cx, cy), 20 * impactProgress, starPaint);
        break;

      default:
        final beamEndY = cy + size.height * 0.3 * (1 - impactProgress);
        paint.strokeWidth = lineWidth * 2;
        canvas.drawLine(Offset(cx, cy + size.height * 0.3), Offset(cx, beamEndY), paint);
        glowPaint.strokeWidth = lineWidth * 5;
        canvas.drawLine(Offset(cx, cy + size.height * 0.3), Offset(cx, beamEndY), glowPaint);
        break;
    }

    if (isFinisher) {
      final reach = size.width * 0.35 * impactProgress;
      canvas.drawLine(Offset(cx - reach, cy - reach), Offset(cx + reach, cy + reach), paint);
      canvas.drawLine(Offset(cx + reach, cy - reach), Offset(cx - reach, cy + reach), paint);
    }
  }

  @override
  bool shouldRepaint(_WeaponBattleEffectPainter oldDelegate) => progress != oldDelegate.progress;
}

class _DamageCrackPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color? glowColor;
  _DamageCrackPainter({required this.progress, required this.color, this.glowColor});
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint()
      ..color = color.withValues(alpha: (progress - 0.3) * 0.6)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    Paint? glowPaint;
    if (glowColor != null) {
      glowPaint = Paint()
        ..color = glowColor!.withValues(alpha: (progress - 0.3) * 0.5)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    }

    final cracks = (progress * 8).floor();
    final rng = Random(42);
    for (int i = 0; i < cracks; i++) {
      final startAngle = rng.nextDouble() * 2 * pi;
      final len = 20 + rng.nextDouble() * 35;
      final x1 = cx + cos(startAngle) * 14;
      final y1 = cy + sin(startAngle) * 14;
      var x2 = x1 + cos(startAngle) * len;
      var y2 = y1 + sin(startAngle) * len;
      if (glowPaint != null) canvas.drawLine(Offset(x1, y1), Offset(x2, y2), glowPaint);
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
      if (rng.nextBool()) {
        final branchAngle = startAngle + (rng.nextDouble() - 0.5) * 1.2;
        final bLen = len * 0.5;
        final bx = x2 + cos(branchAngle) * bLen;
        final by = y2 + sin(branchAngle) * bLen;
        if (glowPaint != null) canvas.drawLine(Offset(x2, y2), Offset(bx, by), glowPaint);
        canvas.drawLine(Offset(x2, y2), Offset(bx, by), paint);
      }
    }
  }
  @override
  bool shouldRepaint(_DamageCrackPainter oldDelegate) =>
      progress != oldDelegate.progress || glowColor != oldDelegate.glowColor;
}

// Dizzy spiral eyes overlay for heavily damaged monsters
class _MonsterOverlayPainter extends CustomPainter {
  final double animValue;
  _MonsterOverlayPainter({required this.animValue});
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.35;
    final eyeSpacing = size.width * 0.15;
    final spiralSize = size.width * 0.08;

    for (final side in [-1.0, 1.0]) {
      final ex = cx + side * eyeSpacing;
      final ey = cy;
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      final path = Path();
      const turns = 2.5;
      for (double t = 0; t < turns * 2 * pi; t += 0.2) {
        final r = spiralSize * (t / (turns * 2 * pi));
        final angle = t + animValue * pi * 4;
        final x = ex + cos(angle) * r;
        final y = ey + sin(angle) * r;
        if (t == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }
  }
  @override
  bool shouldRepaint(_MonsterOverlayPainter oldDelegate) => animValue != oldDelegate.animValue;
}

// Per-monster death explosion painter (scaled for bigger monster)
class _MonsterDeathPainter extends CustomPainter {
  final double progress;
  final List<_MonsterDebris> debris;
  final Color themeColor;
  final double monsterSize;

  _MonsterDeathPainter({
    required this.progress, required this.debris, required this.themeColor,
    this.monsterSize = 180,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final baseRadius = monsterSize * 0.3;

    // White flash (0.0-0.3)
    if (progress < 0.3) {
      final flashAlpha = progress < 0.15
          ? (progress / 0.15)
          : ((0.3 - progress) / 0.15);
      final flashPaint = Paint()..color = Colors.white.withValues(alpha: flashAlpha * 0.8);
      canvas.drawCircle(Offset(cx, cy), baseRadius, flashPaint);
    }

    // Debris chunks (0.1-0.8)
    if (progress > 0.1 && progress < 0.8) {
      for (final d in debris) {
        if (d.life <= 0) continue;
        canvas.save();
        canvas.translate(cx + d.x, cy + d.y);
        canvas.rotate(d.rotation);
        final paint = Paint()..color = d.color.withValues(alpha: d.life.clamp(0, 1));
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: d.size, height: d.size * 0.7),
          paint,
        );
        canvas.restore();
      }
    }

    // Smoke poof ring (0.2-0.6)
    if (progress > 0.2 && progress < 0.6) {
      final smokeT = ((progress - 0.2) / 0.4).clamp(0.0, 1.0);
      final radius = baseRadius * 0.5 + smokeT * baseRadius * 1.5;
      final smokeAlpha = (1.0 - smokeT) * 0.5;
      final smokePaint = Paint()
        ..color = Colors.grey.withValues(alpha: smokeAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10 * (1.0 - smokeT)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(cx, cy), radius, smokePaint);
    }

    // Ghost silhouette floats upward and fades (0.4-1.0)
    if (progress > 0.4) {
      final ghostT = ((progress - 0.4) / 0.6).clamp(0.0, 1.0);
      final ghostY = cy - ghostT * 50;
      final ghostAlpha = (1.0 - ghostT) * 0.4;
      final ghostPaint = Paint()
        ..color = themeColor.withValues(alpha: ghostAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(Offset(cx, ghostY), 25 * (1.0 - ghostT * 0.5), ghostPaint);
    }
  }

  @override
  bool shouldRepaint(_MonsterDeathPainter oldDelegate) => progress != oldDelegate.progress;
}
