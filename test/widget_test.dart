
import 'package:flutter_test/flutter_test.dart';
import 'package:adelaide_register/main.dart';

void main() {
  testWidgets('ClearPass register opens successfully', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ClearPassApp());

    expect(find.text('ClearPass'), findsOneWidget);
    expect(find.text('Visitor sign-in'), findsOneWidget);
  });
}
