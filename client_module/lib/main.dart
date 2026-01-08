import 'package:flutter/material.dart';
import 'app.dart';
import 'screens/login_page.dart';

void main() {
  runApp(const _Root());
}

/// Простейший прототипный "Auth Gate":
/// - пока не залогинился -> LoginPage
/// - после логина -> твой существующий ClientModuleApp (из app.dart)
class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  bool _authed = false;

  @override
  Widget build(BuildContext context) {
    if (_authed) {
      return const ClientModuleApp();
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginPage(onLoggedIn: () => setState(() => _authed = true)),
    );
  }
}
