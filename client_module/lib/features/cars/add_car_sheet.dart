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
  final _modelController = TextEditingController();
  final _plateController = TextEditingController();
  final _colorController = TextEditingController();

  int? _year;
  String? _bodyType;

  bool _saving = false;

  List<String> get _modelsForSelectedMake {
    final make = _makeController.text.trim();
    return kCarModelsByMake[make] ?? const <String>[];
  }

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _plateController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_saving) return;
    setState(() => _saving = true);

    final messenger = ScaffoldMessenger.of(context);

    final make = _makeController.text.trim();
    final model = _modelController.text.trim();
    final plate = _plateController.text.trim();

    try {
      await widget.repo.addCar(
        makeDisplay: make,
        modelDisplay: model,
        plateDisplay: plate,
        year: _year,
        color: _colorController.text.trim().isEmpty
            ? null
            : _colorController.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    final years = List<int>.generate(35, (i) => DateTime.now().year - i);

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
                      _modelController.clear();
                      setState(() {});
                    },
                    fieldViewBuilder: (context, controller, focusNode, _) {
                      controller.text = _makeController.text;

                      controller.addListener(() {
                        if (_makeController.text != controller.text) {
                          _makeController.text = controller.text;
                          _modelController.clear();
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
                  const SizedBox(height: 12),
                  Autocomplete<String>(
                    optionsBuilder: (value) {
                      final list = _modelsForSelectedMake;
                      final q = value.text.trim().toLowerCase();
                      if (q.isEmpty) {
                        return list;
                      }
                      return list.where((m) => m.toLowerCase().contains(q));
                    },
                    onSelected: (v) =>
                        setState(() => _modelController.text = v),
                    fieldViewBuilder: (context, controller, focusNode, _) {
                      controller.text = _modelController.text;

                      controller.addListener(() {
                        if (_modelController.text != controller.text) {
                          _modelController.text = controller.text;
                        }
                      });

                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Модель',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) {
                            return 'Укажи модель';
                          }
                          final list = _modelsForSelectedMake;
                          if (list.isEmpty) {
                            return 'Сначала выбери марку';
                          }
                          if (!list.contains(s)) {
                            return 'Выбери модель из списка';
                          }
                          return null;
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _year,
                    decoration: const InputDecoration(
                      labelText: 'Год',
                      border: OutlineInputBorder(),
                    ),
                    items: years
                        .map(
                          (y) => DropdownMenuItem<int>(
                            value: y,
                            child: Text(y.toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _year = v),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _colorController,
                    decoration: const InputDecoration(
                      labelText: 'Цвет',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _bodyType,
                    decoration: const InputDecoration(
                      labelText: 'Кузов',
                      border: OutlineInputBorder(),
                    ),
                    items: kBodyTypes
                        .map(
                          (t) => DropdownMenuItem<String>(
                            value: t,
                            child: Text(t),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _bodyType = v),
                  ),
                  const SizedBox(height: 12),
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
