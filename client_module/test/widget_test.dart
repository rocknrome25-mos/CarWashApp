import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client_module/app.dart';

import 'package:client_module/core/data/app_repository.dart';
import 'package:client_module/core/models/booking.dart';
import 'package:client_module/core/models/car.dart';
import 'package:client_module/core/models/service.dart';
import 'package:client_module/core/models/client.dart';
import 'package:client_module/core/realtime/realtime_client.dart';

class _FakeRepo implements AppRepository {
  Client? _current;

  final _ctrl = StreamController<BookingRealtimeEvent>.broadcast();

  @override
  Stream<BookingRealtimeEvent> get bookingEvents => _ctrl.stream;

  @override
  Client? get currentClient => _current;

  @override
  Future<void> setCurrentClient(Client c) async {
    _current = c;
  }

  @override
  Future<void> logout() async {
    _current = null;
  }

  @override
  Future<void> dispose() async {
    await _ctrl.close();
  }

  @override
  Future<Client> loginDemo({required String phone}) async {
    final p = phone.trim();
    if (p.isEmpty) throw Exception('phone is required');

    final c = Client(
      id: 'demo-client',
      phone: p,
      name: 'Demo',
      gender: 'MALE',
      birthDate: null,
    );
    _current = c;
    return c;
  }

  @override
  Future<Client> registerClient({
    required String phone,
    String? name,
    required String gender,
    DateTime? birthDate,
  }) async {
    final c = Client(
      id: 'test-client',
      phone: phone,
      name: (name?.trim().isEmpty ?? true) ? null : name!.trim(),
      gender: gender,
      birthDate: birthDate,
    );
    _current = c;
    return c;
  }

  @override
  Future<List<Service>> getServices({bool forceRefresh = false}) async =>
      const [];

  @override
  Future<List<Car>> getCars({bool forceRefresh = false}) async => const [];

  @override
  Future<Car> addCar({
    required String makeDisplay,
    required String modelDisplay,
    required String plateDisplay,
    int? year,
    String? color,
    String? bodyType,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteCar(String id) async {}

  @override
  Future<List<Booking>> getBookings({
    bool includeCanceled = false,
    bool forceRefresh = false,
  }) async => const [];

  @override
  Future<List<DateTimeRange>> getBusySlots({
    required int bayId,
    required DateTime from,
    required DateTime to,
    bool forceRefresh = false,
  }) async => const [];

  @override
  Future<Booking> createBooking({
    required String carId,
    required String serviceId,
    required DateTime dateTime,
    int? bayId,
    int? depositRub,
    int? bufferMin,
    String? comment,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Booking> payBooking({required String bookingId, String? method}) {
    throw UnimplementedError();
  }

  @override
  Future<Booking> cancelBooking(String id) {
    throw UnimplementedError();
  }
}

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    final repo = _FakeRepo();

    await tester.pumpWidget(ClientModuleApp(repo: repo, onLogout: () {}));
    await tester.pump();

    expect(find.text('Автомойка'), findsOneWidget);
  });
}
