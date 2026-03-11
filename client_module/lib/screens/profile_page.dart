import 'package:flutter/material.dart';
import '../core/data/app_repository.dart';

class ProfilePage extends StatelessWidget {
  final AppRepository repo;

  const ProfilePage({super.key, required this.repo});

  @override
  Widget build(BuildContext context) {
    final c = repo.currentClient;
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final rawDisplayName = c?.displayName.trim() ?? '';
    final displayName = rawDisplayName.isNotEmpty ? rawDisplayName : 'Клиент';

    final phone = (c?.phone ?? '').trim();
    final name = (c?.name ?? '').trim().isEmpty ? '—' : c!.name!;
    final gender = c?.gender == 'FEMALE' ? 'Жен' : 'Муж';
    final birthDate = c?.birthDate == null ? '—' : _fmtDate(c!.birthDate!);

    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset + 8),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.45),
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                    color: Colors.black.withValues(alpha: 0.06),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: cs.primary.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      color: cs.primary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: cs.onSurface.withValues(alpha: 0.96),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          phone.isEmpty ? 'Телефон не указан' : phone,
                          style: textTheme.bodyMedium?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.68),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
              child: Column(
                children: [
                  _infoRow(context, 'Имя', name),
                  const SizedBox(height: 14),
                  _divider(context),
                  const SizedBox(height: 14),
                  _infoRow(context, 'Пол', gender),
                  const SizedBox(height: 14),
                  _divider(context),
                  const SizedBox(height: 14),
                  _infoRow(context, 'Дата рождения', birthDate),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await repo.logout();
                  if (context.mounted) {
                    Navigator.of(context).pop(true);
                  }
                },
                icon: const Icon(Icons.logout_rounded),
                label: Text(
                  'Выйти',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface.withValues(alpha: 0.68),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 6,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface.withValues(alpha: 0.94),
            ),
          ),
        ),
      ],
    );
  }

  Widget _divider(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 1,
      color: cs.outlineVariant.withValues(alpha: 0.35),
    );
  }

  String _fmtDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year}';
  }
}
