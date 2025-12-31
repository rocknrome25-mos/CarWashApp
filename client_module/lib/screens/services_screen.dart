import 'package:flutter/material.dart';
import '../api/services_api.dart';
import '../core/models/service.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  late final ServicesApi api;
  late Future<List<Service>> future;

  @override
  void initState() {
    super.initState();
    api = ServicesApi(baseUrl: 'http://10.0.2.2:3000');
    future = api.fetchServices();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Услуги')),
      body: FutureBuilder<List<Service>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final items = snapshot.data ?? [];
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final s = items[i];
              return ListTile(
                title: Text(s.name),
                trailing: Text('${s.priceRub} ₽'),
              );
            },
          );
        },
      ),
    );
  }
}
