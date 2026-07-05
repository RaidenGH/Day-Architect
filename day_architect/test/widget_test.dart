import 'package:flutter_test/flutter_test.dart';

import 'package:day_architect/main.dart';

void main() {
  testWidgets('App builds successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const DayArchitectApp());
    // Verify the app renders without crashing
    expect(find.text('Day Architect'), findsOneWidget);
  });
}
