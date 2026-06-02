import 'package:flutter_test/flutter_test.dart';

import 'package:smart_campus_guide/main.dart';

void main() {
  testWidgets('App renders login page', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartCampusApp());
    await tester.pumpAndSettle();

    expect(find.text('SWU Guide'), findsOneWidget);
    expect(find.text('西大智慧校园导览'), findsOneWidget);
    expect(find.text('登 录'), findsOneWidget);
  });
}
