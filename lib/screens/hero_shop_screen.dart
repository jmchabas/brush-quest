import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/audio_service.dart';
import '../services/cosmetic_service.dart';
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
  final _cosmeticService = CosmeticService();
  final _streakService = StreakService();

  List<String> _unlockedHeroes = ['blaze'];
  String _selectedHeroId = 'blaze';
  List<String> _unlockedWeapons = ['star_blaster'];
  String _selectedWeaponId = 'star_blaster';
  List<String> _unlockedCosmetics = [];
  String? _selectedCosmeticId;
  int _stars = 0;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    AnalyticsService().logShopVisit();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final unlockedHeroes = await _heroService.getUnlockedHeroIds();
    final selectedHero = await _heroService.getSelectedHeroId();
    final unlockedWeapons = await _weaponService.getUnlockedWeaponIds();
    final selectedWeapon = await _weaponService.getSelectedWeaponId();
    final unlockedCosmetics = await _cosmeticService.getUnlockedCosmeticIds();
    final selectedCosmetic = await _cosmeticService.getSelectedCosmeticId();
    final stars = await _streakService.getTotalStars();
    if (mounted) {
      setState(() {
        _unlockedHeroes = unlockedHeroes;
        _selectedHeroId = selectedHero;
        _unlockedWeapons = unlockedWeapons;
        _selectedWeaponId = selectedWeapon;
        _unlockedCosmetics = unlockedCosmetics;
        _selectedCosmeticId = selectedCosmetic;
        _stars = stars;
      });
    }
  }

  Future<void> _onHeroTap(HeroCharacter hero) async {
    if (_unlockedHeroes.contains(hero.id)) {
      await _heroService.selectHero(hero.id);
      HapticFeedback.mediumImpact();
      _playSelectionVoice(AudioService().heroPickerVoiceFor(hero.id));
      await _loadData();
    } else if (_stars >= hero.cost) {
      final success = await _heroService.unlockHero(hero.id);
      if (success) {
        await _heroService.selectHero(hero.id);
        HapticFeedback.heavyImpact();
        AnalyticsService().logHeroUnlock(heroId: hero.id, starsSpent: hero.cost);
        // Finding #8: Don't play voice here — the unlock dialog's initState
        // plays the intro voice. Playing it here too causes an audible stutter.
        if (mounted) _showHeroUnlockAnimation(hero);
        await _loadData();
      }
    } else {
      HapticFeedback.lightImpact();
      // Describe the hero, then tell them they need more stars
      _playSelectionVoice(AudioService().heroPickerVoiceFor(hero.id));
      AudioService().playVoice('voice_need_stars.mp3');
    }
  }

  Future<void> _onWeaponTap(WeaponItem weapon) async {
    if (_unlockedWeapons.contains(weapon.id)) {
      await _weaponService.selectWeapon(weapon.id);
      HapticFeedback.mediumImpact();
      _playSelectionVoice(AudioService().weaponPickerVoiceFor(weapon.id));
      await _loadData();
    } else if (_stars >= weapon.cost) {
      final success = await _weaponService.unlockWeapon(weapon.id);
      if (success) {
        await _weaponService.selectWeapon(weapon.id);
        HapticFeedback.heavyImpact();
        AnalyticsService().logWeaponUnlock(weaponId: weapon.id, starsSpent: weapon.cost);
        // Finding #8: Don't play voice here — the unlock dialog's initState
        // plays the intro voice. Playing it here too causes an audible stutter.
        if (mounted) _showWeaponUnlockAnimation(weapon);
        await _loadData();
      }
    } else {
      HapticFeedback.lightImpact();
      // Describe the weapon, then tell them they need more stars
      _playSelectionVoice(AudioService().weaponPickerVoiceFor(weapon.id));
      AudioService().playVoice('voice_need_stars.mp3');
    }
  }

  Future<void> _onCosmeticTap(CosmeticItem cosmetic) async {
    if (_unlockedCosmetics.contains(cosmetic.id)) {
      // Already owned — toggle selection (tap again to deselect)
      if (_selectedCosmeticId == cosmetic.id) {
        await _cosmeticService.deselect();
      } else {
        await _cosmeticService.select(cosmetic.id);
      }
      HapticFeedback.mediumImpact();
      _playSelectionVoice('voice_great_choice.mp3');
      await _loadData();
    } else if (_stars >= cosmetic.cost) {
      final success = await _cosmeticService.unlock(cosmetic.id);
      if (success) {
        await _cosmeticService.select(cosmetic.id);
        HapticFeedback.heavyImpact();
        _playSelectionVoice('voice_great_choice.mp3');
        await _loadData();
      }
    } else {
      HapticFeedback.lightImpact();
      _playSelectionVoice('voice_need_stars.mp3');
    }
  }

  void _playSelectionVoice(String fileName) {
    AudioService().playVoice(fileName, clearQueue: true, interrupt: true);
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
                      onTap: () => Navigator.of(context).pop(),
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
                    // Star balance
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.yellowAccent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star,
                            color: Colors.yellowAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$_stars',
                            style: const TextStyle(
                              color: Colors.yellowAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
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
                          SizedBox(width: 6),
                          Text('HEROES'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bolt, size: 20),
                          SizedBox(width: 6),
                          Text('WEAPONS'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome, size: 20),
                          SizedBox(width: 6),
                          Text('FRAMES'),
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
                    _buildHeroGrid(),
                    // Weapons tab
                    _buildWeaponGrid(),
                    // Frames tab
                    _buildCosmeticGrid(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroGrid() {
    final selectedHero = HeroService.allHeroes.firstWhere(
      (h) => h.id == _selectedHeroId,
      orElse: () => HeroService.allHeroes.first,
    );

    return CustomScrollView(
      slivers: [
        // Featured selected hero display
        SliverToBoxAdapter(
          child: _FeaturedHeroDisplay(hero: selectedHero),
        ),
        // Hero grid
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.68,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final hero = HeroService.allHeroes[index];
                final isUnlocked = _unlockedHeroes.contains(hero.id);
                final isSelected = _selectedHeroId == hero.id;
                final canAfford = _stars >= hero.cost;

                return _HeroCard(
                  hero: hero,
                  isUnlocked: isUnlocked,
                  isSelected: isSelected,
                  canAfford: canAfford,
                  currentStars: _stars,
                  onTap: () => _onHeroTap(hero),
                );
              },
              childCount: HeroService.allHeroes.length,
            ),
          ),
        ),
      ],
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
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final weapon = WeaponService.allWeapons[index];
                final isUnlocked = _unlockedWeapons.contains(weapon.id);
                final isSelected = _selectedWeaponId == weapon.id;
                final canAfford = _stars >= weapon.cost;

                return _WeaponCard(
                  weapon: weapon,
                  isUnlocked: isUnlocked,
                  isSelected: isSelected,
                  canAfford: canAfford,
                  currentStars: _stars,
                  onTap: () => _onWeaponTap(weapon),
                );
              },
              childCount: WeaponService.allWeapons.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCosmeticGrid() {
    // Find the selected cosmetic for featured display
    final selectedCosmetic = _selectedCosmeticId != null
        ? CosmeticService.getCosmeticById(_selectedCosmeticId!)
        : null;

    return CustomScrollView(
      slivers: [
        // Featured selected cosmetic display (or hint if none selected)
        SliverToBoxAdapter(
          child: selectedCosmetic != null
              ? _FeaturedCosmeticDisplay(cosmetic: selectedCosmetic)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 20,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 3,
                            ),
                          ),
                          child: Icon(
                            Icons.auto_awesome,
                            color: Colors.white.withValues(alpha: 0.4),
                            size: 36,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Text(
                            'NO FRAME SELECTED',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
        // Cosmetic grid
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.85,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final cosmetic = CosmeticService.allCosmetics[index];
                final isUnlocked =
                    _unlockedCosmetics.contains(cosmetic.id);
                final isSelected = _selectedCosmeticId == cosmetic.id;
                final canAfford = _stars >= cosmetic.cost;

                return _CosmeticCard(
                  cosmetic: cosmetic,
                  isUnlocked: isUnlocked,
                  isSelected: isSelected,
                  canAfford: canAfford,
                  currentStars: _stars,
                  onTap: () => _onCosmeticTap(cosmetic),
                );
              },
              childCount: CosmeticService.allCosmetics.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final HeroCharacter hero;
  final bool isUnlocked;
  final bool isSelected;
  final bool canAfford;
  final int currentStars;
  final VoidCallback onTap;

  const _HeroCard({
    required this.hero,
    required this.isUnlocked,
    required this.isSelected,
    required this.canAfford,
    required this.currentStars,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? hero.primaryColor
                : isUnlocked
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: hero.primaryColor.withValues(alpha: 0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
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
                    child: ClipOval(
                      child: Opacity(
                        opacity: isUnlocked ? 1.0 : 0.85,
                        child: ColorFiltered(
                          colorFilter: isUnlocked
                              ? const ColorFilter.mode(
                                  Colors.transparent,
                                  BlendMode.dst,
                                )
                              : ColorFilter.matrix(_partialDesaturationMatrix(0.3)),
                          child: Image.asset(hero.imagePath, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (!isUnlocked && hero.cost > 0)
                    _LockedProgressIndicator(
                      currentStars: currentStars,
                      cost: hero.cost,
                      canAfford: canAfford,
                    ),
                ],
              ),
            ),
            if (!isUnlocked)
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
            if (isSelected)
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
  }
}

class _WeaponCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? weapon.primaryColor
                : isUnlocked
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: weapon.primaryColor.withValues(alpha: 0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
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
                    child: ClipOval(
                      child: Opacity(
                        opacity: isUnlocked ? 1.0 : 0.85,
                        child: ColorFiltered(
                          colorFilter: isUnlocked
                              ? const ColorFilter.mode(
                                  Colors.transparent,
                                  BlendMode.dst,
                                )
                              : ColorFilter.matrix(_partialDesaturationMatrix(0.3)),
                          child: Image.asset(weapon.imagePath, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (!isUnlocked && weapon.cost > 0)
                    _LockedProgressIndicator(
                      currentStars: currentStars,
                      cost: weapon.cost,
                      canAfford: canAfford,
                    ),
                ],
              ),
            ),
            if (!isUnlocked)
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
            if (isSelected)
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
    lumR * invSat + saturation, lumG * invSat,               lumB * invSat,               0, 0,
    lumR * invSat,               lumG * invSat + saturation, lumB * invSat,               0, 0,
    lumR * invSat,               lumG * invSat,               lumB * invSat + saturation, 0, 0,
    0,                           0,                           0,                           1, 0,
  ];
}

class _FeaturedHeroDisplay extends StatelessWidget {
  final HeroCharacter hero;

  const _FeaturedHeroDisplay({required this.hero});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Row(
          children: [
            // Hero image
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
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
              child: ClipOval(
                child: Image.asset(hero.imagePath, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 20),
            // Hero info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hero.name,
                    style: TextStyle(
                      color: hero.primaryColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hero.title,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.greenAccent.withValues(alpha: 0.8),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'SELECTED',
                        style: TextStyle(
                          color: Colors.greenAccent.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedWeaponDisplay extends StatelessWidget {
  final WeaponItem weapon;

  const _FeaturedWeaponDisplay({required this.weapon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Row(
          children: [
            // Weapon image
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
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
              child: ClipOval(
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
                      const SizedBox(width: 4),
                      Text(
                        'EQUIPPED',
                        style: TextStyle(
                          color: Colors.greenAccent.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
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

    AudioService().playVoice('voice_intro_hero_${widget.hero.id}.mp3', clearQueue: true, interrupt: true);

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
                    child: Image.asset(widget.hero.imagePath, fit: BoxFit.cover),
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

    AudioService().playVoice('voice_intro_weapon_${widget.weapon.id}.mp3', clearQueue: true, interrupt: true);

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
                    child: Image.asset(widget.weapon.imagePath, fit: BoxFit.cover),
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

/// Finding #13: Progress indicator for locked items showing "X/Y" stars
/// and a mini linear progress bar.
class _LockedProgressIndicator extends StatelessWidget {
  final int currentStars;
  final int cost;
  final bool canAfford;

  const _LockedProgressIndicator({
    required this.currentStars,
    required this.cost,
    required this.canAfford,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (currentStars / cost).clamp(0.0, 1.0);
    final progressColor =
        canAfford ? Colors.yellowAccent : Colors.white.withValues(alpha: 0.5);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Star count text: "X/Y"
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.star,
              color: progressColor,
              size: 14,
            ),
            const SizedBox(width: 3),
            Text(
              '$currentStars/$cost',
              style: TextStyle(
                color: progressColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Mini progress bar
        SizedBox(
          width: 80,
          height: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                canAfford
                    ? Colors.yellowAccent
                    : Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Finding #7: Cosmetic frame card for the FRAMES tab.
class _CosmeticCard extends StatelessWidget {
  final CosmeticItem cosmetic;
  final bool isUnlocked;
  final bool isSelected;
  final bool canAfford;
  final int currentStars;
  final VoidCallback onTap;

  const _CosmeticCard({
    required this.cosmetic,
    required this.isUnlocked,
    required this.isSelected,
    required this.canAfford,
    required this.currentStars,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? cosmetic.color
                : isUnlocked
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: cosmetic.color.withValues(alpha: 0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Frame preview: colored ring
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isUnlocked
                            ? cosmetic.color
                            : cosmetic.color.withValues(alpha: 0.4),
                        width: cosmetic.isAnimated ? 5 : 4,
                      ),
                      boxShadow: isUnlocked
                          ? [
                              BoxShadow(
                                color: cosmetic.color.withValues(alpha: 0.3),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.auto_awesome,
                        color: isUnlocked
                            ? cosmetic.color.withValues(alpha: 0.6)
                            : Colors.white.withValues(alpha: 0.15),
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Frame name
                  Text(
                    cosmetic.name,
                    style: TextStyle(
                      color: isUnlocked
                          ? cosmetic.color
                          : Colors.white.withValues(alpha: 0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Cost / progress if locked
                  if (!isUnlocked)
                    _LockedProgressIndicator(
                      currentStars: currentStars,
                      cost: cosmetic.cost,
                      canAfford: canAfford,
                    ),
                ],
              ),
            ),
            // Lock icon
            if (!isUnlocked)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.25),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.lock,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 18,
                  ),
                ),
              ),
            // Selected checkmark
            if (isSelected)
              Positioned(
                bottom: 6,
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
                      size: 18,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Featured display for the selected cosmetic frame.
class _FeaturedCosmeticDisplay extends StatelessWidget {
  final CosmeticItem cosmetic;

  const _FeaturedCosmeticDisplay({required this.cosmetic});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Row(
          children: [
            // Frame preview ring
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: cosmetic.color,
                  width: cosmetic.isAnimated ? 5 : 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: cosmetic.color.withValues(alpha: 0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.auto_awesome,
                  color: cosmetic.color.withValues(alpha: 0.6),
                  size: 32,
                ),
              ),
            ),
            const SizedBox(width: 20),
            // Frame info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cosmetic.name,
                    style: TextStyle(
                      color: cosmetic.color,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.greenAccent.withValues(alpha: 0.8),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'SELECTED',
                        style: TextStyle(
                          color: Colors.greenAccent.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
