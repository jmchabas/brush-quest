import 'package:shared_preferences/shared_preferences.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  final String emoji;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
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
    ),
    Achievement(
      id: 'streak_7',
      title: 'WEEKLY WARRIOR',
      description: 'Brush 7 days in a row!',
      emoji: '⭐',
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
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final newlyUnlocked = <Achievement>[];

    for (final milestone in _milestones) {
      final key = '$_prefix${milestone.id}';
      if (prefs.getBool(key) == true) continue;

      bool earned = false;
      switch (milestone.id) {
        case 'first_brush':
          earned = totalStars >= 1;
        case 'streak_3':
          earned = streak >= 3;
        case 'streak_7':
          earned = streak >= 7;
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
