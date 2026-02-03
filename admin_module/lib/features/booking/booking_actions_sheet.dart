// C:\dev\carwash\admin_module\lib\features\booking\booking_actions_sheet.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'; // kIsWeb
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
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

  // Sticky note (admin note)
  final noteCtrl = TextEditingController();

  // Move
  static const _moveReasons = <String>['Задержка', 'Сбой', 'Передумал', 'Другое'];
  String moveReasonKind = _moveReasons.first;
  final moveCommentCtrl = TextEditingController();
  bool clientAgreed = true;

  int selectedBay = 1;
  DateTime? selectedDateTimeLocal;

  // Pay
  String paymentMethod = 'CARD'; // CARD / CASH / CONTRACT

  // Discount
  final discountCtrl = TextEditingController(text: '0');
  final discountReasonCtrl = TextEditingController(text: '');

  // Addons
  List<Map<String, dynamic>> addons = [];
  final addonServiceIdCtrl = TextEditingController();
  final addonQtyCtrl = TextEditingController(text: '1');

  // Photos
  List<Map<String, dynamic>> photos = [];
  String photoKind = 'BEFORE'; // BEFORE/AFTER/DAMAGE/OTHER (server enums)
  final photoNoteCtrl = TextEditingController();

  // Local previews so photo appears immediately
  final Map<String, Uint8List> _localPreviewByTempId = {};
  final _picker = ImagePicker();

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
  String get _bookingId => (widget.booking['id'] ?? '').toString();

  static const _timeout = Duration(seconds: 20);

  @override
  void initState() {
    super.initState();

    final bayId = widget.booking['bayId'];
    if (bayId is num) selectedBay = bayId.toInt();

    final adminNote = widget.booking['adminNote'];
    if (adminNote is String && adminNote.trim().isNotEmpty) {
      noteCtrl.text = adminNote.trim();
    }

    final dtIso = widget.booking['dateTime']?.toString();
    if (dtIso != null && dtIso.isNotEmpty) {
      selectedDateTimeLocal = DateTime.tryParse(dtIso)?.toLocal();
    }

    final dr = widget.booking['discountRub'];
    if (dr is num) discountCtrl.text = dr.toInt().toString();

    final dn = widget.booking['discountNote'];
    if (dn is String && dn.trim().isNotEmpty) {
      discountReasonCtrl.text = dn.trim();
    }

    final rawAddons = widget.booking['addons'];
    if (rawAddons is List) {
      addons = rawAddons
          .whereType<Map>()
          .map((x) => Map<String, dynamic>.from(x))
          .toList();
    }

    final rawPhotos = widget.booking['photos'];
    if (rawPhotos is List) {
      photos = rawPhotos
          .whereType<Map>()
          .map((x) => Map<String, dynamic>.from(x))
          .toList();
    }

    _refreshAddonsAndPhotos();
  }

  @override
  void dispose() {
    noteCtrl.dispose();
    moveCommentCtrl.dispose();
    discountCtrl.dispose();
    discountReasonCtrl.dispose();
    addonServiceIdCtrl.dispose();
    addonQtyCtrl.dispose();
    photoNoteCtrl.dispose();
    super.dispose();
  }

  // ---------------- helpers ----------------

  String _fmtTimeIso(String? iso) {
    if (iso == null || iso.isEmpty) return '--:--';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '--:--';
    return DateFormat('HH:mm').format(dt);
  }

  String _fmtDateTimeLocal(DateTime dt) =>
      DateFormat('yyyy-MM-dd HH:mm').format(dt);

  int _intOr0(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  void _showSnack(String msg) {
    final m = msg.trim();
    if (m.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), behavior: SnackBarBehavior.floating),
    );
  }

  Uri _u(String path, [Map<String, String>? q]) {
    final uri = Uri.parse(widget.api.baseUrl + path);
    return q == null ? uri : uri.replace(queryParameters: q);
  }

  Map<String, String> _headers({bool json = true}) {
    final h = <String, String>{
      'x-user-id': _userId,
      'x-shift-id': _shiftId,
    };
    if (json) h['Content-Type'] = 'application/json; charset=utf-8';
    return h;
  }

  // Convert server kind to RU label for UI
  String _kindRu(String kind) {
    switch (kind.toUpperCase()) {
      case 'BEFORE':
        return 'ДО';
      case 'AFTER':
        return 'ПОСЛЕ';
      case 'DAMAGE':
        return 'ПОВРЕЖДЕНИЯ';
      case 'OTHER':
        return 'ДРУГОЕ';
      default:
        return kind;
    }
  }

  // ---------- status helpers ----------
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

  Color _statusColor() {
    if (_statusRu == 'МОЕТСЯ') return Colors.blue;
    if (_statusRu == 'ЗАВЕРШЕНО') return Colors.green;
    if (_statusRu == 'ОТМЕНЕНО') return Colors.red;
    return Colors.orange;
  }

  // payment info
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

  // auto string (no model)
  String _buildCarLine(Map<String, dynamic> b) {
    final plate = (b['car']?['plateDisplay'] ?? '').toString().trim();
    final make = (b['car']?['makeDisplay'] ?? '').toString().trim();
    final body = (b['car']?['bodyType'] ?? '').toString().trim();
    final color = (b['car']?['color'] ?? '').toString().trim();

    bool ok(String s) => s.isNotEmpty && s != '—' && s.toLowerCase() != 'null';

    final parts = <String>[];
    if (ok(plate)) parts.add(plate);
    if (ok(make)) parts.add(make);
    if (ok(body)) parts.add(body);
    if (ok(color)) parts.add(color);

    return parts.isEmpty ? '—' : parts.join(' • ');
  }

  // ---------------- low-level lists ----------------

  Future<List<dynamic>> _getList(String path, {Map<String, String>? q}) async {
    final res = await http.get(_u(path, q), headers: _headers()).timeout(_timeout);
    if (res.statusCode >= 400) {
      throw Exception('GET $path failed: ${res.statusCode} ${res.body}');
    }
    final d = jsonDecode(res.body);
    if (d is List) return d;
    if (d is Map && d['items'] is List) return (d['items'] as List);
    if (d is Map<String, dynamic>) return [d];
    return const [];
  }

  Future<Map<String, dynamic>> _postMap(String path, Map<String, dynamic> body) async {
    final res = await http.post(_u(path), headers: _headers(), body: jsonEncode(body)).timeout(_timeout);
    if (res.statusCode >= 400) {
      throw Exception('POST $path failed: ${res.statusCode} ${res.body}');
    }
    final d = jsonDecode(res.body);
    if (d is Map<String, dynamic>) return d;
    if (d is Map) return Map<String, dynamic>.from(d);
    throw Exception('POST $path failed: unexpected response');
  }

  Future<void> _delete(String path) async {
    final res = await http.delete(_u(path), headers: _headers()).timeout(_timeout);
    if (res.statusCode >= 400) {
      throw Exception('DELETE $path failed: ${res.statusCode} ${res.body}');
    }
  }

  Future<void> _refreshAddonsAndPhotos() async {
    try {
      final a = await _getList('/admin/bookings/$_bookingId/addons');
      final p = await _getList('/admin/bookings/$_bookingId/photos');
      if (!mounted) return;
      setState(() {
        addons = a.whereType<Map>().map((x) => Map<String, dynamic>.from(x)).toList();
        photos = p.whereType<Map>().map((x) => Map<String, dynamic>.from(x)).toList();
      });
    } catch (e) {
      _showSnack('Не удалось обновить фото: $e');
    }
  }

  // ---------------- unified run wrapper ----------------

  Future<void> _run(Future<void> Function() fn, {bool closeAfter = true}) async {
    setState(() => loading = true);
    try {
      await fn();
      await _refreshAddonsAndPhotos();
      widget.onDone();
      if (!mounted) return;
      if (closeAfter) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ---------------- actions: service/process ----------------

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

  // ---------------- actions: move ----------------

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

  // ---------------- actions: pay ----------------

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

  // ---------------- actions: discount ----------------

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

  // ---------------- actions: addons ----------------

  int _addonsTotalPrice() {
    var sum = 0;
    for (final a in addons) {
      final qty = _intOr0(a['qty']);
      final price = _intOr0(a['priceRubSnapshot']);
      sum += price * (qty <= 0 ? 1 : qty);
    }
    return sum;
  }

  int _addonsTotalDurationMin() {
    var sum = 0;
    for (final a in addons) {
      final qty = _intOr0(a['qty']);
      final dur = _intOr0(a['durationMinSnapshot']);
      sum += dur * (qty <= 0 ? 1 : qty);
    }
    return sum;
  }

  Future<void> _addAddon() async {
    final serviceId = addonServiceIdCtrl.text.trim();
    final qty = int.tryParse(addonQtyCtrl.text.trim()) ?? 1;

    if (serviceId.isEmpty) {
      _showSnack('serviceId обязателен');
      return;
    }
    if (qty <= 0) {
      _showSnack('qty должен быть > 0');
      return;
    }

    await _run(() async {
      await _postMap('/admin/bookings/$_bookingId/addons', {
        'serviceId': serviceId,
        'qty': qty,
      });
    }, closeAfter: false);
  }

  Future<void> _removeAddon(String serviceId) async {
    if (serviceId.trim().isEmpty) return;
    await _run(() async {
      await _delete('/admin/bookings/$_bookingId/addons/$serviceId');
    }, closeAfter: false);
  }

  // ---------------- photos: UX + replace ----------------

  ImageSource _bestImageSource() {
    if (kIsWeb) return ImageSource.gallery;
    final p = Theme.of(context).platform;
    if (p == TargetPlatform.windows ||
        p == TargetPlatform.macOS ||
        p == TargetPlatform.linux) {
      return ImageSource.gallery;
    }
    return ImageSource.camera;
  }

  String _absUrl(String raw) {
    final u = raw.trim();
    if (u.isEmpty) return '';
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    final base = Uri.parse(widget.api.baseUrl);
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: u.startsWith('/') ? u : '/$u',
    ).toString();
  }

  Future<void> _deletePhotoIfSupported(String photoId) async {
    // This endpoint must exist server-side: DELETE /admin/bookings/:id/photos/:photoId
    await _delete('/admin/bookings/$_bookingId/photos/$photoId');
  }

  Future<void> _replaceKindPhotosIfPossible(String kind) async {
    // delete existing photos for this kind (BEFORE/AFTER) to make "replace"
    final k = kind.toUpperCase();
    final existing = photos
        .where((p) => (p['kind'] ?? '').toString().toUpperCase() == k)
        .toList();

    if (existing.isEmpty) return;

    for (final p in existing) {
      final id = (p['id'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      try {
        await _deletePhotoIfSupported(id);
      } catch (_) {
        // If backend doesn't support delete yet — stop (will behave like add)
        return;
      }
    }
  }

  Future<void> _uploadPhotoFile({required String kind, bool replace = false}) async {
    final file = await _picker.pickImage(
      source: _bestImageSource(),
      imageQuality: 85,
    );
    if (file == null) return;

    final note = photoNoteCtrl.text.trim();
    final bytes = await file.readAsBytes();

    // optimistic preview
    final tempId = 'local_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _localPreviewByTempId[tempId] = bytes;
      photos.insert(0, {
        'id': tempId,
        'kind': kind,
        'url': '',
        'note': note,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        '_local': true,
      });
    });

    try {
      // if replace requested: try delete old kind photos (best-effort)
      if (replace) {
        await _replaceKindPhotosIfPossible(kind);
      }

      final req = http.MultipartRequest(
        'POST',
        _u('/admin/bookings/$_bookingId/photos/upload'),
      );
      req.headers.addAll(_headers(json: false));
      req.fields['kind'] = kind;
      if (note.isNotEmpty) req.fields['note'] = note;

      req.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: file.name,
      ));

      final streamed = await req.send().timeout(_timeout);
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode >= 400) {
        throw Exception('UPLOAD failed: ${res.statusCode} ${res.body}');
      }

      photoNoteCtrl.clear();

      await _refreshAddonsAndPhotos();
      widget.onDone();
    } catch (e) {
      _showSnack('Не удалось загрузить фото: $e');
    } finally {
      if (mounted) {
        setState(() {
          _localPreviewByTempId.remove(tempId);
          photos.removeWhere((p) => (p['id'] ?? '').toString() == tempId);
        });
      }
    }
  }

  Future<void> _openPhotoFull(Map<String, dynamic> p) async {
    final id = (p['id'] ?? '').toString();
    final rawUrl = (p['url'] ?? '').toString();
    final abs = _absUrl(rawUrl);

    Widget content;
    if (_localPreviewByTempId.containsKey(id)) {
      content = InteractiveViewer(
        child: Image.memory(_localPreviewByTempId[id]!, fit: BoxFit.contain),
      );
    } else if (abs.isNotEmpty) {
      content = InteractiveViewer(
        child: Image.network(abs, fit: BoxFit.contain),
      );
    } else {
      content = const Padding(
        padding: EdgeInsets.all(18),
        child: Text('Фото недоступно'),
      );
    }

    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            color: Colors.black,
            child: Stack(
              children: [
                Positioned.fill(child: content),
                Positioned(
                  top: 6,
                  right: 6,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _photoThumb(Map<String, dynamic> p) {
    final id = (p['id'] ?? '').toString();
    final url = (p['url'] ?? '').toString();

    if (_localPreviewByTempId.containsKey(id)) {
      return Image.memory(
        _localPreviewByTempId[id]!,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }

    final abs = _absUrl(url);
    if (abs.isEmpty) {
      return const Center(child: Icon(Icons.photo, size: 22));
    }

    return Image.network(
      abs,
      width: 72,
      height: 72,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image)),
    );
  }

  Widget _photoCard(BuildContext context, Map<String, dynamic> p) {
    final cs = Theme.of(context).colorScheme;

    final kind = (p['kind'] ?? '').toString();
    final note = (p['note'] ?? '').toString().trim();

    final createdAt = DateTime.tryParse((p['createdAt'] ?? '').toString())?.toLocal();
    final time = createdAt == null ? '' : DateFormat('HH:mm').format(createdAt);

    return InkWell(
      onTap: () => _openPhotoFull(p),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
        ),
        child: Row(
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(12), child: _photoThumb(p)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_kindRu(kind), style: const TextStyle(fontWeight: FontWeight.w900)),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    note,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ]),
            ),
            if (time.isNotEmpty)
              Text(
                time,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------- UI helpers ----------------

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

  Widget _sectionCard({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
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
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
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
            onSelected: loading ? null : (_) => setState(() => paymentMethod = v),
          ),
      ],
    );
  }

  Tab _tabLabel(String s) {
    return Tab(
      child: Text(
        s,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }

  // ---------------- build ----------------

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

    final carLine = _buildCarLine(b);

    final dtIso = b['dateTime']?.toString() ?? '';
    final dtLine = dtIso.isNotEmpty ? _fmtTimeIso(dtIso) : '--:--';

    final startedAt = _startedAtIso();
    final finishedAt = _finishedAtIso();

    final payBadges = _paymentBadges();
    final paid = _paidTotalRub();
    final toPay = _toPayRub();

    final discountRub = _discountRub();
    final effectivePriceRub = _effectivePriceRub();

    final clientCommentText = (b['comment'] ?? '').toString().trim();
    final hasClientComment = clientCommentText.isNotEmpty;

    final addonsSumRub = _addonsTotalPrice();
    final addonsDur = _addonsTotalDurationMin();

    return DefaultTabController(
      length: 5,
      child: SafeArea(
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            children: [
              // Sticky header
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.20),
                  border: Border(bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6))),
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Назад',
                      onPressed: loading ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$dtLine • $serviceName • Пост $bayIdStr',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
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

              // Tabs bar
              Material(
                color: cs.surface,
                child: TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: cs.onSurface,
                  unselectedLabelColor: cs.onSurface.withValues(alpha: 0.65),
                  indicatorColor: cs.primary,
                  tabs: [
                    _tabLabel('Сервис'),
                    _tabLabel('Оплата'),
                    _tabLabel('Скидка'),
                    _tabLabel('Перенос'),
                    _tabLabel('Фото'),
                  ],
                ),
              ),

              Expanded(
                child: TabBarView(
                  children: [
                    // TAB: SERVICE
                    SingleChildScrollView(
                      padding: EdgeInsets.only(
                        left: 12, right: 12, top: 12,
                        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: Column(
                        children: [
                          if (hasClientComment)
                            _sectionCard(
                              title: 'Комментарий клиента',
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.amber.withValues(alpha: 0.7)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.campaign, size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        clientCommentText,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: cs.onSurface.withValues(alpha: 0.92),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          _sectionCard(
                            title: 'Информация',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Клиент: $clientTitle', style: const TextStyle(fontWeight: FontWeight.w800)),
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
                                    Expanded(child: Text('Начато: ${_fmtTimeIso(startedAt)}')),
                                    Expanded(child: Text('Завершено: ${_fmtTimeIso(finishedAt)}')),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          _sectionCard(
                            title: 'Действия',
                            child: Row(
                              children: [
                                Expanded(
                                  child: FilledButton(
                                    onPressed: loading || !_canStart ? null : _start,
                                    child: loading
                                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator())
                                        : const Text('Начать'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: loading || !_canFinish ? null : _finish,
                                    child: const Text('Завершить'),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          _sectionCard(
                            title: 'Заметка администратора',
                            child: TextField(
                              controller: noteCtrl,
                              minLines: 1,
                              maxLines: 4,
                              decoration: const InputDecoration(labelText: 'Комментарий администратора'),
                            ),
                          ),

                          _sectionCard(
                            title: 'Доп. услуги (upsale)',
                            trailing: (addonsSumRub > 0 || addonsDur > 0)
                                ? Text(
                                    '+$addonsSumRub ₽ • +$addonsDur мин',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: cs.onSurface.withValues(alpha: 0.85),
                                    ),
                                  )
                                : null,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (addons.isEmpty)
                                  Text('Пока нет доп. услуг.', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)))
                                else
                                  Column(
                                    children: [
                                      for (final a in addons)
                                        Container(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: cs.surfaceContainerHighest.withValues(alpha: 0.18),
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  (a['service']?['name'] ?? a['serviceName'] ?? a['serviceId'] ?? 'Услуга').toString(),
                                                  style: const TextStyle(fontWeight: FontWeight.w900),
                                                ),
                                              ),
                                              Text('x${_intOr0(a['qty'])}', style: const TextStyle(fontWeight: FontWeight.w900)),
                                              const SizedBox(width: 10),
                                              Text('${_intOr0(a['priceRubSnapshot'])} ₽', style: const TextStyle(fontWeight: FontWeight.w900)),
                                              const SizedBox(width: 6),
                                              IconButton(
                                                tooltip: 'Убрать',
                                                onPressed: loading ? null : () => _removeAddon((a['serviceId'] ?? '').toString()),
                                                icon: const Icon(Icons.delete_outline),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: addonServiceIdCtrl,
                                        decoration: const InputDecoration(labelText: 'serviceId'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    SizedBox(
                                      width: 90,
                                      child: TextField(
                                        controller: addonQtyCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(labelText: 'qty'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: loading ? null : _addAddon,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Добавить'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // TAB: PAY
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                      child: Column(
                        children: [
                          _sectionCard(
                            title: 'Статус оплаты',
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest.withValues(alpha: 0.20),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
                              ),
                              child: Text(_paymentStatusRu, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Оплачено: $paid ₽   К оплате: $toPay ₽', style: const TextStyle(fontWeight: FontWeight.w900)),
                                const SizedBox(height: 6),
                                Text(
                                  'Стоимость: $effectivePriceRub ₽ (скидка: $discountRub ₽)',
                                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.75), fontWeight: FontWeight.w800),
                                ),
                                if (payBadges.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final x in payBadges)
                                        Chip(
                                          avatar: Icon(_payIcon(x), size: 18),
                                          label: Text(x == 'CARD' ? 'Карта' : x == 'CASH' ? 'Наличные' : 'Контракт'),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (toPay > 0)
                            _sectionCard(
                              title: 'Оплатить остаток',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('К оплате: $toPay ₽', style: const TextStyle(fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 10),
                                  _paymentMethodChips(),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed: loading ? null : _payFully,
                                      icon: const Icon(Icons.payments),
                                      label: const Text('Оплачено полностью'),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            _sectionCard(
                              title: 'Оплата',
                              child: Text('Остаток 0 ₽ — оплачено.', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.75))),
                            ),
                        ],
                      ),
                    ),

                    // TAB: DISCOUNT
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                      child: Column(
                        children: [
                          if (!_discountEnabled)
                            _sectionCard(
                              title: 'Скидка',
                              child: Text('Функция скидок отключена.', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.75))),
                            )
                          else
                            _sectionCard(
                              title: 'Скидка',
                              child: Column(
                                children: [
                                  TextField(
                                    controller: discountCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Скидка (₽)'),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: discountReasonCtrl,
                                    decoration: const InputDecoration(labelText: 'Причина скидки (обязательно)'),
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
                      ),
                    ),

                    // TAB: MOVE
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                      child: Column(
                        children: [
                          if (!_moveEnabled)
                            _sectionCard(
                              title: 'Перенос',
                              child: Text('Функция переноса отключена.', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.75))),
                            )
                          else
                            _sectionCard(
                              title: 'Перенос записи',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: loading || !_canMove ? null : _pickMoveDateTime,
                                          child: Text(selectedDateTimeLocal == null ? 'Выбрать дату/время' : _fmtDateTimeLocal(selectedDateTimeLocal!)),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      SizedBox(
                                        width: 130,
                                        child: DropdownButtonFormField<int>(
                                          initialValue: selectedBay,
                                          decoration: const InputDecoration(labelText: 'Пост'),
                                          items: const [
                                            DropdownMenuItem(value: 1, child: Text('Пост 1')),
                                            DropdownMenuItem(value: 2, child: Text('Пост 2')),
                                          ],
                                          onChanged: loading || !_canMove ? null : (v) => setState(() => selectedBay = v ?? 1),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: clientAgreed,
                                        onChanged: loading || !_canMove ? null : (v) => setState(() => clientAgreed = v ?? false),
                                      ),
                                      const Expanded(child: Text('Согласовано с клиентом')),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  DropdownButtonFormField<String>(
                                    initialValue: moveReasonKind,
                                    items: _moveReasons.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
                                    onChanged: loading || !_canMove ? null : (v) => setState(() => moveReasonKind = v ?? _moveReasons.first),
                                    decoration: const InputDecoration(labelText: 'Причина'),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: moveCommentCtrl,
                                    decoration: const InputDecoration(labelText: 'Комментарий (обязательно)'),
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
                      ),
                    ),

                    // TAB: PHOTOS
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                      child: Column(
                        children: [
                          _sectionCard(
                            title: 'Фото авто',
                            trailing: IconButton(
                              tooltip: 'Обновить',
                              onPressed: loading ? null : _refreshAddonsAndPhotos,
                              icon: const Icon(Icons.refresh),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DropdownButtonFormField<String>(
                                  initialValue: photoKind,
                                  decoration: const InputDecoration(labelText: 'Тип'),
                                  items: const [
                                    DropdownMenuItem(value: 'BEFORE', child: Text('ДО')),
                                    DropdownMenuItem(value: 'AFTER', child: Text('ПОСЛЕ')),
                                    DropdownMenuItem(value: 'DAMAGE', child: Text('ПОВРЕЖДЕНИЯ')),
                                    DropdownMenuItem(value: 'OTHER', child: Text('ДРУГОЕ')),
                                  ],
                                  onChanged: loading ? null : (v) => setState(() => photoKind = (v ?? 'BEFORE')),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: photoNoteCtrl,
                                  decoration: const InputDecoration(labelText: 'Комментарий (необязательно)'),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: loading ? null : () => _uploadPhotoFile(kind: photoKind, replace: false),
                                    icon: const Icon(Icons.photo_camera),
                                    label: const Text('Снять/выбрать и загрузить'),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: loading ? null : () => _uploadPhotoFile(kind: 'BEFORE', replace: true),
                                        child: const Text('Переснять ДО'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: loading ? null : () => _uploadPhotoFile(kind: 'AFTER', replace: true),
                                        child: const Text('Переснять ПОСЛЕ'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                if (photos.isEmpty)
                                  Text('Пока нет фото.', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)))
                                else
                                  Column(children: [for (final p in photos) _photoCard(context, p)]),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
