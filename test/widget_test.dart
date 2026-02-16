import 'package:flutter_test/flutter_test.dart';
import 'package:brush_quest/main.dart';

void main() {
  testWidgets('App starts without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const BrushQuestApp());
    expect(find.text('BRUSH QUEST'), findsOneWidget);
  });
}
