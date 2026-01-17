import 'package:flutter/material.dart';

import '../../../core/data/app_repository.dart';
import '../../../core/models/service.dart';
import '../create_booking_page.dart';
import 'select_bay_page.dart';
import 'select_service_page.dart';

class BookingFlow {
  static Future<bool> start(BuildContext context, AppRepository repo) async {
    final nav = Navigator.of(context);

    final bay = await nav.push<BayChoice>(
      MaterialPageRoute(builder: (_) => const SelectBayPage()),
    );
    if (bay == null) return false;

    final Service? service = await nav.push<Service>(
      MaterialPageRoute(builder: (_) => SelectServicePage(repo: repo)),
    );
    if (service == null) return false;

    // На этом шаге можно передать bay в CreateBookingPage через параметр,
    // но у тебя сейчас его нет. Самый быстрый вариант: оставить табы внутри CreateBookingPage
    // и просто предвыбрать услугу.
    final created = await nav.push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateBookingPage(
          repo: repo,
          preselectedServiceId: service.id,
        ),
      ),
    );

    return created == true;
  }
}
