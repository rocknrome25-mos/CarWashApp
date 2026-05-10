class Service {
  final String id;
  final String name;
  final int priceRub;
  final int durationMin;
  final String? imageUrl;
  final String? description;
  final bool isActive;
  final int sortOrder;
  final String? kind;

  Service({
    required this.id,
    required this.name,
    required this.priceRub,
    required this.durationMin,
    this.imageUrl,
    this.description,
    required this.isActive,
    required this.sortOrder,
    this.kind,
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      id: json['id'] as String,
      name: json['name'] as String,
      priceRub: json['priceRub'] as int? ?? 0,
      durationMin: json['durationMin'] as int? ?? 30,
      imageUrl: json['imageUrl'] as String?,
      description: json['description'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      sortOrder: json['sortOrder'] as int? ?? 0,
      kind: json['kind'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'priceRub': priceRub,
      'durationMin': durationMin,
      'imageUrl': imageUrl,
      'description': description,
      'isActive': isActive,
      'sortOrder': sortOrder,
      'kind': kind,
    };
  }

  Service copyWith({
    String? id,
    String? name,
    int? priceRub,
    int? durationMin,
    String? imageUrl,
    String? description,
    bool? isActive,
    int? sortOrder,
    String? kind,
  }) {
    return Service(
      id: id ?? this.id,
      name: name ?? this.name,
      priceRub: priceRub ?? this.priceRub,
      durationMin: durationMin ?? this.durationMin,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      kind: kind ?? this.kind,
    );
  }
}