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

  String _gender = 'MALE';
  bool _loading = false;

  String _normalizePhone(String raw) {
    final s = raw.trim();
    final digits = s.replaceAll(RegExp(r'\D'), '');

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
      if (pass != '1234') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Неверный пароль (для прототипа: 1234)'),
          ),
        );
        return;
      }

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
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(title: const Text('Вход')),
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
                    child: Icon(Icons.lock_outline_rounded, color: cs.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Вход в профиль',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: cs.onSurface.withValues(alpha: 0.96),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Для демо: телефон, имя, пол и пароль 1234.',
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
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Телефон',
                hintText: '+7 999 123-45-67',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Theme.of(context).cardColor.withValues(alpha: 0.92),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _nameCtrl,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Имя',
                hintText: 'Например: Роман',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Theme.of(context).cardColor.withValues(alpha: 0.92),
              ),
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: _gender,
              decoration: InputDecoration(
                labelText: 'Пол',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Theme.of(context).cardColor.withValues(alpha: 0.92),
              ),
              isExpanded: true,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withValues(alpha: 0.92),
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
              decoration: InputDecoration(
                labelText: 'Пароль',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Theme.of(context).cardColor.withValues(alpha: 0.92),
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

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: _loading ? null : _submit,
                icon: const Icon(Icons.login_rounded),
                label: Text(
                  _loading ? 'Входим...' : 'Войти',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
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
