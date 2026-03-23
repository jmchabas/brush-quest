import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/mouth_guide.dart';
import '../widgets/space_background.dart';
import '../services/audio_service.dart';
import '../services/analytics_service.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  final _audio = AudioService();
  int _currentPage = 0;
  int _lastNarratedPage = -1;

  late AnimationController _pulseController;
  late AnimationController _floatController;
  late AnimationController _glowController;

  // Battle scene animation for page 2
  late AnimationController _battleController;

  // Animated quadrant cycling for mouth guide demo
  static const _quadrantOrder = [
    MouthQuadrant.topLeft,
    MouthQuadrant.topFront,
    MouthQuadrant.topRight,
    MouthQuadrant.bottomLeft,
    MouthQuadrant.bottomFront,
    MouthQuadrant.bottomRight,
  ];
  int _quadrantIndex = 0;
  late AnimationController _quadrantCycleController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _floatController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat(reverse: true);
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    // 5-second battle loop: fight (0-0.4), defeat (0.4-0.7), star (0.7-0.9), pause (0.9-1.0)
    _battleController = AnimationController(
      duration: const Duration(milliseconds: 5000),
      vsync: this,
    )..repeat();
    _quadrantCycleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _quadrantIndex = (_quadrantIndex + 1) % _quadrantOrder.length;
        });
        _quadrantCycleController.forward(from: 0);
      }
    });
    _quadrantCycleController.forward();
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) _playPageNarration(0, force: true);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pulseController.dispose();
    _floatController.dispose();
    _glowController.dispose();
    _battleController.dispose();
    _quadrantCycleController.dispose();
    super.dispose();
  }

  void _nextPage() {
    HapticFeedback.lightImpact();
    _audio.playSfx('whoosh.mp3');
    if (_currentPage < 2) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    HapticFeedback.heavyImpact();
    _audio.playSfx('victory.mp3');
    _audio.playVoice('voice_lets_fight.mp3', clearQueue: true, interrupt: true);
    AnalyticsService().logOnboardingComplete();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  void _playPageNarration(int page, {bool force = false}) {
    if (!force && _lastNarratedPage == page) return;
    _lastNarratedPage = page;
    final voiceFile = switch (page) {
      0 => 'voice_onboarding_1.mp3',
      1 => 'voice_onboarding_2.mp3',
      2 => 'voice_onboarding_3.mp3',
      _ => 'voice_onboarding_1.mp3',
    };
    _audio.playVoice(voiceFile, clearQueue: true, interrupt: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 14),
                child: Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    onPressed: () =>
                        _playPageNarration(_currentPage, force: true),
                    icon: const Icon(
                      Icons.volume_up_rounded,
                      color: Color(0xFF00E5FF),
                      size: 30,
                    ),
                    tooltip: 'Repeat voice',
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (i) {
                    setState(() => _currentPage = i);
                    _playPageNarration(i);
                  },
                  children: [
                    _buildWelcomePage(),
                    _buildHowToPlayPage(),
                    _buildMouthGuidePage(),
                  ],
                ),
              ),
              _buildBottomNav(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          AnimatedBuilder(
            animation: _floatController,
            builder: (context, child) {
              final y = sin(_floatController.value * pi) * 8;
              return Transform.translate(offset: Offset(0, y), child: child);
            },
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0xFF7C4DFF), Color(0xFF4A148C)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C4DFF).withValues(alpha: 0.5),
                    blurRadius: 30,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: ClipOval(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Image.asset(
                    'assets/images/hero_blaze.png',
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'WELCOME\nSPACE RANGER!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontSize: 38,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
              shadows: [
                Shadow(
                  color: const Color(0xFF7C4DFF).withValues(alpha: 0.8),
                  blurRadius: 20,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Evil Cavity Monsters are attacking\nyour teeth! Only YOU can stop them!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 18,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          // Visual storytelling: show monsters vs toothbrush so kid
          // understands the concept without reading the text above.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Monster
              SizedBox(
                width: 80,
                height: 80,
                child: Image.asset(
                  'assets/images/monster_purple.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                height: 80,
                child: Image.asset(
                  'assets/images/monster_green.png',
                  fit: BoxFit.contain,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: AnimatedBuilder(
                  animation: _glowController,
                  builder: (context, _) {
                    final scale = 0.9 + _glowController.value * 0.2;
                    final glowAlpha = 0.3 + _glowController.value * 0.5;
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD740)
                                  .withValues(alpha: glowAlpha),
                              blurRadius: 16,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.bolt,
                          color: Color(0xFFFFD740),
                          size: 48,
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(
                width: 80,
                height: 80,
                child: Image.asset(
                  'assets/images/toothbrush_icon.png',
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }

  Widget _buildHowToPlayPage() {
    // Battle sequence driven by _battleController (0.0 -> 1.0 over 5 seconds):
    //   0.0 - 0.40: Hero attacks monster (lunging + impact sparks)
    //   0.40 - 0.70: Monster defeated (shrinks, fades, spins away)
    //   0.70 - 0.90: Star earned (bounces in with celebration)
    //   0.90 - 1.00: Brief pause before loop restarts
    return AnimatedBuilder(
      animation: _battleController,
      builder: (context, _) {
        final t = _battleController.value;

        // --- Hero animation ---
        // During fight phase, hero lunges right toward monster
        final double heroLunge;
        if (t < 0.40) {
          // Rapid back-and-forth lunging (attack swings)
          heroLunge = sin(t / 0.40 * pi * 6) * 18;
        } else {
          // After fight, hero settles
          heroLunge = 0;
        }
        // Hero scale pulse during attack
        final double heroScale;
        if (t < 0.40) {
          heroScale = 1.0 + sin(t / 0.40 * pi * 6).abs() * 0.12;
        } else {
          heroScale = 1.0;
        }

        // --- Monster animation ---
        final double monsterShake;
        final double monsterScale;
        final double monsterOpacity;
        final double monsterRotation;
        if (t < 0.40) {
          // Taking hits — shake intensifies over the fight
          final fightProgress = t / 0.40;
          monsterShake = sin(t * pi * 30) * (2 + fightProgress * 6);
          monsterScale = 1.0 - fightProgress * 0.1; // Slight shrink
          monsterOpacity = 1.0;
          monsterRotation = 0;
        } else if (t < 0.70) {
          // Defeated — shrink, spin, fade
          final defeatProgress = (t - 0.40) / 0.30;
          final eased = Curves.easeInBack.transform(defeatProgress);
          monsterShake = 0;
          monsterScale = (1.0 - eased) * 0.9;
          monsterOpacity = 1.0 - eased;
          monsterRotation = eased * pi * 2;
        } else {
          monsterShake = 0;
          monsterScale = 0;
          monsterOpacity = 0;
          monsterRotation = 0;
        }

        // --- Impact effects (sparks/bolts between hero and monster) ---
        final double impactOpacity;
        final double impactScale;
        if (t < 0.40) {
          // Flash on each hit
          impactOpacity = sin(t / 0.40 * pi * 6).abs() * 0.9;
          impactScale = 0.6 + sin(t / 0.40 * pi * 6).abs() * 0.6;
        } else if (t < 0.50) {
          // Lingering flash during defeat start
          final fade = (t - 0.40) / 0.10;
          impactOpacity = (1.0 - fade) * 0.7;
          impactScale = 1.0 - fade * 0.3;
        } else {
          impactOpacity = 0;
          impactScale = 0;
        }

        // --- Star animation ---
        final double starScale;
        final double starOpacity;
        final double starBounce;
        if (t < 0.70) {
          starScale = 0;
          starOpacity = 0;
          starBounce = 0;
        } else if (t < 0.90) {
          // Star arrives with elastic bounce
          final starProgress = (t - 0.70) / 0.20;
          final eased = Curves.elasticOut.transform(starProgress);
          starScale = eased;
          starOpacity = starProgress.clamp(0.0, 1.0);
          starBounce = sin(starProgress * pi * 3) * (1.0 - starProgress) * 12;
        } else {
          // Star holds with gentle float
          final holdProgress = (t - 0.90) / 0.10;
          starScale = 1.0;
          starOpacity = 1.0;
          starBounce = sin(holdProgress * pi) * 4;
        }

        // --- Star glow ring ---
        final double glowRingScale;
        final double glowRingOpacity;
        if (t >= 0.72 && t < 0.85) {
          final ringProgress = (t - 0.72) / 0.13;
          glowRingScale = 0.5 + ringProgress * 1.5;
          glowRingOpacity = (1.0 - ringProgress) * 0.6;
        } else {
          glowRingScale = 0;
          glowRingOpacity = 0;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Battle arena
              SizedBox(
                height: 320,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // --- Energy ring behind the fight ---
                    if (t < 0.50)
                      Positioned(
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF7C4DFF).withValues(
                                alpha: 0.1 + (t < 0.40 ? t / 0.40 * 0.15 : 0),
                              ),
                              width: 2,
                            ),
                          ),
                        ),
                      ),

                    // --- Hero (Blaze) — bottom-left ---
                    Positioned(
                      left: 16,
                      bottom: 40,
                      child: Transform.translate(
                        offset: Offset(heroLunge, 0),
                        child: Transform.scale(
                          scale: heroScale,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF7C4DFF)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/images/hero_blaze.png',
                              width: 120,
                              height: 120,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // --- Monster — top-right ---
                    Positioned(
                      right: 16,
                      top: 20,
                      child: Transform.translate(
                        offset: Offset(monsterShake, 0),
                        child: Transform.rotate(
                          angle: monsterRotation,
                          child: Transform.scale(
                            scale: monsterScale,
                            child: Opacity(
                              opacity: monsterOpacity.clamp(0.0, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFF1744)
                                          .withValues(alpha: 0.3),
                                      blurRadius: 16,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Image.asset(
                                  'assets/images/monster_purple.png',
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // --- Impact effects (between hero and monster) ---
                    if (impactOpacity > 0.01)
                      Positioned(
                        right: 80,
                        top: 100,
                        child: Transform.scale(
                          scale: impactScale,
                          child: Opacity(
                            opacity: impactOpacity.clamp(0.0, 1.0),
                            child: const _ImpactBurst(),
                          ),
                        ),
                      ),

                    // --- Defeat explosion particles ---
                    if (t >= 0.40 && t < 0.65)
                      Positioned(
                        right: 40,
                        top: 45,
                        child: _DefeatParticles(
                          progress: ((t - 0.40) / 0.25).clamp(0.0, 1.0),
                        ),
                      ),

                    // --- Star glow ring expanding ---
                    if (glowRingOpacity > 0.01)
                      Positioned(
                        right: 36,
                        top: 40,
                        child: Transform.scale(
                          scale: glowRingScale,
                          child: Opacity(
                            opacity: glowRingOpacity.clamp(0.0, 1.0),
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFFFD740),
                                  width: 3,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // --- Star earned (appears where monster was) ---
                    if (starOpacity > 0.01)
                      Positioned(
                        right: 36,
                        top: 30 - starBounce,
                        child: Transform.scale(
                          scale: starScale,
                          child: Opacity(
                            opacity: starOpacity.clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFFD740)
                                        .withValues(alpha: 0.6),
                                    blurRadius: 30,
                                    spreadRadius: 10,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.star_rounded,
                                color: Color(0xFFFFD740),
                                size: 80,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // --- Small sparkle stars around the earned star ---
                    if (t >= 0.74 && t < 0.90)
                      ..._buildSparkles(
                        centerRight: 56,
                        centerTop: 55,
                        progress: ((t - 0.74) / 0.16).clamp(0.0, 1.0),
                      ),
                  ],
                ),
              ),
              const Spacer(flex: 3),
            ],
          ),
        );
      },
    );
  }

  /// Builds small sparkle stars that fly out from the earned star.
  List<Widget> _buildSparkles({
    required double centerRight,
    required double centerTop,
    required double progress,
  }) {
    const sparkleOffsets = [
      Offset(-40, -30),
      Offset(35, -25),
      Offset(-30, 30),
      Offset(40, 20),
      Offset(0, -40),
      Offset(-20, 0),
    ];
    return sparkleOffsets.map((offset) {
      final dx = offset.dx * progress;
      final dy = offset.dy * progress;
      final opacity = (1.0 - progress).clamp(0.0, 1.0) * 0.8;
      final scale = 0.5 + (1.0 - progress) * 0.5;
      return Positioned(
        right: centerRight - dx,
        top: centerTop - dy,
        child: Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: const Icon(
              Icons.star_rounded,
              color: Color(0xFFFFD740),
              size: 20,
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildMouthGuidePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          Text(
            'FOLLOW THE GUIDE',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFFF80AB),
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Brush where the teeth glow!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 28),
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, _) => MouthGuide(
              activeQuadrant: _quadrantOrder[_quadrantIndex],
              glowAnim: _glowController.value,
              highlightColor: const Color(0xFF00E5FF),
              size: 240,
            ),
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          // Page dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              final isActive = i == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 28 : 10,
                height: 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  color: isActive
                      ? const Color(0xFF7C4DFF)
                      : Colors.white.withValues(alpha: 0.3),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          // Next / Start button
          GestureDetector(
            onTap: _currentPage < 2 ? _nextPage : _completeOnboarding,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = _currentPage == 2
                    ? 1.0 + _pulseController.value * 0.04
                    : 1.0;
                return Transform.scale(scale: scale, child: child);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _currentPage == 2
                        ? [const Color(0xFF69F0AE), const Color(0xFF00BFA5)]
                        : [const Color(0xFF7C4DFF), const Color(0xFF9C27B0)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (_currentPage == 2
                                  ? const Color(0xFF69F0AE)
                                  : const Color(0xFF7C4DFF))
                              .withValues(alpha: 0.4),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_currentPage == 2)
                      const Icon(Icons.rocket_launch, color: Colors.white, size: 24)
                    else
                      const SizedBox.shrink(),
                    if (_currentPage == 2)
                      const SizedBox(width: 8),
                    Text(
                      _currentPage == 2 ? "LET'S GO!" : 'NEXT',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                    if (_currentPage < 2) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, color: Colors.white, size: 24),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Starburst / zap impact effect between hero and monster.
class _ImpactBurst extends StatelessWidget {
  const _ImpactBurst();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      height: 70,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Central flash
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.9),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD740).withValues(alpha: 0.8),
                  blurRadius: 20,
                  spreadRadius: 6,
                ),
              ],
            ),
          ),
          // Radiating bolts
          const Positioned(
            top: 0,
            child: Icon(Icons.bolt, color: Color(0xFFFFD740), size: 24),
          ),
          const Positioned(
            bottom: 0,
            child: Icon(Icons.bolt, color: Color(0xFFFF9100), size: 20),
          ),
          Positioned(
            left: 0,
            child: Transform.rotate(
              angle: -pi / 4,
              child: const Icon(Icons.bolt, color: Color(0xFFFFD740), size: 22),
            ),
          ),
          Positioned(
            right: 0,
            child: Transform.rotate(
              angle: pi / 4,
              child: const Icon(Icons.bolt, color: Color(0xFFFF9100), size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

/// Particles that fly out when the monster is defeated.
class _DefeatParticles extends StatelessWidget {
  final double progress;

  const _DefeatParticles({required this.progress});

  @override
  Widget build(BuildContext context) {
    final opacity = (1.0 - progress).clamp(0.0, 1.0);
    const particleData = [
      // (dx multiplier, dy multiplier, size, color)
      (1.0, -1.0, 12.0, Color(0xFFFF1744)),
      (-0.8, -0.6, 10.0, Color(0xFFFF9100)),
      (0.5, 1.0, 8.0, Color(0xFF7C4DFF)),
      (-1.0, 0.3, 10.0, Color(0xFFFF1744)),
      (0.3, -1.2, 9.0, Color(0xFFFF9100)),
      (-0.5, 0.8, 11.0, Color(0xFF7C4DFF)),
    ];
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: particleData.map((p) {
          final dx = p.$1 * progress * 50;
          final dy = p.$2 * progress * 50;
          return Transform.translate(
            offset: Offset(dx, dy),
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: p.$3,
                height: p.$3,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.$4,
                  boxShadow: [
                    BoxShadow(
                      color: p.$4.withValues(alpha: 0.6),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
