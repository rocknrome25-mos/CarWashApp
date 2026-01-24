import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api/admin_api_client.dart';
import '../../core/models/admin_session.dart';

class BookingActionsSheet extends StatefulWidget {
  final AdminApiClient api;
  final AdminSession session;
  final Map<String, dynamic> booking;
  final VoidCallback onDone;

  const BookingActionsSheet({
    super.key,
    required this.api,
    required this.session,
    required this.booking,
    required this.onDone,
  });

  @override
  State<BookingActionsSheet> createState() => _BookingActionsSheetState();
}

class _BookingActionsSheetState extends State<BookingActionsSheet> {
  bool loading = false;
  String? error;

  final noteCtrl = TextEditingController();
  final moveReasonCtrl = TextEditingController(text: 'Сдвиг из-за задержки');
  bool clientAgreed = true;

  int selectedBay = 1;
  DateTime? selectedDateTimeLocal;

  // Оплата админом
  String paymentMethod = 'CARD'; // CARD / CASH / CONTRACT

  bool get _moveEnabled => widget.session.featureOn('BOOKING_MOVE', defaultValue: true);
  bool get _cashEnabled => widget.session.featureOn('CASH_DRAWER', defaultValue: true);
  bool get _contractEnabled => widget.session.featureOn('CONTRACT_PAYMENTS', defaultValue: true);

  @override
  void initState() {
    super.initState();

    final bayId = widget.booking['bayId'];
    if (bayId is num) selectedBay = bayId.toInt();

    final adminNote = widget.booking['adminNote'];
    if (adminNote is String && adminNote.trim().isNotEmpty) {
      noteCtrl.text = adminNote;
    }

    final dtIso = widget.booking['dateTime']?.toString();
    if (dtIso != null && dtIso.isNotEmpty) {
      selectedDateTimeLocal = DateTime.parse(dtIso).toLocal();
    }

    paymentMethod = 'CARD';
  }

  @override
  void dispose() {
    noteCtrl.dispose();
    moveReasonCtrl.dispose();
    super.dispose();
  }

  String get _userId => widget.session.userId;
  String get _shiftId => widget.session.activeShiftId ?? '';
  String get _bookingId => widget.booking['id'] as String;

  String _fmtTimeIso(String? iso) {
    if (iso == null || iso.isEmpty) return '--:--';
    final dt = DateTime.parse(iso).toLocal();
    return DateFormat('HH:mm').format(dt);
  }

  String _fmtDateTimeLocal(DateTime dt) {
    return DateFormat('yyyy-MM-dd HH:mm').format(dt);
  }

  String _status() => (widget.booking['status'] ?? '').toString();
  bool get _isCompleted => _status() == 'COMPLETED';
  bool get _isCanceled => _status() == 'CANCELED';

  bool get _canStart => !_isCanceled && !_isCompleted;
  bool get _canMove => _moveEnabled && !_isCanceled && !_isCompleted;
  bool get _canFinish => !_isCanceled && !_isCompleted;

