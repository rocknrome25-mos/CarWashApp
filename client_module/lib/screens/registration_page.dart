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
      Navigator.of(context).pop(true);
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
    final cs = Theme.of(context).colorScheme;
    final selected = _gender == value;

    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        child: OutlinedButton.icon(
          onPressed: _saving ? null : () => setState(() => _gender = value),
          icon: Icon(icon),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 52),
            backgroundColor: selected
                ? cs.primary.withValues(alpha: 0.08)
                : Theme.of(context).cardColor,
            side: BorderSide(
              width: selected ? 1.8 : 1,
              color: selected
                  ? cs.primary
                  : cs.outlineVariant.withValues(alpha: 0.65),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final birthText = _birthDate == null ? 'Не указана' : _fmtDate(_birthDate!);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация')),
      body: SafeArea(
        child: Form(
          key: _formKey,
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
                        Icons.person_add_alt_1_rounded,
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
                              'Создать профиль',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: cs.onSurface.withValues(alpha: 0.96),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Укажи основные данные, чтобы продолжить и записываться на услуги.',
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

              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Телефон',
                  hintText: '+7 999 123-45-67',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).cardColor.withValues(alpha: 0.92),
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
                decoration: InputDecoration(
                  labelText: 'Имя (необязательно)',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).cardColor.withValues(alpha: 0.92),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'Пол',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: cs.onSurface.withValues(alpha: 0.92),
                ),
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  _genderButton(
                    value: Gender.male,
                    icon: Icons.male_rounded,
                    label: 'Муж',
                  ),
                  const SizedBox(width: 10),
                  _genderButton(
                    value: Gender.female,
                    icon: Icons.female_rounded,
                    label: 'Жен',
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _saving ? null : _pickBirthDate,
                  borderRadius: BorderRadius.circular(18),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).cardColor.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.55),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: cs.surfaceContainerHighest.withValues(
                              alpha: 0.22,
                            ),
                          ),
                          child: Icon(
                            Icons.cake_outlined,
                            color: cs.onSurface.withValues(alpha: 0.82),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Дата рождения',
                                style: textTheme.bodySmall?.copyWith(
                                  color: cs.onSurface.withValues(alpha: 0.65),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                birthText,
                                style: textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: cs.onSurface.withValues(alpha: 0.94),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: cs.onSurface.withValues(alpha: 0.55),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
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
                        child: Padding(
                          padding: const EdgeInsets.only(top: 11),
                          child: Text(
                            'Я согласен(на) с условиями использования приложения и обработкой персональных данных.',
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                              color: cs.onSurface.withValues(alpha: 0.88),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: Text(
                    _saving ? 'Сохраняю...' : 'Зарегистрироваться / Продолжить',
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
      ),
    );
  }
}
