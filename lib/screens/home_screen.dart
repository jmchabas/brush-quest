import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/streak_service.dart';
import '../services/audio_service.dart';
import '../services/hero_service.dart';
import '../services/weapon_service.dart';
import '../services/telemetry_service.dart';
import '../widgets/space_background.dart';
import '../widgets/mute_button.dart';
import 'brushing_screen.dart';
import 'hero_shop_screen.dart';
import 'world_map_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _streakService = StreakService();
  final _heroService = HeroService();
  final _weaponService = WeaponService();
  final _telemetry = TelemetryService();
  int _totalStars = 0;
  int _streak = 0;
  int _todayBrushCount = 0;
  int _totalBrushes = 0;
  int _bossProgress = 0;
  int _bossRemaining = 4;
  bool _bossReady = false;
  bool _morningDone = false;
  bool _eveningDone = false;
  HeroCharacter _selectedHero = HeroService.allHeroes[0];
  WeaponItem _selectedWeapon = WeaponService.allWeapons[0];

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;
  late AnimationController _auraController;
  bool _buttonPressed = false;
  bool _welcomePlayed = false;
  String? _lastPickerVoice;
  bool _homeImpressionLogged = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _playWelcomeVoice();

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
    final weapon = await _weaponService.getSelectedWeapon();
    final streak = await _streakService.getStreak();
    final todayCount = await _streakService.getTodayBrushCount();
    final totalBrushes = await _streakService.getTotalBrushes();
    final todaySlots = await _streakService.getTodaySlots();
    final brushCycle = totalBrushes % 5;
    final bossReady = brushCycle == 4;
    final bossRemaining = bossReady ? 0 : (4 - brushCycle);

    if (mounted) {
      setState(() {
        _totalStars = stars;
        _selectedHero = hero;
        _selectedWeapon = weapon;
        _streak = streak;
        _totalBrushes = totalBrushes;
        _bossProgress = brushCycle;
        _bossRemaining = bossRemaining;
        _bossReady = bossReady;
        _todayBrushCount = todayCount;
        _morningDone = todaySlots.morningDone;
        _eveningDone = todaySlots.eveningDone;
      });
      if (!_homeImpressionLogged) {
        _homeImpressionLogged = true;
        _telemetry.logEvent(
          'home_impression',
          params: {
            'total_stars': stars,
            'streak': streak,
            'today_brush_count': todayCount,
            'total_brushes': totalBrushes,
            'selected_hero': hero.id,
            'selected_weapon': weapon.id,
          },
        );
      }
    }
  }

  Future<void> _playWelcomeVoice() async {
    if (_welcomePlayed) return;
    _welcomePlayed = true;
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    final brushCount = await _streakService.getTodayBrushCount();
    final total = await _streakService.getTotalBrushes();
    if (total == 0) {
      AudioService().playVoice('voice_welcome.mp3');
    } else if (brushCount == 0) {
      AudioService().playVoice('voice_welcome_back.mp3');
    }
  }

  void _startBrushing() {
    HapticFeedback.heavyImpact();
    AudioService().playSfx('whoosh.mp3');
    _telemetry.logEvent(
      'home_start_tap',
      params: {
        'selected_hero': _selectedHero.id,
        'selected_weapon': _selectedWeapon.id,
        'today_brush_count': _todayBrushCount,
        'boss_ready': _bossReady,
      },
    );
    _startBrushingFlow();
  }

  Future<void> _startBrushingFlow() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    if (!prefs.containsKey('camera_mode_configured')) {
      if (!prefs.containsKey('camera_enabled')) {
        await prefs.setBool('camera_enabled', true);
      }
      await prefs.setBool('camera_mode_configured', true);
    }

    _showPreBrushPicker();
  }

  void _launchBrushingScreen() {
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

    final nowHour = DateTime.now().hour;
    final isMorningSlot = nowHour < 15;
    final activeSlotDone = isMorningSlot ? _morningDone : _eveningDone;
    final bothSlotsDone = _morningDone && _eveningDone;
    final starHint = !activeSlotDone
        ? (isMorningSlot
              ? 'Morning mission star is ready!'
              : 'Evening mission star is ready!')
        : bothSlotsDone
        ? 'Both stars collected today. This run is practice only.'
        : (isMorningSlot
              ? 'Morning star already earned. Next star unlocks this evening.'
              : 'Evening star already earned. Next star unlocks tomorrow morning.');

    _lastPickerVoice = null;
    _playPickerVoice(AudioService().heroPickerVoiceFor(_selectedHero.id));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PreBrushPicker(
        heroes: HeroService.allHeroes,
        weapons: WeaponService.allWeapons,
        unlockedHeroIds: unlocked,
        unlockedWeaponIds: unlockedWeapons,
        selectedHero: _selectedHero,
        selectedWeapon: _selectedWeapon,
        willEarnStarNow: !activeSlotDone,
        starHint: starHint,
        morningDone: _morningDone,
        eveningDone: _eveningDone,
        onHeroSelected: (hero) async {
          await _heroService.selectHero(hero.id);
          setState(() => _selectedHero = hero);
          _telemetry.logEvent(
            'picker_hero_selected',
            params: {'hero_id': hero.id},
          );
          _playPickerVoice(AudioService().heroPickerVoiceFor(hero.id));
        },
        onWeaponSelected: (weapon) async {
          await _weaponService.selectWeapon(weapon.id);
          setState(() => _selectedWeapon = weapon);
          _telemetry.logEvent(
            'picker_weapon_selected',
            params: {'weapon_id': weapon.id},
          );
          _playPickerVoice(AudioService().weaponPickerVoiceFor(weapon.id));
        },
        onGo: () {
          Navigator.pop(ctx);
          _telemetry.logEvent(
            'session_confirmed',
            params: {
              'hero_id': _selectedHero.id,
              'weapon_id': _selectedWeapon.id,
            },
          );
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
    );
  }

  void _playPickerVoice(String fileName) {
    if (_lastPickerVoice == fileName) return;
    _lastPickerVoice = fileName;
    AudioService().playVoice(fileName, clearQueue: true, interrupt: true);
  }

  void _openShop() {
    _telemetry.logEvent('navigation_tap', params: {'target': 'heroes'});
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const HeroShopScreen()))
        .then((_) => _loadStats());
  }

  void _openWorldMap() {
    _telemetry.logEvent('navigation_tap', params: {'target': 'map'});
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const WorldMapScreen()))
        .then((_) => _loadStats());
  }

  void _openSettings() {
    _telemetry.logEvent('navigation_tap', params: {'target': 'settings'});
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
                        Icons.sanitizer_rounded,
                        color: const Color(0xFF69F0AE).withValues(alpha: 0.85),
                        size: statIconSize,
                      ),
                      const SizedBox(width: statPairSpacing),
                      Text(
                        '$_todayBrushCount/2',
                        style: TextStyle(
                          color: _todayBrushCount >= 2
                              ? const Color(0xFF69F0AE)
                              : Colors.white.withValues(alpha: 0.6),
                          fontWeight: FontWeight.bold,
                          fontSize: statValueSize,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        _morningDone ? Icons.wb_sunny : Icons.wb_sunny_outlined,
                        color: _morningDone ? Colors.amber : Colors.white38,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _eveningDone
                            ? Icons.nightlight_round
                            : Icons.nightlight_outlined,
                        color: _eveningDone
                            ? const Color(0xFF90CAF9)
                            : Colors.white38,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.workspace_premium,
                                color: Color(0xFFFFD54F),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _bossReady
                                    ? 'BOSS READY NEXT BRUSH'
                                    : 'BOSS IN $_bossRemaining BRUSH${_bossRemaining == 1 ? '' : 'ES'}',
                                style: TextStyle(
                                  color: _bossReady
                                      ? const Color(0xFFFFD54F)
                                      : Colors.white.withValues(alpha: 0.85),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              minHeight: 8,
                              value: _bossReady ? 1.0 : (_bossProgress / 4.0),
                              backgroundColor: Colors.white10,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _bossReady
                                    ? const Color(0xFFFFD54F)
                                    : const Color(0xFF00E5FF),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'MISSIONS CLEARED: $_totalBrushes',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                            ),
                          ),
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
                                            child: Icon(
                                              _selectedWeapon.icon,
                                              color:
                                                  _selectedWeapon.primaryColor,
                                              size: 26,
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
                            icon: Icons.settings,
                            label: 'SETTINGS',
                            color: const Color(0xFF69F0AE),
                            onTap: _openSettings,
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
  final bool willEarnStarNow;
  final String starHint;
  final bool morningDone;
  final bool eveningDone;
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
    required this.willEarnStarNow,
    required this.starHint,
    required this.morningDone,
    required this.eveningDone,
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
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D0B2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0xFF7C4DFF), width: 2)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: widget.willEarnStarNow
                  ? const Color(0xFF69F0AE).withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.willEarnStarNow
                    ? const Color(0xFF69F0AE).withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.star,
                      color: widget.willEarnStarNow
                          ? Colors.yellowAccent
                          : Colors.white54,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.willEarnStarNow
                          ? 'STAR MISSION READY'
                          : 'PRACTICE MISSION',
                      style: TextStyle(
                        color: widget.willEarnStarNow
                            ? const Color(0xFF69F0AE)
                            : Colors.white70,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.starHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 11,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.morningDone
                          ? Icons.wb_sunny
                          : Icons.wb_sunny_outlined,
                      color: widget.morningDone ? Colors.amber : Colors.white38,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'AM',
                      style: TextStyle(
                        color: widget.morningDone
                            ? Colors.amber
                            : Colors.white38,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Icon(
                      widget.eveningDone
                          ? Icons.nightlight_round
                          : Icons.nightlight_outlined,
                      color: widget.eveningDone
                          ? const Color(0xFF90CAF9)
                          : Colors.white38,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'PM',
                      style: TextStyle(
                        color: widget.eveningDone
                            ? const Color(0xFF90CAF9)
                            : Colors.white38,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

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
                child: Icon(
                  _weapon.icon,
                  color: _weapon.primaryColor,
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _hero.name,
            style: TextStyle(
              color: _hero.primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _hero.description,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 12,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _weapon.name,
            style: TextStyle(
              color: _weapon.primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _weapon.description,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 11,
              height: 1.2,
            ),
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
                      : null,
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
                      : null,
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
                    child: Icon(
                      unlocked ? w.icon : Icons.lock,
                      color: unlocked
                          ? (selected ? w.primaryColor : Colors.white54)
                          : Colors.white24,
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
      onTap: onTap,
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
