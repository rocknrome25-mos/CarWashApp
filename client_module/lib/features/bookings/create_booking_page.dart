import 'package:flutter/material.dart';
import '../../core/data/demo_repository.dart';

class CreateBookingPage extends StatefulWidget {
  final DemoRepository repo;
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
  String? carId;
  String? serviceId;
  DateTime dateTime = DateTime.now().add(const Duration(hours: 2));

  @override
  void initState() {
    super.initState();
    final cars = widget.repo.getCars();
    final services = widget.repo.getServices();
    if (cars.isNotEmpty) carId = cars.first.id;
    serviceId =
        widget.preselectedServiceId ??
        (services.isNotEmpty ? services.first.id : null);
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
      dateTime = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  void _save() {
    if (carId == null || serviceId == null) return;

    widget.repo.addBooking(
      carId: carId!,
      serviceId: serviceId!,
      dateTime: dateTime,
    );

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final cars = widget.repo.getCars();
    final services = widget.repo.getServices();

    return Scaffold(
      appBar: AppBar(title: const Text('Создать запись')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: carId,
              decoration: const InputDecoration(
                labelText: 'Авто',
                border: OutlineInputBorder(),
              ),
              items: cars
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.id,
                      child: Text('${c.brand} ${c.model} (${c.plate})'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => carId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: serviceId,
              decoration: const InputDecoration(
                labelText: 'Услуга',
                border: OutlineInputBorder(),
              ),
              items: services
                  .map(
                    (s) => DropdownMenuItem(
                      value: s.id,
                      child: Text('${s.name} (${s.priceRub} ₽)'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => serviceId = v),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pickDateTime,
                icon: const Icon(Icons.schedule),
                label: Text(
                  '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.year} '
                  '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}',
                ),
              ),
            ),
            const Spacer(),
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
