import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/api/api_client.dart';
import 'core/cache/memory_cache.dart';
import 'core/data/api_repository.dart';
import 'core/data/app_repository.dart';

import 'features/bookings/bookings_page.dart';
import 'features/cars/cars_page.dart';
import 'screens/services_screen.dart';
import 'screens/contacts_page.dart';

class ClientModuleApp extends StatefulWidget {
  const ClientModuleApp({super.key});

  @override
  State<ClientModuleApp> createState() => _ClientModuleAppState();
}

class _ClientModuleAppState extends State<ClientModuleApp> {
  late final AppRepository repo;

  int index = 0;

  /// Общий триггер обновлений для вкладок Services/Bookings.
  int refreshToken = 0;

  String _resolveBaseUrl() {
    // Web
    if (kIsWeb) return 'http://localhost:3000';

    // Android Emulator -> host machine
    if (Platform.isAndroid) return 'http://10.0.2.2:3000';

    // Windows/macOS/Linux desktop
    return 'http://localhost:3000';
  }

  /// ✅ после создания брони:
  /// 1) обновляем refreshToken
  /// 2) переключаемся на вкладку "Записи" (index = 2)
  void _onBookingCreated() {
    setState(() {
      refreshToken++;
      index = 2;
    });
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
    final pages = <Widget>[
      CarsPage(repo: repo),
      ServicesScreen(
        repo: repo,
        refreshToken: refreshToken,
        onBookingCreated: _onBookingCreated,
      ),
      BookingsPage(repo: repo, refreshToken: refreshToken),

      // ✅ Контакты (прототипные данные пока)
      const ContactsPage(
        title: 'Контакты',
        address: 'Москва, бульвар Андрея Тарковского, 10',
        phone: '+7-927-310-9336',
        telegram: '@carwash_demo', // любой пока
        navigatorLink:
            'https://www.google.com/maps/search/?api=1&query=Москва%2C%20бульвар%20Андрея%20Тарковского%2010',
      ),
    ];

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Автомойка',
      locale: const Locale('ru', 'RU'),
      supportedLocales: const [Locale('ru', 'RU'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.red),
      home: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Image.asset(
                'assets/images/logo/carwash_logo_512.png',
                width: 26,
                height: 26,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 10),
              const Text('Автомойка'),
            ],
          ),
        ),
        body: pages[index],
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (v) => setState(() => index = v),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.directions_car),
              label: 'Авто',
            ),
            NavigationDestination(
              icon: Icon(Icons.local_car_wash),
              label: 'Услуги',
            ),
            NavigationDestination(icon: Icon(Icons.event), label: 'Записи'),
            NavigationDestination(
              icon: Icon(Icons.contact_phone),
              label: 'Контакты',
            ),
          ],
        ),
      ),
    );
  }
}
