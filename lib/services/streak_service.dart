import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'sync_service.dart';

class BrushRecord {
  final String date;
  final String time;
  final String heroId;
  final String worldId;

  BrushRecord({
    required this.date,
    required this.time,
    required this.heroId,
    required this.worldId,
  });

  Map<String, dynamic> toJson() => {
    'date': date,
    'time': time,
    'heroId': heroId,
    'worldId': worldId,
  };

  factory BrushRecord.fromJson(Map<String, dynamic> json) => BrushRecord(
    date: json['date'] as String,
    time: json['time'] as String,
    heroId: json['heroId'] as String? ?? 'blaze',
    worldId: json['worldId'] as String? ?? 'candy_crater',
  );
}

class StreakService {
  static const _keyLastBrushDate = 'last_brush_date';
  static const _keyCurrentStreak = 'current_streak';
  static const _keyTotalStars = 'total_stars';
  static const _keyTodayBrushCount = 'today_brush_count';
  static const _keyTodayDate = 'today_date';
  static const _keyTotalBrushes = 'total_brushes';
  static const _keyBestStreak = 'best_streak';
  static const _keyHistory = 'brush_history';

  Future<void> recordBrush({String heroId = 'blaze', String worldId = 'candy_crater'}) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayString();
    final now = DateTime.now();
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

    // Update best streak
    final bestStreak = prefs.getInt(_keyBestStreak) ?? 0;
    if (streak > bestStreak) {
      await prefs.setInt(_keyBestStreak, streak);
    }

    // Update total stars
    int totalStars = prefs.getInt(_keyTotalStars) ?? 0;
    totalStars++;
    await prefs.setInt(_keyTotalStars, totalStars);

    // Update lifetime brush count
    int totalBrushes = prefs.getInt(_keyTotalBrushes) ?? 0;
    totalBrushes++;
    await prefs.setInt(_keyTotalBrushes, totalBrushes);

    // Append to history log (keep last 100 entries)
    final record = BrushRecord(
      date: today,
      time: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      heroId: heroId,
      worldId: worldId,
    );
    final historyJson = prefs.getStringList(_keyHistory) ?? [];
    historyJson.add(jsonEncode(record.toJson()));
    if (historyJson.length > 100) {
      historyJson.removeRange(0, historyJson.length - 100);
    }
    await prefs.setStringList(_keyHistory, historyJson);

    if (AuthService().isSignedIn) {
      SyncService().uploadProgress().catchError((_) {});
    }
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

  Future<bool> spendStars(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_keyTotalStars) ?? 0;
    if (current < amount) return false;
    await prefs.setInt(_keyTotalStars, current - amount);
    return true;
  }

  Future<void> addBonusStars(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_keyTotalStars) ?? 0;
    await prefs.setInt(_keyTotalStars, current + amount);
  }

  Future<int> getTodayBrushCount() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(_keyTodayDate) ?? '';
    if (savedDate == _todayString()) {
      return prefs.getInt(_keyTodayBrushCount) ?? 0;
    }
    return 0;
  }

  Future<int> getTotalBrushes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyTotalBrushes) ?? 0;
  }

  Future<int> getBestStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyBestStreak) ?? 0;
  }

  Future<List<BrushRecord>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList(_keyHistory) ?? [];
    return historyJson
        .map((json) => BrushRecord.fromJson(jsonDecode(json) as Map<String, dynamic>))
        .toList()
        .reversed
        .toList(); // Most recent first
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
