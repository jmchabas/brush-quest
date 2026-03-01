import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:brush_quest/services/streak_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StreakService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('first brush grants one star and one daily slot', () async {
      final service = StreakService();
      final outcome = await service.recordBrush();
      final stars = await service.getTotalStars();
      final todayCount = await service.getTodayBrushCount();

      expect(outcome.starsEarned, 1);
      expect(stars, 1);
      expect(todayCount, 1);
    });

    test('second brush same slot grants no additional base stars', () async {
      final service = StreakService();
      await service.recordBrush();
      final second = await service.recordBrush();
      final stars = await service.getTotalStars();

      expect(second.starsEarned, 0);
      expect(stars, 1);
    });
  });
}
