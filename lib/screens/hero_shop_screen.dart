import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/audio_service.dart';
import '../services/hero_service.dart';
import '../services/weapon_service.dart';
import '../services/streak_service.dart';
import '../widgets/space_background.dart';
import '../widgets/glass_card.dart';
import '../services/analytics_service.dart';

class HeroShopScreen extends StatefulWidget {
  const HeroShopScreen({super.key});

  @override
  State<HeroShopScreen> createState() => _HeroShopScreenState();
}

class _HeroShopScreenState extends State<HeroShopScreen>
    with SingleTickerProviderStateMixin {
  final _heroService = HeroService();
  final _weaponService = WeaponService();
  final _streakService = StreakService();

  List<String> _unlockedHeroes = ['blaze'];
  String _selectedHeroId = 'blaze';
  List<String> _unlockedWeapons = ['star_blaster'];
  String _selectedWeaponId = 'star_blaster';
  int _wallet = 0;
  int _rank = 0;
  List<String> _unlockedEvolutions = [];
  Map<String, int> _evolutionStages = {};
  bool _isPurchaseDialogOpen = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;
      final voice = _tabController.index == 0
          ? 'voice_tab_heroes.mp3'
          : 'voice_tab_weapons.mp3';
      AudioService().playVoice(voice, clearQueue: true, interrupt: true);
    });
    // Show wallet/rank immediately before async load refines them
    SharedPreferences.getInstance().then((p) {
      if (mounted) {
        setState(() {
          _wallet = p.getInt('star_wallet') ?? 0;
          _rank = p.getInt('total_stars') ?? 0;
        });
      }
    });
    _loadData();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        AudioService().playVoice(
          'voice_entry_hero_hq.mp3',
          clearQueue: true,
          interrupt: true,
        );
      }
    });
    // Ambient music — low volume so voice lines stay clear
    AudioService().playMusic('battle_music_loop.mp3');
    AudioService().setMusicVolume(0.05);
    AnalyticsService().logShopVisit();
  }

  @override
  void dispose() {
    AudioService().stopVoice();
    AudioService().stopMusic();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final unlockedHeroes = await _heroService.getUnlockedHeroIds();
    final selectedHero = await _heroService.getSelectedHeroId();
    final unlockedWeapons = await _weaponService.getUnlockedWeaponIds();
    final selectedWeapon = await _weaponService.getSelectedWeaponId();
    final wallet = await _streakService.getWallet();
    final rank = await _streakService.getRangerRank();
    final unlockedEvolutions = await _heroService.getUnlockedEvolutionIds();
    final evolutionStages = <String, int>{};
    for (final hero in HeroService.allHeroes) {
      evolutionStages[hero.id] = await _heroService.getEvolutionStage(hero.id);
    }
    if (mounted) {
      setState(() {
        _unlockedHeroes = unlockedHeroes;
        _selectedHeroId = selectedHero;
        _unlockedWeapons = unlockedWeapons;
        _selectedWeaponId = selectedWeapon;
        _wallet = wallet;
        _rank = rank;
        _unlockedEvolutions = unlockedEvolutions;
        _evolutionStages = evolutionStages;
      });
    }
  }

  Future<String> _selectNudgeVoice() async {
    final slots = await _streakService.getTodaySlots();
    if (slots.morningDone && !slots.eveningDone) {
      return 'voice_shop_nudge_tonight.mp3';
    }
    final streak = await _streakService.getStreak();
    if (streak >= 1 && streak <= 2) {
      return 'voice_shop_nudge_streak3.mp3';
    }
    if (streak >= 5 && streak <= 6) {
      return 'voice_shop_nudge_streak7.mp3';
    }
    return 'voice_shop_nudge_default.mp3';
  }

  Future<void> _onEvolutionTap(
    HeroCharacter hero,
    HeroEvolution evolution,
  ) async {
    final isHeroOwned = _unlockedHeroes.contains(hero.id);
    final isEvoOwned = evolution.stage == 1
        ? isHeroOwned
        : _unlockedEvolutions.contains(evolution.id);
    final currentStage = _evolutionStages[hero.id] ?? 1;
    final isEquipped =
        _selectedHeroId == hero.id && currentStage == evolution.stage;

    if (isEquipped) return;

    if (!isHeroOwned) {
      // Hero not purchased — only stage 1 is tappable for purchase
      if (evolution.stage != 1) {
        unawaited(HapticFeedback.lightImpact());
        unawaited(AudioService().playVoice('voice_need_stars.mp3'));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock, color: Colors.amber, size: 24),
                  const SizedBox(width: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/images/hero_${hero.id}.png',
                      width: 32,
                      height: 32,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward,
                    color: Colors.white70,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.star, color: Color(0xFFFFD54F), size: 24),
                ],
              ),
              backgroundColor: hero.primaryColor.withValues(alpha: 0.9),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      if (_wallet >= hero.price) {
        if (hero.price > 0) {
          final confirmed = await _showPurchaseConfirmation(
            hero.name,
            hero.price,
          );
          if (!confirmed) return;
        }
        final success = await _heroService.purchaseHero(hero.id);
        if (success) {
          await _heroService.selectHero(hero.id);
          unawaited(HapticFeedback.heavyImpact());
          unawaited(
            AnalyticsService().logHeroUnlock(
              heroId: hero.id,
              starsAtUnlock: _rank,
            ),
          );
          if (mounted) _showHeroUnlockAnimation(hero);
          await _loadData();
        }
      } else {
        unawaited(HapticFeedback.lightImpact());
        _playSelectionVoice(
          AudioService().evolutionPickerVoiceFor(hero.id, evolution.stage),
        );
        unawaited(AudioService().playVoice(await _selectNudgeVoice()));
        _showCannotAffordSnackBar(
          price: hero.price,
          wallet: _wallet,
          accentColor: hero.primaryColor,
        );
      }
      return;
    }

    if (isEvoOwned) {
      // Equip this evolution + select hero
      await _heroService.selectHero(hero.id);
      await _heroService.setEvolutionStage(hero.id, evolution.stage);
      unawaited(HapticFeedback.mediumImpact());
      _playSelectionVoice(
        AudioService().evolutionPickerVoiceFor(hero.id, evolution.stage),
      );
      await _loadData();
    } else if (_wallet >= evolution.price) {
      // Check sequential gating: stage 3 needs stage 2
      if (evolution.stage >= 3) {
        final prevId = '${hero.id}_stage${evolution.stage - 1}';
        if (!_unlockedEvolutions.contains(prevId)) {
          unawaited(HapticFeedback.lightImpact());
          _playSelectionVoice(
            AudioService().evolutionPickerVoiceFor(hero.id, evolution.stage),
          );
          unawaited(AudioService().playVoice(await _selectNudgeVoice()));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock, color: Colors.amber, size: 24),
                    const SizedBox(width: 8),
                    // Previous stage thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/images/heroes/hero_${hero.id}_stage${evolution.stage - 1}_star_blaster.png',
                        width: 32,
                        height: 32,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/images/hero_${hero.id}.png',
                          width: 32,
                          height: 32,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.arrow_forward,
                      color: Colors.white70,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    // Current stage thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/images/heroes/hero_${hero.id}_stage${evolution.stage}_star_blaster.png',
                        width: 32,
                        height: 32,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/images/hero_${hero.id}.png',
                          width: 32,
                          height: 32,
                        ),
                      ),
                    ),
                  ],
                ),
                backgroundColor: hero.primaryColor.withValues(alpha: 0.9),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
      }
      final confirmed = await _showPurchaseConfirmation(
        evolution.name,
        evolution.price,
      );
      if (!confirmed) return;
      final success = await _heroService.purchaseEvolution(evolution.id);
      if (success) {
        // Only auto-equip the purchased evolution if the child already has
        // this hero selected. Otherwise the hero silently switches — e.g.
        // Shadow-selected kid buys Blaze stage2 "just to own it" and their
        // equipped hero flips to Blaze with no confirmation or voice.
        final currentHero = await _heroService.getSelectedHero();
        if (currentHero.id == hero.id) {
          await _heroService.setEvolutionStage(hero.id, evolution.stage);
        }
        unawaited(HapticFeedback.heavyImpact());
        await _loadData();
      }
    } else {
      unawaited(HapticFeedback.lightImpact());
      _playSelectionVoice(
        AudioService().evolutionPickerVoiceFor(hero.id, evolution.stage),
      );
      unawaited(AudioService().playVoice(await _selectNudgeVoice()));
      _showCannotAffordSnackBar(
        price: evolution.price,
        wallet: _wallet,
        accentColor: hero.primaryColor,
      );
    }
  }

  Future<void> _onWeaponTap(WeaponItem weapon) async {
    if (_unlockedWeapons.contains(weapon.id)) {
      // Already selected — no-op to avoid unnecessary work
      if (_selectedWeaponId == weapon.id) return;
      await _weaponService.selectWeapon(weapon.id);
      unawaited(HapticFeedback.mediumImpact());
      _playSelectionVoice(AudioService().weaponPickerVoiceFor(weapon.id));
      await _loadData();
    } else if (_wallet >= weapon.price) {
      if (weapon.price > 0) {
        final confirmed = await _showPurchaseConfirmation(
          weapon.name,
          weapon.price,
        );
        if (!confirmed) return;
      }
      final success = await _weaponService.purchaseWeapon(weapon.id);
      if (success) {
        await _weaponService.selectWeapon(weapon.id);
        unawaited(HapticFeedback.heavyImpact());
        unawaited(
          AnalyticsService().logWeaponUnlock(
            weaponId: weapon.id,
            starsAtUnlock: _rank,
          ),
        );
        // Finding #8: Don't play voice here — the unlock dialog's initState
        // plays the intro voice. Playing it here too causes an audible stutter.
        if (mounted) _showWeaponUnlockAnimation(weapon);
        await _loadData();
      }
    } else {
      unawaited(HapticFeedback.lightImpact());
      // Describe the weapon, then give a context-aware nudge
      _playSelectionVoice(AudioService().weaponPickerVoiceFor(weapon.id));
      unawaited(AudioService().playVoice(await _selectNudgeVoice()));
      _showCannotAffordSnackBar(
        price: weapon.price,
        wallet: _wallet,
        accentColor: weapon.primaryColor,
      );
    }
  }

  Future<bool> _showPurchaseConfirmation(String itemName, int price) async {
    if (_isPurchaseDialogOpen) return false;
    _isPurchaseDialogOpen = true;
    try {
      return await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1A1A2E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Get $itemName?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 32),
                      const SizedBox(width: 8),
                      Text(
                        '$price',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text(
                          'Not yet',
                          style: TextStyle(color: Colors.white54, fontSize: 18),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E676),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          'YES!',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ) ??
          false;
    } finally {
      _isPurchaseDialogOpen = false;
    }
  }

  void _playSelectionVoice(String fileName) {
    AudioService().playVoice(fileName, clearQueue: true, interrupt: true);
  }

  void _showCannotAffordSnackBar({
    required int price,
    required int wallet,
    required Color accentColor,
  }) {
    final delta = price - wallet;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF1A1A2E),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, color: accentColor, size: 24),
            const SizedBox(width: 6),
            Text(
              '$delta more',
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.auto_awesome,
              color: accentColor.withValues(alpha: 0.7),
              size: 20,
            ),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: accentColor.withValues(alpha: 0.4)),
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  void _showHeroUnlockAnimation(HeroCharacter hero) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _HeroUnlockDialog(hero: hero),
    );
  }

  void _showWeaponUnlockAnimation(WeaponItem weapon) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _WeaponUnlockDialog(weapon: weapon),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        AudioService().stopVoice();
                        Navigator.of(context).pop();
                      },
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'HEROES & WEAPONS',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 28,
                              letterSpacing: 3,
                            ),
                      ),
                    ),
                    // Star Wallet (only counter that matters in shop)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.yellowAccent.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star,
                            color: Colors.yellowAccent,
                            size: 24,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$_wallet',
                            style: const TextStyle(
                              color: Colors.yellowAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Tab bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: const Color(0xFF7C4DFF).withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 2,
                  ),
                  tabs: const [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shield, size: 20),
                          SizedBox(width: 8),
                          Text('HEROES'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bolt, size: 20),
                          SizedBox(width: 8),
                          Text('WEAPONS'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Heroes tab
                    _buildEvolutionGrid(),
                    // Weapons tab
                    _buildWeaponGrid(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEvolutionGrid() {
    final selectedHero = HeroService.allHeroes.firstWhere(
      (h) => h.id == _selectedHeroId,
      orElse: () => HeroService.allHeroes.first,
    );
    final selectedStage = _evolutionStages[selectedHero.id] ?? 1;

    // +1 item for the featured hero header at index 0 (C15 T3-19 symmetry
    // with Weapons tab). The remaining indices map to the hero roster.
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      itemCount: HeroService.allHeroes.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _FeaturedHeroDisplay(
            hero: selectedHero,
            stage: selectedStage,
          );
        }
        final hero = HeroService.allHeroes[index - 1];
        final isHeroOwned = _unlockedHeroes.contains(hero.id);
        final isSelected = _selectedHeroId == hero.id;
        final currentStage = _evolutionStages[hero.id] ?? 1;
        final evolutions = HeroService.evolutionsForHero(hero.id);

        return _HeroEvolutionRow(
          hero: hero,
          evolutions: evolutions,
          isHeroOwned: isHeroOwned,
          isSelected: isSelected,
          currentStage: currentStage,
          wallet: _wallet,
          selectedWeaponId: _selectedWeaponId,
          unlockedEvolutions: _unlockedEvolutions,
          onEvolutionTap: (evo) => _onEvolutionTap(hero, evo),
        );
      },
    );
  }

  Widget _buildWeaponGrid() {
    final selectedWeapon = WeaponService.allWeapons.firstWhere(
      (w) => w.id == _selectedWeaponId,
      orElse: () => WeaponService.allWeapons.first,
    );

    return CustomScrollView(
      slivers: [
        // Featured selected weapon display
        SliverToBoxAdapter(
          child: _FeaturedWeaponDisplay(weapon: selectedWeapon),
        ),
        // Weapon grid
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.68,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final weapon = WeaponService.allWeapons[index];
              final isUnlocked = _unlockedWeapons.contains(weapon.id);
              final isSelected = _selectedWeaponId == weapon.id;
              final canAfford = _wallet >= weapon.price;

              return _WeaponCard(
                weapon: weapon,
                isUnlocked: isUnlocked,
                isSelected: isSelected,
                canAfford: canAfford,
                currentStars: _wallet,
                onTap: () => _onWeaponTap(weapon),
              );
            }, childCount: WeaponService.allWeapons.length),
          ),
        ),
      ],
    );
  }
}

