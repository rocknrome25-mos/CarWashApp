import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/washer_api_client.dart';
import '../../core/storage/washer_session_store.dart';

class ClockPage extends StatefulWidget {
  final WasherApiClient api;
  final WasherSessionStore store;

  const ClockPage({super.key, required this.api, required this.store});

  @override
  State<ClockPage> createState() => _ClockPageState();
}

class _ClockPageState extends State<ClockPage>
    with SingleTickerProviderStateMixin {
  bool loading = true;
  bool refreshing = false;
  String? error;

  bool noAssignment = false;

  Map<String, dynamic>? shift;
  DateTime? lastUpdated;

  Timer? _timer;
  static const _autoRefreshSec = 15;

  late final AnimationController _introController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  bool _asBool(dynamic v) {
    if (v is bool) return v;
    final s = (v ?? '').toString().trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes';
  }

  DateTime? _asDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString())?.toLocal();
  }

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnim = CurvedAnimation(
      parent: _introController,
      curve: Curves.easeOut,
    );

    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.035), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _introController, curve: Curves.easeOutCubic),
        );

    _load(initial: true).then((_) {
      if (mounted) _introController.forward();
    });

    _timer = Timer.periodic(const Duration(seconds: _autoRefreshSec), (
      _,
    ) async {
      if (!mounted) return;
      if (loading || refreshing) return;
      await _load(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _introController.dispose();
    super.dispose();
  }

  Future<void> _load({bool initial = false, bool silent = false}) async {
    setState(() {
      if (initial) loading = true;
      refreshing = !initial;
      if (!silent) error = null;
    });

    try {
      final s = await widget.api.getCurrentShift();
      if (!mounted) return;
      setState(() {
        shift = s;
        noAssignment = false;
        lastUpdated = DateTime.now();
      });
    } on WasherApiException catch (e) {
      if (!mounted) return;
      if (e.status == 404) {
        setState(() {
          noAssignment = true;
          shift = null;
          lastUpdated = DateTime.now();
        });
      } else {
        if (!silent) setState(() => error = e.toString());
      }
    } catch (e) {
      if (!silent && mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
          refreshing = false;
        });
      }
    }
  }

  Future<void> _clockIn() async {
    try {
      await widget.api.clockIn();
      await _load();
      _snack('Clock-in отмечен');
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _clockOut() async {
    try {
      await widget.api.clockOut();
      await _load();
      _snack('Clock-out отмечен');
    } catch (e) {
      _snack(e.toString());
    }
  }

  void _snack(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: _YCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: cs.error.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.error_outline, color: cs.error),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Не удалось загрузить данные',
                        textAlign: TextAlign.center,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error!,
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.78),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: _ScaleTap(
                          child: FilledButton(
                            onPressed: () => _load(),
                            child: const Text('Повторить'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (noAssignment) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: _YCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.work_off, color: cs.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Нет активного назначения',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Clock-in будет доступен после назначения на пост.',
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface.withValues(alpha: 0.78),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: refreshing ? null : () => _load(),
                      icon: refreshing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      tooltip: 'Обновить',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final s = shift!;
    final clock = (s['clock'] as Map).cast<String, dynamic>();

    final canIn = _asBool(clock['canClockIn']);
    final canOut = _asBool(clock['canClockOut']);

    final inAt = _asDate(clock['clockInAt']);
    final outAt = _asDate(clock['clockOutAt']);

    final df = DateFormat('dd.MM HH:mm');
    final tf = DateFormat('HH:mm:ss');

    String statusText;
    IconData statusIcon;
    Color statusColor;

    if (inAt != null && outAt == null) {
      statusText = 'На смене';
      statusIcon = Icons.play_circle_outline;
      statusColor = Colors.green;
    } else if (inAt != null && outAt != null) {
      statusText = 'Смена закрыта';
      statusIcon = Icons.check_circle_outline;
      statusColor = cs.primary;
    } else {
      statusText = 'Ожидает отметку';
      statusIcon = Icons.schedule;
      statusColor = Colors.orange;
    }

    return RefreshIndicator(
      onRefresh: () => _load(),
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              _YCard(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.access_time, color: cs.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Табель',
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              lastUpdated == null
                                  ? 'Обновление…'
                                  : 'Обновлено: ${tf.format(lastUpdated!)}',
                              style: textTheme.bodySmall?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.65),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: refreshing ? null : () => _load(),
                        icon: refreshing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh),
                        tooltip: 'Обновить',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              _YCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Сегодня',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Отмечайте начало и завершение смены',
                        style: textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),

                      _StatusPill(
                        icon: statusIcon,
                        text: statusText,
                        color: statusColor,
                      ),

                      const SizedBox(height: 14),

                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(
                            alpha: 0.35,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Column(
                          children: [
                            _RowLine(
                              label: 'Clock-in',
                              value: inAt == null ? '—' : df.format(inAt),
                              icon: Icons.login_rounded,
                            ),
                            const SizedBox(height: 10),
                            _RowLine(
                              label: 'Clock-out',
                              value: outAt == null ? '—' : df.format(outAt),
                              icon: Icons.logout_rounded,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: _ScaleTap(
                              child: FilledButton.icon(
                                onPressed: canIn ? _clockIn : null,
                                icon: const Icon(Icons.login_rounded),
                                label: const Text('Clock-in'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ScaleTap(
                              child: OutlinedButton.icon(
                                onPressed: canOut ? _clockOut : null,
                                icon: const Icon(Icons.logout_rounded),
                                label: const Text('Clock-out'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowLine extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _RowLine({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: cs.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface.withValues(alpha: 0.72),
            ),
          ),
        ),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _StatusPill({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScaleTap extends StatefulWidget {
  final Widget child;

  const _ScaleTap({required this.child});

  @override
  State<_ScaleTap> createState() => _ScaleTapState();
}

class _ScaleTapState extends State<_ScaleTap> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      behavior: HitTestBehavior.translucent,
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _YCard extends StatelessWidget {
  final Widget child;
  const _YCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.58)),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 8),
            color: Colors.black.withValues(alpha: 0.06),
          ),
        ],
      ),
      child: child,
    );
  }
}
