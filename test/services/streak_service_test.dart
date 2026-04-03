import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:brush_quest/services/streak_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StreakService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    // ── Star earning ──────────────────────────────────────────────

    test('first brush grants two stars and one daily slot', () async {
      final service = StreakService();
      final outcome = await service.recordBrush();
      final stars = await service.getTotalStars();
      final todayCount = await service.getTodayBrushCount();

      expect(outcome.starsEarned, 2);
      expect(stars, 2);
      expect(todayCount, 1);
    });

    test('second brush same slot still grants stars (no daily cap)', () async {
      final service = StreakService();
      await service.recordBrush();
      final second = await service.recordBrush();
      final stars = await service.getTotalStars();

      expect(second.starsEarned, 2);
      expect(stars, 4);
    });

    test('multiple brushes all give 2 stars each', () async {
      final service = StreakService();
      for (int i = 0; i < 5; i++) {
        final outcome = await service.recordBrush();
        expect(outcome.starsEarned, 2);
      }
      final stars = await service.getTotalStars();
      expect(stars, 10);
    });

    // ── Today brush count ─────────────────────────────────────────

    test('getTodayBrushCount returns correct count after multiple brushes', () async {
      final service = StreakService();
      await service.recordBrush();
      await service.recordBrush();
      await service.recordBrush();
      final count = await service.getTodayBrushCount();
      expect(count, 3);
    });

    test('getTodayBrushCount returns 0 when no brushes recorded', () async {
      final service = StreakService();
      final count = await service.getTodayBrushCount();
      expect(count, 0);
    });

    test('getTodayBrushCount returns 0 when stored date differs from today', () async {
      // Pre-seed with a different date
      SharedPreferences.setMockInitialValues({
        'today_date': '1999-01-01',
        'today_brush_count': 5,
      });
      final service = StreakService();
      final count = await service.getTodayBrushCount();
      expect(count, 0);
    });

    // ── Total stars accumulation ──────────────────────────────────

    test('getTotalStars returns 0 when no brushes recorded', () async {
      final service = StreakService();
      final stars = await service.getTotalStars();
      expect(stars, 0);
    });

    test('getTotalStars accumulates correctly over many brushes', () async {
      final service = StreakService();
      for (int i = 0; i < 10; i++) {
        await service.recordBrush();
      }
      final stars = await service.getTotalStars();
      expect(stars, 20);
    });

    // ── Bonus stars ───────────────────────────────────────────────

    test('addBonusStars adds to existing balance', () async {
      SharedPreferences.setMockInitialValues({'total_stars': 5});
      final service = StreakService();
      await service.addBonusStars(3);
      final stars = await service.getTotalStars();
      expect(stars, 8);
    });

    test('addBonusStars with 0 or negative amount does nothing', () async {
      SharedPreferences.setMockInitialValues({'total_stars': 5});
      final service = StreakService();
      await service.addBonusStars(0);
      expect(await service.getTotalStars(), 5);
      await service.addBonusStars(-3);
      expect(await service.getTotalStars(), 5);
    });

    // ── Streak tracking ───────────────────────────────────────────

    test('first ever brush starts streak at 1', () async {
      final service = StreakService();
      await service.recordBrush();
      final streak = await service.getStreak();
      expect(streak, 1);
    });

    test('brushing twice same day does not double-count streak', () async {
      final service = StreakService();
      await service.recordBrush();
      await service.recordBrush();
      final streak = await service.getStreak();
      expect(streak, 1);
    });

    test('streak resets when last_brush_date is not yesterday or today', () async {
      // Simulate brushing 3 days ago (streak should be broken)
      final now = DateTime.now();
      final threeDaysAgo = now.subtract(const Duration(days: 3));
      final oldDate =
          '${threeDaysAgo.year}-${threeDaysAgo.month.toString().padLeft(2, '0')}-${threeDaysAgo.day.toString().padLeft(2, '0')}';

      SharedPreferences.setMockInitialValues({
        'last_brush_date': oldDate,
        'current_streak': 10,
      });

      final service = StreakService();
      await service.recordBrush();
      final streak = await service.getStreak();
      expect(streak, 1); // Reset to 1 (today counts)
    });

    test('streak continues when last_brush_date is yesterday', () async {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayStr =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

      SharedPreferences.setMockInitialValues({
        'last_brush_date': yesterdayStr,
        'current_streak': 5,
      });

      final service = StreakService();
      await service.recordBrush();
      final streak = await service.getStreak();
      expect(streak, 6);
    });

    test('streak continues when last brush was 2 days ago (grace period)', () async {
      final now = DateTime.now();
      final twoDaysAgo = now.subtract(const Duration(days: 2));
      final twoDaysAgoStr =
          '${twoDaysAgo.year}-${twoDaysAgo.month.toString().padLeft(2, '0')}-${twoDaysAgo.day.toString().padLeft(2, '0')}';

      SharedPreferences.setMockInitialValues({
        'last_brush_date': twoDaysAgoStr,
        'current_streak': 5,
      });

      final service = StreakService();
      await service.recordBrush();
      final streak = await service.getStreak();
      expect(streak, 6); // Grace period: streak continues
    });

    test('streak breaks when last brush was 3+ days ago (no pause)', () async {
      final now = DateTime.now();
      final threeDaysAgo = now.subtract(const Duration(days: 3));
      final threeDaysAgoStr =
          '${threeDaysAgo.year}-${threeDaysAgo.month.toString().padLeft(2, '0')}-${threeDaysAgo.day.toString().padLeft(2, '0')}';

      SharedPreferences.setMockInitialValues({
        'last_brush_date': threeDaysAgoStr,
        'current_streak': 8,
      });

      final service = StreakService();
      await service.recordBrush();
      final streak = await service.getStreak();
      expect(streak, 1); // No grace period: streak broken
    });

    test('getStreak returns streak when last brush was 2 days ago', () async {
      final now = DateTime.now();
      final twoDaysAgo = now.subtract(const Duration(days: 2));
      final twoDaysAgoStr =
          '${twoDaysAgo.year}-${twoDaysAgo.month.toString().padLeft(2, '0')}-${twoDaysAgo.day.toString().padLeft(2, '0')}';

      SharedPreferences.setMockInitialValues({
        'last_brush_date': twoDaysAgoStr,
        'current_streak': 4,
      });

      final service = StreakService();
      final streak = await service.getStreak();
      expect(streak, 4); // Grace period: streak still valid
    });

    test('getStreak returns 0 when last brush was 3+ days ago', () async {
      final now = DateTime.now();
      final threeDaysAgo = now.subtract(const Duration(days: 3));
      final threeDaysAgoStr =
          '${threeDaysAgo.year}-${threeDaysAgo.month.toString().padLeft(2, '0')}-${threeDaysAgo.day.toString().padLeft(2, '0')}';

      SharedPreferences.setMockInitialValues({
        'last_brush_date': threeDaysAgoStr,
        'current_streak': 4,
      });

      final service = StreakService();
      final streak = await service.getStreak();
      expect(streak, 0); // Beyond grace period: streak shows 0
    });

    test('streak continues during pause even after 3+ days', () async {
      final now = DateTime.now();
      final fiveDaysAgo = now.subtract(const Duration(days: 5));
      final fiveDaysAgoStr =
          '${fiveDaysAgo.year}-${fiveDaysAgo.month.toString().padLeft(2, '0')}-${fiveDaysAgo.day.toString().padLeft(2, '0')}';
      final pauseUntil = now.add(const Duration(days: 3));

      SharedPreferences.setMockInitialValues({
        'last_brush_date': fiveDaysAgoStr,
        'current_streak': 10,
        'streak_pause_until': pauseUntil.toIso8601String(),
      });

      final service = StreakService();

      // getStreak should return the stored streak while paused
      final readStreak = await service.getStreak();
      expect(readStreak, 10);

      // recordBrush should continue the streak (not reset)
      await service.recordBrush();
      final streak = await service.getStreak();
      expect(streak, 11); // Paused: streak continues
    });

    test('getStreak returns 0 when last brush date is stale (more than yesterday)', () async {
      final now = DateTime.now();
      final longAgo = now.subtract(const Duration(days: 10));
      final longAgoStr =
          '${longAgo.year}-${longAgo.month.toString().padLeft(2, '0')}-${longAgo.day.toString().padLeft(2, '0')}';

      SharedPreferences.setMockInitialValues({
        'last_brush_date': longAgoStr,
        'current_streak': 7,
      });

      final service = StreakService();
      // Don't record a new brush -- just check the read path
      final streak = await service.getStreak();
      expect(streak, 0);
    });

    test('getStreak returns stored value when last brush is today', () async {
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      SharedPreferences.setMockInitialValues({
        'last_brush_date': todayStr,
        'current_streak': 4,
      });

      final service = StreakService();
      final streak = await service.getStreak();
      expect(streak, 4);
    });

    // ── Parent pause helpers ────────────────────────────────────────

    test('isStreakPaused returns false when no pause set', () async {
      final service = StreakService();
      expect(await service.isStreakPaused(), false);
    });

    test('isStreakPaused returns true when pause is in the future', () async {
      final service = StreakService();
      await service.setStreakPause(DateTime.now().add(const Duration(days: 2)));
      expect(await service.isStreakPaused(), true);
    });

    test('isStreakPaused returns false when pause is in the past', () async {
      SharedPreferences.setMockInitialValues({
        'streak_pause_until': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      });
      final service = StreakService();
      expect(await service.isStreakPaused(), false);
    });

    test('clearStreakPause removes the pause', () async {
      final service = StreakService();
      await service.setStreakPause(DateTime.now().add(const Duration(days: 2)));
      expect(await service.isStreakPaused(), true);
      await service.clearStreakPause();
      expect(await service.isStreakPaused(), false);
    });

    test('getStreakPauseEnd returns null when no pause set', () async {
      final service = StreakService();
      expect(await service.getStreakPauseEnd(), isNull);
    });

    test('getStreakPauseEnd returns the stored date', () async {
      final service = StreakService();
      final until = DateTime.now().add(const Duration(days: 3));
      await service.setStreakPause(until);
      final result = await service.getStreakPauseEnd();
      expect(result, isNotNull);
      // Compare to nearest second to avoid microsecond differences
      expect(result!.difference(until).inSeconds.abs(), lessThan(1));
    });

    // ── Best streak ───────────────────────────────────────────────

    test('best streak is updated when current streak exceeds it', () async {
      final service = StreakService();
      await service.recordBrush();
      final best = await service.getBestStreak();
      expect(best, 1);
    });

    test('best streak is not lowered when streak resets', () async {
      // Set up a high best streak but stale last brush date
      final now = DateTime.now();
      final longAgo = now.subtract(const Duration(days: 5));
      final longAgoStr =
          '${longAgo.year}-${longAgo.month.toString().padLeft(2, '0')}-${longAgo.day.toString().padLeft(2, '0')}';

      SharedPreferences.setMockInitialValues({
        'last_brush_date': longAgoStr,
        'current_streak': 20,
        'best_streak': 20,
      });

      final service = StreakService();
      await service.recordBrush(); // streak resets to 1
      final best = await service.getBestStreak();
      expect(best, 20); // best streak preserved
    });

    // ── Total brushes ─────────────────────────────────────────────

    test('getTotalBrushes increments correctly', () async {
      final service = StreakService();
      await service.recordBrush();
      await service.recordBrush();
      await service.recordBrush();
      final total = await service.getTotalBrushes();
      expect(total, 3);
    });

    // ── History ───────────────────────────────────────────────────

    test('getHistory returns empty list when no brushes', () async {
      final service = StreakService();
      final history = await service.getHistory();
      expect(history, isEmpty);
    });

    test('getHistory returns brush records in reverse chronological order', () async {
      final service = StreakService();
      await service.recordBrush(heroId: 'blaze', worldId: 'candy_crater');
      await service.recordBrush(heroId: 'frost', worldId: 'slime_swamp');
      final history = await service.getHistory();
      expect(history.length, 2);
      // Most recent first
      expect(history[0].heroId, 'frost');
      expect(history[0].worldId, 'slime_swamp');
      expect(history[1].heroId, 'blaze');
      expect(history[1].worldId, 'candy_crater');
    });

    test('getHistory records contain date and time', () async {
      final service = StreakService();
      await service.recordBrush();
      final history = await service.getHistory();
      expect(history.length, 1);
      expect(history[0].date, isNotEmpty);
      expect(history[0].time, isNotEmpty);
      // date should be YYYY-MM-DD format
      expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(history[0].date), true);
      // time should be HH:MM format
      expect(RegExp(r'^\d{2}:\d{2}$').hasMatch(history[0].time), true);
    });

    test('history is capped at 100 entries', () async {
      final service = StreakService();
      for (int i = 0; i < 105; i++) {
        await service.recordBrush();
      }
      final history = await service.getHistory();
      expect(history.length, 100);
    });

    // ── recordBrush with custom hero/world ────────────────────────

    test('recordBrush stores custom heroId and worldId', () async {
      final service = StreakService();
      await service.recordBrush(heroId: 'nova', worldId: 'dark_dimension');
      final history = await service.getHistory();
      expect(history[0].heroId, 'nova');
      expect(history[0].worldId, 'dark_dimension');
    });

    // ── BrushOutcome slot detection ───────────────────────────────

    test('BrushOutcome reports correct slot type', () async {
      final service = StreakService();
      final outcome = await service.recordBrush();
      final hour = DateTime.now().hour;
      if (hour < 12) {
        expect(outcome.slot, BrushSlot.morning);
      } else {
        expect(outcome.slot, BrushSlot.evening);
      }
    });

    test('first brush of a slot marks newSlotCompleted true', () async {
      final service = StreakService();
      final outcome = await service.recordBrush();
      expect(outcome.newSlotCompleted, true);
    });

    test('subsequent brush of same slot marks newSlotCompleted false', () async {
      final service = StreakService();
      await service.recordBrush();
      final second = await service.recordBrush();
      expect(second.newSlotCompleted, false);
    });

    // ── TodaySlotsStatus ──────────────────────────────────────────

    test('getTodaySlots returns both false when no brushes', () async {
      final service = StreakService();
      final slots = await service.getTodaySlots();
      expect(slots.morningDone, false);
      expect(slots.eveningDone, false);
      expect(slots.completedCount, 0);
    });

    test('getTodaySlots marks current slot after a brush', () async {
      final service = StreakService();
      await service.recordBrush();
      final slots = await service.getTodaySlots();
      final hour = DateTime.now().hour;
      if (hour < 12) {
        expect(slots.morningDone, true);
      } else {
        expect(slots.eveningDone, true);
      }
    });

    // ── BrushRecord JSON round-trip ───────────────────────────────

    test('BrushRecord serialises and deserialises correctly', () {
      final record = BrushRecord(
        date: '2026-03-14',
        time: '08:30',
        heroId: 'bolt',
        worldId: 'sugar_volcano',
      );
      final json = record.toJson();
      final restored = BrushRecord.fromJson(json);
      expect(restored.date, '2026-03-14');
      expect(restored.time, '08:30');
      expect(restored.heroId, 'bolt');
      expect(restored.worldId, 'sugar_volcano');
    });

    test('BrushRecord.fromJson uses defaults for missing heroId/worldId', () {
      final json = {'date': '2026-01-01', 'time': '09:00'};
      final record = BrushRecord.fromJson(json);
      expect(record.heroId, 'blaze');
      expect(record.worldId, 'candy_crater');
    });
  });

  group('Wallet and Ranger Rank', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('recordBrush credits both wallet and ranger rank', () async {
      final service = StreakService();
      await service.recordBrush();

      expect(await service.getWallet(), 2);
      expect(await service.getRangerRank(), 2);
    });

    test('spendStars deducts from wallet only', () async {
      final service = StreakService();
      await service.recordBrush();
      await service.recordBrush();

      final success = await service.spendStars(3);
      expect(success, true);
      expect(await service.getWallet(), 1);
      expect(await service.getRangerRank(), 4);
    });

    test('spendStars fails when insufficient balance', () async {
      final service = StreakService();
      await service.recordBrush();

      final success = await service.spendStars(5);
      expect(success, false);
      expect(await service.getWallet(), 2);
    });

    test('spendStars rejects zero and negative amounts', () async {
      final service = StreakService();
      await service.recordBrush();

      expect(await service.spendStars(0), false);
      expect(await service.spendStars(-1), false);
    });

    test('addBonusStars credits both wallet and rank', () async {
      final service = StreakService();
      await service.addBonusStars(5);

      expect(await service.getWallet(), 5);
      expect(await service.getRangerRank(), 5);
    });

    test('getTotalStars still works as alias for ranger rank', () async {
      final service = StreakService();
      await service.recordBrush();

      expect(await service.getTotalStars(), await service.getRangerRank());
    });
  });

  group('Comeback bonus', () {
    test('comeback bonus awards +3 stars when streak breaks', () async {
      // Simulate a streak that broke (last brush was 5 days ago)
      final fiveDaysAgo = DateTime.now().subtract(const Duration(days: 5));
      final fiveDaysAgoStr =
          '${fiveDaysAgo.year}-${fiveDaysAgo.month.toString().padLeft(2, '0')}-${fiveDaysAgo.day.toString().padLeft(2, '0')}';

      SharedPreferences.setMockInitialValues({
        'last_brush_date': fiveDaysAgoStr,
        'current_streak': 10,
        'total_stars': 50,
        'star_wallet': 20,
      });
      final service = StreakService();
      final outcome = await service.recordBrush();
      // Base 2 + comeback 3 = 5 (no streak bonus since streak reset to 1)
      expect(outcome.comebackBonus, 3);
      expect(outcome.starsEarned, 5);
      expect(await service.getWallet(), 25); // 20 + 5
    });

    test('no comeback bonus when streak continues', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayStr =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

      SharedPreferences.setMockInitialValues({
        'last_brush_date': yesterdayStr,
        'current_streak': 5,
        'total_stars': 50,
        'star_wallet': 20,
      });
      final service = StreakService();
      final outcome = await service.recordBrush();
      expect(outcome.comebackBonus, 0);
    });

    test('no comeback bonus on very first brush', () async {
      SharedPreferences.setMockInitialValues({});
      final service = StreakService();
      final outcome = await service.recordBrush();
      expect(outcome.comebackBonus, 0);
      expect(outcome.starsEarned, 2); // Just base stars
    });

    test('comeback bonus only awarded on first brush of the day', () async {
      final fiveDaysAgo = DateTime.now().subtract(const Duration(days: 5));
      final fiveDaysAgoStr =
          '${fiveDaysAgo.year}-${fiveDaysAgo.month.toString().padLeft(2, '0')}-${fiveDaysAgo.day.toString().padLeft(2, '0')}';

      SharedPreferences.setMockInitialValues({
        'last_brush_date': fiveDaysAgoStr,
        'current_streak': 8,
        'total_stars': 50,
        'star_wallet': 20,
      });
      final service = StreakService();
      final first = await service.recordBrush();
      final second = await service.recordBrush();
      expect(first.comebackBonus, 3);
      expect(second.comebackBonus, 0);
    });
  });

  group('Daily streak bonus', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('claimDailyBonus returns 0 when no streak', () async {
      final service = StreakService();
      final bonus = await service.claimDailyBonus();
      expect(bonus, 0);
    });

    test('claimDailyBonus returns 1 for 3+ day streak', () async {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayStr =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

      SharedPreferences.setMockInitialValues({
        'last_brush_date': yesterdayStr,
        'current_streak': 4,
        'total_stars': 10,
        'star_wallet': 10,
      });
      final service = StreakService();
      final bonus = await service.claimDailyBonus();
      expect(bonus, 1);
      expect(await service.getWallet(), 11);
      expect(await service.getRangerRank(), 11);
    });

    test('claimDailyBonus returns 2 for 7+ day streak', () async {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayStr =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

      SharedPreferences.setMockInitialValues({
        'last_brush_date': yesterdayStr,
        'current_streak': 10,
        'total_stars': 20,
        'star_wallet': 20,
      });
      final service = StreakService();
      final bonus = await service.claimDailyBonus();
      expect(bonus, 2);
      expect(await service.getWallet(), 22);
    });

    test('claimDailyBonus only awards once per day', () async {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayStr =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

      SharedPreferences.setMockInitialValues({
        'last_brush_date': yesterdayStr,
        'current_streak': 5,
        'total_stars': 10,
        'star_wallet': 10,
      });
      final service = StreakService();
      final first = await service.claimDailyBonus();
      final second = await service.claimDailyBonus();
      expect(first, 1);
      expect(second, 0);
      expect(await service.getWallet(), 11); // Not 12
    });

    test('claimDailyBonus returns 0 for streak < 3', () async {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayStr =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

      SharedPreferences.setMockInitialValues({
        'last_brush_date': yesterdayStr,
        'current_streak': 2,
        'total_stars': 10,
        'star_wallet': 10,
      });
      final service = StreakService();
      final bonus = await service.claimDailyBonus();
      expect(bonus, 0);
      expect(await service.getWallet(), 10); // Unchanged
    });
  });

  group('Migration', () {
    test('migrateToWalletEconomy copies total_stars to star_wallet', () async {
      SharedPreferences.setMockInitialValues({'total_stars': 42});
      await StreakService.migrateToWalletEconomy();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('star_wallet'), 42);
    });

    test('migrateToWalletEconomy is idempotent', () async {
      SharedPreferences.setMockInitialValues({'total_stars': 42, 'star_wallet': 10});
      await StreakService.migrateToWalletEconomy();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('star_wallet'), 10); // NOT overwritten
    });

    test('migrateToWalletEconomy handles zero stars', () async {
      SharedPreferences.setMockInitialValues({});
      await StreakService.migrateToWalletEconomy();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('star_wallet'), 0);
    });
  });

  group('First-time celebration flags', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    // ── Default values ────────────────────────────────────────────

    test('hasSeenFirstStreak3 defaults to false', () async {
      final service = StreakService();
      expect(await service.hasSeenFirstStreak3(), false);
    });

    test('hasSeenFirstStreak7 defaults to false', () async {
      final service = StreakService();
      expect(await service.hasSeenFirstStreak7(), false);
    });

    test('hasSeenFirstDailyPair defaults to false', () async {
      final service = StreakService();
      expect(await service.hasSeenFirstDailyPair(), false);
    });

    test('hasSeenFirstComeback defaults to false', () async {
      final service = StreakService();
      expect(await service.hasSeenFirstComeback(), false);
    });

    // ── Setters flip to true ──────────────────────────────────────

    test('markFirstStreak3Seen sets flag to true', () async {
      final service = StreakService();
      await service.markFirstStreak3Seen();
      expect(await service.hasSeenFirstStreak3(), true);
    });

    test('markFirstStreak7Seen sets flag to true', () async {
      final service = StreakService();
      await service.markFirstStreak7Seen();
      expect(await service.hasSeenFirstStreak7(), true);
    });

    test('markFirstDailyPairSeen sets flag to true', () async {
      final service = StreakService();
      await service.markFirstDailyPairSeen();
      expect(await service.hasSeenFirstDailyPair(), true);
    });

    test('markFirstComebackSeen sets flag to true', () async {
      final service = StreakService();
      await service.markFirstComebackSeen();
      expect(await service.hasSeenFirstComeback(), true);
    });

  });

  group('BonusBreakdown', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('BrushOutcome exposes dailyBonus separately from streakMultiplierBonus', () {
      final service = StreakService();
      final bonus = service.calculateStreakBonusDetailed(streak: 5, bothSlotsDone: true);
      expect(bonus.dailyBonus, 1);
      expect(bonus.streakMultiplierBonus, 1);
      expect(bonus.total, 2);
    });

    test('7-day streak gives streakMultiplierBonus of 2', () {
      final service = StreakService();
      final bonus = service.calculateStreakBonusDetailed(streak: 7, bothSlotsDone: false);
      expect(bonus.dailyBonus, 0);
      expect(bonus.streakMultiplierBonus, 2);
      expect(bonus.total, 2);
    });

    test('no streak and single slot gives zero bonus', () {
      final service = StreakService();
      final bonus = service.calculateStreakBonusDetailed(streak: 1, bothSlotsDone: false);
      expect(bonus.dailyBonus, 0);
      expect(bonus.streakMultiplierBonus, 0);
      expect(bonus.total, 0);
    });

    test('7-day streak with both slots gives max bonus of 3', () {
      final service = StreakService();
      final bonus = service.calculateStreakBonusDetailed(streak: 7, bothSlotsDone: true);
      expect(bonus.dailyBonus, 1);
      expect(bonus.streakMultiplierBonus, 2);
      expect(bonus.total, 3);
    });
  });

  group('Streak bonuses', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('daily completion bonus awards +1 when both slots done', () async {
      final service = StreakService();
      final bonus = service.calculateStreakBonus(streak: 1, bothSlotsDone: true);
      expect(bonus, 1);
    });

    test('streak 3+ adds +1 per brush', () async {
      final bonus = StreakService().calculateStreakBonus(streak: 3, bothSlotsDone: false);
      expect(bonus, 1);
    });

    test('streak 7+ adds +2 per brush (replaces +1)', () async {
      final bonus = StreakService().calculateStreakBonus(streak: 7, bothSlotsDone: false);
      expect(bonus, 2);
    });

    test('streak 7+ with both slots gives +3 total bonus', () async {
      final bonus = StreakService().calculateStreakBonus(streak: 7, bothSlotsDone: true);
      expect(bonus, 3);
    });

    test('streak 0-2 with one slot gives no bonus', () async {
      final bonus = StreakService().calculateStreakBonus(streak: 2, bothSlotsDone: false);
      expect(bonus, 0);
    });

    test('BrushOutcome includes baseStars and streakBonus', () async {
      final service = StreakService();
      final outcome = await service.recordBrush();
      // First brush, no streak bonus expected (streak=1, only one slot done)
      expect(outcome.baseStars, 2);
      expect(outcome.streakBonus, 0); // No streak bonus on first brush
      expect(outcome.starsEarned, 2); // base only
    });
  });
}
