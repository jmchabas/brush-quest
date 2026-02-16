import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/hero_service.dart';
import '../services/streak_service.dart';
import '../widgets/space_background.dart';
import '../widgets/glass_card.dart';

class HeroShopScreen extends StatefulWidget {
  const HeroShopScreen({super.key});

  @override
  State<HeroShopScreen> createState() => _HeroShopScreenState();
}

class _HeroShopScreenState extends State<HeroShopScreen> {
  final _heroService = HeroService();
  final _streakService = StreakService();
  List<String> _unlocked = ['blaze'];
  String _selectedId = 'blaze';
  int _stars = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final unlocked = await _heroService.getUnlockedHeroIds();
    final selected = await _heroService.getSelectedHeroId();
    final stars = await _streakService.getTotalStars();
    if (mounted) {
      setState(() {
        _unlocked = unlocked;
        _selectedId = selected;
        _stars = stars;
      });
    }
  }

  Future<void> _onHeroTap(HeroCharacter hero) async {
    if (_unlocked.contains(hero.id)) {
      // Already unlocked — select it
      await _heroService.selectHero(hero.id);
      HapticFeedback.mediumImpact();
      await _loadData();
    } else if (_stars >= hero.cost) {
      // Can afford — buy it
      final success = await _heroService.unlockHero(hero.id);
      if (success) {
        await _heroService.selectHero(hero.id);
        HapticFeedback.heavyImpact();
        if (mounted) {
          _showUnlockAnimation(hero);
        }
        await _loadData();
      }
    } else {
      // Can't afford
      HapticFeedback.lightImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Need ${hero.cost - _stars} more stars!',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showUnlockAnimation(HeroCharacter hero) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _UnlockDialog(hero: hero),
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
                      child: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'SPACE RANGERS',
                        style:
                            Theme.of(context).textTheme.headlineMedium?.copyWith(
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
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.yellowAccent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star,
                              color: Colors.yellowAccent, size: 20),
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

              // Hero grid
              Expanded(
                child: GridView.builder(
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
                    final isUnlocked = _unlocked.contains(hero.id);
                    final isSelected = _selectedId == hero.id;
                    final canAfford = _stars >= hero.cost;

                    return _HeroCard(
                      hero: hero,
                      isUnlocked: isUnlocked,
                      isSelected: isSelected,
                      canAfford: canAfford,
                      onTap: () => _onHeroTap(hero),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
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
            // Hero content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Hero image
                  Expanded(
                    child: ClipOval(
                      child: ColorFiltered(
                        colorFilter: isUnlocked
                            ? const ColorFilter.mode(
                                Colors.transparent, BlendMode.dst)
                            : ColorFilter.mode(
                                Colors.black.withValues(alpha: 0.6),
                                BlendMode.srcATop),
                        child: Image.asset(
                          hero.imagePath,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Name
                  Text(
                    hero.name,
                    style: TextStyle(
                      color: isUnlocked
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Title
                  Text(
                    hero.title,
                    style: TextStyle(
                      color: isUnlocked
                          ? hero.primaryColor
                          : Colors.white.withValues(alpha: 0.3),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Price or status
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: hero.primaryColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'SELECTED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    )
                  else if (isUnlocked)
                    Text(
                      'TAP TO SELECT',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 10,
                        letterSpacing: 1,
                      ),
                    )
                  else
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
            // Lock overlay
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
          ],
        ),
      ),
    );
  }
}

class _UnlockDialog extends StatefulWidget {
  final HeroCharacter hero;

  const _UnlockDialog({required this.hero});

  @override
  State<_UnlockDialog> createState() => _UnlockDialogState();
}

class _UnlockDialogState extends State<_UnlockDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    Future.delayed(const Duration(seconds: 2), () {
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
    );
  }
}
