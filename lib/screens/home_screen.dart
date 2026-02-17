import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/streak_service.dart';
import '../services/audio_service.dart';
import '../services/hero_service.dart';
import '../widgets/space_background.dart';
import '../widgets/mute_button.dart';
import 'brushing_screen.dart';
import 'hero_shop_screen.dart';
import 'world_map_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  final _streakService = StreakService();
  final _heroService = HeroService();
  int _totalStars = 0;
  HeroCharacter _selectedHero = HeroService.allHeroes[0];

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;
  late AnimationController _auraController;
  bool _buttonPressed = false;

  @override
  void initState() {
    super.initState();
    _loadStats();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _floatController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _auraController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _floatController.dispose();
    _auraController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final stars = await _streakService.getTotalStars();
    final hero = await _heroService.getSelectedHero();

    if (mounted) {
      setState(() {
        _totalStars = stars;
        _selectedHero = hero;
      });
    }
  }

  void _startBrushing() {
    HapticFeedback.heavyImpact();
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

  void _openHeroShop() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const HeroShopScreen()))
        .then((_) => _loadStats());
  }

  void _openWorldMap() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const WorldMapScreen()))
        .then((_) => _loadStats());
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'GOOD MORNING';
    if (hour < 17) return 'GOOD AFTERNOON';
    return 'GOOD EVENING';
  }

  IconData _getTimeIcon() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 18) return Icons.wb_sunny;
    return Icons.nightlight_round;
  }

  Color _getTimeIconColor() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 18) return Colors.amber;
    return const Color(0xFF90CAF9);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Stack(
            children: [
              // Top-right controls
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const MuteButton(),
                  ],
                ),
              ),

              // Top-left: MAP button
              Positioned(
                top: 12,
                left: 12,
                child: _MiniNavButton(
                  icon: Icons.map,
                  label: 'MAP',
                  color: const Color(0xFF00E5FF),
                  onTap: _openWorldMap,
                ),
              ),

              // Top-right: HEROES button (next to mute)
              Positioned(
                top: 12,
                right: 52,
                child: _MiniNavButton(
                  icon: Icons.shield,
                  label: 'HEROES',
                  color: const Color(0xFF7C4DFF),
                  onTap: _openHeroShop,
                ),
              ),

              Column(
                children: [
                  const SizedBox(height: 56),

                  // Title
                  Stack(
                    children: [
                      Text(
                        'BRUSH QUEST',
                        style: Theme.of(context)
                            .textTheme
                            .headlineLarge
                            ?.copyWith(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 3,
                              foreground: Paint()
                                ..style = PaintingStyle.stroke
                                ..strokeWidth = 4
                                ..color = const Color(0xFF7C4DFF),
                            ),
                      ),
                      Text(
                        'BRUSH QUEST',
                        style: Theme.of(context)
                            .textTheme
                            .headlineLarge
                            ?.copyWith(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 3,
                              shadows: [
                                Shadow(
                                  color: const Color(0xFF7C4DFF)
                                      .withValues(alpha: 0.8),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Greeting
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_getTimeIcon(),
                          color: _getTimeIconColor(), size: 14),
                      const SizedBox(width: 6),
                      Text(
                        _getGreeting(),
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF00E5FF)
                                      .withValues(alpha: 0.7),
                                  letterSpacing: 4,
                                  fontSize: 12,
                                ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Stars display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star, color: Colors.yellowAccent, size: 36),
                      const SizedBox(width: 8),
                      Text(
                        '$_totalStars',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 36,
                          shadows: [
                            Shadow(
                              color: Colors.yellowAccent.withValues(alpha: 0.5),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Hero as BRUSH button
                  AnimatedBuilder(
                    animation:
                        Listenable.merge([_pulseAnimation, _floatAnimation, _auraController]),
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _floatAnimation.value),
                        child: Transform.scale(
                          scale: _buttonPressed
                              ? 0.92
                              : _pulseAnimation.value,
                          child: child,
                        ),
                      );
                    },
                    child: GestureDetector(
                      onTapDown: (_) =>
                          setState(() => _buttonPressed = true),
                      onTapUp: (_) {
                        setState(() => _buttonPressed = false);
                        _startBrushing();
                      },
                      onTapCancel: () =>
                          setState(() => _buttonPressed = false),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Hero circle with aura
                          AnimatedBuilder(
                            animation: _auraController,
                            builder: (context, child) {
                              final auraSize = 270 + _auraController.value * 16;
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Outer aura glow
                                  Container(
                                    width: auraSize,
                                    height: auraSize,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: _selectedHero.primaryColor
                                              .withValues(alpha: 0.3 + _auraController.value * 0.2),
                                          blurRadius: 40,
                                          spreadRadius: 10,
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Hero circle
                                  Container(
                                    width: 260,
                                    height: 260,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _selectedHero.primaryColor,
                                        width: 4,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _selectedHero.primaryColor
                                              .withValues(alpha: 0.6),
                                          blurRadius: 30,
                                          spreadRadius: 5,
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: Image.asset(
                                        _selectedHero.imagePath,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'BRUSH!',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 28,
                                  letterSpacing: 3,
                                  shadows: [
                                    Shadow(
                                      color: _selectedHero.primaryColor
                                          .withValues(alpha: 0.8),
                                      blurRadius: 16,
                                    ),
                                  ],
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _selectedHero.name,
                            style: TextStyle(
                              color: _selectedHero.primaryColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),
                  const SizedBox(height: 24),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniNavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MiniNavButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.7),
              fontSize: 8,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
