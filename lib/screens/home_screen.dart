import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/streak_service.dart';
import '../services/audio_service.dart';
import '../services/hero_service.dart';
import '../services/weapon_service.dart';
import '../services/greeting_service.dart';
import '../widgets/space_background.dart';
import '../widgets/mute_button.dart';
import 'brushing_screen.dart';
import 'hero_shop_screen.dart';
import 'world_map_screen.dart';
import 'settings_screen.dart';
import 'card_album_screen.dart';
import '../services/analytics_service.dart';

class HomeScreen extends StatefulWidget {
  final bool skipGreeting;
  const HomeScreen({super.key, this.skipGreeting = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _streakService = StreakService();
  final _heroService = HeroService();
  final _weaponService = WeaponService();
  final _greetingService = GreetingService();
  bool _greetingChecked = false;
  int _totalStars = 0;
  int _streak = 0;
  int _todayBrushCount = 0;
  int _bossProgress = 0;
  bool _bossReady = false;
  HeroCharacter _selectedHero = HeroService.allHeroes[0];
  WeaponItem _selectedWeapon = WeaponService.allWeapons[0];

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;
  late AnimationController _auraController;
  bool _buttonPressed = false;
  String? _lastPickerVoice;

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
    AudioService().stopMusic();
    _pulseController.dispose();
    _floatController.dispose();
    _auraController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final stars = await _streakService.getTotalStars();
    final hero = await _heroService.getSelectedHero();
    final weapon = await _weaponService.getSelectedWeapon();
    final streak = await _streakService.getStreak();
    final todayCount = await _streakService.getTodayBrushCount();
    final totalBrushes = await _streakService.getTotalBrushes();
    final brushCycle = totalBrushes % 5;
    final bossReady = brushCycle == 4;

    if (mounted) {
      setState(() {
        _totalStars = stars;
        _selectedHero = hero;
        _selectedWeapon = weapon;
        _streak = streak;
        _bossProgress = brushCycle;
        _bossReady = bossReady;
        _todayBrushCount = todayCount;
      });
      _checkGreeting();
      // Ambient music on home screen (very low volume)
      AudioService().playMusic('battle_music_loop.mp3');
      AudioService().setMusicVolume(0.06);
    }
  }

  Future<void> _checkGreeting() async {
    if (_greetingChecked) return;
    _greetingChecked = true;
    // Skip greeting when returning from a brush session
    if (widget.skipGreeting) return;

    final totalBrushes = await _streakService.getTotalBrushes();
    if (totalBrushes == 0) return;

    final now = DateTime.now();
    final todayDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final lastGreetingDate = await _greetingService.getLastGreetingDate();

    final nextHero = await _heroService.getNextLockedHero();
    final nextWeapon = await _weaponService.getNextLockedWeapon();

    final result = _greetingService.checkGreeting(
      totalBrushes: totalBrushes,
      brushStreak: _streak,
      totalStars: _totalStars,
      nextHeroName: nextHero?.name,
      nextHeroCost: nextHero?.cost,
      nextWeaponName: nextWeapon?.name,
      nextWeaponCost: nextWeapon?.cost,
      todayDate: todayDate,
      lastGreetingDate: lastGreetingDate,
    );

    if (result != null && mounted) {
      await _greetingService.markGreetingShown(todayDate);
      AnalyticsService().logDailyLogin(streak: _streak);
      _showGreetingPopup(result);
    } else if (lastGreetingDate == todayDate && mounted) {
      // Already greeted today — play a short welcome back voice
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) AudioService().playVoice('voice_welcome_back.mp3');
    }
  }

