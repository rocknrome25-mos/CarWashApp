import 'package:flutter/material.dart';
import 'core/api/washer_api_client.dart';
import 'core/storage/washer_session_store.dart';
import 'features/shell/shell_page.dart';
import 'features/login/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = WasherSessionStore();
  await store.load();

  // поменяешь потом на прод URL
  final api = WasherApiClient(baseUrl: 'http://localhost:3000', store: store);

  runApp(MyApp(api: api, store: store));
}

class MyApp extends StatelessWidget {
  final WasherApiClient api;
  final WasherSessionStore store;

  const MyApp({super.key, required this.api, required this.store});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Carwash Washer',
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
