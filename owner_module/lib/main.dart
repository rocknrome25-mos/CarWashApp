import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/api/api_client.dart';
import 'core/cache/memory_cache.dart';
import 'core/data/api_repository.dart';
import 'core/data/app_repository.dart';
import 'core/theme/app_theme.dart' as theme;
import 'features/auth/owner_login_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _Root());
}

class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  bool _authed = true;
  AppRepository? repo;
  String? _startupError;

  String _resolveBaseUrl() {
    const defined = String.fromEnvironment('BASE_URL', defaultValue: '');
    if (defined.trim().isNotEmpty) {
      return defined.trim();
    }

    if (kIsWeb) {
      return 'http://localhost:3000';
    }

    if (Platform.isAndroid) {
      return 'http://95.174.95.1:3000';
    }

    return 'http://95.174.95.1:3000';
  }

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  void _initApp() {
    try {
      final baseUrl = _resolveBaseUrl();

      repo = ApiRepository(
        api: ApiClient(baseUrl: baseUrl),
        cache: MemoryCache(),
      );
    } catch (e, st) {
      debugPrint('APP START ERROR: $e');
      debugPrintStack(stackTrace: st);
      setState(() {
        _startupError = e.toString();
      });
    }
  }

  @override
  void dispose() {
    repo?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = repo;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme.AppTheme.dark(),
      home: _startupError != null
          ? _StartupErrorPage(error: _startupError!)
          : repository == null
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _authed
          ? OwnerModuleApp(
              repo: repository,
              onLogout: () => setState(() => _authed = false),
            )
          : OwnerLoginPage(
              repo: repository,
              onSuccess: () => setState(() => _authed = true),
            ),
    );
  }
}

class _StartupErrorPage extends StatelessWidget {
  final String error;

  const _StartupErrorPage({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ошибка запуска')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SelectableText('Приложение не смогло запуститься.\n\n$error'),
      ),
    );
  }
}
