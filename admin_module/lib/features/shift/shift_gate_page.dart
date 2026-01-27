import 'package:flutter/material.dart';
import '../../core/api/admin_api_client.dart';
import '../../core/models/admin_session.dart';
import '../../core/storage/session_store.dart';
import '../login/login_page.dart';
import '../shell/shell_page.dart';

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

  bool get _cashEnabled => session.featureOn('CASH_DRAWER', defaultValue: true);

  Future<void> _logout() async {
    await widget.store.clear();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LoginPage(api: widget.api, store: widget.store),
      ),
    );
  }

  Future<int?> _askOpenFloat() async {
    final ctrl = TextEditingController(text: '0');
    return showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Наличные в кассе на начало смены'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Сумма (₽)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(
              int.tryParse(ctrl.text.trim()),
            ),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Future<void> _openShift() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final shift = await widget.api.openShift(session.userId);
      final shiftId = (shift['id'] ?? '').toString();

      session = session.copyWith(activeShiftId: shiftId);
      await widget.store.save(session);

      if (_cashEnabled) {
        final openFloat = await _askOpenFloat();
        if (openFloat == null) {
          throw Exception('Нужно указать сумму наличных в кассе на начало смены');
        }
        await widget.api.cashOpenFloat(
          session.userId,
          shiftId,
          openFloat,
          note: 'Размен/остаток на начало',
        );
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ShellPage(api: widget.api, store: widget.store, session: session),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shiftId = session.activeShiftId;

    if (shiftId != null && shiftId.isNotEmpty) {
      return ShellPage(api: widget.api, store: widget.store, session: session);
    }

    final locationTitle =
        (session.locationName ?? '').trim().isNotEmpty ? session.locationName!.trim() : session.locationId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Смена'),
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Админ: ${session.phone}'),
            Text('Локация: $locationTitle'),
            const SizedBox(height: 12),
            if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : _openShift,
                child: loading
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator())
                    : const Text('Открыть смену'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}