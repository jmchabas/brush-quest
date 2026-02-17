import 'dart:math';
import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/streak_service.dart';
import '../services/hero_service.dart';
import '../services/achievement_service.dart';
import '../services/world_service.dart';
import '../widgets/space_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/achievement_popup.dart';
import 'home_screen.dart';

class VictoryScreen extends StatefulWidget {
  final int starsCollected;
  const VictoryScreen({super.key, this.starsCollected = 1});

  @override
  State<VictoryScreen> createState() => _VictoryScreenState();
}

class _VictoryScreenState extends State<VictoryScreen>
    with TickerProviderStateMixin {
  final _audio = AudioService();
  final _streakService = StreakService();
  final _heroService = HeroService();
  final _achievementService = AchievementService();
  final _worldService = WorldService();

  late AnimationController _starController;
  late Animation<double> _starScale;
  late AnimationController _starRotationController;
  late AnimationController _starGlowController;
  late AnimationController _confettiController;
  late AnimationController _doneButtonController;
  int _newStreak = 0;
  int _newStars = 0;
  List<Achievement> _newAchievements = [];
  HeroCharacter? _nextHero;
  int _starsToNextHero = 0;

  @override
  void initState() {
    super.initState();

    _starController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _starScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _starController, curve: Curves.elasticOut),
    );

    _starRotationController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );

    _starGlowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _confettiController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _doneButtonController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _recordAndAnimate();
  }

  Future<void> _recordAndAnimate() async {
    final hero = await _heroService.getSelectedHero();
    final world = await _worldService.getCurrentWorld();
    await _streakService.recordBrush(heroId: hero.id, worldId: world.id);
    // Add mid-brush stars (minus the 1 already added by recordBrush)
    if (widget.starsCollected > 1) {
      await _streakService.addBonusStars(widget.starsCollected - 1);
    }
    await _worldService.recordMission();
    _newStreak = await _streakService.getStreak();
    _newStars = await _streakService.getTotalStars();

    _newAchievements = await _achievementService.checkAndUnlock(
      streak: _newStreak,
      totalStars: _newStars,
    );

    // Get next locked hero info
    _nextHero = await _heroService.getNextLockedHero();
    if (_nextHero != null) {
      _starsToNextHero = _nextHero!.cost - _newStars;
      if (_starsToNextHero < 0) _starsToNextHero = 0;
    }

    if (mounted) setState(() {});

    _audio.playSfx('victory.mp3');
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      _audio.playVoice('voice_great_job.mp3');
      _starController.forward();
      _starRotationController.repeat();
      _starGlowController.repeat(reverse: true);
      _confettiController.repeat();

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _doneButtonController.repeat(reverse: true);
          // Play stars unlock voice after great job
          if (_nextHero != null && _starsToNextHero > 0) {
            _audio.playVoice('voice_stars_unlock.mp3');
          }
        }
      });

      for (int i = 0; i < _newAchievements.length; i++) {
        Future.delayed(Duration(milliseconds: 1500 + i * 1200), () {
          if (mounted) {
            _showAchievement(_newAchievements[i]);
          }
        });
      }
    }
  }

  void _showAchievement(Achievement achievement) {
    _audio.playSfx('whoosh.mp3');
    showAchievementPopup(context, achievement);
  }

  @override
  void dispose() {
    _starController.dispose();
    _starRotationController.dispose();
    _starGlowController.dispose();
    _confettiController.dispose();
    _doneButtonController.dispose();
    super.dispose();
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Stack(
            children: [
              // Confetti layer
              AnimatedBuilder(
                animation: _confettiController,
                builder: (context, child) {
                  return CustomPaint(
                    size: MediaQuery.of(context).size,
                    painter: _ConfettiPainter(_confettiController.value),
                  );
                },
              ),

              // Content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),

                    // Big star with rotation + glow
                    AnimatedBuilder(
                      animation: Listenable.merge([
                        _starScale,
                        _starRotationController,
                        _starGlowController,
                      ]),
                      builder: (context, child) {
                        final glowIntensity =
                            0.4 + _starGlowController.value * 0.4;
                        return ScaleTransition(
                          scale: _starScale,
                          child: Transform.rotate(
                            angle:
                                _starRotationController.value * 2 * pi * 0.1,
                            child: Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const RadialGradient(
                                  colors: [
                                    Color(0xFFFFD54F),
                                    Color(0xFFFFA000),
                                    Color(0xFFFF6F00),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFFD54F)
                                        .withValues(alpha: glowIntensity),
                                    blurRadius: 50,
                                    spreadRadius: 15,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.star,
                                size: 90,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'GREAT JOB!',
                      style:
                          Theme.of(context).textTheme.headlineLarge?.copyWith(
                                fontSize: 44,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: const Color(0xFFFFD54F)
                                        .withValues(alpha: 0.8),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'SPACE RANGER',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: const Color(0xFF00E5FF),
                            letterSpacing: 6,
                            fontSize: 18,
                          ),
                    ),

                    const SizedBox(height: 28),

                    // Stars collected this session
                    if (widget.starsCollected > 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.star,
                                color: Colors.yellowAccent, size: 28),
                            const SizedBox(width: 6),
                            TweenAnimationBuilder<int>(
                              tween: IntTween(begin: 0, end: widget.starsCollected),
                              duration: const Duration(milliseconds: 1200),
                              builder: (context, val, _) => Text(
                                '+$val',
                                style: const TextStyle(
                                  color: Colors.yellowAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 28,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'COLLECTED!',
                              style: TextStyle(
                                color: Colors.yellowAccent.withValues(alpha: 0.7),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Total stars count
                    GlassCard(
                      margin: const EdgeInsets.symmetric(horizontal: 48),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      child: Column(
                        children: [
                          const Icon(Icons.star,
                              color: Colors.yellowAccent, size: 40),
                          const SizedBox(height: 4),
                          TweenAnimationBuilder<int>(
                            tween: IntTween(begin: 0, end: _newStars),
                            duration: const Duration(milliseconds: 1500),
                            builder: (context, val, _) => Text(
                              '$val',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 40,
                                  ),
                            ),
                          ),
                          Text(
                            'TOTAL STARS',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Colors.white54,
                                  letterSpacing: 3,
                                  fontSize: 13,
                                ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Stars until next hero
                    if (_nextHero != null && _starsToNextHero > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_open,
                                color: _nextHero!.primaryColor, size: 18),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '$_starsToNextHero more to unlock ${_nextHero!.name}!',
                                style: TextStyle(
                                  color: _nextHero!.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  letterSpacing: 1,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_nextHero == null)
                      Text(
                        'ALL HEROES UNLOCKED!',
                        style: TextStyle(
                          color: const Color(0xFF69F0AE),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 2,
                        ),
                      ),

                    const Spacer(flex: 2),

                    // DONE button
                    AnimatedBuilder(
                      animation: _doneButtonController,
                      builder: (context, child) {
                        final scale =
                            1.0 + _doneButtonController.value * 0.05;
                        return Transform.scale(
                          scale: scale,
                          child: child,
                        );
                      },
                      child: GestureDetector(
                        onTap: _goHome,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 60, vertical: 20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF7C4DFF), Color(0xFF9C27B0)],
                            ),
                            borderRadius: BorderRadius.circular(40),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7C4DFF)
                                    .withValues(alpha: 0.5),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: Text(
                            'DONE',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 24,
                                  letterSpacing: 4,
                                ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final Random _random = Random(42);

  _ConfettiPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final colors = [
      const Color(0xFFFF4081),
      const Color(0xFF7C4DFF),
      const Color(0xFF00E5FF),
      const Color(0xFFFFD54F),
      const Color(0xFF69F0AE),
      const Color(0xFFFF6E40),
    ];

    for (int i = 0; i < 120; i++) {
      final baseX = _random.nextDouble() * size.width;
      final sineDrift = sin((progress * 4 + i * 0.3)) * 30;
      final x = baseX + sineDrift;
      final speed = 0.6 + _random.nextDouble() * 0.8;
      final startY = -20.0 + _random.nextDouble() * -100;
      final y =
          startY + (size.height + 120) * ((progress * speed + i * 0.015) % 1.0);
      final color = colors[i % colors.length];

      final paint = Paint()..color = color.withValues(alpha: 0.8);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * 4 + i.toDouble());

      final shapeType = i % 3;
      if (shapeType == 0) {
        final w = 4.0 + _random.nextDouble() * 8;
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: w, height: w * 0.5),
          paint,
        );
      } else if (shapeType == 1) {
        canvas.drawCircle(
            Offset.zero, 2.0 + _random.nextDouble() * 4, paint);
      } else {
        final s = 3.0 + _random.nextDouble() * 5;
        final path = Path()
          ..moveTo(0, -s)
          ..lineTo(s * 0.6, s * 0.4)
          ..lineTo(-s * 0.6, s * 0.4)
          ..close();
        canvas.drawPath(path, paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
