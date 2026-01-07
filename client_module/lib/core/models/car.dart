import '../utils/normalize.dart';

class Car {
  final String id;

  // То, что видит пользователь (как выбрал/ввел)
  final String make;
  final String model;
  final String plateDisplay;

  // Нормализованные значения для отчетов/уникальности
  final String makeNormalized;
  final String modelNormalized;
  final String plateNormalized;

  final int? year;
  final String? color;
  final String? bodyType;

  Car({
    required this.id,
    required this.make,
    required this.model,
    required this.plateDisplay,
    required this.plateNormalized,
    this.year,
    String? color,
    String? bodyType,
  }) : color = (color == null || color.trim().isEmpty) ? null : color.trim(),
       bodyType = (bodyType == null || bodyType.trim().isEmpty)
           ? null
           : bodyType.trim(),
       makeNormalized = normalizeName(make),
       modelNormalized = normalizeName(model);

  String get title => '$make $model';

  String get subtitle {
    final parts = <String>[];
    if (year != null) parts.add(year.toString());
    if (color != null) parts.add(color!);
    if (bodyType != null) parts.add(bodyType!);
    return parts.isEmpty
        ? plateDisplay
        : '$plateDisplay • ${parts.join(' • ')}';
  }

  /// Единообразная аватарка по марке (используй везде в UI)
  /// Ожидаемые файлы:
  /// assets/images/cars/mercedes.png
  /// assets/images/cars/bmw.png
  /// assets/images/cars/audi.png
  /// assets/images/cars/default.png
  String get avatarAsset {
    final key = _makeKey(makeNormalized);

    switch (key) {
      case 'mercedes':
        return 'assets/images/cars/mercedes.png';
      case 'bmw':
        return 'assets/images/cars/bmw.png';
      case 'audi':
        return 'assets/images/cars/audi.png';
      default:
        return 'assets/images/cars/default.png';
    }
  }

  /// Приводим любые варианты ввода к ключам.
  /// normalizeName() уже убирает регистр/пробелы, но "мерседес" всё равно будет кириллицей.
  String _makeKey(String makeNorm) {
    final m = makeNorm.toLowerCase();

    // RU варианты
    if (m.contains('мерсед')) return 'mercedes';
    if (m.contains('бмв')) return 'bmw';
    if (m.contains('ауди')) return 'audi';

    // EN варианты
    if (m.contains('mercedes')) return 'mercedes';
    if (m == 'bmw' || m.contains('bmw')) return 'bmw';
    if (m.contains('audi')) return 'audi';

    return m;
  }

  /// ---- API mapping ----
  /// Backend fields: makeDisplay/modelDisplay/plateDisplay/plateNormalized
  factory Car.fromJson(Map<String, dynamic> j) {
    return Car(
      id: j['id'] as String,
      make: (j['makeDisplay'] ?? j['make'] ?? '') as String,
      model: (j['modelDisplay'] ?? j['model'] ?? '') as String,
      plateDisplay: (j['plateDisplay'] ?? '') as String,
      plateNormalized: (j['plateNormalized'] ?? '') as String,
      year: j['year'] as int?,
      color: j['color'] as String?,
      bodyType: j['bodyType'] as String?,
    );
  }

  Map<String, dynamic> toCreateJson() {
    // Что ждёт backend на POST /cars
    return {
      'makeDisplay': make.trim(),
      'modelDisplay': model.trim(),
      'plateDisplay': plateDisplay.trim(),
      'year': year,
      'color': color,
      'bodyType': bodyType,
    };
  }
}
