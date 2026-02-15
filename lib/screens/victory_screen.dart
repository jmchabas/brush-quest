import 'dart:math';
import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/streak_service.dart';
import 'home_screen.dart';

class VictoryScreen extends StatefulWidget {
  const VictoryScreen({super.key});

  @override
  State<VictoryScreen> createState() => _VictoryScreenState();
}

class _VictoryScreenState extends State<VictoryScreen>
    with TickerProviderStateMixin {
  final _audio = AudioService();
  final _streakService = StreakService();

  late AnimationController _starController;
  late Animation<double> _starScale;
  late AnimationController _confettiController;
  int _newStreak = 0;
  int _newStars = 0;

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

    _confettiController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _recordAndAnimate();
  }

  Future<void> _recordAndAnimate() async {
    await _streakService.recordBrush();
    _newStreak = await _streakService.getStreak();
    _newStars = await _streakService.getTotalStars();
    if (mounted) setState(() {});

    _audio.playSfx('victory.mp3');
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      _audio.playVoice('voice_great_job.mp3');
      _starController.forward();
      _confettiController.repeat();
    }
  }

  @override
  void dispose() {
    _starController.dispose();
    _confettiController.dispose();
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
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background_space.png'),
            fit: BoxFit.cover,
          ),
        ),
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

                    // Big star
                    ScaleTransition(
                      scale: _starScale,
                      child: Container(
                        width: 180,
                        height: 180,
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
                                  .withValues(alpha: 0.6),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.star,
                          size: 100,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    Text(
                      'GREAT JOB!',
                      style:
                          Theme.of(context).textTheme.headlineLarge?.copyWith(
                                fontSize: 48,
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
                    const SizedBox(height: 8),
                    Text(
                      'SPACE RANGER',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: const Color(0xFF00E5FF),
                            letterSpacing: 6,
                          ),
                    ),

                    const SizedBox(height: 40),

                    // Stats
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              const Icon(Icons.local_fire_department,
                                  color: Colors.orangeAccent, size: 36),
                              const SizedBox(height: 4),
                              Text(
                                '$_newStreak day${_newStreak == 1 ? '' : 's'}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(color: Colors.white),
                              ),
                              Text(
                                'STREAK',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.white54,
                                      letterSpacing: 2,
                                    ),
                              ),
                            ],
                          ),
                          Container(
                            width: 1,
                            height: 50,
                            color: Colors.white24,
                          ),
                          Column(
                            children: [
                              const Icon(Icons.star,
                                  color: Colors.yellowAccent, size: 36),
                              const SizedBox(height: 4),
                              Text(
                                '$_newStars total',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(color: Colors.white),
                              ),
                              Text(
                                'STARS',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.white54,
                                      letterSpacing: 2,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const Spacer(flex: 2),

                    // Done button
                    GestureDetector(
                      onTap: _goHome,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 48, vertical: 16),
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
                                letterSpacing: 4,
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

    for (int i = 0; i < 60; i++) {
      final x = _random.nextDouble() * size.width;
      final startY = -20.0 + _random.nextDouble() * -100;
      final y = startY + (size.height + 120) * ((progress + i * 0.02) % 1.0);
      final color = colors[i % colors.length];
      final rectSize = 4.0 + _random.nextDouble() * 8;

      final paint = Paint()..color = color.withValues(alpha: 0.8);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * 4 + i.toDouble());
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: rectSize, height: rectSize * 0.5),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
