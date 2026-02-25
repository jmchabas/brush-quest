import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/audio_service.dart';
import '../services/streak_service.dart';
import '../services/hero_service.dart';
import '../services/weapon_service.dart';
import '../services/achievement_service.dart';
import '../services/world_service.dart';
import '../widgets/space_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/achievement_popup.dart';
import 'home_screen.dart';
import 'brushing_screen.dart';

enum _ChestRewardType { confetti, dance, bonusStar, doubleStar, jackpot }

class _ChestReward {
  final _ChestRewardType type;
  final int bonusStars;
  final String voiceFile;
  final Color color;
  final IconData icon;

  const _ChestReward({
    required this.type,
    required this.bonusStars,
    required this.voiceFile,
    required this.color,
    required this.icon,
  });
}

const _rewardTable = [
  // 30% confetti
  _ChestReward(type: _ChestRewardType.confetti, bonusStars: 0, voiceFile: 'voice_chest_wow.mp3', color: Color(0xFF00E5FF), icon: Icons.celebration),
  _ChestReward(type: _ChestRewardType.confetti, bonusStars: 0, voiceFile: 'voice_chest_wow.mp3', color: Color(0xFF00E5FF), icon: Icons.celebration),
  _ChestReward(type: _ChestRewardType.confetti, bonusStars: 0, voiceFile: 'voice_chest_wow.mp3', color: Color(0xFF00E5FF), icon: Icons.celebration),
  _ChestReward(type: _ChestRewardType.confetti, bonusStars: 0, voiceFile: 'voice_chest_wow.mp3', color: Color(0xFF00E5FF), icon: Icons.celebration),
  _ChestReward(type: _ChestRewardType.confetti, bonusStars: 0, voiceFile: 'voice_chest_wow.mp3', color: Color(0xFF00E5FF), icon: Icons.celebration),
  _ChestReward(type: _ChestRewardType.confetti, bonusStars: 0, voiceFile: 'voice_chest_wow.mp3', color: Color(0xFF00E5FF), icon: Icons.celebration),
  // 25% dance
  _ChestReward(type: _ChestRewardType.dance, bonusStars: 0, voiceFile: 'voice_chest_dance.mp3', color: Color(0xFFFF4081), icon: Icons.music_note),
  _ChestReward(type: _ChestRewardType.dance, bonusStars: 0, voiceFile: 'voice_chest_dance.mp3', color: Color(0xFFFF4081), icon: Icons.music_note),
  _ChestReward(type: _ChestRewardType.dance, bonusStars: 0, voiceFile: 'voice_chest_dance.mp3', color: Color(0xFFFF4081), icon: Icons.music_note),
  _ChestReward(type: _ChestRewardType.dance, bonusStars: 0, voiceFile: 'voice_chest_dance.mp3', color: Color(0xFFFF4081), icon: Icons.music_note),
  _ChestReward(type: _ChestRewardType.dance, bonusStars: 0, voiceFile: 'voice_chest_dance.mp3', color: Color(0xFFFF4081), icon: Icons.music_note),
  // 25% bonus star
  _ChestReward(type: _ChestRewardType.bonusStar, bonusStars: 1, voiceFile: 'voice_chest_bonus_star.mp3', color: Color(0xFFFFD54F), icon: Icons.star),
  _ChestReward(type: _ChestRewardType.bonusStar, bonusStars: 1, voiceFile: 'voice_chest_bonus_star.mp3', color: Color(0xFFFFD54F), icon: Icons.star),
  _ChestReward(type: _ChestRewardType.bonusStar, bonusStars: 1, voiceFile: 'voice_chest_bonus_star.mp3', color: Color(0xFFFFD54F), icon: Icons.star),
  _ChestReward(type: _ChestRewardType.bonusStar, bonusStars: 1, voiceFile: 'voice_chest_bonus_star.mp3', color: Color(0xFFFFD54F), icon: Icons.star),
  _ChestReward(type: _ChestRewardType.bonusStar, bonusStars: 1, voiceFile: 'voice_chest_bonus_star.mp3', color: Color(0xFFFFD54F), icon: Icons.star),
  // 15% double
  _ChestReward(type: _ChestRewardType.doubleStar, bonusStars: 1, voiceFile: 'voice_chest_double.mp3', color: Color(0xFF69F0AE), icon: Icons.auto_awesome),
  _ChestReward(type: _ChestRewardType.doubleStar, bonusStars: 1, voiceFile: 'voice_chest_double.mp3', color: Color(0xFF69F0AE), icon: Icons.auto_awesome),
  _ChestReward(type: _ChestRewardType.doubleStar, bonusStars: 1, voiceFile: 'voice_chest_double.mp3', color: Color(0xFF69F0AE), icon: Icons.auto_awesome),
  // 5% jackpot
  _ChestReward(type: _ChestRewardType.jackpot, bonusStars: 2, voiceFile: 'voice_chest_jackpot.mp3', color: Color(0xFFFFD54F), icon: Icons.emoji_events),
];

