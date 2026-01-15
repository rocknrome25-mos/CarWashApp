import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/data/app_repository.dart';

import 'features/bookings/bookings_page.dart';
import 'features/cars/cars_page.dart';
import 'screens/services_screen.dart';
import 'screens/contacts_page.dart';

class ClientModuleApp extends StatefulWidget {
  final AppRepository repo;
  final VoidCallback onLogout;

  const ClientModuleApp({
    super.key,
    required this.repo,
    required this.onLogout,
  });

  @override
  State<ClientModuleApp> createState() => _ClientModuleAppState();
}

class _ClientModuleAppState extends State<ClientModuleApp> {
  int index = 0;

  /// Общий триггер обновлений для вкладок Services/Bookings.
  int refreshToken = 0;

  void _onBookingCreated() {
    setState(() {
      refreshToken++;
      index = 2;
    });
  }

  Future<void> _openProfile() async {
    final c = widget.repo.currentClient;

    // показываем sheet и ждём результат: true = logout
    final didLogout = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(c?.displayName ?? 'Профиль'),
                  subtitle: Text(c?.phone ?? ''),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await widget.repo.logout();

                      // закрываем только если sheet ещё в дереве
                      if (sheetContext.mounted) {
                        Navigator.of(sheetContext).pop(true);
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Выйти'),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );

    // ✅ правильная проверка после async gap
    if (!context.mounted) return;

    if (didLogout == true) {
      widget.onLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      CarsPage(repo: widget.repo),
      ServicesScreen(
        repo: widget.repo,
        refreshToken: refreshToken,
        onBookingCreated: _onBookingCreated,
      ),
      BookingsPage(repo: widget.repo, refreshToken: refreshToken),
      const ContactsPage(
        title: 'Контакты',
        address: 'Москва, бульвар Андрея Тарковского, 10',
        phone: '+7-927-310-9336',
        telegram: '@carwash_demo',
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
          actions: [
            IconButton(
              tooltip: 'Профиль',
              onPressed: _openProfile,
              icon: const Icon(Icons.account_circle),
            ),
          ],
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
