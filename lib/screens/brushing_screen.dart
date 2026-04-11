import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/audio_service.dart';
import '../services/hero_service.dart';
import '../services/world_service.dart';
import '../services/camera_service.dart';
import '../services/weapon_service.dart';
import '../widgets/space_background.dart';
import '../widgets/mute_button.dart';
import 'package:lottie/lottie.dart';
import '../widgets/mouth_guide.dart';
import '../services/analytics_service.dart';
import '../services/trophy_service.dart';
import 'victory_screen.dart';

class BrushingScreen extends StatefulWidget {
  const BrushingScreen({super.key});

  @override
  State<BrushingScreen> createState() => _BrushingScreenState();
}

enum BrushPhase {
  countdown,
  topLeft,
  topFront,
  topRight,
  bottomLeft,
  bottomFront,
  bottomRight,
  done,
}

enum SessionStage { worldIntro, countdown, brushing, done }

const brushPhaseOrder = [
  BrushPhase.topLeft,
  BrushPhase.topFront,
  BrushPhase.topRight,
  BrushPhase.bottomLeft,
  BrushPhase.bottomFront,
  BrushPhase.bottomRight,
];

// Attack style variations
enum AttackStyle { chargeSlash, uppercut, spinAttack, energyBeam, powerSlam }

// Shape variants for visual damage popups (replaces text)
enum ImpactShapeType {
  fourPointStar,
  sixPointStar,
  speedLines,
  circleBurst,
  lightningBolt,
  goldStarburst,    // CRITICAL hit — larger with concentric rings
  flameCombo,       // combo counter — flame shape with number
  explosionBurst,   // FINISH — huge yellow explosion
  shatteredStar,    // K.O. — star breaking apart with mini stars
  rewardStar,       // micro-reward — spinning gold star
  rewardBolt,       // micro-reward — lightning bolt with glow
  rewardShield,     // micro-reward — shield with shimmer
}

class _DamagePopup {
  ImpactShapeType shapeType;
  int comboNumber; // only used for flameCombo
  double x, y, opacity, offsetY, rotation, scale;
  Color color;
  _DamagePopup({
    required this.shapeType,
    required this.x,
    required this.y,
    required this.color,
    required this.opacity,
    required this.offsetY,
    this.rotation = 0,
    this.scale = 1.0,
    this.comboNumber = 0,
  });
}

class _Particle {
  double x, y, vx, vy, size, opacity, life;
  Color color;
  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    this.opacity = 1.0,
    this.life = 1.0,
  });
}

class _HitSpark {
  double x, y, vx, vy, life, size;
  Color color;
  _HitSpark({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    this.life = 1.0,
    this.size = 3.0,
  });
}

// Floating star animation
class _FloatingStar {
  double x, y, targetX, targetY, progress, size;
  _FloatingStar({
    required this.x,
    required this.y,
    required this.targetX,
    required this.targetY,
    required this.progress,
    required this.size,
  });
}

// Debris chunk for monster death explosion
class _MonsterDebris {
  double x, y, vx, vy, rotation, rotationSpeed, size, life;
  Color color;
  _MonsterDebris({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.rotation,
    required this.rotationSpeed,
    required this.size,
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
    'Captain',
    'Lord',
    'Evil',
    'Dr.',
    'King',
    'Mega',
    'Super',
    'Tiny',
    'Big',
    'Dark',
    'Slimy',
    'Smelly',
    'Grumpy',
    'Fuzzy',
  ];
  static const _lastNames = [
    'Plaque',
    'Cavity',
    'Gumrot',
    'Slime',
    'Tartar',
    'Decay',
    'Mold',
    'Stinky',
    'Goop',
    'Fuzz',
    'Rot',
    'Crud',
    'Blob',
  ];
  static const _tintColors = [
    Color(0xFFFF4081),
    Color(0xFF7C4DFF),
    Color(0xFF00BCD4),
    Color(0xFFFF6E40),
    Color(0xFF69F0AE),
    Color(0xFFFFD54F),
    Color(0xFFE040FB),
    Color(0xFF40C4FF),
    Color(0xFFFF6D00),
  ];

  factory _MonsterPersonality.random(Random rng) {
    return _MonsterPersonality(
      bobSpeed: 0.6 + rng.nextDouble() * 0.9,
      bobAmount: 2.0 + rng.nextDouble() * 8.0,
      wobbleAmount: 0.02 + rng.nextDouble() * 0.05,
      sizeMultiplier: 0.9 + rng.nextDouble() * 0.2,
      tintColor: _tintColors[rng.nextInt(_tintColors.length)],
      tintStrength: 0.05 + rng.nextDouble() * 0.2,
      name:
          '${_firstNames[rng.nextInt(_firstNames.length)]} ${_lastNames[rng.nextInt(_lastNames.length)]}',
      entranceStyle: rng.nextInt(4),
    );
  }

}

class _MonsterSlot {
  final int imageIndex;
  final String? customImagePath; // unique trophy monster image
  final _MonsterPersonality personality;
  double health;
  bool alive;
  double hitRecoil;
  double wobblePhase;
  bool isDefeating;
  double defeatProgress;
  final List<_MonsterDebris> debris;
  _MonsterSlot({
    required this.imageIndex,
    this.customImagePath,
    required this.health,
    required this.alive,
    required this.wobblePhase,
    required this.personality,
  }) : hitRecoil = 0.0,
       isDefeating = false,
       defeatProgress = 0.0,
       debris = [];

  /// Resolved image path — prefers unique trophy image, falls back to base.
  String get resolvedImagePath =>
      customImagePath ?? _BrushingScreenState._monsterImages[imageIndex];
}

class _BrushingScreenState extends State<BrushingScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _audio = AudioService();
  final _heroService = HeroService();
  final _worldService = WorldService();
  final _cameraService = CameraService();
  final _weaponService = WeaponService();
  final _trophyService = TrophyService();
  TrophyMonster? _currentTrophyTarget;

  HeroCharacter _hero = HeroService.allHeroes[0];
  int _evolutionStage = 1;
  WorldData _world = WorldService.allWorlds[0];
  DailyModifier _dailyModifier = const DailyModifier(
    type: DailyModifierType.none,
    title: 'NORMAL MISSION',
    description: 'Steady progress day.',
    icon: Icons.public,
    color: Color(0xFFB388FF),
  );
  WeaponItem _weapon = WeaponService.allWeapons[0];

  BrushPhase _phase = BrushPhase.countdown;
  int _countdownValue = 3;
  int _phaseSecondsLeft = 20;
  int _phaseDuration = 20;
  Timer? _timer;
  Timer? _baseAttackTimer;
  bool _isPaused = false;
  bool _isQuitting = false;
  bool _showGoText = false;
  bool _phaseTransitioning = false;

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
  int _hitStopFrames = 0; // Tier 1: freeze frame on hit
  double _ghostHealth = 1.0; // Tier 1: ghost health bar drain
  int _comboCount = 0; // Tier 2: combo counter
  int _lastComboTime = 0; // Tier 2: combo window tracking
  double _monsterBlinkTimer = 0.0; // Tier 2: eye blink timer
  bool _monsterBlinking = false; // Tier 2: eye blink state
  AttackStyle get _currentAttackStyle =>
      AttackStyle.values[_attackStyleIndex % AttackStyle.values.length];

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
  // _showZoneBanner removed (visual banner removed in UX overhaul)
  bool _heroLunging = false; // hero attack lunge animation
  int _monstersDefeated = 0; // monsters killed by damage during this session
  Timer? _stallTimer; // mercy timer when camera works but no motion detected

  // Mouth guide overlay
  bool _showMouthGuideOverlay = false;
  late AnimationController _mouthGuideGlowController;
  late AnimationController _hitLottieController;
  bool _showHitEffect = false;
  bool _showDefeatExplosion = false; // Tier 2: Lottie defeat explosion
  late AnimationController _defeatLottieController;
  bool _showSparkleStars = false; // Tier 2: Lottie sparkle stars on defeat
  late AnimationController _sparkleLottieController;

  // Entrance dust cloud
  bool _showEntranceDust = false; // Tier 2: dust cloud on monster landing
  late AnimationController _dustLottieController;

  Timer? _microRewardTimer;
  Timer? _musicHealthTimer;
  bool _musicWasPlaying = false; // track music state for app lifecycle restore
  bool _showCameraPrompt = false; // first-brush camera prompt
  bool _showWorldIntro = true;
  Timer? _worldIntroTimer;
  SessionStage _sessionStage = SessionStage.worldIntro;
  static const _checkpointTsKey = 'session_checkpoint_ts';
  static const _checkpointPhaseKey = 'session_checkpoint_phase';
  static const _checkpointSecondsKey = 'session_checkpoint_seconds';
  static const _checkpointWorldKey = 'session_checkpoint_world';

  late final String _sessionId;

  // Tier 3: Fragment shaders
  ui.FragmentProgram? _dissolveProgram;
  ui.FragmentProgram? _shockwaveProgram;
  // Tier 3: Slow-motion on finisher kill
  bool _slowMotion = false;
  int _slowMotionFrame = 0;

  // Tier 3: Shockwave overlay
  double _shockwaveProgress = -1.0; // -1 = inactive
  late AnimationController _shockwaveController;

  // Tier 3: Weapon trail
  final List<Offset> _weaponTrailPoints = [];

  // Phase names removed (mouth guide visual is sufficient)

  static const _phaseToMouthQuadrant = {
    BrushPhase.topLeft: MouthQuadrant.topLeft,
    BrushPhase.topFront: MouthQuadrant.topFront,
    BrushPhase.topRight: MouthQuadrant.topRight,
    BrushPhase.bottomLeft: MouthQuadrant.bottomLeft,
    BrushPhase.bottomFront: MouthQuadrant.bottomFront,
    BrushPhase.bottomRight: MouthQuadrant.bottomRight,
  };

  static const _phaseVoiceFiles = {
    BrushPhase.topLeft: 'voice_top_left.mp3',
    BrushPhase.topFront: 'voice_top_front.mp3',
    BrushPhase.topRight: 'voice_top_right.mp3',
    BrushPhase.bottomLeft: 'voice_bottom_left.mp3',
    BrushPhase.bottomFront: 'voice_bottom_front.mp3',
    BrushPhase.bottomRight: 'voice_bottom_right.mp3',
  };

  static const _monsterImages = [
    'assets/images/monster_purple.png',
    'assets/images/monster_green.png',
    'assets/images/monster_orange.png',
    'assets/images/monster_red.png',
  ];

  // Impact shape variants for damage popups (visual only — no text)
  static const _impactShapes = [
    ImpactShapeType.fourPointStar,
    ImpactShapeType.sixPointStar,
    ImpactShapeType.speedLines,
    ImpactShapeType.circleBurst,
    ImpactShapeType.lightningBolt,
  ];

  // Micro-reward shapes (visual only — no text)
  static const _microRewardShapes = [
    ImpactShapeType.rewardStar,
    ImpactShapeType.rewardBolt,
    ImpactShapeType.rewardShield,
  ];
  bool _playedEncouragement = false;
  bool _playedMidEncouragement = false;
  bool _playedAlmostThere = false;

