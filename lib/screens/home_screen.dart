import 'package:flutter/material.dart';
import '../services/streak_service.dart';
import '../services/audio_service.dart';
import 'brushing_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _streakService = StreakService();
  int _streak = 0;
  int _totalStars = 0;
  int _todayCount = 0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _loadStats();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _floatController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final streak = await _streakService.getStreak();
    final stars = await _streakService.getTotalStars();
    final today = await _streakService.getTodayBrushCount();
    if (mounted) {
      setState(() {
        _streak = streak;
        _totalStars = stars;
        _todayCount = today;
      });
    }
  }

  void _startBrushing() {
    AudioService().playSfx('whoosh.mp3');
    Navigator.of(context)
        .push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const BrushingScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
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
            transitionDuration: const Duration(milliseconds: 500),
          ),
        )
        .then((_) => _loadStats());
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
          child: Column(
            children: [
              const SizedBox(height: 40),
              // Title
              Text(
                'BRUSH QUEST',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 3,
                      shadows: [
                        Shadow(
                          color: const Color(0xFF7C4DFF).withValues(alpha: 0.8),
                          blurRadius: 20,
                        ),
                        Shadow(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                          blurRadius: 40,
                        ),
                      ],
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'SPACE RANGER EDITION',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF00E5FF),
                      letterSpacing: 6,
                      fontSize: 12,
                    ),
              ),

              const Spacer(),

              // Stats row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatBadge(
                    icon: Icons.local_fire_department,
                    iconColor: Colors.orangeAccent,
                    value: '$_streak',
                    label: 'STREAK',
                  ),
                  _StatBadge(
                    icon: Icons.star,
                    iconColor: Colors.yellowAccent,
                    value: '$_totalStars',
                    label: 'STARS',
                  ),
                  _StatBadge(
                    icon: Icons.today,
                    iconColor: Colors.greenAccent,
                    value: '$_todayCount/2',
                    label: 'TODAY',
                  ),
                ],
              ),

              const Spacer(),

              // Brush button
              AnimatedBuilder(
                animation: Listenable.merge([_pulseAnimation, _floatAnimation]),
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _floatAnimation.value),
                    child: Transform.scale(
                      scale: _pulseAnimation.value,
                      child: child,
                    ),
                  );
                },
                child: GestureDetector(
                  onTap: _startBrushing,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [
                          Color(0xFF9C27B0),
                          Color(0xFF7C4DFF),
                          Color(0xFF3D1F8C),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF7C4DFF).withValues(alpha: 0.6),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                        BoxShadow(
                          color:
                              const Color(0xFF00E5FF).withValues(alpha: 0.3),
                          blurRadius: 50,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.rocket_launch,
                          size: 60,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'BRUSH!',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatBadge({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                  fontSize: 10,
                  letterSpacing: 2,
                ),
          ),
        ],
      ),
    );
  }
}
