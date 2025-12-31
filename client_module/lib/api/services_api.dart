import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/models/service.dart';

class ServiceDto {
  final String id;
  final String name;
  final int priceRub;

  ServiceDto({required this.id, required this.name, required this.priceRub});

  factory ServiceDto.fromJson(Map<String, dynamic> json) => ServiceDto(
    id: json['id'] as String,
    name: json['name'] as String,
    priceRub: json['priceRub'] as int,
  );

  Service toDomain() => Service(
    id: id,
    name: name,
    priceRub: priceRub,
    durationMin: null, // пока нет в БД
  );
}

class ServicesApi {
  final String baseUrl;
  ServicesApi({required this.baseUrl});

  Future<List<Service>> fetchServices() async {
    final uri = Uri.parse('$baseUrl/services');
    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception('Failed to load services: ${res.statusCode} ${res.body}');
    }

    final List data = jsonDecode(res.body) as List;
    return data
        .map((e) => ServiceDto.fromJson(e as Map<String, dynamic>).toDomain())
        .toList();
  }
}
