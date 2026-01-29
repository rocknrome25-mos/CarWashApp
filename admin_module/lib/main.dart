import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/api/admin_api_client.dart';
import 'core/storage/session_store.dart';
import 'features/login/login_page.dart';
import 'features/shift/shift_gate_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru_RU', null);
  runApp(const AdminApp());
}

class AdminApp extends StatefulWidget {
  const AdminApp({super.key});

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  final api = AdminApiClient(baseUrl: 'http://127.0.0.1:3000');
  final store = SessionStore();

  // Акцент “тиффани” (можно поменять потом)
  static const _seed = Color(0xFF2DD4BF);

  @override
  Widget build(BuildContext context) {
    // “Яндекс-подобный” тёмный минимализм: мягкие поверхности + яркий акцент
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    );

    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,

      // Фон как у “приложений-кошельков/заправок”: темный, но не черный.
      scaffoldBackgroundColor: const Color(0xFF0B0F14),

      // Карточки: крупные скругления + лёгкая обводка
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),

      // AppBar: “плоский”, без лишней заливки
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),

      // Input: как “брендовый” интерфейс — мягкий outline
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.22),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.2),
        ),
      ),

      // NavigationBar: темная панель + “пилюля” индикатора
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF0B0F14),
        indicatorColor: colorScheme.primary.withValues(alpha: 0.18),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface.withValues(alpha: 0.75),
          ),
        ),
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(color: colorScheme.onSurface.withValues(alpha: 0.75)),
        ),
      ),

      // Chips: компактные, как у Яндекс
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
    );

    return MaterialApp(
      title: 'Carwash Admin',
      debugShowCheckedModeBanner: false,
      theme: theme,
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
