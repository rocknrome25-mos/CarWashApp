import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../washers/washers_page.dart';
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

  int waitlistCount = 0;
  bool _loadingWaitlistCount = false;

  late final RealtimeClient _rt;
  StreamSubscription<BookingRealtimeEvent>? _rtSub;
  Timer? _rtDebounce;

  // ✅ keys to force refresh after manual creation
  final _shiftKey = GlobalKey<_ShiftTabState>();
  final _waitlistKey = GlobalKey<_WaitlistTabState>();

  String get _todayYmd => DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();

    _rt = RealtimeClient(baseHttpUrl: widget.api.baseUrl);
    _rt.connect();
    _subscribeRealtimeForBadge();

    _loadWaitlistCount();
  }

  @override
  void dispose() {
    _rtDebounce?.cancel();
    _rtSub?.cancel();
    _rt.close();
    super.dispose();
  }

  void _subscribeRealtimeForBadge() {
    _rtSub?.cancel();
    _rtSub = _rt.events.listen((ev) {
      if (ev.type != 'booking.changed') return;

      final loc = widget.session.locationId.trim();
      if (loc.isEmpty) return;
      if (ev.locationId.trim() != loc) return;

      _rtDebounce?.cancel();
      _rtDebounce = Timer(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        _loadWaitlistCount();
      });
    });
  }

  Future<void> _loadWaitlistCount() async {
    if (_loadingWaitlistCount) return;
    setState(() => _loadingWaitlistCount = true);

    try {
      final sid = widget.session.activeShiftId ?? '';
      if (sid.isEmpty) return;

      final wl = await widget.api.waitlistDay(
        widget.session.userId,
        sid,
        _todayYmd,
      );

      if (!mounted) return;
      setState(() => waitlistCount = wl.length);
    } catch (_) {
      // ignore badge errors
    } finally {
      if (mounted) setState(() => _loadingWaitlistCount = false);
    }
  }

  Widget _queueIconWithBadge() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.queue),
        if (waitlistCount > 0)
          Positioned(
            right: -10,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(999),
              ),
              constraints: const BoxConstraints(minWidth: 18),
              child: Text(
                waitlistCount > 99 ? '99+' : waitlistCount.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _goShiftAndRefresh() {
    setState(() => idx = 0);
    // дать кадр переключиться
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _shiftKey.currentState?.load();
    });
  }

  void _goWaitlistAndRefresh() {
    setState(() => idx = 2);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _waitlistKey.currentState?.load();
      _loadWaitlistCount();
    });
  }

  //////////////////////////////////////////////////////////////////////
  ///
  ///
  ///
  ///
  ///
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: idx,
        children: [
          ShiftTab(
            key: _shiftKey,
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
            key: _waitlistKey,
            api: widget.api,
            store: widget.store,
            session: widget.session,
          ),
          RecordTab(
            api: widget.api,
            store: widget.store,
            session: widget.session,
            onCreatedBooking: _goShiftAndRefresh,
            onCreatedWaitlist: _goWaitlistAndRefresh,
          ),
          WashersPage(
            api: widget.api,
            store: widget.store,
            session: widget.session,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (v) {
          setState(() => idx = v);
          if (v == 2) _loadWaitlistCount();
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.event_note),
            label: 'Смена',
          ),
          const NavigationDestination(
            icon: Icon(Icons.car_repair),
            label: 'Посты',
          ),
          NavigationDestination(icon: _queueIconWithBadge(), label: 'Ожидание'),
          const NavigationDestination(
            icon: Icon(Icons.add_box_outlined),
            label: 'Записать',
          ),
          const NavigationDestination(
            icon: Icon(Icons.people_alt_outlined),
            label: 'Мойщики',
          ),
        ],
      ),
    );
  }
}

/* ========================= TAB 4: ЗАПИСАТЬ ========================= */

class RecordTab extends StatefulWidget {
  final AdminApiClient api;
  final SessionStore store;
  final AdminSession session;

  // ✅ new: navigate+refresh after creation
  final VoidCallback onCreatedBooking;
  final VoidCallback onCreatedWaitlist;

  const RecordTab({
    super.key,
    required this.api,
    required this.store,
    required this.session,
    required this.onCreatedBooking,
    required this.onCreatedWaitlist,
  });

  @override
  State<RecordTab> createState() => _RecordTabState();
}

class _RecordTabState extends State<RecordTab> {
  bool loading = true;
  bool submitting = false;
  String? error;

  static const int _slotStepMin = 30;
  static const int _bufferMin = 15;
  static const int _openHour = 8;
  static const int _closeHour = 22;

  DateTime selectedDay = DateTime.now();
  int selectedBay = 1;

  List<Map<String, dynamic>> baseServices = [];
  List<Map<String, dynamic>> addonServices = [];

  String? selectedServiceId;
  String? selectedServiceName;
  int baseMin = 60;

