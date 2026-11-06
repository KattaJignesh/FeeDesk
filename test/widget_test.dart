import 'package:flutter_test/flutter_test.dart';
import 'package:pappa_project/main.dart';

void main() {
  testWidgets('App starts successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const FeeDeskApp());

    expect(find.text('Welcome to FeeDesk'), findsOneWidget);
  });
}