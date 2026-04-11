import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/owner_login_page.dart';

class OwnerApp extends StatelessWidget {
  const OwnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Owner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const OwnerLoginPage(),
    );
  }
}