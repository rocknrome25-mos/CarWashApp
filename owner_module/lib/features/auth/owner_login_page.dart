import 'package:flutter/material.dart';

import '../../core/data/app_repository.dart';

class OwnerLoginPage extends StatefulWidget {
  final AppRepository repo;
  final VoidCallback onSuccess;

  const OwnerLoginPage({
    super.key,
    required this.repo,
    required this.onSuccess,
  });

  @override
  State<OwnerLoginPage> createState() => _OwnerLoginPageState();
}

class _OwnerLoginPageState extends State<OwnerLoginPage> {
  bool _loading = false;

  Future<void> _enterDemo() async {
    setState(() => _loading = true);

    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    widget.onSuccess();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),

            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),

              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,

                children: [
                  // Логотип / иконка
                  Container(
                    width: 94,
                    height: 94,

                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEEE8),
                      borderRadius: BorderRadius.circular(28),

                      boxShadow: [
                        BoxShadow(
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                          color: Colors.black.withValues(alpha: 0.05),
                        ),
                      ],
                    ),

                    child: Icon(
                      Icons.bar_chart_rounded,
                      size: 46,
                      color: Colors.deepOrange.shade400,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Заголовок
                  Text(
                    'Кабинет владельца',

                    textAlign: TextAlign.center,

                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Подзаголовок
                  Text(
                    'ЖК Рассказово\nг. Москва, бульвар Андрея Тарковского, д. 10',

                    textAlign: TextAlign.center,

                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Карточка входа
                  Card(
                    elevation: 0,

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),

                    child: Padding(
                      padding: const EdgeInsets.all(24),

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,

                        children: [
                          Text(
                            'Вход в модуль',

                            textAlign: TextAlign.center,

                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),

                          const SizedBox(height: 14),

                          Text(
                            'Пока используем тестовый вход\nбез реальной авторизации.',

                            textAlign: TextAlign.center,

                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),

                          const SizedBox(height: 26),

                          SizedBox(
                            width: double.infinity,
                            height: 56,

                            child: FilledButton(
                              onPressed: _loading ? null : _enterDemo,

                              child: _loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Войти'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
