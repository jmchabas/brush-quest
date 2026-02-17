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
import '../widgets/space_background.dart';
import '../widgets/mute_button.dart';
import '../widgets/glass_card.dart';
import 'victory_screen.dart';

class BrushingScreen extends StatefulWidget {
  const BrushingScreen({super.key});

  @override
  State<BrushingScreen> createState() => _BrushingScreenState();
}

enum BrushPhase { gearUp, countdown, topLeft, topRight, bottomLeft, bottomRight, done }

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

// Monster in multi-monster grid
class _MonsterSlot {
  final int imageIndex;
  double health; // 1.0 = full, 0.0 = dead
  bool alive;
  double hitRecoil;        // 0→1→0: set to 1.0 on attack, decays per tick
  double wobblePhase;      // random offset so each monster wobbles out of sync
  bool isDefeating;
  double defeatProgress;   // 0→1 during death explosion
  final List<_MonsterDebris> debris;
  _MonsterSlot({
    required this.imageIndex, required this.health, required this.alive,
    required this.wobblePhase,
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

  BrushPhase _phase = BrushPhase.gearUp;
  int _countdownValue = 3;
  int _phaseSecondsLeft = 30;
  Timer? _timer;
  Timer? _attackTimer;
  bool _isPaused = false;
  bool _showGoText = false;

  // Animation controllers
  late AnimationController _gearUpController;
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

  // Multi-monster system: 4 quadrants, each with 2-3 monsters
  late List<List<_MonsterSlot>> _quadrantMonsters;
  int _currentQuadrant = 0;
  // Star collection system
  int _starsCollected = 0;
  int _attacksSinceLastStar = 0;
  final List<_FloatingStar> _floatingStars = [];
  Timer? _starCleanupTimer;

  // Camera & motion detection
  bool _cameraReady = false;
  int _lastAttackTime = 0; // milliseconds since epoch
  static const int _minAttackCooldownMs = 700;
  static const int _mercyAttackIntervalMs = 5000; // fallback auto-attack when no motion
  Timer? _mercyAttackTimer;

  static const _phaseLabels = {
    BrushPhase.topLeft: 'BRUSH TOP LEFT!',
    BrushPhase.topRight: 'BRUSH TOP RIGHT!',
    BrushPhase.bottomLeft: 'BRUSH BOTTOM LEFT!',
    BrushPhase.bottomRight: 'BRUSH BOTTOM RIGHT!',
  };

  static const _phaseVoiceFiles = {
    BrushPhase.topLeft: 'voice_top_left.mp3',
    BrushPhase.topRight: 'voice_top_right.mp3',
    BrushPhase.bottomLeft: 'voice_bottom_left.mp3',
    BrushPhase.bottomRight: 'voice_bottom_right.mp3',
  };

  static const _phaseArrowRotations = {
    BrushPhase.topLeft: -0.785,
    BrushPhase.topRight: 0.785,
    BrushPhase.bottomLeft: -2.356,
    BrushPhase.bottomRight: 2.356,
  };

  static const _monsterImages = [
    'assets/images/monster_purple.png',
    'assets/images/monster_green.png',
    'assets/images/monster_orange.png',
    'assets/images/monster_red.png',
  ];

  static const _encouragementVoices = [
    'voice_keep_going.mp3',
    'voice_youre_doing_great.mp3',
    'voice_almost_there.mp3',
  ];

  static const _damageTexts = ['POW!', 'ZAP!', 'BOOM!', 'WHAM!', 'BAM!', 'SLASH!', 'SMASH!', 'HIT!'];

  bool _playedEncouragement = false;
  bool _playedAlmostThere = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();

    // Init multi-monster grid (will be set properly in _loadHeroAndWorld)
    _initMonsterGrid();

    _gearUpController = AnimationController(
      duration: const Duration(milliseconds: 2500), vsync: this,
    );
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

    _initParticles();
    _loadHeroAndWorld();
    _initCamera();
    _startGearUp();

    _damageCleanupTimer = Timer.periodic(
      const Duration(milliseconds: 40),
      (_) => _cleanupEffects(),
    );
    _starCleanupTimer = Timer.periodic(
      const Duration(milliseconds: 30),
      (_) => _updateFloatingStars(),
    );
  }

  void _initMonsterGrid() {
    _quadrantMonsters = List.generate(4, (qi) {
      final count = 2 + _random.nextInt(2); // 2-3 monsters per quadrant
      return List.generate(count, (mi) {
        return _MonsterSlot(
          imageIndex: _random.nextInt(_monsterImages.length),
          health: 1.0, alive: true,
          wobblePhase: _random.nextDouble() * 2 * pi,
        );
      });
    });
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

    // Decay hit recoil and update debris for all monsters
    for (final quadrant in _quadrantMonsters) {
      for (final m in quadrant) {
        if (m.hitRecoil > 0.01) {
          m.hitRecoil -= 0.06;
          if (m.hitRecoil < 0.01) m.hitRecoil = 0.0;
        }
        if (m.isDefeating) {
          m.defeatProgress += 0.025;
          if (m.defeatProgress >= 1.0) {
            m.isDefeating = false;
            m.defeatProgress = 1.0;
            m.debris.clear();
          }
        }
        for (final d in m.debris) {
          d.x += d.vx;
          d.y += d.vy;
          d.vy += 0.4; // gravity
          d.rotation += d.rotationSpeed;
          d.life -= 0.03;
        }
        m.debris.removeWhere((d) => d.life <= 0);
      }
    }
  }

  void _updateFloatingStars() {
    if (!mounted || _floatingStars.isEmpty) return;
    setState(() {
      for (final star in _floatingStars) {
        star.progress += 0.025;
        // Wobble path
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
    await _cameraService.initialize();
    if (mounted) {
      setState(() {
        _cameraReady = _cameraService.isAvailable;
      });
    }
  }

  void _startMotionDetection() {
    if (!_cameraReady) return;
    _cameraService.startMotionDetection((intensity) {
      if (!mounted || _isPaused || _phase == BrushPhase.done) return;

      // Motion threshold to trigger attack
      if (intensity < 0.08) return; // Too little motion, ignore

      final now = DateTime.now().millisecondsSinceEpoch;
      // Map intensity to cooldown: high motion = shorter cooldown
      // intensity 0.08-0.3 (slow) → 2500ms, 0.3-0.6 (med) → 1500ms, 0.6+ (fast) → 700ms
      final int dynamicCooldown;
      if (intensity > 0.6) {
        dynamicCooldown = _minAttackCooldownMs;
      } else if (intensity > 0.3) {
        dynamicCooldown = 1500;
      } else {
        dynamicCooldown = 2500;
      }

      if (now - _lastAttackTime >= dynamicCooldown) {
        _lastAttackTime = now;
        _triggerAttack();
        // Reset mercy timer since we just attacked
        _resetMercyTimer();
      }
    });
  }

  void _stopMotionDetection() {
    _cameraService.stopMotionDetection();
    _mercyAttackTimer?.cancel();
  }

  /// Mercy auto-attack: fires if no motion-triggered attack for 5 seconds.
  /// Ensures the kid still makes progress even when holding still briefly.
  void _startMercyTimer() {
    _mercyAttackTimer?.cancel();
    _mercyAttackTimer = Timer.periodic(
      Duration(milliseconds: _mercyAttackIntervalMs),
      (_) {
        if (mounted && !_isPaused && _phase != BrushPhase.done &&
            _phase != BrushPhase.countdown && _phase != BrushPhase.gearUp) {
          _triggerAttack();
          _lastAttackTime = DateTime.now().millisecondsSinceEpoch;
        }
      },
    );
  }

  void _resetMercyTimer() {
    _mercyAttackTimer?.cancel();
    _startMercyTimer();
  }

  Future<void> _loadHeroAndWorld() async {
    final hero = await _heroService.getSelectedHero();
    final world = await _worldService.getCurrentWorld();
    final weapon = await _weaponService.getSelectedWeapon();
    if (mounted) {
      setState(() {
        _hero = hero;
        _world = world;
        _weapon = weapon;
        // Re-init monsters with world-specific indices
        _quadrantMonsters = List.generate(4, (qi) {
          final count = 2 + _random.nextInt(2);
          return List.generate(count, (mi) {
            return _MonsterSlot(
              imageIndex: world.monsterIndices[_random.nextInt(world.monsterIndices.length)],
              health: 1.0, alive: true,
              wobblePhase: _random.nextDouble() * 2 * pi,
            );
          });
        });
        _initParticles();
      });
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _timer?.cancel();
    _attackTimer?.cancel();
    _mercyAttackTimer?.cancel();
    _damageCleanupTimer?.cancel();
    _starCleanupTimer?.cancel();
    _stopMotionDetection();
    _gearUpController.dispose();
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
    _audio.stopMusic();
    super.dispose();
  }

  // ==================== GEAR-UP SEQUENCE ====================

  void _startGearUp() {
    _audio.playVoice('voice_gear_up.mp3');
    Timer(const Duration(milliseconds: 0), () {
      if (mounted) _audio.playSfx('gear_up_power.mp3');
    });
    Timer(const Duration(milliseconds: 400), () {
      if (mounted) _audio.playSfx('gear_up_equip.mp3');
    });
    Timer(const Duration(milliseconds: 900), () {
      if (mounted) _audio.playSfx('gear_up_shield.mp3');
    });
    Timer(const Duration(milliseconds: 1900), () {
      if (mounted) _audio.playSfx('gear_up_ready.mp3');
    });

    _gearUpController.forward(from: 0).then((_) {
      if (mounted) _startCountdown();
    });
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
    _currentQuadrant = 0;
    _totalHits = 0;
    _attackStyleIndex = 0;
    _starsCollected = 0;
    _attacksSinceLastStar = 0;

    // Start battle music
    _audio.playMusic('battle_music.mp3');

    _switchToPhase(BrushPhase.topLeft);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPaused) return;
      setState(() => _phaseSecondsLeft--);

      // Damage monsters as time passes
      _damageCurrentMonsters();

      if (_phaseSecondsLeft == 20 && !_playedEncouragement) {
        _playedEncouragement = true;
        _audio.playVoice(_encouragementVoices[_random.nextInt(_encouragementVoices.length)]);
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
            _killAllMonstersInQuadrant(_currentQuadrant);
            _collectStars(1); // Phase transition bonus
            _playDefeatAnimation(() {
              _currentQuadrant = currentIndex + 1;
              _switchToPhase(brushPhaseOrder[currentIndex + 1]);
              _playEntranceAnimation();
            });
          });
        } else {
          _triggerFinisher(() {
            _killAllMonstersInQuadrant(_currentQuadrant);
            _collectStars(1);
            _playDefeatAnimation(() { timer.cancel(); _finishBrushing(); });
          });
        }
      }
    });

