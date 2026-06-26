import 'package:flutter_test/flutter_test.dart';
import 'package:olympus_titans/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const OlympusTitansApp());
    expect(find.byType(OlympusTitansApp), findsOneWidget);
  });
}
