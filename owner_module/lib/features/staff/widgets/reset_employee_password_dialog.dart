import 'package:flutter/material.dart';

class ResetEmployeePasswordDialog extends StatefulWidget {
  const ResetEmployeePasswordDialog({super.key});

  @override
  State<ResetEmployeePasswordDialog> createState() =>
      _ResetEmployeePasswordDialogState();
}

class _ResetEmployeePasswordDialogState
    extends State<ResetEmployeePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_passwordController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Сброс пароля'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: TextFormField(
            controller: _passwordController,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Новый пароль',
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _obscure = !_obscure;
                  });
                },
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (value) {
              final v = (value ?? '').trim();
              if (v.isEmpty) return 'Введите пароль';
              if (v.length < 6) return 'Минимум 6 символов';
              return null;
            },
            onFieldSubmitted: (_) => _submit(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Сбросить')),
      ],
    );
  }
}
