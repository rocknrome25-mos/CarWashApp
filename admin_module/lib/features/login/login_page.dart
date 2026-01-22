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

  Future<void> _login() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final loginJson = await widget.api.adminLogin(ctrl.text.trim());

      final user = loginJson['user'] as Map<String, dynamic>;
      final locationId = user['locationId'] as String;

      final cfg = await widget.api.getConfig(locationId);
      final features = _parseFeatures(cfg);

      final session = AdminSession.fromLoginJson(
        loginJson,
        featuresEnabled: features,
      );

      await widget.store.save(session);

      if (!mounted) {
        return;
      }

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
      if (!mounted) {
        return;
      }
      setState(() => error = e.toString());
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(labelText: 'Телефон'),
            ),
            const SizedBox(height: 12),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : _login,
                child: loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(),
                      )
                    : const Text('Войти'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
