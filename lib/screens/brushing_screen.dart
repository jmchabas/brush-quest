import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/audio_service.dart';
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

class _BrushingScreenState extends State<BrushingScreen>
    with TickerProviderStateMixin {
  final _audio = AudioService();

  BrushPhase _phase = BrushPhase.countdown;
  int _countdownValue = 3;
  int _phaseSecondsLeft = 30;
  int _totalSecondsLeft = 120;
  Timer? _timer;
  int _monstersDefeated = 0;

  late AnimationController _monsterController;
  late Animation<double> _monsterShake;
  late AnimationController _zapController;
  late Animation<double> _zapOpacity;
  late AnimationController _phaseTransitionController;

  final _random = Random();

  static const _phaseLabels = {
    BrushPhase.topLeft: 'TOP LEFT',
    BrushPhase.topRight: 'TOP RIGHT',
    BrushPhase.bottomLeft: 'BOTTOM LEFT',
    BrushPhase.bottomRight: 'BOTTOM RIGHT',
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

  int _currentMonsterIndex = 0;

  @override
  void initState() {
    super.initState();

    _monsterController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    )..repeat(reverse: true);
    _monsterShake = Tween<double>(begin: -5, end: 5).animate(
      CurvedAnimation(parent: _monsterController, curve: Curves.easeInOut),
    );

    _zapController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _zapOpacity = Tween<double>(begin: 0, end: 1).animate(_zapController);

    _phaseTransitionController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _monsterController.dispose();
    _zapController.dispose();
    _phaseTransitionController.dispose();
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
        _startBrushing();
      }
    });
  }

  void _startBrushing() {
    _currentMonsterIndex = 0;
    _switchToPhase(BrushPhase.topLeft);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _phaseSecondsLeft--;
        _totalSecondsLeft--;
      });

      // Random zap effect during brushing
      if (_random.nextDouble() < 0.15) {
        _triggerZap();
      }

      if (_phaseSecondsLeft <= 0) {
        _monstersDefeated++;
        _audio.playSfx('monster_defeat.mp3');
        final currentIndex = brushPhaseOrder.indexOf(_phase);
        if (currentIndex < brushPhaseOrder.length - 1) {
          _currentMonsterIndex = currentIndex + 1;
          _switchToPhase(brushPhaseOrder[currentIndex + 1]);
        } else {
          timer.cancel();
          _finishBrushing();
        }
      }
    });
  }

  void _switchToPhase(BrushPhase newPhase) {
    setState(() {
      _phase = newPhase;
      _phaseSecondsLeft = 30;
    });
    _phaseTransitionController.forward(from: 0);
    _audio.playSfx('whoosh.mp3');
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _phaseVoiceFiles.containsKey(newPhase)) {
        _audio.playVoice(_phaseVoiceFiles[newPhase]!);
      }
    });
  }

  void _triggerZap() {
    _audio.playSfx('zap.mp3');
    _zapController.forward(from: 0).then((_) {
      _zapController.reverse();
    });
  }

  void _finishBrushing() {
    setState(() => _phase = BrushPhase.done);
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const VictoryScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == BrushPhase.countdown) {
      return _buildCountdown();
    }
    return _buildBrushing();
  }

  Widget _buildCountdown() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background_space.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: TweenAnimationBuilder<double>(
            key: ValueKey(_countdownValue),
            tween: Tween(begin: 0.5, end: 1.5),
            duration: const Duration(milliseconds: 800),
            curve: Curves.elasticOut,
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: Text(
                  _countdownValue > 0 ? '$_countdownValue' : 'GO!',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontSize: 120,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: const Color(0xFF00E5FF)
                                .withValues(alpha: 0.8),
                            blurRadius: 40,
                          ),
                        ],
                      ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBrushing() {
    final progress = 1.0 - (_totalSecondsLeft / 120.0);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background_space.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),

              // Phase label
              SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _phaseTransitionController,
                  curve: Curves.elasticOut,
                )),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    _phaseLabels[_phase] ?? '',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: const Color(0xFF00E5FF),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                        ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Quadrant indicator
              _QuadrantIndicator(activePhase: _phase),

              const Spacer(),

              // Monster
              Stack(
                alignment: Alignment.center,
                children: [
                  // Zap flash
                  AnimatedBuilder(
                    animation: _zapOpacity,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _zapOpacity.value,
                        child: Container(
                          width: 280,
                          height: 280,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00E5FF)
                                    .withValues(alpha: 0.8),
                                blurRadius: 60,
                                spreadRadius: 20,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  // Monster image
                  AnimatedBuilder(
                    animation: _monsterShake,
                    builder: (context, child) {
                      final damageProgress = 1.0 - (_phaseSecondsLeft / 30.0);
                      return Transform.translate(
                        offset: Offset(_monsterShake.value, 0),
                        child: Opacity(
                          opacity: 0.4 + (1.0 - damageProgress) * 0.6,
                          child: Transform.scale(
                            scale: 0.7 + (1.0 - damageProgress) * 0.3,
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: Image.asset(
                      _monsterImages[_currentMonsterIndex],
                      width: 220,
                      height: 220,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Timer
              Text(
                _phaseSecondsLeft.toString().padLeft(2, '0'),
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      color: _phaseSecondsLeft <= 5
                          ? Colors.orangeAccent
                          : Colors.white,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'seconds left in this sector',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white54,
                    ),
              ),

              const SizedBox(height: 24),

              // Overall progress bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'MISSION PROGRESS',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white54,
                                    letterSpacing: 2,
                                    fontSize: 10,
                                  ),
                        ),
                        Text(
                          '$_monstersDefeated/4',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white70,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 12,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF00E5FF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuadrantIndicator extends StatelessWidget {
  final BrushPhase activePhase;

  const _QuadrantIndicator({required this.activePhase});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      padding: const EdgeInsets.all(4),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _quadrant(BrushPhase.topLeft),
          _quadrant(BrushPhase.topRight),
          _quadrant(BrushPhase.bottomLeft),
          _quadrant(BrushPhase.bottomRight),
        ],
      ),
    );
  }

  Widget _quadrant(BrushPhase phase) {
    final isActive = activePhase == phase;
    final isPast = brushPhaseOrder.indexOf(phase) <
        brushPhaseOrder.indexOf(activePhase);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: isPast
            ? const Color(0xFF00E5FF).withValues(alpha: 0.6)
            : isActive
                ? const Color(0xFF7C4DFF)
                : Colors.white.withValues(alpha: 0.1),
        border: isActive
            ? Border.all(color: const Color(0xFF00E5FF), width: 2)
            : null,
      ),
    );
  }
}

