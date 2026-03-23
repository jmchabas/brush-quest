import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'sync_service.dart';

enum BrushSlot { morning, evening }

class BrushOutcome {
  final int baseStars;
  final int streakBonus;
  final int starsEarned; // baseStars + streakBonus
  final BrushSlot slot;
  final bool newSlotCompleted;

  const BrushOutcome({
    required this.baseStars,
    required this.streakBonus,
    required this.starsEarned,
    required this.slot,
    required this.newSlotCompleted,
  });
}

class TodaySlotsStatus {
  final bool morningDone;
  final bool eveningDone;
  const TodaySlotsStatus({required this.morningDone, required this.eveningDone});

  int get completedCount => (morningDone ? 1 : 0) + (eveningDone ? 1 : 0);
}

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
  static const _keyMorningDoneDate = 'morning_done_date';
  static const _keyEveningDoneDate = 'evening_done_date';
  static const _keyStarWallet = 'star_wallet';

  /// Calculate bonus stars from streak length and daily slot completion.
  int calculateStreakBonus({required int streak, required bool bothSlotsDone}) {
    int bonus = 0;
    if (bothSlotsDone) bonus += 1; // Daily completion
    if (streak >= 7) {
      bonus += 2; // 7+ day streak
    } else if (streak >= 3) {
      bonus += 1; // 3+ day streak
    }
    return bonus;
  }

  Future<BrushOutcome> recordBrush({String heroId = 'blaze', String worldId = 'candy_crater'}) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayString();
    final now = DateTime.now();
    final lastDate = prefs.getString(_keyLastBrushDate) ?? '';
    final slot = _slotForHour(now.hour);
    final slotKey = slot == BrushSlot.morning ? _keyMorningDoneDate : _keyEveningDoneDate;
    final slotAlreadyDone = prefs.getString(slotKey) == today;
    final newSlotCompleted = !slotAlreadyDone;

    // Every completed brush earns 2 stars — no daily cap.
    const starsEarned = 2;
    if (newSlotCompleted) {
      await prefs.setString(slotKey, today);
    }
    // Track total brushes done today (not capped to slots)
    final storedDate = prefs.getString(_keyTodayDate) ?? '';
    int todayCount = storedDate == today ? (prefs.getInt(_keyTodayBrushCount) ?? 0) : 0;
    todayCount++;
    await prefs.setInt(_keyTodayBrushCount, todayCount);
    await prefs.setString(_keyTodayDate, today);

    // Update streak (once per day, on first brush of the day)
    int streak = prefs.getInt(_keyCurrentStreak) ?? 0;
    if (lastDate != today) {
      if (lastDate == _yesterdayString()) {
        streak++;
      } else if (lastDate.isEmpty) {
        streak = 1;
      } else {
        streak = 1; // Streak broken
      }
      await prefs.setInt(_keyCurrentStreak, streak);
      await prefs.setString(_keyLastBrushDate, today);
    }

    // Update best streak
    final bestStreak = prefs.getInt(_keyBestStreak) ?? 0;
    if (streak > bestStreak) {
      await prefs.setInt(_keyBestStreak, streak);
    }

    // Calculate streak bonus
    final updatedSlots = TodaySlotsStatus(
      morningDone: prefs.getString(_keyMorningDoneDate) == today,
      eveningDone: prefs.getString(_keyEveningDoneDate) == today,
    );
    final streakBonus = calculateStreakBonus(
      streak: streak,
      bothSlotsDone: updatedSlots.morningDone && updatedSlots.eveningDone,
    );
    final totalEarned = starsEarned + streakBonus;

    // Update total stars
    int totalStars = prefs.getInt(_keyTotalStars) ?? 0;
    totalStars += totalEarned;
    await prefs.setInt(_keyTotalStars, totalStars);

    // Credit wallet (spendable balance)
    int wallet = prefs.getInt(_keyStarWallet) ?? 0;
    wallet += totalEarned;
    await prefs.setInt(_keyStarWallet, wallet);

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

    try {
      if (AuthService().isSignedIn) {
        SyncService().uploadProgress().catchError((_) {});
      }
    } catch (_) {
      // Firebase may be unavailable in unit tests; local progress still persists.
    }

    return BrushOutcome(
      baseStars: starsEarned,
      streakBonus: streakBonus,
      starsEarned: totalEarned,
      slot: slot,
      newSlotCompleted: newSlotCompleted,
    );
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

  Future<void> addBonusStars(int amount) async {
    if (amount <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_keyTotalStars) ?? 0;
    await prefs.setInt(_keyTotalStars, current + amount);
    // Also credit wallet
    final wallet = prefs.getInt(_keyStarWallet) ?? 0;
    await prefs.setInt(_keyStarWallet, wallet + amount);
  }

  Future<int> getWallet() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyStarWallet) ?? 0;
  }

  Future<int> getRangerRank() async {
    return getTotalStars(); // Ranger Rank IS the lifetime total
  }

  /// Spend stars from the wallet. Returns true if successful.
  /// Ranger Rank is never affected by spending.
  Future<bool> spendStars(int amount) async {
    if (amount <= 0) return false;
    final prefs = await SharedPreferences.getInstance();
    final wallet = prefs.getInt(_keyStarWallet) ?? 0;
    if (wallet < amount) return false;
    await prefs.setInt(_keyStarWallet, wallet - amount);
    return true;
  }

  Future<int> getTodayBrushCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayString();
    final storedDate = prefs.getString(_keyTodayDate) ?? '';
    if (storedDate != today) return 0;
    return prefs.getInt(_keyTodayBrushCount) ?? 0;
  }

  Future<TodaySlotsStatus> getTodaySlots() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayString();
    final morningDone = prefs.getString(_keyMorningDoneDate) == today;
    final eveningDone = prefs.getString(_keyEveningDoneDate) == today;
    return TodaySlotsStatus(morningDone: morningDone, eveningDone: eveningDone);
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

  BrushSlot _slotForHour(int hour) {
    return hour < 15 ? BrushSlot.morning : BrushSlot.evening;
  }
}
