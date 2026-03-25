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

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    AnalyticsService().logShopVisit();
  }

  @override
  void dispose() {
    AudioService().stopVoice();
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

  Future<void> _onHeroTap(HeroCharacter hero) async {
    if (_unlockedHeroes.contains(hero.id)) {
      // Select hero and open the armor/evolution bottom sheet
      await _heroService.selectHero(hero.id);
      HapticFeedback.mediumImpact();
      _playSelectionVoice(AudioService().heroPickerVoiceFor(hero.id));
      await _loadData();
      if (mounted) _showArmorBottomSheet(hero);
    } else if (_wallet >= hero.price) {
      if (hero.price > 10) {
        final confirmed = await _showPurchaseConfirmation(hero.name, hero.price);
        if (!confirmed) return;
      }
      final success = await _heroService.purchaseHero(hero.id);
      if (success) {
        await _heroService.selectHero(hero.id);
        HapticFeedback.heavyImpact();
        AnalyticsService().logHeroUnlock(heroId: hero.id, starsAtUnlock: _rank);
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
      _showCannotAffordSnackBar(
        price: hero.price,
        wallet: _wallet,
        accentColor: hero.primaryColor,
      );
    }
  }

  Future<void> _onWeaponTap(WeaponItem weapon) async {
    if (_unlockedWeapons.contains(weapon.id)) {
      await _weaponService.selectWeapon(weapon.id);
      HapticFeedback.mediumImpact();
      _playSelectionVoice(AudioService().weaponPickerVoiceFor(weapon.id));
      await _loadData();
    } else if (_wallet >= weapon.price) {
      if (weapon.price > 10) {
        final confirmed = await _showPurchaseConfirmation(weapon.name, weapon.price);
        if (!confirmed) return;
      }
      final success = await _weaponService.purchaseWeapon(weapon.id);
      if (success) {
        await _weaponService.selectWeapon(weapon.id);
        HapticFeedback.heavyImpact();
        AnalyticsService().logWeaponUnlock(weaponId: weapon.id, starsAtUnlock: _rank);
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
      _showCannotAffordSnackBar(
        price: weapon.price,
        wallet: _wallet,
        accentColor: weapon.primaryColor,
      );
    }
  }

  Future<bool> _showPurchaseConfirmation(String itemName, int price) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Get $itemName?',
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.star, color: Colors.amber, size: 32),
              const SizedBox(width: 8),
              Text('$price', style: const TextStyle(color: Colors.amber, fontSize: 32, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Not yet', style: TextStyle(color: Colors.white54, fontSize: 18)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('YES!', style: TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold)),
              ),
            ]),
          ],
        ),
      ),
    ) ?? false;
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
          children: [
            Icon(Icons.star, color: accentColor, size: 18),
            const SizedBox(width: 8),
            Text(
              'Need $delta more stars! Keep brushing!',
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
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

  void _showArmorBottomSheet(HeroCharacter hero) {
    final evolutions = HeroService.evolutionsForHero(hero.id);
    if (evolutions.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final currentStage = _evolutionStages[hero.id] ?? 1;
            final currentWeaponId = _selectedWeaponId;

            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A2E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Hero image with current evolution + weapon
                  Container(
                    width: 100,
                    height: 100,
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
                      child: HeroService.buildHeroImage(
                        hero.id,
                        stage: currentStage,
                        weaponId: currentWeaponId,
                        size: 100,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    HeroService.getEvolutionForHero(hero.id, currentStage).name,
                    style: TextStyle(
                      color: hero.primaryColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // "Armor" header
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'ARMOR',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Evolution options
                  ...evolutions.map((evo) {
                    final isOwned = evo.stage == 1 || _unlockedEvolutions.contains(evo.id);
                    final isEquipped = currentStage == evo.stage;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildEvolutionOption(
                        ctx: ctx,
                        setSheetState: setSheetState,
                        hero: hero,
                        evolution: evo,
                        isOwned: isOwned,
                        isEquipped: isEquipped,
                        currentWeaponId: currentWeaponId,
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEvolutionOption({
    required BuildContext ctx,
    required StateSetter setSheetState,
    required HeroCharacter hero,
    required HeroEvolution evolution,
    required bool isOwned,
    required bool isEquipped,
    required String currentWeaponId,
  }) {
    final displayColor = hero.primaryColor;
    final canAfford = isOwned || _wallet >= evolution.price;

    return GestureDetector(
      onTap: () async {
        if (isEquipped) return;
        if (isOwned) {
          // Equip this evolution stage
          await _heroService.setEvolutionStage(hero.id, evolution.stage);
          HapticFeedback.mediumImpact();
          _playSelectionVoice(AudioService().heroPickerVoiceFor(hero.id));
          await _loadData();
          setSheetState(() {});
        } else if (canAfford) {
          // Purchase evolution
          if (evolution.price > 10) {
            final confirmed = await _showPurchaseConfirmation(evolution.name, evolution.price);
            if (!confirmed) return;
          }
          final success = await _heroService.purchaseEvolution(evolution.id);
          if (success) {
            // Auto-equip after purchase
            await _heroService.setEvolutionStage(hero.id, evolution.stage);
            HapticFeedback.heavyImpact();
            await _loadData();
            setSheetState(() {});
          }
        } else {
          // Can't afford — describe the evolution first, then tell them they need more stars
          HapticFeedback.lightImpact();
          _playSelectionVoice(AudioService().heroPickerVoiceFor(hero.id));
          AudioService().playVoice('voice_need_stars.mp3');
          _showCannotAffordSnackBar(
            price: evolution.price,
            wallet: _wallet,
            accentColor: hero.primaryColor,
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isEquipped
              ? displayColor.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isEquipped
                ? displayColor.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.1),
            width: isEquipped ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Hero evolution preview thumbnail
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isEquipped
                      ? displayColor.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: HeroService.buildHeroImage(
                  hero.id,
                  stage: evolution.stage,
                  weaponId: currentWeaponId,
                  size: 48,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Name + description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    evolution.name,
                    style: TextStyle(
                      color: isEquipped ? Colors.white : Colors.white.withValues(alpha: 0.8),
                      fontSize: 15,
                      fontWeight: isEquipped ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      evolution.description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Badge
            if (isEquipped)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'EQUIPPED',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              )
            else if (isOwned)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'OWNED',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star,
                    color: canAfford ? Colors.yellowAccent : Colors.white.withValues(alpha: 0.4),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${evolution.price}',
                    style: TextStyle(
                      color: canAfford ? Colors.yellowAccent : Colors.white.withValues(alpha: 0.4),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
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
                    // Ranger Rank
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.cyanAccent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.diamond,
                            color: Colors.cyanAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$_rank',
                            style: const TextStyle(
                              color: Colors.cyanAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Wallet
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
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
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$_wallet',
                            style: const TextStyle(
                              color: Colors.yellowAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
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
                    _buildHeroGrid(),
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
                final canAfford = _wallet >= hero.price;

                return _HeroCard(
                  hero: hero,
                  isUnlocked: isUnlocked,
                  isSelected: isSelected,
                  canAfford: canAfford,
                  currentStars: _wallet,
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
                final canAfford = _wallet >= weapon.price;

                return _WeaponCard(
                  weapon: weapon,
                  isUnlocked: isUnlocked,
                  isSelected: isSelected,
                  canAfford: canAfford,
                  currentStars: _wallet,
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
                    child: Opacity(
                      opacity: isUnlocked ? 1.0 : 0.85,
                      child: ColorFiltered(
                        colorFilter: isUnlocked
                            ? const ColorFilter.mode(
                                Colors.transparent,
                                BlendMode.dst,
                              )
                            : ColorFilter.matrix(_partialDesaturationMatrix(0.3)),
                        child: Image.asset(hero.imagePath, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (!isUnlocked && hero.price > 0)
                    _PriceTag(
                      price: hero.price,
                      wallet: currentStars,
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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
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
                  if (!isUnlocked && weapon.price > 0)
                    _PriceTag(
                      price: weapon.price,
                      wallet: currentStars,
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
    final tagColor =
        canAfford ? Colors.yellowAccent : Colors.white.withValues(alpha: 0.5);

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

