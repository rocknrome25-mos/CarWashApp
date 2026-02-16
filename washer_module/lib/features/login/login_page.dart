import 'package:flutter/material.dart';
import '../../core/api/washer_api_client.dart';
import '../../core/storage/washer_session_store.dart';
import '../shell/shell_page.dart';

class LoginPage extends StatefulWidget {
  final WasherApiClient api;
  final WasherSessionStore store;

  const LoginPage({super.key, required this.api, required this.store});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final ctrl = TextEditingController(text: '+79990000101');
  bool loading = false;
  String? error;

  Future<void> _doLogin() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final res = await widget.api.login(ctrl.text.trim());
      final user = (res['user'] as Map).cast<String, dynamic>();

      await widget.store.save(
        userId: user['id'].toString(),
        phone: user['phone'].toString(),
        name: user['name']?.toString(),
        locationId: user['locationId'].toString(),
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ShellPage(api: widget.api, store: widget.store),
        ),
      );
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Вход мойщика')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Телефон',
                hintText: '+7999...',
              ),
            ),
            const SizedBox(height: 12),
            if (error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  error!,
                  style: TextStyle(color: cs.onErrorContainer),
                ),
              ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: loading ? null : _doLogin,
                child: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
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
