import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api/admin_api_client.dart';
import '../../core/models/admin_session.dart';
import '../../core/storage/session_store.dart';
import '../booking/booking_actions_sheet.dart';
import '../login/login_page.dart';

class CalendarPage extends StatefulWidget {
  final AdminApiClient api;
  final SessionStore store;
  final AdminSession session;

  const CalendarPage({
    super.key,
    required this.api,
    required this.store,
    required this.session,
  });

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  bool loading = true;
  String? error;
  List<dynamic> bookings = [];
  DateTime selectedDay = DateTime.now();

  bool get _cashEnabled => widget.session.featureOn('CASH_DRAWER', defaultValue: true);

  String get _ymd => DateFormat('yyyy-MM-dd').format(selectedDay);

  String _ruTitle() {
    final d = selectedDay;
    final dayName = DateFormat('EEEE', 'ru_RU').format(d);
    final date = DateFormat('d MMMM y', 'ru_RU').format(d);
    return '${_cap(dayName)} • $date';
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

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
      final list = await widget.api.calendarDay(
        widget.session.userId,
        widget.session.activeShiftId!,
        _ymd,
      );
      if (!mounted) return;
      setState(() => bookings = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _fmtTime(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    return DateFormat('HH:mm').format(dt);
  }

  // status RU + МОЕТСЯ
  String _statusRu(Map<String, dynamic> b) {
    final raw = (b['status'] ?? '').toString();
    final startedAt = b['startedAt']?.toString();
    final finishedAt = b['finishedAt']?.toString();

    if (raw == 'CANCELED') return 'ОТМЕНЕНО';
    if (startedAt != null && startedAt.isNotEmpty && (finishedAt == null || finishedAt.isEmpty)) {
      return 'МОЕТСЯ';
    }
    if (raw == 'COMPLETED') return 'ЗАВЕРШЕНО';
    return 'ОЖИДАЕТ';
  }

  Color _statusColor(String statusRu) {
    switch (statusRu) {
      case 'МОЕТСЯ':
        return Colors.blue;
      case 'ЗАВЕРШЕНО':
        return Colors.green;
      case 'ОТМЕНЕНО':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _paymentStatusRu(String ps) {
    if (ps == 'PAID') return 'ОПЛАЧЕНО';
    if (ps == 'PARTIAL') return 'ЧАСТИЧНО';
    if (ps == 'UNPAID') return 'НЕ ОПЛАЧЕНО';
    return ps;
  }

  IconData _payIcon(String x) {
    switch (x) {
      case 'CARD':
        return Icons.credit_card;
      case 'CASH':
        return Icons.payments;
      case 'CONTRACT':
        return Icons.business_center;
      default:
        return Icons.receipt_long;
    }
  }

  Future<void> _closeShiftNoCash() async {
    final userId = widget.session.userId;
    final shiftId = widget.session.activeShiftId!;
    try {
      await widget.api.closeShift(userId, shiftId);
      await widget.store.clear();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginPage(api: widget.api, store: widget.store)),
        (r) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    }
  }

  Future<void> _closeShiftWithCash() async {
    final userId = widget.session.userId;
    final shiftId = widget.session.activeShiftId!;
    try {
      final exp = await widget.api.cashExpected(userId, shiftId);
      if (!mounted) return;

      final expectedRub = (exp['expectedRub'] as num).toInt();

      final countedCtrl = TextEditingController(text: expectedRub.toString());
      final handoverCtrl = TextEditingController(text: '0');
      final keepCtrl = TextEditingController(text: expectedRub.toString());
      final noteCtrl = TextEditingController(text: '');

      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) {
          return StatefulBuilder(
            builder: (ctx, setStateDialog) {
              final counted = int.tryParse(countedCtrl.text.trim()) ?? 0;
              final diff = counted - expectedRub;

              return AlertDialog(
                title: const Text('Закрытие кассы'),
                content: SingleChildScrollView(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(child: Text('Ожидаемая сумма наличных')),
                          Text('$expectedRub ₽', style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Expanded(child: Text('Разница (факт - ожидаемая)')),
                          Text(
                            '${diff >= 0 ? '+' : ''}$diff ₽',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: diff == 0 ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: countedCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Фактически в кассе (₽)'),
                        onChanged: (_) => setStateDialog(() {}),
                      ),
                      TextField(
                        controller: handoverCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Сдать владельцу (₽)'),
                      ),
                      TextField(
                        controller: keepCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Оставить в кассе (₽)'),
                      ),
                      TextField(
                        controller: noteCtrl,
                        decoration: const InputDecoration(labelText: 'Комментарий (необязательно)'),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(false),
                    child: const Text('Отмена'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(true),
                    child: const Text('Закрыть кассу и смену'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (ok != true) return;

      final counted = int.tryParse(countedCtrl.text.trim()) ?? 0;
      final handover = int.tryParse(handoverCtrl.text.trim()) ?? 0;
      final keep = int.tryParse(keepCtrl.text.trim()) ?? 0;
      final note = noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim();

      await widget.api.cashClose(
        userId,
        shiftId,
        countedRub: counted,
        handoverRub: handover,
        keepRub: keep,
        note: note,
      );

      await widget.api.closeShift(userId, shiftId);

      await widget.store.clear();
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginPage(api: widget.api, store: widget.store)),
        (r) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    }
  }

  Future<void> _closeShift() async {
    if (_cashEnabled) {
      await _closeShiftWithCash();
    } else {
      await _closeShiftNoCash();
    }
  }

  void _shiftDay(int deltaDays) {
    setState(() => selectedDay = selectedDay.add(Duration(days: deltaDays)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final shiftId = widget.session.activeShiftId ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(_ruTitle()),
        actions: [
          IconButton(tooltip: 'Вчера', onPressed: () => _shiftDay(-1), icon: const Icon(Icons.chevron_left)),
          IconButton(
            tooltip: 'Сегодня',
            onPressed: () {
              setState(() => selectedDay = DateTime.now());
              _load();
            },
            icon: const Icon(Icons.today),
          ),
          IconButton(tooltip: 'Завтра', onPressed: () => _shiftDay(1), icon: const Icon(Icons.chevron_right)),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          TextButton(onPressed: _closeShift, child: const Text('Закрыть смену')),
          const SizedBox(width: 8),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!, style: const TextStyle(color: Colors.red)))
              : bookings.isEmpty
                  ? const Center(child: Text('Нет записей'))
                  : ListView.separated(
                      itemCount: bookings.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final b = bookings[i] as Map<String, dynamic>;

                        final statusRu = _statusRu(b);
                        final statusColor = _statusColor(statusRu);

                        final serviceName = b['service']?['name']?.toString() ?? 'Услуга';
                        final bayId = b['bayId']?.toString() ?? '';
                        final dateTimeIso = b['dateTime']?.toString() ?? '';

                        final clientName = b['client']?['name']?.toString();
                        final clientPhone = b['client']?['phone']?.toString();
                        final clientTitle = (clientName != null && clientName.isNotEmpty) ? clientName : (clientPhone ?? '');

                        final plate = b['car']?['plateDisplay']?.toString() ?? '';
                        final make = b['car']?['makeDisplay']?.toString() ?? '';
                        final model = b['car']?['modelDisplay']?.toString() ?? '';
                        final color = b['car']?['color']?.toString();
                        final body = b['car']?['bodyType']?.toString();

                        final carParts = <String>[];
                        if (plate.isNotEmpty) carParts.add(plate);
                        final mm = ('$make $model').trim();
                        if (mm.isNotEmpty) carParts.add(mm);
                        if (body != null && body.trim().isNotEmpty) carParts.add(body.trim());
                        if (color != null && color.trim().isNotEmpty) carParts.add(color.trim());
                        final carLine = carParts.isEmpty ? '' : 'Авто: ${carParts.join(' • ')}';

                        final clientComment = b['comment']?.toString();
                        final hasComment = clientComment != null && clientComment.trim().isNotEmpty;

                        final time = dateTimeIso.isNotEmpty ? _fmtTime(dateTimeIso) : '--:--';

                        final paid = (b['paidTotalRub'] as num?)?.toInt() ?? 0;
                        final toPay = (b['remainingRub'] as num?)?.toInt() ?? 0;

                        final ps = (b['paymentStatus'] ?? '').toString();
                        final psRu = _paymentStatusRu(ps);

                        final badges = (b['paymentBadges'] is List)
                            ? (b['paymentBadges'] as List).map((x) => x.toString()).toList()
                            : <String>[];

                        return ListTile(
                          title: Text('$time • $serviceName • Пост $bayId'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(clientTitle),
                              if (carLine.isNotEmpty) Text(carLine),
                              if (hasComment) Text('Комментарий: ${clientComment.trim()}'),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Chip(
                                    label: Text(statusRu),
                                    visualDensity: VisualDensity.compact,
                                    side: BorderSide(color: statusColor),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(psRu),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('Оплачено: $paid ₽   К оплате: $toPay ₽'),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                children: [
                                  for (final x in badges)
                                    Chip(
                                      avatar: Icon(_payIcon(x), size: 18),
                                      label: Text(x == 'CARD' ? 'Карта' : x == 'CASH' ? 'Наличные' : 'Контракт'),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                ],
                              ),
                            ],
                          ),
                          onTap: () async {
                            await showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              builder: (_) => BookingActionsSheet(
                                api: widget.api,
                                session: widget.session,
                                booking: b,
                                onDone: _load,
                              ),
                            );
                          },
                        );
                      },
                    ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8),
        child: Text('Shift: $shiftId', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
      ),
    );
  }
}
