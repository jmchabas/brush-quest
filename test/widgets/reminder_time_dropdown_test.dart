// test/widgets/reminder_time_dropdown_test.dart
import 'package:brush_quest/services/reminder_plan.dart';
import 'package:brush_quest/widgets/reminder_time_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<List<ReminderTime>> pumpList(
    WidgetTester tester,
    ReminderTime value, {
    bool enabled = true,
  }) async {
    final picked = <ReminderTime>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ReminderTimeDropdown(
              value: value,
              choices: eveningReminderChoices,
              onChanged: enabled ? picked.add : null,
            ),
          ),
        ),
      ),
    );
    return picked;
  }

  DropdownButton<int> dropdown(WidgetTester tester) =>
      tester.widget<DropdownButton<int>>(find.byType(DropdownButton<int>));

  testWidgets('shows the time; a pick reports the new one', (tester) async {
    final picked = await pumpList(tester, (hour: 19, minute: 30));
    expect(find.text('7:30 PM'), findsOneWidget);
    await tester.tap(find.byType(ReminderTimeDropdown));
    await tester.pumpAndSettle();
    // The open list shows the times up to the current one: pick one above.
    await tester.tap(find.text('6:45 PM').last);
    await tester.pumpAndSettle();
    expect(picked, [(hour: 18, minute: 45)]);
  });

  testWidgets('offers every quarter hour from 5 to 10 pm', (tester) async {
    await pumpList(tester, (hour: 19, minute: 30));
    expect(dropdown(tester).items, hasLength(21));
  });

  testWidgets('a saved time that is not a choice still shows, without an '
      'error', (tester) async {
    await pumpList(tester, (hour: 18, minute: 10));
    expect(find.text('6:10 PM'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(dropdown(tester).items, hasLength(22));
  });

  testWidgets('the times use the app font, not the phone default', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Fredoka'),
        home: Scaffold(
          body: Center(
            child: ReminderTimeDropdown(
              value: (hour: 19, minute: 30),
              choices: eveningReminderChoices,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    final style = DefaultTextStyle.of(tester.element(find.text('7:30 PM')));
    expect(style.style.fontFamily, 'Fredoka');
    expect(style.style.color, Colors.white);
    expect(style.style.fontSize, 16);
  });

  testWidgets('without onChanged it is greyed out', (tester) async {
    await pumpList(tester, (hour: 19, minute: 30), enabled: false);
    expect(dropdown(tester).onChanged, isNull);
  });
}
