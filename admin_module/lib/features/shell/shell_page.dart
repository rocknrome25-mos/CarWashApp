import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/admin_api_client.dart';
import '../../core/models/admin_session.dart';
import '../../core/storage/session_store.dart';
import '../booking/booking_actions_sheet.dart';
import '../login/login_page.dart';

class ShellPage extends StatefulWidget {
  final AdminApiClient api;
  final SessionStore store;
  final AdminSession session;

  const ShellPage({
    super.key,
    required this.api,
    required this.store,
    required this.session,
  });

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  int _idx = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _idx,
        children: [
          ShiftTab(
            api: widget.api,
            store: widget.store,
            session: widget.session,
          ),
          BaysTab(
            api: widget.api,
            store: widget.store,
            session: widget.session,
          ),
          WaitlistTab(
            api: widget.api,
            store: widget.store,
            session: widget.session,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (v) => setState(() => _idx = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.event_note), label: 'Смена'),
          NavigationDestination(icon: Icon(Icons.car_repair), label: 'Посты'),
          NavigationDestination(icon: Icon(Icons.queue), label: 'Ожидание'),
        ],
      ),
    );
  }
}

/* ========================= TAB 1: СМЕНА ========================= */

class ShiftTab extends StatefulWidget {
  final AdminApiClient api;
  final SessionStore store;
  final AdminSession session;

  const ShiftTab({
    super.key,
    required this.api,
    required this.store,
    required this.session,
  });

  @override
  State<ShiftTab> createState() => _ShiftTabState();
}

class _ShiftTabState extends State<ShiftTab> {
  bool loading = true;
  String? error;

  List<dynamic> bookings = [];
  DateTime selectedDay = DateTime.now();

  bool get _cashEnabled =>
      widget.session.featureOn('CASH_DRAWER', defaultValue: true);
  String get _ymd => DateFormat('yyyy-MM-dd').format(selectedDay);

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  String _ruTitle() {
    final d = selectedDay;
    final dayName = DateFormat('EEEE', 'ru_RU').format(d);
    final date = DateFormat('d MMMM y', 'ru_RU').format(d);
    return '${_cap(dayName)} • $date';
  }

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

