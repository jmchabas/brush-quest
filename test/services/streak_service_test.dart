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
      if (hour < 15) {
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
      if (hour < 15) {
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
