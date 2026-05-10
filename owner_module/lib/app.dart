import 'package:flutter/material.dart';
import 'core/data/app_repository.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/owner_shell_page.dart';

class OwnerModuleApp extends StatefulWidget {
  final AppRepository repo;
  final VoidCallback onLogout;

  const OwnerModuleApp({super.key, required this.repo, required this.onLogout});

  @override
  State<OwnerModuleApp> createState() => _OwnerModuleAppState();
}

class _OwnerModuleAppState extends State<OwnerModuleApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Автомойка - Владелец',
      theme: AppTheme.dark(),
      home: OwnerShellPage(repo: widget.repo, onLogout: widget.onLogout),
    );
  }
}
