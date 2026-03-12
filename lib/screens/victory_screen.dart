import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/audio_service.dart';
import '../services/streak_service.dart';
import '../services/hero_service.dart';
import '../services/achievement_service.dart';
import '../services/world_service.dart';
import '../services/card_service.dart';
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
  final String label;

  const _ChestReward({
    required this.type,
    required this.bonusStars,
    required this.voiceFile,
    required this.color,
    required this.icon,
    required this.label,
  });
}

// Streak-aware reward selection using variable ratio scheduling.
// Higher streaks increase chances of better rewards.
_ChestReward _rollChestReward(Random rng, int streak) {
  final roll = rng.nextInt(100);

  // Streak >= 7: 20% confetti, 15% dance, 30% bonus, 18% double, 10% jackpot, 7% mega
  // Streak >= 3: 25% confetti, 20% dance, 25% bonus, 15% double, 10% jackpot, 5% mega
  // No streak:   35% confetti, 25% dance, 25% bonus, 10% double, 4% jackpot, 1% mega
  final int confettiCeil;
  final int danceCeil;
  final int bonusCeil;
  final int doubleCeil;
  final int jackpotCeil;
  // remainder = mega jackpot

  if (streak >= 7) {
    confettiCeil = 20;
    danceCeil = 35;
    bonusCeil = 65;
    doubleCeil = 83;
    jackpotCeil = 93;
  } else if (streak >= 3) {
    confettiCeil = 25;
    danceCeil = 45;
    bonusCeil = 70;
    doubleCeil = 85;
    jackpotCeil = 95;
  } else {
    confettiCeil = 35;
    danceCeil = 60;
    bonusCeil = 85;
    doubleCeil = 95;
    jackpotCeil = 99;
  }

  if (roll < confettiCeil) {
    return const _ChestReward(
      type: _ChestRewardType.confetti,
      bonusStars: 0,
      voiceFile: 'voice_chest_wow.mp3',
      color: Color(0xFF00E5FF),
      icon: Icons.celebration,
      label: 'PARTY TIME!',
    );
  } else if (roll < danceCeil) {
    return const _ChestReward(
      type: _ChestRewardType.dance,
      bonusStars: 0,
      voiceFile: 'voice_chest_dance.mp3',
      color: Color(0xFFFF4081),
      icon: Icons.music_note,
      label: 'DANCE BREAK!',
    );
  } else if (roll < bonusCeil) {
    return const _ChestReward(
      type: _ChestRewardType.bonusStar,
      bonusStars: 1,
      voiceFile: 'voice_chest_bonus_star.mp3',
      color: Color(0xFFFFD54F),
      icon: Icons.star,
      label: 'BONUS STAR!',
    );
  } else if (roll < doubleCeil) {
    return const _ChestReward(
      type: _ChestRewardType.doubleStar,
      bonusStars: 1,
      voiceFile: 'voice_chest_double.mp3',
      color: Color(0xFF69F0AE),
      icon: Icons.auto_awesome,
      label: 'DOUBLE POWER!',
    );
  } else if (roll < jackpotCeil) {
    return const _ChestReward(
      type: _ChestRewardType.jackpot,
      bonusStars: 3,
      voiceFile: 'voice_chest_jackpot.mp3',
      color: Color(0xFFFFD54F),
      icon: Icons.emoji_events,
      label: 'JACKPOT!',
    );
  } else {
    return const _ChestReward(
      type: _ChestRewardType.jackpot,
      bonusStars: 5,
      voiceFile: 'voice_chest_jackpot.mp3',
      color: Color(0xFFFF6D00),
      icon: Icons.emoji_events,
      label: 'MEGA JACKPOT!',
    );
  }
}

class VictoryScreen extends StatefulWidget {
  final int starsCollected;
  final int totalHits;
  final int monstersDefeated;
  final bool isBossSession;
  final String? sessionId;
  const VictoryScreen({
    super.key,
    this.starsCollected = 1,
    this.totalHits = 0,
    this.monstersDefeated = 4,
    this.isBossSession = false,
    this.sessionId,
  });

