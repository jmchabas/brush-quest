import 'package:shared_preferences/shared_preferences.dart';

class StreakService {
  static const _keyLastBrushDate = 'last_brush_date';
  static const _keyCurrentStreak = 'current_streak';
  static const _keyTotalStars = 'total_stars';
  static const _keyTodayBrushCount = 'today_brush_count';
  static const _keyTodayDate = 'today_date';

  Future<void> recordBrush() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayString();
    final lastDate = prefs.getString(_keyLastBrushDate) ?? '';
    final savedDate = prefs.getString(_keyTodayDate) ?? '';

    // Update today's brush count
    int todayCount = 0;
    if (savedDate == today) {
      todayCount = prefs.getInt(_keyTodayBrushCount) ?? 0;
    }
    todayCount++;
    await prefs.setInt(_keyTodayBrushCount, todayCount);
    await prefs.setString(_keyTodayDate, today);

    // Update streak
    int streak = prefs.getInt(_keyCurrentStreak) ?? 0;
    if (lastDate == today) {
      // Already brushed today, don't increment streak
    } else if (lastDate == _yesterdayString()) {
      streak++;
    } else if (lastDate.isEmpty) {
      streak = 1;
    } else {
      streak = 1; // Streak broken
    }
    await prefs.setInt(_keyCurrentStreak, streak);
    await prefs.setString(_keyLastBrushDate, today);

    // Update total stars
    int totalStars = prefs.getInt(_keyTotalStars) ?? 0;
    totalStars++;
    await prefs.setInt(_keyTotalStars, totalStars);
  }

  Future<int> getStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDate = prefs.getString(_keyLastBrushDate) ?? '';
    final today = _todayString();
    final yesterday = _yesterdayString();

    if (lastDate == today || lastDate == yesterday) {
      return prefs.getInt(_keyCurrentStreak) ?? 0;
    }
    return 0;
  }

  Future<int> getTotalStars() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyTotalStars) ?? 0;
  }

  Future<int> getTodayBrushCount() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(_keyTodayDate) ?? '';
    if (savedDate == _todayString()) {
      return prefs.getInt(_keyTodayBrushCount) ?? 0;
    }
    return 0;
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _yesterdayString() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
  }
}