  // Encouragement arcs: each arc is a 3-beat connected micro-story
  // [beat1 = energizing @80%, beat2 = supportive @50%, beat3 = almost-there @20%]
  static const _encouragementArcs = [
    ['voice_arc1_beat1.mp3', 'voice_arc1_beat2.mp3', 'voice_arc1_beat3.mp3'],
    ['voice_arc2_beat1.mp3', 'voice_arc2_beat2.mp3', 'voice_arc2_beat3.mp3'],
    ['voice_arc3_beat1.mp3', 'voice_arc3_beat2.mp3', 'voice_arc3_beat3.mp3'],
    ['voice_arc4_beat1.mp3', 'voice_arc4_beat2.mp3', 'voice_arc4_beat3.mp3'],
    ['voice_arc5_beat1.mp3', 'voice_arc5_beat2.mp3', 'voice_arc5_beat3.mp3'],
    ['voice_arc6_beat1.mp3', 'voice_arc6_beat2.mp3', 'voice_arc6_beat3.mp3'],
    ['voice_arc7_beat1.mp3', 'voice_arc7_beat2.mp3', 'voice_arc7_beat3.mp3'],
    ['voice_arc8_beat1.mp3', 'voice_arc8_beat2.mp3', 'voice_arc8_beat3.mp3'],
    ['voice_arc9_beat1.mp3', 'voice_arc9_beat2.mp3', 'voice_arc9_beat3.mp3'],
    ['voice_arc10_beat1.mp3', 'voice_arc10_beat2.mp3', 'voice_arc10_beat3.mp3'],
  ];
  int _currentArcIndex = -1;
  int _lastArcIndex = -1;
  // Shuffled arc order for variety across a full session
  late List<int> _arcOrder;
  int _arcOrderPosition = 0;
  // Lifetime brush count — used for encouragement skip probability
  int _totalBrushes = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    WakelockPlus.enable();
    // Briefly show edge-to-edge, then switch to immersive after 1.5s
    // so Android's "Viewing full screen" toast auto-dismisses before battle.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
    });

    // Shuffle arc order so encouragements don't repeat in the same sequence
    _arcOrder = List.generate(_encouragementArcs.length, (i) => i);
    _arcOrder.shuffle(_random);
    _arcOrderPosition = 0;

    // Load lifetime brush count for encouragement skip probability
    SharedPreferences.getInstance().then((prefs) {
      _totalBrushes = prefs.getInt('total_brushes') ?? 0;
    });

    // Init single monster
    _monster = _createMonster();

    _attackSequenceController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _phaseTransitionController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _monsterEntranceController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _flashController = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _screenShakeController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _monsterBreathController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 50),
      vsync: this,
    )..repeat();
    _particleController.addListener(_updateParticlesAndSparks);
    _timerPulseController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);
    _heroIdleController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _mouthGuideGlowController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    )..repeat(reverse: true);

    _hitLottieController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (!mounted) return;
        setState(() => _showHitEffect = false);
      }
    });

    _defeatLottieController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (!mounted) return;
        setState(() => _showDefeatExplosion = false);
      }
    });

    _sparkleLottieController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (!mounted) return;
        setState(() => _showSparkleStars = false);
      }
    });

    _dustLottieController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (!mounted) return;
        setState(() => _showEntranceDust = false);
      }
    });

    _shockwaveController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _shockwaveProgress = -1.0;
      }
    });
    _shockwaveController.addListener(() {
      _shockwaveProgress = _shockwaveController.value;
    });

    _loadShaders();
    _initParticles();
    _prepareSession();
    _initCamera();

    _damageCleanupTimer = Timer.periodic(
      const Duration(milliseconds: 40),
      (_) {
        if (!mounted) return;
        _cleanupEffects();
      },
    );
    _starCleanupTimer = Timer.periodic(
      const Duration(milliseconds: 30),
      (_) {
        if (!mounted) return;
        _updateFloatingStars();
      },
    );
  }

  Future<void> _loadShaders() async {
    try {
      _dissolveProgram = await ui.FragmentProgram.fromAsset(
        'assets/shaders/dissolve.frag',
      );
      _shockwaveProgram = await ui.FragmentProgram.fromAsset(
        'assets/shaders/shockwave.frag',
      );
      if (mounted) setState(() {});
    } on Exception catch (e) {
      debugPrint('Shader load failed (non-fatal): $e');
    }
  }

  _MonsterSlot _createMonster() {
    final imageIndex = _random.nextInt(_monsterImages.length);
    return _MonsterSlot(
      imageIndex: imageIndex,
      customImagePath: _currentTrophyTarget?.imagePath,
      health: 1.0,
      alive: true,
      wobblePhase: _random.nextDouble() * 2 * pi,
      personality: _MonsterPersonality.random(_random),
    );
  }

  _MonsterSlot _createWorldMonster() {
    return _MonsterSlot(
      imageIndex:
          _world.monsterIndices[_random.nextInt(_world.monsterIndices.length)],
      health: 1.0,
      alive: true,
      wobblePhase: _random.nextDouble() * 2 * pi,
      personality: _MonsterPersonality.random(_random),
    );
  }

  void _initParticles() {
    _particles.clear();
    for (int i = 0; i < 20; i++) {
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
    // Hit stop: skip updates during freeze frames for impactful hits
    if (_hitStopFrames > 0) {
      _hitStopFrames--;
      return;
    }
    // Slow-motion: skip every other frame for cinematic finisher
    if (_slowMotion) {
      _slowMotionFrame++;
      if (_slowMotionFrame.isEven) return;
    }
    for (int i = 0; i < _particles.length; i++) {
      final p = _particles[i];
      p.x += p.vx;
      p.y += p.vy;
      p.life -= 0.006;
      p.opacity = p.life.clamp(0, 0.7);
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

    // Ghost health bar: smoothly drain toward actual health
    if (_ghostHealth > _monster.health) {
      _ghostHealth -= 0.008; // Slow drain
      if (_ghostHealth < _monster.health) _ghostHealth = _monster.health;
    }

    // Monster eye blink timer
    _monsterBlinkTimer += 0.05;
    if (!_monsterBlinking && _monsterBlinkTimer > 3.0 + (_monster.wobblePhase * 2)) {
      _monsterBlinking = true;
      _monsterBlinkTimer = 0;
    }
    if (_monsterBlinking && _monsterBlinkTimer > 0.15) {
      _monsterBlinking = false;
      _monsterBlinkTimer = 0;
    }

    // Combo decay: reset if no hits for 2 seconds
    if (_comboCount > 0) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastComboTime > 2000) {
        _comboCount = 0;
      }
    }
  }

  void _updateFloatingStars() {
    if (!mounted || _floatingStars.isEmpty) return;
    setState(() {
      for (final star in _floatingStars) {
        star.progress += 0.025;
        final t = star.progress.clamp(0.0, 1.0);
        final curve = Curves.easeInOut.transform(t);
        star.x = star.x + (star.targetX - star.x) * 0.05;
        star.y =
            star.y +
            (star.targetY - star.y) * 0.05 +
            sin(star.progress * 8) * 0.5;
        star.size = 20 * (1.0 - curve * 0.5);
      }
      _floatingStars.removeWhere((s) => s.progress >= 1.0);
    });
  }

  Future<void> _initCamera() async {
    final prefs = await SharedPreferences.getInstance();
    final cameraEnabled = prefs.getBool('camera_enabled') ?? false;
    if (!cameraEnabled) return;
    final ready = await _cameraService.initialize();
    if (mounted) {
      setState(() => _cameraReady = ready);
    }
  }

  void _startMotionDetection() {
    if (!_cameraReady) return;
    _cameraService.startMotionDetection((intensity) {
      try {
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
      } on Exception catch (e) {
        debugPrint('Motion callback error: $e');
      }
    });
  }

  /// Map motion intensity to attack cooldown in milliseconds.
  /// Higher brushing intensity = shorter cooldown = faster attacks.
  int _intensityToCooldown(double intensity) {
    if (intensity >= 0.4) return 300; // vigorous brushing
    if (intensity >= 0.15) return 500; // normal brushing
    return 800; // gentle motion
  }

  /// Mercy timer: if camera is active but no motion detected for 10 seconds,
  /// fire a single attack to prevent total stall (e.g. phone placed badly).
  void _resetStallTimer() {
    _stallTimer?.cancel();
    if (!_cameraReady) return;
    _stallTimer = Timer(const Duration(seconds: 10), () {
      if (mounted &&
          !_isPaused &&
          _phase != BrushPhase.done &&
          _phase != BrushPhase.countdown) {
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
    final evolutionStage = await _heroService.getEvolutionStage(hero.id);
    final trophyTarget = await _trophyService.getNextUncaptured(world.id);
    final prefs = await SharedPreferences.getInstance();
    final duration = prefs.getInt('phase_duration') ?? 20;
    if (mounted) {
      setState(() {
        _hero = hero;
        _evolutionStage = evolutionStage;
        _world = world;
        _dailyModifier = _worldService.getDailyModifier();
        _weapon = weapon;
        _phaseDuration = duration;
        _currentTrophyTarget = trophyTarget;
        _monster = _createMonster();
        _initParticles();
      });
    }
  }

  Future<void> _prepareSession() async {
    await _loadHeroAndWorld();
    final restored = await _tryRestoreCheckpoint();
    if (!restored) {
      unawaited(_startWorldIntro());
    }
  }

  Future<bool> _tryRestoreCheckpoint() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_checkpointTsKey);
    final phaseName = prefs.getString(_checkpointPhaseKey);
    final secondsLeft = prefs.getInt(_checkpointSecondsKey);
    final worldId = prefs.getString(_checkpointWorldKey);
    if (ts == null ||
        phaseName == null ||
        secondsLeft == null ||
        worldId == null) {
      return false;
    }
    final age = DateTime.now().millisecondsSinceEpoch - ts;
    if (age > const Duration(minutes: 3).inMilliseconds) {
      await _clearCheckpoint();
      return false;
    }
    if (worldId != _world.id) {
      await _clearCheckpoint();
      return false;
    }

    final restoredPhase = BrushPhase.values
        .where((p) => p.name == phaseName)
        .toList();
    if (restoredPhase.isEmpty ||
        restoredPhase.first == BrushPhase.done ||
        restoredPhase.first == BrushPhase.countdown) {
      await _clearCheckpoint();
      return false;
    }

    setState(() {
      _showWorldIntro = false;
      _sessionStage = SessionStage.brushing;
      _phase = restoredPhase.first;
      _phaseSecondsLeft = secondsLeft.clamp(1, _phaseDuration);
    });
    _startBrushing(resumeFromCheckpoint: true);
    return true;
  }

  Future<void> _saveCheckpoint() async {
    if (_sessionStage != SessionStage.brushing) return;
    if (_phase == BrushPhase.countdown || _phase == BrushPhase.done) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_checkpointTsKey, DateTime.now().millisecondsSinceEpoch);
    await prefs.setString(_checkpointPhaseKey, _phase.name);
    await prefs.setInt(_checkpointSecondsKey, _phaseSecondsLeft);
    await prefs.setString(_checkpointWorldKey, _world.id);
  }

  Future<void> _clearCheckpoint() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_checkpointTsKey);
    await prefs.remove(_checkpointPhaseKey);
    await prefs.remove(_checkpointSecondsKey);
    await prefs.remove(_checkpointWorldKey);
  }

  Future<void> _startWorldIntro() async {
    // Always show world intro — it's the mission briefing moment.
    // Kid can tap to skip; auto-advances after 10 seconds.
    _worldIntroTimer?.cancel();
    setState(() {
      _showWorldIntro = true;
      _sessionStage = SessionStage.worldIntro;
    });
    _playWorldMissionBriefing();

    // Auto-advance after 10 seconds; tap anywhere skips immediately
    _worldIntroTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _showWorldIntro) {
        _dismissWorldIntro();
      }
    });
  }

  Future<void> _dismissWorldIntro() async {
    _worldIntroTimer?.cancel();

    if (!mounted) return;
    setState(() {
      _showWorldIntro = false;
    });

    // Check if this is the first ever brush and camera prompt hasn't been shown.
    // Skip the prompt entirely if camera was explicitly disabled in settings.
    final prefs = await SharedPreferences.getInstance();
    final totalBrushes = prefs.getInt('total_brushes') ?? 0;
    final cameraPromptShown = prefs.getBool('camera_prompt_shown') ?? false;
    final cameraAlreadyEnabled = prefs.getBool('camera_enabled') ?? false;
    final cameraConfigured = prefs.getBool('camera_mode_configured') ?? false;

    // Show camera prompt only on first brush, if not already shown,
    // camera not already enabled, and user hasn't explicitly configured
    // camera off in settings.
    final shouldShowPrompt = totalBrushes == 0 &&
        !cameraPromptShown &&
        !cameraAlreadyEnabled &&
        !cameraConfigured;

    if (shouldShowPrompt) {
      if (!mounted) return;
      setState(() {
        _showCameraPrompt = true;
        _sessionStage = SessionStage.countdown;
      });
      unawaited(_audio.playVoice('voice_camera_prompt.mp3'));
      return; // Wait for user to respond to camera prompt
    }

    setState(() => _sessionStage = SessionStage.countdown);
    _startCountdown();
  }

  Future<void> _onCameraPromptAccept() async {
    unawaited(_audio.stopVoice());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('camera_prompt_shown', true);
    await prefs.setBool('camera_enabled', true);
    if (!mounted) return;
    setState(() => _showCameraPrompt = false);
    // Initialize camera now that it's been enabled
    final ready = await _cameraService.initialize();
    if (mounted) setState(() => _cameraReady = ready);
    _startCountdown();
  }

  Future<void> _onCameraPromptSkip() async {
    unawaited(_audio.stopVoice());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('camera_prompt_shown', true);
    if (!mounted) return;
    setState(() => _showCameraPrompt = false);
    _startCountdown();
  }

  Future<void> _exitWorldIntro() async {
    _worldIntroTimer?.cancel();

    // On the very first brush, redirect the kid back to the fight
    // instead of silently exiting — they may not realize what the X does.
    final prefs = await SharedPreferences.getInstance();
    final totalBrushes = prefs.getInt('total_brushes') ?? 0;
    if (totalBrushes == 0) {
      unawaited(_audio.stopVoice());
      unawaited(_audio.playVoice('voice_lets_fight.mp3', clearQueue: true, interrupt: true));
      // Dismiss the intro and start the session instead of popping
      unawaited(_dismissWorldIntro());
      return;
    }

    unawaited(_audio.stopVoice());
    unawaited(_audio.stopMusic());
    if (!mounted) return;
    setState(() => _isQuitting = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _playWorldMissionBriefing() {
    _audio.playVoice('voice_world_${_world.id}.mp3', clearQueue: true, interrupt: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // App backgrounded — stop all audio
      _musicWasPlaying = _audio.isMusicPlaying;
      _audio.stopAllAudio();
      // Pause the brushing session so the timer doesn't run in the background
      if (!_isPaused && _sessionStage == SessionStage.brushing && !_isQuitting) {
        _togglePause();
      }
    } else if (state == AppLifecycleState.resumed) {
      // App foregrounded — resume music if it was playing before
      // Don't auto-resume: the child will tap RESUME themselves
      if (_musicWasPlaying && !_isPaused && _sessionStage == SessionStage.brushing) {
        _audio.playMusic('battle_music_loop.mp3');
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _timer?.cancel();
    _baseAttackTimer?.cancel();
    _stallTimer?.cancel();
    _microRewardTimer?.cancel();
    _musicHealthTimer?.cancel();
    _worldIntroTimer?.cancel();
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
    _hitLottieController.dispose();
    _defeatLottieController.dispose();
    _sparkleLottieController.dispose();
    _dustLottieController.dispose();
    _shockwaveController.dispose();
    _audio.stopVoice();
    _audio.stopMusic();
    super.dispose();
  }

  // ==================== COUNTDOWN ====================

  void _startCountdown() {
    setState(() {
      _phase = BrushPhase.countdown;
      _sessionStage = SessionStage.countdown;
    });
    _audio.playVoice('voice_countdown.mp3', clearQueue: true, interrupt: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_countdownValue > 1) {
        setState(() => _countdownValue--);
        _audio.playSfx('countdown_beep.mp3');
      } else {
        timer.cancel();
        setState(() {
          _countdownValue = 0;
          _showGoText = true;
        });
        HapticFeedback.heavyImpact();
        _audio.playSfx('countdown_beep.mp3');
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) _startBrushing();
        });
      }
    });
  }

  // ==================== BRUSHING ====================

  void _startBrushing({bool resumeFromCheckpoint = false}) {
    // Ensure we always have a valid arc (covers checkpoint resume)
    if (_currentArcIndex < 0) _pickNextArc();
    if (!resumeFromCheckpoint) {
      _totalHits = 0;
      _attackStyleIndex = 0;
    }
    _sessionStage = SessionStage.brushing;

    // Start battle music (2-min pre-looped file for reliable Android playback)
    _audio.playMusic('battle_music_loop.mp3');

    // Periodic music health check — recovers if player gets stuck
    _musicHealthTimer?.cancel();
    _musicHealthTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        if (!mounted) return;
        _audio.ensureMusicPlaying();
      },
    );

    _scheduleNextMicroReward();

    if (!resumeFromCheckpoint) {
      _pickNextArc();
      _switchToPhase(BrushPhase.topLeft);
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_isPaused) return;
      setState(() {
        _phaseSecondsLeft--;
        if (_phaseSecondsLeft < 0) _phaseSecondsLeft = 0;
      });
      _saveCheckpoint();

      final energizeAt = (_phaseDuration * 0.80).round();
      final supportAt = (_phaseDuration * 0.50).round();
      final almostAt = (_phaseDuration * 0.20).round();
      if (_phaseSecondsLeft == energizeAt && !_playedEncouragement) {
        _playedEncouragement = true;
        if (!_shouldSkipEncouragement()) {
          _audio.playVoice(_encouragementArcs[_currentArcIndex][0]);
        }
      }
      if (_phaseSecondsLeft == supportAt && !_playedMidEncouragement) {
        _playedMidEncouragement = true;
        if (!_shouldSkipEncouragement()) {
          _audio.playVoice(_encouragementArcs[_currentArcIndex][1]);
        }
      }
      if (_phaseSecondsLeft == almostAt && !_playedAlmostThere) {
        _playedAlmostThere = true;
        if (!_shouldSkipEncouragement()) {
          _audio.playVoice(_encouragementArcs[_currentArcIndex][2]);
        }
      }

      if (_phaseSecondsLeft <= 0 && !_phaseTransitioning) {
        _phaseTransitioning = true;
        _playedEncouragement = false;
        _playedMidEncouragement = false;
        _playedAlmostThere = false;
        _pickNextArc();
        final currentIndex = brushPhaseOrder.indexOf(_phase);
        if (currentIndex < brushPhaseOrder.length - 1) {
          _triggerFinisher(() {
            _monstersDefeated++;
            _startMonsterDeath(_monster);
            _playDefeatAnimation(() {
              final nextIndex = currentIndex + 1;
              _monster = _createWorldMonster();
              _switchToPhase(brushPhaseOrder[nextIndex]);
              _playEntranceAnimation();
            });
          });
        } else {
          _triggerFinisher(() {
            _monstersDefeated++;
            _startMonsterDeath(_monster);
            _playDefeatAnimation(() {
              timer.cancel();
              _finishBrushing();
            });
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
    _baseAttackTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (mounted &&
          !_isPaused &&
          _phase != BrushPhase.done &&
          _phase != BrushPhase.countdown) {
        _triggerAttack();
      }
    });
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
      monster.debris.add(
        _MonsterDebris(
          x: 0,
          y: 0,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed - 3,
          rotation: _random.nextDouble() * 2 * pi,
          rotationSpeed: (_random.nextDouble() - 0.5) * 0.3,
          size: 6 + _random.nextDouble() * 12,
          color: _world.themeColor,
        ),
      );
    }
  }

  void _triggerFinisher(VoidCallback onComplete) {
    _baseAttackTimer?.cancel();
    _stallTimer?.cancel();
    setState(() {
      _isFinisher = true;
      _slowMotion = true; // Tier 3: cinematic slow-motion
    });
    _attackStyleIndex = 4;
    _attackSequenceController.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) _screenShakeController.forward(from: 0);
    });
    _flashController.forward(from: 0).then((_) { if (mounted) _flashController.reverse(); });
    HapticFeedback.heavyImpact();
    _audio.playSfx('zap.mp3');

    // Tier 3: Shockwave on finisher (staggered for visual impact)
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _shockwaveController.forward(from: 0);
    });

    for (int i = 0; i < 18; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed = 4.0 + _random.nextDouble() * 8;
      _hitSparks.add(
        _HitSpark(
          x: 0,
          y: 0,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed,
          color: _weapon.primaryColor,
          life: 1.0,
          size: 2 + _random.nextDouble() * 5,
        ),
      );
    }

    setState(() {
      _damagePopups.add(
        _DamagePopup(
          shapeType: ImpactShapeType.explosionBurst,
          x: 0.5,
          y: 0.15,
          color: Colors.yellowAccent,
          opacity: 1.0,
          offsetY: 0,
          rotation: 0,
          scale: 2.0,
        ),
      );
      while (_damagePopups.length > 15) {
        _damagePopups.removeAt(0);
      }
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _isFinisher = false;
          _slowMotion = false;
        });
        onComplete();
      }
    });
  }

  void _playDefeatAnimation(VoidCallback onComplete) {
    _baseAttackTimer?.cancel();
    _audio.playSfx('monster_defeat.mp3');
    HapticFeedback.heavyImpact();
    _flashController.forward(from: 0).then((_) { if (mounted) _flashController.reverse(); });
    _spawnDefeatSparks();

    // Tier 2: Lottie defeat explosion + sparkle stars
    setState(() {
      _showDefeatExplosion = true;
      _showSparkleStars = true;
    });
    _defeatLottieController.forward(from: 0);
    _sparkleLottieController.forward(from: 0);

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) onComplete();
    });
  }

  void _spawnDefeatSparks() {
    for (int i = 0; i < 12; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed = 3.0 + _random.nextDouble() * 6;
      _hitSparks.add(
        _HitSpark(
          x: 0,
          y: 0,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed,
          color: _world.themeColor,
          life: 1.0,
          size: 2.0 + _random.nextDouble() * 4,
        ),
      );
    }
  }

  void _playEntranceAnimation() {
    setState(() {
      _monsterEntering = true;
      _ghostHealth = 1.0; // Reset ghost health for new monster
    });
    _monsterEntranceController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() {
          _monsterEntering = false;
          // Tier 2: dust cloud on landing
          _showEntranceDust = true;
        });
        _dustLottieController.forward(from: 0);
        HapticFeedback.mediumImpact();
        if (_cameraReady) {
          _resetStallTimer();
        } else {
          _startBaseAttackTimer();
        }
      }
    });
  }

  void _switchToPhase(BrushPhase newPhase) {
    _phaseTransitioning = false;
    setState(() {
      _phase = newPhase;
      _phaseSecondsLeft = _phaseDuration;
      _showMouthGuideOverlay = true;
    });
    _phaseTransitionController.forward(from: 0);
    _audio.playSfx('whoosh.mp3');
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _phaseVoiceFiles.containsKey(newPhase)) {
        _audio.playVoice(_phaseVoiceFiles[newPhase]!, clearQueue: true, interrupt: true);
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

    // Hit stop: freeze 3 frames on impact for meaty feel
    _hitStopFrames = 3;

    // Combo tracking
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastComboTime < 2000) {
      _comboCount++;
    } else {
      _comboCount = 1;
    }
    _lastComboTime = now;

    setState(() {
      _totalHits++;
      _attackStyleIndex = _totalHits % AttackStyle.values.length;
      if (_monster.alive) {
        _monster.hitRecoil = 1.0;
        const baseDamage = 0.08;
        _monster.health -= baseDamage * _dailyModifier.damageMultiplier;
        if (_monster.health <= 0) {
          _monster.health = 0;
        }
      }
    });

    _attackSequenceController.forward(from: 0);
    setState(() => _showHitEffect = true);
    _hitLottieController.forward(from: 0);
    _screenShakeController.forward(from: 0);
    _flashController.forward(from: 0).then((_) { if (mounted) _flashController.reverse(); });

    // Hero lunge animation
    setState(() => _heroLunging = true);
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _heroLunging = false);
    });

    _spawnDamagePopup();
    _spawnHitSparks();

    // Tier 3: Shockwave on critical hits
    if (_totalHits > 0 && _totalHits % 5 == 0) {
      _shockwaveController.forward(from: 0);
    }

    // Tier 3: Weapon trail point
    _weaponTrailPoints.add(Offset(0, _heroLunging ? -35 : 0));
    if (_weaponTrailPoints.length > 8) _weaponTrailPoints.removeAt(0);

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
    setState(() {
      _damagePopups.add(
        _DamagePopup(
          shapeType: ImpactShapeType.shatteredStar,
          x: 0.5,
          y: 0.12,
          color: Colors.yellowAccent,
          opacity: 1.0,
          offsetY: 0,
          rotation: 0,
          scale: 2.2,
        ),
      );
    });

    _startMonsterDeath(_monster);
    _audio.playSfx('monster_defeat.mp3');
    HapticFeedback.heavyImpact();
    _flashController.forward(from: 0).then((_) { if (mounted) _flashController.reverse(); });
    _spawnDefeatSparks();

    // Celebration voice after early kill — queued (not interrupting) with a small delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _audio.playVoice('voice_awesome.mp3');
      }
    });

    // Tier 3: Shockwave + slow-motion on K.O.
    _shockwaveController.forward(from: 0);
    setState(() => _slowMotion = true);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _slowMotion = false);
    });

    // Spawn a new monster in the same phase after death animation
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted ||
          _phase == BrushPhase.done ||
          _phase == BrushPhase.countdown) {
        return;
      }
      setState(() {
        _monster = _createWorldMonster();
      });
      _playEntranceAnimation();
    });
  }

  void _scheduleNextMicroReward() {
    _microRewardTimer?.cancel();
    final delaySecs = 8 + _random.nextInt(5); // 8-12s cadence
    _microRewardTimer = Timer(Duration(seconds: delaySecs), () {
      if (!mounted ||
          _isPaused ||
          _phase == BrushPhase.done ||
          _phase == BrushPhase.countdown) {
        _scheduleNextMicroReward();
        return;
      }
      _triggerMicroReward();
      _scheduleNextMicroReward();
    });
  }

  void _triggerMicroReward() {
    final shape = _microRewardShapes[_random.nextInt(_microRewardShapes.length)];
    setState(() {
      _damagePopups.add(
        _DamagePopup(
          shapeType: shape,
          x: 0.5,
          y: 0.1,
          color: const Color(0xFFFFD54F),
          opacity: 1.0,
          offsetY: 0,
          rotation: (_random.nextDouble() - 0.5) * 0.2,
          scale: 1.35,
        ),
      );
      while (_damagePopups.length > 15) {
        _damagePopups.removeAt(0);
      }
    });
    // Keep micro-reward as visual-only to avoid competing with guidance voices.
  }

  void _pickNextArc() {
    // Walk through a shuffled order of all arcs so every arc plays before
    // any repeats. When the pool is exhausted, reshuffle (avoiding the
    // last-played arc at the boundary).
    if (_arcOrderPosition >= _arcOrder.length) {
      _arcOrder.shuffle(_random);
      // If the first arc in the new shuffle is the same as the last played,
      // swap it with a random later position to avoid back-to-back repeat.
      if (_arcOrder.first == _lastArcIndex && _arcOrder.length > 1) {
        final swapIdx = 1 + _random.nextInt(_arcOrder.length - 1);
        final tmp = _arcOrder[0];
        _arcOrder[0] = _arcOrder[swapIdx];
        _arcOrder[swapIdx] = tmp;
      }
      _arcOrderPosition = 0;
    }
    final next = _arcOrder[_arcOrderPosition];
    _arcOrderPosition++;
    _lastArcIndex = next;
    _currentArcIndex = next;
  }

  /// For experienced brushers (10+ lifetime brushes), occasionally skip
  /// individual encouragement beats to let the music carry the energy.
  /// Returns true if the beat should be skipped.
  bool _shouldSkipEncouragement() {
    if (_totalBrushes < 10) return false;
    // 30% chance to skip any given beat after 10 brushes
    return _random.nextDouble() < 0.30;
  }

  void _spawnDamagePopup() {
    final isCritical = _totalHits > 0 && _totalHits % 5 == 0;
    final shape = isCritical
        ? ImpactShapeType.goldStarburst
        : _impactShapes[_random.nextInt(_impactShapes.length)];

    // Combo scaling: bigger shape the higher the combo
    final comboScale = _comboCount >= 8 ? 1.6 : (_comboCount >= 5 ? 1.4 : (_comboCount >= 3 ? 1.2 : 1.0));
    final baseScale = isCritical ? 1.8 : 1.3;

    setState(() {
      _damagePopups.add(
        _DamagePopup(
          shapeType: shape,
          x: 0.25 + _random.nextDouble() * 0.5,
          y: 0.1 + _random.nextDouble() * 0.3,
          color: isCritical ? const Color(0xFFFFD54F) : _weapon.primaryColor,
          opacity: 1.0,
          offsetY: 0,
          rotation: (_random.nextDouble() - 0.5) * 0.4,
          scale: baseScale * comboScale,
        ),
      );

      // Show combo counter at milestones (3, 5, 8, 10+) — flame shape with number
      if (_comboCount == 3 || _comboCount == 5 || _comboCount == 8 || (_comboCount >= 10 && _comboCount % 5 == 0)) {
        _damagePopups.add(
          _DamagePopup(
            shapeType: ImpactShapeType.flameCombo,
            comboNumber: _comboCount,
            x: 0.5,
            y: 0.05,
            color: const Color(0xFF69F0AE),
            opacity: 1.0,
            offsetY: 0,
            rotation: 0,
            scale: 1.5 + (_comboCount / 20).clamp(0.0, 0.8),
          ),
        );
      }
      while (_damagePopups.length > 15) {
        _damagePopups.removeAt(0);
      }
    });
  }

  void _spawnHitSparks() {
    for (int i = 0; i < 5; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed = 2.0 + _random.nextDouble() * 5;
      _hitSparks.add(
        _HitSpark(
          x: 0,
          y: 0,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed - 2,
          color: _weapon.primaryColor,
          life: 1.0,
          size: 1.5 + _random.nextDouble() * 3,
        ),
      );
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
      _microRewardTimer?.cancel();
      _musicHealthTimer?.cancel();
      // Audio cue: whoosh SFX signals the game is paused
      _audio.playSfx('whoosh.mp3');
      _audio.pauseMusic();
    } else {
      // Resume music before voice so ducking works correctly
      _audio.resumeMusic();
      // Restart music health check
      _musicHealthTimer?.cancel();
      _musicHealthTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) {
          if (!mounted) return;
          _audio.ensureMusicPlaying();
        },
      );
      // Audio cue: random encouraging voice on resume
      const resumeVoices = [
        'voice_lets_fight.mp3',
        'voice_keep_going.mp3',
        'voice_go_go_go.mp3',
      ];
      final resumeVoice = resumeVoices[Random().nextInt(resumeVoices.length)];
      _audio.playVoice(resumeVoice, clearQueue: true, interrupt: true);
      _monsterBreathController.repeat(reverse: true);
      _heroIdleController.repeat(reverse: true);
      if (_cameraReady) {
        _resetStallTimer();
      } else {
        _startBaseAttackTimer();
      }
      _scheduleNextMicroReward();
    }
  }

  void _quitBrushing() {
    _timer?.cancel();
    _baseAttackTimer?.cancel();
    _microRewardTimer?.cancel();
    _musicHealthTimer?.cancel();
    _audio.stopVoice();
    _audio.stopMusic();
    _clearCheckpoint();
    AnalyticsService().logBrushSessionAbandon(
      phase: _phase.name,
      secondsRemaining: _phaseSecondsLeft,
      totalHits: _totalHits,
    );
    if (!mounted) return;
    setState(() => _isQuitting = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _finishBrushing() {
    _baseAttackTimer?.cancel();
    _stallTimer?.cancel();
    _microRewardTimer?.cancel();
    _musicHealthTimer?.cancel();
    _stopMotionDetection();
    _audio.stopVoice();
    _audio.stopMusic();
    _clearCheckpoint();
    if (!mounted) return;
    setState(() {
      _phase = BrushPhase.done;
      _sessionStage = SessionStage.done;
      _isQuitting = true;
    });
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => VictoryScreen(
          totalHits: _totalHits,
          monstersDefeated: _monstersDefeated,
          sessionId: _sessionId,
          trophyTargetId: _currentTrophyTarget?.id,
        ),
        transitionsBuilder: (context, anim, secondaryAnimation, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  /// Returns the phase progress as 0.0 to 1.0 (0 = just started, 1 = phase ending)
  double _getPhaseProgress() {
    if (_phaseDuration <= 0) return 0.0;
    return (1.0 - _phaseSecondsLeft / _phaseDuration).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _isQuitting,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_showCameraPrompt) {
          _onCameraPromptSkip();
          return;
        }
        if (_showWorldIntro) {
          _exitWorldIntro();
          return;
        }
        _togglePause();
      },
      child: _showWorldIntro
          ? _buildWorldIntro()
          : _showCameraPrompt
          ? _buildCameraPrompt()
          : _sessionStage == SessionStage.countdown
          ? _buildCountdown()
          : _buildBrushing(),
    );
  }

  // ==================== CAMERA PROMPT UI ====================

  Widget _buildCameraPrompt() {
    // Play the camera pitch voice on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _showCameraPrompt) {
        _audio.playVoice('voice_camera_prompt.mp3', clearQueue: true);
      }
    });

    return Scaffold(
      body: _WorldBackground(
        world: _world,
        child: Stack(
          children: [
            // Subtle world image overlay for continuity
            Positioned.fill(
              child: Opacity(
                opacity: 0.15,
                child: Image.asset(_world.imagePath, fit: BoxFit.cover),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const Spacer(flex: 2),

                    // Hero with energy beam from camera
                    _CameraPowerUpVisual(
                      hero: _hero,
                      evolutionStage: _evolutionStage,
                      weapon: _weapon,
                      themeColor: _world.themeColor,
                    ),

                    const Spacer(flex: 1),

                    // POWER UP button (big, glowing, inviting)
                    GestureDetector(
                      onTap: _onCameraPromptAccept,
                      child: Container(
                        width: double.infinity,
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00E676), Color(0xFF00BFA5)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E676).withValues(alpha: 0.5),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bolt, color: Colors.white, size: 32),
                            SizedBox(width: 8),
                            Icon(Icons.videocam, color: Colors.white, size: 28),
                            SizedBox(width: 8),
                            Icon(Icons.bolt, color: Colors.white, size: 32),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // "Not now" option (subtle, non-pressuring)
                    GestureDetector(
                      onTap: _onCameraPromptSkip,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Not now',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Parent trust line
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          color: Colors.white.withValues(alpha: 0.5),
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Camera detects motion only — no pictures taken or stored.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 11,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== COUNTDOWN UI ====================

  Widget _buildCountdown() {
    final displayText = _showGoText
        ? 'GO!'
        : (_countdownValue > 0 ? '$_countdownValue' : '');
    final textColor = _showGoText ? const Color(0xFF69F0AE) : Colors.white;
    final fontSize = _showGoText ? 140.0 : 120.0;
    return Scaffold(
      body: SpaceBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Hero + weapon display during countdown
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: _hero.primaryColor.withValues(alpha: 0.4),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _hero.primaryColor, width: 3),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(17),
                      child: HeroService.buildHeroImage(
                        _hero.id,
                        stage: _evolutionStage,
                        weaponId: _weapon.id,
                        size: 130,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _hero.name,
                style: TextStyle(
                  color: _hero.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 24),
              // Countdown number / GO!
              Stack(
                alignment: Alignment.center,
                children: [
                  if (_showGoText)
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 200),
                      duration: const Duration(milliseconds: 400),
                      builder: (context, radius, _) => Container(
                        width: radius * 2,
                        height: radius * 2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF69F0AE).withValues(alpha: 0.4),
                              const Color(0xFF69F0AE).withValues(alpha: 0.0),
                            ],
                          ),
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
                      child: Text(
                        displayText,
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(
                              fontSize: fontSize,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                              shadows: [
                                Shadow(
                                  color:
                                      (_showGoText
                                              ? const Color(0xFF69F0AE)
                                              : const Color(0xFF00E5FF))
                                          .withValues(alpha: 0.8),
                                  blurRadius: 40,
                                ),
                              ],
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorldIntro() {
    return Scaffold(
      body: GestureDetector(
        onTap: _dismissWorldIntro,
        behavior: HitTestBehavior.opaque,
        child: _WorldBackground(
          world: _world,
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0.22,
                  child: Image.asset(_world.imagePath, fit: BoxFit.cover),
                ),
              ),
              // Back/close button — lets kid exit without starting a brush session
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8,
                child: IconButton(
                  onPressed: _exitWorldIntro,
                  iconSize: 32,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.4),
                    shape: const CircleBorder(),
                  ),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 1.0, end: 0.0),
                        duration: const Duration(seconds: 10),
                        builder: (context, value, child) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 156,
                                height: 156,
                                child: CircularProgressIndicator(
                                  value: value,
                                  strokeWidth: 3,
                                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                                  valueColor: AlwaysStoppedAnimation(
                                    _world.themeColor.withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                              child!,
                            ],
                          );
                        },
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: _world.themeColor, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: _world.themeColor.withValues(alpha: 0.55),
                                blurRadius: 28,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(_world.imagePath, fit: BoxFit.cover),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _world.name.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 3,
                              shadows: [
                                Shadow(
                                  color: _world.themeColor.withValues(alpha: 0.8),
                                  blurRadius: 18,
                                ),
                              ],
                            ),
                      ),
                      const SizedBox(height: 24),
                      _PulsingTapToFight(themeColor: _world.themeColor),
                    ],
                  ),
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
    const monsterSize = 160.0;
    const heroSize = 168.0;

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
                    painter: _WorldParticlePainter(
                      particles: _particles,
                      particleType: _world.particleType,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -24,
                left: -24,
                child: IgnorePointer(
                  child: Container(
                    width: 156,
                    height: 156,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _world.themeColor.withValues(alpha: 0.18),
                          blurRadius: 28,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Opacity(
                        opacity: 0.24,
                        child: Image.asset(_world.imagePath, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _buildMissionHud(),

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

                              const SizedBox(height: 4),

                              // Monster health bar
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 48,
                                ),
                                child: _buildMonsterHealthBar(),
                              ),

                              const SizedBox(height: 8),

                              // Attack effects zone (spacer)
                              const SizedBox(height: 12),

                              // HERO
                              _buildHero(heroSize),

                              const SizedBox(height: 8),

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

                          // Tier 3: Shockwave shader overlay
                          if (_shockwaveProgress >= 0 && _shockwaveProgram != null)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: AnimatedBuilder(
                                  animation: _shockwaveController,
                                  builder: (context, _) => CustomPaint(
                                    painter: _ShockwavePainter(
                                      program: _shockwaveProgram!,
                                      progress: _shockwaveController.value,
                                      color: _weapon.primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          // Tier 3: Weapon trail during attacks
                          if (_heroLunging && _weaponTrailPoints.length > 2)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: _WeaponTrailPainter(
                                    points: _weaponTrailPoints,
                                    color: _weapon.primaryColor,
                                    heroY: screenHeight * 0.6,
                                    centerX: screenWidth / 2,
                                  ),
                                ),
                              ),
                            ),

                          // Lottie hit effect
                          if (_showHitEffect)
                            Positioned(
                              top: 50,
                              left: 0,
                              right: 0,
                              child: IgnorePointer(
                                child: Center(
                                  child: Lottie.asset(
                                    'assets/animations/hit_pow.json',
                                    width: 200,
                                    height: 200,
                                    repeat: false,
                                    controller: _hitLottieController,
                                  ),
                                ),
                              ),
                            ),

                          // Tier 2: Lottie defeat explosion
                          if (_showDefeatExplosion)
                            Positioned(
                              top: 20,
                              left: 0,
                              right: 0,
                              child: IgnorePointer(
                                child: Center(
                                  child: Lottie.asset(
                                    'assets/animations/explosion.json',
                                    width: 280,
                                    height: 280,
                                    repeat: false,
                                    controller: _defeatLottieController,
                                  ),
                                ),
                              ),
                            ),

                          // Tier 2: Lottie sparkle stars on defeat
                          if (_showSparkleStars)
                            Positioned(
                              top: 40,
                              left: 0,
                              right: 0,
                              child: IgnorePointer(
                                child: Center(
                                  child: Lottie.asset(
                                    'assets/animations/sparkle_stars.json',
                                    width: 240,
                                    height: 240,
                                    repeat: false,
                                    controller: _sparkleLottieController,
                                  ),
                                ),
                              ),
                            ),

                          // Tier 2: Entrance dust cloud
                          if (_showEntranceDust)
                            Positioned(
                              top: 60,
                              left: 0,
                              right: 0,
                              child: IgnorePointer(
                                child: Center(
                                  child: Lottie.asset(
                                    'assets/animations/smoke_puff.json',
                                    width: 200,
                                    height: 200,
                                    repeat: false,
                                    controller: _dustLottieController,
                                  ),
                                ),
                              ),
                            ),

                          // Damage popups — visual impact shapes (no text)
                          ..._damagePopups.map(
                            (popup) => Positioned(
                              left: popup.x * screenWidth - 40,
                              top: popup.offsetY + 120,
                              child: Transform.rotate(
                                angle: popup.rotation,
                                child: Transform.scale(
                                  scale: popup.scale,
                                  child: Opacity(
                                    opacity: popup.opacity.clamp(0, 1),
                                    child: CustomPaint(
                                      size: const Size(60, 60),
                                      painter: _ImpactShapePainter(
                                        shapeType: popup.shapeType,
                                        color: popup.color,
                                        comboNumber: popup.comboNumber,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Floating stars
                          ..._floatingStars.map(
                            (star) => Positioned(
                              left: star.x - star.size / 2,
                              top: star.y - star.size / 2,
                              child: Opacity(
                                opacity: (1.0 - star.progress).clamp(0, 1),
                                child: Icon(
                                  Icons.star,
                                  color: Colors.yellowAccent,
                                  size: star.size,
                                ),
                              ),
                            ),
                          ),

                          // Mouth guide overlay at phase transitions
                          if (_showMouthGuideOverlay &&
                              _phaseToMouthQuadrant.containsKey(_phase))
                            Center(
                              child: MouthGuideOverlay(
                                quadrant: _phaseToMouthQuadrant[_phase]!,
                                themeColor: _world.themeColor,
                                label: '',
                                onDismiss: () {
                                  if (mounted) {
                                    setState(
                                      () => _showMouthGuideOverlay = false,
                                    );
                                  }
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Camera status indicator
                        if (_cameraReady) ...[
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _motionGlow
                                  ? const Color(
                                      0xFF69F0AE,
                                    ).withValues(alpha: 0.3)
                                  : Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.videocam,
                              color: _motionGlow
                                  ? const Color(0xFF69F0AE)
                                  : Colors.white38,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        const MuteButton(),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: _togglePause,
                          behavior: HitTestBehavior.opaque,
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(
                              Icons.pause,
                              color: Colors.white70,
                              size: 32,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Flash overlay
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _flashController,
                  builder: (context, _) => _flashController.value > 0
                      ? Container(
                          color: _weapon.primaryColor.withValues(
                            alpha: _flashController.value * 0.15,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),

              if (_isPaused) _buildPauseOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMissionHud() {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 84),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: _phaseTransitionController,
                curve: Curves.elasticOut,
              ),
            ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Row(
            key: ValueKey('mission-hud-${_phase.name}'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mouth guide — prominent so the kid sees where to brush
              AnimatedBuilder(
                animation: _mouthGuideGlowController,
                builder: (context, _) => MouthGuide(
                  activeQuadrant:
                      _phaseToMouthQuadrant[_phase] ??
                      MouthQuadrant.topLeft,
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
          ),
        ),
      ),
    );
  }

  // ==================== BIG MONSTER ====================

  Widget _buildBigMonster(double size) {
    final damageProgress = 1.0 - _monster.health;

    // Death: dissolve shader + debris particles
    if (_monster.isDefeating) {
      return SizedBox(
        width: size + 60,
        height: size + 60,
        child: AnimatedBuilder(
          animation: _particleController,
          builder: (context, _) => Stack(
            alignment: Alignment.center,
            children: [
              // Monster dissolving via fragment shader
              if (_dissolveProgram != null && _monster.defeatProgress < 0.85)
                ShaderMask(
                  shaderCallback: (bounds) {
                    final shader = _dissolveProgram!.fragmentShader();
                    shader.setFloat(0, _monster.defeatProgress);
                    shader.setFloat(1, bounds.width);
                    shader.setFloat(2, bounds.height);
                    return shader;
                  },
                  blendMode: BlendMode.dstIn,
                  child: Image.asset(
                    _monster.resolvedImagePath,
                    width: size,
                    height: size,
                    fit: BoxFit.contain,
                  ),
                )
              else if (_dissolveProgram == null)
                // Fallback: simple opacity fade if shader didn't load
                Opacity(
                  opacity: (1.0 - _monster.defeatProgress).clamp(0.0, 1.0),
                  child: Image.asset(
                    _monster.resolvedImagePath,
                    width: size,
                    height: size,
                    fit: BoxFit.contain,
                  ),
                ),
              // Debris chunks on top
              CustomPaint(
                size: Size(size + 60, size + 60),
                painter: _MonsterDeathPainter(
                  progress: _monster.defeatProgress,
                  debris: _monster.debris,
                  themeColor: _world.themeColor,
                  monsterSize: size,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_monster.alive) return SizedBox(width: size, height: size);

    final effectiveSize = size * _monster.personality.sizeMultiplier;

    // Monster image: transparent PNGs — no ShaderMask needed
    // At high damage, shift tint toward red to show the monster is hurt
    final damageTint = damageProgress > 0.5
        ? Color.lerp(
            _monster.personality.tintColor,
            Colors.red,
            ((damageProgress - 0.5) * 1.5).clamp(0.0, 0.6),
          )!
        : _monster.personality.tintColor;
    final damageTintStrength = _monster.personality.tintStrength +
        (damageProgress > 0.5 ? (damageProgress - 0.5) * 0.2 : 0.0);

    final Widget monsterImage = ColorFiltered(
      colorFilter: _monster.hitRecoil > 0.93
          // Tier 1: White flash on hit — 1-2 frames only, not overused
          ? const ColorFilter.mode(Colors.white, BlendMode.srcATop)
          : ColorFilter.mode(
              damageTint.withValues(alpha: damageTintStrength.clamp(0.0, 0.35)),
              BlendMode.overlay,
            ),
      child: Image.asset(
        _monster.resolvedImagePath,
        width: effectiveSize,
        height: effectiveSize,
        fit: BoxFit.contain,
      ),
    );

    Widget monsterWidget = AnimatedBuilder(
      animation: _monsterBreathController,
      builder: (context, child) {
        final breathT = _monsterBreathController.value;
        final p = _monster.personality;

        double scaleX = 1.0, scaleY = 1.0, rotation = 0.0;
        double translateX = 0.0, translateY = 0.0;

        // Cartoon-style breathing: exaggerated squash/stretch cycle
        final breathCycle = sin(
          breathT * p.bobSpeed * pi * 2 + _monster.wobblePhase,
        );
        final breathStretch = breathCycle * 0.06;
        scaleX = 1.0 - breathStretch;
        scaleY = 1.0 + breathStretch;

        // Multi-frequency organic wobble (not a single clean sine)
        final wobble1 = sin(
          (breathT * p.bobSpeed + _monster.wobblePhase) * pi * 2,
        );
        final wobble2 = sin(
          (breathT * p.bobSpeed * 1.7 + _monster.wobblePhase * 2.3) * pi * 2,
        );
        rotation = (wobble1 * 0.7 + wobble2 * 0.3) * p.wobbleAmount;
        translateY += (wobble1 * 0.6 + wobble2 * 0.4) * p.bobAmount;
        translateX += wobble2 * p.bobAmount * 0.3;

        // Damage shake: more damaged = more erratic
        if (damageProgress > 0.3) {
          final intensity = (damageProgress - 0.3) * 12;
          translateX +=
              sin(breathT * pi * 12 + _monster.wobblePhase) * intensity;
          translateY +=
              cos(breathT * pi * 10 + _monster.wobblePhase) * intensity * 0.5;
          rotation += sin(breathT * pi * 8) * (damageProgress - 0.3) * 0.12;
        }
        // Angry jitter + pulsing at low health
        if (damageProgress > 0.6) {
          final jitter = (damageProgress - 0.6) * 6;
          translateX += sin(breathT * pi * 20) * jitter;
          final ragePulse = sin(breathT * pi * 4) * 0.04;
          scaleX *= 1.0 + ragePulse;
          scaleY *= 1.0 + ragePulse;
        }

        // Hit recoil: exaggerated cartoon squash/stretch + knockback
        if (_monster.hitRecoil > 0.01) {
          if (_monster.hitRecoil > 0.5) {
            final t = (_monster.hitRecoil - 0.5) * 2;
            scaleX *= 1.0 + t * 0.30;
            scaleY *= 1.0 - t * 0.20;
          } else {
            final t = _monster.hitRecoil * 2;
            scaleX *= 1.0 - t * 0.12;
            scaleY *= 1.0 + t * 0.10;
          }
          translateY -= _monster.hitRecoil * 30;
        }

        final glowAlpha =
            (0.15 + breathT * 0.15) * (0.5 + damageProgress * 0.5);
        // Breathing shadow size
        final shadowScale = 0.65 + breathCycle * 0.08;

        return Transform.translate(
          offset: Offset(translateX, translateY),
          child: Transform.rotate(
            angle: rotation,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(scaleX, scaleY, 1.0),
              child: SizedBox(
                width: size + 20,
                height: size * 1.3,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Breathing shadow
                    Positioned(
                      bottom: 0,
                      child: Container(
                        width: size * shadowScale,
                        height: size * 0.10,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(size),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 14,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Inner glow (pulses from center — feels alive)
                    Container(
                      width: size * 0.7,
                      height: size * 0.7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _monster.personality.tintColor.withValues(
                              alpha: 0.12 + breathCycle.abs() * 0.15,
                            ),
                            blurRadius: 40,
                            spreadRadius: 15,
                          ),
                        ],
                      ),
                    ),
                    // Outer aura glow (damage-reactive)
                    if (glowAlpha > 0.01)
                      Container(
                        width: size + 20,
                        height: size + 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.redAccent.withValues(
                                alpha: glowAlpha,
                              ),
                              blurRadius: 24,
                              spreadRadius: 8,
                            ),
                          ],
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
                    // Menacing eye glow with blink + pupil tracking
                    Positioned(
                      bottom: 10,
                      child: CustomPaint(
                        size: Size(size, size),
                        painter: _MonsterEyeGlowPainter(
                          animValue: breathT,
                          tintColor: _monster.personality.tintColor,
                          damage: damageProgress,
                          isBlinking: _monsterBlinking,
                          pupilOffsetY: 0.15, // Looking down toward hero
                        ),
                      ),
                    ),
                    // Drool/slime particles dripping down
                    Positioned(
                      bottom: 0,
                      child: CustomPaint(
                        size: Size(size, size * 0.4),
                        painter: _MonsterDripPainter(
                          animValue: breathT,
                          color: _monster.personality.tintColor,
                          phase: _monster.wobblePhase,
                        ),
                      ),
                    ),
                    // (Circle overlays removed — don't match transparent PNGs)
                    // Damage cracks (only at heavy damage, subtle)
                    if (damageProgress > 0.6)
                      Positioned(
                        bottom: 10,
                        child: CustomPaint(
                          size: Size(size, size),
                          painter: _DamageCrackPainter(
                            progress: damageProgress,
                            color: Colors.white.withValues(alpha: 0.5),
                            glowColor: damageProgress > 0.7
                                ? _weapon.primaryColor
                                : null,
                          ),
                        ),
                      ),
                    // Dizzy spiral eyes (50-70% damage)
                    if (damageProgress > 0.5 && damageProgress <= 0.7)
                      Positioned(
                        bottom: 10,
                        child: CustomPaint(
                          size: Size(size, size),
                          painter: _MonsterOverlayPainter(animValue: breathT),
                        ),
                      ),
                    // (Red pulse circle removed — replaced by damage-reactive tint on sprite)
                    // (White flash now handled by ColorFilter on the sprite itself)
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
          final t = CurvedAnimation(
            parent: _monsterEntranceController,
            curve: Curves.bounceOut,
          ).value;
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
    final ghostHealthClamped = _ghostHealth.clamp(0.0, 1.0);
    final barColor = Color.lerp(
      const Color(0xFFFF5252),
      const Color(0xFF69F0AE),
      health,
    )!;

    return Container(
      height: 22,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: barColor.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: barColor.withValues(alpha: 0.3),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          children: [
            Container(color: Colors.black.withValues(alpha: 0.5)),
            // Ghost health layer (drains slowly — shows recent damage)
            if (ghostHealthClamped > health)
              FractionallySizedBox(
                widthFactor: ghostHealthClamped,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.25),
                        Colors.white.withValues(alpha: 0.12),
                      ],
                    ),
                  ),
                ),
              ),
            // Actual health layer
            FractionallySizedBox(
              widthFactor: health,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [barColor, barColor.withValues(alpha: 0.7)],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // MONSTER HP label removed — health bar position + color is self-explanatory
          ],
        ),
      ),
    );
  }

  // ==================== HERO ====================

  Widget _buildHero(double size) {
    final avatar = HeroService.buildHeroImage(
      _hero.id,
      stage: _evolutionStage,
      weaponId: _weapon.id,
      size: size,
    );

    return AnimatedBuilder(
      animation: _heroIdleController,
      builder: (context, child) {
        final t = _heroIdleController.value;
        final glowBoost = _motionGlow ? 0.4 : 0.0;

        // Cartoon squash/stretch idle breathing
        final breathCycle = sin(t * pi);
        double heroScaleX = 1.0 - breathCycle * 0.04;
        double heroScaleY = 1.0 + breathCycle * 0.04;
        final bob = breathCycle * 4;

        // Attack lunge: jump upward with extra stretch
        double lungeOffset = 0.0;
        if (_heroLunging) {
          lungeOffset = -35.0;
          heroScaleX *= 0.88;
          heroScaleY *= 1.15;
        }

        final pulse = 0.3 + t * 0.3 + glowBoost;

        return Transform.translate(
          offset: Offset(0, bob + lungeOffset),
          child: Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.diagonal3Values(heroScaleX, heroScaleY, 1.0),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Glow
                Container(
                  width: size + 16,
                  height: size + 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _hero.primaryColor.withValues(alpha: pulse),
                        blurRadius: 20 + (glowBoost * 20),
                        spreadRadius: 4 + (glowBoost * 8),
                      ),
                    ],
                  ),
                ),
                // Orbiting power particles
                CustomPaint(
                  size: Size(size + 24, size + 24),
                  painter: _HeroPowerParticlePainter(
                    animValue: t,
                    color: _hero.primaryColor,
                    secondaryColor: _hero.attackColor,
                    isAttacking: _heroLunging,
                  ),
                ),
                // Hero image (transparent PNGs — no ShaderMask needed)
                child!,
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
          scale: 1.0 + _timerPulseController.value * 0.15,
          child: child,
        ),
        child: timerText,
      );
    }
    if (isCritical) {
      return Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _timerPulseController,
            builder: (context, _) => Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withValues(
                      alpha: 0.3 * _timerPulseController.value,
                    ),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
          ),
          timerText,
        ],
      );
    }
    return timerText;
  }

  Widget _buildPauseOverlay() {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pulsing pause icon — no text needed
            const _PulsingPauseIcon(color: Colors.white54),
            const SizedBox(height: 48),
            // Resume button — enlarged play arrow, no text
            GestureDetector(
              onTap: _togglePause,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00E676), Color(0xFF00BFA5)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E676).withValues(alpha: 0.5),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 48),
              ),
            ),
            const SizedBox(height: 24),
            // "GO HOME" button — house icon, softer styling
            GestureDetector(
              onTap: _quitBrushing,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF8B4F5A).withValues(alpha: 0.3),
                  border: Border.all(
                    color: const Color(0xFF8B4F5A).withValues(alpha: 0.6),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.home,
                  color: Color(0xFFCC7A88),
                  size: 36,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== CAMERA POWER-UP VISUAL ====================

class _CameraPowerUpVisual extends StatefulWidget {
  final HeroCharacter hero;
  final int evolutionStage;
  final WeaponItem weapon;
  final Color themeColor;

  const _CameraPowerUpVisual({
    required this.hero,
    required this.evolutionStage,
    required this.weapon,
    required this.themeColor,
  });

  @override
  State<_CameraPowerUpVisual> createState() => _CameraPowerUpVisualState();
}

class _CameraPowerUpVisualState extends State<_CameraPowerUpVisual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = _pulseController.value;
        final beamOpacity = 0.3 + pulse * 0.5;
        final heroGlow = 8.0 + pulse * 16.0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Camera icon at top with pulse
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF7C4DFF).withValues(alpha: 0.3 + pulse * 0.3),
                border: Border.all(
                  color: const Color(0xFF7C4DFF).withValues(alpha: 0.6 + pulse * 0.4),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C4DFF).withValues(alpha: pulse * 0.5),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: const Icon(Icons.videocam, color: Colors.white, size: 28),
            ),

            // Energy beam (camera → hero)
            Container(
              width: 4,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF7C4DFF).withValues(alpha: beamOpacity),
                    widget.hero.primaryColor.withValues(alpha: beamOpacity),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C4DFF).withValues(alpha: beamOpacity * 0.6),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),

            // Hero — large, glowing, powered up
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.hero.primaryColor,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.hero.primaryColor.withValues(alpha: 0.4 + pulse * 0.3),
                    blurRadius: heroGlow,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: const Color(0xFF7C4DFF).withValues(alpha: pulse * 0.3),
                    blurRadius: heroGlow * 1.5,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipOval(
                child: HeroService.buildHeroImage(
                  widget.hero.id,
                  stage: widget.evolutionStage,
                  weaponId: widget.weapon.id,
                  size: 180,
                ),
              ),
            ),
          ],
        );
      },
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
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  world.gradientColors.length > 2
                      ? world.gradientColors[2]
                      : const Color(0xFF0D0B2E),
                  world.gradientColors.length > 1
                      ? world.gradientColors[1].withValues(alpha: 0.6)
                      : const Color(0xFF0D0B2E),
                  world.gradientColors.isNotEmpty
                      ? world.gradientColors[0].withValues(alpha: 0.3)
                      : const Color(0xFF0D0B2E),
                  world.gradientColors.length > 2
                      ? world.gradientColors[2]
                      : const Color(0xFF0D0B2E),
                ],
                stops: const [0.0, 0.3, 0.6, 1.0],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Opacity(
            opacity: 0.6,
            child: Image.asset(
              world.backgroundImage,
              fit: BoxFit.cover,
            ),
          ),
        ),
        child,
      ],
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
      final paint = Paint()
        ..color = p.color.withValues(alpha: p.opacity.clamp(0, 1));
      switch (particleType) {
        case 'bubble':
          paint.style = PaintingStyle.stroke;
          paint.strokeWidth = 1;
          canvas.drawCircle(Offset(x, y), p.size + 1, paint);
        case 'ember':
          paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
          canvas.drawCircle(Offset(x, y), p.size, paint);
        case 'twinkle':
          paint.strokeWidth = 1.5;
          paint.strokeCap = StrokeCap.round;
          canvas.drawLine(Offset(x - p.size, y), Offset(x + p.size, y), paint);
          canvas.drawLine(Offset(x, y - p.size), Offset(x, y + p.size), paint);
        case 'crack':
          paint.strokeWidth = 1;
          paint.strokeCap = StrokeCap.round;
          canvas.drawLine(
            Offset(x, y),
            Offset(x + p.vx * 600, y + p.vy * 600),
            paint,
          );
        default:
          final path = Path();
          path.moveTo(x, y - p.size);
          path.lineTo(x + p.size * 0.6, y);
          path.lineTo(x, y + p.size);
          path.lineTo(x - p.size * 0.6, y);
          path.close();
          canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_WorldParticlePainter oldDelegate) =>
      particles.length != oldDelegate.particles.length;
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
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      final px = cx + s.x;
      final py = cy + s.y;
      final r = s.size * s.life;

      final path = Path();
      for (int i = 0; i < 4; i++) {
        final outerAngle = i * pi / 2;
        final innerAngle = outerAngle + pi / 4;
        if (i == 0) {
          path.moveTo(px + cos(outerAngle) * r, py + sin(outerAngle) * r);
        } else {
          path.lineTo(px + cos(outerAngle) * r, py + sin(outerAngle) * r);
        }
        path.lineTo(px + cos(innerAngle) * r * 0.4, py + sin(innerAngle) * r * 0.4);
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_HitSparkPainter oldDelegate) =>
      sparks.length != oldDelegate.sparks.length || sparks.isNotEmpty;
}

/// Energy ring particles orbiting the monster
class _EnergyRingPainter extends CustomPainter {
  final double animValue;
  final Color color;
  final double health;

  _EnergyRingPainter({
    required this.animValue,
    required this.color,
    required this.health,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.width * 0.42;
    const particleCount = 8;

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
  bool shouldRepaint(_EnergyRingPainter oldDelegate) =>
      animValue != oldDelegate.animValue || health != oldDelegate.health;
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

    const impactStart = 0.35;
    const impactEnd = 0.7;
    if (progress < impactStart || progress > impactEnd) return;

    final impactProgress =
        ((progress - impactStart) / (impactEnd - impactStart)).clamp(0.0, 1.0);
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

      case AttackEffectType.lightningWand:
        final path = Path();
        path.moveTo(cx, cy + size.height * 0.3);
        const segments = 6;
        for (int i = 1; i <= segments; i++) {
          final t = i / segments;
          final y =
              cy + size.height * 0.3 - size.height * 0.3 * t * impactProgress;
          final x = cx + (i.isEven ? 1 : -1) * 20 * impactProgress;
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

      case AttackEffectType.vineWhip:
        final path = Path();
        path.moveTo(cx - size.width * 0.3, cy + 30);
        path.quadraticBezierTo(
          cx,
          cy - 40 * impactProgress,
          cx + size.width * 0.3 * impactProgress,
          cy,
        );
        paint.strokeWidth = lineWidth * 1.5;
        canvas.drawPath(path, paint);
        canvas.drawPath(path, glowPaint);
        final path2 = Path();
        path2.moveTo(cx + size.width * 0.3, cy + 30);
        path2.quadraticBezierTo(
          cx,
          cy - 20 * impactProgress,
          cx - size.width * 0.25 * impactProgress,
          cy + 10,
        );
        canvas.drawPath(path2, paint);

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

      case AttackEffectType.defaultBeam:
        final beamEndY = cy + size.height * 0.3 * (1 - impactProgress);
        paint.strokeWidth = lineWidth * 2;
        canvas.drawLine(
          Offset(cx, cy + size.height * 0.3),
          Offset(cx, beamEndY),
          paint,
        );
        glowPaint.strokeWidth = lineWidth * 5;
        canvas.drawLine(
          Offset(cx, cy + size.height * 0.3),
          Offset(cx, beamEndY),
          glowPaint,
        );
    }

    if (isFinisher) {
      final reach = size.width * 0.35 * impactProgress;
      canvas.drawLine(
        Offset(cx - reach, cy - reach),
        Offset(cx + reach, cy + reach),
        paint,
      );
      canvas.drawLine(
        Offset(cx + reach, cy - reach),
        Offset(cx - reach, cy + reach),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WeaponBattleEffectPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// Glowing eyes that pulse menacingly with blink and pupil tracking
class _MonsterEyeGlowPainter extends CustomPainter {
  final double animValue;
  final Color tintColor;
  final double damage;
  final bool isBlinking;
  final double pupilOffsetY;

  _MonsterEyeGlowPainter({
    required this.animValue,
    required this.tintColor,
    required this.damage,
    this.isBlinking = false,
    this.pupilOffsetY = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (damage > 0.5) return; // Dizzy eyes take over at high damage
    final cx = size.width / 2;
    final cy = size.height * 0.36;
    final eyeSpacing = size.width * 0.12;
    final eyeSize = size.width * 0.045;

    final pulse = sin(animValue * pi * 2);
    final glowAlpha = (0.5 + pulse * 0.3).clamp(0.0, 1.0);
    final eyeRadius = eyeSize + pulse * eyeSize * 0.3;

    // Blink: squash eye vertically
    final blinkScaleY = isBlinking ? 0.1 : 1.0;

    for (final side in [-1.0, 1.0]) {
      final ex = cx + side * eyeSpacing;

      canvas.save();
      // Apply blink by scaling Y around eye center
      canvas.translate(ex, cy);
      canvas.scale(1.0, blinkScaleY);
      canvas.translate(-ex, -cy);

      // Outer glow
      final glowPaint = Paint()
        ..color = tintColor.withValues(alpha: glowAlpha * 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(Offset(ex, cy), eyeRadius * 2.5, glowPaint);

      // Core eye
      final corePaint = Paint()
        ..color = tintColor.withValues(alpha: glowAlpha * 0.85)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(Offset(ex, cy), eyeRadius, corePaint);

      // Pupil: offset toward hero (downward)
      final pupilX = ex;
      final pupilY = cy + pupilOffsetY * eyeRadius * 2;
      final centerPaint = Paint()
        ..color = Colors.white.withValues(alpha: glowAlpha * 0.7);
      canvas.drawCircle(Offset(pupilX, pupilY), eyeRadius * 0.4, centerPaint);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_MonsterEyeGlowPainter oldDelegate) =>
      animValue != oldDelegate.animValue ||
      damage != oldDelegate.damage ||
      isBlinking != oldDelegate.isBlinking;
}

/// Drool/slime particles dripping from the monster's bottom edge
class _MonsterDripPainter extends CustomPainter {
  final double animValue;
  final Color color;
  final double phase;

  _MonsterDripPainter({
    required this.animValue,
    required this.color,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random((phase * 1000).toInt());
    const dripCount = 3;

    for (int i = 0; i < dripCount; i++) {
      final baseX = size.width * 0.25 + rng.nextDouble() * size.width * 0.5;
      final speed = 0.3 + rng.nextDouble() * 0.7;
      final dripPhase = (animValue * speed + i * 0.33 + phase) % 1.0;

      final y = dripPhase * size.height;
      final alpha = (1.0 - dripPhase) * 0.5;
      final radius = 2.0 + (1.0 - dripPhase) * 2.5;

      // Wobble the drip sideways
      final wobble = sin(dripPhase * pi * 3 + i) * 3;

      final paint = Paint()
        ..color = color.withValues(alpha: alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(Offset(baseX + wobble, y), radius, paint);

      // Elongated drip shape (tail)
      if (dripPhase < 0.7) {
        final tailPaint = Paint()
          ..color = color.withValues(alpha: alpha * 0.6)
          ..strokeWidth = radius * 0.8
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(baseX + wobble, y),
          Offset(baseX + wobble * 0.5, y - radius * 3),
          tailPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_MonsterDripPainter oldDelegate) =>
      animValue != oldDelegate.animValue;
}

/// Orbiting power sparkles around the hero
class _HeroPowerParticlePainter extends CustomPainter {
  final double animValue;
  final Color color;
  final Color secondaryColor;
  final bool isAttacking;

  _HeroPowerParticlePainter({
    required this.animValue,
    required this.color,
    required this.secondaryColor,
    required this.isAttacking,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.width * 0.48;
    final particleCount = isAttacking ? 10 : 5;
    final speed = isAttacking ? 3.0 : 1.0;

    for (int i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * 2 * pi + animValue * pi * 2 * speed;
      final orbitRadius = radius + sin(angle * 2 + animValue * pi * 4) * 6;
      final x = cx + cos(angle) * orbitRadius;
      final y = cy + sin(angle) * orbitRadius * 0.7; // Slightly elliptical

      final useSecondary = i.isEven;
      final c = useSecondary ? secondaryColor : color;
      final alpha = isAttacking
          ? 0.8
          : (0.35 + sin(angle + animValue * pi * 4) * 0.25);
      final pSize = isAttacking ? 3.5 : 2.0 + sin(angle * 3) * 1.0;

      // Glow
      final glowPaint = Paint()
        ..color = c.withValues(alpha: alpha * 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(x, y), pSize * 2, glowPaint);

      // Core
      final paint = Paint()..color = c.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), pSize, paint);
    }
  }

  @override
  bool shouldRepaint(_HeroPowerParticlePainter oldDelegate) =>
      animValue != oldDelegate.animValue ||
      isAttacking != oldDelegate.isAttacking;
}

class _DamageCrackPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color? glowColor;
  _DamageCrackPainter({
    required this.progress,
    required this.color,
    this.glowColor,
  });
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
      final x2 = x1 + cos(startAngle) * len;
      final y2 = y1 + sin(startAngle) * len;
      if (glowPaint != null) {
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), glowPaint);
      }
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
      if (rng.nextBool()) {
        final branchAngle = startAngle + (rng.nextDouble() - 0.5) * 1.2;
        final bLen = len * 0.5;
        final bx = x2 + cos(branchAngle) * bLen;
        final by = y2 + sin(branchAngle) * bLen;
        if (glowPaint != null) {
          canvas.drawLine(Offset(x2, y2), Offset(bx, by), glowPaint);
        }
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
  bool shouldRepaint(_MonsterOverlayPainter oldDelegate) =>
      animValue != oldDelegate.animValue;
}

// Per-monster death explosion painter (scaled for bigger monster)
class _MonsterDeathPainter extends CustomPainter {
  final double progress;
  final List<_MonsterDebris> debris;
  final Color themeColor;
  final double monsterSize;

  _MonsterDeathPainter({
    required this.progress,
    required this.debris,
    required this.themeColor,
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
      final flashPaint = Paint()
        ..color = Colors.white.withValues(alpha: flashAlpha * 0.8);
      canvas.drawCircle(Offset(cx, cy), baseRadius, flashPaint);
    }

    // Debris chunks (0.1-0.8)
    if (progress > 0.1 && progress < 0.8) {
      for (final d in debris) {
        if (d.life <= 0) continue;
        canvas.save();
        canvas.translate(cx + d.x, cy + d.y);
        canvas.rotate(d.rotation);
        final paint = Paint()
          ..color = d.color.withValues(alpha: d.life.clamp(0, 1));
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: d.size,
            height: d.size * 0.7,
          ),
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
      canvas.drawCircle(
        Offset(cx, ghostY),
        25 * (1.0 - ghostT * 0.5),
        ghostPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_MonsterDeathPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

class _PulsingTapToFight extends StatefulWidget {
  final Color themeColor;
  const _PulsingTapToFight({required this.themeColor});

  @override
  State<_PulsingTapToFight> createState() => _PulsingTapToFightState();
}

class _PulsingTapToFightState extends State<_PulsingTapToFight>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1.0 + _controller.value * 0.12;
        final glowAlpha = 0.3 + _controller.value * 0.4;
        return Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  widget.themeColor,
                  widget.themeColor.withValues(alpha: 0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: widget.themeColor.withValues(alpha: glowAlpha),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt, color: Colors.white, size: 28),
                SizedBox(width: 10),
                Text(
                  'TAP TO FIGHT!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    shadows: [
                      Shadow(color: Colors.black54, blurRadius: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ==================== TIER 3 PAINTERS ====================

/// Shockwave ripple effect using fragment shader
class _ShockwavePainter extends CustomPainter {
  final ui.FragmentProgram program;
  final double progress;
  final Color color;

  _ShockwavePainter({
    required this.program,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;

    final shader = program.fragmentShader();
    shader.setFloat(0, progress);
    shader.setFloat(1, size.width);
    shader.setFloat(2, size.height);
    shader.setFloat(3, 0.5); // center.x (normalized)
    shader.setFloat(4, 0.35); // center.y (monster area)
    shader.setFloat(5, color.r);
    shader.setFloat(6, color.g);
    shader.setFloat(7, color.b);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(_ShockwavePainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// Weapon trail — glowing arc during hero attacks (like Fruit Ninja)
class _WeaponTrailPainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  final double heroY;
  final double centerX;

  _WeaponTrailPainter({
    required this.points,
    required this.color,
    required this.heroY,
    required this.centerX,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    // Build a trail path from hero toward monster
    final path = Path();
    final trailStart = Offset(centerX, heroY);

    path.moveTo(trailStart.dx, trailStart.dy);

    // Arc upward toward monster area
    final controlX = centerX + sin(points.length * 0.5) * 40;
    final controlY = heroY - 80;
    final endY = heroY - 120;

    path.quadraticBezierTo(controlX, controlY, centerX, endY);

    // Draw glowing trail
    for (int i = 0; i < 3; i++) {
      final trailPaint = Paint()
        ..color = color.withValues(alpha: 0.6 - i * 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (6 - i * 1.5).clamp(1.0, 6.0)
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3.0 + i * 3);
      canvas.drawPath(path, trailPaint);
    }

    // Bright core
    final corePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, corePaint);
  }

  @override
  bool shouldRepaint(_WeaponTrailPainter oldDelegate) => true;
}

// ==================== VISUAL-ONLY IMPACT SHAPES ====================

/// Draws exciting comic-book style impact shapes for damage popups.
/// Replaces all text labels with bold visual cues a 7-year-old can understand.
class _ImpactShapePainter extends CustomPainter {
  final ImpactShapeType shapeType;
  final Color color;
  final int comboNumber;

  _ImpactShapePainter({
    required this.shapeType,
    required this.color,
    this.comboNumber = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.45;

    switch (shapeType) {
      case ImpactShapeType.fourPointStar:
        _drawJaggedStar(canvas, cx, cy, r, 4, color);
      case ImpactShapeType.sixPointStar:
        _drawJaggedStar(canvas, cx, cy, r, 6, color);
      case ImpactShapeType.speedLines:
        _drawSpeedLines(canvas, cx, cy, r, color);
      case ImpactShapeType.circleBurst:
        _drawCircleBurst(canvas, cx, cy, r, color);
      case ImpactShapeType.lightningBolt:
        _drawLightningBolt(canvas, cx, cy, r, color);
      case ImpactShapeType.goldStarburst:
        _drawGoldStarburst(canvas, cx, cy, r);
      case ImpactShapeType.flameCombo:
        _drawFlameCombo(canvas, cx, cy, r, comboNumber);
      case ImpactShapeType.explosionBurst:
        _drawExplosionBurst(canvas, cx, cy, r);
      case ImpactShapeType.shatteredStar:
        _drawShatteredStar(canvas, cx, cy, r);
      case ImpactShapeType.rewardStar:
        _drawRewardStar(canvas, cx, cy, r);
      case ImpactShapeType.rewardBolt:
        _drawRewardBolt(canvas, cx, cy, r);
      case ImpactShapeType.rewardShield:
        _drawRewardShield(canvas, cx, cy, r);
    }
  }

  void _drawJaggedStar(Canvas canvas, double cx, double cy, double r, int points, Color c) {
    // Glow shadow
    final glowPaint = Paint()
      ..color = c.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final path = _starPath(cx, cy, r, r * 0.4, points);
    canvas.drawPath(path, glowPaint);
    // Bright fill
    final fillPaint = Paint()..color = c;
    canvas.drawPath(path, fillPaint);
    // White center highlight
    final centerPath = _starPath(cx, cy, r * 0.35, r * 0.15, points);
    canvas.drawPath(centerPath, Paint()..color = Colors.white.withValues(alpha: 0.7));
  }

  Path _starPath(double cx, double cy, double outerR, double innerR, int points) {
    final path = Path();
    final step = pi / points;
    for (int i = 0; i < points * 2; i++) {
      final angle = i * step - pi / 2;
      final radius = i.isEven ? outerR : innerR;
      final x = cx + cos(angle) * radius;
      final y = cy + sin(angle) * radius;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  void _drawSpeedLines(Canvas canvas, double cx, double cy, double r, Color c) {
    final paint = Paint()
      ..color = c
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final glowPaint = Paint()
      ..color = c.withValues(alpha: 0.4)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    // Draw 6 speed lines radiating outward
    for (int i = 0; i < 6; i++) {
      final angle = i * pi / 3 + pi / 6;
      final innerR = r * 0.3;
      final outerR = r * (0.8 + (i % 2) * 0.2);
      final x1 = cx + cos(angle) * innerR;
      final y1 = cy + sin(angle) * innerR;
      final x2 = cx + cos(angle) * outerR;
      final y2 = cy + sin(angle) * outerR;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), glowPaint);
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    }
    // Central dot
    canvas.drawCircle(Offset(cx, cy), r * 0.15, Paint()..color = Colors.white);
  }

  void _drawCircleBurst(Canvas canvas, double cx, double cy, double r, Color c) {
    // Outer ring with glow
    final ringPaint = Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final glowRingPaint = Paint()
      ..color = c.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(Offset(cx, cy), r, glowRingPaint);
    canvas.drawCircle(Offset(cx, cy), r, ringPaint);
    // Inner burst
    canvas.drawCircle(Offset(cx, cy), r * 0.5, Paint()..color = c.withValues(alpha: 0.6));
    canvas.drawCircle(Offset(cx, cy), r * 0.25, Paint()..color = Colors.white.withValues(alpha: 0.8));
    // Small radiating dots
    for (int i = 0; i < 8; i++) {
      final angle = i * pi / 4;
      final dx = cx + cos(angle) * r * 0.75;
      final dy = cy + sin(angle) * r * 0.75;
      canvas.drawCircle(Offset(dx, dy), 3, Paint()..color = c);
    }
  }

  void _drawLightningBolt(Canvas canvas, double cx, double cy, double r, Color c) {
    final path = Path();
    path.moveTo(cx - r * 0.15, cy - r);
    path.lineTo(cx + r * 0.35, cy - r * 0.1);
    path.lineTo(cx, cy - r * 0.1);
    path.lineTo(cx + r * 0.15, cy + r);
    path.lineTo(cx - r * 0.35, cy + r * 0.1);
    path.lineTo(cx, cy + r * 0.1);
    path.close();
    // Glow
    canvas.drawPath(path, Paint()
      ..color = c.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    // Fill
    canvas.drawPath(path, Paint()..color = c);
    // White highlight down center
    final highlightPath = Path();
    highlightPath.moveTo(cx - r * 0.05, cy - r * 0.8);
    highlightPath.lineTo(cx + r * 0.15, cy - r * 0.1);
    highlightPath.lineTo(cx - r * 0.05, cy - r * 0.1);
    highlightPath.lineTo(cx + r * 0.05, cy + r * 0.8);
    highlightPath.lineTo(cx - r * 0.15, cy + r * 0.1);
    highlightPath.lineTo(cx + r * 0.05, cy + r * 0.1);
    highlightPath.close();
    canvas.drawPath(highlightPath, Paint()..color = Colors.white.withValues(alpha: 0.5));
  }

  void _drawGoldStarburst(Canvas canvas, double cx, double cy, double r) {
    // Larger CRITICAL hit — gold starburst with concentric rings
    const gold = Color(0xFFFFD54F);
    const brightGold = Color(0xFFFFEB3B);
    // Outer glow
    canvas.drawCircle(Offset(cx, cy), r * 1.2, Paint()
      ..color = gold.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    // Concentric rings
    for (int i = 3; i >= 1; i--) {
      final ringR = r * (0.3 + i * 0.25);
      canvas.drawCircle(Offset(cx, cy), ringR, Paint()
        ..color = gold.withValues(alpha: 0.15 + i * 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
    }
    // Star shape
    final starPath = _starPath(cx, cy, r, r * 0.35, 8);
    canvas.drawPath(starPath, Paint()
      ..color = gold.withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawPath(starPath, Paint()..color = brightGold);
    // White hot center
    canvas.drawCircle(Offset(cx, cy), r * 0.2, Paint()..color = Colors.white);
  }

  void _drawFlameCombo(Canvas canvas, double cx, double cy, double r, int combo) {
    // Flame shape with number inside
    final flamePath = Path();
    flamePath.moveTo(cx, cy - r); // top of flame
    flamePath.cubicTo(cx + r * 0.5, cy - r * 0.7, cx + r * 0.6, cy - r * 0.2, cx + r * 0.4, cy + r * 0.3);
    flamePath.cubicTo(cx + r * 0.5, cy + r * 0.1, cx + r * 0.3, cy + r * 0.6, cx + r * 0.15, cy + r * 0.8);
    flamePath.quadraticBezierTo(cx, cy + r, cx - r * 0.15, cy + r * 0.8);
    flamePath.cubicTo(cx - r * 0.3, cy + r * 0.6, cx - r * 0.5, cy + r * 0.1, cx - r * 0.4, cy + r * 0.3);
    flamePath.cubicTo(cx - r * 0.6, cy - r * 0.2, cx - r * 0.5, cy - r * 0.7, cx, cy - r);
    flamePath.close();

    // Orange→yellow gradient via layered fill
    canvas.drawPath(flamePath, Paint()
      ..color = const Color(0xFFFF6D00).withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawPath(flamePath, Paint()..color = const Color(0xFFFF6D00));
    // Inner lighter flame
    final innerFlame = Path();
    innerFlame.moveTo(cx, cy - r * 0.55);
    innerFlame.cubicTo(cx + r * 0.25, cy - r * 0.35, cx + r * 0.3, cy, cx + r * 0.15, cy + r * 0.4);
    innerFlame.quadraticBezierTo(cx, cy + r * 0.55, cx - r * 0.15, cy + r * 0.4);
    innerFlame.cubicTo(cx - r * 0.3, cy, cx - r * 0.25, cy - r * 0.35, cx, cy - r * 0.55);
    innerFlame.close();
    canvas.drawPath(innerFlame, Paint()..color = const Color(0xFFFFAB00));
    // Hot center
    canvas.drawCircle(Offset(cx, cy + r * 0.1), r * 0.2, Paint()..color = const Color(0xFFFFD54F));

    // Number in center (numbers are universal — kids can read them)
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$combo',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(cx - textPainter.width / 2, cy - textPainter.height / 2 + r * 0.05));
  }

  void _drawExplosionBurst(Canvas canvas, double cx, double cy, double r) {
    // Big yellow explosion starburst
    const yellow = Color(0xFFFFEB3B);
    const orange = Color(0xFFFF9800);
    // Glow
    canvas.drawCircle(Offset(cx, cy), r * 1.5, Paint()
      ..color = yellow.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16));
    // Outer spikes — jagged 12-point star
    final spikePath = _starPath(cx, cy, r * 1.1, r * 0.5, 12);
    canvas.drawPath(spikePath, Paint()..color = orange);
    // Inner star
    final innerPath = _starPath(cx, cy, r * 0.7, r * 0.35, 8);
    canvas.drawPath(innerPath, Paint()..color = yellow);
    // White hot core
    canvas.drawCircle(Offset(cx, cy), r * 0.25, Paint()..color = Colors.white);
    // Extra radial lines for intensity
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 12; i++) {
      final angle = i * pi / 6;
      final x1 = cx + cos(angle) * r * 0.3;
      final y1 = cy + sin(angle) * r * 0.3;
      final x2 = cx + cos(angle) * r * 1.0;
      final y2 = cy + sin(angle) * r * 1.0;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), linePaint);
    }
  }

  void _drawShatteredStar(Canvas canvas, double cx, double cy, double r) {
    // Main cracked star in yellow
    const yellow = Color(0xFFFFEB3B);
    // Glow
    canvas.drawCircle(Offset(cx, cy), r * 1.3, Paint()
      ..color = yellow.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    // Star with crack lines
    final starPath = _starPath(cx, cy, r, r * 0.4, 5);
    canvas.drawPath(starPath, Paint()..color = yellow);
    // Crack lines through center
    final crackPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - r * 0.6, cy - r * 0.3), Offset(cx + r * 0.4, cy + r * 0.5), crackPaint);
    canvas.drawLine(Offset(cx + r * 0.2, cy - r * 0.5), Offset(cx - r * 0.3, cy + r * 0.4), crackPaint);
    // 4 mini stars bursting outward
    const miniStarColor = Colors.yellowAccent;
    for (int i = 0; i < 4; i++) {
      final angle = i * pi / 2 + pi / 4;
      final dist = r * 1.2;
      final mx = cx + cos(angle) * dist;
      final my = cy + sin(angle) * dist;
      final miniPath = _starPath(mx, my, r * 0.18, r * 0.08, 4);
      canvas.drawPath(miniPath, Paint()..color = miniStarColor);
      canvas.drawPath(miniPath, Paint()
        ..color = miniStarColor.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    }
  }

  void _drawRewardStar(Canvas canvas, double cx, double cy, double r) {
    // Spinning gold star with sparkle trail
    const gold = Color(0xFFFFD54F);
    canvas.drawCircle(Offset(cx, cy), r * 0.8, Paint()
      ..color = gold.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    final starPath = _starPath(cx, cy, r * 0.8, r * 0.35, 5);
    canvas.drawPath(starPath, Paint()..color = gold);
    canvas.drawPath(starPath, Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    // Inner highlight
    canvas.drawCircle(Offset(cx - r * 0.1, cy - r * 0.1), r * 0.15,
      Paint()..color = Colors.white.withValues(alpha: 0.6));
  }

  void _drawRewardBolt(Canvas canvas, double cx, double cy, double r) {
    // Lightning bolt with glow
    const yellow = Color(0xFFFFEB3B);
    _drawLightningBolt(canvas, cx, cy, r * 0.85, yellow);
    // Extra glow ring
    canvas.drawCircle(Offset(cx, cy), r * 0.9, Paint()
      ..color = yellow.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
  }

  void _drawRewardShield(Canvas canvas, double cx, double cy, double r) {
    // Shield shape with shimmer
    const gold = Color(0xFFFFD54F);
    const cyan = Color(0xFF00E5FF);
    final shieldPath = Path();
    shieldPath.moveTo(cx, cy - r); // top point
    shieldPath.quadraticBezierTo(cx + r * 0.9, cy - r * 0.7, cx + r * 0.7, cy);
    shieldPath.quadraticBezierTo(cx + r * 0.5, cy + r * 0.6, cx, cy + r);
    shieldPath.quadraticBezierTo(cx - r * 0.5, cy + r * 0.6, cx - r * 0.7, cy);
    shieldPath.quadraticBezierTo(cx - r * 0.9, cy - r * 0.7, cx, cy - r);
    shieldPath.close();
    // Glow
    canvas.drawPath(shieldPath, Paint()
      ..color = cyan.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    // Fill
    canvas.drawPath(shieldPath, Paint()..color = cyan.withValues(alpha: 0.8));
    // Border
    canvas.drawPath(shieldPath, Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3);
    // Central star emblem
    final miniStar = _starPath(cx, cy, r * 0.3, r * 0.12, 4);
    canvas.drawPath(miniStar, Paint()..color = gold);
    // Shimmer highlight
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - r * 0.15, cy - r * 0.3), width: r * 0.4, height: r * 0.2),
      Paint()..color = Colors.white.withValues(alpha: 0.4),
    );
  }

  @override
  bool shouldRepaint(_ImpactShapePainter oldDelegate) =>
      shapeType != oldDelegate.shapeType ||
      color != oldDelegate.color ||
      comboNumber != oldDelegate.comboNumber;
}

/// Small burst/explosion icon for the defeated counter in the HUD.
class _SmallBurstPainter extends CustomPainter {
  final Color color;
  _SmallBurstPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.45;

    // Glow
    canvas.drawCircle(Offset(cx, cy), r * 1.2, Paint()
      ..color = color.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));

    // 6-point star burst
    final path = Path();
    for (int i = 0; i < 12; i++) {
      final angle = i * pi / 6 - pi / 2;
      final radius = i.isEven ? r : r * 0.4;
      final x = cx + cos(angle) * radius;
      final y = cy + sin(angle) * radius;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
    // White center
    canvas.drawCircle(Offset(cx, cy), r * 0.25, Paint()..color = Colors.white.withValues(alpha: 0.7));
  }

  @override
  bool shouldRepaint(_SmallBurstPainter oldDelegate) => color != oldDelegate.color;
}

/// Phase-progress icon that changes based on time elapsed in the current phase.
/// Replaces text encouragements with visual cues:
/// - 0-33%: Crossed swords (attack!)
/// - 34-66%: Shield (steady)
/// - 67-83%: Hourglass (time running)
/// - 84-100%: Target/bullseye (finish it!)
class _PhaseProgressIconPainter extends CustomPainter {
  final double progress; // 0.0 = just started, 1.0 = phase ending
  final Color themeColor;
  final double pulseValue;

  _PhaseProgressIconPainter({
    required this.progress,
    required this.themeColor,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.4;

    if (progress <= 0.33) {
      _drawCrossedSwords(canvas, cx, cy, r, themeColor, pulseValue);
    } else if (progress <= 0.66) {
      _drawShield(canvas, cx, cy, r, themeColor);
    } else if (progress <= 0.83) {
      _drawHourglass(canvas, cx, cy, r, Colors.orange, pulseValue);
    } else {
      _drawTarget(canvas, cx, cy, r, Colors.red, pulseValue);
    }
  }

  void _drawCrossedSwords(Canvas canvas, double cx, double cy, double r, Color c, double pulse) {
    final glowAlpha = 0.3 + pulse * 0.3;
    final paint = Paint()
      ..color = c
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final glowPaint = Paint()
      ..color = c.withValues(alpha: glowAlpha)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    // Sword 1: top-left to bottom-right
    canvas.drawLine(Offset(cx - r, cy - r * 0.8), Offset(cx + r, cy + r * 0.8), glowPaint);
    canvas.drawLine(Offset(cx - r, cy - r * 0.8), Offset(cx + r, cy + r * 0.8), paint);
    // Sword 2: top-right to bottom-left
    canvas.drawLine(Offset(cx + r, cy - r * 0.8), Offset(cx - r, cy + r * 0.8), glowPaint);
    canvas.drawLine(Offset(cx + r, cy - r * 0.8), Offset(cx - r, cy + r * 0.8), paint);
    // Cross guards (short perpendicular lines at 1/3 from top)
    final guardY = cy - r * 0.3;
    canvas.drawLine(Offset(cx - r * 0.5, guardY - r * 0.15), Offset(cx - r * 0.5, guardY + r * 0.15), paint);
    canvas.drawLine(Offset(cx + r * 0.5, guardY - r * 0.15), Offset(cx + r * 0.5, guardY + r * 0.15), paint);
  }

  void _drawShield(Canvas canvas, double cx, double cy, double r, Color c) {
    final shieldPath = Path();
    shieldPath.moveTo(cx, cy - r);
    shieldPath.quadraticBezierTo(cx + r * 0.9, cy - r * 0.7, cx + r * 0.7, cy);
    shieldPath.quadraticBezierTo(cx + r * 0.5, cy + r * 0.6, cx, cy + r);
    shieldPath.quadraticBezierTo(cx - r * 0.5, cy + r * 0.6, cx - r * 0.7, cy);
    shieldPath.quadraticBezierTo(cx - r * 0.9, cy - r * 0.7, cx, cy - r);
    shieldPath.close();
    // Glow
    canvas.drawPath(shieldPath, Paint()
      ..color = c.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    // Fill
    canvas.drawPath(shieldPath, Paint()..color = c.withValues(alpha: 0.7));
    // Border
    canvas.drawPath(shieldPath, Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    // Chevron in center
    final chevronPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - r * 0.25, cy - r * 0.1), Offset(cx, cy - r * 0.35), chevronPaint);
    canvas.drawLine(Offset(cx, cy - r * 0.35), Offset(cx + r * 0.25, cy - r * 0.1), chevronPaint);
  }

  void _drawHourglass(Canvas canvas, double cx, double cy, double r, Color c, double pulse) {
    final scale = 1.0 + pulse * 0.08;
    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(scale, scale);
    canvas.translate(-cx, -cy);

    // Hourglass shape
    final path = Path();
    // Top triangle (wide at top, narrow at center)
    path.moveTo(cx - r * 0.6, cy - r);
    path.lineTo(cx + r * 0.6, cy - r);
    path.lineTo(cx + r * 0.08, cy);
    path.lineTo(cx - r * 0.08, cy);
    path.close();
    // Bottom triangle (narrow at center, wide at bottom)
    path.moveTo(cx - r * 0.08, cy);
    path.lineTo(cx + r * 0.08, cy);
    path.lineTo(cx + r * 0.6, cy + r);
    path.lineTo(cx - r * 0.6, cy + r);
    path.close();

    // Glow
    canvas.drawPath(path, Paint()
      ..color = c.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    // Fill
    canvas.drawPath(path, Paint()..color = c.withValues(alpha: 0.7));
    // Border
    canvas.drawPath(path, Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    // Top/bottom bars
    canvas.drawLine(Offset(cx - r * 0.7, cy - r), Offset(cx + r * 0.7, cy - r),
      Paint()..color = c..strokeWidth = 3..strokeCap = StrokeCap.round);
    canvas.drawLine(Offset(cx - r * 0.7, cy + r), Offset(cx + r * 0.7, cy + r),
      Paint()..color = c..strokeWidth = 3..strokeCap = StrokeCap.round);

    canvas.restore();
  }

  void _drawTarget(Canvas canvas, double cx, double cy, double r, Color c, double pulse) {
    final glowAlpha = 0.3 + pulse * 0.4;
    // Outer glow pulse
    canvas.drawCircle(Offset(cx, cy), r * 1.2, Paint()
      ..color = c.withValues(alpha: glowAlpha * 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    // Rings
    for (int i = 3; i >= 1; i--) {
      final ringR = r * (i / 3);
      final ringPaint = Paint()
        ..color = i.isOdd ? c : Colors.white
        ..style = i == 3 ? PaintingStyle.fill : PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, cy), ringR, ringPaint);
    }
    // Bullseye center
    canvas.drawCircle(Offset(cx, cy), r * 0.15, Paint()..color = Colors.white);
    // Urgency lines radiating outward
    final linePaint = Paint()
      ..color = c.withValues(alpha: 0.6 + pulse * 0.3)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 8; i++) {
      final angle = i * pi / 4;
      final x1 = cx + cos(angle) * r * 1.1;
      final y1 = cy + sin(angle) * r * 1.1;
      final x2 = cx + cos(angle) * r * 1.4;
      final y2 = cy + sin(angle) * r * 1.4;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), linePaint);
    }
  }

  @override
  bool shouldRepaint(_PhaseProgressIconPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      themeColor != oldDelegate.themeColor ||
      pulseValue != oldDelegate.pulseValue;
}

/// Pulsing pause icon for the pause overlay (replaces static icon + "PAUSED" text).
class _PulsingPauseIcon extends StatefulWidget {
  final Color color;
  const _PulsingPauseIcon({required this.color});

  @override
  State<_PulsingPauseIcon> createState() => _PulsingPauseIconState();
}

class _PulsingPauseIconState extends State<_PulsingPauseIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final scale = 1.0 + _controller.value * 0.08;
        final alpha = 0.4 + _controller.value * 0.3;
        return Transform.scale(
          scale: scale,
          child: Icon(
            Icons.pause_circle_filled,
            size: 80,
            color: widget.color.withValues(alpha: alpha),
          ),
        );
      },
    );
  }
}
