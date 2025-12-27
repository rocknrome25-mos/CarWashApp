import 'package:flutter/material.dart';
import '../../core/data/demo_repository.dart';

class AddCarSheet extends StatefulWidget {
  final DemoRepository repo;

  const AddCarSheet({super.key, required this.repo});

  @override
  State<AddCarSheet> createState() => _AddCarSheetState();
}

class _AddCarSheetState extends State<AddCarSheet> {
  final _formKey = GlobalKey<FormState>();
  final brand = TextEditingController();
  final model = TextEditingController();
  final plate = TextEditingController();

  @override
  void dispose() {
    brand.dispose();
    model.dispose();
    plate.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    widget.repo.addCar(brand: brand.text, model: model.text, plate: plate.text);

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: bottomInset + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Добавить авто',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: brand,
              decoration: const InputDecoration(
                labelText: 'Марка',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Укажи марку' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: model,
              decoration: const InputDecoration(
                labelText: 'Модель',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Укажи модель' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: plate,
              decoration: const InputDecoration(
                labelText: 'Госномер',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Укажи номер' : null,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: const Text('Сохранить'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
