import 'package:flutter/material.dart';

enum BayChoice { any, bay1, bay2 }

class SelectBayPage extends StatefulWidget {
  const SelectBayPage({super.key});

  @override
  State<SelectBayPage> createState() => _SelectBayPageState();
}

class _SelectBayPageState extends State<SelectBayPage> {
  static const Color _pinkAny = Color(0xFFE7A2B3);
  static const Color _greenLine = Color(0xFF2DBD6E);
  static const Color _blueLine = Color(0xFF2D9CDB);

  BayChoice choice = BayChoice.any;

  Color _stripe(BayChoice v) {
    switch (v) {
      case BayChoice.any:
        return _pinkAny;
      case BayChoice.bay1:
        return _greenLine;
      case BayChoice.bay2:
        return _blueLine;
    }
  }

  String _title(BayChoice v) {
    switch (v) {
      case BayChoice.any:
        return 'Любая линия';
      case BayChoice.bay1:
        return 'Зелёная линия';
      case BayChoice.bay2:
        return 'Синяя линия';
    }
  }

  Widget _item(BayChoice v) {
    final selected = choice == v;
    final stripe = _stripe(v);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => choice = v),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? stripe.withValues(alpha: 0.10) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? stripe.withValues(alpha: 0.55)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 28,
              decoration: BoxDecoration(
                color: stripe,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _title(v).toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.black.withValues(alpha: 0.85),
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: stripe, size: 18)
            else
              Icon(
                Icons.circle_outlined,
                color: Colors.black.withValues(alpha: 0.25),
                size: 18,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stripe = _stripe(choice);

    return Scaffold(
      appBar: AppBar(title: const Text('Выбрать линию')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _item(BayChoice.any),
            const SizedBox(height: 10),
            _item(BayChoice.bay1),
            const SizedBox(height: 10),
            _item(BayChoice.bay2),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: stripe,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(context).pop(choice),
                child: const Text(
                  'Далее',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
