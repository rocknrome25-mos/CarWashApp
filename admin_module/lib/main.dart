import 'package:flutter/material.dart';
import 'core/api/admin_api_client.dart';
import 'core/storage/session_store.dart';
import 'features/login/login_page.dart';
import 'features/shift/shift_gate_page.dart';

void main() {
  runApp(const AdminApp());
}

class AdminApp extends StatefulWidget {
  const AdminApp({super.key});

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  final api = AdminApiClient(baseUrl: 'http://localhost:3000');
  final store = SessionStore();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Carwash Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: FutureBuilder(
        future: store.load(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final session = snap.data;
          if (session == null) {
            return LoginPage(api: api, store: store);
          }
          return ShiftGatePage(api: api, store: store, session: session);
        },
      ),
    );
  }
}
