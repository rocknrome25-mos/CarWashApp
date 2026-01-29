import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/admin_api_client.dart';
import '../../core/models/admin_session.dart';
import '../../core/realtime/realtime_client.dart';
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
  int idx = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: idx,
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
        selectedIndex: idx,
        onDestinationSelected: (v) => setState(() => idx = v),
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

  // realtime
  late final RealtimeClient _rt;
  StreamSubscription<BookingRealtimeEvent>? _rtSub;
  Timer? _rtDebounce;

  // Dispatcher tabs: Bay 1 / Bay 2
  int bayTab = 0; // 0 => bay 1, 1 => bay 2

  bool get cashEnabled =>
      widget.session.featureOn('CASH_DRAWER', defaultValue: true);

  String get ymd => DateFormat('yyyy-MM-dd').format(selectedDay);

  String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  String ruTitle() {
    final d = selectedDay;
    final dayName = DateFormat('EEEE', 'ru_RU').format(d);
    final date = DateFormat('d MMMM y', 'ru_RU').format(d);
    return '${cap(dayName)} • $date';
  }

  @override
  void initState() {
    super.initState();
    _rt = RealtimeClient(baseHttpUrl: widget.api.baseUrl);
    _rt.connect();
    _subscribeRealtime();
    load();
  }

  @override
  void dispose() {
    _rtDebounce?.cancel();
    _rtDebounce = null;

    _rtSub?.cancel();
    _rtSub = null;

    _rt.close();
    super.dispose();
  }

  void _subscribeRealtime() {
    _rtSub?.cancel();
    _rtSub = _rt.events.listen((ev) {
      if (ev.type != 'booking.changed') return;

      final loc = widget.session.locationId.trim();
      if (loc.isEmpty) return;

      if (ev.locationId.trim() != loc) return;

      // debounce burst
      _rtDebounce?.cancel();
      _rtDebounce = Timer(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        load(); // refresh list
      });
    });
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final sid = widget.session.activeShiftId ?? '';
      if (sid.isEmpty) throw Exception('Нет активной смены. Перезайди.');

      final list = await widget.api.calendarDay(
        widget.session.userId,
        sid,
        ymd,
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

  void shiftDay(int deltaDays) {
    setState(() => selectedDay = selectedDay.add(Duration(days: deltaDays)));
    load();
  }

  String statusRu(Map<String, dynamic> b) {
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

  Color statusColor(String s) {
    switch (s) {
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

  String paymentStatusRu(String ps) {
    if (ps == 'PAID') return 'ОПЛАЧЕНО';
    if (ps == 'PARTIAL') return 'ЧАСТИЧНО';
    if (ps == 'UNPAID') return 'НЕ ОПЛАЧЕНО';
    return ps;
  }

  IconData payIcon(String x) {
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

  Future<void> closeShiftNoCash() async {
    final userId = widget.session.userId;
    final shiftId = widget.session.activeShiftId ?? '';
    if (shiftId.isEmpty) return;

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

  Future<void> closeShiftWithCash() async {
    final userId = widget.session.userId;
    final shiftId = widget.session.activeShiftId ?? '';
    if (shiftId.isEmpty) return;

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
                            style: const TextStyle(fontWeight: FontWeight.w800),
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
                              fontWeight: FontWeight.w800,
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

  Future<void> closeShift() async {
    if (cashEnabled) {
      await closeShiftWithCash();
    } else {
      await closeShiftNoCash();
    }
  }

  int _bayIdOf(dynamic x) {
    if (x is Map<String, dynamic>) {
      final v = x['bayId'];
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse('${x['bayId']}') ?? 0;
    }
    return 0;
  }

  List<Map<String, dynamic>> _bayBookings(int bayId) {
    final out = <Map<String, dynamic>>[];
    for (final x in bookings) {
      if (x is Map<String, dynamic>) {
        if (_bayIdOf(x) == bayId) out.add(x);
      }
    }
    // Server already returns bayId asc + dateTime asc, but keep it safe:
    out.sort((a, b) {
      final ad =
          DateTime.tryParse((a['dateTime'] ?? '').toString()) ?? DateTime(1970);
      final bd =
          DateTime.tryParse((b['dateTime'] ?? '').toString()) ?? DateTime(1970);
      return ad.compareTo(bd);
    });
    return out;
  }

  Widget _bayTabs(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // You said: bay1 green line, bay2 blue line.
    // Keep subtle: thin top indicator like Yandex segmented tabs.
    Color indicatorColor(int index) {
      if (index == 0) return const Color(0xFF2DBD6E); // green
      return const Color(0xFF2D9CDB); // blue
    }

    Widget tabButton({required int index, required String label}) {
      final selected = bayTab == index;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => bayTab = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? cs.surface
                  : cs.surfaceContainerHighest.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? cs.outlineVariant.withValues(alpha: 0.7)
                    : cs.outlineVariant.withValues(alpha: 0.35),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                        color: Colors.black.withValues(alpha: 0.05),
                      ),
                    ]
                  : const [],
            ),
            child: Column(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: selected
                        ? cs.onSurface
                        : cs.onSurface.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 3,
                  width: 46,
                  decoration: BoxDecoration(
                    color: selected
                        ? indicatorColor(index)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          tabButton(index: 0, label: 'Пост 1'),
          const SizedBox(width: 10),
          tabButton(index: 1, label: 'Пост 2'),
        ],
      ),
    );
  }

  Widget _bookingCard(BuildContext context, Map<String, dynamic> b) {
    final cs = Theme.of(context).colorScheme;

    final st = statusRu(b);
    final stColor = statusColor(st);

    final serviceName = b['service']?['name']?.toString() ?? 'Услуга';
    final bayId = b['bayId']?.toString() ?? '';

    final dateTimeIso = b['dateTime']?.toString() ?? '';
    final time = dateTimeIso.isNotEmpty
        ? DateFormat('HH:mm').format(DateTime.parse(dateTimeIso).toLocal())
        : '--:--';

    final clientName = b['client']?['name']?.toString();
    final clientPhone = b['client']?['phone']?.toString();
    final clientTitle = (clientName != null && clientName.isNotEmpty)
        ? clientName
        : (clientPhone ?? '');

    final plate = b['car']?['plateDisplay']?.toString() ?? '';
    final make = b['car']?['makeDisplay']?.toString() ?? '';
    final model = b['car']?['modelDisplay']?.toString() ?? '';
    final carLine = plate.isEmpty ? '' : '$plate • $make $model';

    final paid = (b['paidTotalRub'] as num?)?.toInt() ?? 0;
    final toPay = (b['remainingRub'] as num?)?.toInt() ?? 0;

    final ps = (b['paymentStatus'] ?? '').toString();
    final psRu = paymentStatusRu(ps);

    final badges = (b['paymentBadges'] is List)
        ? (b['paymentBadges'] as List).map((x) => x.toString()).toList()
        : <String>[];

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => BookingActionsSheet(
            api: widget.api,
            session: widget.session,
            booking: b,
            onDone: load,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              blurRadius: 10,
              offset: const Offset(0, 6),
              color: Colors.black.withValues(alpha: 0.04),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // LEFT
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    time,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    serviceName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    clientTitle,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  if (carLine.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      carLine,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),

            // MIDDLE
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Пост $bayId',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: stColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: stColor),
                    ),
                    child: Text(
                      st,
                      style: TextStyle(
                        color: stColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // RIGHT
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    psRu,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Оплачено: $paid ₽\nК оплате: $toPay ₽',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                  if (badges.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final x in badges)
                          Chip(
                            avatar: Icon(payIcon(x), size: 18),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bayId = bayTab == 0 ? 1 : 2;
    final list = _bayBookings(bayId);

    return Scaffold(
      appBar: AppBar(
        title: Text(ruTitle()),
        actions: [
          IconButton(
            tooltip: 'Вчера',
            onPressed: () => shiftDay(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Сегодня',
            onPressed: () {
              setState(() => selectedDay = DateTime.now());
              load();
            },
            icon: const Icon(Icons.today),
          ),
          IconButton(
            tooltip: 'Завтра',
            onPressed: () => shiftDay(1),
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: load),
          TextButton(onPressed: closeShift, child: const Text('Закрыть смену')),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _bayTabs(context),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : (error != null)
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  )
                : list.isEmpty
                ? Center(
                    child: Text(
                      'Нет записей на Пост $bayId',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      return _bookingCard(context, list[i]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/* ========================= TAB 2: ПОСТЫ ========================= */
/* (оставляю как у тебя сейчас — менять под realtime не нужно) */

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
    loadBays();
  }

  Future<void> loadBays() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final sid = widget.session.activeShiftId ?? '';
      if (sid.isEmpty) throw Exception('Нет активной смены. Перезайди.');

      final bays = await widget.api.listBays(widget.session.userId, sid);

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
        bayIsActive[1] = map[1] ?? (bayIsActive[1] ?? true);
        bayIsActive[2] = map[2] ?? (bayIsActive[2] ?? true);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> toggleBay(int bayNumber) async {
    final isOpen = bayIsActive[bayNumber] ?? true;
    final uid = widget.session.userId;
    final sid = widget.session.activeShiftId ?? '';
    if (sid.isEmpty) return;

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
        await widget.api.setBayActive(
          uid,
          sid,
          bayNumber: bayNumber,
          isActive: true,
        );
      }

      await loadBays();
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    }
  }

  Widget bayCard(int bayNumber) {
    final cs = Theme.of(context).colorScheme;
    final isOpen = bayIsActive[bayNumber] ?? true;

    final statusText = isOpen ? 'ОТКРЫТ' : 'ЗАКРЫТ';
    final statusIcon = isOpen ? Icons.check_circle : Icons.cancel;
    final statusColor = isOpen ? Colors.green : Colors.red;

    final btnText = isOpen ? 'Закрыть пост' : 'Открыть пост';
    final btnIcon = isOpen ? Icons.lock : Icons.lock_open;

    final button = isOpen
        ? OutlinedButton.icon(
            onPressed: loading ? null : () => toggleBay(bayNumber),
            icon: Icon(btnIcon),
            label: Text(btnText),
          )
        : FilledButton.icon(
            onPressed: loading ? null : () => toggleBay(bayNumber),
            icon: Icon(btnIcon),
            label: Text(btnText),
          );

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              blurRadius: 10,
              offset: const Offset(0, 6),
              color: Colors.black.withValues(alpha: 0.04),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Пост $bayNumber',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
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
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: button),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Посты'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: loadBays),
          const SizedBox(width: 8),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : (error != null)
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [bayCard(1), const SizedBox(width: 10), bayCard(2)],
              ),
            ),
    );
  }
}

/* ========================= TAB 3: ОЖИДАНИЕ ========================= */
/* (без realtime пока — подключим позже, если захочешь автообновление и тут) */

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

  String get ymd => DateFormat('yyyy-MM-dd').format(selectedDay);

  String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  String ruTitle() {
    final d = selectedDay;
    final dayName = DateFormat('EEEE', 'ru_RU').format(d);
    final date = DateFormat('d MMMM y', 'ru_RU').format(d);
    return '${cap(dayName)} • $date';
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  void shiftDay(int deltaDays) {
    setState(() => selectedDay = selectedDay.add(Duration(days: deltaDays)));
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final sid = widget.session.activeShiftId ?? '';
      if (sid.isEmpty) throw Exception('Нет активной смены. Перезайди.');

      final wl = await widget.api.waitlistDay(widget.session.userId, sid, ymd);
      if (!mounted) return;
      setState(() => waitlist = wl);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String fmtTime(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    return DateFormat('HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(ruTitle()),
        actions: [
          IconButton(
            tooltip: 'Вчера',
            onPressed: () => shiftDay(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Сегодня',
            onPressed: () {
              setState(() => selectedDay = DateTime.now());
              load();
            },
            icon: const Icon(Icons.today),
          ),
          IconButton(
            tooltip: 'Завтра',
            onPressed: () => shiftDay(1),
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: load),
          const SizedBox(width: 8),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : (error != null)
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
            )
          : waitlist.isEmpty
          ? const Center(child: Text('Очередь пуста'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              itemCount: waitlist.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final w = waitlist[i] as Map<String, dynamic>;

                final dtIso = (w['desiredDateTime'] ?? w['dateTime'] ?? '')
                    .toString();
                final time = dtIso.isNotEmpty ? fmtTime(dtIso) : '--:--';

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

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.6),
                    ),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                        color: Colors.black.withValues(alpha: 0.04),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$time • Пост ${bay.isEmpty ? '—' : bay} • $serviceName',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        clientTitle,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      if (carLine.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          carLine,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Причина: ${reason.isEmpty ? '—' : reason}',
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
