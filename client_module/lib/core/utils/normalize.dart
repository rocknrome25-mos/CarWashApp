String normalizePlate(String input) {
  final s = input.trim().toUpperCase();
  // Убираем пробелы и дефисы, оставляем буквы/цифры
  final cleaned = s.replaceAll(RegExp(r'[\s\-]'), '');
  final only = cleaned.replaceAll(RegExp(r'[^A-Z0-9А-Я0-9]'), '');
  return only;
}

String normalizeName(String input) {
  final s = input.trim().toLowerCase();
  // Убираем повторные пробелы и мусор, оставляем буквы/цифры/пробелы/дефисы
  final cleaned = s.replaceAll(RegExp(r'[^a-z0-9а-яё\-\s]'), '');
  return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
}
