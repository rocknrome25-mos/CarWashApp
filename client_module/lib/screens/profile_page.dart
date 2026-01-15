import 'package:flutter/material.dart';
import '../core/data/app_repository.dart';

class ProfilePage extends StatelessWidget {
  final AppRepository repo;

  const ProfilePage({super.key, required this.repo});

  @override
  Widget build(BuildContext context) {
    final c = repo.currentClient;

    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(c?.displayName ?? 'Клиент'),
              subtitle: Text(c?.phone ?? ''),
            ),
            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _row(
                      'Имя',
                      (c?.name ?? '').trim().isEmpty ? '—' : c!.name!,
                    ),
                    const SizedBox(height: 8),
                    _row('Пол', c?.gender == 'FEMALE' ? 'Жен' : 'Муж'),
                    const SizedBox(height: 8),
                    _row(
                      'Дата рождения',
                      c?.birthDate == null ? '—' : _fmtDate(c!.birthDate!),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await repo.logout();
                  if (context.mounted) {
                    Navigator.of(context).pop(true); // сигнал "вышел"
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Выйти'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(k, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        Expanded(
          flex: 6,
          child: Text(
            v,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  String _fmtDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year}';
  }
}
