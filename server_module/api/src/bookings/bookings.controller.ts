// C:\dev\carwash\server_module\api\src\bookings\bookings.controller.ts
import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Query,
} from '@nestjs/common';
import { BookingsService } from './bookings.service';

type BookingAddonInput = {
  serviceId: string;
  qty?: number;
};

type CreateBookingBody = {
  carId: string;
  serviceId: string;
  dateTime: string;
  locationId?: string;
  bayId?: number;

  // ✅ what client requested: null | 1 | 2
  requestedBayId?: number | null;

  depositRub?: number;
  bufferMin?: number;
  comment?: string;
  clientId?: string;
  addons?: BookingAddonInput[];
};

@Controller('bookings')
export class BookingsController {
  constructor(private readonly bookingsService: BookingsService) {}

  // ✅ PUBLIC "busy slots" (no clientId, no carId)
  // GET /bookings/busy?locationId=...&bayId=1&from=...&to=...
  @Get('busy')
  getBusy(
    @Query('locationId') locationIdRaw?: string,
    @Query('bayId') bayIdRaw?: string,
    @Query('from') fromRaw?: string,
    @Query('to') toRaw?: string,
  ) {
    const locationId = (locationIdRaw ?? '').trim();
    if (!locationId) throw new BadRequestException('locationId is required');

    const bayIdNum = Number(bayIdRaw);
    const bayId = Number.isFinite(bayIdNum) ? Math.trunc(bayIdNum) : 1;
    if (bayId < 1 || bayId > 20) {
      throw new BadRequestException('bayId must be between 1 and 20');
    }

    const fromS = (fromRaw ?? '').trim();
    const toS = (toRaw ?? '').trim();
    if (!fromS || !toS) throw new BadRequestException('from and to are required');

    const from = new Date(fromS);
    const to = new Date(toS);
    if (isNaN(from.getTime()) || isNaN(to.getTime())) {
      throw new BadRequestException('from/to must be ISO string');
    }
    if (to.getTime() <= from.getTime()) {
      throw new BadRequestException('to must be greater than from');
    }

    return this.bookingsService.getBusySlots({ locationId, bayId, from, to });
  }

  // ✅ CLIENT WAITLIST
  // GET /bookings/waitlist?clientId=...&includeAll=true
  @Get('waitlist')
  getWaitlist(
    @Query('clientId') clientId?: string,
    @Query('includeAll') includeAll?: string,
  ) {
    const cid = (clientId ?? '').trim();
    if (!cid) throw new BadRequestException('clientId is required');

    const all = includeAll === '1' || includeAll === 'true';
    return this.bookingsService.findWaitlistForClient(cid, all);
  }

  // GET /bookings?includeCanceled=true&clientId=...
  @Get()
  getAll(
    @Query('includeCanceled') includeCanceled?: string,
    @Query('clientId') clientId?: string,
  ) {
    const cid = (clientId ?? '').trim();
    if (!cid) throw new BadRequestException('clientId is required');

    const flag = includeCanceled === '1' || includeCanceled === 'true';
    return this.bookingsService.findAll(flag, cid);
  }

  // ✅ CREATE BOOKING (+ addons)
  @Post()
  create(@Body() body: CreateBookingBody) {
    if (!body || typeof body !== 'object') {
      throw new BadRequestException('body is required');
    }
    if (!body.carId || !body.serviceId || !body.dateTime) {
      throw new BadRequestException('carId, serviceId and dateTime are required');
    }

    // ✅ validate addons
    if (body.addons != null) {
      if (!Array.isArray(body.addons)) {
        throw new BadRequestException('addons must be an array');
      }
      for (const a of body.addons) {
        const sid = (a?.serviceId ?? '').toString().trim();
        if (!sid) throw new BadRequestException('addons.serviceId is required');

        const q = a?.qty;
        if (q != null) {
          const n = Number(q);
          if (!Number.isFinite(n) || Math.trunc(n) <= 0) {
            throw new BadRequestException('addons.qty must be > 0');
          }
        }
      }
    }

    // ✅ validate requestedBayId: null | 1 | 2
    let requestedBayId: number | null | undefined = body.requestedBayId;

    // if it's a string (can happen), normalize
    if (requestedBayId !== null && requestedBayId !== undefined) {
      const n = Number(requestedBayId as any);
      if (!Number.isFinite(n)) {
        throw new BadRequestException('requestedBayId must be 1 or 2 or null');
      }
      const nn = Math.trunc(n);
      if (nn !== 1 && nn !== 2) {
        throw new BadRequestException('requestedBayId must be 1 or 2 or null');
      }
      requestedBayId = nn;
    } else if (requestedBayId === null) {
      // explicit null is OK: means "ANY"
      requestedBayId = null;
    }

    // ✅ pass a normalized object to service
    const normalized: CreateBookingBody = {
      ...body,
      requestedBayId, // keep null | 1 | 2 | undefined
    };

    return this.bookingsService.create(normalized as any);
  }

  @Post(':id/pay')
  pay(@Param('id') id: string, @Body() body?: any) {
    const bid = (id ?? '').trim();
    if (!bid) throw new BadRequestException('booking id is required');
    return this.bookingsService.pay(bid, body);
  }

  @Delete(':id')
  cancel(@Param('id') id: string, @Query('clientId') clientId?: string) {
    const bid = (id ?? '').trim();
    if (!bid) throw new BadRequestException('booking id is required');

    const cid = (clientId ?? '').trim();
    if (!cid) throw new BadRequestException('clientId is required');

    return this.bookingsService.cancel(bid, cid);
  }

  // ✅ UPSALE: ADDONS (client-side)
  @Post(':id/addons')
  addAddon(@Param('id') id?: string, @Body() body: BookingAddonInput = {} as any) {
    const bookingId = (id ?? '').trim();
    if (!bookingId) throw new BadRequestException('booking id is required');

    const serviceId = (body?.serviceId ?? '').toString().trim();
    if (!serviceId) throw new BadRequestException('serviceId is required');

    const qtyRaw = body?.qty;
    const qtyNum = qtyRaw == null ? 1 : Number(qtyRaw);
    if (!Number.isFinite(qtyNum) || Math.trunc(qtyNum) <= 0) {
      throw new BadRequestException('qty must be > 0');
    }

    return this.bookingsService.addAddonForBooking(bookingId, {
      serviceId,
      qty: Math.trunc(qtyNum),
    });
  }

  @Delete(':id/addons/:serviceId')
  removeAddon(
    @Param('id') id?: string,
    @Param('serviceId') serviceId?: string,
  ) {
    const bookingId = (id ?? '').trim();
    if (!bookingId) throw new BadRequestException('booking id is required');

    const sid = (serviceId ?? '').trim();
    if (!sid) throw new BadRequestException('serviceId is required');

    return this.bookingsService.removeAddonForBooking(bookingId, sid);
  }
}
