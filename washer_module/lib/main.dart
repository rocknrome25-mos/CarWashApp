import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/api/washer_api_client.dart';
import 'core/storage/washer_session_store.dart';
import 'features/shell/shell_page.dart';
import 'features/login/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru');
  await initializeDateFormatting('ru_RU');

  final store = WasherSessionStore();
  await store.load();

  const baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://95.174.95.1:3000',
  );

  final api = WasherApiClient(baseUrl: baseUrl, store: store);

  runApp(MyApp(api: api, store: store));
}

class MyApp extends StatelessWidget {
  final WasherApiClient api;
  final WasherSessionStore store;

  const MyApp({super.key, required this.api, required this.store});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Мойщик',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2D9CDB),
      ),
      home: store.userId == null
          ? LoginPage(api: api, store: store)
          : ShellPage(api: api, store: store),
    );
  }
}
