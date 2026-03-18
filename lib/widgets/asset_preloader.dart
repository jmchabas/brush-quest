import 'dart:math';
import 'package:flutter/material.dart';
import '../services/audio_service.dart';

class AssetPreloader extends StatefulWidget {
  final Widget child;

  const AssetPreloader({super.key, required this.child});

  @override
  State<AssetPreloader> createState() => _AssetPreloaderState();
}

class _AssetPreloaderState extends State<AssetPreloader>
    with TickerProviderStateMixin {
  bool _loaded = false;
  double _progress = 0.0;

  late AnimationController _pulseController;
  late AnimationController _starController;

  static const _images = [
    'assets/images/background_space.png',
    'assets/images/monster_purple.png',
    'assets/images/monster_green.png',
    'assets/images/monster_orange.png',
    'assets/images/monster_red.png',
    'assets/images/hero_blaze.png',
    'assets/images/hero_frost.png',
    'assets/images/hero_bolt.png',
    'assets/images/hero_shadow.png',
    'assets/images/hero_leaf.png',
    'assets/images/hero_nova.png',
    'assets/images/planet_candy.png',
    'assets/images/planet_slime.png',
    'assets/images/planet_volcano.png',
    'assets/images/planet_shadow.png',
    'assets/images/planet_fortress.png',
    'assets/images/planet_frozen.png',
    'assets/images/planet_toxic.png',
    'assets/images/planet_crystal.png',
    'assets/images/planet_storm.png',
    'assets/images/planet_dark.png',
    'assets/images/weapon_star_blaster.png',
    'assets/images/weapon_flame_sword.png',
    'assets/images/weapon_ice_hammer.png',
    'assets/images/weapon_lightning_wand.png',
    'assets/images/weapon_vine_whip.png',
    'assets/images/weapon_cosmic_burst.png',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _starController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _preload();
    }
  }

  Future<void> _preload() async {
    final total = _images.length + 1; // +1 for audio
    int completed = 0;

    try {
      // Load images one by one to track progress
      for (final path in _images) {
        try {
          await precacheImage(
            AssetImage(path),
            context,
          ).timeout(const Duration(milliseconds: 600));
        } catch (_) {
          // Keep startup resilient on constrained/slow emulators.
          // If one asset fails to decode, continue boot so the app remains usable.
        }
        completed++;
        if (mounted) setState(() => _progress = completed / total);
      }

      // Load audio, but never block startup indefinitely.
      await AudioService().preloadAll().timeout(const Duration(seconds: 8));
      completed++;
      if (mounted) setState(() => _progress = completed / total);
    } catch (_) {
      // Ignore preloading errors and continue into the app.
    } finally {
      if (mounted) {
        setState(() {
          _progress = 1.0;
          _loaded = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _starController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loaded) return widget.child;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D0B2E), Color(0xFF1A0A3E), Color(0xFF0D0B2E)],
          ),
        ),
        child: Stack(
          children: [
            // Floating stars background
            AnimatedBuilder(
              animation: _starController,
              builder: (context, _) => CustomPaint(
                size: MediaQuery.of(context).size,
                painter: _LoadingStarsPainter(_starController.value),
              ),
            ),

            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // App icon — large and prominent
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C4DFF).withValues(alpha: 0.4),
                          blurRadius: 40,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: Image.asset(
                        'assets/images/app_icon.png',
                        width: 200,
                        height: 200,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Pulsing title
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final glow = 0.5 + _pulseController.value * 0.5;
                      final scale = 1.0 + _pulseController.value * 0.03;
                      return Transform.scale(
                        scale: scale,
                        child: Text(
                          'BRUSH QUEST',
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(
                                fontSize: 46,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 4,
                                shadows: [
                                  Shadow(
                                    color: const Color(
                                      0xFF7C4DFF,
                                    ).withValues(alpha: glow),
                                    blurRadius: 30,
                                  ),
                                  Shadow(
                                    color: const Color(
                                      0xFF00E5FF,
                                    ).withValues(alpha: glow * 0.6),
                                    blurRadius: 50,
                                  ),
                                ],
                              ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 8),

                  // Subtitle
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, _) => Opacity(
                      opacity: 0.4 + _pulseController.value * 0.3,
                      child: Text(
                        'DEFEAT THE CAVITY MONSTERS',
                        style: TextStyle(
                          color: const Color(0xFF00E5FF),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 5,
                        ),
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Progress bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 64),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            height: 10,
                            child: LinearProgressIndicator(
                              value: _progress,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.1,
                              ),
                              valueColor: const AlwaysStoppedAnimation(
                                Color(0xFF7C4DFF),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _progress < 0.5
                              ? 'LOADING HEROES...'
                              : _progress < 0.9
                              ? 'PREPARING MONSTERS...'
                              : 'ALMOST READY!',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 1),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating sparkle stars on the loading screen
class _LoadingStarsPainter extends CustomPainter {
  final double progress;
  final Random _rng = Random(42);

  _LoadingStarsPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 40; i++) {
      final baseX = _rng.nextDouble() * size.width;
      final baseY = _rng.nextDouble() * size.height;
      final twinkleOffset = sin((progress * 2 * pi) + i * 0.8);
      final alpha = (0.2 + twinkleOffset * 0.3).clamp(0.0, 0.6);
      final starSize = 1.5 + _rng.nextDouble() * 2.5;

      final paint = Paint()
        ..color =
            (i % 3 == 0
                    ? const Color(0xFF00E5FF)
                    : i % 3 == 1
                    ? const Color(0xFF7C4DFF)
                    : Colors.white)
                .withValues(alpha: alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

      canvas.drawCircle(Offset(baseX, baseY), starSize, paint);
    }
  }

  @override
  bool shouldRepaint(_LoadingStarsPainter oldDelegate) =>
      progress != oldDelegate.progress;
}
