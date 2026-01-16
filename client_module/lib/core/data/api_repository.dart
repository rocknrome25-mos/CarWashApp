import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../cache/memory_cache.dart';
import '../data/app_repository.dart';
import '../models/booking.dart';
import '../models/car.dart';
import '../models/service.dart';
import '../models/client.dart';
import '../realtime/realtime_client.dart';

class ApiRepository implements AppRepository {
  final ApiClient api;
  final MemoryCache cache;
  final RealtimeClient realtime;

  static const _kClient = 'current_client';

  ApiRepository({
    required this.api,
    required this.cache,
    required this.realtime,
  });

  // ---------------- REALTIME ----------------

  @override
  Stream<BookingRealtimeEvent> get bookingEvents => realtime.events;

  // ---------------- SESSION ----------------

  @override
  Client? get currentClient => cache.get<Client>(_kClient);

  @override
  Future<void> setCurrentClient(Client c) async {
    cache.set(_kClient, c, ttl: const Duration(days: 365));
    cache.invalidate('cars');
    cache.invalidate('bookings_all');
    cache.invalidate('bookings_active');
    cache.invalidate('busy_slots');
  }

  @override
  Future<void> logout() async {
    cache.invalidate(_kClient);
    cache.invalidate('cars');
    cache.invalidate('bookings_all');
    cache.invalidate('bookings_active');
    cache.invalidate('busy_slots');
  }

  @override
  Future<void> dispose() async {
    await realtime.close();
  }

  String _requireClientId() {
    final cid = currentClient?.id;
    if (cid == null || cid.trim().isEmpty) {
      throw Exception('Нет активного клиента. Перезапусти и войди заново.');
    }
    return cid.trim();
  }

  // ---------------- AUTH / REGISTER ----------------

  @override
  Future<Client> registerClient({
    required String phone,
    String? name,
    required String gender,
    DateTime? birthDate,
  }) async {
    final payload = <String, dynamic>{
      'phone': phone.trim(),
      'gender': gender.trim().toUpperCase(),
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      if (birthDate != null) 'birthDate': birthDate.toUtc().toIso8601String(),
    };

    final j =
        await api.postJson('/clients/register', payload)
            as Map<String, dynamic>;

    final c = Client.fromJson(j);
    await setCurrentClient(c);
    return c;
  }

  @override
  Future<Client> loginDemo({required String phone}) async {
    final p = phone.trim();
    if (p.isEmpty) {
      throw Exception('Телефон обязателен для входа');
    }

    final j =
        await api.postJson('/clients/register', {
              'phone': p,
              'name': 'Demo',
              'gender': 'MALE',
            })
            as Map<String, dynamic>;

    final c = Client.fromJson(j);
    await setCurrentClient(c);
    return c;
  }

  // ---------------- SERVICES ----------------

  @override
  Future<List<Service>> getServices({bool forceRefresh = false}) async {
    const key = 'services';

    if (!forceRefresh) {
      final cached = cache.get<List<Service>>(key);
      if (cached != null) return cached;
    }

    final data = await api.getJson('/services') as List;
    final list = data
        .map((e) => Service.fromJson(e as Map<String, dynamic>))
        .toList();

    cache.set(key, list, ttl: const Duration(minutes: 2));
    return list;
  }

  // ---------------- CARS ----------------

  @override
  Future<List<Car>> getCars({bool forceRefresh = false}) async {
    const key = 'cars';

    if (!forceRefresh) {
      final cached = cache.get<List<Car>>(key);
      if (cached != null) return cached;
    }

    final cid = _requireClientId();
    final data = await api.getJson('/cars', query: {'clientId': cid}) as List;

    final list = data
        .map((e) => Car.fromJson(e as Map<String, dynamic>))
        .toList();

    cache.set(key, list, ttl: const Duration(seconds: 30));
    return list;
  }

  @override
  Future<Car> addCar({
    required String makeDisplay,
    required String modelDisplay,
    required String plateDisplay,
    int? year,
    String? color,
    String? bodyType,
  }) async {
    final cid = _requireClientId();

    final payload = <String, dynamic>{
      'makeDisplay': makeDisplay.trim(),
      'modelDisplay': modelDisplay.trim(),
      'plateDisplay': plateDisplay.trim(),
      'year': year,
      'color': color,
      'bodyType': bodyType,
      'clientId': cid,
    };

    final j = await api.postJson('/cars', payload) as Map<String, dynamic>;

    cache.invalidate('cars');
    cache.invalidate('bookings_all');
    cache.invalidate('bookings_active');
    cache.invalidate('busy_slots');

    return Car.fromJson(j);
  }

