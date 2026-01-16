import 'package:flutter/material.dart';

import '../models/booking.dart';
import '../models/car.dart';
import '../models/service.dart';
import '../models/client.dart';
import '../realtime/realtime_client.dart';

abstract class AppRepository {
  // --- SESSION ---
  Client? get currentClient;

  Future<void> setCurrentClient(Client c);
  Future<void> logout();

  /// ✅ чтобы закрывать WS, если нужно
  Future<void> dispose();

  // --- REALTIME ---
  Stream<BookingRealtimeEvent> get bookingEvents;

  // --- AUTH/REGISTER ---
  Future<Client> registerClient({
    required String phone,
    String? name,
    required String gender,
    DateTime? birthDate,
  });

  Future<Client> loginDemo({required String phone});

  // --- SERVICES ---
  Future<List<Service>> getServices({bool forceRefresh = false});

  // --- CARS ---
  Future<List<Car>> getCars({bool forceRefresh = false});

  Future<Car> addCar({
    required String makeDisplay,
    required String modelDisplay,
    required String plateDisplay,
    int? year,
    String? color,
    String? bodyType,
  });

  Future<void> deleteCar(String id);

  // --- BOOKINGS ---
  Future<List<Booking>> getBookings({
    bool includeCanceled = false,
    bool forceRefresh = false,
  });

  /// ✅ Public busy slots by bay/time (no client data)
  Future<List<DateTimeRange>> getBusySlots({
    required int bayId,
    required DateTime from,
    required DateTime to,
    bool forceRefresh = false,
  });

  Future<Booking> createBooking({
    required String carId,
    required String serviceId,
    required DateTime dateTime,
    int? bayId,
    int? depositRub,
    int? bufferMin,
    String? comment,
  });

  Future<Booking> payBooking({required String bookingId, String? method});
  Future<Booking> cancelBooking(String id);
}
