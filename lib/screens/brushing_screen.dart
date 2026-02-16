import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/audio_service.dart';
import '../widgets/space_background.dart';
import '../widgets/mute_button.dart';
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
  bool _isPaused = false;
  bool _showGoText = false;

  late AnimationController _monsterController;
  late Animation<double> _monsterShake;
  late AnimationController _zapController;
  late Animation<double> _zapOpacity;
  late AnimationController _phaseTransitionController;
  late AnimationController _monsterDefeatController;
  late AnimationController _monsterEntranceController;
  late AnimationController _flashController;

  bool _monsterDefeating = false;
  bool _monsterEntering = false;

  final _random = Random();

  // Shuffled monster order for variety (4.3)
  late List<int> _monsterOrder;

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

  static const _encouragementVoices = [
    'voice_keep_going.mp3',
    'voice_youre_doing_great.mp3',
    'voice_almost_there.mp3',
  ];

  int _currentMonsterIndex = 0;
  bool _playedEncouragement = false;
  bool _playedAlmostThere = false;

  @override
  void initState() {
    super.initState();

    // Shuffle monster order each session (4.3)
    _monsterOrder = [0, 1, 2, 3]..shuffle(_random);

    _monsterController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    )..repeat(reverse: true);
    _monsterShake = Tween<double>(begin: -12, end: 12).animate(
      CurvedAnimation(parent: _monsterController, curve: Curves.easeInOut),
    );

    _zapController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _zapOpacity = Tween<double>(begin: 0, end: 1).animate(_zapController);

    _phaseTransitionController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _monsterDefeatController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _monsterEntranceController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _flashController = AnimationController(
      duration: const Duration(milliseconds: 150),
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
    _monsterDefeatController.dispose();
    _monsterEntranceController.dispose();
    _flashController.dispose();
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
        // Show "GO!" for 800ms before starting
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

  void _startBrushing() {
    _currentMonsterIndex = 0;
    _switchToPhase(BrushPhase.topLeft);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPaused) return;

      setState(() {
        _phaseSecondsLeft--;
        _totalSecondsLeft--;
      });

      // Random zap effect — 30% chance per second (2.4)
      if (_random.nextDouble() < 0.30) {
        _triggerZap();
      }

      // Mid-brushing encouragement (2.6)
      if (_phaseSecondsLeft == 20 && !_playedEncouragement) {
        _playedEncouragement = true;
        final voice =
            _encouragementVoices[_random.nextInt(_encouragementVoices.length)];
        _audio.playVoice(voice);
      }
      if (_phaseSecondsLeft == 10 && !_playedAlmostThere) {
        _playedAlmostThere = true;
        _audio.playVoice('voice_almost_there.mp3');
      }

      if (_phaseSecondsLeft <= 0) {
        _monstersDefeated++;
        _playedEncouragement = false;
        _playedAlmostThere = false;

        final currentIndex = brushPhaseOrder.indexOf(_phase);
        if (currentIndex < brushPhaseOrder.length - 1) {
          // Defeat animation then entrance of next monster
          _playDefeatAnimation(() {
            _currentMonsterIndex = currentIndex + 1;
            _switchToPhase(brushPhaseOrder[currentIndex + 1]);
            _playEntranceAnimation();
          });
        } else {
          // Final monster defeat
          _playDefeatAnimation(() {
            timer.cancel();
            _finishBrushing();
          });
        }
      }
    });
  }

  void _playDefeatAnimation(VoidCallback onComplete) {
    setState(() => _monsterDefeating = true);
    _audio.playSfx('monster_defeat.mp3');
    HapticFeedback.heavyImpact();
    _monsterDefeatController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() => _monsterDefeating = false);
        onComplete();
      }
    });
  }

  void _playEntranceAnimation() {
    setState(() => _monsterEntering = true);
    _monsterEntranceController.forward(from: 0).then((_) {
      if (mounted) setState(() => _monsterEntering = false);
    });
  }

  void _switchToPhase(BrushPhase newPhase) {
    setState(() {
      _phase = newPhase;
      _phaseSecondsLeft = 30;
    });
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
    _zapController.forward(from: 0).then((_) {
      _zapController.reverse();
    });
    // Brief white screen flash (2.4)
    _flashController.forward(from: 0).then((_) {
      _flashController.reverse();
    });
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
    if (_isPaused) {
      _monsterController.stop();
    } else {
      _monsterController.repeat(reverse: true);
    }
  }

  void _quitBrushing() {
    _timer?.cancel();
    Navigator.of(context).pop();
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

  // Dynamic encouragement text based on time left (2.7)
  String _getEncouragementText() {
    if (_phaseSecondsLeft > 20) return 'FIGHT THAT MONSTER!';
    if (_phaseSecondsLeft > 10) return 'KEEP BRUSHING!';
    if (_phaseSecondsLeft > 5) return 'ALMOST THERE!';
    return 'FINISH IT OFF!';
  }

  // Health bar text (2.3)
  String _getHealthText() {
    final damageProgress = 1.0 - (_phaseSecondsLeft / 30.0);
    if (damageProgress < 0.25) return 'MONSTER IS STRONG!';
    if (damageProgress < 0.50) return 'KEEP BRUSHING!';
    if (damageProgress < 0.75) return 'ALMOST DEFEATED!';
    return 'FINISH IT!';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _togglePause();
      },
      child: _phase == BrushPhase.countdown ? _buildCountdown() : _buildBrushing(),
    );
  }

  Widget _buildCountdown() {
    final displayText =
        _showGoText ? 'GO!' : (_countdownValue > 0 ? '$_countdownValue' : '');
    final textColor = _showGoText ? const Color(0xFF69F0AE) : Colors.white;
    final fontSize = _showGoText ? 140.0 : 120.0;

    return Scaffold(
      body: SpaceBackground(
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Green radial burst behind GO! (3.3)
              if (_showGoText)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 200),
                  duration: const Duration(milliseconds: 400),
                  builder: (context, radius, _) {
                    return Container(
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
                    );
                  },
                ),
              TweenAnimationBuilder<double>(
                key: ValueKey('$_countdownValue-$_showGoText'),
                tween: Tween(begin: 0.5, end: 1.5),
                duration: const Duration(milliseconds: 800),
                curve: Curves.elasticOut,
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: Text(
                      displayText,
                      style:
                          Theme.of(context).textTheme.headlineLarge?.copyWith(
                                fontSize: fontSize,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                                shadows: [
                                  Shadow(
                                    color: (_showGoText
                                            ? const Color(0xFF69F0AE)
                                            : const Color(0xFF00E5FF))
                                        .withValues(alpha: 0.8),
                                    blurRadius: 40,
                                  ),
                                ],
                              ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrushing() {
    final progress = 1.0 - (_totalSecondsLeft / 120.0);
    final damageProgress = 1.0 - (_phaseSecondsLeft / 30.0);
    final screenHeight = MediaQuery.of(context).size.height;
    // Responsive monster size (4.4)
    final monsterSize = (screenHeight * 0.35).clamp(250.0, 340.0);

    return Scaffold(
      body: SpaceBackground(
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 8),

                  // Top bar: phase label + controls
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Spacer(),
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                  color: const Color(0xFF00E5FF)
                                      .withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              _phaseLabels[_phase] ?? '',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: const Color(0xFF00E5FF),
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 4,
                                  ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Mute + Pause buttons
                        const MuteButton(),
                        IconButton(
                          onPressed: _togglePause,
                          icon: const Icon(Icons.pause,
                              color: Colors.white70, size: 28),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Quadrant indicator (2.8)
                  _QuadrantIndicator(
                    activePhase: _phase,
                    monstersDefeated: _monstersDefeated,
                  ),

                  const Spacer(),

                  // Monster area
                  SizedBox(
                    height: monsterSize + 60,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Zap flash behind monster
                        AnimatedBuilder(
                          animation: _zapOpacity,
                          builder: (context, child) {
                            return Opacity(
                              opacity: _zapOpacity.value,
                              child: Container(
                                width: monsterSize + 60,
                                height: monsterSize + 60,
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
                        // Monster image with damage effects
                        _buildMonster(damageProgress, monsterSize),
                      ],
                    ),
                  ),

                  // Health bar (2.3)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 60),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            height: 20,
                            child: LinearProgressIndicator(
                              value: 1.0 - damageProgress,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color.lerp(
                                  const Color(0xFFFF5252),
                                  const Color(0xFF69F0AE),
                                  1.0 - damageProgress,
                                )!,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _getHealthText(),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Color.lerp(
                                      const Color(0xFF69F0AE),
                                      const Color(0xFFFF5252),
                                      1.0 - damageProgress,
                                    ),
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                    fontSize: 12,
                                  ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Timer + encouragement text (2.7)
                  Text(
                    _phaseSecondsLeft.toString().padLeft(2, '0'),
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontSize: (screenHeight * 0.08).clamp(48.0, 72.0),
                          fontWeight: FontWeight.bold,
                          color: _phaseSecondsLeft <= 5
                              ? Colors.orangeAccent
                              : Colors.white,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getEncouragementText(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _phaseSecondsLeft <= 5
                              ? Colors.orangeAccent
                              : const Color(0xFF00E5FF),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                  ),

                  const SizedBox(height: 20),

                  // Overall progress bar with star markers (2.9)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'MISSION PROGRESS',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.white54,
                                    letterSpacing: 2,
                                    fontSize: 10,
                                  ),
                            ),
                            Text(
                              '$_monstersDefeated/4',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.white70,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 28,
                          child: Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              // Bar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  height: 20,
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.1),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                      Color(0xFF00E5FF),
                                    ),
                                  ),
                                ),
                              ),
                              // Star markers at 25/50/75/100%
                              for (int i = 1; i <= 4; i++)
                                Positioned(
                                  left: (MediaQuery.of(context).size.width -
                                              80) *
                                          (i / 4.0) -
                                      14,
                                  child: Icon(
                                    Icons.star,
                                    size: 28,
                                    color: _monstersDefeated >= i
                                        ? const Color(0xFFFFD54F)
                                        : Colors.white24,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),

            // White screen flash overlay (2.4)
            AnimatedBuilder(
              animation: _flashController,
              builder: (context, _) {
                return _flashController.value > 0
                    ? Container(
                        color: Colors.white
                            .withValues(alpha: _flashController.value * 0.1),
                      )
                    : const SizedBox.shrink();
              },
            ),

            // Pause overlay (1.4)
            if (_isPaused) _buildPauseOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildMonster(double damageProgress, double monsterSize) {
    // Dynamic shake multiplier (2.1)
    final shakeMult = 1.0 + damageProgress * 2.0;

    Widget monster = AnimatedBuilder(
      animation: _monsterShake,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_monsterShake.value * shakeMult, 0),
          child: child,
        );
      },
      child: Image.asset(
        _monsterImages[_monsterOrder[_currentMonsterIndex]],
        width: monsterSize,
        height: monsterSize,
        fit: BoxFit.contain,
      ),
    );

    // Apply damage effects (2.2)
    final opacity = 0.15 + (1.0 - damageProgress) * 0.85;
    final scale = 0.5 + (1.0 - damageProgress) * 0.5;

    monster = Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: monster,
      ),
    );

    // Red tint overlay that intensifies (2.2)
    monster = ColorFiltered(
      colorFilter: ColorFilter.mode(
        Colors.red.withValues(alpha: damageProgress * 0.4),
        BlendMode.srcATop,
      ),
      child: monster,
    );

    // Defeat animation: scale to 0, spin 720deg, flash white (2.5)
    if (_monsterDefeating) {
      monster = AnimatedBuilder(
        animation: _monsterDefeatController,
        builder: (context, child) {
          final t = _monsterDefeatController.value;
          return Transform.scale(
            scale: 1.0 - t,
            child: Transform.rotate(
              angle: t * 4 * pi,
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.white.withValues(alpha: t),
                  BlendMode.srcATop,
                ),
                child: child,
              ),
            ),
          );
        },
        child: monster,
      );
    }

    // Entrance animation: drop from above, scale 2.0→1.0, bounceOut (2.5)
    if (_monsterEntering) {
      monster = AnimatedBuilder(
        animation: _monsterEntranceController,
        builder: (context, child) {
          final t = CurvedAnimation(
            parent: _monsterEntranceController,
            curve: Curves.bounceOut,
          ).value;
          return Transform.translate(
            offset: Offset(0, -200 * (1.0 - t)),
            child: Transform.scale(
              scale: 2.0 - t,
              child: child,
            ),
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
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pause_circle_filled,
                size: 80, color: Colors.white54),
            const SizedBox(height: 24),
            Text(
              'PAUSED',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 6,
                  ),
            ),
            const SizedBox(height: 48),
            // Resume button (big)
            GestureDetector(
              onTap: _togglePause,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C4DFF), Color(0xFF9C27B0)],
                  ),
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color:
                          const Color(0xFF7C4DFF).withValues(alpha: 0.5),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Text(
                  'RESUME',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Quit button (smaller)
            GestureDetector(
              onTap: _quitBrushing,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  'QUIT',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white70,
                        letterSpacing: 3,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuadrantIndicator extends StatelessWidget {
  final BrushPhase activePhase;
  final int monstersDefeated;

  const _QuadrantIndicator({
    required this.activePhase,
    required this.monstersDefeated,
  });

  static const _labels = ['TL', 'TR', 'BL', 'BR'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        padding: const EdgeInsets.all(4),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _quadrant(context, BrushPhase.topLeft, 0),
          _quadrant(context, BrushPhase.topRight, 1),
          _quadrant(context, BrushPhase.bottomLeft, 2),
          _quadrant(context, BrushPhase.bottomRight, 3),
        ],
      ),
    );
  }

  Widget _quadrant(BuildContext context, BrushPhase phase, int index) {
    final isActive = activePhase == phase;
    final isPast =
        brushPhaseOrder.indexOf(phase) < brushPhaseOrder.indexOf(activePhase);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isPast
            ? const Color(0xFF00E5FF).withValues(alpha: 0.6)
            : isActive
                ? const Color(0xFF7C4DFF)
                : Colors.white.withValues(alpha: 0.1),
        border: isActive
            ? Border.all(color: const Color(0xFF00E5FF), width: 2)
            : null,
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
      child: Center(
        child: isPast
            ? const Icon(Icons.check, color: Colors.white, size: 22)
            : Text(
                _labels[index],
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isActive ? Colors.white : Colors.white38,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
              ),
      ),
    );
  }
}
