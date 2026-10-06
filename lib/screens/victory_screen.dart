import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:flutter/services.dart';
import '../services/audio_service.dart';
import '../services/streak_service.dart';
import '../services/hero_service.dart';
import '../services/weapon_service.dart';
import '../services/achievement_service.dart';
import '../services/world_service.dart';
import '../services/trophy_service.dart';
import '../services/flame_tier.dart';
import '../widgets/space_background.dart';
import '../widgets/achievement_popup.dart';
import '../widgets/trophy_detail_dialog.dart';
import '../widgets/flame_view.dart';
import '../services/goal_service.dart';
import '../services/unlock_service.dart';
import '../widgets/goal_art.dart';
import '../widgets/goal_meter.dart';
import '../widgets/item_silhouette.dart';
import '../services/analytics_service.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import 'home_screen.dart';

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
//
// The 3 / 7 day steps below are the flame steps (kFlameBigAt / kFlameHotAt in
// flame_tier.dart), which also pick the chest look (chestTierFor). They match
// the streak-bonus steps in StreakService (calculateStreakBonus,
// calculateStreakBonusDetailed, claimDailyBonus). Change them together, so a
// fancier chest is really a better chest.
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

  if (streak >= kFlameHotAt) {
    confettiCeil = 20;
    danceCeil = 35;
    bonusCeil = 65;
    doubleCeil = 83;
    jackpotCeil = 93;
  } else if (streak >= kFlameBigAt) {
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

/// Chest colours for one streak step (spec §7.1). Wooden is the original
/// chest, unchanged; silver and gold are palette swaps of it.
class _ChestPalette {
  final Color bodyTop;
  final Color bodyBottom;
  final Color edge;
  final Color lidTop;
  final Color lidBottom;
  final Color lidEdge;
  final Color band;
  final Color bandEdge;
  final Color lockTop;
  final Color lockIcon;

  const _ChestPalette({
    required this.bodyTop,
    required this.bodyBottom,
    required this.edge,
    required this.lidTop,
    required this.lidBottom,
    required this.lidEdge,
    required this.band,
    required this.bandEdge,
    required this.lockTop,
    required this.lockIcon,
  });
}

_ChestPalette _chestPaletteFor(ChestTier tier) => switch (tier) {
  ChestTier.wooden => const _ChestPalette(
    bodyTop: Color(0xFF8D5A33),
    bodyBottom: Color(0xFF5D3420),
    edge: Color(0xFF4E2A17),
    lidTop: Color(0xFFB77845),
    lidBottom: Color(0xFF7A4A2D),
    lidEdge: Color(0xFF5F371F),
    band: Color(0xFFFFC107),
    bandEdge: Color(0xFFFFA000),
    lockTop: Color(0xFFFFF176),
    lockIcon: Color(0xFF6D4C41),
  ),
  ChestTier.silver => const _ChestPalette(
    bodyTop: Color(0xFFCFD8DC),
    bodyBottom: Color(0xFF90A4AE),
    edge: Color(0xFF607D8B),
    lidTop: Color(0xFFECEFF1),
    lidBottom: Color(0xFFB0BEC5),
    lidEdge: Color(0xFF78909C),
    band: Color(0xFFECEFF1),
    bandEdge: Color(0xFF78909C),
    lockTop: Color(0xFFFFFFFF),
    lockIcon: Color(0xFF455A64),
  ),
  ChestTier.gold => const _ChestPalette(
    bodyTop: Color(0xFFFFE082),
    bodyBottom: Color(0xFFFFB300),
    edge: Color(0xFFE65100),
    lidTop: Color(0xFFFFECB3),
    lidBottom: Color(0xFFFFCA28),
    lidEdge: Color(0xFFFF8F00),
    band: Color(0xFFFFF8E1),
    bandEdge: Color(0xFFFF8F00),
    lockTop: Color(0xFFFFFFFF),
    lockIcon: Color(0xFFBF360C),
  ),
};

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

  /// The one flame line for the flame beat (spec §7.3): tier-up, then
  /// bonus, then new, then grow. Null when nothing changed (a second brush
  /// today with no bonus).
  @visibleForTesting
  static String? flameBeatVoiceFor({
    required int previousStreak,
    required int newStreak,
    required int streakMultiplierBonus,
    required int comebackBonus,
  }) {
    final reached = reachedFlameTier(before: previousStreak, after: newStreak);
    if (reached == FlameTier.big) return 'voice_flame_tier_3.mp3';
    if (reached == FlameTier.hot) return 'voice_flame_tier_7.mp3';
    if (reached == FlameTier.golden) return 'voice_flame_tier_14.mp3';
    if (streakMultiplierBonus >= 2) return 'voice_flame_bonus_2.mp3';
    if (streakMultiplierBonus == 1) return 'voice_flame_bonus_1.mp3';
    if (comebackBonus > 0 || (previousStreak == 0 && newStreak == 1)) {
      return 'voice_flame_new.mp3';
    }
    if (newStreak > previousStreak) return 'voice_flame_grow.mp3';
    return null;
  }

  /// Closing line (spec §7.3): "see you tonight" only for a child who
  /// brushed morning and evening yesterday and is brushing in the morning
  /// now; otherwise the flame line.
  @visibleForTesting
  static String closingVoiceFor({
    required int hour,
    required bool yesterdayBoth,
    required int newStreak,
  }) {
    if (hour < 12 && yesterdayBoth) return 'voice_forward_tonight.mp3';
    return daysToNextFlameTier(newStreak) == 1
        ? 'voice_flame_see_you_next.mp3'
        : 'voice_flame_see_you_keep.mp3';
  }

  /// Where the unlock events go. The singleton does nothing on a test host
  /// (it only reaches Firebase on Android), so tests swap in a recording one.
  @visibleForTesting
  static AnalyticsService? debugAnalytics;

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
  bool _showFlameBeat = false;
  int _flameBonusStars = 0;
  bool _showChest = false;
  bool _chestOpened = false;
  _ChestReward? _reward;
  bool _showDoneButton = false;
  Timer? _doneSafetyTimer;
  Timer? _victoryMusicTimer;

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

  // Closing beat (spec §6 step 6): the flame strip and its line.
  bool _forwardHookFired = false;
  bool _showFlameStrip = false;

  // Goal beat (spec §6 step 4): the closest unlock, filled by this brush's
  // stars; one tap unlocks it when it is full.
  Goal? _goal;
  bool _showGoal = false;
  bool _goalUnlocked = false;
  bool _unlocking = false;
  int _goalShownHave = 0;
  Timer? _goalFillTimer;
  static const _goalFillStep = Duration(milliseconds: 75);
  Goal? _worldGoal;

  // The screen scrolls, and on small phones the newest beat lands below the
  // fold: these anchor the goal and the monster card for scrolling.
  final _goalAnchorKey = GlobalKey();
  final _cardAnchorKey = GlobalKey();

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

    // PLAN.md 1D-2 fix 3: re-trigger music on victory entry. brushing_screen's
    // _finishBrushing stops music before the navigation; without this, the
    // victory screen plays voices over total silence, and on iOS the music
    // never resumes on home either. 1500ms delay gives iOS audioplayers time
    // to fully release the prior music player before we create a new one
    // (rapid stop+dispose+create cycles silently fail on iOS Simulator).
    // Store the Timer so dispose can cancel it. Without this, a quick DONE
    // tap before 1500ms races Home's _loadStats postFrame playMusic on iOS —
    // two players spin up for the same source, one gets stuck silent. See
    // project_home_music_dropout memory.
    _victoryMusicTimer = Timer(const Duration(milliseconds: 1500), () async {
      if (!mounted) return;
      await _audio.playMusic('battle_music_loop.mp3');
      if (!mounted) return;
      await _audio.setMusicVolume(0.10);
      if (!mounted) return;
      unawaited(_audio.ensureMusicPlaying());
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
    // The flame pays the streak bonus, and the morning-plus-evening bonus
    // rides along as a small extra. The comeback +3 is not the flame's (a
    // small flame pays nothing): it keeps its own line after the chest.
    _flameBonusStars = _streakMultiplierBonus + _dailyBonus;
    if (outcome.starsEarned > 0) {
      await _worldService.recordMission();
    }
    _newStreak = await _streakService.getStreak();
    _newStars = await _streakService.getTotalStars();
    _newWallet = await _streakService.getWallet();

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

    // t=300ms   Arc beat 1 (celebration). Fire-and-forget — do NOT await the
    // voice before showing the chest. On Android the completion signal can
    // fail to fire, stalling the chest reveal for the full 15s voice timeout
    // (audio_service.dart:613). Pace the chest with a fixed delay instead so
    // the visual flow never depends on voice completion. The voice plays
    // concurrently over the chest drop.
    final arcIndex = _random.nextInt(_victoryArcs.length);
    final arc = _victoryArcs[arcIndex];
    unawaited(
      _audio.playVoice(arc[0], clearQueue: true, interrupt: true),
    ); // celebration
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    // Arc beat 2 (star earned) starts with the star flight. The flame beat
    // waits for it to end, up to a cap, so the flame line is spoken as the
    // flame appears instead of queueing behind both arc beats (spec §7.3).
    // The voice queue is FIFO, so beat 1 is done by then too. The cap keeps
    // the visuals from ever depending on a voice that never completes; muted,
    // playVoice returns at once. A failing voice must not stop the sequence.
    final starLine = _audio.playVoice(arc[1]); // "+1 star!"
    _triggerStarFlight();
    await starLine
        .timeout(const Duration(milliseconds: 2500), onTimeout: () {})
        .catchError((Object _) {});
    if (!mounted) return;

    // ── Flame beat (spec §6 step 2): the flame grows and the bonus stars come
    // out of it, with the line that says why. Fire-and-forget voice;
    // a fixed pause paces the visuals (never wait on voice completion).
    setState(() => _showFlameBeat = true);
    if (_flameBonusStars > 0) unawaited(_audio.playSfx('star_chime.mp3'));
    final flameLine = VictoryScreen.flameBeatVoiceFor(
      previousStreak: _previousStreak,
      newStreak: _newStreak,
      streakMultiplierBonus: _streakMultiplierBonus,
      comebackBonus: _comebackBonus,
    );
    if (flameLine != null) unawaited(_audio.playVoice(flameLine));
    final reached = reachedFlameTier(
      before: _previousStreak,
      after: _newStreak,
    );
    if (reached != null) {
      unawaited(analytics.logFlameTierReached(tier: reached.name));
    }
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;

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

  /// The comeback line, as it was before the flame beat existed: the long
  /// welcome-back line the first time ever (with a heavy haptic), the short
  /// one after that. Plays after the chest reward voice, and is awaited.
  Future<void> _revealComebackBonus() async {
    if (!mounted || _comebackBonus <= 0) return;
    final firstTime = !(await _streakService.hasSeenFirstComeback());
    if (firstTime) await _streakService.markFirstComebackSeen();
    if (!mounted) return;
    if (firstTime) unawaited(HapticFeedback.heavyImpact());
    await _audio.playVoice(
      firstTime ? 'voice_first_comeback.mp3' : 'voice_chest_comeback.mp3',
    );
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
        // The streak lines now play in the flame beat, before the chest (see
        // _recordAndAnimate); the daily pair has no line. Only the comeback
        // line is left among the bonus lines.
        int voiceSlotsRemaining = 3;

        // ── Post-chest comeback line (spec §6 step 2: "the comeback bonus
        // works as today"): P1 the first time ever, P4 after that.
        if (_comebackBonus > 0 && voiceSlotsRemaining > 0) {
          await _revealComebackBonus();
          voiceSlotsRemaining--;
        }

        // ── Goal beat (spec §6 step 4): this brush's stars fill the closest
        // unlock; when it is full, one tap unlocks it. The chest and comeback
        // lines are awaited above, so its line cuts nothing. "Tap to unlock
        // it!" is the child's cue to act: it doesn't depend on the budget.
        Goal? goal;
        try {
          goal = await GoalService().overallGoal();
        } on Object catch (e) {
          debugPrint('Goal beat skipped: $e');
        }
        if (!mounted) return;
        if (goal != null) {
          _showGoalBeat(goal);
          if (goal.affordable) {
            unawaited(_audio.playVoice('voice_tap_to_unlock.mp3'));
            if (voiceSlotsRemaining > 0) voiceSlotsRemaining--;
          } else if (voiceSlotsRemaining > 0) {
            unawaited(_audio.playVoice(_audio.starsLeftVoiceFor(goal.left)));
            voiceSlotsRemaining--;
          }
          await Future.delayed(const Duration(milliseconds: 1200));
          if (!mounted) return;
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
          _scrollCardIntoView();

          unawaited(HapticFeedback.mediumImpact());
          unawaited(_cardFlyController.forward());

          await Future.delayed(const Duration(milliseconds: 700));
          if (!mounted) return;

          unawaited(_cardGlowController.repeat(reverse: true));
          unawaited(_newBadgeController.forward());

          // P2: Trophy captured. The per-trophy naming voice ("Abyss Crawler,
          // the depth creeper...") IS the reward reveal — it must always play
          // so the kid hears what they caught. Previously it was slot-gated
          // and got starved when chest + bonus voices exhausted the 3-slot
          // budget before reaching here, so the trophy was never named (Jim's
          // v24 feedback). Now the naming voice is guaranteed; the generic
          // "new monster card" intro stays slot-gated. Both fire-and-forget so
          // a non-completing voice can't stall the DONE reveal (see issue-1
          // fix: never gate visual flow on voice completion).
          if (result.captured) {
            unawaited(HapticFeedback.heavyImpact());
            final cardVoiceId = widget.trophyTargetId!.replaceAll('_t', '_0');
            if (AudioService.traceEnabled) {
              AudioService.trace(
                '[VIC] trophy captured ${widget.trophyTargetId} '
                '-> voice_card_$cardVoiceId.mp3 (slots=$voiceSlotsRemaining)',
              );
            }
            if (voiceSlotsRemaining > 0) {
              unawaited(_audio.playVoice('voice_card_new.mp3'));
              voiceSlotsRemaining--;
            }
            // Naming voice — always queued, not slot-gated.
            unawaited(_audio.playVoice('voice_card_$cardVoiceId.mp3'));
            if (voiceSlotsRemaining > 0) voiceSlotsRemaining--;
          } else {
            unawaited(_audio.playVoice('voice_keep_going.mp3'));
            // "keep going" is short, counts as a slot
            if (voiceSlotsRemaining > 0) voiceSlotsRemaining--;
          }
          if (!mounted) return;

          // Update total trophies count
          _totalTrophies = await _trophyService.getTotalCaptured();

          // Show world progress
          final worldComplete = await _trophyService.isWorldComplete(_world.id);
          // The rockets fill toward the next planet (spec §6 step 5).
          Goal? worldGoal;
          try {
            worldGoal = await GoalService().worldGoal();
          } on Object catch (e) {
            debugPrint('World rockets skipped: $e');
          }
          if (!mounted) return;
          setState(() {
            _showWorldProgress = true;
            _worldJustCompleted = worldComplete;
            _worldGoal = worldGoal;
          });
          _scrollCardIntoView();

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
            _scrollCardIntoView();

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

  /// The closing beat (spec §6 step 6): the flame strip, and the line for
  /// the next flame, or "see you tonight" for a twice-a-day child brushing in
  /// the morning (spec §7.3).
  Future<void> _showForwardHookSequence() async {
    if (_forwardHookFired) return;
    _forwardHookFired = true;
    var yesterdayBoth = false;
    try {
      final yesterday = await _streakService.getYesterdaySlots();
      yesterdayBoth = yesterday.morningDone && yesterday.eveningDone;
    } on Object catch (e) {
      debugPrint("Yesterday's slots unavailable: $e");
    }
    if (!mounted) return;
    setState(() => _showFlameStrip = true);
    final line = VictoryScreen.closingVoiceFor(
      hour: DateTime.now().hour,
      yesterdayBoth: yesterdayBoth,
      newStreak: _newStreak,
    );
    // DONE follows this: capped, so a voice that never ends can't hold it.
    await _audio
        .playVoice(line)
        .timeout(const Duration(seconds: 5), onTimeout: () {});
  }

  /// Shows the goal with the stars the child had before this brush, then
  /// counts this brush's stars into it, one at a time.
  void _showGoalBeat(Goal goal) {
    final target = min(_newWallet, goal.cost);
    setState(() {
      _goal = goal;
      _showGoal = true;
      _goalShownHave = min(_previousWallet, target);
    });
    _scrollIntoView(_goalAnchorKey);
    _goalFillTimer?.cancel();
    _goalFillTimer = Timer.periodic(_goalFillStep, (timer) {
      if (!mounted || _goalShownHave >= target) {
        timer.cancel();
        return;
      }
      setState(() => _goalShownHave++);
    });
  }

  Future<void> _onGoalTap() async {
    final goal = _goal;
    if (goal == null || !goal.affordable || _goalUnlocked || _unlocking) {
      return;
    }
    // Held for the whole tap: unlockGoal() reports success for an item that
    // is already owned, so a second tap must never reach it.
    _unlocking = true;
    final analytics = VictoryScreen.debugAnalytics ?? AnalyticsService();
    var ok = false;
    try {
      ok = await UnlockService(analytics: analytics).unlockGoal(goal);
    } on Object catch (e) {
      debugPrint('Goal unlock failed: $e');
    }
    if (!mounted) return;
    if (!ok) {
      _unlocking = false; // refused or failed: he can tap again
      return;
    }
    setState(() => _goalUnlocked = true);
    unawaited(HapticFeedback.heavyImpact());
    unawaited(_confettiController.repeat());
    unawaited(_audio.playVoice('voice_unlocked_yours.mp3', interrupt: true));
    unawaited(
      analytics.logGoalUnlocked(
        category: goal.category.name,
        item: goal.itemId,
      ),
    );
    final wallet = await _streakService.getWallet();
    if (mounted) setState(() => _newWallet = wallet);
  }

  /// Height of the fixed pills row over the top of the scroll view (8 px
  /// down, 48 px high).
  static const double _topBarHeight = 56;

  /// Scrolls toward the monster card when it arrives (and when it grows),
  /// but never so far that the goal, which he may still want to tap, slips
  /// under the top bar. On a small phone that shows the goal and the top of
  /// the card; on a tall one, everything, without scrolling.
  void _scrollCardIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final card = _cardAnchorKey.currentContext?.findRenderObject();
      if (!mounted || card is! RenderBox || !card.attached) return;
      final position = Scrollable.maybeOf(
        _cardAnchorKey.currentContext!,
      )?.position;
      final viewport = RenderAbstractViewport.maybeOf(card);
      if (position == null || viewport == null) return;
      // The offset that puts the card's bottom at the bottom of the view.
      var target = viewport.getOffsetToReveal(card, 1).offset;
      final goal = _goalAnchorKey.currentContext?.findRenderObject();
      if (goal is RenderBox && goal.attached) {
        // The offset that puts the goal's top just under the top bar.
        final goalTop =
            viewport.getOffsetToReveal(goal, 0).offset - _topBarHeight;
        target = min(target, goalTop);
      }
      target = target.clamp(position.minScrollExtent, position.maxScrollExtent);
      if (target <= position.pixels) return; // already in view
      unawaited(
        position.animateTo(
          target,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        ),
      );
    });
  }

  /// Brings [key]'s widget into view, only scrolling when it isn't already.
  void _scrollIntoView(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = key.currentContext;
      if (!mounted || target == null) return;
      unawaited(
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        ),
      );
    });
  }

  Widget _buildGoal() {
    final goal = _goal!;
    final art = GoalArt(goal: goal, heroWeaponId: _heroWeaponId, size: 96);
    return KeyedSubtree(
      key: _goalAnchorKey,
      child: Padding(
        // The bottom margin keeps it clear of the screen's edge when it is
        // scrolled into view.
        padding: const EdgeInsets.only(top: 16, bottom: 16),
        child: GestureDetector(
          key: const ValueKey('victory_goal'),
          behavior: HitTestBehavior.opaque,
          onTap: _onGoalTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: goal.affordable && !_goalUnlocked ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 400),
                child: _goalUnlocked
                    ? art
                    : ItemSilhouette(
                        // Only hero art has a transparent background.
                        opaqueArt: goal.category != GoalCategory.hero,
                        child: art,
                      ),
              ),
              const SizedBox(height: 6),
              GoalMeter(
                have: _goalUnlocked ? goal.cost : _goalShownHave,
                cost: goal.cost,
              ),
            ],
          ),
        ),
      ),
    );
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
                    // Rockets toward the next planet; none once every planet
                    // is finished.
                    if (_worldGoal != null) ...[
                      const SizedBox(height: 6),
                      GoalMeter(
                        have: _worldGoal!.have,
                        cost: _worldGoal!.cost,
                        style: GoalMeterStyle.rockets,
                        unit: 18,
                      ),
                    ],
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
    _victoryMusicTimer?.cancel();
    _goalFillTimer?.cancel();
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

                          // Flame beat (spec §6 step 2), directly under the pill
                          // row. Its room is reserved from the start.
                          SizedBox(
                            height: _flameBeatHeight,
                            child: _showFlameBeat ? _buildFlameBeat() : null,
                          ),

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

                          // Goal fill (spec §6 step 4)
                          if (_showGoal && _goal != null) _buildGoal(),

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
                            KeyedSubtree(
                              key: _cardAnchorKey,
                              child: Padding(
                                // Kept clear of the screen's edge when it is
                                // scrolled into view.
                                padding: const EdgeInsets.only(bottom: 8),
                                child: GestureDetector(
                                  onTap: _showTrophyCardDetail,
                                  child: _buildTrophyReveal(),
                                ),
                              ),
                            ),

                          const SizedBox(height: 24),

                          // Flame hook strip (spec §6 step 6): the flame and
                          // the days to its next step. Scaled down on narrow
                          // phones (day 7 is the widest).
                          if (_showFlameStrip) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: FlameStrip(streak: _newStreak),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

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
                  // Scaled down rather than overflowing on very narrow phones.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
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

  static const double _flameStarSize = 22;

  /// Room for the flame beat (the flame, plus the star row when it pays
  /// stars). Kept from the start, so the hero and the title don't jump when
  /// the beat appears.
  double get _flameBeatHeight =>
      FlameIcon.sizeFor(flameTierFor(_newStreak)) +
      (_flameBonusStars > 0 ? _flameStarSize : 0);

  /// Today's flame, with the bonus stars it paid out sliding out of it
  /// (icons only, no text). Two effects at most: the flame grows in, and the
  /// stars slide out and fade in.
  Widget _buildFlameBeat() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.elasticOut,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: FlameIcon(tier: flameTierFor(_newStreak)),
        ),
        if (_flameBonusStars > 0)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.translate(
                // From over the flame to just below it.
                offset: Offset(0, -20 * (1 - t)),
                child: child,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < _flameBonusStars; i++)
                  const Icon(
                    Icons.star,
                    color: Colors.amberAccent,
                    size: _flameStarSize,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildChest() {
    final palette = _chestPaletteFor(chestTierFor(_newStreak));
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
              key: const ValueKey('victory_chest'),
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
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [palette.bodyTop, palette.bodyBottom],
                              ),
                              border: Border.all(
                                color: palette.edge,
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
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [palette.lidTop, palette.lidBottom],
                              ),
                              border: Border.all(
                                color: palette.lidEdge,
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
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [palette.lockTop, palette.band],
                              ),
                              border: Border.all(
                                color: palette.bandEdge,
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
                            child: Icon(
                              Icons.lock,
                              color: palette.lockIcon,
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
                              color: palette.band,
                              border: Border.all(
                                color: palette.bandEdge,
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
                              color: palette.band,
                              border: Border.all(
                                color: palette.bandEdge,
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
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [palette.bodyTop, palette.bodyBottom],
                    ),
                    border: Border.all(color: palette.edge, width: 2.5),
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
                    color: palette.band,
                    border: Border.all(color: palette.bandEdge, width: 1.5),
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
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [palette.lidTop, palette.lidBottom],
                        ),
                        border: Border.all(color: palette.lidEdge, width: 2.5),
                      ),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: 182,
                          height: 10,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: palette.band,
                            border: Border.all(
                              color: palette.bandEdge,
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
