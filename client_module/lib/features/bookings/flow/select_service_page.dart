import 'package:flutter/material.dart';
import '../../../core/data/app_repository.dart';
import '../../../core/models/service.dart';

class SelectServicePage extends StatefulWidget {
  final AppRepository repo;

  const SelectServicePage({super.key, required this.repo});

  @override
  State<SelectServicePage> createState() => _SelectServicePageState();
}

class _SelectServicePageState extends State<SelectServicePage> {
  bool loading = true;
  Object? error;
  List<Service> services = const [];
  String? selectedId;

  bool _isBase(Service s) {
    final k = (s.kind ?? '').toUpperCase().trim();
    return k.isEmpty || k == 'BASE'; // backward compatible
  }

  int _sortOrder(Service s) => s.sortOrder ?? 100000;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final all = await widget.repo.getServices(forceRefresh: true);

      // ✅ only BASE here
      final base = all.where(_isBase).toList();
      base.sort((a, b) {
        final ao = _sortOrder(a);
        final bo = _sortOrder(b);
        if (ao != bo) return ao.compareTo(bo);
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      if (!mounted) return;
      setState(() {
        services = base;
        selectedId = base.isNotEmpty ? base.first.id : null;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Выбрать услугу')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Выбрать услугу')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Ошибка: $error'),
                const SizedBox(height: 12),
                FilledButton(onPressed: _load, child: const Text('Повторить')),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Выбрать услугу')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                itemCount: services.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final s = services[i];
                  final selected = selectedId == s.id;

                  final dur = s.durationMin ?? 30;

                  return InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => setState(() => selectedId = s.id),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.06),
                        ),
                        color: selected
                            ? Colors.black.withValues(alpha: 0.04)
                            : Theme.of(context).cardColor,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${s.priceRub} ₽ • $dur мин',
                                  style: TextStyle(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (selected)
                            const Icon(Icons.check_circle, size: 22),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: selectedId == null
                    ? null
                    : () {
                        final s = services.firstWhere(
                          (x) => x.id == selectedId,
                        );
                        Navigator.of(context).pop(s);
                      },
                child: const Text(
                  'Далее',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
