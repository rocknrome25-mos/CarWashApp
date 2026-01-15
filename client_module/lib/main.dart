import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/api/api_client.dart';
import 'core/cache/memory_cache.dart';
import 'core/data/api_repository.dart';
import 'core/data/app_repository.dart';
import 'screens/start_page.dart';

void main() {
  runApp(const _Root());
}

class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  bool _authed = false;
  late final AppRepository repo;

  String _resolveBaseUrl() {
    if (kIsWeb) return 'http://localhost:3000';
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:3000';
    return 'http://localhost:3000';
  }

  @override
  void initState() {
    super.initState();

    repo = ApiRepository(
      api: ApiClient(baseUrl: _resolveBaseUrl()),
      cache: MemoryCache(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.red),
      home: _authed
          ? ClientModuleApp(
              repo: repo,
              onLogout: () => setState(() => _authed = false),
            )
          : StartPage(
              repo: repo,
              onAuthed: () => setState(() => _authed = true),
            ),
    );
  }
}
