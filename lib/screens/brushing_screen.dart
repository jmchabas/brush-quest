import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/audio_service.dart';
import '../services/hero_service.dart';
import '../services/world_service.dart';
import '../widgets/space_background.dart';
import '../widgets/mute_button.dart';
import '../widgets/glass_card.dart';
import '../widgets/tooth_diagram.dart';
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

// Hit spark — burst from impact point
class _HitSpark {
  double x, y, vx, vy, life, size;
  Color color;
  _HitSpark({
    required this.x, required this.y, required this.vx, required this.vy,
    required this.color, this.life = 1.0, this.size = 3.0,
  });
}

class _BrushingScreenState extends State<BrushingScreen>
    with TickerProviderStateMixin {
  final _audio = AudioService();
  final _heroService = HeroService();
  final _worldService = WorldService();

  HeroCharacter _hero = HeroService.allHeroes[0];
  WorldData _world = WorldService.allWorlds[0];

  BrushPhase _phase = BrushPhase.countdown;
  int _countdownValue = 3;
  int _phaseSecondsLeft = 30;
  Timer? _timer;
  Timer? _attackTimer; // Sub-second attack timer
  bool _isPaused = false;
  bool _showGoText = false;

  // Animation controllers
  late AnimationController _monsterController;
  late Animation<double> _monsterShake;
  late AnimationController _zapController;
  late Animation<double> _zapOpacity;
  late AnimationController _phaseTransitionController;
  late AnimationController _monsterDefeatController;
  late AnimationController _monsterEntranceController;
  late AnimationController _flashController;
  late AnimationController _heroAttackController;
  late AnimationController _screenShakeController;
  late AnimationController _monsterBreathController;
  late AnimationController _particleController;
  late AnimationController _timerPulseController;
  late AnimationController _heroIdleController;
  late AnimationController _monsterHitController;
  late AnimationController _comboFlashController;
  late AnimationController _superAttackController;

  bool _monsterDefeating = false;
  bool _monsterEntering = false;

  final _random = Random();
  late List<int> _monsterOrder;

  // Combat system
  int _comboCount = 0;
  double _powerMeter = 0; // 0..1
  bool _superAttackActive = false;
  int _attackType = 0; // 0=slash, 1=beam, 2=explosion, cycles
  int _totalHits = 0;

  // Damage popups + sparks
  final List<_DamagePopup> _damagePopups = [];
  final List<_HitSpark> _hitSparks = [];
  Timer? _damageCleanupTimer;

  // Battle particles
  final List<_Particle> _particles = [];

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

  int _currentMonsterIndex = 0;
  bool _playedEncouragement = false;
  bool _playedAlmostThere = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _monsterOrder = [0, 1, 2, 3]..shuffle(_random);

    _monsterController = AnimationController(
      duration: const Duration(milliseconds: 300), vsync: this,
    )..repeat(reverse: true);
    _monsterShake = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _monsterController, curve: Curves.easeInOut),
    );

    _zapController = AnimationController(
      duration: const Duration(milliseconds: 400), vsync: this,
    );
    _zapOpacity = Tween<double>(begin: 0, end: 1).animate(_zapController);

    _phaseTransitionController = AnimationController(
      duration: const Duration(milliseconds: 500), vsync: this,
    );
    _monsterDefeatController = AnimationController(
      duration: const Duration(milliseconds: 600), vsync: this,
    );
    _monsterEntranceController = AnimationController(
      duration: const Duration(milliseconds: 600), vsync: this,
    );
    _flashController = AnimationController(
      duration: const Duration(milliseconds: 120), vsync: this,
    );
    _heroAttackController = AnimationController(
      duration: const Duration(milliseconds: 350), vsync: this,
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

    // Hero idle bob
    _heroIdleController = AnimationController(
      duration: const Duration(milliseconds: 1200), vsync: this,
    )..repeat(reverse: true);

    // Monster flinch on hit
    _monsterHitController = AnimationController(
      duration: const Duration(milliseconds: 200), vsync: this,
    );

    // Combo flash
    _comboFlashController = AnimationController(
      duration: const Duration(milliseconds: 300), vsync: this,
    );

    // Super attack
    _superAttackController = AnimationController(
      duration: const Duration(milliseconds: 1200), vsync: this,
    );

    _initParticles();
    _loadHeroAndWorld();
    _startCountdown();

    _damageCleanupTimer = Timer.periodic(
      const Duration(milliseconds: 40),
      (_) => _cleanupEffects(),
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
    // Update world particles
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
    // Update hit sparks
    for (final s in _hitSparks) {
      s.x += s.vx;
      s.y += s.vy;
      s.vy += 0.3; // gravity
      s.life -= 0.05;
    }
    _hitSparks.removeWhere((s) => s.life <= 0);
  }

  Future<void> _loadHeroAndWorld() async {
    final hero = await _heroService.getSelectedHero();
    final world = await _worldService.getCurrentWorld();
    if (mounted) {
      setState(() {
        _hero = hero;
        _world = world;
        _monsterOrder = List<int>.from(world.monsterIndices)..shuffle(_random);
        while (_monsterOrder.length < 4) {
          _monsterOrder.add(world.monsterIndices[_monsterOrder.length % world.monsterIndices.length]);
        }
        _initParticles();
      });
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _timer?.cancel();
    _attackTimer?.cancel();
    _damageCleanupTimer?.cancel();
    _monsterController.dispose();
    _zapController.dispose();
    _phaseTransitionController.dispose();
    _monsterDefeatController.dispose();
    _monsterEntranceController.dispose();
    _flashController.dispose();
    _heroAttackController.dispose();
    _screenShakeController.dispose();
    _monsterBreathController.dispose();
    _particleController.removeListener(_updateParticlesAndSparks);
    _particleController.dispose();
    _timerPulseController.dispose();
    _heroIdleController.dispose();
    _monsterHitController.dispose();
    _comboFlashController.dispose();
    _superAttackController.dispose();
    super.dispose();
  }

  void _startCountdown() {
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

  void _startBrushing() {
    _currentMonsterIndex = 0;
    _comboCount = 0;
    _powerMeter = 0;
    _totalHits = 0;
    _switchToPhase(BrushPhase.topLeft);

    // Main timer: 1s tick for countdown
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPaused) return;
      setState(() => _phaseSecondsLeft--);

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
          _playDefeatAnimation(() {
            _currentMonsterIndex = currentIndex + 1;
            _switchToPhase(brushPhaseOrder[currentIndex + 1]);
            _playEntranceAnimation();
          });
        } else {
          _playDefeatAnimation(() { timer.cancel(); _finishBrushing(); });
        }
      }
    });

    // Attack timer: hits every 1.5-2.5s for constant action
    _scheduleNextAttack();
  }

  void _scheduleNextAttack() {
    if (_isPaused || _phase == BrushPhase.countdown || _phase == BrushPhase.done) return;
    final delay = 1500 + _random.nextInt(1000); // 1.5-2.5 seconds
    _attackTimer = Timer(Duration(milliseconds: delay), () {
      if (mounted && !_isPaused && _phase != BrushPhase.done) {
        _triggerZap();
        _scheduleNextAttack();
      }
    });
  }

  void _playDefeatAnimation(VoidCallback onComplete) {
    _attackTimer?.cancel();
    setState(() => _monsterDefeating = true);
    _audio.playSfx('monster_defeat.mp3');
    HapticFeedback.heavyImpact();
    _flashController.forward(from: 0).then((_) => _flashController.reverse());
    // Spawn a burst of sparks for defeat
    _spawnDefeatSparks();
    _monsterDefeatController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() { _monsterDefeating = false; _comboCount = 0; _powerMeter = 0; });
        onComplete();
      }
    });
  }

  void _spawnDefeatSparks() {
    for (int i = 0; i < 20; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed = 3.0 + _random.nextDouble() * 6;
      _hitSparks.add(_HitSpark(
        x: 0, y: 0,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        color: _world.themeColor,
        life: 1.0,
        size: 2.0 + _random.nextDouble() * 4,
      ));
    }
  }

  void _playEntranceAnimation() {
    setState(() => _monsterEntering = true);
    _monsterEntranceController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() => _monsterEntering = false);
        _scheduleNextAttack();
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

  void _triggerZap() {
    _audio.playSfx('zap.mp3');
    HapticFeedback.lightImpact();

    setState(() {
      _comboCount++;
      _totalHits++;
      _attackType = _totalHits % 3;
      _powerMeter = (_powerMeter + 0.12).clamp(0, 1);
    });

    // Combo flash at milestones
    if (_comboCount % 5 == 0 && _comboCount > 0) {
      _comboFlashController.forward(from: 0);
      HapticFeedback.mediumImpact();
    }

    // Super attack at full power
    if (_powerMeter >= 1.0 && !_superAttackActive) {
      _triggerSuperAttack();
      return;
    }

    _zapController.forward(from: 0).then((_) => _zapController.reverse());
    _flashController.forward(from: 0).then((_) => _flashController.reverse());
    _heroAttackController.forward(from: 0);
    _screenShakeController.forward(from: 0);
    _monsterHitController.forward(from: 0);

    _spawnDamagePopup();
    _spawnHitSparks();
  }

  void _triggerSuperAttack() {
    setState(() { _superAttackActive = true; _powerMeter = 0; });
    _superAttackController.forward(from: 0).then((_) {
      if (mounted) setState(() => _superAttackActive = false);
    });
    _screenShakeController.forward(from: 0);
    HapticFeedback.heavyImpact();
    _audio.playSfx('monster_defeat.mp3');

    // Big damage popup
    setState(() {
      _damagePopups.add(_DamagePopup(
        text: 'SUPER!', x: 0.5, y: 0.15,
        color: Colors.yellowAccent, opacity: 1.0, offsetY: 0,
        rotation: 0, scale: 2.0,
      ));
    });
    // Massive spark burst
    for (int i = 0; i < 30; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed = 4.0 + _random.nextDouble() * 8;
      _hitSparks.add(_HitSpark(
        x: 0, y: 0,
        vx: cos(angle) * speed, vy: sin(angle) * speed,
        color: _hero.attackColor, life: 1.0,
        size: 2 + _random.nextDouble() * 5,
      ));
    }
  }

  void _spawnDamagePopup() {
    final text = _damageTexts[_random.nextInt(_damageTexts.length)];
    final isComboMilestone = _comboCount % 5 == 0 && _comboCount > 0;
    setState(() {
      _damagePopups.add(_DamagePopup(
        text: isComboMilestone ? '${_comboCount}x COMBO!' : text,
        x: 0.25 + _random.nextDouble() * 0.5,
        y: 0.1 + _random.nextDouble() * 0.3,
        color: isComboMilestone ? Colors.yellowAccent : _hero.attackColor,
        opacity: 1.0, offsetY: 0,
        rotation: (_random.nextDouble() - 0.5) * 0.4,
        scale: isComboMilestone ? 1.5 : 1.0,
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
        color: _hero.attackColor, life: 1.0,
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
      _monsterController.stop();
      _monsterBreathController.stop();
      _heroIdleController.stop();
      _attackTimer?.cancel();
    } else {
      _monsterController.repeat(reverse: true);
      _monsterBreathController.repeat(reverse: true);
      _heroIdleController.repeat(reverse: true);
      _scheduleNextAttack();
    }
  }

  void _quitBrushing() { _timer?.cancel(); _attackTimer?.cancel(); Navigator.of(context).pop(); }

  void _finishBrushing() {
    _attackTimer?.cancel();
    setState(() => _phase = BrushPhase.done);
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const VictoryScreen(),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  String _getEncouragementText() {
    if (_phaseSecondsLeft > 20) return 'FIGHT THAT MONSTER!';
    if (_phaseSecondsLeft > 10) return 'KEEP BRUSHING!';
    if (_phaseSecondsLeft > 5) return 'ALMOST THERE!';
    return 'FINISH IT OFF!';
  }

  ToothQuadrant _phaseToQuadrant(BrushPhase phase) {
    switch (phase) {
      case BrushPhase.topLeft: return ToothQuadrant.topLeft;
      case BrushPhase.topRight: return ToothQuadrant.topRight;
      case BrushPhase.bottomLeft: return ToothQuadrant.bottomLeft;
      case BrushPhase.bottomRight: return ToothQuadrant.bottomRight;
      default: return ToothQuadrant.topLeft;
    }
  }

  Set<ToothQuadrant> _getCompletedQuadrants() {
    final completed = <ToothQuadrant>{};
    final currentIndex = brushPhaseOrder.indexOf(_phase);
    for (int i = 0; i < currentIndex; i++) completed.add(_phaseToQuadrant(brushPhaseOrder[i]));
    return completed;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) { if (!didPop) _togglePause(); },
      child: _phase == BrushPhase.countdown ? _buildCountdown() : _buildBrushing(),
    );
  }

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

  Widget _buildBrushing() {
    final damageProgress = 1.0 - (_phaseSecondsLeft / 30.0);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final monsterSize = (screenHeight * 0.26).clamp(180.0, 280.0);
    final heroSize = (screenHeight * 0.11).clamp(80.0, 110.0);

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
                    // Phase label
                    Padding(
                      padding: const EdgeInsets.only(left: 16, right: 76),
                      child: SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
                            .animate(CurvedAnimation(parent: _phaseTransitionController, curve: Curves.elasticOut)),
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Center(child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(_phaseLabels[_phase] ?? '', maxLines: 1,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: _world.themeColor, fontWeight: FontWeight.bold, fontSize: 28, letterSpacing: 3,
                              )),
                          )),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Tooth diagram + combo counter row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ToothDiagram(
                          activeQuadrant: _phaseToQuadrant(_phase),
                          completedQuadrants: _getCompletedQuadrants(),
                          size: 130, activeColor: _world.themeColor,
                        ),
                        const SizedBox(width: 12),
                        // Combo counter
                        if (_comboCount > 0)
                          AnimatedBuilder(
                            animation: _comboFlashController,
                            builder: (context, child) {
                              final flash = _comboFlashController.value;
                              return Transform.scale(
                                scale: 1.0 + flash * 0.3,
                                child: child,
                              );
                            },
                            child: Column(
                              children: [
                                Text('$_comboCount', style: TextStyle(
                                  color: _comboCount >= 10 ? Colors.yellowAccent : _hero.attackColor,
                                  fontSize: _comboCount >= 10 ? 36 : 28,
                                  fontWeight: FontWeight.bold,
                                  shadows: [Shadow(color: _hero.attackColor.withValues(alpha: 0.6), blurRadius: 12)],
                                )),
                                Text('COMBO', style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6), fontSize: 10, letterSpacing: 2,
                                )),
                              ],
                            ),
                          ),
                      ],
                    ),

                    const Spacer(),

                    // === BATTLE ARENA ===
                    SizedBox(
                      height: monsterSize + heroSize + 60,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Monster aura glow (always on, pulses)
                          AnimatedBuilder(
                            animation: _monsterBreathController,
                            builder: (context, _) {
                              final pulse = 0.3 + sin(_monsterBreathController.value * pi) * 0.2;
                              return Container(
                                width: monsterSize + 50, height: monsterSize + 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(
                                    color: Colors.redAccent.withValues(alpha: pulse * damageProgress),
                                    blurRadius: 40, spreadRadius: 10,
                                  )],
                                ),
                              );
                            },
                          ),

                          // Zap flash
                          AnimatedBuilder(
                            animation: _zapOpacity,
                            builder: (context, _) => Opacity(
                              opacity: _zapOpacity.value,
                              child: Container(
                                width: monsterSize + 60, height: monsterSize + 60,
                                decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                                  BoxShadow(color: _hero.attackColor.withValues(alpha: 0.9), blurRadius: 80, spreadRadius: 30),
                                ]),
                              ),
                            ),
                          ),

                          // Monster
                          Positioned(
                            top: 0,
                            child: _buildMonster(damageProgress, monsterSize),
                          ),

                          // Hit sparks
                          AnimatedBuilder(
                            animation: _particleController,
                            builder: (context, _) => CustomPaint(
                              size: Size(monsterSize + 80, monsterSize + 80),
                              painter: _HitSparkPainter(sparks: _hitSparks),
                            ),
                          ),

                          // Hero at bottom of arena
                          Positioned(
                            bottom: 0,
                            child: _buildHero(heroSize),
                          ),

                          // Attack effect overlay
                          if (_heroAttackController.isAnimating)
                            Positioned(
                              top: monsterSize * 0.2,
                              child: AnimatedBuilder(
                                animation: _heroAttackController,
                                builder: (context, _) {
                                  final t = _heroAttackController.value;
                                  if (t < 0.05 || t > 0.9) return const SizedBox.shrink();
                                  return CustomPaint(
                                    size: Size(monsterSize * 0.8, monsterSize * 0.8),
                                    painter: _AttackEffectPainter(
                                      progress: t, color: _hero.attackColor,
                                      attackType: _attackType,
                                    ),
                                  );
                                },
                              ),
                            ),

                          // Super attack full-screen blast
                          if (_superAttackActive)
                            AnimatedBuilder(
                              animation: _superAttackController,
                              builder: (context, _) {
                                final t = _superAttackController.value;
                                return Container(
                                  width: monsterSize * 3 * t, height: monsterSize * 3 * t,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(colors: [
                                      _hero.attackColor.withValues(alpha: (1 - t) * 0.6),
                                      Colors.white.withValues(alpha: (1 - t) * 0.3),
                                      Colors.transparent,
                                    ]),
                                  ),
                                );
                              },
                            ),

                          // Damage popups
                          ..._damagePopups.map((popup) => Positioned(
                            left: popup.x * screenWidth - 40,
                            top: popup.offsetY + 20,
                            child: Transform.rotate(
                              angle: popup.rotation,
                              child: Transform.scale(
                                scale: popup.scale,
                                child: Opacity(
                                  opacity: popup.opacity.clamp(0, 1),
                                  child: Text(popup.text, style: TextStyle(
                                    color: popup.color, fontSize: 24, fontWeight: FontWeight.bold,
                                    shadows: [Shadow(color: popup.color.withValues(alpha: 0.8), blurRadius: 10),
                                             Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 4)],
                                  )),
                                ),
                              ),
                            ),
                          )),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Health bar + Power meter row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: [
                          // Monster health
                          Row(
                            children: [
                              const Icon(Icons.favorite, color: Colors.redAccent, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: SizedBox(
                                    height: 20,
                                    child: LinearProgressIndicator(
                                      value: 1.0 - damageProgress,
                                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                                      valueColor: AlwaysStoppedAnimation(
                                        Color.lerp(const Color(0xFFFF5252), _world.themeColor, 1.0 - damageProgress)!,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Power meter
                          Row(
                            children: [
                              Icon(Icons.bolt, color: _powerMeter >= 1.0 ? Colors.yellowAccent : _hero.attackColor, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: SizedBox(
                                    height: 14,
                                    child: LinearProgressIndicator(
                                      value: _powerMeter,
                                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                                      valueColor: AlwaysStoppedAnimation(
                                        _powerMeter >= 0.8 ? Colors.yellowAccent : _hero.attackColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text('POWER', style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4), fontSize: 8, letterSpacing: 1,
                              )),
                            ],
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
                      fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 16,
                    )),
                    const SizedBox(height: 16),
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
                    ? Container(color: _hero.attackColor.withValues(alpha: _flashController.value * 0.15))
                    : const SizedBox.shrink(),
              ),

              // Super attack flash
              if (_superAttackActive)
                AnimatedBuilder(
                  animation: _superAttackController,
                  builder: (context, _) {
                    final t = _superAttackController.value;
                    final flash = t < 0.3 ? t / 0.3 : 1.0 - ((t - 0.3) / 0.7);
                    return Container(color: Colors.white.withValues(alpha: flash * 0.3));
                  },
                ),

              if (_isPaused) _buildPauseOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimer(double screenHeight) {
    final isUrgent = _phaseSecondsLeft <= 5;
    final isCritical = _phaseSecondsLeft <= 3;
    Widget timerText = Text(
      _phaseSecondsLeft.toString().padLeft(2, '0'),
      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
        fontSize: (screenHeight * 0.07).clamp(48.0, 72.0),
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
          builder: (context, _) => Container(width: 90, height: 90, decoration: BoxDecoration(
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

  Widget _buildHero(double heroSize) {
    return AnimatedBuilder(
      animation: Listenable.merge([_heroAttackController, _heroIdleController]),
      builder: (context, child) {
        final attackT = _heroAttackController.value;
        final idleT = _heroIdleController.value;
        final jumpY = -sin(attackT * pi) * 30;
        final attackScale = 1.0 + sin(attackT * pi) * 0.25;
        final idleBob = sin(idleT * pi) * 4;
        return Transform.translate(
          offset: Offset(0, jumpY + idleBob),
          child: Transform.scale(scale: attackScale, child: child),
        );
      },
      child: SizedBox(
        width: heroSize + 20,
        height: heroSize + 20,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Hero aura glow
            AnimatedBuilder(
              animation: _heroIdleController,
              builder: (context, _) {
                final pulse = 0.3 + _heroIdleController.value * 0.3;
                return Container(
                  width: heroSize + 16, height: heroSize + 16,
                  decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                    BoxShadow(color: _hero.primaryColor.withValues(alpha: pulse), blurRadius: 20, spreadRadius: 4),
                  ]),
                );
              },
            ),
            // Hero image
            ClipOval(
              child: Image.asset(_hero.imagePath, width: heroSize, height: heroSize, fit: BoxFit.cover),
            ),
            // Ring border
            Container(
              width: heroSize, height: heroSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _hero.primaryColor.withValues(alpha: 0.6), width: 2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonster(double damageProgress, double monsterSize) {
    final shakeMult = 1.0 + damageProgress * 2.0;

    Widget monster = AnimatedBuilder(
      animation: Listenable.merge([_monsterShake, _monsterBreathController, _monsterHitController]),
      builder: (context, child) {
        final breathScale = 1.0 + sin(_monsterBreathController.value * pi) * 0.04;
        // Flinch: brief recoil on hit
        final hitT = _monsterHitController.value;
        final flinchScale = 1.0 - sin(hitT * pi) * 0.1;
        final flinchY = sin(hitT * pi) * 8;
        return Transform.translate(
          offset: Offset(_monsterShake.value * shakeMult, flinchY),
          child: Transform.scale(scale: breathScale * flinchScale, child: child),
        );
      },
      child: SizedBox(
        width: monsterSize, height: monsterSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipOval(
              child: Image.asset(
                _monsterImages[_monsterOrder[_currentMonsterIndex]],
                width: monsterSize, height: monsterSize, fit: BoxFit.cover,
              ),
            ),
            // Vignette
            Container(
              width: monsterSize, height: monsterSize,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(
                colors: [Colors.transparent, Colors.transparent, Colors.black.withValues(alpha: 0.5), Colors.black.withValues(alpha: 0.9)],
                stops: const [0.0, 0.5, 0.8, 1.0],
              )),
            ),
            // Damage cracks overlay
            if (damageProgress > 0.3)
              CustomPaint(
                size: Size(monsterSize, monsterSize),
                painter: _DamageCrackPainter(progress: damageProgress, color: Colors.white),
              ),
            // Angry eyes overlay when damaged
            if (damageProgress > 0.5)
              Positioned(
                top: monsterSize * 0.25,
                child: AnimatedBuilder(
                  animation: _monsterBreathController,
                  builder: (context, _) {
                    final glow = 0.4 + sin(_monsterBreathController.value * pi * 2) * 0.3;
                    return Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 10, height: 6, decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: Colors.redAccent.withValues(alpha: glow),
                        boxShadow: [BoxShadow(color: Colors.redAccent.withValues(alpha: glow), blurRadius: 8)],
                      )),
                      SizedBox(width: monsterSize * 0.18),
                      Container(width: 10, height: 6, decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: Colors.redAccent.withValues(alpha: glow),
                        boxShadow: [BoxShadow(color: Colors.redAccent.withValues(alpha: glow), blurRadius: 8)],
                      )),
                    ]);
                  },
                ),
              ),
          ],
        ),
      ),
    );

    final opacity = 0.2 + (1.0 - damageProgress) * 0.8;
    final scale = 0.55 + (1.0 - damageProgress) * 0.45;
    monster = Opacity(opacity: opacity, child: Transform.scale(scale: scale, child: monster));

    monster = ColorFiltered(
      colorFilter: ColorFilter.mode(Colors.red.withValues(alpha: damageProgress * 0.35), BlendMode.srcATop),
      child: monster,
    );

    if (_monsterDefeating) {
      monster = AnimatedBuilder(
        animation: _monsterDefeatController,
        builder: (context, child) {
          final t = _monsterDefeatController.value;
          return Transform.scale(
            scale: 1.0 + t * 0.3,
            child: Transform.rotate(angle: t * 3 * pi, child: Opacity(
              opacity: (1.0 - t).clamp(0, 1),
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(Colors.white.withValues(alpha: t), BlendMode.srcATop),
                child: child,
              ),
            )),
          );
        },
        child: monster,
      );
    }

    if (_monsterEntering) {
      monster = AnimatedBuilder(
        animation: _monsterEntranceController,
        builder: (context, child) {
          final t = CurvedAnimation(parent: _monsterEntranceController, curve: Curves.bounceOut).value;
          return Transform.translate(
            offset: Offset(0, -200 * (1.0 - t)),
            child: Transform.scale(scale: 2.0 - t, child: child),
          );
        },
        child: monster,
      );
    }

    return monster;
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

/// Varied attack effects: slash, beam, explosion
class _AttackEffectPainter extends CustomPainter {
  final double progress;
  final Color color;
  final int attackType;
  _AttackEffectPainter({required this.progress, required this.color, required this.attackType});
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    switch (attackType) {
      case 0: // Slash — diagonal line sweeps across
        final paint = Paint()
          ..color = color.withValues(alpha: (1 - progress) * 0.9)
          ..strokeWidth = 4 + (1 - progress) * 6
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        final startX = cx - size.width * 0.4 + progress * size.width * 0.2;
        final startY = cy - size.height * 0.4;
        final endX = cx + size.width * 0.4 - progress * size.width * 0.2;
        final endY = cy + size.height * 0.4;
        canvas.drawLine(Offset(startX, startY), Offset(endX * progress + startX * (1 - progress), endY * progress + startY * (1 - progress)), paint);
        // Glow
        paint.color = color.withValues(alpha: (1 - progress) * 0.3);
        paint.strokeWidth = 12;
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawLine(Offset(startX, startY), Offset(endX * progress + startX * (1 - progress), endY * progress + startY * (1 - progress)), paint);
        break;
      case 1: // Beam — expanding ring
        final paint = Paint()
          ..color = color.withValues(alpha: (1 - progress) * 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 + (1 - progress) * 5;
        final radius = progress * size.width * 0.5;
        canvas.drawCircle(Offset(cx, cy), radius, paint);
        // Inner glow
        paint.color = color.withValues(alpha: (1 - progress) * 0.2);
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
        paint.strokeWidth = 8;
        canvas.drawCircle(Offset(cx, cy), radius * 0.8, paint);
        break;
      case 2: // Explosion — X-shaped burst
        final paint = Paint()
          ..color = color.withValues(alpha: (1 - progress) * 0.8)
          ..strokeWidth = 3 + (1 - progress) * 4
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
        final reach = progress * size.width * 0.45;
        canvas.drawLine(Offset(cx - reach, cy - reach), Offset(cx + reach, cy + reach), paint);
        canvas.drawLine(Offset(cx + reach, cy - reach), Offset(cx - reach, cy + reach), paint);
        canvas.drawLine(Offset(cx, cy - reach * 1.2), Offset(cx, cy + reach * 1.2), paint);
        canvas.drawLine(Offset(cx - reach * 1.2, cy), Offset(cx + reach * 1.2, cy), paint);
        break;
    }
  }
  @override
  bool shouldRepaint(_AttackEffectPainter oldDelegate) => progress != oldDelegate.progress;
}

/// Damage cracks drawn on monster as it takes damage
class _DamageCrackPainter extends CustomPainter {
  final double progress;
  final Color color;
  _DamageCrackPainter({required this.progress, required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint()
      ..color = color.withValues(alpha: (progress - 0.3) * 0.6)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final cracks = (progress * 8).floor();
    final rng = Random(42); // Deterministic
    for (int i = 0; i < cracks; i++) {
      final startAngle = rng.nextDouble() * 2 * pi;
      final len = 15 + rng.nextDouble() * 25;
      final x1 = cx + cos(startAngle) * 10;
      final y1 = cy + sin(startAngle) * 10;
      var x2 = x1 + cos(startAngle) * len;
      var y2 = y1 + sin(startAngle) * len;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
      // Branch
      if (rng.nextBool()) {
        final branchAngle = startAngle + (rng.nextDouble() - 0.5) * 1.2;
        final bLen = len * 0.5;
        canvas.drawLine(Offset(x2, y2), Offset(x2 + cos(branchAngle) * bLen, y2 + sin(branchAngle) * bLen), paint);
      }
    }
  }
  @override
  bool shouldRepaint(_DamageCrackPainter oldDelegate) => progress != oldDelegate.progress;
}
