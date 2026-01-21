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
    if (!locationId) {
      throw new BadRequestException('locationId is required');
    }

    const bayIdNum = Number(bayIdRaw);
    const bayId = Number.isFinite(bayIdNum) ? Math.trunc(bayIdNum) : 1;
    if (bayId < 1 || bayId > 20) {
      throw new BadRequestException('bayId must be between 1 and 20');
    }

    const fromS = (fromRaw ?? '').trim();
    const toS = (toRaw ?? '').trim();
    if (!fromS || !toS) {
      throw new BadRequestException('from and to are required');
    }

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

  @Post()
  create(
    @Body()
    body: {
      carId: string;
      serviceId: string;
      dateTime: string;
      locationId?: string; // ✅ новое
      bayId?: number;
      depositRub?: number;
      bufferMin?: number;
      comment?: string;
      clientId?: string;
    },
  ) {
    return this.bookingsService.create(body);
  }

  @Post(':id/pay')
  pay(@Param('id') id: string, @Body() body?: any) {
    return this.bookingsService.pay(id, body);
  }

  @Delete(':id')
  cancel(@Param('id') id: string, @Query('clientId') clientId?: string) {
    const cid = (clientId ?? '').trim();
    if (!cid) throw new BadRequestException('clientId is required');

    return this.bookingsService.cancel(id, cid);
  }
}
