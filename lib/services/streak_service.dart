import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'sync_service.dart';

enum BrushSlot { morning, evening }

class BonusBreakdown {
  final int dailyBonus;
  final int streakMultiplierBonus;
  int get total => dailyBonus + streakMultiplierBonus;
  const BonusBreakdown({
    required this.dailyBonus,
    required this.streakMultiplierBonus,
  });
}

class BrushOutcome {
  final int baseStars;
  final int streakBonus;
  final int comebackBonus; // +3 on first brush after streak break
  final int starsEarned; // baseStars + streakBonus + comebackBonus
  final BrushSlot slot;
  final bool newSlotCompleted;
  final BonusBreakdown breakdown;

  const BrushOutcome({
    required this.baseStars,
    required this.streakBonus,
    this.comebackBonus = 0,
    required this.starsEarned,
    required this.slot,
    required this.newSlotCompleted,
    required this.breakdown,
  });
}

class TodaySlotsStatus {
  final bool morningDone;
  final bool eveningDone;
  const TodaySlotsStatus({
    required this.morningDone,
    required this.eveningDone,
  });

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
  /// Cross-service purchase mutex — shared by HeroService & WeaponService.
  /// Prevents concurrent star-deducting purchases from racing.
  static bool isPurchasing = false;

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
  static const _keyStreakPauseUntil = 'streak_pause_until';
  static const _keyLastDailyBonusDate = 'last_daily_bonus_date';
  static const _keyHasSeenFirstStreak3 = 'has_seen_first_streak_3';
  static const _keyHasSeenFirstStreak7 = 'has_seen_first_streak_7';
  static const _keyHasSeenFirstDailyPair = 'has_seen_first_daily_pair';
  static const _keyHasSeenFirstComeback = 'has_seen_first_comeback';

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

  /// Same as [calculateStreakBonus] but returns a [BonusBreakdown] that
  /// separates the daily-pair bonus from the streak-multiplier bonus.
  /// Used by the victory screen to animate each bonus wave separately.
  BonusBreakdown calculateStreakBonusDetailed({
    required int streak,
    required bool bothSlotsDone,
  }) {
    final dailyBonus = bothSlotsDone ? 1 : 0;
    int streakMultiplierBonus = 0;
    if (streak >= 7) {
      streakMultiplierBonus = 2;
    } else if (streak >= 3) {
      streakMultiplierBonus = 1;
    }
    return BonusBreakdown(
      dailyBonus: dailyBonus,
      streakMultiplierBonus: streakMultiplierBonus,
    );
  }