  void _showGreetingPopup(GreetingResult greeting) {
    AudioService().playVoice(greeting.voiceFile);
    HapticFeedback.mediumImpact();

    final title = switch (greeting.state) {
      GreetingState.justStarted => 'HEY SPACE RANGER!',
      GreetingState.streak2to4 => 'WELCOME BACK!',
      GreetingState.streak5to9 => 'WELCOME BACK!',
      GreetingState.streak10to19 => 'SUPER RANGER!',
      GreetingState.streak20plus => 'LEGENDARY!',
      GreetingState.returning => 'WELCOME BACK!',
    };

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 400),
          curve: Curves.elasticOut,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 280),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A0A2E), Color(0xFF0D1B2A)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFF69F0AE).withValues(alpha: 0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF69F0AE).withValues(alpha: 0.3),
                  blurRadius: 20,
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF69F0AE),
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    letterSpacing: 3,
                  ),
                ),
                if (greeting.brushStreak >= 2) ...[
                  const SizedBox(height: 12),
                  Text(
                    '\u{1F525} ${greeting.brushStreak} DAY STREAK!',
                    style: const TextStyle(
                      color: Color(0xFFFFD54F),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      letterSpacing: 1,
                    ),
                  ),
                ],
                if (greeting.teaseItemName != null && greeting.teaseStarsAway != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    "You're ${greeting.teaseStarsAway} stars from ${greeting.teaseItemName}!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => Navigator.of(dialogContext).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF69F0AE).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF69F0AE).withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Text(
                      "LET'S GO!",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // Auto-dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) Navigator.of(context, rootNavigator: true).maybePop();
    });
  }

  void _startBrushing() {
    HapticFeedback.heavyImpact();
    AudioService().playSfx('whoosh.mp3');
    _startBrushingFlow();
  }

  Future<void> _startBrushingFlow() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    if (!prefs.containsKey('camera_mode_configured')) {
      if (!prefs.containsKey('camera_enabled')) {
        await prefs.setBool('camera_enabled', false);
      }
      await prefs.setBool('camera_mode_configured', true);
    }

    _showPreBrushPicker();
  }

  void _launchBrushingScreen() {
    AnalyticsService().logBrushSessionStart(
      heroId: _selectedHero.id,
      weaponId: _selectedWeapon.id,
      worldId: '', // world selected in brushing screen
      isBossSession: _bossReady,
    );
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
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOut,
                        ),
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

  void _showPreBrushPicker() async {
    final unlocked = await _heroService.getUnlockedHeroIds();
    final unlockedWeapons = await _weaponService.getUnlockedWeaponIds();
    if (!mounted) return;

    _lastPickerVoice = null;
    _playPickerVoice(AudioService().heroPickerVoiceFor(_selectedHero.id));

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PreBrushLoadoutScreen(
          child: _PreBrushPicker(
            heroes: HeroService.allHeroes,
            weapons: WeaponService.allWeapons,
            unlockedHeroIds: unlocked,
            unlockedWeaponIds: unlockedWeapons,
            selectedHero: _selectedHero,
            selectedWeapon: _selectedWeapon,
            onHeroSelected: (hero) async {
              await _heroService.selectHero(hero.id);
              setState(() => _selectedHero = hero);
              _playPickerVoice(AudioService().heroPickerVoiceFor(hero.id));
            },
            onWeaponSelected: (weapon) async {
              await _weaponService.selectWeapon(weapon.id);
              setState(() => _selectedWeapon = weapon);
              _playPickerVoice(AudioService().weaponPickerVoiceFor(weapon.id));
            },
            onGo: () {
              Navigator.of(context).pop();
              AudioService().playVoice(
                'voice_lets_fight.mp3',
                clearQueue: true,
                interrupt: true,
              );
              Future.delayed(const Duration(milliseconds: 600), () {
                if (mounted) _launchBrushingScreen();
              });
            },
          ),
        ),
      ),
    );
  }

  void _playPickerVoice(String fileName) {
    if (_lastPickerVoice == fileName) return;
    _lastPickerVoice = fileName;
    AudioService().playVoice(fileName, clearQueue: true, interrupt: true);
  }

  void _openShop() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const HeroShopScreen()))
        .then((_) => _loadStats());
  }

  void _openWorldMap() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const WorldMapScreen()))
        .then((_) => _loadStats());
  }

  void _openCards() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const CardAlbumScreen()))
        .then((_) => _loadStats());
  }

  void _openSettings() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SettingsScreen()))
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
    const statIconSize = 24.0;
    const statValueSize = 24.0;
    const statPairSpacing = 5.0;
    const statGroupSpacing = 24.0;

    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Stack(
            children: [
              // Top-left settings gear
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  onPressed: () {
                    AudioService().playSfx('whoosh.mp3');
                    _openSettings();
                  },
                  icon: Icon(
                    Icons.settings,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 26,
                  ),
                ),
              ),
              // Top-right controls
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [const MuteButton()],
                ),
              ),

              Column(
                children: [
                  const SizedBox(height: 40),

                  // Title
                  Stack(
                    children: [
                      Text(
                        'BRUSH QUEST',
                        style: Theme.of(context).textTheme.headlineLarge
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
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 3,
                              shadows: [
                                Shadow(
                                  color: const Color(
                                    0xFF7C4DFF,
                                  ).withValues(alpha: 0.8),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'HOME BASE',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.2,
                      fontSize: 11,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Greeting
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getTimeIcon(),
                        color: _getTimeIconColor(),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getGreeting(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.7),
                          letterSpacing: 4,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Stats row: streak + stars + today count
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Streak
                      if (_streak > 0) ...[
                        const Icon(
                          Icons.local_fire_department,
                          color: Colors.orangeAccent,
                          size: statIconSize,
                        ),
                        const SizedBox(width: statPairSpacing),
                        Text(
                          '$_streak',
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: statValueSize,
                          ),
                        ),
                        const SizedBox(width: statGroupSpacing),
                      ],
                      // Stars
                      const Icon(
                        Icons.star,
                        color: Colors.yellowAccent,
                        size: statIconSize,
                      ),
                      const SizedBox(width: statPairSpacing),
                      Text(
                        '$_totalStars',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: statValueSize,
                          shadows: [
                            Shadow(
                              color: Colors.yellowAccent.withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      // Today count
                      const SizedBox(width: statGroupSpacing),
                      Icon(
                        Icons.brush,
                        color: const Color(0xFF69F0AE).withValues(alpha: 0.85),
                        size: statIconSize,
                      ),
                      const SizedBox(width: statPairSpacing),
                      Text(
                        '$_todayBrushCount',
                        style: TextStyle(
                          color: _todayBrushCount > 0
                              ? const Color(0xFF69F0AE)
                              : Colors.white.withValues(alpha: 0.6),
                          fontWeight: FontWeight.bold,
                          fontSize: statValueSize,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Boss progress: 5 skull icons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.workspace_premium,
                            color: Color(0xFFFFD54F),
                            size: 16,
                          ),
                          const SizedBox(width: 10),
                          ...List.generate(5, (i) {
                            final filled = i < _bossProgress || _bossReady;
                            return AnimatedBuilder(
                              animation: _bossReady ? _pulseController : const AlwaysStoppedAnimation(0),
                              builder: (context, child) {
                                final scale = _bossReady
                                    ? 1.0 + _pulseController.value * 0.15
                                    : 1.0;
                                return Transform.scale(
                                  scale: scale,
                                  child: child,
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(
                                  Icons.dangerous,
                                  color: filled
                                      ? (_bossReady
                                          ? const Color(0xFFFFD54F)
                                          : const Color(0xFF00E5FF))
                                      : Colors.white.withValues(alpha: 0.2),
                                  size: 24,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Hero as BRUSH button
                  AnimatedBuilder(
                    animation: Listenable.merge([
                      _pulseAnimation,
                      _floatAnimation,
                      _auraController,
                    ]),
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _floatAnimation.value),
                        child: Transform.scale(
                          scale: _buttonPressed ? 0.92 : _pulseAnimation.value,
                          child: child,
                        ),
                      );
                    },
                    child: GestureDetector(
                      onTapDown: (_) => setState(() => _buttonPressed = true),
                      onTapUp: (_) {
                        setState(() => _buttonPressed = false);
                        _startBrushing();
                      },
                      onTapCancel: () => setState(() => _buttonPressed = false),
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
                                              .withValues(
                                                alpha:
                                                    0.3 +
                                                    _auraController.value * 0.2,
                                              ),
                                          blurRadius: 40,
                                          spreadRadius: 10,
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Hero circle + weapon badge
                                  SizedBox(
                                    width: 270,
                                    height: 270,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
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
                                                color: _selectedHero
                                                    .primaryColor
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
                                        // Weapon badge
                                        Positioned(
                                          right: 6,
                                          bottom: 6,
                                          child: Container(
                                            width: 52,
                                            height: 52,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: const Color(0xFF0D0B2E),
                                              border: Border.all(
                                                color: _selectedWeapon
                                                    .primaryColor,
                                                width: 3,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: _selectedWeapon
                                                      .primaryColor
                                                      .withValues(alpha: 0.5),
                                                  blurRadius: 10,
                                                ),
                                              ],
                                            ),
                                            child: ClipOval(
                                              child: Image.asset(
                                                _selectedWeapon.imagePath,
                                                width: 46,
                                                height: 46,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'BRUSH NOW',
                            style: Theme.of(context).textTheme.headlineMedium
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
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.touch_app,
                                color: Colors.white.withValues(
                                  alpha: 0.5 + _auraController.value * 0.4,
                                ),
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'TAP TO START',
                                style: TextStyle(
                                  color: Colors.white.withValues(
                                    alpha: 0.5 + _auraController.value * 0.4,
                                  ),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Secondary nav row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: _SmallNavButton(
                            icon: Icons.rocket_launch,
                            label: 'MAP',
                            color: const Color(0xFF00E5FF),
                            onTap: _openWorldMap,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SmallNavButton(
                            icon: Icons.shield,
                            label: 'HEROES',
                            color: const Color(0xFF7C4DFF),
                            onTap: _openShop,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SmallNavButton(
                            icon: Icons.style,
                            label: 'CARDS',
                            color: const Color(0xFFFFD54F),
                            onTap: _openCards,
                          ),
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

class _PreBrushPicker extends StatefulWidget {
  final List<HeroCharacter> heroes;
  final List<WeaponItem> weapons;
  final List<String> unlockedHeroIds;
  final List<String> unlockedWeaponIds;
  final HeroCharacter selectedHero;
  final WeaponItem selectedWeapon;
  final ValueChanged<HeroCharacter> onHeroSelected;
  final ValueChanged<WeaponItem> onWeaponSelected;
  final VoidCallback onGo;

  const _PreBrushPicker({
    required this.heroes,
    required this.weapons,
    required this.unlockedHeroIds,
    required this.unlockedWeaponIds,
    required this.selectedHero,
    required this.selectedWeapon,
    required this.onHeroSelected,
    required this.onWeaponSelected,
    required this.onGo,
  });

  @override
  State<_PreBrushPicker> createState() => _PreBrushPickerState();
}

class _PreBrushLoadoutScreen extends StatelessWidget {
  final Widget child;
  const _PreBrushLoadoutScreen({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'CHOOSE HERO + WEAPON',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.2,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SingleChildScrollView(child: child),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreBrushPickerState extends State<_PreBrushPicker> {
  late HeroCharacter _hero;
  late WeaponItem _weapon;

  @override
  void initState() {
    super.initState();
    _hero = widget.selectedHero;
    _weapon = widget.selectedWeapon;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Hero + weapon display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _hero.primaryColor, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: _hero.primaryColor.withValues(alpha: 0.4),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(_hero.imagePath, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1A0A3E),
                  border: Border.all(color: _weapon.primaryColor, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: _weapon.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    _weapon.imagePath,
                    width: 28,
                    height: 28,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Hero row
          SizedBox(
            height: 72,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.heroes.length,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemBuilder: (ctx, i) {
                final h = widget.heroes[i];
                final unlocked = widget.unlockedHeroIds.contains(h.id);
                final selected = h.id == _hero.id;
                return GestureDetector(
                  onTap: unlocked
                      ? () {
                          setState(() => _hero = h);
                          widget.onHeroSelected(h);
                        }
                      : () {
                          HapticFeedback.mediumImpact();
                          AudioService().playVoice('voice_need_stars.mp3', clearQueue: true, interrupt: true);
                        },
                  child: Container(
                    width: 64,
                    height: 64,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? h.primaryColor
                            : (unlocked ? Colors.white24 : Colors.white10),
                        width: selected ? 3 : 1,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: h.primaryColor.withValues(alpha: 0.4),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                    child: ClipOval(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColorFiltered(
                            colorFilter: unlocked
                                ? const ColorFilter.mode(
                                    Colors.transparent,
                                    BlendMode.dst,
                                  )
                                : const ColorFilter.mode(
                                    Colors.black54,
                                    BlendMode.saturation,
                                  ),
                            child: Image.asset(h.imagePath, fit: BoxFit.cover),
                          ),
                          if (!unlocked)
                            Center(
                              child: Icon(
                                Icons.lock,
                                color: Colors.white.withValues(alpha: 0.6),
                                size: 20,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // Weapon row
          SizedBox(
            height: 56,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.weapons.length,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemBuilder: (ctx, i) {
                final w = widget.weapons[i];
                final unlocked = widget.unlockedWeaponIds.contains(w.id);
                final selected = w.id == _weapon.id;
                return GestureDetector(
                  onTap: unlocked
                      ? () {
                          setState(() => _weapon = w);
                          widget.onWeaponSelected(w);
                        }
                      : () {
                          HapticFeedback.mediumImpact();
                          AudioService().playVoice('voice_need_stars.mp3', clearQueue: true, interrupt: true);
                        },
                  child: Container(
                    width: 48,
                    height: 48,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? w.primaryColor.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.05),
                      border: Border.all(
                        color: selected
                            ? w.primaryColor
                            : (unlocked ? Colors.white24 : Colors.white10),
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: unlocked
                        ? ClipOval(
                            child: Image.asset(
                              w.imagePath,
                              width: 22,
                              height: 22,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(
                            Icons.lock,
                            color: Colors.white24,
                            size: 22,
                          ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // GO button
          GestureDetector(
            onTap: widget.onGo,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _hero.primaryColor,
                    _hero.primaryColor.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: _hero.primaryColor.withValues(alpha: 0.4),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: const Text(
                'GO!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallNavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SmallNavButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AudioService().playSfx('whoosh.mp3');
        onTap();
      },
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.45), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
