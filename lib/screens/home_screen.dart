import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/streak_service.dart';
import '../services/audio_service.dart';
import '../services/hero_service.dart';
import '../services/world_service.dart';
import '../services/daily_reward_service.dart';
import '../widgets/space_background.dart';
import '../widgets/mute_button.dart';
import '../widgets/glass_card.dart';
import '../widgets/daily_reward_popup.dart';
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
  final _worldService = WorldService();
  final _dailyRewardService = DailyRewardService();

  int _streak = 0;
  int _totalStars = 0;
  int _todayCount = 0;
  HeroCharacter _selectedHero = HeroService.allHeroes[0];
  WorldData _currentWorld = WorldService.allWorlds[0];
  int _worldProgress = 0;
  bool _dailyRewardAvailable = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;
  late AnimationController _giftBounceController;

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

    _giftBounceController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _floatController.dispose();
    _giftBounceController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final streak = await _streakService.getStreak();
    final stars = await _streakService.getTotalStars();
    final today = await _streakService.getTodayBrushCount();
    final hero = await _heroService.getSelectedHero();
    final world = await _worldService.getCurrentWorld();
    final worldProgress = await _worldService.getWorldProgress(world.id);
    final dailyAvail = await _dailyRewardService.canClaimToday();

    if (mounted) {
      setState(() {
        _streak = streak;
        _totalStars = stars;
        _todayCount = today;
        _selectedHero = hero;
        _currentWorld = world;
        _worldProgress = worldProgress;
        _dailyRewardAvailable = dailyAvail;
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

  void _claimDailyReward() async {
    final stars = await showDailyRewardPopup(context);
    if (stars != null) {
      AudioService().playSfx('victory.mp3');
      await _loadStats();
    }
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
              const Positioned(
                top: 8,
                right: 8,
                child: MuteButton(),
              ),

              Column(
                children: [
                  const SizedBox(height: 24),

                  // Title with paint stroke outline
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

                  // Stats row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.local_fire_department,
                            iconColor: Colors.orangeAccent,
                            value: '$_streak',
                            label: 'STREAK',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.star,
                            iconColor: Colors.yellowAccent,
                            value: '$_totalStars',
                            label: 'STARS',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.today,
                            iconColor: Colors.greenAccent,
                            value: '$_todayCount/2',
                            label: 'TODAY',
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Current world + hero info
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          // Hero avatar
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: ClipOval(
                              child: Image.asset(_selectedHero.imagePath,
                                  fit: BoxFit.cover),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // World info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _currentWorld.name.toUpperCase(),
                                  style: TextStyle(
                                    color: _currentWorld.themeColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: SizedBox(
                                    height: 6,
                                    child: LinearProgressIndicator(
                                      value: _worldProgress /
                                          _currentWorld.missionsRequired,
                                      backgroundColor:
                                          Colors.white.withValues(alpha: 0.1),
                                      valueColor: AlwaysStoppedAnimation(
                                          _currentWorld.themeColor),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$_worldProgress / ${_currentWorld.missionsRequired} missions',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // BRUSH button
                  AnimatedBuilder(
                    animation:
                        Listenable.merge([_pulseAnimation, _floatAnimation]),
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
                      child: Container(
                        width: 240,
                        height: 240,
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
                              color: const Color(0xFF7C4DFF)
                                  .withValues(alpha: 0.6),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.rocket_launch,
                              size: 64,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'BRUSH!',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 24,
                                    letterSpacing: 2,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Bottom navigation — Map, Heroes, Daily Gift
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _NavButton(
                          icon: Icons.map,
                          label: 'MAP',
                          color: const Color(0xFF00E5FF),
                          onTap: _openWorldMap,
                        ),
                        _NavButton(
                          icon: Icons.shield,
                          label: 'HEROES',
                          color: const Color(0xFF7C4DFF),
                          onTap: _openHeroShop,
                        ),
                        _NavButton(
                          icon: Icons.card_giftcard,
                          label: 'GIFT',
                          color: const Color(0xFFFFD54F),
                          onTap: _claimDailyReward,
                          showBadge: _dailyRewardAvailable,
                          bounceController: _giftBounceController,
                        ),
                      ],
                    ),
                  ),

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

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 32),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
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

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool showBadge;
  final AnimationController? bounceController;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.showBadge = false,
    this.bounceController,
  });

  @override
  Widget build(BuildContext context) {
    Widget button = GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              if (showBadge)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF5252),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text('!',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );

    if (showBadge && bounceController != null) {
      button = AnimatedBuilder(
        animation: bounceController!,
        builder: (context, child) {
          final bounce =
              Curves.easeInOut.transform(bounceController!.value) * 4;
          return Transform.translate(
            offset: Offset(0, -bounce),
            child: child,
          );
        },
        child: button,
      );
    }

    return button;
  }
}
