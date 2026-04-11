import 'package:shared_preferences/shared_preferences.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final int bonusStars;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    this.bonusStars = 0,
  });
}

class AchievementService {
  static const _prefix = 'achievement_';

  static const _milestones = [
    Achievement(
      id: 'first_brush',
      title: 'FIRST MISSION',
      description: 'Complete your first brushing!',
      emoji: '🚀',
    ),
    Achievement(
      id: 'streak_3',
      title: '3-DAY STREAK',
      description: 'Brush 3 days in a row!',
      emoji: '🔥',
      bonusStars: 1,
    ),
    Achievement(
      id: 'streak_7',
      title: 'WEEKLY WARRIOR',
      description: 'Brush 7 days in a row!',
      emoji: '⭐',
      bonusStars: 2,
    ),
    Achievement(
      id: 'streak_14',
      title: '2-WEEK CHAMPION',
      description: 'Brush 14 days in a row!',
      emoji: '💪',
      bonusStars: 2,
    ),
    Achievement(
      id: 'streak_30',
      title: 'MONTHLY LEGEND',
      description: 'Brush 30 days in a row!',
      emoji: '🏅',
      bonusStars: 3,
    ),
    Achievement(
      id: 'brushes_10',
      title: 'ROOKIE RANGER',
      description: 'Complete 10 brushing missions!',
      emoji: '🪥',
      bonusStars: 1,
    ),
    Achievement(
      id: 'brushes_25',
      title: 'SKILLED RANGER',
      description: 'Complete 25 brushing missions!',
      emoji: '🛡️',
      bonusStars: 2,
    ),
    Achievement(
      id: 'brushes_50',
      title: 'ELITE RANGER',
      description: 'Complete 50 brushing missions!',
      emoji: '⚔️',
      bonusStars: 3,
    ),
    Achievement(
      id: 'brushes_100',
      title: 'ULTIMATE RANGER',
      description: 'Complete 100 brushing missions!',
      emoji: '🌠',
      bonusStars: 5,
    ),
    Achievement(
      id: 'stars_10',
      title: 'STAR COLLECTOR',
      description: 'Earn 10 stars!',
      emoji: '🌟',
    ),
    Achievement(
      id: 'stars_25',
      title: 'STAR CAPTAIN',
      description: 'Earn 25 stars!',
      emoji: '💫',
    ),
    Achievement(
      id: 'stars_50',
      title: 'STAR COMMANDER',
      description: 'Earn 50 stars!',
      emoji: '🏆',
    ),
    Achievement(
      id: 'stars_100',
      title: 'SPACE LEGEND',
      description: 'Earn 100 stars!',
      emoji: '👑',
    ),
  ];

  Future<List<Achievement>> checkAndUnlock({
    required int streak,
    required int totalStars,
    int totalBrushes = 0,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final newlyUnlocked = <Achievement>[];

    for (final milestone in _milestones) {
      final key = '$_prefix${milestone.id}';
      if (prefs.getBool(key) ?? false) continue;

      bool earned = false;
      switch (milestone.id) {
        case 'first_brush':
          earned = totalBrushes >= 1;
        case 'streak_3':
          earned = streak >= 3;
        case 'streak_7':
          earned = streak >= 7;
        case 'streak_14':
          earned = streak >= 14;
        case 'streak_30':
          earned = streak >= 30;
        case 'brushes_10':
          earned = totalBrushes >= 10;
        case 'brushes_25':
          earned = totalBrushes >= 25;
        case 'brushes_50':
          earned = totalBrushes >= 50;
        case 'brushes_100':
          earned = totalBrushes >= 100;
        case 'stars_10':
          earned = totalStars >= 10;
        case 'stars_25':
          earned = totalStars >= 25;
        case 'stars_50':
          earned = totalStars >= 50;
        case 'stars_100':
          earned = totalStars >= 100;
      }

      if (earned) {
        await prefs.setBool(key, true);
        newlyUnlocked.add(milestone);
      }
    }

    return newlyUnlocked;
  }
}