    // Use motion-based attacks if camera available, timer fallback otherwise
    if (_cameraReady) {
      _startMotionDetection();
      _startMercyTimer();
    } else {
      _scheduleNextAttack();
    }
  }

  void _damageCurrentMonsters() {
    final monsters = _quadrantMonsters[_currentQuadrant];
    final aliveCount = monsters.where((m) => m.alive).length;
    if (aliveCount == 0) return;

    // Distribute damage: each second removes 1/30 of total quadrant health
    final damagePerSecond = 1.0 / 30.0 * aliveCount;
    for (final m in monsters) {
      if (m.alive) {
        m.health -= damagePerSecond / aliveCount;
        if (m.health <= 0) {
          _startMonsterDeath(m);
          _collectStars(2); // Monster defeated bonus
          _audio.playSfx('monster_defeat.mp3');
          HapticFeedback.mediumImpact();
        }
      }
    }
  }

  void _killAllMonstersInQuadrant(int qi) {
    for (final m in _quadrantMonsters[qi]) {
      if (m.alive) _startMonsterDeath(m);
    }
  }

  void _startMonsterDeath(_MonsterSlot monster) {
    monster.alive = false;
    monster.health = 0;
    monster.isDefeating = true;
    monster.defeatProgress = 0.0;
    monster.debris.clear();
    for (int i = 0; i < 10; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed = 3.0 + _random.nextDouble() * 6;
      monster.debris.add(_MonsterDebris(
        x: 0, y: 0,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed - 2,
        rotation: _random.nextDouble() * 2 * pi,
        rotationSpeed: (_random.nextDouble() - 0.5) * 0.3,
        size: 4 + _random.nextDouble() * 8,
        color: _world.themeColor,
      ));
    }
  }

  void _collectStars(int count) {
    setState(() {
      _starsCollected += count;
      // Spawn floating stars
      for (int i = 0; i < count; i++) {
        _floatingStars.add(_FloatingStar(
          x: 100 + _random.nextDouble() * 200,
          y: 200 + _random.nextDouble() * 100,
          targetX: MediaQuery.of(context).size.width - 50,
          targetY: 40,
          progress: 0,
          size: 20,
        ));
      }
    });
    _audio.playSfx('voice_star_collected.mp3');
  }

  /// Legacy timer-based attack scheduling (fallback when camera unavailable).
  void _scheduleNextAttack() {
    if (_isPaused || _phase == BrushPhase.countdown || _phase == BrushPhase.gearUp || _phase == BrushPhase.done) return;
    final delay = 2000 + _random.nextInt(1000);
    _attackTimer = Timer(Duration(milliseconds: delay), () {
      if (mounted && !_isPaused && _phase != BrushPhase.done) {
        _triggerAttack();
        _scheduleNextAttack();
      }
    });
  }

  void _triggerFinisher(VoidCallback onComplete) {
    _attackTimer?.cancel();
    _mercyAttackTimer?.cancel();
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
    _attackTimer?.cancel();
    _mercyAttackTimer?.cancel();
    _audio.playSfx('monster_defeat.mp3');
    HapticFeedback.heavyImpact();
    _flashController.forward(from: 0).then((_) => _flashController.reverse());
    _spawnDefeatSparks();
    // Wait for per-monster death animations, then proceed
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
        // Motion-driven attacks don't need re-scheduling (stream is running).
        // Only restart timer-based fallback if no camera.
        if (!_cameraReady) {
          _scheduleNextAttack();
        }
      }
    });
  }

  void _switchToPhase(BrushPhase newPhase) {
    setState(() { _phase = newPhase; _phaseSecondsLeft = 30; });
    _phaseTransitionController.forward(from: 0);
    _audio.playSfx('whoosh.mp3');
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _phaseVoiceFiles.containsKey(newPhase)) {
        _audio.playVoice(_phaseVoiceFiles[newPhase]!);
      }
    });
  }

  void _triggerAttack() {
    _audio.playSfx('zap.mp3');
    HapticFeedback.lightImpact();

    setState(() {
      _totalHits++;
      _attackStyleIndex = _totalHits % AttackStyle.values.length;
      _attacksSinceLastStar++;
      // Hit recoil on alive monsters in current quadrant
      for (final m in _quadrantMonsters[_currentQuadrant]) {
        if (m.alive) m.hitRecoil = 1.0;
      }
    });

    // Every 3rd attack spawns a star
    if (_attacksSinceLastStar >= 3) {
      _attacksSinceLastStar = 0;
      _collectStars(1);
    }

    _attackSequenceController.forward(from: 0);
    _screenShakeController.forward(from: 0);
    _flashController.forward(from: 0).then((_) => _flashController.reverse());

    _spawnDamagePopup();
    _spawnHitSparks();
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
      _attackTimer?.cancel();
    } else {
      _monsterBreathController.repeat(reverse: true);
      _heroIdleController.repeat(reverse: true);
      _scheduleNextAttack();
    }
  }

  void _quitBrushing() {
    _timer?.cancel();
    _attackTimer?.cancel();
    _audio.stopMusic();
    Navigator.of(context).pop();
  }

  void _finishBrushing() {
    _attackTimer?.cancel();
    _mercyAttackTimer?.cancel();
    _stopMotionDetection();
    _audio.stopMusic();
    setState(() => _phase = BrushPhase.done);
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            VictoryScreen(starsCollected: _starsCollected),
        transitionsBuilder: (context, anim, secondaryAnimation, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  String _getEncouragementText() {
    if (_phaseSecondsLeft > 20) return 'FIGHT THOSE MONSTERS!';
    if (_phaseSecondsLeft > 10) return 'KEEP BRUSHING!';
    if (_phaseSecondsLeft > 5) return 'ALMOST THERE!';
    return 'FINISH THEM OFF!';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) { if (!didPop) _togglePause(); },
      child: _phase == BrushPhase.gearUp
          ? _buildGearUp()
          : _phase == BrushPhase.countdown
              ? _buildCountdown()
              : _buildBrushing(),
    );
  }

  // ==================== GEAR-UP UI ====================

  Widget _buildGearUp() {
    return Scaffold(
      body: SpaceBackground(
        child: Center(
          child: AnimatedBuilder(
            animation: _gearUpController,
            builder: (context, _) {
              final t = _gearUpController.value;
              return Stack(
                alignment: Alignment.center,
                children: [
                  if (t > 0.56)
                    _buildShieldAura(((t - 0.56) / 0.44).clamp(0, 1)),

                  if (t > 0.76)
                    Container(
                      color: Colors.white.withValues(alpha: ((t - 0.76) / 0.24).clamp(0, 0.6)),
                    ),

                  if (t < 0.36)
                    Transform.translate(
                      offset: Offset(0, 300 * (1.0 - Curves.elasticOut.transform((t / 0.16).clamp(0, 1)))),
                      child: Transform.scale(
                        scale: Curves.elasticOut.transform((t / 0.16).clamp(0, 1)),
                        child: _buildGearUpHero(),
                      ),
                    )
                  else
                    _buildGearUpHero(),

                  if (t > 0.16 && t < 0.56)
                    Transform.translate(
                      offset: Offset(
                        200 * (1.0 - Curves.easeOut.transform(((t - 0.16) / 0.2).clamp(0, 1))),
                        -80,
                      ),
                      child: Opacity(
                        opacity: ((t - 0.16) / 0.1).clamp(0, 1),
                        child: _buildEquipIcon(Icons.brush, const Color(0xFF42A5F5)),
                      ),
                    )
                  else if (t >= 0.56)
                    Transform.translate(
                      offset: const Offset(0, -80),
                      child: _buildEquipIcon(Icons.brush, const Color(0xFF42A5F5)),
                    ),

                  if (t > 0.36 && t < 0.76)
                    Transform.translate(
                      offset: Offset(
                        -200 * (1.0 - Curves.easeOut.transform(((t - 0.36) / 0.2).clamp(0, 1))),
                        80,
                      ),
                      child: Opacity(
                        opacity: ((t - 0.36) / 0.1).clamp(0, 1),
                        child: _buildEquipIcon(_weapon.icon, _weapon.primaryColor),
                      ),
                    )
                  else if (t >= 0.76)
                    Transform.translate(
                      offset: const Offset(0, 80),
                      child: _buildEquipIcon(_weapon.icon, _weapon.primaryColor),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGearUpHero() {
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _hero.primaryColor, width: 3),
        boxShadow: [
          BoxShadow(
            color: _hero.primaryColor.withValues(alpha: 0.6),
            blurRadius: 30, spreadRadius: 8,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(_hero.imagePath, fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildEquipIcon(IconData icon, Color color) {
    return Container(
      width: 60, height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.2),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 16)],
      ),
      child: Icon(icon, color: color, size: 32),
    );
  }

  Widget _buildShieldAura(double progress) {
    final size = 100 + progress * 300;
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [
          _hero.primaryColor.withValues(alpha: (1 - progress) * 0.4),
          _hero.attackColor.withValues(alpha: (1 - progress) * 0.2),
          Colors.transparent,
        ]),
      ),
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
    final avatarSize = (screenHeight * 0.14).clamp(100.0, 140.0);
    final monsterSize = 80.0; // Smaller for multi-monster

    return Scaffold(
      body: AnimatedBuilder(
        animation: _screenShakeController,
        builder: (context, child) {
          final t = _screenShakeController.value;
          final sx = sin(t * pi * 6) * 4 * (1 - t);
          final sy = cos(t * pi * 4) * 3 * (1 - t);
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
                    // Phase label + star counter
                    Padding(
                      padding: const EdgeInsets.only(left: 16, right: 76),
                      child: SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
                            .animate(CurvedAnimation(parent: _phaseTransitionController, curve: Curves.elasticOut)),
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              Transform.rotate(
                                angle: _phaseArrowRotations[_phase] ?? 0,
                                child: Icon(Icons.arrow_upward, color: _world.themeColor, size: 28),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(_phaseLabels[_phase] ?? '', maxLines: 1,
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      color: _world.themeColor, fontWeight: FontWeight.bold, fontSize: 24, letterSpacing: 2,
                                    )),
                                ),
                              ),
                              // Star counter
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star, color: Colors.yellowAccent, size: 18),
                                    const SizedBox(width: 3),
                                    Text('$_starsCollected',
                                      style: const TextStyle(
                                        color: Colors.yellowAccent,
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

                    const Spacer(),

                    // === BATTLE ARENA with multi-monster + camera center ===
                    SizedBox(
                      height: screenHeight * 0.52,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Monster clusters in 4 corners
                          ..._buildMonsterClusters(screenWidth, screenHeight * 0.52, monsterSize),

                          // Hero avatar in center
                          _buildCenterAvatar(avatarSize),

                          // Battle effect overlay
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
                              size: Size(screenWidth, screenHeight * 0.52),
                              painter: _HitSparkPainter(sparks: _hitSparks),
                            ),
                          ),

                          // Damage popups
                          ..._damagePopups.map((popup) => Positioned(
                            left: popup.x * screenWidth - 40,
                            top: popup.offsetY + 40,
                            child: Transform.rotate(
                              angle: popup.rotation,
                              child: Transform.scale(
                                scale: popup.scale,
                                child: Opacity(
                                  opacity: popup.opacity.clamp(0, 1),
                                  child: Text(popup.text, style: TextStyle(
                                    color: popup.color, fontSize: 22, fontWeight: FontWeight.bold,
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
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Health bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: SizedBox(
                              height: 24,
                              child: LinearProgressIndicator(
                                value: _phaseSecondsLeft / 30.0,
                                backgroundColor: Colors.white.withValues(alpha: 0.1),
                                valueColor: AlwaysStoppedAnimation(
                                  Color.lerp(const Color(0xFFFF5252), _world.themeColor, _phaseSecondsLeft / 30.0)!,
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: Center(
                              child: Text('${_phaseSecondsLeft}s',
                                style: const TextStyle(
                                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold,
                                  shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Timer
                    _buildTimer(screenHeight),
                    const SizedBox(height: 4),
                    Text(_getEncouragementText(), style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _phaseSecondsLeft <= 5 ? Colors.orangeAccent : _world.themeColor,
                      fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 15,
                    )),
                    const SizedBox(height: 12),
                  ],
                ),
              ),

              // Controls
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, right: 8),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
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

  // ==================== CENTER AVATAR ====================

  Widget _buildCenterAvatar(double size) {
    final avatar = ClipOval(
      child: Image.asset(_hero.imagePath, width: size, height: size, fit: BoxFit.cover),
    );

    return AnimatedBuilder(
      animation: _heroIdleController,
      builder: (context, child) {
        final pulse = 0.3 + _heroIdleController.value * 0.3;
        final bob = sin(_heroIdleController.value * pi) * 3;
        return Transform.translate(
          offset: Offset(0, bob),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow
              Container(
                width: size + 16, height: size + 16,
                decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                  BoxShadow(color: _hero.primaryColor.withValues(alpha: pulse), blurRadius: 20, spreadRadius: 4),
                ]),
              ),
              child!,
              // Ring border
              Container(
                width: size, height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _hero.primaryColor.withValues(alpha: 0.8), width: 3),
                ),
              ),
            ],
          ),
        );
      },
      child: avatar,
    );
  }

  // ==================== MULTI-MONSTER CLUSTERS ====================

  List<Widget> _buildMonsterClusters(double areaWidth, double areaHeight, double monsterSize) {
    final widgets = <Widget>[];

    // Position offsets for 4 quadrants: TL, TR, BL, BR
    final positions = [
      Offset(areaWidth * 0.12, areaHeight * 0.08),   // top-left
      Offset(areaWidth * 0.60, areaHeight * 0.08),   // top-right
      Offset(areaWidth * 0.08, areaHeight * 0.55),   // bottom-left
      Offset(areaWidth * 0.62, areaHeight * 0.55),   // bottom-right
    ];

    for (int qi = 0; qi < 4; qi++) {
      final monsters = _quadrantMonsters[qi];
      final isActive = qi == _currentQuadrant;
      final basePos = positions[qi];

      for (int mi = 0; mi < monsters.length; mi++) {
        final m = monsters[mi];
        if (!m.alive && !m.isDefeating) continue; // Hide fully dead monsters

        final offsetX = (mi % 2) * (monsterSize * 0.55);
        final offsetY = (mi ~/ 2) * (monsterSize * 0.45);

        widgets.add(Positioned(
          left: basePos.dx + offsetX,
          top: basePos.dy + offsetY,
          child: _buildSingleMonster(m, monsterSize, isActive, qi),
        ));
      }
    }

    return widgets;
  }

  Widget _buildSingleMonster(_MonsterSlot monster, double size, bool isActive, int quadrantIndex) {
    final damageProgress = 1.0 - monster.health;

    // Fully dead — hide
    if (!monster.alive && !monster.isDefeating) return const SizedBox.shrink();

    final displaySize = size * 0.85;

    // Death explosion — just the painter
    if (monster.isDefeating) {
      return SizedBox(
        width: displaySize + 40,
        height: displaySize + 40,
        child: AnimatedBuilder(
          animation: _particleController,
          builder: (context, _) => CustomPaint(
            painter: _MonsterDeathPainter(
              progress: monster.defeatProgress,
              debris: monster.debris,
              themeColor: _world.themeColor,
            ),
          ),
        ),
      );
    }

    // Build monster image (with blue tint for inactive)
    Widget monsterImage = ClipOval(
      child: Image.asset(
        _monsterImages[monster.imageIndex],
        width: displaySize, height: displaySize, fit: BoxFit.cover,
      ),
    );
    if (!isActive) {
      monsterImage = ColorFiltered(
        colorFilter: ColorFilter.mode(
          Colors.blue.withValues(alpha: 0.3), BlendMode.srcATop,
        ),
        child: monsterImage,
      );
    }

    // Alive monster with full animations
    Widget monsterWidget = AnimatedBuilder(
      animation: _monsterBreathController,
      builder: (context, child) {
        final breathT = _monsterBreathController.value;

        double scaleX = 1.0, scaleY = 1.0, rotation = 0.0;
        double translateX = 0.0, translateY = 0.0;

        if (isActive) {
          // Active: 6% wobble + rotation oscillation
          final wobble = sin((breathT + monster.wobblePhase) * pi);
          scaleX = 1.0 + wobble * 0.06;
          scaleY = 1.0 + wobble * 0.06;
          rotation = sin((breathT + monster.wobblePhase) * pi * 2) * 0.04;

          // Damage shake: more damaged = more erratic
          if (damageProgress > 0.3) {
            final intensity = (damageProgress - 0.3) * 8;
            translateX += sin(breathT * pi * 12 + monster.wobblePhase) * intensity;
            translateY += cos(breathT * pi * 10 + monster.wobblePhase) * intensity * 0.5;
            rotation += sin(breathT * pi * 8) * (damageProgress - 0.3) * 0.08;
          }

          // Lean toward center
          translateX += (quadrantIndex % 2 == 0 ? 3.0 : -3.0) * breathT;
          translateY += (quadrantIndex < 2 ? 3.0 : -3.0) * breathT;

          // Hit recoil: squash/stretch + knockback
          if (monster.hitRecoil > 0.01) {
            if (monster.hitRecoil > 0.5) {
              final t = (monster.hitRecoil - 0.5) * 2;
              scaleX *= 1.0 + t * 0.3;
              scaleY *= 1.0 - t * 0.2;
            } else {
              final t = monster.hitRecoil * 2;
              scaleX *= 1.0 - t * 0.1;
              scaleY *= 1.0 + t * 0.08;
            }
            final knockback = monster.hitRecoil * 12;
            switch (quadrantIndex) {
              case 0: translateX -= knockback; translateY -= knockback;
              case 1: translateX += knockback; translateY -= knockback;
              case 2: translateX -= knockback; translateY += knockback;
              case 3: translateX += knockback; translateY += knockback;
            }
          }
        } else {
          // Inactive: gentle 2% slow bob
          translateY = sin(breathT * pi + monster.wobblePhase) * 3;
          final gentle = 1.0 + sin(breathT * pi) * 0.02;
          scaleX = gentle;
          scaleY = gentle;
        }

        // Computed animation values for children
        final shadowScale = 0.9 + breathT * 0.1;
        final glowAlpha = isActive
            ? (0.15 + breathT * 0.15) * (0.5 + damageProgress * 0.5)
            : 0.0;

        return Transform.translate(
          offset: Offset(translateX, translateY),
          child: Transform.rotate(
            angle: rotation,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(scaleX, scaleY, 1.0),
              child: SizedBox(
              width: displaySize + 20,
              height: displaySize + 30,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Shadow ellipse underneath
                  Positioned(
                    bottom: 0,
                    child: Transform.scale(
                      scale: shadowScale,
                      child: Container(
                        width: displaySize * 0.7,
                        height: displaySize * 0.15,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(displaySize),
                          boxShadow: [BoxShadow(
                            color: Colors.black.withValues(alpha: isActive ? 0.5 : 0.2),
                            blurRadius: 8, spreadRadius: 2,
                          )],
                        ),
                      ),
                    ),
                  ),
                  // Red glow aura (active only)
                  if (glowAlpha > 0.01)
                    Container(
                      width: displaySize + 12, height: displaySize + 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(
                          color: Colors.redAccent.withValues(alpha: glowAlpha),
                          blurRadius: 16, spreadRadius: 4,
                        )],
                      ),
                    ),
                  // Monster image
                  Positioned(bottom: 10, child: child!),
                  // Vignette overlay
                  Positioned(
                    bottom: 10,
                    child: Container(
                      width: displaySize, height: displaySize,
                      decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(
                        colors: [Colors.transparent, Colors.transparent, Colors.black.withValues(alpha: 0.4), Colors.black.withValues(alpha: 0.8)],
                        stops: const [0.0, 0.5, 0.8, 1.0],
                      )),
                    ),
                  ),
                  // Damage cracks (with weapon-color glow at low health)
                  if (damageProgress > 0.3)
                    Positioned(bottom: 10, child: CustomPaint(
                      size: Size(displaySize, displaySize),
                      painter: _DamageCrackPainter(
                        progress: damageProgress, color: Colors.white,
                        glowColor: damageProgress > 0.5 ? _weapon.primaryColor : null,
                      ),
                    )),
                  // Dizzy spiral eyes (50-70% damage)
                  if (damageProgress > 0.5 && damageProgress <= 0.7)
                    Positioned(bottom: 10, child: CustomPaint(
                      size: Size(displaySize, displaySize),
                      painter: _MonsterOverlayPainter(animValue: breathT),
                    )),
                  // Red pulse overlay (> 70% damage)
                  if (damageProgress > 0.7)
                    Positioned(bottom: 10, child: Container(
                      width: displaySize, height: displaySize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red.withValues(alpha: 0.1 + breathT * 0.2),
                      ),
                    )),
                  // White flash on hit
                  if (monster.hitRecoil > 0.6)
                    Positioned(bottom: 10, child: Container(
                      width: displaySize, height: displaySize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: (monster.hitRecoil - 0.6) * 2),
                      ),
                    )),
                  // Sleeping Z's for inactive monsters
                  if (!isActive)
                    Positioned(
                      top: -10, right: -5,
                      child: CustomPaint(
                        size: const Size(40, 50),
                        painter: _SleepingZPainter(animValue: breathT),
                      ),
                    ),
                ],
              ),
            ),
          ),
          ),
        );
      },
      child: monsterImage,
    );

    // Entrance animation
    if (isActive && _monsterEntering) {
      monsterWidget = AnimatedBuilder(
        animation: _monsterEntranceController,
        builder: (context, child) {
          final t = CurvedAnimation(parent: _monsterEntranceController, curve: Curves.bounceOut).value;
          return Transform.scale(scale: 0.3 + t * 0.7, child: Opacity(opacity: t, child: child));
        },
        child: monsterWidget,
      );
    }

    return Opacity(opacity: isActive ? 1.0 : 0.30, child: monsterWidget);
  }

  Widget _buildTimer(double screenHeight) {
    final isUrgent = _phaseSecondsLeft <= 5;
    final isCritical = _phaseSecondsLeft <= 3;
    Widget timerText = Text(
      _phaseSecondsLeft.toString().padLeft(2, '0'),
      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
        fontSize: (screenHeight * 0.06).clamp(40.0, 64.0),
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
    final cy = size.height / 2;
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
        // Orange slash arcs + embers
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
        // Blue shockwave + ice shards
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
        // Ice shard lines
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
        // Yellow zigzag bolts
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
        // Side bolts
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
        // Green whip curves + leaves
        final path = Path();
        path.moveTo(cx - size.width * 0.3, cy + 30);
        path.quadraticBezierTo(
          cx, cy - 40 * impactProgress,
          cx + size.width * 0.3 * impactProgress, cy,
        );
        paint.strokeWidth = lineWidth * 1.5;
        canvas.drawPath(path, paint);
        canvas.drawPath(path, glowPaint);
        // Second vine
        final path2 = Path();
        path2.moveTo(cx + size.width * 0.3, cy + 30);
        path2.quadraticBezierTo(
          cx, cy - 20 * impactProgress,
          cx - size.width * 0.25 * impactProgress, cy + 10,
        );
        canvas.drawPath(path2, paint);
        break;

      case AttackEffectType.cosmicBurst:
        // Rainbow multi-beam + star explosions
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
        // Center star burst
        final starPaint = Paint()
          ..color = Colors.white.withValues(alpha: fadeAlpha * 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
        canvas.drawCircle(Offset(cx, cy), 20 * impactProgress, starPaint);
        break;

      default: // defaultBeam - same as original energyBeam style
        final beamEndY = cy + size.height * 0.3 * (1 - impactProgress);
        paint.strokeWidth = lineWidth * 2;
        canvas.drawLine(Offset(cx, cy + size.height * 0.3), Offset(cx, beamEndY), paint);
        glowPaint.strokeWidth = lineWidth * 5;
        canvas.drawLine(Offset(cx, cy + size.height * 0.3), Offset(cx, beamEndY), glowPaint);
        break;
    }

    // Finisher extra: X-shaped burst
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
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    Paint? glowPaint;
    if (glowColor != null) {
      glowPaint = Paint()
        ..color = glowColor!.withValues(alpha: (progress - 0.3) * 0.5)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    }

    final cracks = (progress * 8).floor();
    final rng = Random(42);
    for (int i = 0; i < cracks; i++) {
      final startAngle = rng.nextDouble() * 2 * pi;
      final len = 15 + rng.nextDouble() * 25;
      final x1 = cx + cos(startAngle) * 10;
      final y1 = cy + sin(startAngle) * 10;
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

// Sleeping Z's floating above inactive monsters
class _SleepingZPainter extends CustomPainter {
  final double animValue;
  _SleepingZPainter({required this.animValue});
  @override
  void paint(Canvas canvas, Size size) {
    final zData = [
      (0.5, 30.0, 14.0),
      (0.3, 20.0, 11.0),
      (0.1, 10.0, 8.0),
    ];
    for (int i = 0; i < zData.length; i++) {
      final (heightFrac, xOff, fontSize) = zData[i];
      final bob = sin(animValue * pi + i * 1.2) * 4;
      final alpha = (0.7 - i * 0.2).clamp(0.0, 1.0);
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'Z',
          style: TextStyle(
            color: const Color(0xFF90CAF9).withValues(alpha: alpha),
            fontSize: fontSize, fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(xOff, size.height * heightFrac + bob));
    }
  }
  @override
  bool shouldRepaint(_SleepingZPainter oldDelegate) => animValue != oldDelegate.animValue;
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
        ..strokeWidth = 1.5;

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

// Per-monster death explosion painter
class _MonsterDeathPainter extends CustomPainter {
  final double progress;
  final List<_MonsterDebris> debris;
  final Color themeColor;

  _MonsterDeathPainter({
    required this.progress, required this.debris, required this.themeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // White flash (0.0-0.3)
    if (progress < 0.3) {
      final flashAlpha = progress < 0.15
          ? (progress / 0.15)
          : ((0.3 - progress) / 0.15);
      final flashPaint = Paint()..color = Colors.white.withValues(alpha: flashAlpha * 0.8);
      canvas.drawCircle(Offset(cx, cy), 30, flashPaint);
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
      final radius = 15 + smokeT * 40;
      final smokeAlpha = (1.0 - smokeT) * 0.5;
      final smokePaint = Paint()
        ..color = Colors.grey.withValues(alpha: smokeAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8 * (1.0 - smokeT)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(cx, cy), radius, smokePaint);
    }

    // Ghost silhouette floats upward and fades (0.4-1.0)
    if (progress > 0.4) {
      final ghostT = ((progress - 0.4) / 0.6).clamp(0.0, 1.0);
      final ghostY = cy - ghostT * 30;
      final ghostAlpha = (1.0 - ghostT) * 0.4;
      final ghostPaint = Paint()
        ..color = themeColor.withValues(alpha: ghostAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(cx, ghostY), 15 * (1.0 - ghostT * 0.5), ghostPaint);
    }
  }

  @override
  bool shouldRepaint(_MonsterDeathPainter oldDelegate) => progress != oldDelegate.progress;
}
