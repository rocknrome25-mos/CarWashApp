// C:\dev\carwash\admin_module\lib\features\calendar\calendar_page.dart
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
  List<dynamic> waitlist = [];

  // bays state (show 1/2)
  final Map<int, bool> bayIsActive = {1: true, 2: true};

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

  void _showSnack(ScaffoldMessengerState messenger, String text) {
    messenger.showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final uid = widget.session.userId;
      final sid = widget.session.activeShiftId ?? '';
      if (sid.isEmpty) throw Exception('Нет активной смены. Перезайди.');

      final list = await widget.api.calendarDay(uid, sid, _ymd);
      final wl = await widget.api.waitlistDay(uid, sid, _ymd);

      // bay states from backend
      final bays = await widget.api.listBays(uid, sid);
      final map = <int, bool>{};

      for (final x in bays) {
        if (x is Map<String, dynamic>) {
          final n = (x['number'] as num?)?.toInt();
          final a = x['isActive'];
          if (n != null && n >= 1 && n <= 50) {
            map[n] = a == true;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        bookings = list;
        waitlist = wl;

        if (map.isNotEmpty) {
          bayIsActive[1] = map[1] ?? (bayIsActive[1] ?? true);
          bayIsActive[2] = map[2] ?? (bayIsActive[2] ?? true);
        }
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ---------------- formatting ----------------

  String _fmtTime(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    return DateFormat('HH:mm').format(dt);
  }

  String _fmtDateShort(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    return DateFormat('dd.MM').format(dt);
  }

  // ---------------- status ----------------

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

  // ---------------- requested bay dot ----------------

  int? _assignedBayId(Map<String, dynamic> b) {
    final bay = b['bayId'];
    final n = (bay is num) ? bay.toInt() : int.tryParse(bay?.toString() ?? '');
    return n;
  }

  String _assignedBayTitle(Map<String, dynamic> b) {
    final n = _assignedBayId(b);
    if (n == null) return 'Пост —';
    return 'Пост $n';
  }

  int? _requestedBayId(Map<String, dynamic> b) {
    final v = b['requestedBayId'];
    if (v == null) return null; // null => any => no dot
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static const Color _greenLine = Color(0xFF2DBD6E);
  static const Color _blueLine = Color(0xFF2D9CDB);

  Color _requestedBayColor(int bayId) {
    if (bayId == 1) return _greenLine;
    if (bayId == 2) return _blueLine;
    return Colors.grey;
  }

  Widget _requestedDot(Map<String, dynamic> b) {
    final req = _requestedBayId(b);
    if (req == null) return const SizedBox.shrink();

    final c = _requestedBayColor(req);

    return Container(
      width: 12,
      height: 12,
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }

  Widget _postWithRequestedDot(Map<String, dynamic> b) {
    final postTitle = _assignedBayTitle(b);
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(postTitle, style: const TextStyle(fontWeight: FontWeight.w900)),
        _requestedDot(b),
      ],
    );
  }

  // ---------------- shift close ----------------

  Future<void> _closeShiftNoCash() async {
    final userId = widget.session.userId;
    final shiftId = widget.session.activeShiftId ?? '';
    if (shiftId.isEmpty) return;

    // capture messenger BEFORE async gap
    final messenger = ScaffoldMessenger.of(context);

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
      if (mounted) setState(() => error = e.toString());
      _showSnack(messenger, 'Ошибка: $e');
    }
  }

  Future<void> _closeShiftWithCash() async {
    final userId = widget.session.userId;
    final shiftId = widget.session.activeShiftId ?? '';
    if (shiftId.isEmpty) return;

    // capture messenger BEFORE async gap
    final messenger = ScaffoldMessenger.of(context);

    try {
      final exp = await widget.api.cashExpected(userId, shiftId);
      if (!mounted) return;

      final expectedRub = (exp['expectedRub'] as num).toInt();

      final countedCtrl = TextEditingController(text: expectedRub.toString());
      final keepCtrl = TextEditingController(text: expectedRub.toString());
      final handoverCtrl = TextEditingController(text: '0');
      final noteCtrl = TextEditingController(text: '');

      String lastEdited = 'keep'; // 'keep' or 'handover'

      void recalcFromKeep() {
        final counted = int.tryParse(countedCtrl.text.trim()) ?? 0;
        var keep = int.tryParse(keepCtrl.text.trim()) ?? 0;
        if (keep < 0) keep = 0;
        if (keep > counted) keep = counted;
        final handover = counted - keep;
        handoverCtrl.text = handover.toString();
      }

      void recalcFromHandover() {
        final counted = int.tryParse(countedCtrl.text.trim()) ?? 0;
        var handover = int.tryParse(handoverCtrl.text.trim()) ?? 0;
        if (handover < 0) handover = 0;
        if (handover > counted) handover = counted;
        final keep = counted - handover;
        keepCtrl.text = keep.toString();
      }

      recalcFromKeep();

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
                        onChanged: (_) {
                          if (lastEdited == 'handover') {
                            recalcFromHandover();
                          } else {
                            recalcFromKeep();
                          }
                          setStateDialog(() {});
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: keepCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Оставить в кассе (перенос) (₽)',
                        ),
                        onChanged: (_) {
                          lastEdited = 'keep';
                          recalcFromKeep();
                          setStateDialog(() {});
                        },
                      ),
                      TextField(
                        controller: handoverCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Сдать инкассатору/владельцу (₽)',
                        ),
                        onChanged: (_) {
                          lastEdited = 'handover';
                          recalcFromHandover();
                          setStateDialog(() {});
                        },
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
      final keep = int.tryParse(keepCtrl.text.trim()) ?? 0;
      final handover = int.tryParse(handoverCtrl.text.trim()) ?? 0;
      final note = noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim();

      if (keep < 0 || handover < 0 || keep + handover != counted) {
        throw Exception(
          'Проверь суммы: "оставить + сдать" должно равняться "фактически в кассе".',
        );
      }

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
      if (mounted) setState(() => error = e.toString());
      _showSnack(messenger, 'Ошибка: $e');
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
    _loadAll();
  }

  // ---------------- bays cards ----------------

  Future<void> _toggleBayCard(int bayNumber) async {
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
          if (mounted) {
            setState(() => error = 'Причина закрытия поста обязательна');
          }
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

      await _loadAll();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
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
            onPressed: loading ? null : () => _toggleBayCard(bayNumber),
            icon: Icon(btnIcon),
            label: Text(btnText),
          )
        : FilledButton.icon(
            onPressed: loading ? null : () => _toggleBayCard(bayNumber),
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

  Widget _baysRow() {
    return Row(children: [_bayCard(1), const SizedBox(width: 10), _bayCard(2)]);
  }

  // ---------------- booking row ----------------

  Widget _bookingRow(Map<String, dynamic> b) {
    final cs = Theme.of(context).colorScheme;

    final statusRu = _statusRu(b);
    final statusColor = _statusColor(statusRu);

    final serviceName = b['service']?['name']?.toString() ?? 'Услуга';
    final dateTimeIso = b['dateTime']?.toString() ?? '';
    final time = dateTimeIso.isNotEmpty ? _fmtTime(dateTimeIso) : '--:--';

    final clientName = b['client']?['name']?.toString();
    final clientPhone = b['client']?['phone']?.toString();
    final clientTitle = (clientName != null && clientName.isNotEmpty)
        ? clientName
        : (clientPhone ?? '');

    final make = b['car']?['makeDisplay']?.toString() ?? '';
    final model = b['car']?['modelDisplay']?.toString() ?? '';
    final plate = b['car']?['plateDisplay']?.toString() ?? '';
    final body = b['car']?['bodyType']?.toString() ?? '';
    final carTitle = [
      if (plate.trim().isNotEmpty) plate.trim(),
      if ('$make $model'.trim().isNotEmpty) '$make $model'.trim(),
      if (body.trim().isNotEmpty) body.trim(),
    ].join(' • ');

    final paid = (b['paidTotalRub'] as num?)?.toInt() ?? 0;
    final toPay = (b['remainingRub'] as num?)?.toInt() ?? 0;

    final ps = (b['paymentStatus'] ?? '').toString();
    final psRu = _paymentStatusRu(ps);

    Widget statusPill() {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: statusColor.withValues(alpha: 0.8)),
        ),
        child: Text(
          statusRu,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: statusColor,
            fontSize: 12,
          ),
        ),
      );
    }

    return InkWell(
      onTap: () async {
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => BookingActionsSheet(
            api: widget.api,
            session: widget.session,
            booking: b,
            onDone: _loadAll,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    time,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    serviceName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    clientTitle,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (carTitle.isNotEmpty)
                    Text(
                      carTitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _postWithRequestedDot(b),
                  const SizedBox(height: 10),
                  statusPill(),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    psRu,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Оплачено: $paid ₽',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                  Text(
                    'К оплате: $toPay ₽',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface.withValues(alpha: 0.75),
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

  // ---------------- WAITLIST ----------------

  String _wlClientTitle(Map<String, dynamic> w) {
    final cn = w['client']?['name']?.toString();
    final cp = w['client']?['phone']?.toString();
    if (cn != null && cn.trim().isNotEmpty) return cn.trim();
    return (cp ?? '').toString().trim();
  }

  String _wlCarTitle(Map<String, dynamic> w) {
    final plate = w['car']?['plateDisplay']?.toString() ?? '';
    final make = w['car']?['makeDisplay']?.toString() ?? '';
    final model = w['car']?['modelDisplay']?.toString() ?? '';
    final s = '${plate.trim()} ${make.trim()} ${model.trim()}'.trim();
    return s.isEmpty ? '—' : s;
  }

  String _wlReqText(Map<String, dynamic> w) {
    final bayReq =
        w['desiredBayId'] ?? w['requestedBayId'] ?? w['requestedBayNumber'];
    final req = (bayReq is num)
        ? bayReq.toInt()
        : int.tryParse(bayReq?.toString() ?? '');
    if (req == null) return 'Запрошено: Любая';
    if (req == 1) return 'Запрошено: Зелёная';
    if (req == 2) return 'Запрошено: Синяя';
    return 'Запрошено: Пост $req';
  }

  Future<void> _openWaitlistConvertSheet(Map<String, dynamic> w) async {
    final uid = widget.session.userId;
    final sid = widget.session.activeShiftId ?? '';
    if (sid.isEmpty) return;

    final waitlistId = (w['id'] ?? '').toString().trim();
    if (waitlistId.isEmpty) return;

    final desiredIso = (w['desiredDateTime'] ?? w['dateTime'] ?? '')
        .toString()
        .trim();

    DateTime selectedLocal = DateTime.now();
    if (desiredIso.isNotEmpty) {
      selectedLocal =
          DateTime.tryParse(desiredIso)?.toLocal() ?? DateTime.now();
    }

    int selectedBay = 1;
    final bayReq =
        w['desiredBayId'] ?? w['requestedBayId'] ?? w['requestedBayNumber'];
    final req = (bayReq is num)
        ? bayReq.toInt()
        : int.tryParse(bayReq?.toString() ?? '');
    if (req == 1 || req == 2) selectedBay = req!;

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (ctx, setSheet) {
              final cs = Theme.of(ctx).colorScheme;

              bool converting = false;

              Future<void> pickDateTime() async {
                final date = await showDatePicker(
                  context: ctx,
                  initialDate: selectedLocal,
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 60)),
                );
                if (date == null) return;

                if (!mounted) return;

                final time = await showTimePicker(
                  context: context, // ✅ вместо ctx
                  initialTime: TimeOfDay.fromDateTime(selectedLocal),
                );
                if (time == null) return;

                setSheet(() {
                  selectedLocal = DateTime(
                    date.year,
                    date.month,
                    date.day,
                    time.hour,
                    time.minute,
                  );
                });
              }

              Future<void> convert() async {
                if (converting) return;
                setSheet(() => converting = true);

                // capture messenger BEFORE async gap (fix lint)
                final messenger = ScaffoldMessenger.of(context);

                try {
                  final isoUtc = selectedLocal.toUtc().toIso8601String();

                  await widget.api.convertWaitlistToBooking(
                    uid,
                    sid,
                    waitlistId,
                    bayId: selectedBay,
                    dateTimeIso: isoUtc,
                  );

                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();

                  if (!mounted) return;
                  await _loadAll();

                  if (!mounted) return;
                  _showSnack(messenger, 'Создано');
                } catch (e) {
                  if (mounted) _showSnack(messenger, 'Ошибка: $e');
                } finally {
                  if (ctx.mounted) setSheet(() => converting = false);
                }
              }

              String dtLabel() =>
                  DateFormat('dd.MM HH:mm').format(selectedLocal);

              return Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 10,
                  bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Перевести из ожидания',
                            style: Theme.of(ctx).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.6),
                        ),
                        color: cs.surfaceContainerHighest.withValues(
                          alpha: 0.18,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _wlClientTitle(w),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _wlCarTitle(w),
                            style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            w['service']?['name']?.toString() ?? 'Услуга',
                            style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _wlReqText(w),
                            style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: converting ? null : pickDateTime,
                            icon: const Icon(Icons.schedule),
                            label: Text(dtLabel()),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 140,
                          child: DropdownButtonFormField<int>(
                            initialValue: selectedBay,
                            decoration: const InputDecoration(
                              labelText: 'Пост',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 1,
                                child: Text('Зелёная'),
                              ),
                              DropdownMenuItem(value: 2, child: Text('Синяя')),
                            ],
                            onChanged: converting
                                ? null
                                : (v) => setSheet(() => selectedBay = v ?? 1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: converting ? null : convert,
                        icon: converting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.done),
                        label: Text(
                          converting ? 'Создаю...' : 'Создать запись',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _waitlistSection() {
    if (waitlist.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Ожидание',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '${waitlist.length}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...waitlist.map((x) {
            final w = x as Map<String, dynamic>;

            final dtIso = (w['desiredDateTime'] ?? w['dateTime'] ?? '')
                .toString();
            final time = dtIso.isNotEmpty ? _fmtTime(dtIso) : '--:--';
            final dateShort = dtIso.isNotEmpty ? _fmtDateShort(dtIso) : '';

            final reqText = _wlReqText(w);
            final serviceName = w['service']?['name']?.toString() ?? 'Услуга';

            final clientTitle = _wlClientTitle(w);
            final carLine = _wlCarTitle(w);

            final reason = (w['reason'] ?? w['waitlistReason'] ?? '')
                .toString();

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                color: Colors.black.withValues(alpha: 0.02),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$time${dateShort.isEmpty ? '' : ' • $dateShort'} • $serviceName',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          clientTitle,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          carLine,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black.withValues(alpha: 0.70),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$reqText\nПричина: ${reason.isEmpty ? "—" : reason}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: loading
                        ? null
                        : () => _openWaitlistConvertSheet(w),
                    child: const Text('В очередь'),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
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
              _loadAll();
            },
            icon: const Icon(Icons.today),
          ),
          IconButton(
            tooltip: 'Завтра',
            onPressed: () => _shiftDay(1),
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAll),
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
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: _baysRow(),
                ),
                _waitlistSection(),
                const SizedBox(height: 6),
                Expanded(
                  child: bookings.isEmpty
                      ? const Center(child: Text('Нет записей'))
                      : ListView.builder(
                          itemCount: bookings.length,
                          itemBuilder: (context, i) {
                            final b = bookings[i] as Map<String, dynamic>;
                            return _bookingRow(b);
                          },
                        ),
                ),
              ],
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
