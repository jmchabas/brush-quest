import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/daily_reward_service.dart';
import 'glass_card.dart';

Future<int?> showDailyRewardPopup(BuildContext context) async {
  return showDialog<int>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _DailyRewardDialog(),
  );
}

class _DailyRewardDialog extends StatefulWidget {
  const _DailyRewardDialog();

  @override
  State<_DailyRewardDialog> createState() => _DailyRewardDialogState();
}

class _DailyRewardDialogState extends State<_DailyRewardDialog>
    with TickerProviderStateMixin {
  final _service = DailyRewardService();
  late AnimationController _bounceController;
  late AnimationController _glowController;
  late AnimationController _starsController;
  int _currentDay = 0;
  int? _claimedStars;
  bool _claiming = false;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _starsController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _loadDay();
  }

  Future<void> _loadDay() async {
    final day = await _service.getCurrentDay();
    if (mounted) setState(() => _currentDay = day);
  }

  Future<void> _claim() async {
    if (_claiming) return;
    setState(() => _claiming = true);
    HapticFeedback.heavyImpact();

    final stars = await _service.claimReward();
    _starsController.forward();

    if (mounted) {
      setState(() => _claimedStars = stars);
    }

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) Navigator.of(context).pop(stars);
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _glowController.dispose();
    _starsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reward = DailyRewardService.rewards[_currentDay % 7];

    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'DAILY GIFT!',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: const Color(0xFFFFD54F),
                    fontWeight: FontWeight.bold,
                    fontSize: 32,
                    letterSpacing: 3,
                    shadows: [
                      Shadow(
                        color:
                            const Color(0xFFFFD54F).withValues(alpha: 0.6),
                        blurRadius: 15,
                      ),
                    ],
                  ),
            ),

            const SizedBox(height: 8),

            // Day indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(7, (i) {
                final isPast = i < _currentDay % 7;
                final isToday = i == _currentDay % 7;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isPast
                          ? const Color(0xFF69F0AE).withValues(alpha: 0.3)
                          : isToday
                              ? const Color(0xFFFFD54F).withValues(alpha: 0.3)
                              : Colors.white.withValues(alpha: 0.1),
                      border: Border.all(
                        color: isPast
                            ? const Color(0xFF69F0AE)
                            : isToday
                                ? const Color(0xFFFFD54F)
                                : Colors.white.withValues(alpha: 0.2),
                        width: isToday ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: isPast
                          ? const Icon(Icons.check,
                              color: Color(0xFF69F0AE), size: 16)
                          : Text(
                              '${i + 1}',
                              style: TextStyle(
                                color: isToday
                                    ? const Color(0xFFFFD54F)
                                    : Colors.white.withValues(alpha: 0.4),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 24),

            // Gift box / reward display
            if (_claimedStars != null) ...[
              // Show claimed reward
              ScaleTransition(
                scale: CurvedAnimation(
                    parent: _starsController, curve: Curves.elasticOut),
                child: Column(
                  children: [
                    const Icon(Icons.star,
                        color: Color(0xFFFFD54F), size: 80),
                    const SizedBox(height: 12),
                    Text(
                      '+$_claimedStars STARS!',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                            color: const Color(0xFFFFD54F),
                            fontWeight: FontWeight.bold,
                            fontSize: 28,
                          ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Show gift box to claim
              AnimatedBuilder(
                animation: Listenable.merge([_bounceController, _glowController]),
                builder: (context, child) {
                  final bounce = Curves.easeInOut
                          .transform(_bounceController.value) *
                      8;
                  final glow = _glowController.value;
                  return Transform.translate(
                    offset: Offset(0, -bounce),
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD54F)
                                .withValues(alpha: 0.3 + glow * 0.3),
                            blurRadius: 30 + glow * 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: child,
                    ),
                  );
                },
                child: const Icon(Icons.card_giftcard,
                    color: Color(0xFFFFD54F), size: 100),
              ),

              const SizedBox(height: 16),

              Text(
                'Day ${reward.day}: ${reward.stars} star${reward.stars == 1 ? '' : 's'}!',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 20),

              // Claim button
              GestureDetector(
                onTap: _claim,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD54F), Color(0xFFFFA000)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color:
                            const Color(0xFFFFD54F).withValues(alpha: 0.5),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: Text(
                    'CLAIM!',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          letterSpacing: 3,
                        ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
