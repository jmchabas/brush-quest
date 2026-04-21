import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/audio_service.dart';
import '../services/streak_service.dart';
import '../services/hero_service.dart';
import '../services/weapon_service.dart';
import '../services/achievement_service.dart';
import '../services/world_service.dart';
import '../services/trophy_service.dart';
import '../widgets/space_background.dart';
import '../widgets/achievement_popup.dart';
import '../widgets/trophy_detail_dialog.dart';
import '../services/analytics_service.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import 'home_screen.dart';

enum _ChestRewardType { confetti, dance, bonusStar, doubleStar, jackpot }

/// Forward hook types shown after the chest sequence to encourage the next brush.
enum _ForwardHookType {
  /// Morning done, evening not yet: moon icon + "see you tonight"
  tonight,

  /// Both slots done today: star burst + "full power!"
  fullPower,

  /// Evening done, morning was not done: sun icon + "see you in the morning"
  morning,
}

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
      bonusStars: 1,
      voiceFile: 'voice_chest_wow.mp3',
      color: Color(0xFF00E5FF),
      icon: Icons.celebration,
      label: 'PARTY TIME!',
    );
  } else if (roll < danceCeil) {
    return const _ChestReward(
      type: _ChestRewardType.dance,
      bonusStars: 1,
      voiceFile: 'voice_chest_dance_v2.mp3',
      color: Color(0xFFFF4081),
      icon: Icons.music_note,
      label: '',
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
      bonusStars: 2,
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
  final int totalHits;
  final int monstersDefeated;
  final String sessionId;
  final String? trophyTargetId;
  const VictoryScreen({
    super.key,
    this.totalHits = 0,
    this.monstersDefeated = 4,
    this.sessionId = '',
    this.trophyTargetId,
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

  late AnimationController _confettiController;
  late AnimationController _doneButtonController;
  late AnimationController _chestBounceController;
  late AnimationController _chestOpenController;
  late AnimationController _rewardRevealController;
  int _newStreak = 0;
  int _newStars = 0;
  int _previousStars = 0;
  int _starsEarnedThisSession = 0;
  int _previousWallet = 0;
  int _newWallet = 0;
  // Bonus breakdown for star rain waves
  int _dailyBonus = 0;
  int _streakMultiplierBonus = 0;
  int _comebackBonus = 0;
  List<Achievement> _newAchievements = [];
  WorldData _world = WorldService.allWorlds[0];
  DailyModifier _dailyModifier = const DailyModifier(
    type: DailyModifierType.none,
    title: 'NORMAL MISSION',
    description: 'Steady progress day.',
    icon: Icons.public,
    color: Color(0xFFB388FF),
  );

  final _trophyService = TrophyService();

  bool _brushRecorded = false;
  bool _showChest = false;
  bool _chestOpened = false;
  _ChestReward? _reward;
  bool _showDoneButton = false;
  Timer? _doneSafetyTimer;

  // Top bar state
  final _walletPillKey = GlobalKey();
  late AnimationController _walletBumpController;
  int _previousStreak = 0;
  HeroCharacter _selectedHero = HeroService.allHeroes[0];

  // Star flight animation state
  bool _showStarFlight = false;
  Offset _starFlightSource = Offset.zero;
  Offset _starFlightTarget = Offset.zero;

  // Hero celebration state
  late AnimationController _heroCelebrationController;
  late Animation<double> _heroScaleAnim;
  late AnimationController _heroGlowController;
  int _heroEvolutionStage = 1;
  String _heroWeaponId = 'star_blaster';

  // Trophy reveal state
  bool _showTrophyReveal = false;
  bool _trophyCaptured = false;
  int _trophyDefeats = 0;
  int _trophyRequired = 0;
  TrophyMonster? _revealedTrophy;
  int _totalTrophies = 0;
  bool _isShowcase =
      false; // endgame showcase: caught monster displayed without banner

  // Trophy reveal animation controllers (reuse card names for compatibility)
  late AnimationController _cardFlyController;
  late AnimationController _cardGlowController;
  late AnimationController _newBadgeController;
  bool _showWorldProgress = false;
  bool _worldJustCompleted = false;

  // Forward hook state (session-end encouragement — voice only)
  bool _forwardHookFired = false;

  // Victory celebration arcs: 2-beat connected story
  // [beat1 = celebration, beat2 = star earned]
  // beat3 (chest prompt) removed — chest is self-explanatory.
  static const _victoryArcs = [
    ['voice_victory_arc1_beat1.mp3', 'voice_victory_arc1_beat2.mp3'],
    ['voice_victory_arc2_beat1.mp3', 'voice_victory_arc2_beat2.mp3'],
    ['voice_victory_arc3_beat1.mp3', 'voice_victory_arc3_beat2.mp3'],
    ['voice_victory_arc4_beat1.mp3', 'voice_victory_arc4_beat2.mp3'],
    ['voice_victory_arc5_beat1.mp3', 'voice_victory_arc5_beat2.mp3'],
    ['voice_victory_arc6_beat1.mp3', 'voice_victory_arc6_beat2.mp3'],
    ['voice_victory_arc7_beat1.mp3', 'voice_victory_arc7_beat2.mp3'],
    ['voice_victory_arc8_beat1.mp3', 'voice_victory_arc8_beat2.mp3'],
  ];

  @override
  void initState() {
    super.initState();

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
    _walletBumpController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _heroCelebrationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _heroScaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _heroCelebrationController,
        curve: Curves.elasticOut,
      ),
    );
    _heroGlowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // C15 T3-32: chest-tap is mandatory — the DONE button used to appear at
    // the 10s mark (or immediately after arc beat 1, below) regardless of
    // whether the kid had tapped the chest. Oliver/Jim: opening the chest is
    // "a big step that the user loves"; don't let the kid skip past it.
    // Extended safety net (60s) stays as a stuck-user fallback only — not a
    // skip path. The chest itself is pulsing and obvious; a responsive kid
    // will tap it in seconds. Stored on `this` so dispose() can cancel it.
    _doneSafetyTimer = Timer(const Duration(seconds: 60), () {
      if (mounted && !_showDoneButton) {
        _audio.playSfx('whoosh.mp3');
        setState(() => _showDoneButton = true);
        _doneButtonController.repeat(reverse: true);
      }
    });

    _recordAndAnimate();
  }

  Future<void> _recordAndAnimate() async {
    if (_brushRecorded) return;
    _brushRecorded = true;

    final hero = await _heroService.getSelectedHero();
    _selectedHero = hero;
    _heroEvolutionStage = await _heroService.getEvolutionStage(hero.id);
    _heroWeaponId = await _weaponService.getSelectedWeaponId();
    _previousStreak = await _streakService.getStreak();
    _world = await _worldService.getCurrentWorld();
    _dailyModifier = _worldService.getDailyModifier();
    _previousStars = await _streakService.getTotalStars();
    _previousWallet = await _streakService.getWallet();
    final outcome = await _streakService.recordBrush(
      heroId: hero.id,
      worldId: _world.id,
    );
    _starsEarnedThisSession = outcome.starsEarned;
    _dailyBonus = outcome.breakdown.dailyBonus;
    _streakMultiplierBonus = outcome.breakdown.streakMultiplierBonus;
    _comebackBonus = outcome.comebackBonus;
    if (outcome.starsEarned > 0) {
      await _worldService.recordMission();
    }
    _newStreak = await _streakService.getStreak();
    _newStars = await _streakService.getTotalStars();
    _newWallet = await _streakService.getWallet();
    await _worldService.getWorldProgress(_world.id);

    final lifetimeBrushes = await _streakService.getTotalBrushes();

    _newAchievements = await _achievementService.checkAndUnlock(
      streak: _newStreak,
      totalStars: _newStars,
      totalBrushes: lifetimeBrushes,
    );

    // Award bonus stars from achievements
    final achievementBonus = _newAchievements.fold(
      0,
      (sum, a) => sum + a.bonusStars,
    );
    if (achievementBonus > 0) {
      await _streakService.addBonusStars(achievementBonus);
      _newStars = await _streakService.getTotalStars();
      _newWallet = await _streakService.getWallet();
    }

    _totalTrophies = await _trophyService.getTotalCaptured();

    // Analytics: log completion + update user properties
    final analytics = AnalyticsService();
    unawaited(
      analytics.logBrushSessionComplete(
        totalHits: widget.totalHits,
        monstersDefeated: widget.monstersDefeated,
        starsEarned: _starsEarnedThisSession,
        newStreak: _newStreak,
        totalStars: _newStars,
      ),
    );
    unawaited(
      analytics.setUserProperties(
        lifetimeBrushes: lifetimeBrushes,
        currentStreak: _newStreak,
        totalStars: _newStars,
      ),
    );

    if (mounted) setState(() {});

    // Auto-sync progress to cloud if signed in (fire-and-forget)
    if (AuthService().currentUser != null) {
      unawaited(
        SyncService().uploadProgress().catchError((e) {
          debugPrint('Cloud sync failed: $e');
        }),
      );
    }

    // ── NEW TIMING SEQUENCE ──
    // t=0       Hero celebration + confetti (victory SFX now plays from brushing_screen)
    unawaited(_heroCelebrationController.forward());
    unawaited(_heroGlowController.repeat(reverse: true));
    unawaited(_confettiController.repeat());

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    // t=300ms   Arc beat 1 (celebration)
    final arcIndex = _random.nextInt(_victoryArcs.length);
    final arc = _victoryArcs[arcIndex];
    await _audio.playVoice(
      arc[0],
      clearQueue: true,
      interrupt: true,
    ); // celebration
    if (!mounted) return;

    // Arc beat 2 (star earned) — start concurrently with star flight,
    // DONE button, and chest drop. No await, no dead time.
    unawaited(_audio.playVoice(arc[1])); // "+1 star!" (fire-and-forget)
    _triggerStarFlight();

    // Show the CHEST only — DONE must stay hidden until the chest is opened
    // and its reward sequence completes (C15 T3-32). Without the DONE button
    // visible, the chest is the only forward affordance and the kid gets the
    // full reveal pleasure before advancing.
    unawaited(_audio.playSfx('whoosh.mp3'));
    setState(() => _showChest = true);
    unawaited(_chestBounceController.repeat(reverse: true));
  }

  void _triggerStarFlight() {
    // Read wallet pill position from its GlobalKey
    final box = _walletPillKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final screenSize = MediaQuery.of(context).size;
    final pillPos = box.localToGlobal(Offset.zero);
    final pillCenter =
        pillPos + Offset(box.size.width / 2, box.size.height / 2);

    setState(() {
      _showStarFlight = true;
      _starFlightSource = Offset(screenSize.width / 2, screenSize.height / 2);
      _starFlightTarget = pillCenter;
    });
  }

  void _onStarLanded() {
    HapticFeedback.lightImpact();
    _walletBumpController.forward(from: 0.0);
    _audio.playSfx('star_chime.mp3');
  }

  Future<void> _revealBonusStars() async {
    if (!mounted) return;

    final hasBonuses =
        _streakMultiplierBonus > 0 || _dailyBonus > 0 || _comebackBonus > 0;
    if (!hasBonuses) return;

    // Mark first-time milestones and determine highest-priority voice.
    // Priority: first-time milestones > repeat bonuses.
    // Only play ONE voice for all bonuses combined.
    String? voiceToPlay;
    bool isFirstTime = false;

    // Check streak bonus (highest priority among bonuses)
    if (_streakMultiplierBonus > 0) {
      if (_newStreak >= 7) {
        final seenBefore = await _streakService.hasSeenFirstStreak7();
        if (!seenBefore) {
          await _streakService.markFirstStreak7Seen();
          voiceToPlay = 'voice_first_streak_7.mp3';
          isFirstTime = true;
        } else {
          voiceToPlay = 'voice_chest_mega_streak.mp3';
        }
      } else {
        final seenBefore = await _streakService.hasSeenFirstStreak3();
        if (!seenBefore) {
          await _streakService.markFirstStreak3Seen();
          voiceToPlay = 'voice_first_streak_3.mp3';
          isFirstTime = true;
        } else {
          voiceToPlay = 'voice_chest_streak_bonus.mp3';
        }
      }
    }

    // Check daily pair (override voice only if it's a first-time and streak wasn't)
    if (_dailyBonus > 0) {
      final seenBefore = await _streakService.hasSeenFirstDailyPair();
      if (!seenBefore) {
        await _streakService.markFirstDailyPairSeen();
        if (!isFirstTime) {
          voiceToPlay = 'voice_first_daily_pair.mp3';
          isFirstTime = true;
        }
      } else {
        voiceToPlay ??= 'voice_chest_daily_pair.mp3';
      }
    }

    // Check comeback bonus
    if (_comebackBonus > 0) {
      final seenBefore = await _streakService.hasSeenFirstComeback();
      if (!seenBefore) {
        await _streakService.markFirstComebackSeen();
        if (!isFirstTime) {
          voiceToPlay = 'voice_first_comeback.mp3';
          isFirstTime = true;
        }
      } else {
        voiceToPlay ??= 'voice_chest_comeback.mp3';
      }
    }

    // Play only the single highest-priority bonus voice
    if (voiceToPlay != null && mounted) {
      if (isFirstTime) unawaited(HapticFeedback.heavyImpact());
      await _audio.playVoice(voiceToPlay);
    }
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
      try {
        if (!mounted) return;
        unawaited(_rewardRevealController.forward());
        if (_reward!.bonusStars > 0) unawaited(HapticFeedback.mediumImpact());

        // ── Slot 0: Chest reward voice (always plays) ──
        await _audio.playVoice(_reward!.voiceFile);

        final totalBonus = _reward!.bonusStars + _dailyModifier.chestBonusStars;
        if (totalBonus > 0) {
          await _streakService.addBonusStars(totalBonus);
          _newStars = await _streakService.getTotalStars();
          _newWallet = await _streakService.getWallet();
          if (mounted) setState(() {});
        }

        // ── 3-slot priority voice budget ──
        // After chest reward (slot 0), allow max 3 more voice slots.
        // Priority: P1 first-time milestones > P2 trophy/world > P3 star milestone
        //         > P4 repeat bonus > P5 legendary (voice only) > P6 achievements (SFX only)
        int voiceSlotsRemaining = 3;

        // ── Post-chest bonus star reveals (all pills shown simultaneously) ──
        // _revealBonusStars handles first-time detection and plays ONE voice
        final hasBonuses =
            _streakMultiplierBonus > 0 || _dailyBonus > 0 || _comebackBonus > 0;

        // Determine first-time milestone status before spending slots
        bool hasFirstTimeMilestone = false;
        if (_streakMultiplierBonus > 0) {
          if (_newStreak >= 7) {
            hasFirstTimeMilestone = !(await _streakService
                .hasSeenFirstStreak7());
          } else {
            hasFirstTimeMilestone = !(await _streakService
                .hasSeenFirstStreak3());
          }
        }
        if (!hasFirstTimeMilestone && _dailyBonus > 0) {
          hasFirstTimeMilestone = !(await _streakService
              .hasSeenFirstDailyPair());
        }
        if (!hasFirstTimeMilestone && _comebackBonus > 0) {
          hasFirstTimeMilestone = !(await _streakService
              .hasSeenFirstComeback());
        }

        // P1: First-time milestones get a voice slot
        if (hasBonuses && hasFirstTimeMilestone && voiceSlotsRemaining > 0) {
          await _revealBonusStars();
          voiceSlotsRemaining--;
        } else if (hasBonuses && voiceSlotsRemaining > 0) {
          // P4: Repeat bonus — lower priority, still gets a slot if available
          await _revealBonusStars();
          voiceSlotsRemaining--;
        } else if (hasBonuses) {
          // No slots left — still mark first-time flags so they don't replay
          if (_streakMultiplierBonus > 0) {
            if (_newStreak >= 7) {
              if (!(await _streakService.hasSeenFirstStreak7())) {
                await _streakService.markFirstStreak7Seen();
              }
            } else {
              if (!(await _streakService.hasSeenFirstStreak3())) {
                await _streakService.markFirstStreak3Seen();
              }
            }
          }
          if (_dailyBonus > 0) {
            if (!(await _streakService.hasSeenFirstDailyPair())) {
              await _streakService.markFirstDailyPairSeen();
            }
          }
          if (_comebackBonus > 0) {
            if (!(await _streakService.hasSeenFirstComeback())) {
              await _streakService.markFirstComebackSeen();
            }
          }
        }

        // ── Trophy defeat/capture ──
        if (widget.trophyTargetId != null) {
          final result = await _trophyService.recordDefeat(
            widget.trophyTargetId!,
          );
          if (!mounted) return;

          await Future.delayed(const Duration(milliseconds: 200));
          if (!mounted) return;

          final trophy = TrophyService.allTrophies.firstWhere(
            (t) => t.id == widget.trophyTargetId,
            orElse: () => TrophyService.allTrophies.first,
          );

          setState(() {
            _showTrophyReveal = true;
            _trophyCaptured = result.captured;
            _trophyDefeats = result.currentDefeats;
            _trophyRequired = result.required;
            _revealedTrophy = trophy;
          });

          unawaited(HapticFeedback.mediumImpact());
          unawaited(_cardFlyController.forward());

          await Future.delayed(const Duration(milliseconds: 700));
          if (!mounted) return;

          unawaited(_cardGlowController.repeat(reverse: true));
          unawaited(_newBadgeController.forward());

          // P2: Trophy captured — voice_card_new + card description
          if (result.captured && voiceSlotsRemaining > 0) {
            unawaited(HapticFeedback.heavyImpact());
            await _audio.playVoice('voice_card_new.mp3');
            voiceSlotsRemaining--;
            // Card description gets its own slot
            if (voiceSlotsRemaining > 0) {
              final cardVoiceId = widget.trophyTargetId!.replaceAll('_t', '_0');
              await _audio.playVoice('voice_card_$cardVoiceId.mp3');
              voiceSlotsRemaining--;
            }
          } else if (!result.captured) {
            unawaited(_audio.playVoice('voice_keep_going.mp3'));
            // "keep going" is short, counts as a slot
            if (voiceSlotsRemaining > 0) voiceSlotsRemaining--;
          }
          if (!mounted) return;

          // Update total trophies count
          _totalTrophies = await _trophyService.getTotalCaptured();

          // Show world progress
          final worldComplete = await _trophyService.isWorldComplete(_world.id);
          if (!mounted) return;
          setState(() {
            _showWorldProgress = true;
            _worldJustCompleted = worldComplete;
          });

          // P2: World complete
          if (_worldJustCompleted && voiceSlotsRemaining > 0) {
            unawaited(HapticFeedback.heavyImpact());
            unawaited(_audio.playSfx('victory.mp3'));
            await _audio.playVoice('voice_world_complete.mp3');
            voiceSlotsRemaining--;
          }
        } else {
          // ── Endgame showcase: no trophy fight this brush — showcase a
          // random already-captured trophy so the victory screen still
          // has a monster moment. Neutral styling (no LEGENDARY badge).
          final capturedIds = await _trophyService.getCapturedIds();
          if (capturedIds.isNotEmpty && mounted) {
            final randomId = capturedIds[_random.nextInt(capturedIds.length)];
            final trophy = TrophyService.allTrophies.firstWhere(
              (t) => t.id == randomId,
              orElse: () => TrophyService.allTrophies.first,
            );

            setState(() {
              _showTrophyReveal = true;
              _trophyCaptured = true;
              _isShowcase = true;
              _trophyDefeats = trophy.defeatsRequired;
              _trophyRequired = trophy.defeatsRequired;
              _revealedTrophy = trophy;
            });

            unawaited(HapticFeedback.mediumImpact());
            unawaited(_cardFlyController.forward());

            await Future.delayed(const Duration(milliseconds: 700));
            if (!mounted) return;

            unawaited(_cardGlowController.repeat(reverse: true));
            // No banner animation — badge is hidden in showcase mode.
            // No auto-voice — kid taps monster to hear its description.
          }
        }

        // Short pause to let the kid see the world progress (reduced from 1500ms)
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;

        // ── P3: Milestone celebration (70/80/90 stars) ──
        if (voiceSlotsRemaining > 0) {
          for (final milestone in [70, 80, 90]) {
            if (_newStars >= milestone && _previousStars < milestone) {
              final voiceFile = 'voice_milestone_$milestone.mp3';
              await _audio.playVoice(voiceFile);
              unawaited(_confettiController.repeat());
              voiceSlotsRemaining--;
              break; // Only play one milestone per session
            }
          }
        }
        if (!mounted) return;

        // ── Achievements (SFX only — no voice_awesome pre-voice, no rotation voices) ──
        // The achievement popup already has visual + haptic feedback.
        for (int i = 0; i < _newAchievements.length; i++) {
          if (!mounted) break;
          if (i > 0) {
            await Future.delayed(const Duration(milliseconds: 800));
          }
          if (mounted) _showAchievementSfxOnly(_newAchievements[i]);
        }

        // ── Forward hook: encourage the next brushing session ──
        if (mounted) {
          await _showForwardHookSequence();
        }
      } on Exception catch (e) {
        debugPrint('Victory chest sequence error: $e');
      } finally {
        // Guarantee the DONE button is visible even if the reward chain fails.
        // It may already be showing (set in _recordAndAnimate), but this
        // ensures it appears if the early-show somehow didn't fire.
        if (mounted && !_showDoneButton) {
          unawaited(_audio.playSfx('whoosh.mp3'));
          setState(() => _showDoneButton = true);
          unawaited(_doneButtonController.repeat(reverse: true));
        }
      }
    });
  }

  /// Determine which forward hook voice to play. No visual — voice only.
  Future<void> _showForwardHookSequence() async {
    if (_forwardHookFired) return;
    _forwardHookFired = true;

    final now = DateTime.now();
    final slots = await _streakService.getTodaySlots();

    _ForwardHookType? hookType;

    if (now.hour < 15 && !slots.eveningDone) {
      hookType = _ForwardHookType.tonight;
    } else if (slots.morningDone && slots.eveningDone) {
      hookType = _ForwardHookType.fullPower;
    } else if (now.hour >= 15 && !slots.morningDone) {
      hookType = _ForwardHookType.morning;
    }

    if (hookType == null || !mounted) return;

    final voiceFile = switch (hookType) {
      _ForwardHookType.tonight => 'voice_forward_tonight.mp3',
      _ForwardHookType.fullPower => 'voice_full_power.mp3',
      _ForwardHookType.morning => 'voice_forward_morning.mp3',
    };
    await _audio.playVoice(voiceFile);
  }

  Widget _buildTrophyReveal() {
    final trophy = _revealedTrophy!;
    // Green = just caught, amber = partial hit, purple = showcase from collection
    // (showcase uses a distinct color so kid doesn't read it as "just caught again")
    final Color glowColor = _isShowcase
        ? const Color(0xFFB388FF)
        : (_trophyCaptured ? const Color(0xFF00E676) : const Color(0xFFFFAB00));

    return AnimatedBuilder(
      animation: Listenable.merge([_cardFlyController, _cardGlowController]),
      builder: (context, _) {
        final flyProgress = Curves.easeOutBack.transform(
          _cardFlyController.value.clamp(0.0, 1.0),
        );
        final glowPulse = _cardGlowController.value;

        return Opacity(
          opacity: flyProgress.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: flyProgress,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                children: [
                  Container(
                    width: 200,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A0A3E),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: glowColor.withValues(
                          alpha: 0.6 + glowPulse * 0.4,
                        ),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: glowColor.withValues(
                            alpha: 0.3 + glowPulse * 0.3,
                          ),
                          blurRadius: 20 + glowPulse * 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_newBadgeController.value > 0 && !_isShowcase)
                          ScaleTransition(
                            scale: CurvedAnimation(
                              parent: _newBadgeController,
                              curve: Curves.elasticOut,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _trophyCaptured
                                    ? const Color(0xFF00E676)
                                    : const Color(0xFFFFAB00),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _trophyCaptured
                                        ? 'CAUGHT!'
                                        : 'HIT! $_trophyDefeats/$_trophyRequired',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        // Monster image
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: glowColor.withValues(alpha: 0.3),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset(
                              trophy.imagePath,
                              fit: BoxFit.cover,
                              color: trophy.tintColor.withValues(alpha: 0.3),
                              colorBlendMode: BlendMode.overlay,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          trophy.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _trophyCaptured ? trophy.title : 'Keep fighting!',
                          style: TextStyle(
                            color: _trophyCaptured ? glowColor : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_showWorldProgress) ...[
                    Text(
                      _worldJustCompleted
                          ? 'WORLD COMPLETE!'
                          : '${_world.name} trophies collected!',
                      style: TextStyle(
                        color: _worldJustCompleted
                            ? Colors.yellowAccent
                            : Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Show trophy detail dialog and play card voice on tap.
  void _showTrophyCardDetail() {
    if (_revealedTrophy == null) return;
    final trophy = _revealedTrophy!;
    final worldColor = WorldService.getWorldById(trophy.worldId).themeColor;
    HapticFeedback.mediumImpact();
    // Play the card's voice on tap
    final cardVoiceId = trophy.id.replaceAll('_t', '_0');
    _audio.playVoice('voice_card_$cardVoiceId.mp3');
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => TrophyDetailDialog(
        trophy: trophy,
        defeatCount: _trophyDefeats,
        worldColor: worldColor,
      ),
    );
  }

  /// Show achievement with SFX only (no voice lines).
  /// The achievement popup already has visual + haptic feedback.
  void _showAchievementSfxOnly(Achievement achievement) {
    _audio.playSfx('star_chime.mp3');
    HapticFeedback.mediumImpact();
    showAchievementPopup(context, achievement);
  }

  @override
  void dispose() {
    _doneSafetyTimer?.cancel();
    _audio.stopVoice();
    _confettiController.dispose();
    _doneButtonController.dispose();
    _chestBounceController.dispose();
    _chestOpenController.dispose();
    _rewardRevealController.dispose();
    _cardFlyController.dispose();
    _cardGlowController.dispose();
    _newBadgeController.dispose();
    _walletBumpController.dispose();
    _heroCelebrationController.dispose();
    _heroGlowController.dispose();
    super.dispose();
  }

  Future<void> _goHome() async {
    // Fire forward hook before navigation if it hasn't been shown yet.
    // _showForwardHookSequence awaits the voice line (2-4s), so no fixed
    // delay needed — the voice itself paces the transition. Then stop
    // any lingering audio before navigation.
    if (!_forwardHookFired) {
      await _showForwardHookSequence();
    }
    await AudioService().stopVoice();
    if (!mounted) return;
    unawaited(
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const HomeScreen(skipGreeting: true),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
        (route) => false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_showDoneButton) {
          _goHome();
        } else {
          HapticFeedback.lightImpact();
          // Brief pulse on the confetti to give visual feedback
          _confettiController.forward(from: 0.0);
        }
      },
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
                          // Extra top padding to clear the fixed top bar
                          const SizedBox(height: 48),

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

                          const SizedBox(height: 16),

                          // Hero celebration (replaces StarRain)
                          AnimatedBuilder(
                            animation: Listenable.merge([
                              _heroScaleAnim,
                              _heroGlowController,
                            ]),
                            builder: (context, _) {
                              final glowPulse = _heroGlowController.value;
                              return Transform.scale(
                                scale: _heroScaleAnim.value.clamp(0.0, 1.0),
                                child: SizedBox(
                                  width: 160,
                                  height: 160,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Pulsing glow in hero's primary color
                                      Container(
                                        width: 140,
                                        height: 140,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: _selectedHero.primaryColor
                                                  .withValues(
                                                    alpha:
                                                        0.3 + glowPulse * 0.3,
                                                  ),
                                              blurRadius: 30 + glowPulse * 15,
                                              spreadRadius: 5 + glowPulse * 5,
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Hero image
                                      Container(
                                        width: 120,
                                        height: 120,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: _selectedHero.primaryColor
                                                .withValues(
                                                  alpha: 0.6 + glowPulse * 0.4,
                                                ),
                                            width: 3,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: _selectedHero.primaryColor
                                                  .withValues(alpha: 0.4),
                                              blurRadius: 16,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: ClipOval(
                                          child: HeroService.buildHeroImage(
                                            _selectedHero.id,
                                            stage: _heroEvolutionStage,
                                            weaponId: _heroWeaponId,
                                            size: 120,
                                          ),
                                        ),
                                      ),
                                      // Sparkle icons at different positions
                                      Positioned(
                                        top: 4,
                                        right: 12,
                                        child: Opacity(
                                          opacity: (glowPulse * 1.2).clamp(
                                            0.0,
                                            1.0,
                                          ),
                                          child: Icon(
                                            Icons.auto_awesome,
                                            color: _selectedHero.primaryColor
                                                .withValues(alpha: 0.8),
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 8,
                                        left: 8,
                                        child: Opacity(
                                          opacity: ((1.0 - glowPulse) * 1.2)
                                              .clamp(0.0, 1.0),
                                          child: Icon(
                                            Icons.auto_awesome,
                                            color: _selectedHero.primaryColor
                                                .withValues(alpha: 0.8),
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 20,
                                        left: 4,
                                        child: Opacity(
                                          opacity:
                                              ((glowPulse - 0.3).abs() < 0.5
                                                      ? glowPulse
                                                      : 1.0 - glowPulse)
                                                  .clamp(0.0, 1.0),
                                          child: Icon(
                                            Icons.auto_awesome,
                                            color: _selectedHero.primaryColor
                                                .withValues(alpha: 0.6),
                                            size: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 20),

                          // TREASURE CHEST
                          if (_showChest) _buildChest(),

                          // Trophy collection progress
                          if (_chestOpened &&
                              _totalTrophies < TrophyService.allTrophies.length)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 16,
                                left: 40,
                                right: 40,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.emoji_events,
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
                                          value:
                                              (_totalTrophies /
                                                      TrophyService
                                                          .allTrophies
                                                          .length)
                                                  .clamp(0.0, 1.0),
                                          backgroundColor: Colors.white
                                              .withValues(alpha: 0.15),
                                          valueColor:
                                              const AlwaysStoppedAnimation(
                                                Color(0xFF00E5FF),
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$_totalTrophies/${TrophyService.allTrophies.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Trophy reveal — tappable for all trophy cards
                          if (_showTrophyReveal && _revealedTrophy != null)
                            GestureDetector(
                              onTap: _showTrophyCardDetail,
                              child: _buildTrophyReveal(),
                            ),

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
                                      colors: [
                                        Color(0xFF7C4DFF),
                                        Color(0xFF9C27B0),
                                      ],
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
                                      const Icon(
                                        Icons.home,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'DONE',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
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

                // Fixed top bar with streak, rank, and wallet pills
                Positioned(
                  top: 8,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Streak pill (fire icon + streak count, orange)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.orangeAccent.withValues(alpha: 0.6),
                            width: 2,
                          ),
                          color: Colors.orangeAccent.withValues(alpha: 0.12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.local_fire_department,
                              color: Colors.orangeAccent,
                              size: 28,
                            ),
                            const SizedBox(width: 4),
                            TweenAnimationBuilder<int>(
                              tween: IntTween(
                                begin: _previousStreak,
                                end: _newStreak,
                              ),
                              duration: const Duration(milliseconds: 1500),
                              builder: (context, val, _) => Text(
                                '$val',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                  shadows: [
                                    Shadow(
                                      color: Color(0x80FF9800),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Rank pill (diamond icon + total stars, purple) — secondary size
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(
                              0xFF7C4DFF,
                            ).withValues(alpha: 0.6),
                            width: 2,
                          ),
                          color: const Color(
                            0xFF7C4DFF,
                          ).withValues(alpha: 0.12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.diamond,
                              color: Color(0xFF7C4DFF),
                              size: 22,
                            ),
                            const SizedBox(width: 4),
                            TweenAnimationBuilder<int>(
                              tween: IntTween(
                                begin: _previousStars,
                                end: _newStars,
                              ),
                              duration: const Duration(milliseconds: 1500),
                              builder: (context, val, _) => Text(
                                '$val',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  shadows: [
                                    Shadow(
                                      color: Color(0x807C4DFF),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Wallet pill (star icon + wallet count, yellow) with GlobalKey + glow
                      AnimatedBuilder(
                        animation: _walletBumpController,
                        builder: (context, child) {
                          final bump = Curves.elasticOut.transform(
                            _walletBumpController.value,
                          );
                          return Transform.scale(
                            scale: 1.0 + bump * 0.15,
                            child: child,
                          );
                        },
                        child: Container(
                          key: _walletPillKey,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: const Color(
                                0xFFFFD54F,
                              ).withValues(alpha: 0.7),
                              width: 2.5,
                            ),
                            color: const Color(
                              0xFFFFD54F,
                            ).withValues(alpha: 0.15),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFFFD54F,
                                ).withValues(alpha: 0.35),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                              BoxShadow(
                                color: const Color(
                                  0xFFFF8F00,
                                ).withValues(alpha: 0.15),
                                blurRadius: 24,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star,
                                color: Color(0xFFFFD54F),
                                size: 28,
                              ),
                              const SizedBox(width: 4),
                              TweenAnimationBuilder<int>(
                                tween: IntTween(
                                  begin: _previousWallet,
                                  end: _newWallet,
                                ),
                                duration: const Duration(milliseconds: 1500),
                                builder: (context, val, _) => Text(
                                  '$val',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 24,
                                    shadows: [
                                      Shadow(
                                        color: Color(0xB0FFD54F),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Star flight animation overlay
                if (_showStarFlight)
                  _StarFlightOverlay(
                    starCount: _starsEarnedThisSession.clamp(1, 5),
                    source: _starFlightSource,
                    target: _starFlightTarget,
                    onStarLanded: _onStarLanded,
                    onComplete: () {
                      if (mounted) setState(() => _showStarFlight = false);
                    },
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
              onTap: _chestOpened ? null : _openChest,
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
              // Reward label — icon-based for dance, text for others
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
                      child: reward.type == _ChestRewardType.dance
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.music_note,
                                  color: Colors.white,
                                  size: 28,
                                  shadows: [
                                    Shadow(color: reward.color, blurRadius: 12),
                                  ],
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.star,
                                  color: Color(0xFFFFD54F),
                                  size: 30,
                                  shadows: [
                                    Shadow(
                                      color: Color(0xFFFFD54F),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.music_note,
                                  color: Colors.white,
                                  size: 28,
                                  shadows: [
                                    Shadow(color: reward.color, blurRadius: 12),
                                  ],
                                ),
                              ],
                            )
                          : Text(
                              reward.label,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                                letterSpacing: 1.5,
                                shadows: [
                                  Shadow(color: reward.color, blurRadius: 16),
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
                                color: const Color(
                                  0xFFFFD54F,
                                ).withValues(alpha: 0.8),
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
      final sineDrift = sin(progress * 4 + i * 0.3) * 30;
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

/// Quadratic bezier tween that interpolates between [begin] and [end]
/// via a randomized control point for a curved arc effect.
class _BezierOffsetTween extends Tween<Offset> {
  final Offset controlPoint;

  _BezierOffsetTween({
    required Offset begin,
    required Offset end,
    required this.controlPoint,
  }) : super(begin: begin, end: end);

  @override
  Offset lerp(double t) {
    final u = 1.0 - t;
    return begin! * (u * u) + controlPoint * (2 * u * t) + end! * (t * t);
  }
}

/// Overlay widget that animates golden stars bursting from [source] and arcing
/// UP into the wallet pill at [target] using quadratic bezier paths.
class _StarFlightOverlay extends StatefulWidget {
  final int starCount;
  final Offset source;
  final Offset target;
  final VoidCallback onStarLanded;
  final VoidCallback onComplete;

  const _StarFlightOverlay({
    required this.starCount,
    required this.source,
    required this.target,
    required this.onStarLanded,
    required this.onComplete,
  });

  @override
  State<_StarFlightOverlay> createState() => _StarFlightOverlayState();
}

class _StarFlightOverlayState extends State<_StarFlightOverlay>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<Offset>> _positionAnims;
  late final List<Animation<double>> _opacityAnims;
  final _random = Random();
  int _landedCount = 0;

  @override
  void initState() {
    super.initState();

    _controllers = List.generate(widget.starCount, (i) {
      return AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );
    });

    _positionAnims = List.generate(widget.starCount, (i) {
      // Randomize control point for unique arc per star
      final dx = (_random.nextDouble() - 0.5) * 200;
      final dy = -100 - _random.nextDouble() * 100; // arc upward
      final controlPoint = Offset(
        (widget.source.dx + widget.target.dx) / 2 + dx,
        widget.source.dy + dy,
      );

      return _BezierOffsetTween(
        begin: widget.source,
        end: widget.target,
        controlPoint: controlPoint,
      ).animate(
        CurvedAnimation(parent: _controllers[i], curve: Curves.easeInOutCubic),
      );
    });

    _opacityAnims = _controllers.map((c) {
      return Tween<double>(
        begin: 1.0,
        end: 0.6,
      ).animate(CurvedAnimation(parent: c, curve: Curves.easeIn));
    }).toList();

    // Stagger the launches
    _launchStars();
  }

  Future<void> _launchStars() async {
    for (int i = 0; i < widget.starCount; i++) {
      if (!mounted) return;
      unawaited(
        _controllers[i].forward().then((_) {
          if (!mounted) return;
          widget.onStarLanded();
          _landedCount++;
          if (_landedCount >= widget.starCount) {
            widget.onComplete();
          }
        }),
      );
      if (i < widget.starCount - 1) {
        await Future.delayed(const Duration(milliseconds: 150));
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.expand(
        child: Stack(
          children: List.generate(widget.starCount, (i) {
            return AnimatedBuilder(
              animation: _controllers[i],
              builder: (context, _) {
                if (_controllers[i].value == 0) return const SizedBox.shrink();
                final pos = _positionAnims[i].value;
                final opacity = _opacityAnims[i].value;
                final scale =
                    1.0 - _controllers[i].value * 0.4; // shrink as it lands
                return Positioned(
                  left: pos.dx - 14,
                  top: pos.dy - 14,
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.scale(
                      scale: scale.clamp(0.4, 1.0),
                      child: const Icon(
                        Icons.star,
                        color: Color(0xFFFFD54F),
                        size: 28,
                        shadows: [
                          Shadow(color: Color(0xCCFFD54F), blurRadius: 12),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}
