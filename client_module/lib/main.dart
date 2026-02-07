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

  /// ✅ One source of truth:
  /// - web: defaults to http://localhost:3000
  /// - android emulator: http://10.0.2.2:3000
  /// - real device / others: MUST be provided via --dart-define=BASE_URL=...
  ///
  /// Examples:
  /// flutter run -d chrome --dart-define=BASE_URL=http://localhost:3000
  /// flutter run -d emulator-5554 --dart-define=BASE_URL=http://10.0.2.2:3000
  /// flutter run -d <your_phone> --dart-define=BASE_URL=http://192.168.1.10:3000
  String _resolveBaseUrl() {
    const defined = String.fromEnvironment('BASE_URL', defaultValue: '');
    if (defined.trim().isNotEmpty) return defined.trim();

    if (kIsWeb) return 'http://localhost:3000';

    // Android emulator default
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:3000';

    // ✅ Do NOT guess localhost on real devices — it will not work
    // Put a clear default so the problem is obvious during testing
    return 'http://CHANGE_ME:3000';
  }

  @override
  void initState() {
    super.initState();

    final baseUrl = _resolveBaseUrl();

    final rt = RealtimeClient.fromBaseUrl(baseUrl);

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