  Future<BrushOutcome> recordBrush({
    String heroId = 'blaze',
    String worldId = 'candy_crater',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayString();
    final now = DateTime.now();
    final lastDate = prefs.getString(_keyLastBrushDate) ?? '';
    final slot = _slotForHour(now.hour);
    final slotKey = slot == BrushSlot.morning
        ? _keyMorningDoneDate
        : _keyEveningDoneDate;
    final slotAlreadyDone = prefs.getString(slotKey) == today;
    final newSlotCompleted = !slotAlreadyDone;

    // Every completed brush earns 2 stars — no daily cap.
    const starsEarned = 2;
    if (newSlotCompleted) {
      await prefs.setString(slotKey, today);
    }
    // Track total brushes done today (not capped to slots)
    final storedDate = prefs.getString(_keyTodayDate) ?? '';
    int todayCount = storedDate == today
        ? (prefs.getInt(_keyTodayBrushCount) ?? 0)
        : 0;
    todayCount++;
    await prefs.setInt(_keyTodayBrushCount, todayCount);
    await prefs.setString(_keyTodayDate, today);

    // Update streak (once per day, on first brush of the day)
    int streak = prefs.getInt(_keyCurrentStreak) ?? 0;
    int comebackBonus = 0;
    if (lastDate != today) {
      if (lastDate == _yesterdayString() || lastDate == _twoDaysAgoString()) {
        streak++;
      } else if (lastDate.isEmpty) {
        streak = 1;
      } else {
        // Check if streak is paused before breaking it
        final pauseEnd = prefs.getString(_keyStreakPauseUntil);
        final isPaused =
            pauseEnd != null &&
            DateTime.now().isBefore(
              DateTime.tryParse(pauseEnd) ?? DateTime(2000),
            );
        if (isPaused) {
          streak++; // Paused — continue streak
        } else {
          streak = 1; // Streak broken (2+ days missed, not paused)
          comebackBonus = 3; // Welcome back bonus to soften restart
        }
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
    final breakdown = calculateStreakBonusDetailed(
      streak: streak,
      bothSlotsDone: updatedSlots.morningDone && updatedSlots.eveningDone,
    );
    final streakBonus = breakdown.total;
    final totalEarned = starsEarned + streakBonus + comebackBonus;

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
      time:
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
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
        unawaited(SyncService().uploadProgress().catchError((_) {}));
      }
    } on Exception catch (_) {
      // Firebase may be unavailable in unit tests; local progress still persists.
    }

    return BrushOutcome(
      baseStars: starsEarned,
      streakBonus: streakBonus,
      comebackBonus: comebackBonus,
      starsEarned: totalEarned,
      slot: slot,
      newSlotCompleted: newSlotCompleted,
      breakdown: breakdown,
    );
  }

  Future<int> getStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDate = prefs.getString(_keyLastBrushDate) ?? '';
    final today = _todayString();
    final yesterday = _yesterdayString();
    final twoDaysAgo = _twoDaysAgoString();

    // If paused, always return the stored streak
    final pauseEnd = prefs.getString(_keyStreakPauseUntil);
    final isPaused =
        pauseEnd != null &&
        DateTime.now().isBefore(DateTime.tryParse(pauseEnd) ?? DateTime(2000));
    if (isPaused) {
      return prefs.getInt(_keyCurrentStreak) ?? 0;
    }

    if (lastDate == today || lastDate == yesterday || lastDate == twoDaysAgo) {
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

  Future<TodaySlotsStatus> getYesterdaySlots() async {
    final history = await getHistory();
    final yesterday = _yesterdayString();
    bool hadMorning = false;
    bool hadEvening = false;
    for (final record in history) {
      if (record.date == yesterday) {
        final hour = int.parse(record.time.split(':')[0]);
        if (hour < 12) {
          hadMorning = true;
        } else {
          hadEvening = true;
        }
        if (hadMorning && hadEvening) break;
      }
    }
    return TodaySlotsStatus(morningDone: hadMorning, eveningDone: hadEvening);
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
        .map(
          (json) =>
              BrushRecord.fromJson(jsonDecode(json) as Map<String, dynamic>),
        )
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

  String _twoDaysAgoString() {
    final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
    return '${twoDaysAgo.year}-${twoDaysAgo.month.toString().padLeft(2, '0')}-${twoDaysAgo.day.toString().padLeft(2, '0')}';
  }

  BrushSlot _slotForHour(int hour) {
    return hour < 12 ? BrushSlot.morning : BrushSlot.evening;
  }

  Future<void> setStreakPause(DateTime until) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStreakPauseUntil, until.toIso8601String());
  }

  Future<void> clearStreakPause() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyStreakPauseUntil);
  }

  Future<bool> isStreakPaused() async {
    final prefs = await SharedPreferences.getInstance();
    final pauseUntil = prefs.getString(_keyStreakPauseUntil);
    if (pauseUntil == null) return false;
    final until = DateTime.tryParse(pauseUntil);
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  Future<DateTime?> getStreakPauseEnd() async {
    final prefs = await SharedPreferences.getInstance();
    final pauseUntil = prefs.getString(_keyStreakPauseUntil);
    if (pauseUntil == null) return null;
    return DateTime.tryParse(pauseUntil);
  }

  /// Claim a daily streak bonus (once per calendar day, on app open).
  /// Returns the bonus amount awarded (0 if already claimed or no streak).
  /// 3+ day streak: +1 star. 7+ day streak: +2 stars.
  Future<int> claimDailyBonus() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayString();
    final lastBonusDate = prefs.getString(_keyLastDailyBonusDate) ?? '';

    if (lastBonusDate == today) return 0; // Already claimed today

    final streak = await getStreak();
    int bonusAmount = 0;
    if (streak >= 7) {
      bonusAmount = 2;
    } else if (streak >= 3) {
      bonusAmount = 1;
    }

    if (bonusAmount > 0) {
      await addBonusStars(bonusAmount);
      await prefs.setString(_keyLastDailyBonusDate, today);
    }

    return bonusAmount;
  }

  // ── First-time celebration flags ────────────────────────────────────────────

  Future<bool> hasSeenFirstStreak3() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHasSeenFirstStreak3) ?? false;
  }

  Future<void> markFirstStreak3Seen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasSeenFirstStreak3, true);
  }

  Future<bool> hasSeenFirstStreak7() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHasSeenFirstStreak7) ?? false;
  }

  Future<void> markFirstStreak7Seen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasSeenFirstStreak7, true);
  }

  Future<bool> hasSeenFirstDailyPair() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHasSeenFirstDailyPair) ?? false;
  }

  Future<void> markFirstDailyPairSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasSeenFirstDailyPair, true);
  }

  Future<bool> hasSeenFirstComeback() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHasSeenFirstComeback) ?? false;
  }

  Future<void> markFirstComebackSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasSeenFirstComeback, true);
  }

  /// Migrate from v1 (cumulative) to v2 (wallet) economy.
  /// Credits existing total_stars to star_wallet if wallet key doesn't exist.
  /// Run once on app startup.
  ///
  /// DESIGN DECISION: Existing users keep ALL previously-unlocked heroes/weapons
  /// AND get their full star total credited to the wallet. This is intentional:
  /// Oliver arrives feeling RICHER — he walks into the new shop with spendable
  /// stars and can buy things immediately.
  static Future<void> migrateToWalletEconomy() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('star_wallet')) return; // Already migrated
    final totalStars = prefs.getInt('total_stars') ?? 0;
    await prefs.setInt('star_wallet', totalStars);
  }
}
