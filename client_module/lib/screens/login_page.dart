import 'package:flutter/material.dart';
import '../core/data/app_repository.dart';

class LoginPage extends StatefulWidget {
  final AppRepository repo;

  const LoginPage({super.key, required this.repo});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneCtrl = TextEditingController(text: '+7 999 123-45-67');
  final _passCtrl = TextEditingController(text: '1234');
  final _nameCtrl = TextEditingController(text: 'Роман');

  String _gender = 'MALE'; // MALE / FEMALE
  bool _loading = false;

  String _normalizePhone(String raw) {
    final s = raw.trim();
    final digits = s.replaceAll(RegExp(r'\D'), '');

    // нормализуем к +7XXXXXXXXXX
    if (digits.length == 10) return '+7$digits';
    if (digits.length == 11 && digits.startsWith('8')) {
      return '+7${digits.substring(1)}';
    }
    if (digits.length == 11 && digits.startsWith('7')) return '+$digits';
    if (s.startsWith('+') && digits.length >= 11) return '+$digits';
    return s;
  }

  bool _looksLikeRuPhone(String p) {
    final digits = p.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return false;
    if (digits.length == 10) return true;
    if (digits.length == 11 &&
        (digits.startsWith('7') || digits.startsWith('8'))) {
      return true;
    }
    return false;
  }

  Future<void> _submit() async {
    if (_loading) return;

    final phoneRaw = _phoneCtrl.text;
    final pass = _passCtrl.text.trim();
    final name = _nameCtrl.text.trim();

    final phone = _normalizePhone(phoneRaw);

    if (!_looksLikeRuPhone(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Проверь телефон. Нужно минимум 10 цифр.'),
        ),
      );
      return;
    }

    if (name.isEmpty || name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите имя (минимум 2 символа).')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // прототип: пароль только 1234
      if (pass != '1234') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Неверный пароль (для прототипа: 1234)'),
          ),
        );
        return;
      }

      // ✅ “правильный” прототипный вход:
      // используем idempotent register (создаст/обновит клиента по телефону),
      // и имя будет реальным, не “Demo”
      await widget.repo.registerClient(
        phone: phone,
        name: name,
        gender: _gender,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgot() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Восстановление доступа'),
        content: const Text(
          'Скоро добавим восстановление по телефону/SMS.\n\nПока прототип: телефон + пароль 1234',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Ок'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Вход')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: primary.withValues(alpha: 0.15)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Прототипный вход\nТелефон + имя + пароль 1234',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Телефон',
                hintText: '+7 999 123-45-67',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _nameCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Имя',
                hintText: 'Например: Роман',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: _gender,
              decoration: const InputDecoration(
                labelText: 'Пол',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'MALE', child: Text('Мужской')),
                DropdownMenuItem(value: 'FEMALE', child: Text('Женский')),
              ],
              onChanged: _loading
                  ? null
                  : (v) => setState(() => _gender = v ?? 'MALE'),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _passCtrl,
              obscureText: true,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Пароль',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _loading ? null : _forgot,
                child: const Text('Забыл логин/пароль'),
              ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _loading ? null : _submit,
                icon: const Icon(Icons.login),
                label: Text(_loading ? 'Входим...' : 'Войти'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
