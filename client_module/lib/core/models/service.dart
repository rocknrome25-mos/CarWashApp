// C:\dev\carwash\client_module\lib\core\models\service.dart
class Service {
  final String id;
  final String name;
  final int priceRub;
  final int? durationMin;

  /// NEW: BASE / ADDON (server)
  final String? kind;

  /// NEW: sorting (server)
  final int? sortOrder;

  /// NEW: active flag (server)
  final bool? isActive;

  /// NEW: location scope (server)
  final String? locationId;

  /// Optional (production): backend can provide full URL to image
  final String? imageUrl;

  /// Optional: description for details page
  final String? description;

  const Service({
    required this.id,
    required this.name,
    required this.priceRub,
    this.durationMin,
    this.kind,
    this.sortOrder,
    this.isActive,
    this.locationId,
    this.imageUrl,
    this.description,
  });

  static int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '').toString());
  }

  static bool? _asBool(dynamic v) {
    if (v is bool) return v;
    final s = (v ?? '').toString().toLowerCase().trim();
    if (s == 'true' || s == '1') return true;
    if (s == 'false' || s == '0') return false;
    return null;
  }

  factory Service.fromJson(Map<String, dynamic> j) {
    return Service(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      priceRub: (j['priceRub'] is num)
          ? (j['priceRub'] as num).toInt()
          : int.tryParse((j['priceRub'] ?? '0').toString()) ?? 0,
      durationMin: _asInt(j['durationMin']),
      kind: (j['kind'] ?? '').toString().trim().isEmpty
          ? null
          : (j['kind'] ?? '').toString().trim(),
      sortOrder: _asInt(j['sortOrder']),
      isActive: _asBool(j['isActive']),
      locationId: (j['locationId'] ?? '').toString().trim().isEmpty
          ? null
          : (j['locationId'] ?? '').toString().trim(),
      imageUrl: j['imageUrl'] as String?,
      description: j['description'] as String?,
    );
  }
}
