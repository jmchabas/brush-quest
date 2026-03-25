import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brush_quest/widgets/star_rain.dart';

void main() {
  testWidgets('shows correct number of wave indicators for base only', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: StarRain(baseStars: 2)),
    ));
    await tester.pump();
    // Wave 1 now uses ImageIcon (toothbrush asset) instead of cleaning_services.
    expect(find.byType(ImageIcon), findsOneWidget);
    expect(find.byIcon(Icons.local_fire_department), findsNothing);
  });

  testWidgets('shows streak wave when streakBonus > 0', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: StarRain(baseStars: 2, streakBonus: 1, currentStreak: 3)),
    ));
    await tester.pump();
    expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
  });

  testWidgets('shows daily wave when dailyBonus > 0', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: StarRain(baseStars: 2, dailyBonus: 1)),
    ));
    await tester.pump();
    expect(find.byIcon(Icons.wb_twilight), findsOneWidget);
  });

  testWidgets('tap to skip jumps to grand total', (tester) async {
    bool completed = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: StarRain(
        baseStars: 2,
        streakBonus: 1,
        dailyBonus: 1,
        currentStreak: 3,
        onComplete: () => completed = true,
      )),
    ));
    await tester.pump();
    await tester.tap(find.byType(StarRain));
    await tester.pump();
    expect(completed, isTrue);
    expect(find.text('+4'), findsOneWidget);
  });
}
