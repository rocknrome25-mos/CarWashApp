import '../utils/normalize.dart';

class Car {
  final String id;

  final String make;
  final String model;
  final String plateDisplay;

  final String makeNormalized;
  final String modelNormalized;
  final String plateNormalized;

  final int? year;
  final String? color;
  final String? bodyType;

  Car({
    required this.id,
    required this.make,
    required String model,
    required this.plateDisplay,
    required this.plateNormalized,
    this.year,
    String? color,
    String? bodyType,
  }) : model = _sanitizeModel(model),
       color = (color == null || color.trim().isEmpty) ? null : color.trim(),
       bodyType = (bodyType == null || bodyType.trim().isEmpty)
           ? null
           : bodyType.trim(),
       makeNormalized = normalizeName(make),
       modelNormalized = normalizeName(_sanitizeModel(model));

  static String _sanitizeModel(String raw) {
    final m = raw.trim();
    if (m.isEmpty) return '';
    final lower = m.toLowerCase();
    if (m == '—' || m == '-' || lower == 'n/a' || lower == 'na') return '';
    return m;
  }

  bool get hasUsefulModel => model.trim().isNotEmpty;

  String get title {
    final mk = make.trim();
    if (!hasUsefulModel) return mk;
    return '$mk ${model.trim()}';
  }

  String get subtitle {
    final parts = <String>[];

    if (year != null) parts.add(year.toString());
    if (color != null) parts.add(color!);
    if (bodyType != null) parts.add(_bodyTypeRu(bodyType!));

    return parts.isEmpty
        ? plateDisplay
        : '$plateDisplay • ${parts.join(' • ')}';
  }

  String _bodyTypeRu(String v) {
    final x = v.trim().toLowerCase();
    if (x == 'sedan') return 'седан';
    if (x == 'suv') return 'внедорожник';
    return v;
  }

  String get avatarAsset {
    final key = _makeKey(makeNormalized);

    switch (key) {
      case 'mercedes':
        return 'assets/images/cars/mercedes_128.png';
      case 'bmw':
        return 'assets/images/cars/bmw_128.png';
      case 'audi':
        return 'assets/images/cars/audi_128.png';
      default:
        return 'assets/images/cars/default.png';
    }
  }

  String _makeKey(String makeNorm) {
    final m = makeNorm.toLowerCase();

    if (m.contains('мерсед')) return 'mercedes';
    if (m.contains('бмв')) return 'bmw';
    if (m.contains('ауди')) return 'audi';

    if (m.contains('mercedes')) return 'mercedes';
    if (m == 'bmw' || m.contains('bmw')) return 'bmw';
    if (m.contains('audi')) return 'audi';

    return m;
  }

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
    return {
      'makeDisplay': make.trim(),
      'modelDisplay': model.trim().isEmpty ? '—' : model.trim(),
      'plateDisplay': plateDisplay.trim(),
      'year': year,
      'color': color,
      'bodyType': bodyType,
    };
  }
}
