import 'package:flutter/material.dart';
import '../../core/constants/car_catalog.dart';
import '../../core/data/app_repository.dart';
import '../../core/utils/normalize.dart';

class AddCarSheet extends StatefulWidget {
  final AppRepository repo;

  const AddCarSheet({super.key, required this.repo});

  @override
  State<AddCarSheet> createState() => _AddCarSheetState();
}

class _AddCarSheetState extends State<AddCarSheet> {
  final _formKey = GlobalKey<FormState>();

  final _makeController = TextEditingController();
  final _plateController = TextEditingController();

  // оставляем в коде, но UI скрываем (на будущее)
  // final _modelController = TextEditingController();
  // final _colorController = TextEditingController();
  // int? _year;

  String? _bodyType; // 'sedan' / 'suv'

  bool _saving = false;

  @override
  void dispose() {
    _makeController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_saving) return;
    setState(() => _saving = true);

    final messenger = ScaffoldMessenger.of(context);

    final make = _makeController.text.trim();
    final plate = _plateController.text.trim();

    try {
      await widget.repo.addCar(
        makeDisplay: make,

        // ✅ modelDisplay обязателен в backend — даём заглушку,
        // а Car-модель потом её очистит (см car.dart)
        modelDisplay: '—',

        plateDisplay: plate,
        bodyType: _bodyType,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      setState(() => _saving = false);
    }
  }

  Widget _bodyTypePicker() {
    final selectedSedan = _bodyType == 'sedan';
    final selectedSuv = _bodyType == 'suv';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: Text(
            'Форма моего авто',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _BodyChip(
                selected: selectedSedan,
                icon: Icons.directions_car_outlined,
                title: 'Седан',
                onTap: () => setState(() => _bodyType = 'sedan'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BodyChip(
                selected: selectedSuv,
                icon: Icons.directions_car_filled_rounded,
                title: 'Внедорожник',
                onTap: () => setState(() => _bodyType = 'suv'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Добавить авто',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  Autocomplete<String>(
                    optionsBuilder: (value) {
                      final q = value.text.trim().toLowerCase();
                      if (q.isEmpty) {
                        return kCarMakes;
                      }
                      return kCarMakes.where(
                        (m) => m.toLowerCase().contains(q),
                      );
                    },
                    onSelected: (v) {
                      _makeController.text = v;
                      setState(() {});
                    },
                    fieldViewBuilder: (context, controller, focusNode, _) {
                      controller.text = _makeController.text;

                      controller.addListener(() {
                        if (_makeController.text != controller.text) {
                          _makeController.text = controller.text;
                          setState(() {});
                        }
                      });

                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Марка',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) {
                            return 'Укажи марку';
                          }
                          if (!kCarMakes.contains(s)) {
                            return 'Выбери марку из списка';
                          }
                          return null;
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 14),

                  _bodyTypePicker(),

                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _plateController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Гос номер',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isEmpty) {
                        return 'Укажи гос номер';
                      }
                      if (normalizePlate(s).isEmpty) {
                        return 'Некорректный номер';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Сохраняю...' : 'Сохранить'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BodyChip extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _BodyChip({
    required this.selected,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? cs.primary : Colors.black.withValues(alpha: 0.10),
            width: selected ? 2 : 1,
          ),
          color: selected ? cs.primary.withValues(alpha: 0.08) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
