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

    if (!context.mounted) return;
    if (didLogout == true) {
      widget.onLogout();
    }
  }

  Widget _brandTitle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Image.asset(
            'assets/images/logo/carwash_logo_512.png',
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: 10),
        const Text('Автомойка'),
      ],
    );
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
      ContactsPage(repo: widget.repo), // from /config
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
      // ВАЖНО: тему ты подключаешь снаружи (main.dart). Здесь оставим как есть.
      theme: Theme.of(context),
      home: Scaffold(
        appBar: AppBar(
          title: _brandTitle(context),
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
