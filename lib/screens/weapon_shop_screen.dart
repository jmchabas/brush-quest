import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/weapon_service.dart';
import '../services/streak_service.dart';
import '../widgets/space_background.dart';
import '../widgets/glass_card.dart';

class WeaponShopScreen extends StatefulWidget {
  const WeaponShopScreen({super.key});

  @override
  State<WeaponShopScreen> createState() => _WeaponShopScreenState();
}

class _WeaponShopScreenState extends State<WeaponShopScreen> {
  final _weaponService = WeaponService();
  final _streakService = StreakService();
  List<String> _unlocked = ['star_blaster'];
  String _selectedId = 'star_blaster';
  int _stars = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final unlocked = await _weaponService.getUnlockedWeaponIds();
    final selected = await _weaponService.getSelectedWeaponId();
    final stars = await _streakService.getTotalStars();
    if (mounted) {
      setState(() {
        _unlocked = unlocked;
        _selectedId = selected;
        _stars = stars;
      });
    }
  }

  Future<void> _onWeaponTap(WeaponItem weapon) async {
    if (_unlocked.contains(weapon.id)) {
      await _weaponService.selectWeapon(weapon.id);
      HapticFeedback.mediumImpact();
      await _loadData();
    } else if (_stars >= weapon.cost) {
      final success = await _weaponService.unlockWeapon(weapon.id);
      if (success) {
        await _weaponService.selectWeapon(weapon.id);
        HapticFeedback.heavyImpact();
        if (mounted) _showUnlockAnimation(weapon);
        await _loadData();
      }
    } else {
      HapticFeedback.lightImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Need ${weapon.cost - _stars} more stars!',
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

  void _showUnlockAnimation(WeaponItem weapon) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _UnlockDialog(weapon: weapon),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
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
                        'WEAPONS',
                        style:
                            Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 28,
                                  letterSpacing: 3,
                                ),
                      ),
                    ),
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
              Expanded(
                child: GridView.builder(
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
                    final isUnlocked = _unlocked.contains(weapon.id);
                    final isSelected = _selectedId == weapon.id;
                    final canAfford = _stars >= weapon.cost;

                    return _WeaponCard(
                      weapon: weapon,
                      isUnlocked: isUnlocked,
                      isSelected: isSelected,
                      canAfford: canAfford,
                      onTap: () => _onWeaponTap(weapon),
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
                  // Weapon icon
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: isUnlocked
                              ? RadialGradient(colors: [
                                  weapon.primaryColor.withValues(alpha: 0.4),
                                  weapon.secondaryColor.withValues(alpha: 0.1),
                                ])
                              : null,
                          color: isUnlocked
                              ? null
                              : Colors.white.withValues(alpha: 0.05),
                        ),
                        child: Icon(
                          weapon.icon,
                          color: isUnlocked
                              ? weapon.primaryColor
                              : Colors.white.withValues(alpha: 0.3),
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    weapon.name,
                    style: TextStyle(
                      color: isUnlocked
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    weapon.description,
                    style: TextStyle(
                      color: isUnlocked
                          ? Colors.white.withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.2),
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: weapon.primaryColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'EQUIPPED',
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
                      'TAP TO EQUIP',
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
          ],
        ),
      ),
    );
  }
}

class _UnlockDialog extends StatefulWidget {
  final WeaponItem weapon;

  const _UnlockDialog({required this.weapon});

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
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    widget.weapon.primaryColor.withValues(alpha: 0.5),
                    widget.weapon.secondaryColor.withValues(alpha: 0.2),
                  ]),
                ),
                child: Icon(
                  widget.weapon.icon,
                  color: widget.weapon.primaryColor,
                  size: 50,
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
    );
  }
}
