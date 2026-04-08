import 'package:flutter/material.dart';
import '../services/trophy_service.dart';

/// Reusable trophy detail dialog shown when tapping a captured monster.
/// Used by both the trophy wall and the victory screen legendary encounter.
class TrophyDetailDialog extends StatelessWidget {
  final TrophyMonster trophy;
  final int defeatCount;
  final Color worldColor;

  const TrophyDetailDialog({
    super.key,
    required this.trophy,
    required this.defeatCount,
    required this.worldColor,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1A1A2E).withValues(alpha: 0.97),
              const Color(0xFF0D0B1A).withValues(alpha: 0.97),
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: worldColor.withValues(alpha: 0.4),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: worldColor.withValues(alpha: 0.2),
              blurRadius: 30,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Monster image with radial glow behind it
              SizedBox(
                height: 160,
                width: 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Radial glow
                    Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            worldColor.withValues(alpha: 0.25),
                            worldColor.withValues(alpha: 0.05),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.6, 1.0],
                        ),
                      ),
                    ),
                    // Monster -- original colors, no tint
                    Image.asset(
                      trophy.imagePath,
                      width: 150,
                      height: 150,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.bug_report,
                        size: 80,
                        color: worldColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Name
              Text(
                trophy.name,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: worldColor.withValues(alpha: 0.5),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // Title -- as a styled badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                decoration: BoxDecoration(
                  color: worldColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  trophy.title,
                  style: TextStyle(
                    color: worldColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Divider
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                color: worldColor.withValues(alpha: 0.15),
              ),
              const SizedBox(height: 16),
              // Flavor text
              Text(
                trophy.flavorText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              // Defeat count with star icons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ...List.generate(
                    defeatCount.clamp(0, 5),
                    (_) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Icon(Icons.star_rounded,
                          color: worldColor, size: 18),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Defeated $defeatCount ${defeatCount == 1 ? 'time' : 'times'}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              // Close button
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        worldColor.withValues(alpha: 0.3),
                        worldColor.withValues(alpha: 0.15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: worldColor.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: worldColor.withValues(alpha: 0.15),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: const Text(
                    'COOL!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
