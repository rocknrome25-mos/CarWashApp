import 'package:flutter/material.dart';
import '../core/data/app_repository.dart';
import 'login_page.dart';
import 'registration_page.dart';

class StartPage extends StatefulWidget {
  final AppRepository repo;
  final VoidCallback onAuthed;

  const StartPage({super.key, required this.repo, required this.onAuthed});

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  Future<void> _goLogin() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => LoginPage(repo: widget.repo)),
    );

    if (ok == true) {
      widget.onAuthed();
    }
  }

  Future<void> _goRegister() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => RegistrationPage(repo: widget.repo)),
    );

    if (ok == true) {
      widget.onAuthed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ✅ White logo card (no sharp corners)
              Container(
                width: 170,
                height: 170,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(34),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.35),
                  ),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                      color: Colors.black.withValues(alpha: 0.20),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/logo/carwash_logo_512.png',
                  fit: BoxFit.contain,
                ),
              ),

              const SizedBox(height: 14),

              Text(
                'Автомойка',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: cs.onSurface.withValues(alpha: 0.95),
                ),
              ),

              const Spacer(flex: 3),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _goLogin,
                  child: const Text('Войти'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _goRegister,
                  child: const Text('Зарегистрироваться'),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
