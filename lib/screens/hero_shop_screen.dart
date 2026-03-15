import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  int _stars = 0;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    AnalyticsService().logShopVisit();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        AudioService().playVoice('voice_entry_hero_shop.mp3', clearQueue: true, interrupt: true);
      }
    });
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
    final stars = await _streakService.getTotalStars();
    if (mounted) {
      setState(() {
        _unlockedHeroes = unlockedHeroes;
        _selectedHeroId = selectedHero;
        _unlockedWeapons = unlockedWeapons;
        _selectedWeaponId = selectedWeapon;
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
        _playSelectionVoice(AudioService().heroIntroVoiceFor(hero.id));
        if (mounted) _showHeroUnlockAnimation(hero);
        await _loadData();
      }
    } else {
      HapticFeedback.lightImpact();
      AudioService().playVoice('voice_need_stars.mp3', clearQueue: true, interrupt: true);
      final needed = hero.cost - _stars;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.star, color: Colors.yellowAccent, size: 18),
                const SizedBox(width: 6),
                Text('Need $needed more!'),
              ],
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
        _playSelectionVoice(AudioService().weaponIntroVoiceFor(weapon.id));
        if (mounted) _showWeaponUnlockAnimation(weapon);
        await _loadData();
      }
    } else {
      HapticFeedback.lightImpact();
      AudioService().playVoice('voice_need_stars.mp3', clearQueue: true, interrupt: true);
      final needed = weapon.cost - _stars;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.star, color: Colors.yellowAccent, size: 18),
                const SizedBox(width: 6),
                Text('Need $needed more!'),
              ],
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: HeroService.allHeroes.length,
      itemBuilder: (context, index) {
        final hero = HeroService.allHeroes[index];
        final isUnlocked = _unlockedHeroes.contains(hero.id);
        final isSelected = _selectedHeroId == hero.id;
        final canAfford = _stars >= hero.cost;

        return _HeroCard(
          hero: hero,
          isUnlocked: isUnlocked,
          isSelected: isSelected,
          canAfford: canAfford,
          onTap: () => _onHeroTap(hero),
        );
      },
    );
  }

  Widget _buildWeaponGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.78,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: WeaponService.allWeapons.length,
      itemBuilder: (context, index) {
        final weapon = WeaponService.allWeapons[index];
        final isUnlocked = _unlockedWeapons.contains(weapon.id);
        final isSelected = _selectedWeaponId == weapon.id;
        final canAfford = _stars >= weapon.cost;

        return _WeaponCard(
          weapon: weapon,
          isUnlocked: isUnlocked,
          isSelected: isSelected,
          canAfford: canAfford,
          onTap: () => _onWeaponTap(weapon),
        );
      },
    );
  }
}

class _HeroCard extends StatelessWidget {
  final HeroCharacter hero;
  final bool isUnlocked;
  final bool isSelected;
  final bool canAfford;
  final VoidCallback onTap;

  const _HeroCard({
    required this.hero,
    required this.isUnlocked,
    required this.isSelected,
    required this.canAfford,
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
                      child: ColorFiltered(
                        colorFilter: isUnlocked
                            ? const ColorFilter.mode(
                                Colors.transparent,
                                BlendMode.dst,
                              )
                            : ColorFilter.mode(
                                Colors.black.withValues(alpha: 0.6),
                                BlendMode.srcATop,
                              ),
                        child: Image.asset(hero.imagePath, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (!isUnlocked)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.star,
                          color: canAfford
                              ? Colors.yellowAccent
                              : Colors.white.withValues(alpha: 0.3),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${hero.cost}',
                          style: TextStyle(
                            color: canAfford
                                ? Colors.yellowAccent
                                : Colors.white.withValues(alpha: 0.3),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (!isUnlocked)
              Positioned(
                top: 8,
                right: 8,
                child: Icon(
                  Icons.lock,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 20,
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
  final VoidCallback onTap;

  const _WeaponCard({
    required this.weapon,
    required this.isUnlocked,
    required this.isSelected,
    required this.canAfford,
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
                      child: ColorFiltered(
                        colorFilter: isUnlocked
                            ? const ColorFilter.mode(
                                Colors.transparent,
                                BlendMode.dst,
                              )
                            : ColorFilter.mode(
                                Colors.black.withValues(alpha: 0.6),
                                BlendMode.srcATop,
                              ),
                        child: Image.asset(weapon.imagePath, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (!isUnlocked)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.star,
                          color: canAfford
                              ? Colors.yellowAccent
                              : Colors.white.withValues(alpha: 0.3),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${weapon.cost}',
                          style: TextStyle(
                            color: canAfford
                                ? Colors.yellowAccent
                                : Colors.white.withValues(alpha: 0.3),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (!isUnlocked)
              Positioned(
                top: 8,
                right: 8,
                child: Icon(
                  Icons.lock,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 20,
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
