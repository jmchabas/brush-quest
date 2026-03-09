import 'package:brush_quest/screens/home_screen.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  String todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> pumpHomeScreen(WidgetTester tester) async {
    final today = todayString();
    SharedPreferences.setMockInitialValues({
      'selected_hero': 'frost',
      'selected_weapon': 'star_blaster',
      'total_stars': 12,
      'current_streak': 3,
      'last_brush_date': today,
      'morning_done_date': today,
      'total_brushes': 1,
      'muted': false,
    });

    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets(
    'home stats row uses new icon and settings stays in secondary nav',
    (tester) async {
      await pumpHomeScreen(tester);

      expect(find.byIcon(Icons.sanitizer_rounded), findsOneWidget);
      expect(find.byIcon(Icons.brush), findsNothing);

      final streakText = tester.widget<Text>(find.text('3'));
      final starsText = tester.widget<Text>(find.text('12'));
      final todayText = tester.widget<Text>(find.text('1/2'));
      expect(streakText.style?.fontSize, 24);
      expect(starsText.style?.fontSize, 24);
      expect(todayText.style?.fontSize, 24);

      expect(find.text('SETTINGS'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byIcon(Icons.settings),
          matching: find.byType(IconButton),
        ),
        findsNothing,
      );
      expect(find.byIcon(Icons.volume_up), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    },
  );
}