  @override
  Future<void> deleteCar(String id) async {
    final cid = _requireClientId();

    await api.deleteJson('/cars/$id', query: {'clientId': cid});

    cache.invalidate('cars');
    cache.invalidate('bookings_all');
    cache.invalidate('bookings_active');
    cache.invalidate('busy_slots');
  }

  // ---------------- BOOKINGS ----------------

  @override
  Future<List<Booking>> getBookings({
    bool includeCanceled = false,
    bool forceRefresh = false,
  }) async {
    final key = includeCanceled ? 'bookings_all' : 'bookings_active';

    if (!forceRefresh) {
      final cached = cache.get<List<Booking>>(key);
      if (cached != null) return cached;
    }

    final cid = _requireClientId();

    final query = <String, String>{'clientId': cid};
    if (includeCanceled) query['includeCanceled'] = 'true';

    final data = await api.getJson('/bookings', query: query) as List;
    final list = data
        .map((e) => Booking.fromJson(e as Map<String, dynamic>))
        .toList();

    cache.set(key, list, ttl: const Duration(seconds: 15));
    return list;
  }

  @override
  Future<List<DateTimeRange>> getBusySlots({
    required int bayId,
    required DateTime from,
    required DateTime to,
    bool forceRefresh = false,
  }) async {
    final key =
        'busy_slots_${bayId}_${from.toUtc().toIso8601String()}_${to.toUtc().toIso8601String()}';

    if (!forceRefresh) {
      final cached = cache.get<List<DateTimeRange>>(key);
      if (cached != null) return cached;
    }

    final query = <String, String>{
      'bayId': bayId.toString(),
      'from': from.toUtc().toIso8601String(),
      'to': to.toUtc().toIso8601String(),
    };

    final data = await api.getJson('/bookings/busy', query: query) as List;

    final ranges = data.map((e) {
      final m = e as Map<String, dynamic>;
      final startUtc = DateTime.parse(m['start'] as String);
      final endUtc = DateTime.parse(m['end'] as String);
      return DateTimeRange(start: startUtc.toLocal(), end: endUtc.toLocal());
    }).toList();

    cache.set(key, ranges, ttl: const Duration(seconds: 20));
    return ranges;
  }

  @override
  Future<Booking> createBooking({
    required String carId,
    required String serviceId,
    required DateTime dateTime,
    int? bayId,
    int? depositRub,
    int? bufferMin,
    String? comment,
  }) async {
    final cid = _requireClientId();

    final payload = <String, dynamic>{
      'carId': carId,
      'serviceId': serviceId,
      'dateTime': dateTime.toUtc().toIso8601String(),
      'clientId': cid,
      if (bayId != null) 'bayId': bayId,
      if (depositRub != null) 'depositRub': depositRub,
      if (bufferMin != null) 'bufferMin': bufferMin,
      if (comment != null) 'comment': comment,
    };

    final j = await api.postJson('/bookings', payload) as Map<String, dynamic>;

    cache.invalidate('bookings_all');
    cache.invalidate('bookings_active');
    cache.invalidate('busy_slots');

    return Booking.fromJson(j);
  }

  @override
  Future<Booking> payBooking({
    required String bookingId,
    String? method,
  }) async {
    final j =
        await api.postJson('/bookings/$bookingId/pay', {
              if (method != null) 'method': method,
            })
            as Map<String, dynamic>;

    cache.invalidate('bookings_all');
    cache.invalidate('bookings_active');
    cache.invalidate('busy_slots');

    return Booking.fromJson(j);
  }

  @override
  Future<Booking> cancelBooking(String id) async {
    final cid = _requireClientId();

    final j =
        await api.deleteJson('/bookings/$id', query: {'clientId': cid})
            as Map<String, dynamic>;

    cache.invalidate('bookings_all');
    cache.invalidate('bookings_active');
    cache.invalidate('busy_slots');

    return Booking.fromJson(j);
  }
}
