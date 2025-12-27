import 'package:flutter_test/flutter_test.dart';
import 'package:client_module/app.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    await tester.pumpWidget(const ClientModuleApp());
    expect(find.text('Автомойка'), findsOneWidget);
  });
}
