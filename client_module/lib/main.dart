import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/api/api_client.dart';
import 'core/cache/memory_cache.dart';
import 'core/data/api_repository.dart';
import 'core/data/app_repository.dart';
import 'core/realtime/realtime_client.dart';
import 'core/theme/app_theme.dart' as theme;
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

  Uri _resolveWsUrl(String baseUrl) {
    final u = Uri.parse(baseUrl);
    final scheme = u.scheme == 'https' ? 'wss' : 'ws';
    return Uri(scheme: scheme, host: u.host, port: u.port, path: '/ws');
  }

  @override
  void initState() {
    super.initState();

    final baseUrl = _resolveBaseUrl();
    final rt = RealtimeClient(wsUri: _resolveWsUrl(baseUrl));
    rt.connect();

    repo = ApiRepository(
      api: ApiClient(baseUrl: baseUrl),
      cache: MemoryCache(),
      realtime: rt,
    );
  }

  @override
  void dispose() {
    repo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme.AppTheme.dark(),
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
