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
  late String ymd;

  @override
  void initState() {
    super.initState();
    ymd = DateFormat('yyyy-MM-dd').format(DateTime.now());
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
        ymd,
      );
      setState(() => bookings = list);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _closeShift() async {
    try {
      await widget.api.closeShift(
        widget.session.userId,
        widget.session.activeShiftId!,
      );
      await widget.store.clear();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => LoginPage(api: widget.api, store: widget.store),
        ),
        (r) => false,
      );
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  String _fmtTime(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    return DateFormat('HH:mm').format(dt);
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ACTIVE':
        return Colors.blue;
      case 'PENDING_PAYMENT':
        return Colors.orange;
      case 'COMPLETED':
        return Colors.green;
      case 'CANCELED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final shiftId = widget.session.activeShiftId ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('Calendar ($ymd)'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          TextButton(onPressed: _closeShift, child: const Text('Close shift')),
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
          ? const Center(child: Text('No bookings'))
          : ListView.separated(
              itemCount: bookings.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final b = bookings[i] as Map<String, dynamic>;
                final status = (b['status'] ?? '').toString();
                final serviceName =
                    b['service']?['name']?.toString() ?? 'Service';
                final bayId = b['bayId']?.toString() ?? '';
                final dateTimeIso = b['dateTime']?.toString() ?? '';
                final startedAt = b['startedAt']?.toString();
                final finishedAt = b['finishedAt']?.toString();
                final clientName = b['client']?['name']?.toString();
                final clientPhone = b['client']?['phone']?.toString();
                final clientTitle =
                    (clientName != null && clientName.isNotEmpty)
                    ? clientName
                    : (clientPhone ?? '');

                final time = dateTimeIso.isNotEmpty
                    ? _fmtTime(dateTimeIso)
                    : '--:--';
                final badgeColor = _statusColor(status);

                final timing = [
                  if (startedAt != null) 'start ${_fmtTime(startedAt)}',
                  if (finishedAt != null) 'finish ${_fmtTime(finishedAt)}',
                ].join(' • ');

                return ListTile(
                  title: Text('$time • $serviceName • Bay $bayId'),
                  subtitle: Text(
                    '$clientTitle${timing.isEmpty ? "" : "\n$timing"}',
                  ),
                  isThreeLine: timing.isNotEmpty,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: badgeColor),
                    ),
                    child: Text(status, style: TextStyle(color: badgeColor)),
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
