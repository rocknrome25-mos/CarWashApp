import 'package:flutter/material.dart';

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
  final repo = DemoRepository();
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      CarsPage(repo: repo),
      ServicesPage(repo: repo),
      BookingsPage(repo: repo),
    ];

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Автомойка',
      theme: ThemeData(useMaterial3: true),
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