class _HeroEvolutionRow extends StatelessWidget {
  final HeroCharacter hero;
  final List<HeroEvolution> evolutions;
  final bool isHeroOwned;
  final bool isSelected;
  final int currentStage;
  final int wallet;
  final String selectedWeaponId;
  final List<String> unlockedEvolutions;
  final ValueChanged<HeroEvolution> onEvolutionTap;

  const _HeroEvolutionRow({
    required this.hero,
    required this.evolutions,
    required this.isHeroOwned,
    required this.isSelected,
    required this.currentStage,
    required this.wallet,
    required this.selectedWeaponId,
    required this.unlockedEvolutions,
    required this.onEvolutionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? hero.primaryColor.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: hero.primaryColor.withValues(alpha: 0.2),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            for (int i = 0; i < evolutions.length; i++) ...[
              if (i > 0) ...[
                const SizedBox(width: 2),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
                const SizedBox(width: 2),
              ],
              Expanded(
                child: _EvolutionCell(
                  hero: hero,
                  evolution: evolutions[i],
                  isHeroOwned: isHeroOwned,
                  isOwned: evolutions[i].stage == 1
                      ? isHeroOwned
                      : unlockedEvolutions.contains(evolutions[i].id),
                  isEquipped: isSelected && currentStage == evolutions[i].stage,
                  isGated:
                      evolutions[i].stage >= 3 &&
                      !unlockedEvolutions.contains(
                        '${hero.id}_stage${evolutions[i].stage - 1}',
                      ),
                  wallet: wallet,
                  weaponId: selectedWeaponId,
                  onTap: () => onEvolutionTap(evolutions[i]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EvolutionCell extends StatefulWidget {
  final HeroCharacter hero;
  final HeroEvolution evolution;
  final bool isHeroOwned;
  final bool isOwned;
  final bool isEquipped;
  final bool isGated;
  final int wallet;
  final String weaponId;
  final VoidCallback onTap;

  const _EvolutionCell({
    required this.hero,
    required this.evolution,
    required this.isHeroOwned,
    required this.isOwned,
    required this.isEquipped,
    required this.isGated,
    required this.wallet,
    required this.weaponId,
    required this.onTap,
  });

  @override
  State<_EvolutionCell> createState() => _EvolutionCellState();
}

class _EvolutionCellState extends State<_EvolutionCell>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;

  int get _displayPrice {
    if (widget.evolution.stage == 1 && !widget.isHeroOwned) {
      return widget.hero.price;
    }
    return widget.evolution.price;
  }

  bool get _canAfford => widget.wallet >= _displayPrice;

  bool get _showBuyIndicator =>
      !widget.isOwned &&
      _canAfford &&
      _displayPrice > 0 &&
      !widget.isGated &&
      !(widget.evolution.stage > 1 && !widget.isHeroOwned);

  /// C15 T3-20: "getting close" amber state. Triggered when the kid is within
  /// 3 stars of affording an item — gives them a tangible "one more brush!"
  /// hook. Only applies to locked-but-reachable cells (not gated, hero owned
  /// if this is a stage 2+ evolution).
  bool get _showAlmostThere =>
      !widget.isOwned &&
      !_canAfford &&
      _displayPrice > 0 &&
      (_displayPrice - widget.wallet) <= 3 &&
      !widget.isGated &&
      !(widget.evolution.stage > 1 && !widget.isHeroOwned);

  @override
  void initState() {
    super.initState();
    _setupPulse();
  }

  @override
  void didUpdateWidget(covariant _EvolutionCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _setupPulse();
  }

  void _setupPulse() {
    if (_showBuyIndicator && _pulseController == null) {
      _pulseController = AnimationController(
        duration: const Duration(milliseconds: 1500),
        vsync: this,
      )..repeat(reverse: true);
    } else if (!_showBuyIndicator && _pulseController != null) {
      _pulseController!.dispose();
      _pulseController = null;
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locked = !widget.isOwned;
    final showPrice = locked && _displayPrice > 0;
    final showLock =
        locked &&
        !_showBuyIndicator &&
        (widget.isGated || (!widget.isHeroOwned && widget.evolution.stage > 1));

    Widget cell = GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: widget.isEquipped
              ? widget.hero.primaryColor.withValues(alpha: 0.15)
              : _showBuyIndicator
              ? const Color(0xFF00E676).withValues(alpha: 0.08)
              : _showAlmostThere
              ? const Color(0xFFFFD54F).withValues(alpha: 0.07)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isEquipped
                ? widget.hero.primaryColor.withValues(alpha: 0.7)
                : _showBuyIndicator
                ? const Color(0xFF00E676).withValues(alpha: 0.6)
                : _showAlmostThere
                ? const Color(0xFFFFD54F).withValues(alpha: 0.5)
                : locked
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.15),
            width: widget.isEquipped
                ? 2
                : _showBuyIndicator
                ? 2
                : _showAlmostThere
                ? 1.5
                : 1,
          ),
          boxShadow: _showBuyIndicator
              ? [
                  BoxShadow(
                    color: const Color(0xFF00E676).withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : _showAlmostThere
              ? [
                  BoxShadow(
                    color: const Color(0xFFFFD54F).withValues(alpha: 0.2),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Hero evolution image
            AspectRatio(
              aspectRatio: 1,
              child: Opacity(
                opacity: locked ? 0.45 : 1.0,
                child: ColorFiltered(
                  colorFilter: locked
                      ? ColorFilter.matrix(_partialDesaturationMatrix(0.5))
                      : const ColorFilter.mode(
                          Colors.transparent,
                          BlendMode.dst,
                        ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: Image.asset(
                          'assets/images/heroes/hero_${widget.hero.id}_stage${widget.evolution.stage}_${widget.weaponId}.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Image.asset(
                              'assets/images/hero_${widget.hero.id}.png',
                              fit: BoxFit.contain,
                            );
                          },
                        ),
                      ),
                      if (showLock)
                        Icon(
                          Icons.lock,
                          color: Colors.white.withValues(alpha: 0.7),
                          size: 24,
                        ),
                      if (_showBuyIndicator)
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF00E676,
                            ).withValues(alpha: 0.85),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF00E676,
                                ).withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.shopping_cart,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Status indicator
            if (widget.isEquipped)
              Icon(
                Icons.check_circle,
                color: widget.hero.primaryColor,
                size: 18,
              )
            else if (_showBuyIndicator)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: Color(0xFF00E676), size: 14),
                  const SizedBox(width: 2),
                  Text(
                    '$_displayPrice',
                    style: const TextStyle(
                      color: Color(0xFF00E676),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            else if (_showAlmostThere)
              // "Getting close" state (T3-20) — amber star + remaining delta
              // with a "+" prefix to distinguish from the full price readout.
              // Kid sees "+2" = "two more brushes and it's yours."
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.star,
                    color: Color(0xFFFFD54F),
                    size: 14,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '+${_displayPrice - widget.wallet}',
                    style: const TextStyle(
                      color: Color(0xFFFFD54F),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            else if (showPrice)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star,
                    color: Colors.white.withValues(alpha: 0.3),
                    size: 14,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '$_displayPrice',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            else if (widget.isOwned && !widget.isEquipped)
              Icon(
                Icons.check_circle_outline,
                color: Colors.white.withValues(alpha: 0.3),
                size: 16,
              ),
          ],
        ),
      ),
    );

    // Wrap affordable items with a subtle pulsing glow
    if (_showBuyIndicator && _pulseController != null) {
      cell = AnimatedBuilder(
        animation: _pulseController!,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFF00E676,
                  ).withValues(alpha: 0.15 + _pulseController!.value * 0.2),
                  blurRadius: 8 + _pulseController!.value * 6,
                  spreadRadius: _pulseController!.value * 2,
                ),
              ],
            ),
            child: child,
          );
        },
        child: cell,
      );
    }

    return cell;
  }
}

