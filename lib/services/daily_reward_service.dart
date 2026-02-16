import 'package:shared_preferences/shared_preferences.dart';

class DailyReward {
  final int day;
  final int stars;
  final String label;

  const DailyReward({
    required this.day,
    required this.stars,
    required this.label,
  });
}

class DailyRewardService {
  static const _lastClaimKey = 'daily_reward_last_claim';
  static const _streakDayKey = 'daily_reward_streak_day';

  static const List<DailyReward> rewards = [
    DailyReward(day: 1, stars: 1, label: 'Day 1'),
    DailyReward(day: 2, stars: 2, label: 'Day 2'),
    DailyReward(day: 3, stars: 3, label: 'Day 3'),
    DailyReward(day: 4, stars: 4, label: 'Day 4'),
    DailyReward(day: 5, stars: 5, label: 'Day 5'),
    DailyReward(day: 6, stars: 7, label: 'Day 6'),
    DailyReward(day: 7, stars: 10, label: 'Day 7'),
  ];

  Future<bool> canClaimToday() async {
    final prefs = await SharedPreferences.getInstance();
    final lastClaim = prefs.getString(_lastClaimKey);
    if (lastClaim == null) return true;

    final today = _todayString();
    return lastClaim != today;
  }

  /// Returns 0-indexed day in the 7-day cycle
  Future<int> getCurrentDay() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_streakDayKey) ?? 0;
  }

  /// Claims today's reward. Returns the number of bonus stars earned.
  Future<int> claimReward() async {
    final prefs = await SharedPreferences.getInstance();
    final day = prefs.getInt(_streakDayKey) ?? 0;
    final reward = rewards[day % rewards.length];

    // Add bonus stars
    final totalStars = prefs.getInt('total_stars') ?? 0;
    await prefs.setInt('total_stars', totalStars + reward.stars);

    // Update tracking
    final today = _todayString();
    await prefs.setString(_lastClaimKey, today);
    await prefs.setInt(_streakDayKey, (day + 1) % rewards.length);

    return reward.stars;
  }

  /// Returns the reward for the current day in the cycle
  Future<DailyReward> getTodayReward() async {
    final day = await getCurrentDay();
    return rewards[day % rewards.length];
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
