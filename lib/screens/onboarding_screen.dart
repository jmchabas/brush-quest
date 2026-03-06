import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/mouth_guide.dart';
import '../widgets/space_background.dart';
import '../services/audio_service.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  int _currentPage = 0;
  bool _cameraMotionEnabled = true;

  late AnimationController _pulseController;
  late AnimationController _floatController;
  late AnimationController _glowController;

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
    _loadInitialCameraChoice();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pulseController.dispose();
    _floatController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _nextPage() {
    HapticFeedback.lightImpact();
    AudioService().playSfx('whoosh.mp3');
    if (_currentPage < 2) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _loadInitialCameraChoice() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('camera_enabled') ?? true;
    if (mounted) {
      setState(() => _cameraMotionEnabled = enabled);
    }
  }

  Future<void> _completeOnboarding() async {
    HapticFeedback.heavyImpact();
    AudioService().playSfx('victory.mp3');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('camera_enabled', _cameraMotionEnabled);
    await prefs.setBool('camera_mode_configured', true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _currentPage = i),
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
              child: const Icon(
                Icons.rocket_launch,
                size: 80,
                color: Colors.white,
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
          const Spacer(flex: 3),
        ],
      ),
    );
  }

  Widget _buildHowToPlayPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          Text(
            'HOW TO PLAY',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF00E5FF),
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 36),
          _OnboardingStep(
            icon: Icons.brush,
            color: const Color(0xFF69F0AE),
            title: 'BRUSH YOUR TEETH',
            subtitle: 'Brush for 2 minutes to win!',
            animation: _pulseController,
          ),
          const SizedBox(height: 20),
          _OnboardingStep(
            icon: Icons.videocam,
            color: const Color(0xFF7C4DFF),
            title: 'CAMERA WATCHES YOU',
            subtitle: 'Brush harder to attack faster!',
            animation: _pulseController,
          ),
          const SizedBox(height: 20),
          _OnboardingStep(
            icon: Icons.star,
            color: Colors.yellowAccent,
            title: 'EARN STARS',
            subtitle: 'Unlock new heroes and weapons!',
            animation: _pulseController,
          ),
          const Spacer(flex: 3),
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
              activeQuadrant: MouthQuadrant.topLeft,
              glowAnim: _glowController.value,
              highlightColor: const Color(0xFF00E5FF),
              size: 240,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Text(
              'The glowing teeth show you\nwhere to brush next!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF7C4DFF).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.videocam, color: Color(0xFF00E5FF), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Camera motion mode',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'Use brushing motion to power attacks.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _cameraMotionEnabled,
                  onChanged: (value) =>
                      setState(() => _cameraMotionEnabled = value),
                  activeThumbColor: const Color(0xFF00E5FF),
                ),
              ],
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
                child: Text(
                  _currentPage == 2 ? "LET'S GO!" : 'NEXT',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingStep extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final AnimationController animation;

  const _OnboardingStep({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final glow = 0.3 + animation.value * 0.3;
            return Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.15),
                border: Border.all(
                  color: color.withValues(alpha: 0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: glow),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 28),
            );
          },
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
