import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:washer_module/main.dart';
import 'package:washer_module/core/api/washer_api_client.dart';
import 'package:washer_module/core/storage/washer_session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App boots into Login when no session', (
    WidgetTester tester,
  ) async {
    // SharedPreferences mock (no saved session)
    SharedPreferences.setMockInitialValues({});

    final store = WasherSessionStore();
    await store.load();

    final api = WasherApiClient(baseUrl: 'http://localhost:3000', store: store);

    await tester.pumpWidget(MyApp(api: api, store: store));
    await tester.pumpAndSettle();

    // LoginPage AppBar title
    expect(find.text('Вход мойщика'), findsOneWidget);
  });
}
