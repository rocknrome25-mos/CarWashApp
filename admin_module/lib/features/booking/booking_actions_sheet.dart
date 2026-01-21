import 'package:flutter/material.dart';
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

  @override
  void dispose() {
    noteCtrl.dispose();
    moveReasonCtrl.dispose();
    super.dispose();
  }

  String get _userId => widget.session.userId;
  String get _shiftId => widget.session.activeShiftId ?? '';
  String get _bookingId => widget.booking['id'] as String;

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
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _start() async {
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
    await _run(() async {
      await widget.api.finishBooking(
        _userId,
        _shiftId,
        _bookingId,
        noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      );
    });
  }

  Future<void> _move() async {
    final b = widget.booking;

    // простая логика: переносим на +30 минут от текущего dateTime
    final currentIso = b['dateTime'] as String;
    final current = DateTime.parse(currentIso).toUtc();
    final newDt = current.add(const Duration(minutes: 30));

    final bayId = (b['bayId'] as num).toInt();
    final reason = moveReasonCtrl.text.trim();

    await _run(() async {
      await widget.api.moveBooking(
        _userId,
        _shiftId,
        _bookingId,
        newDateTimeIso: newDt.toIso8601String(),
        newBayId: bayId,
        reason: reason.isEmpty ? 'Перенос' : reason,
        clientAgreed: clientAgreed,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final serviceName = b['service']?['name']?.toString() ?? 'Service';
    final status = b['status']?.toString() ?? '';
    final bayId = b['bayId']?.toString() ?? '';
    final clientName = b['client']?['name']?.toString();
    final clientPhone = b['client']?['phone']?.toString();
    final titleClient = (clientName != null && clientName.isNotEmpty)
        ? clientName
        : (clientPhone ?? '');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '$serviceName • Bay $bayId',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text('Client: $titleClient'),
              Text('Status: $status'),
              const SizedBox(height: 12),

              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Admin note (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              const Divider(),
              const SizedBox(height: 8),

              Row(
                children: [
                  Checkbox(
                    value: clientAgreed,
                    onChanged: loading
                        ? null
                        : (v) => setState(() => clientAgreed = v ?? false),
                  ),
                  const Expanded(child: Text('Client agreed to move')),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: moveReasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Move reason',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              if (error != null) ...[
                Text(error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 8),
              ],

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: loading ? null : _start,
                      child: loading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(),
                            )
                          : const Text('Start'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: loading ? null : _move,
                      child: const Text('Move +30m'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: loading ? null : _finish,
                      child: const Text('Finish'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              TextButton(
                onPressed: loading ? null : () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
