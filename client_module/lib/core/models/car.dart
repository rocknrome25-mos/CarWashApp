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
    int? year,
    String? color,
    String? bodyType,
  }) : year = year,
       color = (color == null || color.trim().isEmpty) ? null : color.trim(),
       bodyType = (bodyType == null || bodyType.trim().isEmpty)
           ? null
           : bodyType,
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
}
