import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/data/demo_repository.dart';
import 'features/bookings/bookings_page.dart';
import 'features/cars/cars_page.dart';
import 'features/services/services_page.dart';

class ClientModuleApp extends StatefulWidget {
  const ClientModuleApp({super.key});

  @override
  State<ClientModuleApp> createState() => _ClientModuleAppState();
}

class _ClientModuleAppState extends State<ClientModuleApp> {
  final DemoRepository repo = DemoRepository();
  int index = 0;

  void _goToBookings() {
    setState(() => index = 2); // 0=Авто, 1=Услуги, 2=Записи
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      CarsPage(repo: repo),
      ServicesPage(repo: repo, onBookingCreated: _goToBookings),
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
