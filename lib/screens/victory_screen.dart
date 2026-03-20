import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/audio_service.dart';
import '../services/streak_service.dart';
import '../services/hero_service.dart';
import '../services/weapon_service.dart';
import '../services/achievement_service.dart';
import '../services/world_service.dart';
import '../services/card_service.dart';
import '../widgets/space_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/achievement_popup.dart';
import '../services/analytics_service.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import 'home_screen.dart';
import 'card_album_screen.dart';

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
  int _previousStars = 0;
  int _starsEarnedThisSession = 0;
  List<Achievement> _newAchievements = [];
  // Next unlock: whichever of hero/weapon is closer
  String? _nextUnlockName;
  String? _nextUnlockImagePath;
  Color _nextUnlockColor = Colors.white;
  int _nextUnlockAt = 0;
  int _starsToNextUnlock = 0;
  bool _nextUnlockIsHero = true;
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
  bool _showCardDrop = false;
  bool _showDoneButton = false;

  // Card reveal animation controllers
  late AnimationController _cardFlyController;
  late AnimationController _cardGlowController;
  late AnimationController _newBadgeController;
  bool _showWorldProgress = false;
  bool _worldJustCompleted = false;
  int _collectedCardCount = 0;

  // Victory celebration arcs: each arc is a 3-beat connected story
  // [beat1 = celebration, beat2 = star earned, beat3 = chest prompt]
  static const _victoryArcs = [
    ['voice_victory_arc1_beat1.mp3', 'voice_victory_arc1_beat2.mp3', 'voice_victory_arc1_beat3.mp3'],
    ['voice_victory_arc2_beat1.mp3', 'voice_victory_arc2_beat2.mp3', 'voice_victory_arc2_beat3.mp3'],
    ['voice_victory_arc3_beat1.mp3', 'voice_victory_arc3_beat2.mp3', 'voice_victory_arc3_beat3.mp3'],
    ['voice_victory_arc4_beat1.mp3', 'voice_victory_arc4_beat2.mp3', 'voice_victory_arc4_beat3.mp3'],
  ];

  // Post-chest encouragement variants (replaces single voice_keep_going)
  static const _chestEncouragements = [
    'voice_chest_encourage_1.mp3',
    'voice_chest_encourage_2.mp3',
    'voice_chest_encourage_3.mp3',
  ];

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

    _cardFlyController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _cardGlowController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _newBadgeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _recordAndAnimate();
  }

  Future<void> _recordAndAnimate() async {
    final hero = await _heroService.getSelectedHero();
    _world = await _worldService.getCurrentWorld();
    _dailyModifier = _worldService.getDailyModifier();
    _previousStars = await _streakService.getTotalStars();
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

    final lifetimeBrushes = await _streakService.getTotalBrushes();

    _newAchievements = await _achievementService.checkAndUnlock(
      streak: _newStreak,
      totalStars: _newStars,
      totalBrushes: lifetimeBrushes,
    );

    // Award bonus stars from achievements
    final achievementBonus = _newAchievements.fold(0, (sum, a) => sum + a.bonusStars);
    if (achievementBonus > 0) {
      await _streakService.addBonusStars(achievementBonus);
      _newStars = await _streakService.getTotalStars();
    }

    // Pick whichever of next hero / next weapon unlocks sooner
    final nextHero = await _heroService.getNextLockedHero();
    final nextWeapon = await _weaponService.getNextLockedWeapon();
    _computeNextUnlock(nextHero, nextWeapon);
    _collectedCardCount = await _cardService.getCollectedCount();

    // Analytics: log completion + update user properties
    final analytics = AnalyticsService();
    analytics.logBrushSessionComplete(
      totalHits: widget.totalHits,
      monstersDefeated: widget.monstersDefeated,
      isBossSession: widget.isBossSession,
      starsEarned: _starsEarnedThisSession,
      newStreak: _newStreak,
      totalStars: _newStars,
    );
    analytics.setUserProperties(
      lifetimeBrushes: lifetimeBrushes,
      currentStreak: _newStreak,
      totalStars: _newStars,
    );

    if (mounted) setState(() {});

    // Auto-sync progress to cloud if signed in (fire-and-forget)
    if (AuthService().currentUser != null) {
      SyncService().uploadProgress().catchError((e) {
        debugPrint('Cloud sync failed: $e');
      });
    }

    // ── NEW TIMING SEQUENCE ──
    // t=0       Victory SFX + confetti
    _audio.playSfx('victory.mp3');
    _confettiController.repeat();

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    // t=300ms   Arc beat 1 (celebration) + star animation
    final arcIndex = _random.nextInt(_victoryArcs.length);
    final arc = _victoryArcs[arcIndex];
    _audio.playVoice(arc[0]); // celebration

    // Arc beat 2 (star earned) — queued via voice pipeline
    await _audio.playVoice(arc[1]); // "+1 star!"
    _starController.forward();
    _starRotationController.repeat();
    _starGlowController.repeat(reverse: true);

    // Chest drops after voice completes
    if (!mounted) return;
    setState(() => _showChest = true);
    _chestBounceController.repeat(reverse: true);
    _audio.playVoice(arc[2]); // chest prompt
    // NOTE: Achievements are now shown AFTER the chest/card sequence,
    // not concurrently. See _openChest for the scheduling.
  }

  /// Compare next locked hero and weapon; pick whichever unlocks sooner.
  void _computeNextUnlock(HeroCharacter? nextHero, WeaponItem? nextWeapon) {
    if (nextHero == null && nextWeapon == null) {
      // Everything unlocked — no progress bar.
      _nextUnlockName = null;
      return;
    }

    final bool pickHero;
    if (nextHero != null && nextWeapon != null) {
      // Pick whichever has the lower (closer) unlockAt threshold.
      pickHero = nextHero.unlockAt <= nextWeapon.unlockAt;
    } else {
      pickHero = nextHero != null;
    }

    if (pickHero) {
      _nextUnlockName = nextHero!.name;
      _nextUnlockImagePath = nextHero.imagePath;
      _nextUnlockColor = nextHero.primaryColor;
      _nextUnlockAt = nextHero.unlockAt;
      _nextUnlockIsHero = true;
    } else {
      _nextUnlockName = nextWeapon!.name;
      _nextUnlockImagePath = nextWeapon.imagePath;
      _nextUnlockColor = nextWeapon.primaryColor;
      _nextUnlockAt = nextWeapon.unlockAt;
      _nextUnlockIsHero = false;
    }
    _starsToNextUnlock = _nextUnlockAt - _newStars;
    if (_starsToNextUnlock < 0) _starsToNextUnlock = 0;
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
            if (_nextUnlockName != null) {
              _starsToNextUnlock = _nextUnlockAt - _newStars;
              if (_starsToNextUnlock < 0) _starsToNextUnlock = 0;
            }
          });
        }
      }

      // ── Card reveal (guaranteed drop) ──
      final drop = await _cardService.guaranteedCardDrop(_world.id);
      if (!mounted) return;

      // Short pause before card flies out
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      setState(() {
        _cardDrop = drop;
        _showCardDrop = true;
      });
      HapticFeedback.mediumImpact();
      _audio.playSfx('star_chime.mp3');

      // Card fly-in animation
      _cardFlyController.forward();

      // After fly-in, start glow + NEW badge + voice
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;

      _cardGlowController.repeat(reverse: true);
      if (drop.isNew) {
        _newBadgeController.forward();
        _audio.playVoice('voice_card_new.mp3');
      } else {
        // Duplicate card — show POWER UP badge with voice and check for bonus star
        _newBadgeController.forward();
        _audio.playVoice('voice_card_power_up.mp3');
        final bonusStars = await _cardService.checkDuplicateBonus();
        if (bonusStars > 0) {
          await _streakService.addBonusStars(bonusStars);
          _newStars = await _streakService.getTotalStars();
          _starsEarnedThisSession += bonusStars;
          if (mounted) setState(() {});
        }
      }
      // Play the specific card description voice
      await _audio.playVoice('voice_card_${drop.card.id}.mp3');
      if (!mounted) return;

      // Show world progress after card voice finishes
      setState(() {
        _showWorldProgress = true;
        _worldJustCompleted = drop.isNew &&
            drop.worldCollected == drop.worldTotal;
      });

      if (_worldJustCompleted) {
        HapticFeedback.heavyImpact();
        _audio.playSfx('victory.mp3');
      }

      // Short pause to let the kid see the world progress
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;

      // ── Milestone celebration (70/80/90 stars) ──
      for (final milestone in [70, 80, 90]) {
        if (_newStars >= milestone && _previousStars < milestone) {
          final voiceFile = 'voice_milestone_$milestone.mp3';
          await _audio.playVoice(voiceFile);
          _confettiController.repeat();
          await Future.delayed(const Duration(milliseconds: 500));
          break; // Only play one milestone per session
        }
      }
      if (!mounted) return;

      // ── Achievements (AFTER card reveal) ──
      for (int i = 0; i < _newAchievements.length; i++) {
        if (!mounted) break;
        if (i > 0) {
          await Future.delayed(const Duration(milliseconds: 1200));
        }
        if (mounted) _showAchievement(_newAchievements[i]);
      }

      // Wait a beat after last achievement before showing DONE
      if (_newAchievements.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 1000));
      }

      // Legendary ranger voice or next-unlock encouragement
      if (_nextUnlockName == null && _collectedCardCount >= 70 && mounted) {
        await _audio.playVoice('voice_legend.mp3');
      } else if (_nextUnlockName != null && _starsToNextUnlock > 0 && mounted) {
        _audio.playVoice(
          _chestEncouragements[_random.nextInt(_chestEncouragements.length)],
        );
      }

      // ── DONE button with whoosh SFX ──
      if (mounted) {
        _audio.playSfx('whoosh.mp3');
        setState(() => _showDoneButton = true);
        _doneButtonController.repeat(reverse: true);
      }
    });
  }


  void _openCardAlbum() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CardAlbumScreen()),
    );
  }

  /// Rarity-based glow color for card reveal.
  Color _rarityGlowColor(CardRarity rarity) => switch (rarity) {
    CardRarity.common => const Color(0xFF00E5FF), // cyan
    CardRarity.rare => const Color(0xFFB388FF),   // purple
    CardRarity.epic => const Color(0xFFFFD54F),   // gold
  };

  Widget _buildCardDropReveal() {
    final drop = _cardDrop!;
    final glowColor = _rarityGlowColor(drop.card.rarity);

    return AnimatedBuilder(
      animation: Listenable.merge([_cardFlyController, _cardGlowController]),
      builder: (context, _) {
        final flyProgress = Curves.easeOutBack.transform(
          _cardFlyController.value.clamp(0.0, 1.0),
        );
        final glowPulse = _cardGlowController.value;
        final cardScale = flyProgress;
        final cardOpacity = flyProgress.clamp(0.0, 1.0);

        return Opacity(
          opacity: cardOpacity,
          child: Transform.scale(
            scale: cardScale,
            child: GestureDetector(
              onTap: _openCardAlbum,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  children: [
                    // Main card reveal
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Rarity glow behind card
                        Container(
                          width: 160 + glowPulse * 20,
                          height: 180 + glowPulse * 20,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: glowColor.withValues(
                                  alpha: 0.3 + glowPulse * 0.3,
                                ),
                                blurRadius: 40 + glowPulse * 20,
                                spreadRadius: 5 + glowPulse * 10,
                              ),
                            ],
                          ),
                        ),
                        // Card body
                        Container(
                          width: 150,
                          height: 180,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: glowColor.withValues(alpha: 0.7),
                              width: 2.5,
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF1A1A2E),
                                drop.card.tintColor.withValues(alpha: 0.3),
                              ],
                            ),
                          ),
                          child: Stack(
                            children: [
                              // Monster image
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 8, bottom: 36),
                                  child: ColorFiltered(
                                    colorFilter: ColorFilter.mode(
                                      drop.card.tintColor.withValues(alpha: 0.35),
                                      BlendMode.srcATop,
                                    ),
                                    child: Image.asset(
                                      drop.card.imagePath,
                                      width: 90,
                                      height: 90,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                              // Name + rarity at bottom
                              Positioned(
                                left: 8,
                                right: 8,
                                bottom: 8,
                                child: Column(
                                  children: [
                                    Text(
                                      drop.card.name,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      drop.card.rarityLabel,
                                      style: TextStyle(
                                        color: drop.card.rarityColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // "NEW!" or "POWER UP!" badge (animated)
                              Positioned(
                                top: -2,
                                right: -2,
                                child: AnimatedBuilder(
                                  animation: _newBadgeController,
                                  builder: (context, child) {
                                    final badgeScale = Curves.elasticOut
                                        .transform(_newBadgeController.value);
                                    return Transform.scale(
                                      scale: badgeScale,
                                      child: child,
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: drop.isNew
                                          ? const Color(0xFF69F0AE)
                                          : const Color(0xFFFFD54F),
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (drop.isNew
                                                  ? const Color(0xFF69F0AE)
                                                  : const Color(0xFFFFD54F))
                                              .withValues(alpha: 0.6),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      drop.isNew ? 'NEW!' : 'POWER UP!',
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 11,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Epic scale bounce effect
                              if (drop.card.rarity == CardRarity.epic &&
                                  glowPulse > 0)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: const Color(0xFFFFD54F)
                                            .withValues(alpha: glowPulse * 0.5),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // World progress indicator
                    if (_showWorldProgress) ...[
                      const SizedBox(height: 12),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOut,
                        builder: (context, opacity, child) =>
                            Opacity(opacity: opacity, child: child),
                        child: Column(
                          children: [
                            Text(
                              '${drop.worldCollected}/${drop.worldTotal} ${drop.worldName} monsters found!',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_worldJustCompleted) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFFD54F),
                                      Color(0xFFFF6D00),
                                    ],
                                  ),
                                ),
                                child: const Text(
                                  'WORLD COMPLETE!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    // Tap hint
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Tap to see album',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 11,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: Colors.white.withValues(alpha: 0.4),
                          size: 16,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static const _achievementVoices = [
    'voice_wow_amazing.mp3',
    'voice_awesome.mp3',
    'voice_super.mp3',
  ];
  int _achievementVoiceIndex = 0;

  void _showAchievement(Achievement achievement) {
    _audio.playSfx('whoosh.mp3');
    // Rotate through celebratory voices so achievements don't all sound the same.
    final voice =
        _achievementVoices[_achievementVoiceIndex % _achievementVoices.length];
    _achievementVoiceIndex++;
    _audio.playVoice(voice);
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
    _cardFlyController.dispose();
    _cardGlowController.dispose();
    _newBadgeController.dispose();
    super.dispose();
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomeScreen(skipGreeting: true),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _showDoneButton,
      child: Scaffold(
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

                    // Next unlock progress — hero or weapon, whichever is closer
                    if (_chestOpened &&
                        _nextUnlockName != null &&
                        _starsToNextUnlock > 0)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 16,
                          left: 40,
                          right: 40,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: _nextUnlockIsHero
                                    ? BoxShape.circle
                                    : BoxShape.rectangle,
                                borderRadius: _nextUnlockIsHero
                                    ? null
                                    : BorderRadius.circular(10),
                                border: Border.all(
                                  color: _nextUnlockColor,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _nextUnlockColor.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      _nextUnlockIsHero ? 20 : 8,
                                    ),
                                    child: ColorFiltered(
                                      colorFilter: const ColorFilter.mode(
                                        Colors.black54,
                                        BlendMode.saturation,
                                      ),
                                      child: Image.asset(
                                        _nextUnlockImagePath!,
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.lock,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(7),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _nextUnlockColor.withValues(alpha: 0.35),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(7),
                                  child: SizedBox(
                                    height: 14,
                                    child: LinearProgressIndicator(
                                      value: (_newStars / _nextUnlockAt).clamp(
                                        0.0,
                                        1.0,
                                      ),
                                      backgroundColor: Colors.white.withValues(
                                        alpha: 0.15,
                                      ),
                                      valueColor: AlwaysStoppedAnimation(
                                        _nextUnlockColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.star,
                              color: Colors.yellowAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '$_starsToNextUnlock',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                shadows: [
                                  Shadow(
                                    color: _nextUnlockColor.withValues(alpha: 0.8),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    // LEGENDARY RANGER badge (all heroes/weapons/70+ cards)
                    if (_chestOpened &&
                        _nextUnlockName == null &&
                        _collectedCardCount >= 70)
                      Padding(
                        padding: const EdgeInsets.only(top: 16, left: 40, right: 40),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD54F), Color(0xFFFF6D00)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFD54F).withValues(alpha: 0.5),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'LEGENDARY RANGER',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Card collection progress (shown when all heroes/weapons unlocked)
                    if (_chestOpened &&
                        _nextUnlockName == null &&
                        _collectedCardCount < CardService.allCards.length)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 16, left: 40, right: 40,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.style,
                              color: Color(0xFF00E5FF),
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: SizedBox(
                                  height: 14,
                                  child: LinearProgressIndicator(
                                    value: (_collectedCardCount /
                                            CardService.allCards.length)
                                        .clamp(0.0, 1.0),
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.15),
                                    valueColor: const AlwaysStoppedAnimation(
                                      Color(0xFF00E5FF),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$_collectedCardCount/${CardService.allCards.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Card drop reveal
                    if (_showCardDrop && _cardDrop != null)
                      _buildCardDropReveal(),

                    const SizedBox(height: 24),

                    // Buttons (only after full reward sequence)
                    if (_showDoneButton) ...[
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
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.home, color: Colors.white, size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  'DONE',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        letterSpacing: 4,
                                      ),
                                ),
                              ],
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
            final bounce = sin(_chestBounceController.value * pi) * 12;
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
                    width: 260,
                    height: 250,
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
