import 'package:flutter/material.dart';
import '../../core/data/app_repository.dart';
import '../../core/models/car.dart';
import '../../core/models/service.dart';

class CreateBookingPage extends StatefulWidget {
  final AppRepository repo;
  final String? preselectedServiceId;

  const CreateBookingPage({
    super.key,
    required this.repo,
    this.preselectedServiceId,
  });

  @override
  State<CreateBookingPage> createState() => _CreateBookingPageState();
}

class _CreateBookingPageState extends State<CreateBookingPage> {
  final _formKey = GlobalKey<FormState>();

  List<Car> _cars = const [];
  List<Service> _services = const [];

  String? carId;
  String? serviceId;

  DateTime dateTime = DateTime.now().add(const Duration(hours: 2));

  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    dateTime = _roundTo15(dateTime);
    _bootstrap();
  }

  DateTime _roundTo15(DateTime dt) {
    final minutes = (dt.minute / 15).round() * 15;
    final base = DateTime(dt.year, dt.month, dt.day, dt.hour, 0);
    return base.add(Duration(minutes: minutes));
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cars = await widget.repo.getCars();
      final services = await widget.repo.getServices();

      String? selectedCarId;
      if (cars.isNotEmpty) selectedCarId = cars.first.id;

      String? selectedServiceId =
          widget.preselectedServiceId ??
          (services.isNotEmpty ? services.first.id : null);

      // if preselected service not found -> fallback
      if (widget.preselectedServiceId != null &&
          !services.any((s) => s.id == widget.preselectedServiceId)) {
        selectedServiceId = services.isNotEmpty ? services.first.id : null;
      }

      if (!mounted) return;

      setState(() {
        _cars = cars;
        _services = services;
        carId = selectedCarId;
        serviceId = selectedServiceId;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();

    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 60)),
      initialDate: dateTime,
    );

    if (!mounted || d == null) return;

    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(dateTime),
    );

    if (!mounted || t == null) return;

    setState(() {
      dateTime = _roundTo15(DateTime(d.year, d.month, d.day, t.hour, t.minute));
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (carId == null || serviceId == null) return;

    final messenger = ScaffoldMessenger.of(context);

    // бизнес-валидация времени
    final now = DateTime.now();
    final minAllowed = now.add(const Duration(minutes: 30));
    if (dateTime.isBefore(minAllowed)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Выбери время минимум через 30 минут')),
      );
      return;
    }

    try {
      await widget.repo.createBooking(
        carId: carId!,
        serviceId: serviceId!,
        dateTime: dateTime,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Создать запись')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Создать запись')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Error: $_error'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _bootstrap,
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // защита: initialValue должен быть в items
    final carIds = _cars.map((c) => c.id).toSet();
    final serviceIds = _services.map((s) => s.id).toSet();

    final safeCarId = (carId != null && carIds.contains(carId)) ? carId : null;
    final safeServiceId = (serviceId != null && serviceIds.contains(serviceId))
        ? serviceId
        : null;

    String two(int n) => n.toString().padLeft(2, '0');
    final dt =
        '${two(dateTime.day)}.${two(dateTime.month)}.${dateTime.year} '
        '${two(dateTime.hour)}:${two(dateTime.minute)}';

    return Scaffold(
      appBar: AppBar(title: const Text('Создать запись')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: safeCarId,
                decoration: const InputDecoration(
                  labelText: 'Авто',
                  border: OutlineInputBorder(),
                ),
                items: _cars
                    .map(
                      (c) => DropdownMenuItem<String>(
                        value: c.id,
                        child: Text('${c.make} ${c.model} (${c.plateDisplay})'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => carId = v),
                validator: (_) {
                  if (_cars.isEmpty) return 'Сначала добавь авто';
                  if (carId == null) return 'Выбери авто';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: safeServiceId,
                decoration: const InputDecoration(
                  labelText: 'Услуга',
                  border: OutlineInputBorder(),
                ),
                items: _services
                    .map(
                      (s) => DropdownMenuItem<String>(
                        value: s.id,
                        child: Text('${s.name} (${s.priceRub} ₽)'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => serviceId = v),
                validator: (_) {
                  if (_services.isEmpty) return 'Нет услуг';
                  if (serviceId == null) return 'Выбери услугу';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _pickDateTime,
                  icon: const Icon(Icons.schedule),
                  label: Text(dt),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_cars.isEmpty || _services.isEmpty)
                      ? null
                      : _save,
                  child: const Text('Сохранить'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
