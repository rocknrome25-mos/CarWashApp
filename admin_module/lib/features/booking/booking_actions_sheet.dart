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

  final noteCtrl = TextEditingController();

  static const _moveReasons = <String>[
    'Задержка',
    'Сбой',
    'Передумал',
    'Другое',
  ];
  String moveReasonKind = _moveReasons.first;
  final moveCommentCtrl = TextEditingController();
  bool clientAgreed = true;

  int selectedBay = 1;
  DateTime? selectedDateTimeLocal;

  String paymentMethod = 'CARD'; // CARD / CASH / CONTRACT

  final discountCtrl = TextEditingController(text: '0');
  final discountReasonCtrl = TextEditingController(text: '');

  bool get _moveEnabled =>
      widget.session.featureOn('BOOKING_MOVE', defaultValue: true);
  bool get _cashEnabled =>
      widget.session.featureOn('CASH_DRAWER', defaultValue: true);
  bool get _contractEnabled =>
      widget.session.featureOn('CONTRACT_PAYMENTS', defaultValue: true);
  bool get _discountEnabled =>
      widget.session.featureOn('DISCOUNTS', defaultValue: true);

  String get _userId => widget.session.userId;
  String get _shiftId => widget.session.activeShiftId ?? '';
  String get _bookingId => widget.booking['id'] as String;

  @override
  void initState() {
    super.initState();

    final bayId = widget.booking['bayId'];
    if (bayId is num) {
      selectedBay = bayId.toInt();
    }

    final adminNote = widget.booking['adminNote'];
    if (adminNote is String && adminNote.trim().isNotEmpty) {
      noteCtrl.text = adminNote.trim();
    }

    final dtIso = widget.booking['dateTime']?.toString();
    if (dtIso != null && dtIso.isNotEmpty) {
      selectedDateTimeLocal = DateTime.parse(dtIso).toLocal();
    }

    paymentMethod = 'CARD';

    final dr = widget.booking['discountRub'];
    if (dr is num) {
      discountCtrl.text = dr.toInt().toString();
    }

    final dn = widget.booking['discountNote'];
    if (dn is String && dn.trim().isNotEmpty) {
      discountReasonCtrl.text = dn.trim();
    }
  }

  @override
  void dispose() {
    noteCtrl.dispose();
    moveCommentCtrl.dispose();
    discountCtrl.dispose();
    discountReasonCtrl.dispose();
    super.dispose();
  }

  // ---------- helpers ----------

  String _fmtTimeIso(String? iso) {
    if (iso == null || iso.isEmpty) return '--:--';
    final dt = DateTime.parse(iso).toLocal();
    return DateFormat('HH:mm').format(dt);
  }

  String _fmtDateTimeLocal(DateTime dt) =>
      DateFormat('yyyy-MM-dd HH:mm').format(dt);

  int _intOr0(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  String _rawStatus() => (widget.booking['status'] ?? '').toString();
  String? _startedAtIso() => widget.booking['startedAt']?.toString();
  String? _finishedAtIso() => widget.booking['finishedAt']?.toString();

  bool get _isCanceled => _rawStatus() == 'CANCELED';

  String get _statusRu {
    final startedAt = _startedAtIso();
    final finishedAt = _finishedAtIso();

    if (_isCanceled) return 'ОТМЕНЕНО';
    if (startedAt != null &&
        startedAt.isNotEmpty &&
        (finishedAt == null || finishedAt.isEmpty)) {
      return 'МОЕТСЯ';
    }

    switch (_rawStatus()) {
      case 'COMPLETED':
        return 'ЗАВЕРШЕНО';
      case 'ACTIVE':
      case 'PENDING_PAYMENT':
        return 'ОЖИДАЕТ';
      default:
        return _rawStatus();
    }
  }

  bool get _isCompletedRu => _statusRu == 'ЗАВЕРШЕНО';

  bool get _canStart =>
      !_isCanceled && !_isCompletedRu && _statusRu != 'МОЕТСЯ';
  bool get _canFinish => !_isCanceled && !_isCompletedRu;
  bool get _canMove => _moveEnabled && !_isCanceled && !_isCompletedRu;

  List<String> _paymentBadges() {
    final b = widget.booking['paymentBadges'];
    if (b is List) return b.map((x) => x.toString()).toList();
    return const [];
  }

  String _paymentStatus() => (widget.booking['paymentStatus'] ?? '').toString();
  String get _paymentStatusRu {
    final ps = _paymentStatus();
    if (ps == 'PAID') return 'ОПЛАЧЕНО';
    if (ps == 'PARTIAL') return 'ЧАСТИЧНО';
    if (ps == 'UNPAID') return 'НЕ ОПЛАЧЕНО';
    return ps;
  }

  int _paidTotalRub() => _intOr0(widget.booking['paidTotalRub']);
  int _toPayRub() => _intOr0(widget.booking['remainingRub']);
  int _discountRub() => _intOr0(widget.booking['discountRub']);
  int _effectivePriceRub() => _intOr0(widget.booking['effectivePriceRub']);

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

  Color _statusColor() {
    if (_statusRu == 'МОЕТСЯ') return Colors.blue;
    if (_statusRu == 'ЗАВЕРШЕНО') return Colors.green;
    if (_statusRu == 'ОТМЕНЕНО') return Colors.red;
    return Colors.orange;
  }

  // ---------- UX: Human errors ----------

  bool _isBayClosedError(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('409') &&
        (s.contains('bay is closed') ||
            s.contains('bay closed') ||
            s.contains('post is closed') ||
            s.contains('post closed') ||
            s.contains('пост закрыт') ||
            s.contains('bay_is_closed'));
  }

  Future<void> _showBayClosedDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        title: const Text('Пост закрыт'),
        content: const Text(
          'Чтобы начать обслуживание, откройте пост во вкладке «Посты».',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Ок'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    final m = msg.trim();
    if (m.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() => loading = true);
    try {
      await fn();
      widget.onDone();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      if (_isBayClosedError(e)) {
        await _showBayClosedDialog();
      } else {
        _showSnack(e.toString());
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ---------- actions ----------

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

    final toPay = _toPayRub();
    if (toPay > 0) {
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Оплата не завершена'),
          content: Text('К оплате: $toPay ₽.\nЗавершить услугу всё равно?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Завершить'),
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
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;

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
      _showSnack('Выбери новое время для переноса');
      return;
    }

    final comment = moveCommentCtrl.text.trim();
    if (comment.isEmpty) {
      _showSnack('Комментарий к переносу обязателен');
      return;
    }
    if (!clientAgreed) {
      _showSnack('Нужно подтвердить согласие клиента');
      return;
    }

    final newIsoUtc = dt.toUtc().toIso8601String();
    final reason = '$moveReasonKind: $comment';

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
    final toPay = _toPayRub();
    if (toPay <= 0) return;

    if (paymentMethod == 'CASH' && !_cashEnabled) {
      _showSnack('Наличные отключены для этого заказчика');
      return;
    }
    if (paymentMethod == 'CONTRACT' && !_contractEnabled) {
      _showSnack('Контракт отключён для этого заказчика');
      return;
    }

    await _run(() async {
      await widget.api.adminPayBooking(
        _userId,
        _shiftId,
        _bookingId,
        kind: 'REMAINING',
        amountRub: toPay,
        methodType: paymentMethod,
        methodLabel: paymentMethod,
        note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      );
    });
  }

  Future<void> _applyDiscount() async {
    if (!_discountEnabled) return;

    final v = int.tryParse(discountCtrl.text.trim()) ?? 0;
    if (v < 0) {
      _showSnack('Скидка не может быть отрицательной');
      return;
    }

    final reason = discountReasonCtrl.text.trim();
    if (reason.isEmpty) {
      _showSnack('Причина скидки обязательна');
      return;
    }

    await _run(() async {
      await widget.api.adminApplyDiscount(
        _userId,
        _shiftId,
        _bookingId,
        discountRub: v,
        reason: reason,
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

    if (!choices.contains(paymentMethod)) paymentMethod = 'CARD';

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in choices)
          ChoiceChip(
            label: Text(label(v)),
            selected: paymentMethod == v,
            onSelected: loading
                ? null
                : (_) => setState(() => paymentMethod = v),
          ),
      ],
    );
  }

  Widget _sectionCard({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _statusPill(String text) {
    final c = _statusColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.7)),
      ),
      child: Text(
        text,
        style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final b = widget.booking;

    final serviceName = b['service']?['name']?.toString() ?? 'Услуга';
    final bayIdStr = b['bayId']?.toString() ?? '';

    final clientName = b['client']?['name']?.toString();
    final clientPhone = b['client']?['phone']?.toString();
    final clientTitle = (clientName != null && clientName.isNotEmpty)
        ? clientName
        : (clientPhone ?? '');

    final plate = b['car']?['plateDisplay']?.toString() ?? '';
    final make = b['car']?['makeDisplay']?.toString() ?? '';
    // ВАЖНО: модель у клиента может отсутствовать. Если пусто — не включаем вообще.
    final modelRaw = b['car']?['modelDisplay'];
    final model = modelRaw == null ? '' : modelRaw.toString().trim();

    final color = b['car']?['color']?.toString();
    final body = b['car']?['bodyType']?.toString();

    // ✅ FIX: собираем "Авто" без лишних "—" и без пустой модели.
    // Порядок: plate • make • body • color (или make • plate — на вкус; оставил plate первым как раньше у тебя)
    final carParts = <String>[];
    if (plate.trim().isNotEmpty) carParts.add(plate.trim());

    final makePart = make.trim();
    if (makePart.isNotEmpty) carParts.add(makePart);

    // если вдруг модель всё-таки есть — добавим (но у тебя сейчас нет)
    if (model.isNotEmpty) carParts.add(model);

    if (body != null && body.trim().isNotEmpty) carParts.add(body.trim());
    if (color != null && color.trim().isNotEmpty) carParts.add(color.trim());

    final carLine = carParts.isEmpty ? '—' : carParts.join(' • ');

    final dtIso = b['dateTime']?.toString() ?? '';
    final dtLine = dtIso.isNotEmpty ? _fmtTimeIso(dtIso) : '--:--';

    final startedAt = _startedAtIso();
    final finishedAt = _finishedAtIso();

    final payBadges = _paymentBadges();
    final paid = _paidTotalRub();
    final toPay = _toPayRub();

    final discountRub = _discountRub();
    final effectivePriceRub = _effectivePriceRub();

    final clientComment = b['comment']?.toString();
    final hasClientComment =
        clientComment != null && clientComment.trim().isNotEmpty;

    return SafeArea(
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          children: [
            // Sticky header
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.20),
                border: Border(
                  bottom: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Назад',
                    onPressed: loading
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$dtLine • $serviceName • Пост $bayIdStr',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          clientTitle,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface.withValues(alpha: 0.75),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _statusPill(_statusRu),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 12,
                  bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  children: [
                    _sectionCard(
                      title: 'Информация',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Клиент: $clientTitle',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Авто: $carLine',
                            style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Начато: ${_fmtTimeIso(startedAt)}',
                                  style: TextStyle(
                                    color: cs.onSurface.withValues(alpha: 0.75),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Завершено: ${_fmtTimeIso(finishedAt)}',
                                  style: TextStyle(
                                    color: cs.onSurface.withValues(alpha: 0.75),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (hasClientComment) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest.withValues(
                                  alpha: 0.18,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: cs.outlineVariant.withValues(
                                    alpha: 0.55,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Комментарий клиента: ${clientComment.trim()}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    _sectionCard(
                      title: 'Оплата',
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(
                            alpha: 0.20,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.55),
                          ),
                        ),
                        child: Text(
                          _paymentStatusRu,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Оплачено: $paid ₽ К оплате: $toPay ₽',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          if (effectivePriceRub > 0) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Стоимость: $effectivePriceRub ₽ (скидка: $discountRub ₽)',
                              style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.75),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                          if (payBadges.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final x in payBadges)
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
                          if (toPay > 0) ...[
                            const SizedBox(height: 14),
                            const Divider(),
                            const SizedBox(height: 10),
                            Text(
                              'Способ оплаты',
                              style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _paymentMethodChips(),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: loading ? null : _payFully,
                                icon: const Icon(Icons.payments),
                                label: const Text('Оплачено полностью'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    _sectionCard(
                      title: 'Заметка администратора',
                      child: TextField(
                        controller: noteCtrl,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Комментарий администратора',
                        ),
                      ),
                    ),

                    if (_discountEnabled) ...[
                      const SizedBox(height: 10),
                      _sectionCard(
                        title: 'Скидка',
                        child: Column(
                          children: [
                            TextField(
                              controller: discountCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Скидка (₽)',
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: discountReasonCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Причина скидки (обязательно)',
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: loading ? null : _applyDiscount,
                                child: const Text('Применить скидку'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 10),

                    _sectionCard(
                      title: 'Действия',
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: loading || !_canStart ? null : _start,
                              child: loading
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(),
                                    )
                                  : const Text('Начать'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: loading || !_canFinish
                                  ? null
                                  : _finish,
                              child: const Text('Завершить'),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (_moveEnabled) ...[
                      const SizedBox(height: 10),
                      _sectionCard(
                        title: 'Перенос записи',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: loading || !_canMove
                                        ? null
                                        : _pickMoveDateTime,
                                    child: Builder(
                                      builder: (_) {
                                        final dt = selectedDateTimeLocal;
                                        return Text(
                                          dt == null
                                              ? 'Выбрать дату/время'
                                              : _fmtDateTimeLocal(dt),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 130,
                                  child: DropdownButtonFormField<int>(
                                    initialValue: selectedBay,
                                    decoration: const InputDecoration(
                                      labelText: 'Пост',
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 1,
                                        child: Text('Пост 1'),
                                      ),
                                      DropdownMenuItem(
                                        value: 2,
                                        child: Text('Пост 2'),
                                      ),
                                    ],
                                    onChanged: loading || !_canMove
                                        ? null
                                        : (v) => setState(
                                            () => selectedBay = v ?? 1,
                                          ),
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
                                      : (v) => setState(
                                          () => clientAgreed = v ?? false,
                                        ),
                                ),
                                const Expanded(
                                  child: Text('Согласовано с клиентом'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              initialValue: moveReasonKind,
                              items: _moveReasons
                                  .map(
                                    (x) => DropdownMenuItem(
                                      value: x,
                                      child: Text(x),
                                    ),
                                  )
                                  .toList(),
                              onChanged: loading || !_canMove
                                  ? null
                                  : (v) => setState(
                                      () => moveReasonKind =
                                          v ?? _moveReasons.first,
                                    ),
                              decoration: const InputDecoration(
                                labelText: 'Причина',
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: moveCommentCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Комментарий (обязательно)',
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: loading || !_canMove ? null : _move,
                                child: const Text('Перенести'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
