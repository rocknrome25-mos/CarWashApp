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
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;

        return AlertDialog(
          title: const Text('Наличные на начало смены'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.55),
                  ),
                ),
                child: Text(
                  'Укажи сумму наличных, которая остаётся в кассе на старте смены.',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withValues(alpha: 0.75),
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Сумма (₽)',
                  hintText: 'Например: 1500',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(int.tryParse(ctrl.text.trim())),
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
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
          throw Exception(
            'Нужно указать сумму наличных в кассе на начало смены',
          );
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
          builder: (_) =>
              ShellPage(api: widget.api, store: widget.store, session: session),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _infoCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String value,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 6),
            color: Colors.black.withValues(alpha: 0.04),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: cs.onSurface.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shiftId = session.activeShiftId;

    if (shiftId != null && shiftId.isNotEmpty) {
      return ShellPage(api: widget.api, store: widget.store, session: session);
    }

    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final locationTitle = (session.locationName ?? '').trim().isNotEmpty
        ? session.locationName!.trim()
        : session.locationId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Смена'),
        actions: [
          IconButton(
            tooltip: 'Выйти',
            onPressed: loading ? null : _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset + 8),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.45),
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                    color: Colors.black.withValues(alpha: 0.04),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: cs.primary.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Icon(Icons.schedule_rounded, color: cs.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Открытие смены',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: cs.onSurface.withValues(alpha: 0.96),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _cashEnabled
                              ? 'После открытия смены система попросит указать наличные на начало работы.'
                              : 'Смена откроется сразу после подтверждения.',
                          style: textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface.withValues(alpha: 0.66),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            _infoCard(
              context: context,
              icon: Icons.phone_iphone,
              title: 'Администратор',
              value: session.phone,
            ),

            const SizedBox(height: 10),

            _infoCard(
              context: context,
              icon: Icons.location_on_outlined,
              title: 'Локация',
              value: locationTitle,
            ),

            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.55),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _cashEnabled ? Icons.payments_outlined : Icons.info_outline,
                    color: cs.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _cashEnabled
                          ? 'Кассовый режим включён'
                          : 'Кассовый режим отключён',
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface.withValues(alpha: 0.90),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.red),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        error!,
                        style: textTheme.bodyMedium?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.90),
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: loading ? null : _openShift,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(
                  loading ? 'Открываем...' : 'Открыть смену',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
