import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brush_quest/widgets/sun_moon_tracker.dart';

void main() {
  testWidgets('shows two empty slots when neither session done', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SunMoonTracker(morningDone: false, eveningDone: false)),
    ));
    expect(find.byIcon(Icons.wb_sunny), findsOneWidget);
    expect(find.byIcon(Icons.nightlight_round), findsOneWidget);
  });

  testWidgets('sun fills when morning done', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SunMoonTracker(morningDone: true, eveningDone: false)),
    ));
    // Bonus star should be visible (pulsing between sun and moon)
    expect(find.byIcon(Icons.star), findsOneWidget);
  });

  testWidgets('both filled shows completed state', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SunMoonTracker(morningDone: true, eveningDone: true)),
    ));
    expect(find.byIcon(Icons.wb_sunny), findsOneWidget);
    expect(find.byIcon(Icons.nightlight_round), findsOneWidget);
  });
}