  void _shiftDay(int deltaDays) {
    setState(() => selectedDay = selectedDay.add(Duration(days: deltaDays)));
    _load();
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
    if (startedAt != null &&
        startedAt.isNotEmpty &&
        (finishedAt == null || finishedAt.isEmpty)) {
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
        MaterialPageRoute(
          builder: (_) => LoginPage(api: widget.api, store: widget.store),
        ),
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
                          const Expanded(
                            child: Text('Ожидаемая сумма наличных'),
                          ),
                          Text(
                            '$expectedRub ₽',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Разница (факт - ожидаемая)'),
                          ),
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
                        decoration: const InputDecoration(
                          labelText: 'Фактически в кассе (₽)',
                        ),
                        onChanged: (_) => setStateDialog(() {}),
                      ),
                      TextField(
                        controller: handoverCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Сдать владельцу (₽)',
                        ),
                      ),
                      TextField(
                        controller: keepCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Оставить в кассе (₽)',
                        ),
                      ),
                      TextField(
                        controller: noteCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Комментарий (необязательно)',
                        ),
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
        MaterialPageRoute(
          builder: (_) => LoginPage(api: widget.api, store: widget.store),
        ),
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

  @override
  Widget build(BuildContext context) {
    final shiftId = widget.session.activeShiftId ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(_ruTitle()),
        actions: [
          IconButton(
            tooltip: 'Вчера',
            onPressed: () => _shiftDay(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Сегодня',
            onPressed: () {
              setState(() => selectedDay = DateTime.now());
              _load();
            },
            icon: const Icon(Icons.today),
          ),
          IconButton(
            tooltip: 'Завтра',
            onPressed: () => _shiftDay(1),
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          TextButton(
            onPressed: _closeShift,
            child: const Text('Закрыть смену'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            )
          : bookings.isEmpty
          ? const Center(child: Text('Нет записей'))
          : ListView.separated(
              itemCount: bookings.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final b = bookings[i] as Map<String, dynamic>;

                final statusRu = _statusRu(b);
                final statusColor = _statusColor(statusRu);

                final serviceName =
                    b['service']?['name']?.toString() ?? 'Услуга';
                final bayId = b['bayId']?.toString() ?? '';
                final dateTimeIso = b['dateTime']?.toString() ?? '';

                final clientName = b['client']?['name']?.toString();
                final clientPhone = b['client']?['phone']?.toString();
                final clientTitle =
                    (clientName != null && clientName.isNotEmpty)
                    ? clientName
                    : (clientPhone ?? '');

                final plate = b['car']?['plateDisplay']?.toString() ?? '';
                final make = b['car']?['makeDisplay']?.toString() ?? '';
                final model = b['car']?['modelDisplay']?.toString() ?? '';
                final carLine = plate.isEmpty
                    ? ''
                    : 'Авто: $plate • $make $model';

                final clientComment = b['comment']?.toString();
                final hasComment =
                    clientComment != null && clientComment.trim().isNotEmpty;

                final time = dateTimeIso.isNotEmpty
                    ? _fmtTime(dateTimeIso)
                    : '--:--';

                final paid = (b['paidTotalRub'] as num?)?.toInt() ?? 0;
                final toPay = (b['remainingRub'] as num?)?.toInt() ?? 0;

                final ps = (b['paymentStatus'] ?? '').toString();
                final psRu = _paymentStatusRu(ps);

                final badges = (b['paymentBadges'] is List)
                    ? (b['paymentBadges'] as List)
                          .map((x) => x.toString())
                          .toList()
                    : <String>[];

                return ListTile(
                  title: Text('$time • $serviceName • Пост $bayId'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(clientTitle),
                      if (carLine.isNotEmpty) Text(carLine),
                      if (hasComment)
                        Text('Комментарий: ${clientComment.trim()}'),
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
                              label: Text(
                                x == 'CARD'
                                    ? 'Карта'
                                    : x == 'CASH'
                                    ? 'Наличные'
                                    : 'Контракт',
                              ),
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
        child: Text(
          'Shift: $shiftId',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}

/* ========================= TAB 2: ПОСТЫ ========================= */

class BaysTab extends StatefulWidget {
  final AdminApiClient api;
  final SessionStore store;
  final AdminSession session;

  const BaysTab({
    super.key,
    required this.api,
    required this.store,
    required this.session,
  });

  @override
  State<BaysTab> createState() => _BaysTabState();
}

class _BaysTabState extends State<BaysTab> {
  bool loading = true;
  String? error;

  final Map<int, bool> bayIsActive = {1: true, 2: true};

  @override
  void initState() {
    super.initState();
    _loadBays();
  }

  Future<void> _loadBays() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final bays = await widget.api.listBays(
        widget.session.userId,
        widget.session.activeShiftId!,
      );

      final map = <int, bool>{};
      for (final x in bays) {
        if (x is Map<String, dynamic>) {
          final n = (x['number'] as num?)?.toInt();
          final a = x['isActive'];
          if (n != null && n >= 1 && n <= 20) {
            map[n] = a == true;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        bayIsActive[1] = map[1] ?? bayIsActive[1] ?? true;
        bayIsActive[2] = map[2] ?? bayIsActive[2] ?? true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _toggleBay(int bayNumber) async {
    final isOpen = bayIsActive[bayNumber] ?? true;
    final uid = widget.session.userId;
    final sid = widget.session.activeShiftId!;

    try {
      if (isOpen) {
        final ctrl = TextEditingController(text: 'Ремонт/тех.перерыв');
        final ok = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Text('Закрыть пост $bayNumber'),
            content: TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Причина (обязательно)',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Закрыть'),
              ),
            ],
          ),
        );
        if (ok != true) return;

        final reason = ctrl.text.trim();
        if (reason.isEmpty) {
          setState(() => error = 'Причина закрытия поста обязательна');
          return;
        }

        await widget.api.setBayActive(
          uid,
          sid,
          bayNumber: bayNumber,
          isActive: false,
          reason: reason,
        );
      } else {
        // OPEN: no reason
        await widget.api.setBayActive(
          uid,
          sid,
          bayNumber: bayNumber,
          isActive: true,
        );
      }

      await _loadBays();
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    }
  }

  Widget _bayCard(int bayNumber) {
    final isOpen = bayIsActive[bayNumber] ?? true;

    final statusText = isOpen ? 'ОТКРЫТ' : 'ЗАКРЫТ';
    final statusIcon = isOpen ? Icons.check_circle : Icons.cancel;
    final statusColor = isOpen ? Colors.green : Colors.red;

    final btnText = isOpen ? 'Закрыть пост' : 'Открыть пост';
    final btnIcon = isOpen ? Icons.lock : Icons.lock_open;

    final button = isOpen
        ? OutlinedButton.icon(
            onPressed: loading ? null : () => _toggleBay(bayNumber),
            icon: Icon(btnIcon),
            label: Text(btnText),
          )
        : FilledButton.icon(
            onPressed: loading ? null : () => _toggleBay(bayNumber),
            icon: Icon(btnIcon),
            label: Text(btnText),
          );

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Пост $bayNumber',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(statusIcon, color: statusColor),
                const SizedBox(width: 8),
                Text(
                  statusText,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: button),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shiftId = widget.session.activeShiftId ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Посты'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadBays),
          const SizedBox(width: 8),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            )
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [_bayCard(1), const SizedBox(width: 10), _bayCard(2)],
              ),
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          'Shift: $shiftId',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}

/* ========================= TAB 3: ОЧЕРЕДЬ ========================= */

class WaitlistTab extends StatefulWidget {
  final AdminApiClient api;
  final SessionStore store;
  final AdminSession session;

  const WaitlistTab({
    super.key,
    required this.api,
    required this.store,
    required this.session,
  });

  @override
  State<WaitlistTab> createState() => _WaitlistTabState();
}

class _WaitlistTabState extends State<WaitlistTab> {
  bool loading = true;
  String? error;

  List<dynamic> waitlist = [];
  DateTime selectedDay = DateTime.now();

  String get _ymd => DateFormat('yyyy-MM-dd').format(selectedDay);

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  String _ruTitle() {
    final d = selectedDay;
    final dayName = DateFormat('EEEE', 'ru_RU').format(d);
    final date = DateFormat('d MMMM y', 'ru_RU').format(d);
    return '${_cap(dayName)} • $date';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _shiftDay(int deltaDays) {
    setState(() => selectedDay = selectedDay.add(Duration(days: deltaDays)));
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final wl = await widget.api.waitlistDay(
        widget.session.userId,
        widget.session.activeShiftId!,
        _ymd,
      );
      if (!mounted) return;
      setState(() => waitlist = wl);
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

  @override
  Widget build(BuildContext context) {
    final shiftId = widget.session.activeShiftId ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(_ruTitle()),
        actions: [
          IconButton(
            tooltip: 'Вчера',
            onPressed: () => _shiftDay(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Сегодня',
            onPressed: () {
              setState(() => selectedDay = DateTime.now());
              _load();
            },
            icon: const Icon(Icons.today),
          ),
          IconButton(
            tooltip: 'Завтра',
            onPressed: () => _shiftDay(1),
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          const SizedBox(width: 8),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            )
          : waitlist.isEmpty
          ? const Center(child: Text('Очередь пуста'))
          : ListView.separated(
              itemCount: waitlist.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final w = waitlist[i] as Map<String, dynamic>;

                final dtIso = (w['desiredDateTime'] ?? w['dateTime'] ?? '')
                    .toString();
                final time = dtIso.isNotEmpty ? _fmtTime(dtIso) : '--:--';

                final bay = (w['desiredBayId'] ?? w['bayId'] ?? '').toString();
                final serviceName =
                    w['service']?['name']?.toString() ?? 'Услуга';

                final clientName = w['client']?['name']?.toString();
                final clientPhone = w['client']?['phone']?.toString();
                final clientTitle =
                    (clientName != null && clientName.isNotEmpty)
                    ? clientName
                    : (clientPhone ?? '');

                final plate = w['car']?['plateDisplay']?.toString() ?? '';
                final make = w['car']?['makeDisplay']?.toString() ?? '';
                final model = w['car']?['modelDisplay']?.toString() ?? '';
                final carLine = plate.isEmpty ? '' : '$plate • $make $model';

                final reason = (w['reason'] ?? w['waitlistReason'] ?? '')
                    .toString();

                return ListTile(
                  title: Text(
                    '$time • Пост ${bay.isEmpty ? "—" : bay} • $serviceName',
                  ),
                  subtitle: Text(
                    '$clientTitle${carLine.isEmpty ? "" : "\n$carLine"}\n'
                    'Причина: ${reason.isEmpty ? "—" : reason}',
                  ),
                  isThreeLine: true,
                );
              },
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          'Shift: $shiftId',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}