  final Set<String> selectedAddonIds = {};

  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final plateCtrl = TextEditingController();
  String bodyType = 'SEDAN';

  bool _nameFormatting = false;
  bool _phoneFormatting = false;

  List<int> activeBays = const [1, 2];
  List<DateTimeRange> busy = const [];
  DateTime? selectedSlot;

  String get _locId => widget.session.locationId.trim();

  // ---- helpers ----

  int _durationOf(Map<String, dynamic> s) {
    final v = s['durationMin'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('${s['durationMin']}') ?? 30;
  }

  String _addonNameById(String id) {
    final s = addonServices.firstWhere(
      (x) => (x['id'] ?? '').toString() == id,
      orElse: () => const {},
    );
    final name = (s['name'] ?? '').toString().trim();
    return name.isEmpty ? id : name;
  }

  List<String> get _selectedAddonNames {
    if (selectedAddonIds.isEmpty) return const [];
    final names = selectedAddonIds.map(_addonNameById).toList();
    names.sort();
    return names;
  }

  int get extraMin {
    var sum = 0;
    for (final id in selectedAddonIds) {
      final s = addonServices.firstWhere(
        (x) => (x['id'] ?? '').toString() == id,
        orElse: () => const {},
      );
      if (s.isNotEmpty) sum += _durationOf(s);
    }
    return sum;
  }

  int _roundUpToStepMin(int totalMin, int stepMin) {
    if (totalMin <= 0) return 0;
    final q = (totalMin + stepMin - 1) ~/ stepMin;
    return q * stepMin;
  }

  int get blockMin =>
      _roundUpToStepMin(baseMin + extraMin + _bufferMin, _slotStepMin);

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  String _capitalizeWords(String s) {
    final trimmed = s.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) return '';
    final parts = trimmed.split(' ');
    final out = parts
        .map((w) {
          if (w.isEmpty) return w;
          final lower = w.toLowerCase();
          final first = lower[0].toUpperCase();
          return first + (lower.length > 1 ? lower.substring(1) : '');
        })
        .join(' ');
    return out;
  }

  void _setupNameCapitalization() {
    nameCtrl.addListener(() {
      if (_nameFormatting) return;
      final raw = nameCtrl.text;
      final formatted = _capitalizeWords(raw);
      if (raw == formatted) return;
      _nameFormatting = true;
      nameCtrl.value = nameCtrl.value.copyWith(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
        composing: TextRange.empty,
      );
      _nameFormatting = false;
      if (mounted) setState(() {}); // enables button
    });
  }

  String _normalizePhoneForDb(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return s;
    // keep only + and digits
    s = s.replaceAll(RegExp(r'[^\d\+]'), '');
    // if starts with 8XXXXXXXXXX -> +7XXXXXXXXXX
    if (s.startsWith('8') && s.length == 11) {
      s = '+7${s.substring(1)}';
    }
    // if starts with 7XXXXXXXXXX -> +7XXXXXXXXXX
    if (!s.startsWith('+') && s.startsWith('7') && s.length == 11) {
      s = '+$s';
    }
    return s;
  }