class _WeaponCard extends StatefulWidget {
  final WeaponItem weapon;
  final bool isUnlocked;
  final bool isSelected;
  final bool canAfford;
  final int currentStars;
  final VoidCallback onTap;

  const _WeaponCard({
    required this.weapon,
    required this.isUnlocked,
    required this.isSelected,
    required this.canAfford,
    required this.currentStars,
    required this.onTap,
  });

  @override
  State<_WeaponCard> createState() => _WeaponCardState();
}

class _WeaponCardState extends State<_WeaponCard>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;

  bool get _showBuyIndicator =>
      !widget.isUnlocked && widget.canAfford && widget.weapon.price > 0;

  @override
  void initState() {
    super.initState();
    _setupPulse();
  }

  @override
  void didUpdateWidget(covariant _WeaponCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _setupPulse();
  }

  void _setupPulse() {
    if (_showBuyIndicator && _pulseController == null) {
      _pulseController = AnimationController(
        duration: const Duration(milliseconds: 1500),
        vsync: this,
      )..repeat(reverse: true);
    } else if (!_showBuyIndicator && _pulseController != null) {
      _pulseController!.dispose();
      _pulseController = null;
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget card = GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: widget.isSelected
                ? widget.weapon.primaryColor
                : _showBuyIndicator
                ? const Color(0xFF00E676).withValues(alpha: 0.6)
                : widget.isUnlocked
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.1),
            width: widget.isSelected
                ? 3
                : _showBuyIndicator
                ? 2
                : 1,
          ),
          boxShadow: widget.isSelected
              ? [
                  BoxShadow(
                    color: widget.weapon.primaryColor.withValues(alpha: 0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ]
              : _showBuyIndicator
              ? [
                  BoxShadow(
                    color: const Color(0xFF00E676).withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Opacity(
                        opacity: widget.isUnlocked ? 1.0 : 0.5,
                        child: ColorFiltered(
                          colorFilter: widget.isUnlocked
                              ? const ColorFilter.mode(
                                  Colors.transparent,
                                  BlendMode.dst,
                                )
                              : ColorFilter.matrix(
                                  _partialDesaturationMatrix(0.45),
                                ),
                          child: Image.asset(
                            widget.weapon.imagePath,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (!widget.isUnlocked && widget.weapon.price > 0)
                    _PriceTag(
                      price: widget.weapon.price,
                      wallet: widget.currentStars,
                      canAfford: widget.canAfford,
                    ),
                ],
              ),
            ),
            // Top-right indicator: shopping cart for affordable, lock for unaffordable
            if (!widget.isUnlocked && _showBuyIndicator)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676).withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E676).withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.shopping_cart,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              )
            else if (!widget.isUnlocked)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.25),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.lock,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 24,
                  ),
                ),
              ),
            if (widget.isSelected)
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.6),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    // Wrap affordable items with a subtle pulsing glow
    if (_showBuyIndicator && _pulseController != null) {
      card = AnimatedBuilder(
        animation: _pulseController!,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFF00E676,
                  ).withValues(alpha: 0.15 + _pulseController!.value * 0.2),
                  blurRadius: 8 + _pulseController!.value * 6,
                  spreadRadius: _pulseController!.value * 2,
                ),
              ],
            ),
            child: child,
          );
        },
        child: card,
      );
    }

    return card;
  }
}