  @override
  State<VictoryScreen> createState() => _VictoryScreenState();
}

class _VictoryScreenState extends State<VictoryScreen>
    with TickerProviderStateMixin {
  final _audio = AudioService();
  final _streakService = StreakService();
  final _heroService = HeroService();
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
  int _starsEarnedThisSession = 0;
  List<Achievement> _newAchievements = [];
  HeroCharacter? _nextHero;
  int _starsToNextHero = 0;
  WorldData _world = WorldService.allWorlds[0];
  DailyModifier _dailyModifier = const DailyModifier(
    type: DailyModifierType.none,
    title: 'NORMAL MISSION',
    description: 'Steady progress day.',
    icon: Icons.public,
    color: Color(0xFFB388FF),
  );

  final _cardService = CardService();

  bool _showChest = false;
  bool _chestOpened = false;
  _ChestReward? _reward;
  CardDropResult? _cardDrop;
  MonsterCard? _previewCard;
  bool _showCardDrop = false;

  @override
  void initState() {
    super.initState();

    _starController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _starScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _starController, curve: Curves.elasticOut),
    );
    _starRotationController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );
    _starGlowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _confettiController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _doneButtonController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _chestBounceController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _chestOpenController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _rewardRevealController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _recordAndAnimate();
  }

  Future<void> _recordAndAnimate() async {
    final hero = await _heroService.getSelectedHero();
    _world = await _worldService.getCurrentWorld();
    _dailyModifier = _worldService.getDailyModifier();
    final outcome = await _streakService.recordBrush(
      heroId: hero.id,
      worldId: _world.id,
    );
    _starsEarnedThisSession = outcome.starsEarned;
    if (outcome.starsEarned > 0) {
      await _worldService.recordMission();
    }
    _newStreak = await _streakService.getStreak();
    _newStars = await _streakService.getTotalStars();
    await _worldService.getWorldProgress(_world.id);

    _newAchievements = await _achievementService.checkAndUnlock(
      streak: _newStreak,
      totalStars: _newStars,
    );

    _nextHero = await _heroService.getNextLockedHero();
    if (_nextHero != null) {
      _starsToNextHero = _nextHero!.cost - _newStars;
      if (_starsToNextHero < 0) _starsToNextHero = 0;
    }

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

    _reward = _rollChestReward(_random, _newStreak);
    _chestBounceController.stop();
    _chestOpenController.forward();

    _audio.playSfx('star_chime.mp3');

    Future.delayed(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      _rewardRevealController.forward();
      if (_reward!.bonusStars > 0) HapticFeedback.mediumImpact();
      await _audio.playVoice(_reward!.voiceFile);

      final totalBonus = _reward!.bonusStars + _dailyModifier.chestBonusStars;
      if (totalBonus > 0) {
        await _streakService.addBonusStars(totalBonus);
        final updated = await _streakService.getTotalStars();
        _newStars = updated;
        if (mounted) {
          setState(() {
            if (_nextHero != null) {
              _starsToNextHero = _nextHero!.cost - _newStars;
              if (_starsToNextHero < 0) _starsToNextHero = 0;
            }
          });
        }
      }

      if (mounted) _doneButtonController.repeat(reverse: true);

      // Roll for card drop
      final drop = await _cardService.rollCardDrop(_world.id, _newStreak);
      if (drop != null && mounted) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        setState(() {
          _cardDrop = drop;
          _showCardDrop = true;
        });
        HapticFeedback.mediumImpact();
        _audio.playSfx('star_chime.mp3');
        _audio.playVoice(drop.isNew ? 'voice_card_new.mp3' : 'voice_card_fragment.mp3');
      }

      // Load tomorrow's preview
      final preview = await _cardService.getPreviewCard(_world.id);
      if (preview != null && mounted) {
        setState(() => _previewCard = preview);
      }
    });
  }


  Widget _buildCardDropReveal() {
    final drop = _cardDrop!;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: GlassCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Card image
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: drop.card.rarityColor.withValues(alpha: 0.6),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: drop.card.rarityColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ShaderMask(
                    shaderCallback: (bounds) => RadialGradient(
                      colors: [
                        Colors.white,
                        Colors.white.withValues(alpha: 0.0),
                      ],
                      radius: 0.85,
                    ).createShader(bounds),
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        drop.card.tintColor.withValues(alpha: 0.35),
                        BlendMode.srcATop,
                      ),
                      child: Image.asset(
                        drop.card.imagePath,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      drop.isNew ? 'NEW CARD!' : 'CARD FRAGMENT +1',
                      style: TextStyle(
                        color: drop.isNew
                            ? const Color(0xFF69F0AE)
                            : const Color(0xFFFFD54F),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      drop.card.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      drop.card.rarityLabel,
                      style: TextStyle(
                        color: drop.card.rarityColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTomorrowPreview() {
    final card = _previewCard!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Silhouette
            SizedBox(
              width: 40,
              height: 40,
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Colors.black54,
                  BlendMode.srcATop,
                ),
                child: Image.asset(card.imagePath, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A NEW MONSTER IS LURKING...',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Brush again to find it!',
                    style: TextStyle(
                      color: const Color(0xFF69F0AE).withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.help_outline,
              color: Colors.white.withValues(alpha: 0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
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
        pageBuilder: (context, animation, secondaryAnimation) =>
            const BrushingScreen(),
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
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomeScreen(),
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
                    color: const Color(
                      0xFFFFD54F,
                    ).withValues(alpha: _rewardRevealController.value * 0.15),
                  ),
                ),

              Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 24),

                    // Big star
                    AnimatedBuilder(
                      animation: Listenable.merge([
                        _starScale,
                        _starRotationController,
                        _starGlowController,
                      ]),
                      builder: (context, child) {
                        final glow = 0.4 + _starGlowController.value * 0.4;
                        return ScaleTransition(
                          scale: _starScale,
                          child: Transform.rotate(
                            angle: _starRotationController.value * 2 * pi * 0.1,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const RadialGradient(
                                  colors: [
                                    Color(0xFFFFD54F),
                                    Color(0xFFFFA000),
                                    Color(0xFFFF6F00),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFFFD54F,
                                    ).withValues(alpha: glow),
                                    blurRadius: 50,
                                    spreadRadius: 15,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.star,
                                size: 70,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'GREAT JOB!',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: const Color(
                                  0xFFFFD54F,
                                ).withValues(alpha: 0.8),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                    ),

                    const SizedBox(height: 10),
                    if (_starsEarnedThisSession > 0)
                      Text(
                        '+$_starsEarnedThisSession STAR THIS SESSION',
                        style: const TextStyle(
                          color: Color(0xFFFFD54F),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    const SizedBox(height: 12),

                    // Star bank
                    GlassCard(
                      margin: const EdgeInsets.symmetric(horizontal: 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star,
                            color: Colors.yellowAccent,
                            size: 32,
                          ),
                          const SizedBox(width: 8),
                          TweenAnimationBuilder<int>(
                            tween: IntTween(begin: 0, end: _newStars),
                            duration: const Duration(milliseconds: 1500),
                            builder: (context, val, _) => Text(
                              '$val',
                              style: Theme.of(context).textTheme.headlineLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 32,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // TREASURE CHEST
                    if (_showChest) _buildChest(),

                    // Next hero progress (only after chest is opened)
                    if (_chestOpened &&
                        _nextHero != null &&
                        _starsToNextHero > 0)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 16,
                          left: 48,
                          right: 48,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _nextHero!.primaryColor,
                                  width: 2,
                                ),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  ClipOval(
                                    child: ColorFiltered(
                                      colorFilter: const ColorFilter.mode(
                                        Colors.black54,
                                        BlendMode.saturation,
                                      ),
                                      child: Image.asset(
                                        _nextHero!.imagePath,
                                        width: 32,
                                        height: 32,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.lock,
                                    color: Colors.white.withValues(alpha: 0.8),
                                    size: 14,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: SizedBox(
                                  height: 8,
                                  child: LinearProgressIndicator(
                                    value: (_newStars / _nextHero!.cost).clamp(
                                      0.0,
                                      1.0,
                                    ),
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.1,
                                    ),
                                    valueColor: AlwaysStoppedAnimation(
                                      _nextHero!.primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.star,
                              color: Colors.yellowAccent,
                              size: 14,
                            ),
                            Text(
                              '$_starsToNextHero',
                              style: TextStyle(
                                color: _nextHero!.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Card drop reveal
                    if (_showCardDrop && _cardDrop != null)
                      _buildCardDropReveal(),

                    // Tomorrow's preview
                    if (_chestOpened && _previewCard != null && !_showCardDrop)
                      _buildTomorrowPreview(),

                    const SizedBox(height: 24),

                    // Buttons (only after chest opened)
                    if (_chestOpened) ...[
                      GestureDetector(
                        onTap: _brushAgain,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 48,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00E5FF), Color(0xFF00B8D4)],
                            ),
                            borderRadius: BorderRadius.circular(40),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF00E5FF,
                                ).withValues(alpha: 0.4),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                          child: Text(
                            'BRUSH AGAIN',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  letterSpacing: 3,
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      AnimatedBuilder(
                        animation: _doneButtonController,
                        builder: (context, child) => Transform.scale(
                          scale: 1.0 + _doneButtonController.value * 0.05,
                          child: child,
                        ),
                        child: GestureDetector(
                          onTap: _goHome,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 60,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF7C4DFF), Color(0xFF9C27B0)],
                              ),
                              borderRadius: BorderRadius.circular(40),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF7C4DFF,
                                  ).withValues(alpha: 0.5),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                            child: Text(
                              'DONE',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    letterSpacing: 4,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                  ],
                ),
                ),
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
      // Unopened chest — richer chest illustration
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 600),
        curve: Curves.elasticOut,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: AnimatedBuilder(
          animation: _chestBounceController,
          builder: (context, child) {
            final bounce = sin(_chestBounceController.value * pi) * 8;
            final wobble = sin(_chestBounceController.value * pi * 2) * 0.03;
            final sparkleDrift = sin(_chestBounceController.value * pi * 2) * 5;
            return GestureDetector(
              onTap: _openChest,
              behavior: HitTestBehavior.opaque,
              child: Transform.translate(
                offset: Offset(0, -bounce),
                child: Transform.rotate(
                  angle: wobble,
                  child: SizedBox(
                    width: 220,
                    height: 210,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 208,
                          height: 208,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              colors: [Color(0x55FFF59D), Color(0x00FFF59D)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFFFD54F,
                                ).withValues(alpha: 0.55),
                                blurRadius: 40,
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          bottom: 18,
                          child: Container(
                            width: 170,
                            height: 18,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(40),
                              color: Colors.black.withValues(alpha: 0.26),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 42,
                          child: Container(
                            width: 168,
                            height: 88,
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(24),
                              ),
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFF8D5A33), Color(0xFF5D3420)],
                              ),
                              border: Border.all(
                                color: const Color(0xFF4E2A17),
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 104,
                          child: Container(
                            width: 178,
                            height: 68,
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(42),
                                bottom: Radius.circular(16),
                              ),
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFFB77845), Color(0xFF7A4A2D)],
                              ),
                              border: Border.all(
                                color: const Color(0xFF5F371F),
                                width: 2.5,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 78,
                          child: Container(
                            width: 34,
                            height: 36,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFFFFF176), Color(0xFFFFC107)],
                              ),
                              border: Border.all(
                                color: const Color(0xFFFFA000),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFFFD54F,
                                  ).withValues(alpha: 0.4),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.lock,
                              color: Color(0xFF6D4C41),
                              size: 18,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 113,
                          child: Container(
                            width: 184,
                            height: 10,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: const Color(0xFFFFC107),
                              border: Border.all(
                                color: const Color(0xFFFFA000),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 65,
                          child: Container(
                            width: 168,
                            height: 11,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: const Color(0xFFFFC107),
                              border: Border.all(
                                color: const Color(0xFFFFA000),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 30 + sparkleDrift,
                          left: 30,
                          child: const Icon(
                            Icons.auto_awesome,
                            color: Color(0xFFFFF59D),
                            size: 20,
                          ),
                        ),
                        Positioned(
                          right: 28,
                          top: 56 - sparkleDrift * 0.8,
                          child: const Icon(
                            Icons.auto_awesome,
                            color: Color(0xFFFFF59D),
                            size: 16,
                          ),
                        ),
                        Positioned(
                          right: 40,
                          bottom: 56 + sparkleDrift * 0.5,
                          child: const Icon(
                            Icons.auto_awesome,
                            color: Color(0xFFFFF59D),
                            size: 14,
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.black.withValues(alpha: 0.28),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Text(
                              'TAP TO OPEN',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                fontSize: 10,
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
          },
        ),
      );
    }

    // Opened chest — reveal reward
    return AnimatedBuilder(
      animation: Listenable.merge([
        _chestOpenController,
        _rewardRevealController,
      ]),
      builder: (context, _) {
        final openProgress = _chestOpenController.value;
        final revealProgress = _rewardRevealController.value;
        final reward = _reward!;
        final lidLift = Curves.easeOutBack.transform(openProgress);

        return SizedBox(
          width: 260,
          height: 280,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow behind reward
              if (revealProgress > 0)
                Container(
                  width: 200 * revealProgress,
                  height: 200 * revealProgress,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: reward.color.withValues(
                          alpha: 0.5 * revealProgress,
                        ),
                        blurRadius: 80,
                        spreadRadius: 30,
                      ),
                    ],
                  ),
                ),
              Positioned(
                bottom: 26,
                child: Container(
                  width: 180,
                  height: 20,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    color: Colors.black.withValues(alpha: 0.26),
                  ),
                ),
              ),
              Positioned(
                bottom: 52,
                child: Container(
                  width: 172,
                  height: 90,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(24),
                    ),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF8D5A33), Color(0xFF5D3420)],
                    ),
                    border: Border.all(
                      color: const Color(0xFF4E2A17),
                      width: 2.5,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 74,
                child: Container(
                  width: 172,
                  height: 11,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFFFFC107),
                    border: Border.all(
                      color: const Color(0xFFFFA000),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              // Chest lid opening
              Transform.translate(
                offset: Offset(0, -lidLift * 88),
                child: Opacity(
                  opacity: (1 - openProgress).clamp(0.3, 1.0),
                  child: Transform.rotate(
                    angle: -openProgress * 0.7,
                    child: Container(
                      width: 182,
                      height: 70,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(42),
                          bottom: Radius.circular(16),
                        ),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFB77845), Color(0xFF7A4A2D)],
                        ),
                        border: Border.all(
                          color: const Color(0xFF5F371F),
                          width: 2.5,
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: 182,
                          height: 10,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: const Color(0xFFFFC107),
                            border: Border.all(
                              color: const Color(0xFFFFA000),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Reward icon rising from chest (larger)
              if (revealProgress > 0)
                Transform.translate(
                  offset: Offset(0, 14 - revealProgress * 100),
                  child: Transform.scale(
                    scale: revealProgress,
                    child: Container(
                      width: 108,
                      height: 108,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            reward.color,
                            reward.color.withValues(alpha: 0.6),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: reward.color.withValues(alpha: 0.7),
                            blurRadius: 40,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(reward.icon, color: Colors.white, size: 56),
                    ),
                  ),
                ),
              // Sparkle decorations
              if (revealProgress > 0.2)
                Positioned(
                  top: 8,
                  left: 30,
                  child: Opacity(
                    opacity: revealProgress,
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Color(0xFFFFF59D),
                      size: 20,
                    ),
                  ),
                ),
              if (revealProgress > 0.2)
                Positioned(
                  top: 14,
                  right: 28,
                  child: Opacity(
                    opacity: revealProgress,
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Color(0xFFFFF59D),
                      size: 18,
                    ),
                  ),
                ),
              if (revealProgress > 0.3)
                Positioned(
                  top: 42,
                  left: 16,
                  child: Opacity(
                    opacity: revealProgress,
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Color(0xFFFFF59D),
                      size: 14,
                    ),
                  ),
                ),
              if (revealProgress > 0.3)
                Positioned(
                  top: 38,
                  right: 18,
                  child: Opacity(
                    opacity: revealProgress,
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Color(0xFFFFF59D),
                      size: 16,
                    ),
                  ),
                ),
              // Reward label — large, clear text
              if (revealProgress > 0.4)
                Positioned(
                  top: 0,
                  child: Opacity(
                    opacity: ((revealProgress - 0.4) / 0.3).clamp(0.0, 1.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: reward.color.withValues(alpha: 0.2),
                        border: Border.all(
                          color: reward.color.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        reward.label,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          letterSpacing: 1.5,
                          shadows: [
                            Shadow(
                              color: reward.color,
                              blurRadius: 16,
                            ),
                            Shadow(
                              color: reward.color.withValues(alpha: 0.6),
                              blurRadius: 30,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              // Bonus stars text (below label)
              if (revealProgress > 0.5 && reward.bonusStars > 0)
                Positioned(
                  bottom: 8,
                  child: Opacity(
                    opacity: ((revealProgress - 0.5) * 2).clamp(0.0, 1.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '+${reward.bonusStars} ',
                          style: TextStyle(
                            color: const Color(0xFFFFD54F),
                            fontWeight: FontWeight.bold,
                            fontSize: 32,
                            shadows: [
                              Shadow(
                                color: const Color(0xFFFFD54F).withValues(
                                  alpha: 0.8,
                                ),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.star,
                          color: Color(0xFFFFD54F),
                          size: 30,
                        ),
                      ],
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
      const Color(0xFFFF4081),
      const Color(0xFF7C4DFF),
      const Color(0xFF00E5FF),
      const Color(0xFFFFD54F),
      const Color(0xFF69F0AE),
      const Color(0xFFFF6E40),
    ];
    for (int i = 0; i < 120; i++) {
      final baseX = _random.nextDouble() * size.width;
      final sineDrift = sin((progress * 4 + i * 0.3)) * 30;
      final x = baseX + sineDrift;
      final speed = 0.6 + _random.nextDouble() * 0.8;
      final startY = -20.0 + _random.nextDouble() * -100;
      final y =
          startY + (size.height + 120) * ((progress * speed + i * 0.015) % 1.0);
      final color = colors[i % colors.length];
      final paint = Paint()..color = color.withValues(alpha: 0.8);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * 4 + i.toDouble());
      final shapeType = i % 3;
      if (shapeType == 0) {
        final w = 4.0 + _random.nextDouble() * 8;
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: w, height: w * 0.5),
          paint,
        );
      } else if (shapeType == 1) {
        canvas.drawCircle(Offset.zero, 2.0 + _random.nextDouble() * 4, paint);
      } else {
        final s = 3.0 + _random.nextDouble() * 5;
        final path = Path()
          ..moveTo(0, -s)
          ..lineTo(s * 0.6, s * 0.4)
          ..lineTo(-s * 0.6, s * 0.4)
          ..close();
        canvas.drawPath(path, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