  void _setupPhoneSanitizer() {
    phoneCtrl.addListener(() {
      if (_phoneFormatting) return;
      final raw = phoneCtrl.text;
      final cleaned = raw.replaceAll(RegExp(r'[^\d\+\s]'), '');
      if (cleaned == raw) return;
      _phoneFormatting = true;
      phoneCtrl.value = phoneCtrl.value.copyWith(
        text: cleaned,
        selection: TextSelection.collapsed(offset: cleaned.length),
        composing: TextRange.empty,
      );
      _phoneFormatting = false;
      if (mounted) setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    _setupNameCapitalization();
    _setupPhoneSanitizer();
    _init();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    plateCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final sid = widget.session.activeShiftId ?? '';
      if (sid.isEmpty) throw Exception('Нет активной смены. Перезайди.');
      final loc = _locId;
      if (loc.isEmpty) throw Exception('Нет locationId в сессии. Перезайди.');

      final bays = await widget.api.listBays(widget.session.userId, sid);
      final act = <int>[];
      for (final x in bays) {
        if (x is Map<String, dynamic>) {
          final n = (x['number'] as num?)?.toInt();
          final a = x['isActive'] == true;
          if (n != null && a && (n == 1 || n == 2)) act.add(n);
        }
      }
      if (act.isNotEmpty) {
        activeBays = act;
        if (!activeBays.contains(selectedBay)) selectedBay = activeBays.first;
      }

      final base = await widget.api.services(locationId: loc, kind: 'BASE');
      final add = await widget.api.services(locationId: loc, kind: 'ADDON');

      baseServices = base
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      addonServices = add
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();

      if (baseServices.isNotEmpty) {
        final first = baseServices.first;
        selectedServiceId = (first['id'] ?? '').toString();
        selectedServiceName = (first['name'] ?? '').toString();
        baseMin = _durationOf(first);
      }

      await _loadBusy();
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadBusy() async {
    final loc = _locId;
    final day = _dateOnly(selectedDay);
    final from = DateTime(day.year, day.month, day.day, _openHour, 0);
    final to = DateTime(day.year, day.month, day.day, _closeHour, 0);

    final rows = await widget.api.publicBusySlots(
      locationId: loc,
      bayId: selectedBay,
      fromIsoUtc: from.toUtc().toIso8601String(),
      toIsoUtc: to.toUtc().toIso8601String(),
    );

    busy = _parseBusyRanges(rows);

    if (selectedSlot != null && !_isFree(selectedSlot!)) {
      selectedSlot = null;
    }
  }

  List<DateTimeRange> _parseBusyRanges(List<dynamic> rows) {
    final out = <DateTimeRange>[];
    for (final x in rows) {
      if (x is Map) {
        final s = x['start']?.toString() ?? '';
        final e = x['end']?.toString() ?? '';
        final ds = DateTime.tryParse(s);
        final de = DateTime.tryParse(e);
        if (ds != null && de != null) {
          out.add(DateTimeRange(start: ds.toLocal(), end: de.toLocal()));
        }
      }
    }
    return out;
  }

  List<DateTime> _buildSlotsForDay(DateTime day) {
    final now = DateTime.now();
    var start = DateTime(day.year, day.month, day.day, _openHour, 0);
    final end = DateTime(day.year, day.month, day.day, _closeHour, 0);

    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;
    if (isToday) {
      final min = now.add(const Duration(minutes: 5));
      final mod = min.minute % _slotStepMin;
      final add = mod == 0 ? 0 : (_slotStepMin - mod);
      final rounded = DateTime(
        min.year,
        min.month,
        min.day,
        min.hour,
        min.minute,
      ).add(Duration(minutes: add));
      if (rounded.isAfter(start)) start = rounded;
    }

    if (!start.isBefore(end)) return const [];
    final out = <DateTime>[];
    var cur = start;
    while (cur.isBefore(end)) {
      out.add(cur);
      cur = cur.add(const Duration(minutes: _slotStepMin));
    }
    return out;
  }

  bool _overlaps(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) {
    return aStart.isBefore(bEnd) && bStart.isBefore(aEnd);
  }

  bool _isFree(DateTime start) {
    final end = start.add(Duration(minutes: blockMin));
    for (final r in busy) {
      if (_overlaps(start, end, r.start, r.end)) return false;
    }
    return true;
  }

  List<DateTime> _freeSlots() {
    final all = _buildSlotsForDay(_dateOnly(selectedDay));
    return all.where(_isFree).toList();
  }

  Widget _sectionBox(
    BuildContext ctx, {
    required String title,
    required Widget child,
  }) {
    final cs = Theme.of(ctx).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: cs.onSurface.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Future<void> _refresh() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await _loadBusy();
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  bool get _canSubmit {
    final nameOk = nameCtrl.text.trim().isNotEmpty;
    final phoneOk = phoneCtrl.text.trim().isNotEmpty;
    final plateOk = plateCtrl.text.trim().isNotEmpty;
    return nameOk &&
        phoneOk &&
        plateOk &&
        selectedSlot != null &&
        (selectedServiceId ?? '').isNotEmpty;
  }

  Future<void> _submit() async {
    if (!_canSubmit || submitting) return;

    final userId = widget.session.userId;
    final shiftId = widget.session.activeShiftId ?? '';
    final locId = _locId;

    setState(() => submitting = true);

    try {
      final dtUtc = selectedSlot!.toUtc().toIso8601String();

      final addons = selectedAddonIds
          .map((id) => {'serviceId': id, 'qty': 1})
          .toList();

      final phoneDb = _normalizePhoneForDb(phoneCtrl.text);

      final res = await widget.api.createAdminBooking(
        userId,
        shiftId,
        locationId: locId,
        bayId: selectedBay,
        dateTimeIsoUtc: dtUtc,
        clientName: nameCtrl.text.trim(),
        clientPhone: phoneDb,
        carPlate: plateCtrl.text.trim(),
        bodyType: bodyType,
        serviceId: selectedServiceId!,
        addons: addons,
      );

      if (!mounted) return;

      // reset
      setState(() {
        selectedAddonIds.clear();
        selectedSlot = null;
      });
      nameCtrl.clear();
      phoneCtrl.clear();
      plateCtrl.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Создано'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // ✅ navigate based on backend resultType (BOOKING vs WAITLIST)
      final rt = (res['resultType'] ?? '').toString().toUpperCase();
      if (rt == 'WAITLIST') {
        widget.onCreatedWaitlist();
      } else {
        widget.onCreatedBooking();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _refresh();
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final days = List.generate(
      7,
      (i) => _dateOnly(DateTime.now().add(Duration(days: i))),
    );
    final slots = _freeSlots();

    final addonNames = _selectedAddonNames;
    final addonLine = addonNames.isEmpty
        ? 'Доп. услуги: —'
        : 'Доп. услуги: ${addonNames.join(', ')}';
    final totalLine = 'Основная: ${selectedServiceName ?? '—'} • $addonLine';
    final calcLine =
        'Итого: ${baseMin + extraMin} мин + буфер $_bufferMin = блок $blockMin мин';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Записать'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 6),
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
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              children: [
                _sectionBox(
                  context,
                  title: 'Пост и услуга',
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          key: ValueKey('bay_$selectedBay'),
                          initialValue: selectedBay,
                          decoration: const InputDecoration(labelText: 'Пост'),
                          items: [
                            for (final b in activeBays)
                              DropdownMenuItem(
                                value: b,
                                child: Text('Пост $b'),
                              ),
                          ],
                          onChanged: (v) async {
                            final next = v ?? activeBays.first;
                            if (next == selectedBay) return;
                            setState(() {
                              selectedBay = next;
                              selectedSlot = null;
                            });
                            await _refresh();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('svc_${selectedServiceId ?? ''}'),
                          initialValue: selectedServiceId,
                          decoration: const InputDecoration(
                            labelText: 'Основная услуга',
                          ),
                          items: [
                            for (final s in baseServices)
                              DropdownMenuItem(
                                value: (s['id'] ?? '').toString(),
                                child: Text(
                                  '${(s['name'] ?? '').toString()} (${_durationOf(s)} мин)',
                                ),
                              ),
                          ],
                          onChanged: (v) {
                            final id = (v ?? '').toString();
                            if (id.isEmpty) return;
                            final sel = baseServices.firstWhere(
                              (x) => (x['id'] ?? '').toString() == id,
                              orElse: () => baseServices.first,
                            );
                            setState(() {
                              selectedServiceId = id;
                              selectedServiceName = (sel['name'] ?? '')
                                  .toString();
                              baseMin = _durationOf(sel);
                              if (selectedSlot != null &&
                                  !_isFree(selectedSlot!)) {
                                selectedSlot = null;
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                _sectionBox(
                  context,
                  title: 'Доп. услуги',
                  child: addonServices.isEmpty
                      ? Text(
                          'Доп. услуги не настроены',
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final s in addonServices)
                              FilterChip(
                                label: Text(
                                  '${(s['name'] ?? '').toString()} (+${_durationOf(s)} мин)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                selected: selectedAddonIds.contains(
                                  (s['id'] ?? '').toString(),
                                ),
                                onSelected: (v) {
                                  final id = (s['id'] ?? '').toString();
                                  setState(() {
                                    if (v) {
                                      selectedAddonIds.add(id);
                                    } else {
                                      selectedAddonIds.remove(id);
                                    }
                                    if (selectedSlot != null &&
                                        !_isFree(selectedSlot!)) {
                                      selectedSlot = null;
                                    }
                                  });
                                },
                              ),
                          ],
                        ),
                ),

                const SizedBox(height: 12),

                _sectionBox(
                  context,
                  title: 'Итог',
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.6),
                      ),
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.14),
                    ),
                    child: Text(
                      '$totalLine\n$calcLine',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                _sectionBox(
                  context,
                  title: 'Дата',
                  child: SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: days.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final d = days[i];
                        final selected = _dateOnly(d) == _dateOnly(selectedDay);
                        return InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () async {
                            setState(() {
                              selectedDay = d;
                              selectedSlot = null;
                            });
                            await _refresh();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? cs.primary.withValues(alpha: 0.18)
                                  : cs.surfaceContainerHighest.withValues(
                                      alpha: 0.18,
                                    ),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: selected
                                    ? cs.primary.withValues(alpha: 0.65)
                                    : cs.outlineVariant.withValues(alpha: 0.55),
                              ),
                            ),
                            child: Text(
                              '${['ВС', 'ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ'][d.weekday % 7]} ${d.day}',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: cs.onSurface.withValues(alpha: 0.92),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                _sectionBox(
                  context,
                  title: 'Время (только свободные)',
                  child: slots.isEmpty
                      ? Text(
                          'Нет доступных слотов на выбранный день.',
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final s in slots)
                              (selectedSlot == s)
                                  ? FilledButton(
                                      onPressed: () =>
                                          setState(() => selectedSlot = s),
                                      child: Text(
                                        DateFormat('HH:mm').format(s),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    )
                                  : OutlinedButton(
                                      onPressed: () =>
                                          setState(() => selectedSlot = s),
                                      child: Text(
                                        DateFormat('HH:mm').format(s),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                          ],
                        ),
                ),

                const SizedBox(height: 12),

                _sectionBox(
                  context,
                  title: 'Клиент (по звонку)',
                  child: Column(
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Имя Фамилия',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Телефон'),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: plateCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Номер авто',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        key: ValueKey('body_$bodyType'),
                        initialValue: bodyType,
                        decoration: const InputDecoration(
                          labelText: 'Тип кузова',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'SEDAN',
                            child: Text('Седан'),
                          ),
                          DropdownMenuItem(value: 'SUV', child: Text('SUV')),
                          DropdownMenuItem(
                            value: 'HATCH',
                            child: Text('Хэтчбек'),
                          ),
                          DropdownMenuItem(
                            value: 'WAGON',
                            child: Text('Универсал'),
                          ),
                          DropdownMenuItem(
                            value: 'MINIVAN',
                            child: Text('Минивэн'),
                          ),
                          DropdownMenuItem(
                            value: 'OTHER',
                            child: Text('Другое'),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => bodyType = v ?? 'SEDAN'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: submitting
                        ? null
                        : (_canSubmit ? _submit : null),
                    icon: submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.done),
                    label: Text(submitting ? 'Создаю...' : 'Создать запись'),
                  ),
                ),
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

  late final RealtimeClient _rt;
  StreamSubscription<BookingRealtimeEvent>? _rtSub;
  Timer? _rtDebounce;

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
    _rtSub?.cancel();
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

      _rtDebounce?.cancel();
      _rtDebounce = Timer(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        load();
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

  // ✅ AUTOCALC: keep + handover = counted (two-way)
  Future<void> closeShiftWithCash() async {
    final userId = widget.session.userId;
    final shiftId = widget.session.activeShiftId ?? '';
    if (shiftId.isEmpty) return;

    try {
      final exp = await widget.api.cashExpected(userId, shiftId);
      if (!mounted) return;

      final expectedRub = (exp['expectedRub'] as num).toInt();

      final countedCtrl = TextEditingController(text: expectedRub.toString());
      final keepCtrl = TextEditingController(text: expectedRub.toString());
      final handoverCtrl = TextEditingController(text: '0');
      final noteCtrl = TextEditingController(text: '');

      String lastEdited = 'keep'; // 'keep' | 'handover'

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

      // initial fill
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
                          labelText: 'Оставить в кассе (₽)',
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
                          labelText: 'Сдать владельцу (₽)',
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

    Color indicatorColor(int index) {
      if (index == 0) return const Color(0xFF2DBD6E);
      return const Color(0xFF2D9CDB);
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

  String _buildCarLineFromBooking(Map<String, dynamic> b) {
    final plate = (b['car']?['plateDisplay'] ?? '').toString().trim();
    final make = (b['car']?['makeDisplay'] ?? '').toString().trim();
    final body = (b['car']?['bodyType'] ?? '').toString().trim();

    bool ok(String s) => s.isNotEmpty && s != '—' && s.toLowerCase() != 'null';

    final parts = <String>[];
    if (ok(plate)) parts.add(plate);
    if (ok(make)) parts.add(make);
    if (ok(body)) parts.add(body);

    return parts.join(' • ');
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

    final carLine = _buildCarLineFromBooking(b);

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
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _bookingCard(context, list[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

/* ========================= TAB 2: ПОСТЫ ========================= */
/* Ниже — твой код BaysTab без изменений (как у тебя) */

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

// ======================= SHELL_PAGE.dart — PART B (2/2) =======================

/* ========================= TAB 3: ОЖИДАНИЕ ========================= */

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

  late final RealtimeClient _rt;
  StreamSubscription<BookingRealtimeEvent>? _rtSub;
  Timer? _rtDebounce;

  // slot rules (align with server)
  static const int _slotStepMin = 30;
  static const int _bufferMin = 15;
  static const int _openHour = 8;
  static const int _closeHour = 22;

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
    _rtSub?.cancel();
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

      _rtDebounce?.cancel();
      _rtDebounce = Timer(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        load();
      });
    });
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

  // ✅ new day chips + sections (Yandex-ish)
  String _weekdayShortRu(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'ПН';
      case DateTime.tuesday:
        return 'ВТ';
      case DateTime.wednesday:
        return 'СР';
      case DateTime.thursday:
        return 'ЧТ';
      case DateTime.friday:
        return 'ПТ';
      case DateTime.saturday:
        return 'СБ';
      case DateTime.sunday:
        return 'ВС';
    }
    return '';
  }

  Widget _sectionBox(
    BuildContext ctx, {
    required String title,
    required Widget child,
  }) {
    final cs = Theme.of(ctx).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: cs.onSurface.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _dayChip(BuildContext ctx, DateTime d, {required bool selected}) {
    final cs = Theme.of(ctx).colorScheme;
    final bg = selected
        ? cs.primary.withValues(alpha: 0.18)
        : cs.surfaceContainerHighest.withValues(alpha: 0.18);
    final border = selected
        ? cs.primary.withValues(alpha: 0.65)
        : cs.outlineVariant.withValues(alpha: 0.55);
    final label = '${_weekdayShortRu(d.weekday)} ${d.day}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: cs.onSurface.withValues(alpha: 0.92),
        ),
      ),
    );
  }

  Widget _timeSlotBtn(
    BuildContext ctx,
    DateTime s, {
    required bool selected,
    required VoidCallback onTap,
    required bool disabled,
  }) {
    final cs = Theme.of(ctx).colorScheme;
    final label = DateFormat('HH:mm').format(s);

    if (selected) {
      return FilledButton(
        onPressed: disabled ? null : onTap,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: const StadiumBorder(),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      );
    }

    return OutlinedButton(
      onPressed: disabled ? null : onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: const StadiumBorder(),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.8)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  int _roundUpToStepMin(int totalMin, int stepMin) {
    if (totalMin <= 0) return 0;
    final q = (totalMin + stepMin - 1) ~/ stepMin;
    return q * stepMin;
  }

  // ✅ FIX: TODAY => not show slots in the past
  List<DateTime> _buildSlotsForDay(DateTime day) {
    final now = DateTime.now();

    var start = DateTime(day.year, day.month, day.day, _openHour, 0);
    final end = DateTime(day.year, day.month, day.day, _closeHour, 0);

    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;

    if (isToday) {
      final min = now.add(const Duration(minutes: 5));
      final mod = min.minute % _slotStepMin;
      final add = mod == 0 ? 0 : (_slotStepMin - mod);

      final rounded = DateTime(
        min.year,
        min.month,
        min.day,
        min.hour,
        min.minute,
      ).add(Duration(minutes: add));
      if (rounded.isAfter(start)) start = rounded;
    }

    if (!start.isBefore(end)) return const [];

    final out = <DateTime>[];
    var cur = start;
    while (cur.isBefore(end)) {
      out.add(cur);
      cur = cur.add(const Duration(minutes: _slotStepMin));
    }
    return out;
  }

  bool _overlaps(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) {
    return aStart.isBefore(bEnd) && bStart.isBefore(aEnd);
  }

  List<DateTimeRange> _parseBusyRanges(List<dynamic> rows) {
    final out = <DateTimeRange>[];
    for (final x in rows) {
      if (x is Map) {
        final s = x['start']?.toString() ?? '';
        final e = x['end']?.toString() ?? '';
        final ds = DateTime.tryParse(s);
        final de = DateTime.tryParse(e);
        if (ds != null && de != null) {
          out.add(DateTimeRange(start: ds.toLocal(), end: de.toLocal()));
        }
      }
    }
    return out;
  }

  String _buildCarLineFromWaitlist(Map<String, dynamic> w) {
    final plate = (w['car']?['plateDisplay'] ?? '').toString().trim();
    final make = (w['car']?['makeDisplay'] ?? '').toString().trim();
    final body = (w['car']?['bodyType'] ?? '').toString().trim();

    bool ok(String s) => s.isNotEmpty && s != '—' && s.toLowerCase() != 'null';

    final parts = <String>[];
    if (ok(plate)) parts.add(plate);
    if (ok(make)) parts.add(make);
    if (ok(body)) parts.add(body);

    return parts.join(' • ');
  }

  String _reasonRu(String raw) {
    final r = raw.trim();
    if (r.isEmpty) return '—';

    final up = r.toUpperCase();
    if (up.contains('ALL_BAYS_CLOSED')) return 'Все посты закрыты';
    if (up.contains('BAY_CLOSED')) return 'Пост закрыт';

    return r;
  }

  String _phoneFromWaitlist(Map<String, dynamic> w) {
    return (w['client']?['phone'] ?? '').toString().trim();
  }

  Future<void> _copyPhone(String phone) async {
    final p = phone.trim();
    if (p.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: p));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Номер скопирован'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _dispatcherCall(String phone) async {
    final p = phone.trim();
    if (p.isEmpty) return;
    await _copyPhone(p);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Номер скопирован. Вставь в телефон для звонка.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ✅ NEW: delete waitlist from UI (with reason + audit on backend)
  Future<void> _deleteWaitlist(
    Map<String, dynamic> w, {
    required BuildContext sheetCtx,
  }) async {
    final sid = widget.session.activeShiftId ?? '';
    if (sid.isEmpty) return;

    final wid = (w['id'] ?? '').toString().trim();
    if (wid.isEmpty) return;

    final reasonCtrl = TextEditingController(text: 'Клиент не отвечает');
    final ok = await showDialog<bool>(
      context: sheetCtx,
      barrierDismissible: false,
      builder: (dctx) => AlertDialog(
        title: const Text('Удалить из ожидания?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Запись будет скрыта из WAITING и попадёт в аудит.'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Причина (обязательно)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dctx).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final reason = reasonCtrl.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Причина обязательна'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      setState(() => loading = true);

      await widget.api.deleteWaitlist(
        widget.session.userId,
        sid,
        wid,
        reason: reason,
      );

      if (!mounted) return;

      Navigator.of(sheetCtx).pop();
      await load();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Удалено из ожидания'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ====== CONTINUATION: WaitlistTab (from _openConvertToQueueSheet to end) ======

  Future<void> _openConvertToQueueSheet(Map<String, dynamic> w) async {
    final sid = widget.session.activeShiftId ?? '';
    if (sid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет активной смены. Перезайди.')),
      );
      return;
    }

    // запрет если все посты закрыты
    final bays = await widget.api.listBays(widget.session.userId, sid);
    final activeBays = <int>[];
    for (final x in bays) {
      if (x is Map<String, dynamic>) {
        final n = (x['number'] as num?)?.toInt();
        final a = x['isActive'] == true;
        if (n != null && a && (n == 1 || n == 2)) activeBays.add(n);
      }
    }

    if (activeBays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Посты закрыты. Открой пост, чтобы поставить в очередь.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final waitlistId = (w['id'] ?? '').toString().trim();
    if (waitlistId.isEmpty) return;

    final locId = widget.session.locationId.trim();
    if (locId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Нет locationId в сессии.')));
      return;
    }

    // длительность слота: service.duration + buffer, округляем вверх до 30
    final dur = (w['service']?['durationMin'] as num?)?.toInt() ?? 30;
    final blockMin = _roundUpToStepMin(dur + _bufferMin, _slotStepMin);

    DateTime selectedDayLocal = _dateOnly(DateTime.now());
    int selectedBay = activeBays.first;
    DateTime? selectedSlot;

    List<DateTimeRange> busy = const [];

    Future<void> loadBusy() async {
      final from = DateTime(
        selectedDayLocal.year,
        selectedDayLocal.month,
        selectedDayLocal.day,
        _openHour,
        0,
      );
      final to = DateTime(
        selectedDayLocal.year,
        selectedDayLocal.month,
        selectedDayLocal.day,
        _closeHour,
        0,
      );

      final rows = await widget.api.publicBusySlots(
        locationId: locId,
        bayId: selectedBay,
        fromIsoUtc: from.toUtc().toIso8601String(),
        toIsoUtc: to.toUtc().toIso8601String(),
      );

      busy = _parseBusyRanges(rows);
    }

    bool isFree(DateTime start) {
      final end = start.add(Duration(minutes: blockMin));
      for (final r in busy) {
        if (_overlaps(start, end, r.start, r.end)) return false;
      }
      return true;
    }

    List<DateTime> freeSlots() {
      final all = _buildSlotsForDay(selectedDayLocal);
      return all.where(isFree).toList();
    }

    await loadBusy();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        bool converting = false;
        bool loadingSlots = false;

        Future<void> refresh(StateSetter setSheet) async {
          setSheet(() => loadingSlots = true);
          try {
            await loadBusy();
            if (selectedSlot != null && !isFree(selectedSlot!)) {
              selectedSlot = null;
            }
          } catch (_) {
            // ignore
          } finally {
            setSheet(() => loadingSlots = false);
          }
        }

        Future<void> convert(BuildContext ctx, StateSetter setSheet) async {
          if (converting) return;
          if (selectedSlot == null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Выбери время.')));
            return;
          }

          setSheet(() => converting = true);

          try {
            await widget.api.convertWaitlistToBooking(
              widget.session.userId,
              sid,
              waitlistId,
              bayId: selectedBay,
              dateTimeIso: selectedSlot!.toUtc().toIso8601String(),
            );

            if (!mounted) return;
            Navigator.of(ctx).pop(); // close convert sheet
            await load();
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
          } finally {
            setSheet(() => converting = false);
          }
        }

        return SafeArea(
          child: StatefulBuilder(
            builder: (ctx, setSheet) {
              final cs = Theme.of(ctx).colorScheme;
              final slots = freeSlots();
              final days = List.generate(
                7,
                (i) => _dateOnly(DateTime.now().add(Duration(days: i))),
              );

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
                            'В очередь',
                            style: Theme.of(ctx).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: selectedBay,
                            decoration: const InputDecoration(
                              labelText: 'Пост',
                            ),
                            items: [
                              for (final b in activeBays)
                                DropdownMenuItem(
                                  value: b,
                                  child: Text('Пост $b'),
                                ),
                            ],
                            onChanged: (loadingSlots || converting)
                                ? null
                                : (v) async {
                                    selectedBay = v ?? activeBays.first;
                                    selectedSlot = null;
                                    await refresh(setSheet);
                                  },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.6),
                            ),
                            color: cs.surfaceContainerHighest.withValues(
                              alpha: 0.14,
                            ),
                          ),
                          child: Text(
                            'Слот: $blockMin мин',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _sectionBox(
                      ctx,
                      title: 'Дата',
                      child: SizedBox(
                        height: 44,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: days.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (_, i) {
                            final d = days[i];
                            final selected = _dateOnly(d) == selectedDayLocal;

                            return InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: (loadingSlots || converting)
                                  ? null
                                  : () async {
                                      selectedDayLocal = _dateOnly(d);
                                      selectedSlot = null;
                                      await refresh(setSheet);
                                    },
                              child: _dayChip(ctx, d, selected: selected),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _sectionBox(
                      ctx,
                      title: 'Время',
                      child: () {
                        if (loadingSlots) {
                          return const Padding(
                            padding: EdgeInsets.all(12),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (slots.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'Нет доступных слотов на выбранный день.',
                              style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.75),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        }

                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final s in slots)
                                _timeSlotBtn(
                                  ctx,
                                  s,
                                  selected: selectedSlot == s,
                                  disabled: converting,
                                  onTap: () => setSheet(() => selectedSlot = s),
                                ),
                            ],
                          ),
                        );
                      }(),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: (loadingSlots || converting)
                            ? null
                            : () => convert(ctx, setSheet),
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

  Future<void> _openWaitlistSheet(Map<String, dynamic> w) async {
    final cs = Theme.of(context).colorScheme;

    final dtIso = (w['desiredDateTime'] ?? w['dateTime'] ?? '').toString();
    final time = dtIso.isNotEmpty ? fmtTime(dtIso) : '--:--';

    final bay = (w['desiredBayId'] ?? w['bayId'] ?? '').toString();
    final serviceName = w['service']?['name']?.toString() ?? 'Услуга';

    final clientName = (w['client']?['name'] ?? '').toString().trim();
    final clientPhone = _phoneFromWaitlist(w);
    final clientTitle = clientName.isNotEmpty
        ? clientName
        : (clientPhone.isNotEmpty ? clientPhone : 'Клиент');

    final carLine = _buildCarLineFromWaitlist(w);

    final reasonRaw = (w['reason'] ?? w['waitlistReason'] ?? '').toString();
    final reason = _reasonRu(reasonRaw);

    final hasPhone = clientPhone.isNotEmpty;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Ожидание • $time • Пост ${bay.isEmpty ? '—' : bay}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        serviceName,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        clientTitle,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      if (carLine.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          carLine,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        'Причина: $reason',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Телефон',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        hasPhone ? clientPhone : '—',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: hasPhone
                                  ? () => _copyPhone(clientPhone)
                                  : null,
                              icon: const Icon(Icons.copy),
                              label: const Text('Скопировать'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: hasPhone
                                  ? () => Share.share(clientPhone)
                                  : null,
                              icon: const Icon(Icons.share),
                              label: const Text('Поделиться'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: hasPhone
                              ? () => _dispatcherCall(clientPhone)
                              : null,
                          icon: const Icon(Icons.phone),
                          label: const Text('Позвонить'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: loading
                            ? null
                            : () async {
                                Navigator.of(sheetCtx).pop();
                                await Future<void>.delayed(
                                  const Duration(milliseconds: 150),
                                );
                                if (!mounted) return;
                                await _openConvertToQueueSheet(w);
                              },
                        icon: const Icon(Icons.playlist_add),
                        label: const Text('В очередь'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: loading
                            ? null
                            : () => _deleteWaitlist(w, sheetCtx: sheetCtx),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Удалить'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(sheetCtx).pop(),
                  child: const Text('Закрыть'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _waitlistCard(BuildContext context, Map<String, dynamic> w) {
    final cs = Theme.of(context).colorScheme;

    final dtIso = (w['desiredDateTime'] ?? w['dateTime'] ?? '').toString();
    final time = dtIso.isNotEmpty ? fmtTime(dtIso) : '--:--';

    final bay = (w['desiredBayId'] ?? w['bayId'] ?? '').toString();
    final serviceName = w['service']?['name']?.toString() ?? 'Услуга';

    final clientName = (w['client']?['name'] ?? '').toString().trim();
    final clientPhone = _phoneFromWaitlist(w);
    final clientTitle = clientName.isNotEmpty
        ? clientName
        : (clientPhone.isNotEmpty ? clientPhone : 'Клиент');

    final carLine = _buildCarLineFromWaitlist(w);

    final reasonRaw = (w['reason'] ?? w['waitlistReason'] ?? '').toString();
    final reason = _reasonRu(reasonRaw);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _openWaitlistSheet(w),
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
              'Причина: $reason',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.75),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) =>
                  _waitlistCard(context, waitlist[i] as Map<String, dynamic>),
            ),
    );
  }
}
