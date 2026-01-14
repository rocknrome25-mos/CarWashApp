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

  // UI скрыт, но оставляем в коде на будущее
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

    try {
      await widget.repo.addCar(
        makeDisplay: _makeController.text.trim(),

        // backend требует modelDisplay — даём безопасную заглушку
        modelDisplay: '—',

        plateDisplay: _plateController.text.trim(),
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
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _BodyChip(
                selected: _bodyType == 'sedan',
                asset: 'assets/images/body/sedan.png',
                title: 'Седан',
                onTap: () => setState(() => _bodyType = 'sedan'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BodyChip(
                selected: _bodyType == 'suv',
                asset: 'assets/images/body/suv.png',
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
                      if (q.isEmpty) return kCarMakes;
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
                          if (s.isEmpty) return 'Укажи марку';
                          if (!kCarMakes.contains(s)) {
                            return 'Выбери марку из списка';
                          }
                          return null;
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 16),
                  _bodyTypePicker(),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _plateController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Гос номер',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isEmpty) return 'Укажи гос номер';
                      if (normalizePlate(s).isEmpty) {
                        return 'Некорректный номер';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

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
  final String asset;
  final String title;
  final VoidCallback onTap;

  const _BodyChip({
    required this.selected,
    required this.asset,
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
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 12),
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
            Image.asset(asset, width: 36, height: 36, fit: BoxFit.contain),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