  int _intOr0(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  List<String> _paymentBadges() {
    final b = widget.booking['paymentBadges'];
    if (b is List) return b.map((x) => x.toString()).toList();
    return const [];
  }

  String _paymentStatus() => (widget.booking['paymentStatus'] ?? '').toString();
  int _paidTotalRub() => _intOr0(widget.booking['paidTotalRub']);
  int _remainingRub() => _intOr0(widget.booking['remainingRub']);

  Future<void> _run(Future<void> Function() fn) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await fn();
      widget.onDone();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _start() async {
    if (!_canStart) return;
    await _run(() async {
      await widget.api.startBooking(
        _userId,
        _shiftId,
        _bookingId,
        noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      );
    });
  }

  Future<void> _finish() async {
    if (!_canFinish) return;

    final remaining = _remainingRub();
    if (remaining > 0) {
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Оплата не завершена'),
          content: Text('Осталось оплатить: $remaining ₽.\nЗакончить услугу всё равно?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Закончить'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    await _run(() async {
      await widget.api.finishBooking(
        _userId,
        _shiftId,
        _bookingId,
        noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      );
    });
  }

  Future<void> _pickMoveDateTime() async {
    final initial = selectedDateTimeLocal ?? DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (date == null) return;
    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    if (!mounted) return;

    setState(() {
      selectedDateTimeLocal = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _move() async {
    if (!_canMove) return;

    final dt = selectedDateTimeLocal;
    if (dt == null) {
      setState(() => error = 'Выбери новое время для переноса');
      return;
    }

    final reason = moveReasonCtrl.text.trim();
    if (reason.isEmpty) {
      setState(() => error = 'Причина переноса обязательна');
      return;
    }
    if (!clientAgreed) {
      setState(() => error = 'Нужно подтвердить согласие клиента');
      return;
    }

    final newIsoUtc = dt.toUtc().toIso8601String();

    await _run(() async {
      await widget.api.moveBooking(
        _userId,
        _shiftId,
        _bookingId,
        newDateTimeIso: newIsoUtc,
        newBayId: selectedBay,
        reason: reason,
        clientAgreed: clientAgreed,
      );
    });
  }

  Future<void> _payFully() async {
    final remaining = _remainingRub();
    if (remaining <= 0) return;

    if (paymentMethod == 'CASH' && !_cashEnabled) {
      setState(() => error = 'Наличные отключены для этого заказчика');
      return;
    }
    if (paymentMethod == 'CONTRACT' && !_contractEnabled) {
      setState(() => error = 'Контракт отключён для этого заказчика');
      return;
    }

    await _run(() async {
      await widget.api.adminPayBooking(
        _userId,
        _shiftId,
        _bookingId,
        kind: 'REMAINING',
        amountRub: remaining,
        methodType: paymentMethod,
        methodLabel: paymentMethod,
        note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      );
    });
  }

  Widget _paymentMethodChips() {
    final choices = <String>['CARD'];
    if (_cashEnabled) choices.add('CASH');
    if (_contractEnabled) choices.add('CONTRACT');

    String label(String v) {
      switch (v) {
        case 'CARD':
          return 'Карта';
        case 'CASH':
          return 'Наличные';
        case 'CONTRACT':
          return 'Контракт';
        default:
          return v;
      }
    }

    if (!choices.contains(paymentMethod)) {
      paymentMethod = 'CARD';
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in choices)
          ChoiceChip(
            label: Text(label(v)),
            selected: paymentMethod == v,
            onSelected: loading ? null : (_) => setState(() => paymentMethod = v),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;

    final serviceName = b['service']?['name']?.toString() ?? 'Услуга';
    final status = _status();
    final bayIdStr = b['bayId']?.toString() ?? '';

    final clientName = b['client']?['name']?.toString();
    final clientPhone = b['client']?['phone']?.toString();
    final titleClient = (clientName != null && clientName.isNotEmpty) ? clientName : (clientPhone ?? '');

    // ✅ авто в карточке
    final plate = b['car']?['plateDisplay']?.toString() ?? '';
    final make = b['car']?['makeDisplay']?.toString() ?? '';
    final model = b['car']?['modelDisplay']?.toString() ?? '';
    final color = b['car']?['color']?.toString();
    final body = b['car']?['bodyType']?.toString();

    final carParts = <String>[];
    if (plate.isNotEmpty) carParts.add(plate);
    if ('$make $model'.trim().isNotEmpty) carParts.add('$make $model'.trim());
    if (body != null && body.trim().isNotEmpty) carParts.add(body.trim());
    if (color != null && color.trim().isNotEmpty) carParts.add(color.trim());
    final carLine = carParts.isEmpty ? 'Авто: —' : 'Авто: ${carParts.join(' • ')}';

    final dateTimeIso = b['dateTime']?.toString() ?? '';
    final startedAt = b['startedAt']?.toString();
    final finishedAt = b['finishedAt']?.toString();

    final payBadges = _paymentBadges();
    final payStatus = _paymentStatus();
    final paid = _paidTotalRub();
    final remaining = _remainingRub();

    final dtLine = dateTimeIso.isNotEmpty ? _fmtTimeIso(dateTimeIso) : '--:--';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '$dtLine • $serviceName • Пост $bayIdStr',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text('Клиент: $titleClient'),
              Text(carLine, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('Статус: $status'),
              const SizedBox(height: 8),

              if (payBadges.isNotEmpty || payStatus.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final x in payBadges)
                      Chip(label: Text(x), visualDensity: VisualDensity.compact),
                    if (payStatus.isNotEmpty)
                      Chip(label: Text(payStatus), visualDensity: VisualDensity.compact),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Оплачено: $paid ₽   Осталось: $remaining ₽'),
                const SizedBox(height: 8),
              ],

              Text('План: ${dateTimeIso.isEmpty ? '--:--' : _fmtTimeIso(dateTimeIso)}'),
              Text('Старт: ${_fmtTimeIso(startedAt)}'),
              Text('Финиш: ${_fmtTimeIso(finishedAt)}'),

              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Комментарий администратора',
                  border: OutlineInputBorder(),
                ),
              ),

              // ===== PAYMENT BLOCK =====
              if (remaining > 0) ...[
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 10),
                Text('Оплата перед завершением', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('Осталось оплатить: $remaining ₽'),
                const SizedBox(height: 8),
                _paymentMethodChips(),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: loading ? null : _payFully,
                  icon: const Icon(Icons.payments),
                  label: const Text('Оплачено полностью'),
                ),
              ],

              // ===== MOVE BLOCK =====
              if (_moveEnabled) ...[
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 10),
                Text('Перенос записи', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: loading || !_canMove ? null : _pickMoveDateTime,
                        child: Text(
                          selectedDateTimeLocal == null
                              ? 'Выбрать дату/время'
                              : _fmtDateTimeLocal(selectedDateTimeLocal!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 120,
                      child: DropdownButtonFormField<int>(
                        initialValue: selectedBay,
                        decoration: const InputDecoration(
                          labelText: 'Пост',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('Пост 1')),
                          DropdownMenuItem(value: 2, child: Text('Пост 2')),
                        ],
                        onChanged: loading || !_canMove
                            ? null
                            : (v) => setState(() => selectedBay = v ?? 1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Checkbox(
                      value: clientAgreed,
                      onChanged: loading || !_canMove
                          ? null
                          : (v) => setState(() => clientAgreed = v ?? false),
                    ),
                    const Expanded(child: Text('Согласовано с клиентом')),
                  ],
                ),

                TextField(
                  controller: moveReasonCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Причина переноса (обязательно)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: loading || !_canMove ? null : _move,
                  child: const Text('Перенести'),
                ),
              ],

              const SizedBox(height: 12),
              if (error != null) ...[
                Text(error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 8),
              ],

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: loading || !_canStart ? null : _start,
                      child: loading
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator())
                          : const Text('Начать'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: loading || !_canFinish ? null : _finish,
                      child: const Text('Закончить'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              TextButton(
                onPressed: loading ? null : () => Navigator.of(context).pop(),
                child: const Text('Закрыть'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
