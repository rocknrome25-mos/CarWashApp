import 'package:flutter/material.dart';
import '../../core/api/admin_api_client.dart';
import '../../core/models/admin_session.dart';
import '../../core/storage/session_store.dart';
import '../shift/shift_gate_page.dart';

class LoginPage extends StatefulWidget {
  final AdminApiClient api;
  final SessionStore store;

  const LoginPage({super.key, required this.api, required this.store});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final ctrl = TextEditingController(text: '+79990000011');

  bool loading = false;
  String? error;

  Map<String, bool> _parseFeatures(Map<String, dynamic> cfg) {
    final out = <String, bool>{};
    final f = cfg['features'];

    if (f is Map) {
      f.forEach((k, v) {
        if (v is Map && v['enabled'] is bool) {
          out[k.toString()] = v['enabled'] as bool;
        } else if (v is bool) {
          out[k.toString()] = v;
        }
      });
    }

    return out;
  }

  String? _parseLocationName(Map<String, dynamic> cfg) {
    final loc = cfg['location'];
    if (loc is Map) {
      final name = (loc['name'] ?? '').toString().trim();
      if (name.isNotEmpty) return name;
    }
    return null;
  }

  Future<void> _login() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final loginJson = await widget.api.adminLogin(ctrl.text.trim());

      final user = loginJson['user'] as Map<String, dynamic>;
      final locationId = (user['locationId'] ?? '').toString();

      final cfg = await widget.api.getConfig(locationId);
      final features = _parseFeatures(cfg);
      final locationName = _parseLocationName(cfg);

      final session = AdminSession.fromLoginJson(
        loginJson,
        featuresEnabled: features,
        locationName: locationName,
      );

      await widget.store.save(session);

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ShiftGatePage(
            api: widget.api,
            store: widget.store,
            session: session,
          ),
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
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Login')),
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
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                    color: Colors.black.withValues(alpha: 0.06),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: cs.primary.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Icon(
                      Icons.admin_panel_settings_rounded,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Вход в админ-модуль',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: cs.onSurface.withValues(alpha: 0.96),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Введи телефон администратора, чтобы продолжить работу со сменой и календарём.',
                            style: textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.66),
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: ctrl,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => loading ? null : _login(),
              decoration: InputDecoration(
                labelText: 'Телефон',
                hintText: '+79990000011',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Theme.of(context).cardColor.withValues(alpha: 0.92),
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

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: loading ? null : _login,
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
                    : const Icon(Icons.login_rounded),
                label: Text(
                  loading ? 'Входим...' : 'Войти',
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