/// Creates a color matrix for partial desaturation.
/// [saturation] ranges from 0.0 (full grayscale) to 1.0 (full color).
List<double> _partialDesaturationMatrix(double saturation) {
  final double invSat = 1.0 - saturation;
  // Luminance weights (ITU-R BT.601)
  const double lumR = 0.2126;
  const double lumG = 0.7152;
  const double lumB = 0.0722;

  return <double>[
    lumR * invSat + saturation,
    lumG * invSat,
    lumB * invSat,
    0,
    0,
    lumR * invSat,
    lumG * invSat + saturation,
    lumB * invSat,
    0,
    0,
    lumR * invSat,
    lumG * invSat,
    lumB * invSat + saturation,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}

class _FeaturedWeaponDisplay extends StatelessWidget {
  final WeaponItem weapon;

  const _FeaturedWeaponDisplay({required this.weapon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      // Featured weapon was decorative with no onTap — a non-reader's only
      // signal that the description text exists is voice. Wire tap to the
      // picker voice so "what does my weapon do?" is discoverable.
      child: GestureDetector(
        onTap: () {
          final voice = AudioService().weaponPickerVoiceFor(weapon.id);
          AudioService().playVoice(voice, clearQueue: true, interrupt: true);
          HapticFeedback.selectionClick();
        },
        child: GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Row(
            children: [
              // Weapon image
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: weapon.primaryColor.withValues(alpha: 0.6),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: weapon.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: Image.asset(weapon.imagePath, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 20),
              // Weapon info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      weapon.name,
                      style: TextStyle(
                        color: weapon.primaryColor,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      weapon.description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.greenAccent.withValues(alpha: 0.8),
                          size: 16,
                        ),
                      ],
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
}

/// Mirrors _FeaturedWeaponDisplay on the Heroes tab (C15 T3-19: 4-agent
/// converged finding — shop tabs were asymmetric, Weapons had a featured
/// card and Heroes was grid-only). Shows the currently selected hero with
/// name + description + tap-to-voice-describe.
class _FeaturedHeroDisplay extends StatelessWidget {
  final HeroCharacter hero;
  final int stage;

  const _FeaturedHeroDisplay({required this.hero, required this.stage});

  @override
  Widget build(BuildContext context) {
    // Evolution stage-specific art when available, fallback to base hero art.
    final evolvedPath =
        'assets/images/heroes/hero_${hero.id}_stage${stage}_star_blaster.png';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: GestureDetector(
        onTap: () {
          final voice = AudioService().heroPickerVoiceFor(hero.id);
          AudioService().playVoice(voice, clearQueue: true, interrupt: true);
          HapticFeedback.selectionClick();
        },
        child: GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Row(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: hero.primaryColor.withValues(alpha: 0.6),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: hero.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: Image.asset(
                    evolvedPath,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Image.asset(hero.imagePath, fit: BoxFit.cover),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hero.name,
                      style: TextStyle(
                        color: hero.primaryColor,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hero.description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.greenAccent.withValues(alpha: 0.8),
                          size: 16,
                        ),
                      ],
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
}

class _HeroUnlockDialog extends StatefulWidget {
  final HeroCharacter hero;

  const _HeroUnlockDialog({required this.hero});

  @override
  State<_HeroUnlockDialog> createState() => _HeroUnlockDialogState();
}

class _HeroUnlockDialogState extends State<_HeroUnlockDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    AudioService().playVoice(
      'voice_intro_hero_${widget.hero.id}.mp3',
      clearQueue: true,
      interrupt: true,
    );

    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: GlassCard(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: ClipOval(
                    child: Image.asset(
                      widget.hero.imagePath,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${widget.hero.name} UNLOCKED!',
                  style: TextStyle(
                    color: widget.hero.primaryColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.hero.title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WeaponUnlockDialog extends StatefulWidget {
  final WeaponItem weapon;

  const _WeaponUnlockDialog({required this.weapon});

  @override
  State<_WeaponUnlockDialog> createState() => _WeaponUnlockDialogState();
}

class _WeaponUnlockDialogState extends State<_WeaponUnlockDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    AudioService().playVoice(
      'voice_intro_weapon_${widget.weapon.id}.mp3',
      clearQueue: true,
      interrupt: true,
    );

    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: GlassCard(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    widget.weapon.imagePath,
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${widget.weapon.name} UNLOCKED!',
                  style: TextStyle(
                    color: widget.weapon.primaryColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.weapon.description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Price tag for locked items showing the star cost.
/// Affordable items show the price in amber/green; unaffordable in gray with
/// a hint showing how many more stars are needed.
class _PriceTag extends StatelessWidget {
  final int price;
  final int wallet;
  final bool canAfford;

  const _PriceTag({
    required this.price,
    required this.wallet,
    required this.canAfford,
  });

  @override
  Widget build(BuildContext context) {
    final tagColor = canAfford
        ? Colors.yellowAccent
        : Colors.white.withValues(alpha: 0.5);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Price row
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, color: tagColor, size: 14),
            const SizedBox(width: 2),
            Text(
              '$price',
              style: TextStyle(
                color: tagColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        // "Need X more" hint for unaffordable items
        if (!canAfford)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '${price - wallet} more',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 10,
              ),
            ),
          ),
      ],
    );
  }
}
