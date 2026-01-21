import 'package:flutter/material.dart';
import '../../core/api/admin_api_client.dart';
import '../../core/models/admin_session.dart';
import '../../core/storage/session_store.dart';
import '../calendar/calendar_page.dart';
import '../login/login_page.dart';

class ShiftGatePage extends StatefulWidget {
  final AdminApiClient api;
  final SessionStore store;
  final AdminSession session;

  const ShiftGatePage({
    super.key,
    required this.api,
    required this.store,
    required this.session,
  });

  @override
  State<ShiftGatePage> createState() => _ShiftGatePageState();
}

class _ShiftGatePageState extends State<ShiftGatePage> {
  bool loading = false;
  String? error;
  late AdminSession session = widget.session;

  Future<void> _openShift() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final shift = await widget.api.openShift(session.userId);
      final shiftId = shift['id'] as String;
      session = session.copyWith(activeShiftId: shiftId);
      await widget.store.save(session);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CalendarPage(
            api: widget.api,
            store: widget.store,
            session: session,
          ),
        ),
      );
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _logout() async {
    await widget.store.clear();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LoginPage(api: widget.api, store: widget.store),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shiftId = session.activeShiftId;

    if (shiftId != null && shiftId.isNotEmpty) {
      // сразу в календарь
      return CalendarPage(
        api: widget.api,
        store: widget.store,
        session: session,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shift'),
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Admin: ${session.phone}'),
            Text('Location: ${session.locationId}'),
            const SizedBox(height: 12),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : _openShift,
                child: loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(),
                      )
                    : const Text('Open Shift'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