class VictoryScreen extends StatefulWidget {
  final int starsCollected;
  final int totalHits;
  final int monstersDefeated;
  final bool isBossSession;
  const VictoryScreen({super.key, this.starsCollected = 1, this.totalHits = 0, this.monstersDefeated = 4, this.isBossSession = false});

  @override
  State<VictoryScreen> createState() => _VictoryScreenState();
}

class _VictoryScreenState extends State<VictoryScreen>
    with TickerProviderStateMixin {
  final _audio = AudioService();
  final _streakService = StreakService();
  final _heroService = HeroService();
  final _weaponService = WeaponService();
  final _achievementService = AchievementService();
  final _worldService = WorldService();
  final _random = Random();

  late AnimationController _starController;
  late Animation<double> _starScale;
  late AnimationController _starRotationController;
  late AnimationController _starGlowController;
  late AnimationController _confettiController;
  late AnimationController _doneButtonController;
  late AnimationController _chestBounceController;
  late AnimationController _chestOpenController;
  late AnimationController _rewardRevealController;
  int _newStreak = 0;
  int _newStars = 0;
  List<Achievement> _newAchievements = [];
  HeroCharacter? _nextHero;
  int _starsToNextHero = 0;
  String? _nextMilestoneLabel;
  int _starsToNextMilestone = 0;
  WorldData _world = WorldService.allWorlds[0];
  int _worldProgress = 0;
  int _worldRemaining = 0;

  bool _showChest = false;
  bool _chestOpened = false;
  _ChestReward? _reward;

  @override
  void initState() {
    super.initState();

    _starController = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);
    _starScale = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _starController, curve: Curves.elasticOut));
    _starRotationController = AnimationController(duration: const Duration(seconds: 8), vsync: this);
    _starGlowController = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this);
    _confettiController = AnimationController(duration: const Duration(seconds: 3), vsync: this);
    _doneButtonController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);

    _chestBounceController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _chestOpenController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _rewardRevealController = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);

    _recordAndAnimate();
  }

  Future<void> _recordAndAnimate() async {
    final hero = await _heroService.getSelectedHero();
    _world = await _worldService.getCurrentWorld();
    await _streakService.recordBrush(heroId: hero.id, worldId: _world.id);
    await _worldService.recordMission();
    _newStreak = await _streakService.getStreak();
    _newStars = await _streakService.getTotalStars();
    _worldProgress = await _worldService.getWorldProgress(_world.id);
    _worldRemaining = (_world.missionsRequired - _worldProgress).clamp(0, 9999);

    _newAchievements = await _achievementService.checkAndUnlock(
      streak: _newStreak, totalStars: _newStars,
    );

    _nextHero = await _heroService.getNextLockedHero();
    if (_nextHero != null) {
      _starsToNextHero = _nextHero!.cost - _newStars;
      if (_starsToNextHero < 0) _starsToNextHero = 0;
    }
    await _refreshMilestoneHint();

    if (mounted) setState(() {});

    _audio.playSfx('victory.mp3');
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final hour = DateTime.now().hour;
    final victoryVoice = (hour >= 5 && hour < 12)
        ? 'voice_great_job_morning.mp3'
        : (hour >= 18 || hour < 5)
            ? 'voice_great_job_tonight.mp3'
            : 'voice_you_did_it.mp3';
    _audio.playVoice(victoryVoice);
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) _audio.playVoice('voice_victory_star_and_chest.wav');
    });
    _starController.forward();
    _starRotationController.repeat();
    _starGlowController.repeat(reverse: true);
    _confettiController.repeat();

    for (int i = 0; i < _newAchievements.length; i++) {
      Future.delayed(Duration(milliseconds: 1500 + i * 1200), () {
        if (mounted) _showAchievement(_newAchievements[i]);
      });
    }

    // Show chest after initial celebration
    Future.delayed(const Duration(milliseconds: 3400), () {
      if (!mounted) return;
      setState(() => _showChest = true);
      _chestBounceController.repeat(reverse: true);
      _audio.playVoice('voice_open_chest.mp3');
    });
  }

  void _openChest() {
    if (_chestOpened) return;
    setState(() => _chestOpened = true);
    HapticFeedback.heavyImpact();

    _reward = _rewardTable[_random.nextInt(_rewardTable.length)];
    _chestBounceController.stop();
    _chestOpenController.forward();

    _audio.playSfx('star_chime.mp3');

    Future.delayed(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      _rewardRevealController.forward();
      _audio.playVoice(_reward!.voiceFile);

      if (_reward!.bonusStars > 0) {
        await _streakService.addBonusStars(_reward!.bonusStars);
        final updated = await _streakService.getTotalStars();
        _newStars = updated;
        await _refreshMilestoneHint();
        if (mounted) {
          setState(() {
            if (_nextHero != null) {
              _starsToNextHero = _nextHero!.cost - _newStars;
              if (_starsToNextHero < 0) _starsToNextHero = 0;
            }
          });
        }
      }

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _doneButtonController.repeat(reverse: true);
      });
      Future.delayed(const Duration(milliseconds: 2800), () {
        if (mounted) _audio.playVoice('voice_see_you_soon.wav');
      });
    });
  }

  Future<void> _refreshMilestoneHint() async {
    final unlockedHeroes = await _heroService.getUnlockedHeroIds();
    final unlockedWeapons = await _weaponService.getUnlockedWeaponIds();
    final candidates = <MapEntry<String, int>>[];

    for (final hero in HeroService.allHeroes) {
      if (!unlockedHeroes.contains(hero.id)) {
        candidates.add(MapEntry(hero.name, (hero.cost - _newStars).clamp(0, 9999)));
      }
    }
    for (final weapon in WeaponService.allWeapons) {
      if (!unlockedWeapons.contains(weapon.id)) {
        candidates.add(MapEntry(weapon.name, (weapon.cost - _newStars).clamp(0, 9999)));
      }
    }

    if (candidates.isEmpty) {
      _nextMilestoneLabel = null;
      _starsToNextMilestone = 0;
      return;
    }
    candidates.sort((a, b) => a.value.compareTo(b.value));
    _nextMilestoneLabel = candidates.first.key;
    _starsToNextMilestone = candidates.first.value;
  }

  List<String> _buildComebackLines() {
    final lines = <String>[];

    if (_newStreak > 1) {
      lines.add('YOU ARE ON A $_newStreak DAY STREAK.');
    } else {
      lines.add('COME BACK TOMORROW TO START YOUR STREAK.');
    }

    if (_worldRemaining <= 0) {
      lines.add('WORLD COMPLETE! NEXT WORLD IS WAITING.');
    } else if (_worldRemaining == 1) {
      lines.add('ONE MORE MISSION TO FINISH ${_world.name.toUpperCase()}!');
    } else {
      lines.add('$_worldRemaining MISSIONS LEFT IN ${_world.name.toUpperCase()}.');
    }

    if (_nextMilestoneLabel != null) {
      if (_starsToNextMilestone <= 1) {
        lines.add('ONE MORE STAR TO UNLOCK $_nextMilestoneLabel.');
      } else {
        lines.add('$_starsToNextMilestone STARS TO UNLOCK $_nextMilestoneLabel.');
      }
    }

    lines.add('SEE YOU SOON, SPACE RANGER.');
    return lines;
  }

  void _showAchievement(Achievement achievement) {
    _audio.playSfx('whoosh.mp3');
    showAchievementPopup(context, achievement);
  }

  @override
  void dispose() {
    _starController.dispose();
    _starRotationController.dispose();
    _starGlowController.dispose();
    _confettiController.dispose();
    _doneButtonController.dispose();
    _chestBounceController.dispose();
    _chestOpenController.dispose();
    _rewardRevealController.dispose();
    super.dispose();
  }

  void _brushAgain() {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const BrushingScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
      (route) => false,
    );
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Stack(
            children: [
              // Confetti layer
              AnimatedBuilder(
                animation: _confettiController,
                builder: (context, child) => CustomPaint(
                  size: MediaQuery.of(context).size,
                  painter: _ConfettiPainter(_confettiController.value),
                ),
              ),

              // Jackpot golden overlay
              if (_chestOpened && _reward?.type == _ChestRewardType.jackpot)
                AnimatedBuilder(
                  animation: _rewardRevealController,
                  builder: (context, _) => Container(
                    color: const Color(0xFFFFD54F).withValues(alpha: _rewardRevealController.value * 0.15),
                  ),
                ),

              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 1),

                    // Big star
                    AnimatedBuilder(
                      animation: Listenable.merge([_starScale, _starRotationController, _starGlowController]),
                      builder: (context, child) {
                        final glow = 0.4 + _starGlowController.value * 0.4;
                        return ScaleTransition(
                          scale: _starScale,
                          child: Transform.rotate(
                            angle: _starRotationController.value * 2 * pi * 0.1,
                            child: Container(
                              width: 120, height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const RadialGradient(colors: [Color(0xFFFFD54F), Color(0xFFFFA000), Color(0xFFFF6F00)]),
                                boxShadow: [BoxShadow(color: const Color(0xFFFFD54F).withValues(alpha: glow), blurRadius: 50, spreadRadius: 15)],
                              ),
                              child: const Icon(Icons.star, size: 70, color: Colors.white),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text('GREAT JOB!', style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white,
                      shadows: [Shadow(color: const Color(0xFFFFD54F).withValues(alpha: 0.8), blurRadius: 20)],
                    )),

                    const SizedBox(height: 16),

                    // Star bank
                    GlassCard(
                      margin: const EdgeInsets.symmetric(horizontal: 48),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.yellowAccent, size: 32),
                          const SizedBox(width: 8),
                          TweenAnimationBuilder<int>(
                            tween: IntTween(begin: 0, end: _newStars),
                            duration: const Duration(milliseconds: 1500),
                            builder: (context, val, _) => Text('$val',
                              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 32)),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // TREASURE CHEST
                    if (_showChest) _buildChest(),

                    // Next hero progress (only after chest is opened)
                    if (_chestOpened && _nextHero != null && _starsToNextHero > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 16, left: 48, right: 48),
                        child: Row(
                          children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: _nextHero!.primaryColor, width: 2),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  ClipOval(child: ColorFiltered(
                                    colorFilter: const ColorFilter.mode(Colors.black54, BlendMode.saturation),
                                    child: Image.asset(_nextHero!.imagePath, width: 32, height: 32, fit: BoxFit.cover),
                                  )),
                                  Icon(Icons.lock, color: Colors.white.withValues(alpha: 0.8), size: 14),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: SizedBox(height: 8, child: LinearProgressIndicator(
                                  value: (_newStars / _nextHero!.cost).clamp(0.0, 1.0),
                                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                                  valueColor: AlwaysStoppedAnimation(_nextHero!.primaryColor),
                                )),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.star, color: Colors.yellowAccent, size: 14),
                            Text('$_starsToNextHero', style: TextStyle(
                              color: _nextHero!.primaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    if (_chestOpened)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(26, 14, 26, 0),
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Column(
                            children: [
                              Text(
                                'YOU ARE STACKING STARS LIKE A SUPER RANGER!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 1.3,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ..._buildComebackLines().map((line) => Padding(
                                    padding: const EdgeInsets.only(bottom: 3),
                                    child: Text(
                                      line,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: line.contains('SEE YOU SOON')
                                            ? const Color(0xFF69F0AE).withValues(alpha: 0.95)
                                            : const Color(0xFFFFD54F).withValues(alpha: 0.95),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11.5,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      ),

                    const Spacer(flex: 1),

                    // Buttons (only after chest opened)
                    if (_chestOpened) ...[
                      GestureDetector(
                        onTap: _brushAgain,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF00B8D4)]),
                            borderRadius: BorderRadius.circular(40),
                            boxShadow: [BoxShadow(color: const Color(0xFF00E5FF).withValues(alpha: 0.4), blurRadius: 16)],
                          ),
                          child: Text('BRUSH AGAIN', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 3)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      AnimatedBuilder(
                        animation: _doneButtonController,
                        builder: (context, child) => Transform.scale(
                          scale: 1.0 + _doneButtonController.value * 0.05, child: child),
                        child: GestureDetector(
                          onTap: _goHome,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF7C4DFF), Color(0xFF9C27B0)]),
                              borderRadius: BorderRadius.circular(40),
                              boxShadow: [BoxShadow(color: const Color(0xFF7C4DFF).withValues(alpha: 0.5), blurRadius: 20)],
                            ),
                            child: Text('DONE', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 4)),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChest() {
    if (!_chestOpened) {
      // Unopened chest — big, bouncing, tappable
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 600),
        curve: Curves.elasticOut,
        builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
        child: AnimatedBuilder(
          animation: _chestBounceController,
          builder: (context, child) {
            final bounce = sin(_chestBounceController.value * pi) * 8;
            final wobble = sin(_chestBounceController.value * pi * 2) * 0.03;
            return Transform.translate(
              offset: Offset(0, -bounce),
              child: Transform.rotate(angle: wobble, child: child),
            );
          },
          child: GestureDetector(
            onTap: _openChest,
            child: Container(
              width: 190, height: 190,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const RadialGradient(
                  colors: [Color(0x33FFF59D), Color(0x00FFF59D)],
                ),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFFFD54F).withValues(alpha: 0.65), blurRadius: 38, spreadRadius: 7),
                  BoxShadow(color: const Color(0xFFFF6F00).withValues(alpha: 0.3), blurRadius: 60, spreadRadius: 10),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Chest body
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                      width: 122, height: 24,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFA1887F), Color(0xFF6D4C41)],
                          ),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFFFD54F), width: 2),
                        ),
                      ),
                      Container(
                        width: 132, height: 78,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter, end: Alignment.bottomCenter,
                            colors: [Color(0xFFA1887F), Color(0xFF4E342E)],
                          ),
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                          border: Border.all(color: const Color(0xFFFFD54F), width: 2),
                        ),
                      ),
                    ],
                  ),
                  // Lock/clasp
                  Positioned(
                    top: 70,
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFFD54F),
                        border: Border.all(color: const Color(0xFFFFA000), width: 2),
                        boxShadow: [BoxShadow(color: const Color(0xFFFFD54F).withValues(alpha: 0.6), blurRadius: 10)],
                      ),
                      child: const Icon(Icons.lock, color: Color(0xFF5D4037), size: 18),
                    ),
                  ),
                  Positioned(
                    top: 18, right: 26,
                    child: Text('?', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  ),
                  Positioned(
                    left: 22,
                    top: 24 + sin(_chestBounceController.value * pi * 2) * 4,
                    child: const Icon(Icons.auto_awesome, color: Color(0xFFFFF59D), size: 18),
                  ),
                  Positioned(
                    right: 30,
                    bottom: 28 + cos(_chestBounceController.value * pi * 2) * 4,
                    child: const Icon(Icons.auto_awesome, color: Color(0xFFFFF59D), size: 16),
                  ),
                  Positioned(
                    top: 90,
                    left: 34,
                    right: 34,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD54F).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 112,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          colors: [Color(0xFF80D8FF), Color(0xFF00B8D4)],
                        ),
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF80D8FF).withValues(alpha: 0.8),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Opened chest — reveal reward
    return AnimatedBuilder(
      animation: Listenable.merge([_chestOpenController, _rewardRevealController]),
      builder: (context, _) {
        final openProgress = _chestOpenController.value;
        final revealProgress = _rewardRevealController.value;
        final reward = _reward!;

        return SizedBox(
          width: 200, height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow behind reward
              if (revealProgress > 0)
                Container(
                  width: 160 * revealProgress,
                  height: 160 * revealProgress,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                      color: reward.color.withValues(alpha: 0.4 * revealProgress),
                      blurRadius: 60, spreadRadius: 20,
                    )],
                  ),
                ),
              // Chest lid opening
              Transform.translate(
                offset: Offset(0, -openProgress * 80),
                child: Opacity(
                  opacity: (1 - openProgress).clamp(0.3, 1.0),
                  child: Transform.rotate(
                    angle: -openProgress * 0.5,
                    child: Container(
                      width: 100 - openProgress * 20, height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8D6E63),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFFFD54F), width: 2),
                      ),
                    ),
                  ),
                ),
              ),
              // Chest base
              Positioned(
                bottom: 40,
                child: Container(
                  width: 110, height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Color(0xFF8D6E63), Color(0xFF5D4037)],
                    ),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                    border: Border.all(color: const Color(0xFFFFD54F), width: 2),
                  ),
                ),
              ),
              // Reward icon rising from chest
              if (revealProgress > 0)
                Transform.translate(
                  offset: Offset(0, 20 - revealProgress * 70),
                  child: Transform.scale(
                    scale: revealProgress,
                    child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          reward.color,
                          reward.color.withValues(alpha: 0.6),
                        ]),
                        boxShadow: [BoxShadow(
                          color: reward.color.withValues(alpha: 0.6),
                          blurRadius: 30, spreadRadius: 5,
                        )],
                      ),
                      child: Icon(reward.icon, color: Colors.white, size: 44),
                    ),
                  ),
                ),
              // Bonus text
              if (revealProgress > 0.5 && reward.bonusStars > 0)
                Positioned(
                  top: 0,
                  child: Opacity(
                    opacity: ((revealProgress - 0.5) * 2).clamp(0.0, 1.0),
                    child: Text(
                      '+${reward.bonusStars}',
                      style: TextStyle(
                        color: reward.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 36,
                        shadows: [Shadow(color: reward.color.withValues(alpha: 0.8), blurRadius: 12)],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
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
      const Color(0xFFFF4081), const Color(0xFF7C4DFF), const Color(0xFF00E5FF),
      const Color(0xFFFFD54F), const Color(0xFF69F0AE), const Color(0xFFFF6E40),
    ];
    for (int i = 0; i < 120; i++) {
      final baseX = _random.nextDouble() * size.width;
      final sineDrift = sin((progress * 4 + i * 0.3)) * 30;
      final x = baseX + sineDrift;
      final speed = 0.6 + _random.nextDouble() * 0.8;
      final startY = -20.0 + _random.nextDouble() * -100;
      final y = startY + (size.height + 120) * ((progress * speed + i * 0.015) % 1.0);
      final color = colors[i % colors.length];
      final paint = Paint()..color = color.withValues(alpha: 0.8);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * 4 + i.toDouble());
      final shapeType = i % 3;
      if (shapeType == 0) {
        final w = 4.0 + _random.nextDouble() * 8;
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: w, height: w * 0.5), paint);
      } else if (shapeType == 1) {
        canvas.drawCircle(Offset.zero, 2.0 + _random.nextDouble() * 4, paint);
      } else {
        final s = 3.0 + _random.nextDouble() * 5;
        final path = Path()..moveTo(0, -s)..lineTo(s * 0.6, s * 0.4)..lineTo(-s * 0.6, s * 0.4)..close();
        canvas.drawPath(path, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => oldDelegate.progress != progress;
}
