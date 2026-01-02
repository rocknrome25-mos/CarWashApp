import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/api/api_client.dart';
import 'core/cache/memory_cache.dart';
import 'core/data/api_app_repository.dart';
import 'core/data/app_repository.dart';

import 'features/bookings/bookings_page.dart';
import 'features/cars/cars_page.dart';
import 'screens/services_screen.dart';

class ClientModuleApp extends StatefulWidget {
  const ClientModuleApp({super.key});

  @override
  State<ClientModuleApp> createState() => _ClientModuleAppState();
}

class _ClientModuleAppState extends State<ClientModuleApp> {
  late final AppRepository repo;

  int index = 0;

  @override
  void initState() {
    super.initState();

    repo = ApiAppRepository(
      api: ApiClient(baseUrl: 'http://10.0.2.2:3000'),
      cache: MemoryCache(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      CarsPage(repo: repo),
      ServicesScreen(repo: repo),
      BookingsPage(repo: repo),
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
        appBar: AppBar(title: const Text('Автомойка')),
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
          ],
        ),
      ),
    );
  }
}
