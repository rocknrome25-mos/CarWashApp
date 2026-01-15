import 'package:flutter/material.dart';
import '../core/data/app_repository.dart';

enum Gender { male, female }

class RegistrationPage extends StatefulWidget {
  final AppRepository repo;

  const RegistrationPage({super.key, required this.repo});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _formKey = GlobalKey<FormState>();

  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  Gender? _gender;
  DateTime? _birthDate;

  bool _agree = false;
  bool _saving = false;

  String _fmtDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year}';
  }

  String _normalizePhone(String raw) {
    final s = raw.trim();
    final digits = s.replaceAll(RegExp(r'\D'), '');

    // нормализуем к +7XXXXXXXXXX (как на бэке)
    if (digits.length == 10) return '+7$digits';
    if (digits.length == 11 && digits.startsWith('8')) {
      return '+7${digits.substring(1)}';
    }
    if (digits.length == 11 && digits.startsWith('7')) return '+$digits';
    if (s.startsWith('+') && digits.length >= 11) return '+$digits';
    return raw.trim();
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

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initial = _birthDate ?? DateTime(now.year - 25, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900, 1, 1),
      lastDate: now,
      helpText: 'Дата рождения (необязательно)',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );

    if (!mounted) return;
    if (picked == null) return;

    setState(() => _birthDate = picked);
  }

  Future<void> _submit() async {
    if (_saving) return;

    final phone = _normalizePhone(_phoneCtrl.text);
    if (!_formKey.currentState!.validate()) return;

    if (!_looksLikeRuPhone(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Проверь телефон. Нужно минимум 10 цифр.'),
        ),
      );
      return;
    }

    if (_gender == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Выбери пол')));
      return;
    }

    if (!_agree) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нужно согласие на обработку данных')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final genderStr = _gender == Gender.male ? 'MALE' : 'FEMALE';

      await widget.repo.registerClient(
        phone: phone,
        name: _nameCtrl.text,
        gender: genderStr,
        birthDate: _birthDate,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true); // ✅ успех (авторизация для демо)
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Widget _genderButton({
    required Gender value,
    required IconData icon,
    required String label,
  }) {
    final selected = _gender == value;

    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        child: OutlinedButton.icon(
          onPressed: () => setState(() => _gender = value),
          icon: Icon(icon),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            side: BorderSide(
              width: selected ? 2 : 1,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.black.withValues(alpha: 0.18),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final birthText = _birthDate == null ? 'Не указана' : _fmtDate(_birthDate!);

    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Телефон',
                  hintText: '+7 999 123-45-67',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) return 'Телефон обязателен';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Имя (необязательно)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Пол',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.black.withValues(alpha: 0.85),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _genderButton(
                    value: Gender.male,
                    icon: Icons.male,
                    label: 'Муж',
                  ),
                  const SizedBox(width: 10),
                  _genderButton(
                    value: Gender.female,
                    icon: Icons.female,
                    label: 'Жен',
                  ),
                ],
              ),

              const SizedBox(height: 12),

              InkWell(
                onTap: _saving ? null : _pickBirthDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.20),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cake_outlined),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Дата рождения: $birthText',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _agree,
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _agree = v ?? false),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: GestureDetector(
                      onTap: _saving
                          ? null
                          : () => setState(() => _agree = !_agree),
                      child: const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'Я согласен(на) с условиями использования приложения и обработкой персональных данных.',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(
                    _saving ? 'Сохраняю...' : 'Зарегистрироваться / Продолжить',
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
