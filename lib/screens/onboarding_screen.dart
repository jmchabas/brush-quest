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

  // Animated quadrant cycling for mouth guide demo
  static const _quadrantOrder = [
    MouthQuadrant.topLeft,
    MouthQuadrant.topRight,
    MouthQuadrant.bottomLeft,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(flex: 1),
          // Panel 1: BRUSH — large toothbrush with sparkle animation
          Row(
            children: [
              // Blaze guide on panel 1
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AnimatedBuilder(
                  animation: _floatController,
                  builder: (context, child) {
                    final y = sin(_floatController.value * pi) * 5;
                    return Transform.translate(
                      offset: Offset(0, y),
                      child: child,
                    );
                  },
                  child: Image.asset(
                    'assets/images/hero_blaze.png',
                    width: 56,
                    height: 56,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, _) {
                          final glow = 0.2 + _pulseController.value * 0.4;
                          return Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF69F0AE)
                                      .withValues(alpha: glow),
                                  blurRadius: 30,
                                  spreadRadius: 8,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      AnimatedBuilder(
                        animation: _floatController,
                        builder: (context, child) {
                          final angle =
                              sin(_floatController.value * pi * 2) * 0.08;
                          return Transform.rotate(angle: angle, child: child);
                        },
                        child: Image.asset(
                          'assets/images/toothbrush_icon.png',
                          width: 110,
                          height: 110,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 56),
            ],
          ),
          const SizedBox(height: 8),
          _StepArrow(animation: _pulseController, color: const Color(0xFF7C4DFF)),
          const SizedBox(height: 8),
          // Panel 2: FIGHT — monster + zap
          SizedBox(
            height: 130,
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final shake =
                          sin(_pulseController.value * pi * 4) * 3;
                      return Transform.translate(
                        offset: Offset(shake, 0),
                        child: child,
                      );
                    },
                    child: Image.asset(
                      'assets/images/monster_purple.png',
                      width: 100,
                      height: 100,
                      fit: BoxFit.contain,
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 40,
                    child: AnimatedBuilder(
                      animation: _glowController,
                      builder: (context, _) {
                        final scale = 0.7 + _glowController.value * 0.5;
                        final opacity = 0.4 + _glowController.value * 0.6;
                        return Transform.scale(
                          scale: scale,
                          child: Icon(
                            Icons.flash_on,
                            color: const Color(0xFFFFD740)
                                .withValues(alpha: opacity),
                            size: 44,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _StepArrow(animation: _pulseController, color: const Color(0xFFFFD740)),
          const SizedBox(height: 8),
          // Panel 3: WIN — large star with radiating glow
          SizedBox(
            height: 120,
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, _) {
                      final glow = 0.3 + _pulseController.value * 0.5;
                      return Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD740)
                                  .withValues(alpha: glow),
                              blurRadius: 35,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  AnimatedBuilder(
                    animation: _floatController,
                    builder: (context, _) {
                      final bounce = sin(_floatController.value * pi) * 6;
                      return Transform.translate(
                        offset: Offset(0, -bounce),
                        child: const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFFD740),
                          size: 90,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const Spacer(flex: 1),
        ],
      ),
    );
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

/// Animated arrow connecting the how-to-play steps.
class _StepArrow extends StatelessWidget {
  final AnimationController animation;
  final Color color;

  const _StepArrow({
    required this.animation,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final offset = animation.value * 4;
        final opacity = 0.4 + animation.value * 0.4;
        return Transform.translate(
          offset: Offset(0, offset),
          child: Icon(
            Icons.keyboard_double_arrow_down_rounded,
            color: color.withValues(alpha: opacity),
            size: 32,
          ),
        );
      },
    );
  }
}
